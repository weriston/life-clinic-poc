#!/usr/bin/env bash
set -euo pipefail

# deploy.sh 
# - Idempotente (create/update)
# - Suporta --destroy para remover infra criada
# - Usa aws cli, jq, zip
# - Detecta account/region via sts / aws configure
# - Cria: S3 (private), CloudFront (HTTPS), Lambda, IAM role, API Gateway (REST), bucket policy, invalidation
# - Packs backend into ZIP (includes ia/ by default)
# - Safe: no hardcoded account ids in repo. Uses runtime detection.

# REQUIREMENTS:
# - aws cli v2 configured (aws configure)
# - jq
# - zip
# - openssl (for simple key generation if needed)
# - You must run from repo root

# Usage:
#   bash deploy.sh            # deploy/create/update
#   bash deploy.sh --destroy  # destroy created infra (use carefully)
#   bash deploy.sh --help

AWS_CLI=${AWS_CLI:-aws}
JQ=${JQ:-jq}
ZIP=${ZIP:-zip}
OPENSSL=${OPENSSL:-openssl}

# ---------------------------
# Args
# ---------------------------
DESTROY=false
FORCE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --destroy) DESTROY=true; shift ;;
    --force) FORCE=true; shift ;;
    --help) echo "Usage: $0 [--destroy] [--force]"; exit 0 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# ---------------------------
# Auto detect environment
# ---------------------------
AWS_REGION=$($AWS_CLI configure get region || echo "")
if [[ -z "$AWS_REGION" ]]; then
  echo "[ERROR] AWS region not set. Run: aws configure"
  exit 1
fi

AWS_ACCOUNT_ID=$($AWS_CLI sts get-caller-identity --query Account --output text)
if [[ -z "$AWS_ACCOUNT_ID" ]]; then
  echo "[ERROR] Cannot detect AWS account id"
  exit 1
fi

TIMESTAMP=$(date +%s)
STACK_TAG="lifeclinic-poc"
LAMBDA_NAME=${LAMBDA_NAME:-"manual-backend-function"}
LAMBDA_HANDLER=${LAMBDA_HANDLER:-"backend/server.handler"}
LAMBDA_RUNTIME=${LAMBDA_RUNTIME:-"nodejs18.x"}
LAMBDA_ROLE_NAME=${LAMBDA_ROLE_NAME:-"${STACK_TAG}-lambda-role"}
BUCKET_NAME=${BUCKET_NAME:-"lifeclinic-frontend-${AWS_ACCOUNT_ID}"}
CF_COMMENT="LifeClinic POC CloudFront distribution"
API_NAME=${API_NAME:-"Life Clinic API"}
STAGE_NAME=${STAGE_NAME:-"prod"}
CLOUDFRONT_LOG_BUCKET=${CLOUDFRONT_LOG_BUCKET:-""} # optional

# Files
BACKEND_ZIP="../backend-lambda.zip"   # relative to backend dir; will be created
BACKEND_DIR="./backend"
FRONTEND_DIR="./frontend/build"
DEPLOY_LOG="./deploy-output.log"

echo "[INFO] Deploy starting - account=$AWS_ACCOUNT_ID region=$AWS_REGION" | tee -a $DEPLOY_LOG

# ---------------------------
# Helper funcs
# ---------------------------
function awsjson() {
  # wrapper to call aws and parse json safely
  $AWS_CLI "$@" --output json
}

# ---------------------------
# Destroy flow
# ---------------------------
if [[ "$DESTROY" == "true" ]]; then
  echo "[WARN] Destroy mode. This will remove resources created by this script (Lambda, API GW, CloudFront, S3 bucket policy/distribution)."
  if [[ "$FORCE" != "true" ]]; then
    read -p "Type 'DESTROY' to proceed: " CONF
    if [[ "$CONF" != "DESTROY" ]]; then
      echo "Aborting."
      exit 1
    fi
  fi

  # 1) Find API by name and delete
  API_ID=$($AWS_CLI apigateway get-rest-apis --query "items[?name=='${API_NAME}'].id | [0]" --output text || echo "")
  if [[ -n "$API_ID" ]]; then
    echo "[DESTROY] Deleting API Gateway $API_ID"
    $AWS_CLI apigateway delete-rest-api --rest-api-id "$API_ID"
  fi

  # 2) Delete Lambda function
  if $AWS_CLI lambda get-function --function-name "$LAMBDA_NAME" >/dev/null 2>&1; then
    echo "[DESTROY] Deleting Lambda $LAMBDA_NAME"
    $AWS_CLI lambda delete-function --function-name "$LAMBDA_NAME"
  fi

  # 3) Delete IAM role (detach policies)
  ROLE_ARN=$($AWS_CLI iam get-role --role-name "$LAMBDA_ROLE_NAME" --query 'Role.Arn' --output text 2>/dev/null || echo "")
  if [[ -n "$ROLE_ARN" ]]; then
    echo "[DESTROY] Deleting IAM role $LAMBDA_ROLE_NAME"
    # detach policies
    for arn in $($AWS_CLI iam list-attached-role-policies --role-name "$LAMBDA_ROLE_NAME" --query 'AttachedPolicies[].PolicyArn' --output text || echo ""); do
      $AWS_CLI iam detach-role-policy --role-name "$LAMBDA_ROLE_NAME" --policy-arn "$arn"
    done
    $AWS_CLI iam delete-role --role-name "$LAMBDA_ROLE_NAME" || true
  fi

  # 4) CloudFront distributions created by this script are searched by comment
  DIST_ID=$($AWS_CLI cloudfront list-distributions --query "DistributionList.Items[?Comment=='${CF_COMMENT}'].Id | [0]" --output text 2>/dev/null || echo "")
  if [[ -n "$DIST_ID" && "$DIST_ID" != "None" ]]; then
    echo "[DESTROY] Disabling CloudFront distribution $DIST_ID"
    ETag=$($AWS_CLI cloudfront get-distribution-config --id "$DIST_ID" --query 'ETag' --output text)
    CFG=$($AWS_CLI cloudfront get-distribution-config --id "$DIST_ID" --output json)
    # patch to disable
    $AWS_CLI cloudfront update-distribution \
      --id "$DIST_ID" \
      --if-match "$ETag" \
      --distribution-config "$(echo $CFG | $JQ 'del(.ETag) | .DistributionConfig | .Enabled = false')"
    echo "[DESTROY] Waiting 10s for disabled state"
    sleep 10
    # delete
    $AWS_CLI cloudfront delete-distribution --id "$DIST_ID" --if-match "$ETag" || true
  fi

  # 5) Remove bucket policy (but not the bucket itself)
  if $AWS_CLI s3api get-bucket-policy --bucket "$BUCKET_NAME" >/dev/null 2>&1; then
    echo "[DESTROY] Deleting bucket policy on $BUCKET_NAME"
    $AWS_CLI s3api delete-bucket-policy --bucket "$BUCKET_NAME"
  fi

  # 6) Optionally remove bucket website config
  if $AWS_CLI s3api get-bucket-website --bucket "$BUCKET_NAME" >/dev/null 2>&1; then
    echo "[DESTROY] Deleting bucket website config"
    $AWS_CLI s3api delete-bucket-website --bucket "$BUCKET_NAME"
  fi

  echo "[DESTROY] Done."
  exit 0
fi

# ---------------------------
# 1) Build & upload frontend
# ---------------------------
echo "[1/12] Build frontend (if react project)"
if [[ -d "./frontend" ]]; then
  pushd frontend >/dev/null
  if [[ -f package.json ]]; then
    echo "[INFO] Running frontend build..."
    npm run build
  fi
  popd >/dev/null
fi

# create bucket if not exists
if ! $AWS_CLI s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "[2/12] Creating S3 bucket $BUCKET_NAME"
  if [[ "$AWS_REGION" == "us-east-1" ]]; then
    $AWS_CLI s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION"
  else
    $AWS_CLI s3api create-bucket --bucket "$BUCKET_NAME" --create-bucket-configuration LocationConstraint="$AWS_REGION" --region "$AWS_REGION"
  fi
else
  echo "[2/12] Bucket $BUCKET_NAME exists"
fi

# ---------------------------
# 2) Make bucket private and upload build
# ---------------------------
echo "[3/12] Configure bucket (private origin - CloudFront)"
# remove public access block if present (we want to serve via CloudFront)
if $AWS_CLI s3api get-public-access-block --bucket "$BUCKET_NAME" >/dev/null 2>&1; then
  $AWS_CLI s3api delete-public-access-block --bucket "$BUCKET_NAME"
fi

# apply private ACL (owner only)
$AWS_CLI s3api put-bucket-acl --bucket "$BUCKET_NAME" --acl private

# sync files with cache header defaults (index.html no-cache)
echo "[3.1] Uploading frontend files with cache-control rules"
# index.html -> no-cache
$AWS_CLI s3 cp frontend/build/index.html s3://$BUCKET_NAME/index.html \
  --cache-control "no-cache, max-age=0" --acl private
# static assets -> long cache
$AWS_CLI s3 sync frontend/build/ s3://$BUCKET_NAME/ --exclude "index.html" \
  --cache-control "max-age=31536000, public" --acl private

# set website config (for fallback only, CloudFront origin uses s3 bucket not website)
$AWS_CLI s3api put-bucket-website --bucket "$BUCKET_NAME" --website-configuration '{
  "IndexDocument": {"Suffix": "index.html"},
  "ErrorDocument": {"Key": "index.html"}
}'

# ---------------------------
# 3) Create IAM role for Lambda (least privilege)
# ---------------------------
echo "[4/12] Ensure IAM role for Lambda exists: $LAMBDA_ROLE_NAME"
ROLE_ARN=$($AWS_CLI iam get-role --role-name "$LAMBDA_ROLE_NAME" --query 'Role.Arn' --output text 2>/dev/null || echo "")
if [[ -z "$ROLE_ARN" ]]; then
  cat > /tmp/trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": { "Service": "lambda.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  $AWS_CLI iam create-role --role-name "$LAMBDA_ROLE_NAME" --assume-role-policy-document file:///tmp/trust-policy.json
  # attach managed policy for basic lambda execution + cloudwatch
  $AWS_CLI iam attach-role-policy --role-name "$LAMBDA_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
  ROLE_ARN=$($AWS_CLI iam get-role --role-name "$LAMBDA_ROLE_NAME" --query 'Role.Arn' --output text)
  echo "[INFO] Created role $LAMBDA_ROLE_NAME ($ROLE_ARN)"
else
  echo "[INFO] Role $LAMBDA_ROLE_NAME exists ($ROLE_ARN)"
fi

# ---------------------------
# 4) Package backend lambda
# ---------------------------
echo "[5/12] Packaging backend Lambda"
pushd backend >/dev/null
# clean and create zip
rm -f ../backend-lambda.zip
# make sure node_modules included if you want to run in lambda; otherwise user must include dependencies
$ZIP -r ../backend-lambda.zip . -x "*.git*" "node_modules/*" || true
# If you need to include node_modules, uncomment:
# $ZIP -r ../backend-lambda.zip . -x "*.git*"
popd >/dev/null
echo "[INFO] Built $BACKEND_ZIP"

# ---------------------------
# 5) Create or update Lambda
# ---------------------------
echo "[6/12] Create or update Lambda function: $LAMBDA_NAME"
if $AWS_CLI lambda get-function --function-name "$LAMBDA_NAME" >/dev/null 2>&1; then
  echo "[INFO] Updating function code"
  $AWS_CLI lambda update-function-code --function-name "$LAMBDA_NAME" --zip-file fileb://$BACKEND_ZIP
  $AWS_CLI lambda update-function-configuration --function-name "$LAMBDA_NAME" --handler "$LAMBDA_HANDLER" --runtime "$LAMBDA_RUNTIME" --role "$ROLE_ARN"
else
  echo "[INFO] Creating function"
  $AWS_CLI lambda create-function --function-name "$LAMBDA_NAME" \
    --runtime "$LAMBDA_RUNTIME" \
    --handler "$LAMBDA_HANDLER" \
    --role "$ROLE_ARN" \
    --zip-file fileb://$BACKEND_ZIP \
    --timeout 15 --memory-size 256
fi
LAMBDA_ARN=$($AWS_CLI lambda get-function --function-name "$LAMBDA_NAME" --query 'Configuration.FunctionArn' --output text)

# ---------------------------
# 6) API Gateway REST (idempotent)
# ---------------------------
echo "[7/12] Ensure API Gateway REST: $API_NAME"
API_ID=$($AWS_CLI apigateway get-rest-apis --query "items[?name=='${API_NAME}'].id | [0]" --output text || echo "")
if [[ -z "$API_ID" || "$API_ID" == "None" ]]; then
  API_ID=$($AWS_CLI apigateway create-rest-api --name "$API_NAME" --description "API for Life Clinic POC" --query 'id' --output text)
  echo "[INFO] Created API: $API_ID"
else
  echo "[INFO] Found existing API: $API_ID"
fi

ROOT_ID=$($AWS_CLI apigateway get-resources --rest-api-id $API_ID --query "items[?path=='/'].id" --output text)
# create resource /api if not exist
API_RESOURCE_API=$($AWS_CLI apigateway get-resources --rest-api-id $API_ID --query "items[?path=='/api'].id | [0]" --output text || echo "")
if [[ -z "$API_RESOURCE_API" || "$API_RESOURCE_API" == "None" ]]; then
  API_RESOURCE_API=$($AWS_CLI apigateway create-resource --rest-api-id $API_ID --parent-id $ROOT_ID --path-part api --query 'id' --output text)
  echo "[INFO] Created resource /api -> $API_RESOURCE_API"
fi

ensure_method_and_integration() {
  local resource_id=$1
  local http_method=$2
  local lambda_arn=$3
  # create method if not exists
  if ! $AWS_CLI apigateway get-method --rest-api-id $API_ID --resource-id $resource_id --http-method $http_method >/dev/null 2>&1; then
    $AWS_CLI apigateway put-method --rest-api-id $API_ID --resource-id $resource_id --http-method $http_method --authorization-type "NONE"
  fi
  # put integration (aws_proxy)
  if ! $AWS_CLI apigateway get-integration --rest-api-id $API_ID --resource-id $resource_id --http-method $http_method >/dev/null 2>&1; then
    $AWS_CLI apigateway put-integration --rest-api-id $API_ID --resource-id $resource_id --http-method $http_method \
      --type AWS_PROXY \
      --integration-http-method POST \
      --uri "arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/${lambda_arn}/invocations"
  else
    echo "[INFO] Integration exists for ${http_method} on ${resource_id}"
  fi
  # add lambda permission for this API & method
  SID="apigw-${API_ID}-${resource_id}-${http_method}"
  SOURCE_ARN="arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/${http_method}/*"
  # Try add-permission idempotently (catch error)
  set +e
  $AWS_CLI lambda add-permission --function-name "$LAMBDA_NAME" --statement-id "$SID" --action lambda:InvokeFunction --principal apigateway.amazonaws.com --source-arn "$SOURCE_ARN" >/dev/null 2>&1
  set -e
}

# create /api/recomendar
RES_RECOMENDAR=$($AWS_CLI apigateway get-resources --rest-api-id $API_ID --query "items[?path=='/api/recomendar'].id | [0]" --output text || echo "")
if [[ -z "$RES_RECOMENDAR" || "$RES_RECOMENDAR" == "None" ]]; then
  RES_RECOMENDAR=$($AWS_CLI apigateway create-resource --rest-api-id $API_ID --parent-id $API_RESOURCE_API --path-part recomendar --query 'id' --output text)
fi

# create /api/agendar
RES_AGENDAR=$($AWS_CLI apigateway get-resources --rest-api-id $API_ID --query "items[?path=='/api/agendar'].id | [0]" --output text || echo "")
if [[ -z "$RES_AGENDAR" || "$RES_AGENDAR" == "None" ]]; then
  RES_AGENDAR=$($AWS_CLI apigateway create-resource --rest-api-id $API_ID --parent-id $API_RESOURCE_API --path-part agendar --query 'id' --output text)
fi

# create /api/insumos
RES_INSUMOS=$($AWS_CLI apigateway get-resources --rest-api-id $API_ID --query "items[?path=='/api/insumos'].id | [0]" --output text || echo "")
if [[ -z "$RES_INSUMOS" || "$RES_INSUMOS" == "None" ]]; then
  RES_INSUMOS=$($AWS_CLI apigateway create-resource --rest-api-id $API_ID --parent-id $API_RESOURCE_API --path-part insumos --query 'id' --output text)
fi

# ensure POST/OPTIONS for recomendar
ensure_method_and_integration "$RES_RECOMENDAR" "POST" "$LAMBDA_ARN"
# add mock OPTIONS to handle CORS
if ! $AWS_CLI apigateway get-method --rest-api-id $API_ID --resource-id $RES_RECOMENDAR --http-method OPTIONS >/dev/null 2>&1; then
  $AWS_CLI apigateway put-method --rest-api-id $API_ID --resource-id $RES_RECOMENDAR --http-method OPTIONS --authorization-type "NONE"
  $AWS_CLI apigateway put-integration --rest-api-id $API_ID --resource-id $RES_RECOMENDAR --http-method OPTIONS --type MOCK --request-templates '{"application/json":"{}"}' --passthrough-behavior WHEN_NO_MATCH
  $AWS_CLI apigateway put-method-response --rest-api-id $API_ID --resource-id $RES_RECOMENDAR --http-method OPTIONS --status-code 200 --response-models '{"application/json":"Empty"}' --response-parameters "method.response.header.Access-Control-Allow-Origin=true" "method.response.header.Access-Control-Allow-Headers=true" "method.response.header.Access-Control-Allow-Methods=true"
  $AWS_CLI apigateway put-integration-response --rest-api-id $API_ID --resource-id $RES_RECOMENDAR --http-method OPTIONS --status-code 200 --response-templates '{"application/json": ""}' --response-parameters "{\"method.response.header.Access-Control-Allow-Origin\":\"'*\",\"method.response.header.Access-Control-Allow-Headers\":\"'Content-Type,Authorization'\",\"method.response.header.Access-Control-Allow-Methods\":\"'POST,OPTIONS'\"}"
fi

# ensure GET for insumos (and OPTIONS)
ensure_method_and_integration "$RES_INSUMOS" "GET" "$LAMBDA_ARN"
if ! $AWS_CLI apigateway get-method --rest-api-id $API_ID --resource-id $RES_INSUMOS --http-method OPTIONS >/dev/null 2>&1; then
  $AWS_CLI apigateway put-method --rest-api-id $API_ID --resource-id $RES_INSUMOS --http-method OPTIONS --authorization-type "NONE"
  $AWS_CLI apigateway put-integration --rest-api-id $API_ID --resource-id $RES_INSUMOS --http-method OPTIONS --type MOCK --request-templates '{"application/json":"{}"}' --passthrough-behavior WHEN_NO_MATCH
  $AWS_CLI apigateway put-method-response --rest-api-id $API_ID --resource-id $RES_INSUMOS --http-method OPTIONS --status-code 200 --response-models '{"application/json":"Empty"}' --response-parameters "method.response.header.Access-Control-Allow-Origin=true" "method.response.header.Access-Control-Allow-Headers=true" "method.response.header.Access-Control-Allow-Methods=true"
  $AWS_CLI apigateway put-integration-response --rest-api-id $API_ID --resource-id $RES_INSUMOS --http-method OPTIONS --status-code 200 --response-templates '{"application/json": ""}' --response-parameters "{\"method.response.header.Access-Control-Allow-Origin\":\"'*\",""method.response.header.Access-Control-Allow-Headers\":\"'Content-Type,Authorization'\",\"method.response.header.Access-Control-Allow-Methods\":\"'GET,OPTIONS'\"}"
fi

# ensure POST for agendar (and OPTIONS)
ensure_method_and_integration "$RES_AGENDAR" "POST" "$LAMBDA_ARN"
if ! $AWS_CLI apigateway get-method --rest-api-id $API_ID --resource-id $RES_AGENDAR --http-method OPTIONS >/dev/null 2>&1; then
  $AWS_CLI apigateway put-method --rest-api-id $API_ID --resource-id $RES_AGENDAR --http-method OPTIONS --authorization-type "NONE"
  $AWS_CLI apigateway put-integration --rest-api-id $API_ID --resource-id $RES_AGENDAR --http-method OPTIONS --type MOCK --request-templates '{"application/json":"{}"}' --passthrough-behavior WHEN_NO_MATCH
  $AWS_CLI apigateway put-method-response --rest-api-id $API_ID --resource-id $RES_AGENDAR --http-method OPTIONS --status-code 200 --response-models '{"application/json":"Empty"}' --response-parameters "method.response.header.Access-Control-Allow-Origin=true" "method.response.header.Access-Control-Allow-Headers=true" "method.response.header.Access-Control-Allow-Methods=true"
  $AWS_CLI apigateway put-integration-response --rest-api-id $API_ID --resource-id $RES_AGENDAR --http-method OPTIONS --status-code 200 --response-templates '{"application/json": ""}' --response-parameters "{\"method.response.header.Access-Control-Allow-Origin\":\"'*\",""method.response.header.Access-Control-Allow-Headers\":\"'Content-Type,Authorization'\",\"method.response.header.Access-Control-Allow-Methods\":\"'POST,OPTIONS'\"}"
fi

# Deploy the API
echo "[8/12] Deploying API to stage $STAGE_NAME"
$AWS_CLI apigateway create-deployment --rest-api-id $API_ID --stage-name $STAGE_NAME >/dev/null

API_INVOKE_URL="https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/${STAGE_NAME}"
echo "[INFO] API URL: $API_INVOKE_URL"

# ---------------------------
# 7) CloudFront (HTTPS + origin access)
# ---------------------------
echo "[9/12] CloudFront setup (private S3 origin + HTTPS)"
# Create Origin Access Identity (OAI)
OAI_ID=$($AWS_CLI cloudfront list-cloud-front-origin-access-identities --query "CloudFrontOriginAccessIdentityList.Items[?Comment=='${STACK_TAG}'].Id | [0]" --output text 2>/dev/null || echo "")
if [[ -z "$OAI_ID" || "$OAI_ID" == "None" ]]; then
  OAI_JSON=$($AWS_CLI cloudfront create-cloud-front-origin-access-identity --cloud-front-origin-access-identity-config "CallerReference=${TIMESTAMP},Comment=${STACK_TAG}" --output json)
  OAI_ID=$(echo "$OAI_JSON" | $JQ -r '.CloudFrontOriginAccessIdentity.Id')
  OAI_S3_CANONICAL_USER=$(echo "$OAI_JSON" | $JQ -r '.CloudFrontOriginAccessIdentity.S3CanonicalUserId')
  echo "[INFO] Created OAI $OAI_ID"
else
  OAI_S3_CANONICAL_USER=$($AWS_CLI cloudfront get-cloud-front-origin-access-identity --id "$OAI_ID" --query 'CloudFrontOriginAccessIdentity.S3CanonicalUserId' --output text)
  echo "[INFO] Found OAI $OAI_ID"
fi

# Grant OAI read permission on bucket
echo "[9.1] Granting OAI permission to read bucket objects"
POLICY=$(cat <<EOF
{
  "Version":"2012-10-17",
  "Statement":[
    {
      "Effect":"Allow",
      "Principal":{"CanonicalUser":"$OAI_S3_CANONICAL_USER"},
      "Action":"s3:GetObject",
      "Resource":"arn:aws:s3:::${BUCKET_NAME}/*"
    }
  ]
}
EOF
)
$AWS_CLI s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy "$POLICY"

# Build CloudFront distribution config (basic)
ORIGIN_ID="S3-${BUCKET_NAME}"
DIST_ID=$($AWS_CLI cloudfront list-distributions --query "DistributionList.Items[?Comment=='${CF_COMMENT}'].Id | [0]" --output text 2>/dev/null || echo "")
if [[ -z "$DIST_ID" || "$DIST_ID" == "None" ]]; then
  echo "[9.2] Creating CloudFront distribution"
  CALLER_REF="lc-${TIMESTAMP}"
  read -r -d '' DIST_CONFIG <<EOF || true
{
  "CallerReference": "${CALLER_REF}",
  "Comment": "${CF_COMMENT}",
  "DefaultRootObject": "index.html",
  "Enabled": true,
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "${ORIGIN_ID}",
        "DomainName": "${BUCKET_NAME}.s3.amazonaws.com",
        "S3OriginConfig": {
          "OriginAccessIdentity": "origin-access-identity/cloudfront/${OAI_ID}"
        }
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "${ORIGIN_ID}",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET","HEAD"]
    },
    "ForwardedValues": {
      "QueryString": false,
      "Cookies": {"Forward": "none"}
    },
    "MinTTL": 0,
    "DefaultTTL": 3600,
    "MaxTTL": 31536000
  },
  "ViewerCertificate": {
    "CloudFrontDefaultCertificate": true
  }
}
EOF

  DIST_JSON=$($AWS_CLI cloudfront create-distribution --distribution-config "$DIST_CONFIG")
  DIST_ID=$(echo "$DIST_JSON" | $JQ -r '.Distribution.Id')
  DIST_DOMAIN=$(echo "$DIST_JSON" | $JQ -r '.Distribution.DomainName')
  echo "[INFO] Created CloudFront dist: $DIST_ID ($DIST_DOMAIN)"
else
  echo "[9.2] Found existing CloudFront distribution $DIST_ID"
  DIST_DOMAIN=$($AWS_CLI cloudfront get-distribution --id "$DIST_ID" --query 'Distribution.DomainName' --output text)
fi

# ---------------------------
# 8) Add Lambda permissions for API (already attempted in ensure_method_and_integration)
# ---------------------------
echo "[10/12] Ensure Lambda permissions for API Gateway"
# Ensure policy entries exist for each method - done in ensure_method_and_integration

# ---------------------------
# 9) Invalidate CloudFront so latest assets are served
# ---------------------------
echo "[11/12] Creating CloudFront invalidation for /*"
ETAG=$($AWS_CLI cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*" --query 'Invalidation.Id' --output text)
echo "[INFO] Invalidation created: $ETAG"

# ---------------------------
# 10) Output summary & write frontend env
# ---------------------------
CF_DOMAIN=$($AWS_CLI cloudfront get-distribution --id "$DIST_ID" --query 'Distribution.DomainName' --output text)
FRONTEND_URL="https://${CF_DOMAIN}"
echo "[12/12] DEPLOY COMPLETED"
echo "Frontend URL: $FRONTEND_URL"
echo "API URL: $API_INVOKE_URL"

cat > frontend/.env <<EOF
REACT_APP_API_URL=${API_INVOKE_URL}
REACT_APP_CLOUDFRONT_DOMAIN=${CF_DOMAIN}
EOF

echo "[INFO] Wrote frontend/.env"

echo "---- DEPLOY OUTPUT ----" | tee -a $DEPLOY_LOG
echo "Frontend: $FRONTEND_URL" | tee -a $DEPLOY_LOG
echo "API: $API_INVOKE_URL" | tee -a $DEPLOY_LOG
echo "CloudFront domain: $CF_DOMAIN" | tee -a $DEPLOY_LOG

exit 0
