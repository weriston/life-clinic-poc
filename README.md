# Life Clinic POC - Desafio Líder de Soluções (Colibri)

Plataforma digital para tratamento de infertilidade com IA para rede de acolhimento inteligente. Este é um POC (Proof of Concept) completo, desenvolvido buscando atender ao escopo definido. Foco em inovação "Lovable" (IA simples e escalável), web-first, compliant LGPD (dados mock anonimizados).

## Entregáveis do Desafio
1. **Diagramas**: Contexto da solução e infraestrutura (Mermaid interativo em /docs/diagramas.md).
2. **App com IA**: MVP funcional com matching de especialistas (React frontend, Node backend, Python/Scikit-learn IA).
3. **Cloud Infra**: Deploy em AWS (S3 para hosting, Lambda para backend/IA – via Console web).
4. **Demo Rodando**: URL S3 [adicionar após deploy], vídeo demo [link Loom/YouTube, 1 min mostrando fluxo].

## Stack Técnica
- **Frontend**: React (responsivo, form para input paciente).
- **Backend**: Node.js (API Express para chamar IA).
- **IA**: Python com Scikit-learn (cosine similarity para matching inteligente de especialistas em infertilidade, ex.: FIV, hormônios).
- **Infra**: AWS S3 (hosting estático) + Lambda (serverless para IA/backend).
- **Banco**: RDS PostgreSQL mock (local para POC; dados sensíveis não armazenados).
- **Ferramentas**: Mermaid para diagramas, npm/pip para deps.

Alinhamento ao PDF: Módulos (agenda online, CRM médico, prontuário digital, smart insumos), integrações (EMR, pagamentos), foco em Rede de Acolhimento Inteligente e LGPD (encryption simulado).

## Como Rodar Localmente (Teste Rápido)
1. Clone o repo: `git clone https://github.com/seuusuario/life-clinic-poc.git && cd life-clinic-poc`.
2. **Instale Dependências**:
   - Backend: `cd backend; npm init -y; npm install express cors`.
   - Frontend: `cd ../frontend; npm init -y; npm install react react-dom react-scripts`.
   - IA: `pip3 install scikit-learn numpy` (global ou virtualenv).
3. **Rode Backend**: `cd backend; node server.js` (localhost:3001).
4. **Rode Frontend**: `cd frontend; npx react-scripts start` (localhost:3000).
5. **Teste IA**: `python3 ia/ia_matching.py 30 SP FIV` (output: "Dr. Silva - Especialista em FIV em SP (similaridade: 0.95)").
6. **Demo Local**: Abra localhost:3000, input (idade 30, SP, FIV) > Submit > Veja recomendação IA.

Exemplo de Fluxo: Paciente agenda consulta > IA recomenda especialista > Notificação CRM > Prontuário atualizado.

## Deploy em AWS (Via Console Web)
Devido suporte macOS antigo, use Console (sem CLI):
1. **S3 para Frontend**: Console > S3 > Create bucket (nome único, us-east-1) > Enable static hosting > Policy pública > Upload pasta build (npm run build no frontend).
2. **Lambda para Backend/IA**: Console > Lambda > Create function (Node.js 18.x) > Upload ZIP (zip -r server.zip backend ia node_modules) > Handler: server.handler.
3. **API Gateway**: Crie REST API > Integre Lambda > Deploy > Use invoke URL no fetch do React.
4. **URL Final**: S3 endpoint (ex.: http://bucket.s3-website-us-east-1.amazonaws.com).
5. **Custo**: 0 para POC baixo tráfego (free-tier).

Detalhes em /docs/deploy.md (adicionar se precisar).

## Inovação e Destaques
- **IA Lovable**: Matching baseado em similaridade vetorial (Scikit-learn) – fácil expandir para ML avançado (ex.: Hugging Face).
- **LGPD Compliant**: Dados mock, sem storage real; encryption em infra (VPC/IAM).
- **Escalabilidade**: Serverless (Lambda auto-scale), web-first (React responsivo).
- **Próximos**: Integração RDS real, chat IA, analytics.

## Diagramas
- Contexto da Solução: Jornada paciente → IA → médico (/docs/diagramas.md).
- Infraestrutura: AWS free-tier layout.

Autor: Weriston Castro Alves | Data: Dezembro 2025 | Contato: weristonsp@gmail.com para dúvidas.
