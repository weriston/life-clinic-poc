# Diagramas da Arquitetura - Life Clinic POC

## Diagrama de Contexto da Solução da Aplicação
Fluxo high-level da plataforma: Jornada do paciente, módulos (agenda, CRM, prontuario) e IA para matching de especialistas (alinhado ao PDF do desafio).

```mermaid
graph TD
    A[Paciente] --> B[Login e Registro Frontend React]
    B --> C[Agenda Online Agendar Consulta]
    C --> D[IA Matching Recomendar Especialista Python Scikit]
    D --> E[CRM para Medico Notificacao Backend Node.js]
    E --> F[Prontuario Digital Armazenar Dados Seguros DB]
    F --> G[Smart Insumos Gerenciar Medicamentos]
    G --> H[Integracao Externa EMR e Pagamentos API]
    H --> I[Output Relatório AI para Decisão]
    style A fill:#e1f5fe
    style D fill:#f3e5f5
    style I fill:#e8f5e8
```
### Diagrama de Infraestrutura (AWS)
Arquitetura em cloud: Frontend no S3, Backend/IA no Lambda, DB no RDS, com seguranca LGPD.

```mermaid
graph LR
    A[Frontend React App] --> B[S3 Bucket Hosting Estático]
    C[Backend Node.js APIs] --> D[Lambda Execução Serverless]
    E[IA Python Scripts] --> F[Lambda Processamento]
    G[Database Dados Pacientes] --> H[RDS PostgreSQL Armazenamento Seguro]
    I[Seguranca LGPD] --> J[IAM Roles VPC Encryption]
    B --> K[CloudFront CDN Distribuição]
    D --> K
    F --> K
    H --> K
    style J fill:#ffebee
    style K fill:#e3f2fd
```
