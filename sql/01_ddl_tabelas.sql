-- =============================================================================
-- 01_ddl_tabelas.sql
-- Projeto Físico (Etapa 4) - CDSS-JuntaMed (PostgreSQL)
-- Entidades Fortes, Fracas e Relacionamentos N:M (Regras R1 a R8)
-- =============================================================================

-- 1. UNIDADE_SAUDE (Forte - Fonte: OpenDataSUS / CNES)
--    PK: co_cnes | Atributos: no_fantasia

-- 2. MEDICO (Forte - Fonte: OpenDataSUS / CNES)
--    PK: crm | Atributos: nome_medico

-- 3. LOTA (Relacionamento N:M entre MEDICO e UNIDADE_SAUDE - Regra R1)
--    PK composta: (crm, co_cnes)

-- 4. PACIENTE (Forte - Fonte: MIMIC-IV Demo)
--    PK: subject_id | Atributos: idade, alergias

-- 5. ATENDIMENTO (Forte - Regras R2, R3)
--    PK: hadm_id | FKs: subject_id (NOT NULL), crm (NOT NULL)
--    Atributos: admittime, escore_sofa (derivado)

-- 6. EXAME_CLINICO (Fraca, dependente de ATENDIMENTO - Regra R4)
--    PK composta: (hadm_id, seq_exame)
--    Atributos: itemid, item_name, valuenum, valueuom, charttime, flag_anormal

-- 7. SESSAO_JUNTA (Forte - Regra R5)
--    PK: id_sessao | FK: hadm_id (NOT NULL)
--    Atributos: indice_discordancia (derivado)

-- 8. AGENTE_IA (Forte)
--    PK: id_agente | Atributos: tipo_agente

-- 9. PARECER_AGENTE (Fraca, dependente de SESSAO_JUNTA - Regra R6)
--    PK composta: (id_sessao, num_parecer) | FK: id_agente (NOT NULL)
--    Atributos: texto_parecer

-- 10. DIRETRIZ_CLINICA (Forte - Protocolos CONITEC/SUS)
--     PK: id_diretriz | Atributos: titulo_protocolo

-- 11. FUNDAMENTA (Relacionamento N:M entre PARECER_AGENTE e DIRETRIZ_CLINICA - Regra R7)
--     PK composta: (id_sessao, num_parecer, id_diretriz)

-- 12. MEDICAMENTO (Forte - Fonte: ANVISA)
--     PK: num_registro (13 dígitos) | Atributos: nome_produto, categoria_risco_renal, situacao_registro

-- 13. PRESCREVE (Relacionamento N:M entre ATENDIMENTO e MEDICAMENTO - Regra R8)
--     PK composta: (hadm_id, num_registro, data_prescricao)
--     Atributos: posologia, alerta_renal (derivado), data_prescricao
