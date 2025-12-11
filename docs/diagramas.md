%% Context Diagram - Life Clinic POC
graph LR
  User["Usuário (Browser)"]
  CF["CloudFront (HTTPS)"]
  S3["S3 Bucket (static assets) - private"]
  API["API Gateway (REST)"]
  Lambda["Lambda - manual-backend-function"]
  IA["IA / IA local (mock)"]
  CW["CloudWatch Logs"]

  User -->|HTTPS| CF
  CF -->|GET/HEAD| S3
  User -->|AJAX POST /api/recomendar| API
  API -->|Invoke| Lambda
  Lambda -->|logs| CW
  Lambda -->|call or exec| IA
