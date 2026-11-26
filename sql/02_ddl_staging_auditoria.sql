-- =============================================================================
-- 02_ddl_staging_auditoria.sql
-- Camada de Staging (STG_*) e Log de Auditoria para Ingestão em Duplo Estágio
-- =============================================================================

-- Tabelas de Staging (sem FKs rígidas para permitir sanitização e deduplicação):
-- - stg_cnes_unidades
-- - stg_cnes_medicos
-- - stg_anvisa_medicamentos
-- - stg_mimic_patients
-- - stg_mimic_admissions
-- - stg_mimic_labevents

-- Tabela de Log de Auditoria de ETL:
-- - etl_audit_log (id_log, fonte, registro_bruto, motivo_rejeicao, data_ocorrencia)
--   Registra linhas rejeitadas por campos essenciais vazios/nulos (pág. 17).
