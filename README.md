# Life Clinic — Proof of Concept (POC)

Este repositório contém uma prova de conceito desenvolvida para demonstrar arquitetura, engenharia de software, boas práticas em cloud e integração com IA.  
O objetivo é materializar uma aplicação web simples, porém completa, contemplando:

- Frontend Web responsivo
- Backend serverless
- Integração com IA (mock)
- Infraestrutura totalmente automatizada via CLI
- Documentação técnica e diagramas

---

## 🚀 Arquitetura Geral da Solução

A aplicação segue uma arquitetura **serverless**, priorizando baixo custo, segurança e simplicidade de operação.

### Componentes
- **S3** → hospeda o frontend React (arquivos estáticos)
- **CloudFront** → distribuição global, HTTPS, cache e segurança
- **API Gateway (REST)** → expõe o endpoint `/api/recomendar`
- **AWS Lambda (Node.js)** → backend sem servidores
- **IAM** → controle de permissões mínimo
- **CloudWatch Logs** → observabilidade do backend

### Diagrama de Contexto
![Context Diagram](docs/context-diagram.png)

### Diagrama de Infraestrutura
![Infra Diagram](docs/infra-diagram.png)

---

## 🧩 Fluxo da Aplicação

1. O usuário acessa o domínio HTTPS do CloudFront  
2. CloudFront busca os arquivos estáticos no S3 (origin privada protegida por OAI)  
3. O frontend comunica via `POST /api/recomendar` com o API Gateway  
4. API Gateway invoca a Lambda  
5. A Lambda processa a recomendação com um modelo IA simplificado (mock)  
6. O resultado retorna ao navegador

---

## 🛠 Tecnologias Utilizadas

| Camada | Tecnologia |
|--------|------------|
| Frontend | React (create-react-app) |
| Backend | Node.js 18 (Lambda) |
| API | AWS API Gateway |
| Infra | AWS CLI, CloudFormation implícito, bash scripts |
| Observabilidade | CloudWatch Logs |
| Segurança | IAM Least Privilege + OAI |

---

## 🔐 Segurança & Boas Práticas

- **Bucket S3 privado**: não exposto publicamente.  
- **CloudFront + OAI**: apenas CloudFront acessa o S3.  
- **HTTPS obrigatório**: melhoria para produção, mesmo em free-tier.  
- **IAM mínimo**: Lambda usa apenas `AWSLambdaBasicExecutionRole`.  
- **Sem credenciais no repo**: `.gitignore` otimizado.  
- **Sem exposição de AWS Account ID**: scripts carregam o valor dinamicamente via `aws sts get-caller-identity`.

---

## 📦 Deploy Automático

O arquivo `deploy.sh` executa:

1. Build do frontend  
2. Criação e configuração do bucket S3  
3. Upload dos artefatos do frontend  
4. Criação do pacote da Lambda  
5. Criação do API Gateway  
6. Deploy automático da infraestrutura  

### Comando principal:

```bash
bash deploy.sh

```
### Destruir tudo:

```bash
bash deploy.sh --destroy --force

```

### Rodando Localmente:
```bash
cd frontend
npm install
npm start

```

### Backend (mock)

```bash
cd backend
node server.js

```

## 📊 Custos Estimados (Free Tier Friendly)

- ** S3: centavos/mês
- ** CloudFront: gratuito no primeiro TB
- ** Lambda: 1M execuções gratuitas
- ** API Gateway: gratuito até certo volume
- ** Custo total: praticamente zero durante o POC.

### Estrutura do repositório

```bash
/backend
/frontend
/docs
deploy.sh
.gitignore
README.md

```

### Autor
Weriston Castro Alves