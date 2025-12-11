%% Infrastructure Diagram - Life Clinic POC
flowchart LR
  subgraph AWS [AWS - us-east-1]
    direction TB
    S3Bucket[S3: lifeclinic-frontend-<acct>]
    CF[CloudFront Distribution]
    OAI[Origin Access Identity]
    APIGW[API Gateway (REST)]
    LambdaFunc[Lambda: manual-backend-function]
    IAMRole[IAM Role: lambda-role]
    CW[CloudWatch Logs]
    ACM[ACM Certificate (optional)]
  end

  User -->|https| CF
  CF -->|s3 origin (private)| S3Bucket
  CF -->|forward /api/*| APIGW
  APIGW --> LambdaFunc
  LambdaFunc --> CW
  LambdaFunc -->|assume role| IAMRole
  CF -. optional .-> ACM
  S3Bucket -. policy allows OAI .-> OAI
