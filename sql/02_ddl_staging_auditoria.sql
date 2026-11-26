-- =============================================================================
-- 02_ddl_staging_auditoria.sql
-- Camada de Staging (STG_*) e Log de Auditoria para Ingestão em Duplo Estágio
-- =============================================================================

DROP TABLE IF EXISTS etl_audit_log CASCADE;
DROP TABLE IF EXISTS stg_mimic_labevents CASCADE;
DROP TABLE IF EXISTS stg_mimic_admissions CASCADE;
DROP TABLE IF EXISTS stg_mimic_patients CASCADE;
DROP TABLE IF EXISTS stg_anvisa_medicamentos CASCADE;
DROP TABLE IF EXISTS stg_cnes_medicos CASCADE;
DROP TABLE IF EXISTS stg_cnes_unidades CASCADE;

-- 1. Staging: OpenDataSUS / CNES (Unidades de Saúde)
CREATE TABLE stg_cnes_unidades (
    co_cnes TEXT,
    no_fantasia TEXT,
    loaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. Staging: OpenDataSUS / CNES (Médicos e Vínculo de Lotação)
CREATE TABLE stg_cnes_medicos (
    crm TEXT,
    nome_medico TEXT,
    co_cnes TEXT,
    loaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3. Staging: ANVISA (Medicamentos)
CREATE TABLE stg_anvisa_medicamentos (
    num_registro TEXT,
    nome_produto TEXT,
    categoria_risco_renal TEXT,
    situacao_registro TEXT,
    loaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4. Staging: MIMIC-IV Demo (Pacientes)
CREATE TABLE stg_mimic_patients (
    subject_id TEXT,
    idade TEXT,
    alergias TEXT,
    loaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 5. Staging: MIMIC-IV Demo (Atendimentos / Admissões)
CREATE TABLE stg_mimic_admissions (
    hadm_id TEXT,
    subject_id TEXT,
    crm TEXT,
    admittime TEXT,
    escore_sofa TEXT,
    loaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 6. Staging: MIMIC-IV Demo (Exames Laboratoriais)
CREATE TABLE stg_mimic_labevents (
    hadm_id TEXT,
    itemid TEXT,
    item_name TEXT,
    valuenum TEXT,
    valueuom TEXT,
    charttime TEXT,
    flag_anormal TEXT,
    loaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 7. Log de Auditoria de ETL (registros rejeitados por nulos/inválidos)
CREATE TABLE etl_audit_log (
    id_log SERIAL PRIMARY KEY,
    fonte VARCHAR(50) NOT NULL,
    registro_bruto TEXT NOT NULL,
    motivo_rejeicao TEXT NOT NULL,
    data_ocorrencia TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);