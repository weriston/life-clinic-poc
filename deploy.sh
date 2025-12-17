#!/usr/bin/env bash
set -euo pipefail

# deploy.sh - CI/CD Final para Life Clinic POC
# v4.1.28
# - APRIMORAMENTO: Limpeza abrangente de todos os métodos HTTP (GET, POST, PUT, DELETE, PATCH, OPTIONS)
#   antes de configurar o método ANY, tornando o script ainda mais robusto e idempotente
#   contra configurações residuais ou intervenções manuais anteriores.
# - FIX CRÍTICO FINAL: Utilização do método ANY no API Gateway para cada rota.
#   Isso garante que todas as requisições HTTP (incluindo OPTIONS) sejam
#   roteadas para a Lambda, resolvendo o problema "Missing Authentication Token"
#   e permitindo que o Express/CORS na Lambda tratem o preflight corretamente.
# - Removidas todas as configurações de OPTIONS, put-integration-response e
#   put-method-response para o API Gateway, pois o método ANY combinado com
#   o Express/CORS na Lambda simplifica e corrige o fluxo.
# - FIX FINAL CRÍTICO: Corrigido erro "unbound variable" movendo a definição
#   da variável METHOD para antes de sua primeira utilização no log, garantindo
#   que ela esteja sempre definida.
# - FIX FINAL E CRÍTICO: Tratamento idempotente para 'aws lambda add-permission'
#   com `2>/dev/null || true`, resolvendo o ResourceConflictException
#   e permitindo que o script seja executado múltiplas vezes sem falhas.
# - FIX FINAL E CRÍTICO: Remoção de todas as configurações de CORS dos métodos GET/POST
#   no API Gateway (put-integration-response, put-method-response) devido ao uso
#   de Lambda Proxy Integration (AWS_PROXY). A responsabilidade pelo CORS
#   para GET/POST é da função Lambda (Express).
# - NEW: Adição da variável de ambiente CLOUDFRONT_FRONTEND_URL na Lambda
#   para que o backend Node.js possa configurar o CORS do Express dinamicamente.
# - FIX CRÍTICO: Correção da sintaxe de heredoc (revertendo &lt; para <).
# - FIX CRÍTICO: Tratamento idempotente do 'ConflictException' em `put-method` na API Gateway.
#   Reintroduzido `|| true` APENAS para os comandos `aws apigateway put-method`,
#   permitindo que o script continue e depure erros nos comandos de configuração de CORS
#   (put-integration-response, put-method-response).
# - FIX CRÍTICO: Removido '--no-cli-pager' para compatibilidade com versões mais antigas do AWS CLI.
#   Mantido o modo de depuração ativado (erros agora serão exibidos no terminal).
# - FIX: CORS automatizado na API Gateway para métodos OPTIONS, GET, POST.
#   Configura cabeçalhos Access-Control-Allow-Origin, Methods, Headers.
# - FIX: Geração do JSON do CloudFront CustomErrorResponses.ResponseCode como string.
# - FIX: Manipulação do JSON do CloudFront DistributionConfig mais robusta.
# - FIX: Sintaxe heredoc (`cat <<EOF`) verificada e ajustada para garantir `<<` literal.
# - NEW: Integração e gerenciamento do CloudFront (cria/atualiza origem, invalida cache)
# - FIX: Adicionado log [7/7] para a seção final de OUTPUT
# - FIX: Resolvido ResourceConflictException aguardando Lambda após update-function-code
# - FIX: Ajuste na função wait_for_lambda para verificar LastUpdateStatus
# - FIX: Aumenta Timeout e Memory da Lambda (verificado no update)
# - FIX: Garante inclusão da pasta 'ia/' na Lambda (verificado no zip)
# - Adiciona Bucket Policy para acesso público do S3
# - FIX: Injeção de REACT_APP_API_URL no build do frontend
# - FIX: função log()
# - FIX: criação de bucket em us-east-1
# - REST API v1 idempotente
# - Lambda handler consistente (server.handler)
# - Cleanup de permissões antigas (ajustado para melhor idempotência)
# - Compatível Free Tier

AWS_CLI=${AWS_CLI:-aws}
ZIP=${ZIP:-zip}
DEPLOY_LOG="deploy.log"

# ===== LOG =====
log() {
  echo "[INFO] $1" | tee -a "$DEPLOY_LOG"
}

# ===== PRÉ-REQUISITOS =====
command -v jq >/dev/null || { echo "[ERROR] jq não instalado. Por favor, instale-o (ex: brew install jq ou sudo apt-get install jq)"; exit 1; }

# ===== CONTEXTO AWS =====
AWS_REGION=${AWS_REGION:-$($AWS_CLI configure get region 2>/dev/null || echo "us-east-1")}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-$($AWS_CLI sts get-caller-identity --query Account --output text 2>/dev/null || echo "")}
[[ -z "$AWS_ACCOUNT_ID" ]] && { echo "[ERROR] AWS account não detectada"; exit 1; }

# ===== STACK =====
STACK_TAG="lifeclinic-poc"
LAMBDA_NAME="manual-backend-function"
LAMBDA_HANDLER="backend/index.handler"
LAMBDA_RUNTIME="nodejs18.x"
LAMBDA_ROLE_NAME="${STACK_TAG}-lambda-role"
BUCKET_NAME="lifeclinic-frontend-${AWS_ACCOUNT_ID}"
API_NAME="Life Clinic API"
STAGE_NAME="prod"

# --- CONFIGURAÇÕES DA LAMBDA ---
LAMBDA_TIMEOUT=30 # Aumentado para 30 segundos para acomodar cold start e IA Python
LAMBDA_MEMORY=512 # Aumentado para 512 MB para acomodar dependências Python
# --- FIM DAS CONFIGURAÇÕES DA LAMBDA ---

# --- CONFIGURAÇÕES CLOUDFRONT ---
CLOUDFRONT_DISTRIBUTION_ID="ER8KK22BLY7IB" # ID da sua distribuição CloudFront
CLOUDFRONT_ORIGIN_ID="S3-${BUCKET_NAME}" # ID lógico da origem no CloudFront
CLOUDFRONT_ORIGIN_DOMAIN="${BUCKET_NAME}.s3.amazonaws.com" # Domínio do bucket S3
CLOUDFRONT_URL="https://d1c2ebdnb5ff4l.cloudfront.net" # URL para output (sem barra final para CORS)
# --- FIM DAS CONFIGURAÇÕES CLOUDFRONT ---


log "Deploy iniciado — Conta: $AWS_ACCOUNT_ID | Região: $AWS_REGION"

# ===== HELPERS =====
wait_for_lambda() {
  local name=$1 elapsed=0
  while true; do
    # Consulta o estado e o status da última atualização da Lambda
    status_info=$($AWS_CLI lambda get-function --function-name "$name" --query '{State: Configuration.State, LastUpdateStatus: Configuration.LastUpdateStatus}' --output json 2>/dev/null || echo '{"State": "Pending", "LastUpdateStatus": "InProgress"}')
    state=$(echo "$status_info" | jq -r '.State')
    last_update_status=$(echo "$status_info" | jq -r '.LastUpdateStatus')

    # Considera a Lambda ativa apenas quando o estado é 'Active' E não está em 'InProgress' de uma atualização
    if [[ "$state" == "Active" && "$last_update_status" != "InProgress" ]]; then
      log "Lambda '$name' está Ativa."
      return 0
    fi
    log "Aguardando Lambda '$name' ficar Ativa (Estado: $state, Último Update: $last_update_status)... ($elapsed s)"
    [[ $elapsed -ge 300 ]] && { echo "[ERROR] Timeout: Lambda '$name' não ficou ativa após 300 segundos."; exit 1; }
    sleep 10; elapsed=$((elapsed+10))
  done
}

wait_for_cloudfront_deployment() {
  local dist_id=$1 elapsed=0
  log "Aguardando CloudFront Deployment de '$dist_id' completar..."
  while true; do
    status=$($AWS_CLI cloudfront get-distribution --id "$dist_id" --query 'Distribution.Status' --output text)
    if [[ "$status" == "Deployed" ]]; then
      log "CloudFront Deployment de '$dist_id' completo."
      return 0
    fi
    [[ $elapsed -ge 600 ]] && { echo "[ERROR] Timeout: CloudFront deployment não completou após 600 segundos."; exit 1; }
    sleep 20; elapsed=$((elapsed+20))
  done
}

cleanup_old_permissions() {
  local lambda_name=$1
  local api_id=$2

  local current_api_source_arn="arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${api_id}/*/*/*"

  policy_json=$($AWS_CLI lambda get-policy \
    --function-name "$lambda_name" \
    --query Policy \
    --output text 2>/dev/null || echo "")

  [[ -z "$policy_json" || "$policy_json" == "None" ]] && return 0

  echo "$policy_json" | jq -c '.Statement[]' | while read -r stmt; do
    sid=$(echo "$stmt" | jq -r '.Sid')

    # Extrai o SourceArn da permissão, se existir
    src_arn_from_policy=$(echo "$stmt" | jq -r '
      .Condition.ArnLike
      | to_entries[]
      | select(.key=="AWS:SourceArn")
      | .value
    ' 2>/dev/null || echo "")

    # Remove permissões cujo SourceArn não corresponda ao SourceArn da API atual
    # ou que não contenham o API_ID atual em seu Statement ID (para pegar resquícios de SIDs antigos)
    if [[ -n "$sid" && ("$src_arn_from_policy" != "$current_api_source_arn" || ! "$sid" =~ "apigw-${api_id}") ]]; then
      log "Removendo permissão Lambda antiga: $sid (SourceArn: $src_arn_from_policy, Esperado: $current_api_source_arn)"
      $AWS_CLI lambda remove-permission \
        --function-name "$lambda_name" \
        --statement-id "$sid" 2>/dev/null || true
    fi
  done
}


# ===== [1/7] S3 Bucket Setup =====
log "[1/7] S3 Bucket Setup"
if ! $AWS_CLI s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  if [[ "$AWS_REGION" == "us-east-1" ]]; then
    $AWS_CLI s3api create-bucket --bucket "$BUCKET_NAME"
  else
    $AWS_CLI s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$AWS_REGION" \
      --create-bucket-configuration LocationConstraint="$AWS_REGION"
  fi
  log "Bucket S3 '$BUCKET_NAME' criado em $AWS_REGION."
else
  log "Bucket S3 '$BUCKET_NAME' já existe em $AWS_REGION."
fi

# --- BUCKET POLICY PARA ACESSO PÚBLICO ---
log "Configurando Bucket Policy para acesso público ao S3 '$BUCKET_NAME'..."
BUCKET_POLICY_JSON=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
    }
  ]
}
EOF
)
$AWS_CLI s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy "$BUCKET_POLICY_JSON"
log "Bucket Policy configurada."
# --- FIM BUCKET POLICY ---


# Não sincronizamos o frontend aqui ainda, será feito após o build com a URL da API.

# ===== [2/7] IAM ROLE =====
log "[2/7] IAM Role"
ROLE_ARN=$($AWS_CLI iam get-role --role-name "$LAMBDA_ROLE_NAME" --query Role.Arn --output text 2>/dev/null || echo "")
if [[ "$ROLE_ARN" == "None" || -z "$ROLE_ARN" ]]; then
  log "Criando IAM Role: $LAMBDA_ROLE_NAME"
  $AWS_CLI iam create-role \
    --role-name "$LAMBDA_ROLE_NAME" \
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
  $AWS_CLI iam attach-role-policy \
    --role-name "$LAMBDA_ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
  sleep 15 # Espera para consistência eventual do IAM
  ROLE_ARN=$($AWS_CLI iam get-role --role-name "$LAMBDA_ROLE_NAME" --query Role.Arn --output text)
  log "IAM Role '$LAMBDA_ROLE_NAME' criado com ARN: $ROLE_ARN"
else
  log "IAM Role '$LAMBDA_ROLE_NAME' já existe com ARN: $ROLE_ARN"
fi


# ===== [3/7] LAMBDA =====
log "[3/7] Lambda"
# --- AJUSTE DO ZIP PARA INCLUIR A PASTA 'ia/' E MANTER ESTRUTURA PARA HANDLER ---
log "Instalando dependências do backend..."
pushd backend >/dev/null
npm ci --silent || npm install --silent # Garante que as dependências do Node.js estejam instaladas
popd >/dev/null

log "Empacotando backend e scripts de IA para Lambda..."
rm -f lambda.zip # Garante que o arquivo zip antigo seja removido

# Zips the 'backend' folder (which contains server.js and its node_modules)
# and the 'ia' folder, both from the project root.
# This creates a zip with:
# - backend/ (containing server.js and node_modules/)
# - ia/ (containing ia_matching.py)
# This structure correctly resolves path.join(__dirname, '../ia/ia_matching.py')
log "Empacotando backend e scripts de IA para Lambda..."
rm -f lambda.zip

pushd backend >/dev/null
zip -qr ../lambda.zip .
popd >/dev/null

zip -qr lambda.zip ia

# --- FIM DO AJUSTE DO ZIP ---


if $AWS_CLI lambda get-function --function-name "$LAMBDA_NAME" >/dev/null 2>&1; then
  log "Atualizando código da função Lambda existente: $LAMBDA_NAME"
  $AWS_CLI lambda update-function-code --function-name "$LAMBDA_NAME" --zip-file fileb://lambda.zip
  wait_for_lambda "$LAMBDA_NAME"
  log "Código da função Lambda '$LAMBDA_NAME' atualizado."

  log "Atualizando configuração da função Lambda: $LAMBDA_NAME (Timeout: ${LAMBDA_TIMEOUT}s, Memória: ${LAMBDA_MEMORY}MB)"
  $AWS_CLI lambda update-function-configuration \
    --function-name "$LAMBDA_NAME" \
    --handler "$LAMBDA_HANDLER" \
    --runtime "$LAMBDA_RUNTIME" \
    --timeout "$LAMBDA_TIMEOUT" \
    --memory-size "$LAMBDA_MEMORY" \
    --environment "Variables={CLOUDFRONT_FRONTEND_URL=${CLOUDFRONT_URL}}" \
    --output text
  wait_for_lambda "$LAMBDA_NAME"
  log "Configuração da função Lambda '$LAMBDA_NAME' atualizada."
else
  log "Criando nova função Lambda: $LAMBDA_NAME (Timeout: ${LAMBDA_TIMEOUT}s, Memória: ${LAMBDA_MEMORY}MB)"
  $AWS_CLI lambda create-function \
    --function-name "$LAMBDA_NAME" \
    --runtime "$LAMBDA_RUNTIME" \
    --handler "$LAMBDA_HANDLER" \
    --role "$ROLE_ARN" \
    --zip-file fileb://lambda.zip \
    --timeout "$LAMBDA_TIMEOUT" \
    --memory-size "$LAMBDA_MEMORY" \
    --environment "Variables={CLOUDFRONT_FRONTEND_URL=${CLOUDFRONT_URL}}" \
    --output text
  wait_for_lambda "$LAMBDA_NAME"
  log "Função Lambda '$LAMBDA_NAME' criada com timeout=${LAMBDA_TIMEOUT}s e memória=${LAMBDA_MEMORY}MB."
fi

LAMBDA_ARN=$($AWS_CLI lambda get-function --function-name "$LAMBDA_NAME" --query Configuration.FunctionArn --output text)


# ===== [4/7] API GATEWAY (REST v1) =====
log "[4/7] API Gateway"

API_ID=$($AWS_CLI apigateway get-rest-apis --query "items[?name=='$API_NAME'].id | [0]" --output text)
if [[ "$API_ID" == "None" || -z "$API_ID" ]]; then
  API_ID=$($AWS_CLI apigateway create-rest-api --name "$API_NAME" --query id --output text)
  log "API Gateway REST criada: $API_ID"
else
  log "API Gateway REST reutilizada: $API_ID"
fi

ROOT_ID=$($AWS_CLI apigateway get-resources --rest-api-id "$API_ID" --query "items[?path=='/'].id | [0]" --output text)
API_RES=$($AWS_CLI apigateway get-resources --rest-api-id "$API_ID" --query "items[?path=='/api'].id | [0]" --output text)

if [[ "$API_RES" == "None" || -z "$API_RES" ]]; then
  API_RES=$($AWS_CLI apigateway create-resource --rest-api-id "$API_ID" --parent-id "$ROOT_ID" --path-part api --query id --output text)
  log "Recurso /api criado com ID: $API_RES"
else
  log "Recurso /api já existe com ID: $API_RES"
fi

# Chamada para limpeza de permissões antes de adicionar as novas
log "Iniciando limpeza de permissões Lambda antigas para $LAMBDA_NAME e API $API_ID..."
cleanup_old_permissions "$LAMBDA_NAME" "$API_ID"
log "Limpeza de permissões concluída."

for route in insumos agendar recomendar; do
  RID=$($AWS_CLI apigateway get-resources --rest-api-id "$API_ID" --query "items[?path=='/api/$route'].id | [0]" --output text)
  if [[ "$RID" == "None" || -z "$RID" ]]; then
    RID=$($AWS_CLI apigateway create-resource --rest-api-id "$API_ID" --parent-id "$API_RES" --path-part "$route" --query id --output text)
    log "Recurso /api/$route criado com ID: $RID"
  else
    log "Recurso /api/$route já existe com ID: $RID"
  fi

  # APRIMORAMENTO: Limpa todos os métodos HTTP conhecidos para esta rota
  log "Removendo qualquer configuração de métodos HTTP pré-existente (GET, POST, PUT, DELETE, PATCH, OPTIONS) para /api/$route no API Gateway..."
  for m in GET POST PUT DELETE PATCH OPTIONS; do
    $AWS_CLI apigateway delete-method \
      --rest-api-id "$API_ID" \
      --resource-id "$RID" \
      --http-method "$m" \
      2>/dev/null || true # Ignora o erro se o método não existir
  done

  # Configurando método ANY para /api/$route
  log "Configurando método ANY para /api/$route..."
  $AWS_CLI apigateway put-method \
    --rest-api-id "$API_ID" \
    --resource-id "$RID" \
    --http-method ANY \
    --authorization-type NONE || true # Tratamento de ConflictException para idempotência

  log "Configurando integração para /api/$route..."
  $AWS_CLI apigateway put-integration \
    --rest-api-id "$API_ID" \
    --resource-id "$RID" \
    --http-method ANY \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations" \
    --passthrough-behavior WHEN_NO_MATCH \
    --timeout-in-millis 29000

  # Nenhuma configuração de CORS no API Gateway. A Lambda (Express) é responsável.
  # Removidas todas as chamadas put-integration-response e put-method-response para ANY

  # Usamos um statement-id fixo por API_ID e rota para idempotência real
  STATEMENT_ID="apigw-${API_ID}-${route}-permission"
  log "Adicionando permissão Lambda para /api/$route com Statement ID: $STATEMENT_ID..."
  $AWS_CLI lambda add-permission \
    --function-name "$LAMBDA_NAME" \
    --statement-id "$STATEMENT_ID" \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/*/*" \
    2>/dev/null || true # Ignora o erro se a permissão já existir

done

log "Realizando deploy do API Gateway para o estágio '$STAGE_NAME'..."
$AWS_CLI apigateway create-deployment \
  --rest-api-id "$API_ID" \
  --stage-name "$STAGE_NAME" \
  --description "Deploy automático $(date)" >/dev/null
log "Deploy do API Gateway concluído."

API_URL="https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/${STAGE_NAME}"
log "API disponível em: $API_URL"


# ===== [5/7] FRONTEND BUILD & S3 SYNC (Agora com a API_URL disponível) =====
log "[5/7] Build frontend com URL da API"
pushd frontend >/dev/null
log "Instalando dependências do frontend..."
npm ci --silent || npm install --silent # Garante que as dependências do React estejam instaladas
log "Injetando REACT_APP_API_URL e construindo frontend..."
# Exporta a variável de ambiente antes do build do React
export REACT_APP_API_URL="$API_URL"
npm run build --silent
popd >/dev/null
log "Build do frontend concluído."

log "[5/7] Sincronizando frontend com S3 bucket '$BUCKET_NAME'"
$AWS_CLI s3 sync frontend/build s3://$BUCKET_NAME/ --delete # --acl public-read REMOVIDO para compatibilidade com Bucket Object Ownership
log "Sincronização do frontend com S3 concluída."


# ===== [6/7] CLOUDFRONT CONFIGURATION AND INVALIDATION =====
log "[6/7] CloudFront Configuration and Invalidation"

# Obtém a configuração atual da distribuição CloudFront e o ETag
DIST_RESPONSE=$($AWS_CLI cloudfront get-distribution-config --id "$CLOUDFRONT_DISTRIBUTION_ID")
CURRENT_ETAG=$(echo "$DIST_RESPONSE" | jq -r '.ETag')
# Extrai *apenas* o objeto DistributionConfig que o CLI espera para update
# Isso já remove o ETag do nível superior
DISTRIBUTION_CONFIG_BASE=$(echo "$DIST_RESPONSE" | jq '.DistributionConfig')

# Monta o JSON para CustomErrorResponses separadamente para garantir tipos corretos
CUSTOM_ERROR_RESPONSES_JSON=$(cat <<EOCER
{
  "Quantity": 2,
  "Items": [
    {"ErrorCode": 404, "ResponsePagePath": "/index.html", "ResponseCode": "200", "ErrorCachingMinTTL": 10},
    {"ErrorCode": 403, "ResponsePagePath": "/index.html", "ResponseCode": "200", "ErrorCachingMinTTL": 10}
  ]
}
EOCER
)

# Adiciona/Atualiza a origem S3
S3_ORIGIN_JSON=$(cat <<EOS3O
{
  "Id": "${CLOUDFRONT_ORIGIN_ID}",
  "DomainName": "${BUCKET_NAME}.s3.amazonaws.com",
  "S3OriginConfig": {
    "OriginAccessIdentity": ""
  },
  "CustomHeaders": {"Quantity": 0, "Items": []},
  "OriginPath": ""
}
EOS3O
)

# Modifica o DISTRIBUTION_CONFIG_BASE para incluir as alterações desejadas
MODIFIED_DISTRIBUTION_CONFIG=$(echo "$DISTRIBUTION_CONFIG_BASE" | jq \
  --arg root_object "index.html" \
  --argjson custom_errors "$CUSTOM_ERROR_RESPONSES_JSON" \
  --argjson s3_origin "$S3_ORIGIN_JSON" \
  '
  .DefaultRootObject = $root_object |
  .CustomErrorResponses = $custom_errors |
  # Adiciona ou substitui a nossa origem S3 na lista de origens existentes
  .Origins.Items |= (map(select(.Id != $s3_origin.Id)) + [$s3_origin]) |
  .Origins.Quantity = (.Origins.Items | length) |
  # Garante que o DefaultCacheBehavior aponte para a nossa origem S3
  .DefaultCacheBehavior.TargetOriginId = $s3_origin.Id
  '
)


# Agora, chama o update-distribution com o objeto DistributionConfig *modificado*
$AWS_CLI cloudfront update-distribution \
  --id "$CLOUDFRONT_DISTRIBUTION_ID" \
  --distribution-config "$MODIFIED_DISTRIBUTION_CONFIG" \
  --if-match "$CURRENT_ETAG" >/dev/null
log "Distribuição CloudFront atualizada com nova origem e configurações. Aguardando deploy..."
wait_for_cloudfront_deployment "$CLOUDFRONT_DISTRIBUTION_ID"

# Invalidação do cache
log "Invalidando cache do CloudFront para garantir conteúdo atualizado..."
INVALIDATION_ID=$($AWS_CLI cloudfront create-invalidation \
  --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
  --paths "/*" \
  --query 'Invalidation.Id' --output text)
log "Invalidação de cache iniciada (ID: $INVALIDATION_ID). Pode levar alguns minutos para propagar."


# ===== [7/7] OUTPUT =====
log "[7/7] Deploy finalizado com sucesso!"
log "API: $API_URL"
log "Lambda: $LAMBDA_ARN"
log "Frontend S3 Bucket: s3://$BUCKET_NAME"
log "CloudFront URL: https://d1c2ebdnb5ff4l.cloudfront.net/" # Adicionado a URL do CloudFront para referência

rm -f lambda.zip
log "Arquivos temporários limpos."