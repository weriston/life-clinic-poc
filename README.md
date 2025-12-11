# Life Clinic POC

Plataforma digital para tratamento de infertilidade com IA para rede de acolhimento inteligente. Este é um POC (Proof of Concept) completo, desenvolvido buscando atender ao escopo definido. Foco em inovação "Lovable" (IA simples e escalável), web-first, compliant LGPD (dados mock anonimizados).

# Deploy & Arquitetura (POC)

## Overview
POC serverless com:
- Frontend React hospedado em S3 (origin privada)
- CloudFront (HTTPS) distribuindo frontend
- API Gateway (REST) + Lambda (Node.js) como backend
- IAM roles mínimos, logs em CloudWatch

## Pré-requisitos
- AWS CLI v2 configurado (`aws configure`)
- jq, zip, openssl
- Node.js / npm (para build frontend)

## Comandos principais
- Deploy/update: `bash deploy.sh`
- Destroy: `bash deploy.sh --destroy --force`

## Segurança / boas práticas explicadas
- Bucket privado, apenas CloudFront lê via OAI
- IAM role com policy mínima (`AWSLambdaBasicExecutionRole`)
- Não commit de credenciais no repositório (`.gitignore` pronto)
- Variáveis sensíveis detectadas em runtime via `aws sts get-caller-identity`

## Slides / Diagrama (apresentação)
- Diagrama de contexto (usuário -> CloudFront -> API -> Lambda -> IA)
- Diagrama de infra (S3, CloudFront, API Gateway, Lambda, IAM, CloudWatch)
- Argumente: custo baixo, facilidade de deploy, segurança (OAI), observabilidade.

## Dicas para a entrevista
- Demonstre a capacidade de automação (deploy.sh)
- Explique tradeoffs: CloudFront aumenta custo levemente mas entrega HTTPS e segurança; sem CloudFront, S3 website é HTTP only.
- Mostre o README + scripts no GitHub: é prova de trabalho reprodutível.


Autor: Weriston Castro Alves | Data: Dezembro 2025 | Contato: weristonsp@gmail.com para dúvidas.
