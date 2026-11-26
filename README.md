# CDSS-JuntaMed

Sistema de Suporte à Decisão Clínica e Auditoria Prescritiva com Junta Médica Multiagente (IMD0401 - Banco de Dados / UFRN).

## Visão Geral
O projeto integra três fontes públicas de dados clínicos e cadastrais (**OpenDataSUS/CNES**, **ANVISA** e **PhysioNet MIMIC-IV Demo**) em um SGBD relacional (PostgreSQL) com arquitetura de ingestão em duplo estágio (`STG_*` -> Produção) e suporte transacional para uma Junta Médica Virtual.

## Estrutura de Pastas

```text
cdss-juntamed/
├── README.md                  # Documentação principal e roteiro de execução
├── requirements.txt           # Dependências Python para ETL e testes
├── .env                       # Modelo de variáveis de ambiente (banco e APIs)
├── .gitignore                 # Arquivos ignorados (dados brutos, .env, venv)
├── data/
│   ├── raw/                   # Dados brutos baixados (ANVISA CSV, MIMIC-IV CSV, CNES JSON)
│   └── processed/             # Dados sanitizados prontos para carga
├── specs/                     # Especificações YAML das operações críticas 
│   ├── spec_01_listar_exames_criticos.yaml
│   ├── spec_02_convocar_junta_deliberativa.yaml
│   └── spec_03_prescrever_medicamento_com_alerta.yaml
├── sql/                      # Scripts SQL do projeto físico (Etapa 4)
│   ├── 01_ddl_tabelas.sql
│   ├── 02_ddl_staging_auditoria.sql
│   ├── 03_indices.sql
│   ├── 04_funcoes_transacoes.sql
│   └── 05_seed_inicial.sql
```

## O que é necessário para executar o trabalho

### 1. Ferramentas e Ambiente
- **PostgreSQL 15+** (recomendado pelo suporte nativo a `INSERT ... ON CONFLICT DO UPDATE`, `FOR SHARE`, funções de janela `ROW_NUMBER()` e índices B-Tree com ordenação `DESC`).
- **Python 3.10+** com ambiente virtual (`venv`).
- **Cliente SQL** (DBeaver, pgAdmin ou `psql`).

### 2. Fontes de Dados Públicas (baixar para `data/raw/`)
1. **OpenDataSUS / CNES** (Estabelecimentos e corpo clínico):
   - API REST: `https://apidadosabertos.saude.gov.br/cnes`
   - Portal: `https://opendatasus.saude.gov.br`
2. **Portal de Dados Abertos da ANVISA** (Medicamentos e princípios ativos):
   - Portal: `https://dados.gov.br` (CSV separado por `;`, encoding UTF-8/ISO-8859-1).
3. **PhysioNet MIMIC-IV Clinical Database Demo v2.2** (Pacientes, internações e exames):
   - Portal: `https://physionet.org/content/mimic-iv-demo/` (`admissions.csv`, `patients.csv`, `labevents.csv`).

### 3. Dados Iniciais de Governança
- Cadastro inicial de **Diretrizes Clínicas Oficiais (CONITEC/SUS)** para atender à regra **R7**.
- Cadastro inicial dos **Agentes de IA** (`AGENTE_IA`) para atender à regra **R6**.

## Ordem de Execução Sugerida
1. Configurar `.env` a partir de `.env.example` e instalar dependências:
   ```bash
   python -m venv .venv
   pip install -r requirements.txt
   ```
2. Criar o banco no PostgreSQL e rodar os scripts de `sql/` na ordem numérica (`01` -> `05`).
3. Baixar os datasets públicos para `data/raw/` e executar os scripts de `etl/`.
4. Validar as 10 funções do catálogo (`01` a `10`) e os cenários de concorrência/rollback das Specs (`FN-04`, `FN-06`, `FN-07`).
