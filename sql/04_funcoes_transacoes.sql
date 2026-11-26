-- =============================================================================
-- 04_funcoes_transacoes.sql
-- Catálogo de Funções (FN-01 a FN-10) e Blocos Transacionais (Etapa 3)
-- =============================================================================

-- Consultas (Leitura):
-- - FN-01: autenticar_e_consultar_corpo_clinico(crm, co_cnes)
-- - FN-03: consultar_historico_paciente(subject_id)
-- - FN-05: listar_exames_criticos_atendimento(hadm_id, apenas_anormais, limite) [Spec 1]
-- - FN-08: consultar_deliberacoes_junta(id_sessao)
-- - FN-09: buscar_diretrizes_clinicas_ativas(termo_busca)

-- Gravações e Transações Críticas:
-- - FN-02: abrir_atendimento_clinico(subject_id, crm, co_cnes)
-- - FN-04: registrar_resultado_exame(hadm_id, valuenum, ...) [Serialização de seq_exame]
-- - FN-06: convocar_junta_deliberativa(...) [Spec 2 - Atomicidade estrita / ROLLBACK total]
-- - FN-07: prescrever_medicamento_com_alerta(hadm_id, num_registro, posologia) [Spec 3 - FOR SHARE]
-- - FN-10: calcular_escore_gravidade_sofa(hadm_id)
