-- =============================================================================
-- 04_funcoes_transacoes.sql
-- Catálogo de Funções (FN-01 a FN-10), Triggers e Blocos Transacionais (Etapa 3)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- TRIGGER DE INTEGRIDADE: Regra R7 (Todo PARECER_AGENTE deve ter >= 1 DIRETRIZ)
-- Validada apenas no COMMIT (DEFERRABLE INITIALLY DEFERRED) para permitir o
-- INSERT em parecer_agente seguido do INSERT em fundamenta na mesma transação.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_validar_parecer_fundamentado()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM fundamenta f
        WHERE f.id_sessao = NEW.id_sessao
          AND f.num_parecer = NEW.num_parecer
    ) THEN
        RAISE EXCEPTION 'Violação da Regra R7: O parecer (sessão %, parecer %) deve ser fundamentado por pelo menos uma diretriz clínica.',
            NEW.id_sessao, NEW.num_parecer;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_valida_r7_parecer_fundamentado ON parecer_agente;
CREATE CONSTRAINT TRIGGER trg_valida_r7_parecer_fundamentado
    AFTER INSERT ON parecer_agente
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_validar_parecer_fundamentado();

-- -----------------------------------------------------------------------------
-- FN-01: autenticar_e_consultar_corpo_clinico(crm, co_cnes)
-- Verifica vínculo de lotação (Regra R1) e retorna dados do médico e unidade.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION autenticar_e_consultar_corpo_clinico(
    p_crm VARCHAR(20),
    p_co_cnes VARCHAR(10)
)
RETURNS TABLE (
    crm VARCHAR(20),
    nome_medico VARCHAR(150),
    co_cnes VARCHAR(10),
    no_fantasia VARCHAR(200)
) AS $$
BEGIN
    RETURN QUERY
    SELECT m.crm, m.nome_medico, u.co_cnes, u.no_fantasia
    FROM lota l
    JOIN medico m ON m.crm = l.crm
    JOIN unidade_saude u ON u.co_cnes = l.co_cnes
    WHERE l.crm = p_crm
      AND l.co_cnes = p_co_cnes;
END;
$$ LANGUAGE plpgsql STABLE;

-- -----------------------------------------------------------------------------
-- FN-02: abrir_atendimento_clinico(hadm_id, subject_id, crm, co_cnes, admittime)
-- Valida lotação do médico (R1) e abre novo atendimento (R2, R3).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION abrir_atendimento_clinico(
    p_hadm_id INT,
    p_subject_id INT,
    p_crm VARCHAR(20),
    p_co_cnes VARCHAR(10),
    p_admittime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
RETURNS INT AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM lota WHERE crm = p_crm AND co_cnes = p_co_cnes
    ) THEN
        RAISE EXCEPTION 'Violação da Regra R1: Médico CRM % não está lotado na unidade CNES %.', p_crm, p_co_cnes;
    END IF;

    INSERT INTO atendimento (hadm_id, subject_id, crm, admittime, escore_sofa)
    VALUES (p_hadm_id, p_subject_id, p_crm, p_admittime, 0);

    RETURN p_hadm_id;
END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------------------------------
-- FN-03: consultar_historico_paciente(subject_id)
-- Retorna histórico clínico consolidado de atendimentos do paciente.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION consultar_historico_paciente(
    p_subject_id INT
)
RETURNS TABLE (
    subject_id INT,
    idade INT,
    alergias TEXT[],
    hadm_id INT,
    admittime TIMESTAMP,
    escore_sofa INT,
    crm_responsavel VARCHAR(20),
    nome_medico VARCHAR(150)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.subject_id,
        p.idade,
        p.alergias,
        a.hadm_id,
        a.admittime,
        a.escore_sofa,
        m.crm,
        m.nome_medico
    FROM paciente p
    LEFT JOIN atendimento a ON a.subject_id = p.subject_id
    LEFT JOIN medico m ON m.crm = a.crm
    WHERE p.subject_id = p_subject_id
    ORDER BY a.admittime DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- -----------------------------------------------------------------------------
-- FN-04: registrar_resultado_exame(...)
-- Serializa a geração da chave parcial seq_exame (Regra R4) travando o
-- atendimento pai com FOR UPDATE para evitar condição de corrida.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION registrar_resultado_exame(
    p_hadm_id INT,
    p_itemid INT,
    p_item_name VARCHAR(150),
    p_valuenum NUMERIC(10, 3),
    p_valueuom VARCHAR(30),
    p_charttime TIMESTAMP,
    p_flag_anormal BOOLEAN DEFAULT FALSE
)
RETURNS INT AS $$
DECLARE
    v_next_seq INT;
BEGIN
    -- Trava a linha do atendimento pai para serializar a contagem de seq_exame
    PERFORM 1 FROM atendimento WHERE hadm_id = p_hadm_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Atendimento hadm_id % não encontrado.', p_hadm_id;
    END IF;

    SELECT COALESCE(MAX(seq_exame), 0) + 1
      INTO v_next_seq
      FROM exame_clinico
     WHERE hadm_id = p_hadm_id;

    INSERT INTO exame_clinico (
        hadm_id, seq_exame, itemid, item_name, valuenum, valueuom, charttime, flag_anormal
    )
    VALUES (
        p_hadm_id, v_next_seq, p_itemid, p_item_name, p_valuenum, p_valueuom, p_charttime, p_flag_anormal
    );

    RETURN v_next_seq;
END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------------------------------
-- FN-05 [Spec 1]: listar_exames_criticos_atendimento(hadm_id, apenas_anormais, limite)
-- Aproveita o índice composto B-Tree (hadm_id, flag_anormal, charttime DESC).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION listar_exames_criticos_atendimento(
    p_hadm_id INT,
    p_apenas_anormais BOOLEAN DEFAULT TRUE,
    p_limite INT DEFAULT 50
)
RETURNS TABLE (
    seq_exame INT,
    itemid INT,
    item_name VARCHAR(150),
    valuenum NUMERIC(10, 3),
    valueuom VARCHAR(30),
    charttime TIMESTAMP,
    flag_anormal BOOLEAN
) AS $$
BEGIN
    IF p_apenas_anormais THEN
        RETURN QUERY
        SELECT e.seq_exame, e.itemid, e.item_name, e.valuenum, e.valueuom, e.charttime, e.flag_anormal
        FROM exame_clinico e
        WHERE e.hadm_id = p_hadm_id
          AND e.flag_anormal = TRUE
        ORDER BY e.charttime DESC
        LIMIT p_limite;
    ELSE
        RETURN QUERY
        SELECT e.seq_exame, e.itemid, e.item_name, e.valuenum, e.valueuom, e.charttime, e.flag_anormal
        FROM exame_clinico e
        WHERE e.hadm_id = p_hadm_id
        ORDER BY e.charttime DESC
        LIMIT p_limite;
    END IF;
END;
$$ LANGUAGE plpgsql STABLE;

-- -----------------------------------------------------------------------------
-- FN-06 [Spec 2]: convocar_junta_deliberativa(hadm_id, indice_discordancia, pareceres_json)
-- Atomicidade estrita: cria sessão, pareceres (R6) e fundamentação (R7).
-- Se qualquer parecer vier sem diretriz ou falhar, toda a operação sofre ROLLBACK.
-- Formato esperado de p_pareceres (JSONB):
--   [{"id_agente": 1, "texto_parecer": "...", "diretrizes": [1, 2]}]
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION convocar_junta_deliberativa(
    p_hadm_id INT,
    p_indice_discordancia NUMERIC(5, 2),
    p_pareceres JSONB
)
RETURNS INT AS $$
DECLARE
    v_id_sessao INT;
    v_num_parecer INT := 0;
    v_item JSONB;
    v_id_diretriz INT;
BEGIN
    IF p_pareceres IS NULL OR jsonb_typeof(p_pareceres) <> 'array' OR jsonb_array_length(p_pareceres) = 0 THEN
        RAISE EXCEPTION 'A junta deliberativa exige ao menos um parecer de agente.';
    END IF;

    INSERT INTO sessao_junta (hadm_id, indice_discordancia)
    VALUES (p_hadm_id, p_indice_discordancia)
    RETURNING id_sessao INTO v_id_sessao;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_pareceres)
    LOOP
        v_num_parecer := v_num_parecer + 1;

        IF (v_item->'diretrizes') IS NULL
           OR jsonb_typeof(v_item->'diretrizes') <> 'array'
           OR jsonb_array_length(v_item->'diretrizes') = 0 THEN
            RAISE EXCEPTION 'Violação da Regra R7: Parecer % sem diretrizes clínicas vinculadas.', v_num_parecer;
        END IF;

        INSERT INTO parecer_agente (id_sessao, num_parecer, id_agente, texto_parecer)
        VALUES (
            v_id_sessao,
            v_num_parecer,
            (v_item->>'id_agente')::INT,
            v_item->>'texto_parecer'
        );

        FOR v_id_diretriz IN
            SELECT (elem)::INT FROM jsonb_array_elements_text(v_item->'diretrizes') AS elem
        LOOP
            INSERT INTO fundamenta (id_sessao, num_parecer, id_diretriz)
            VALUES (v_id_sessao, v_num_parecer, v_id_diretriz);
        END LOOP;
    END LOOP;

    RETURN v_id_sessao;
END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------------------------------
-- FN-07 [Spec 3]: prescrever_medicamento_com_alerta(hadm_id, num_registro, posologia)
-- Usa FOR SHARE no medicamento para garantir leitura consistente da situação
-- regulatória (ANVISA) e calcula automaticamente alerta_renal (Regra R8).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION prescrever_medicamento_com_alerta(
    p_hadm_id INT,
    p_num_registro VARCHAR(13),
    p_posologia VARCHAR(200)
)
RETURNS BOOLEAN AS $$
DECLARE
    v_situacao VARCHAR(50);
    v_risco_renal VARCHAR(50);
    v_tem_exame_renal_alterado BOOLEAN;
    v_alerta_renal BOOLEAN := FALSE;
BEGIN
    SELECT situacao_registro, categoria_risco_renal
      INTO v_situacao, v_risco_renal
      FROM medicamento
     WHERE num_registro = p_num_registro
       FOR SHARE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Medicamento com registro ANVISA % não encontrado.', p_num_registro;
    END IF;

    IF UPPER(v_situacao) <> 'VALIDO' THEN
        RAISE EXCEPTION 'Prescrição bloqueada: Medicamento % está com situação %.', p_num_registro, v_situacao;
    END IF;

    -- Verifica se o atendimento possui exame renal (ex.: Creatinina) alterado
    SELECT EXISTS (
        SELECT 1
        FROM exame_clinico
        WHERE hadm_id = p_hadm_id
          AND flag_anormal = TRUE
          AND item_name ILIKE '%creatinin%'
    ) INTO v_tem_exame_renal_alterado;

    IF UPPER(v_risco_renal) IN ('ALTO', 'MODERADO') AND v_tem_exame_renal_alterado THEN
        v_alerta_renal := TRUE;
    END IF;

    INSERT INTO prescreve (hadm_id, num_registro, posologia, alerta_renal)
    VALUES (p_hadm_id, p_num_registro, p_posologia, v_alerta_renal);

    RETURN v_alerta_renal;
END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------------------------------
-- FN-08: consultar_deliberacoes_junta(id_sessao)
-- Retorna os pareceres dos agentes e as diretrizes CONITEC/SUS que os fundamentam.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION consultar_deliberacoes_junta(
    p_id_sessao INT
)
RETURNS TABLE (
    id_sessao INT,
    hadm_id INT,
    indice_discordancia NUMERIC(5, 2),
    num_parecer INT,
    tipo_agente VARCHAR(60),
    texto_parecer TEXT,
    diretrizes_citadas TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.id_sessao,
        s.hadm_id,
        s.indice_discordancia,
        pa.num_parecer,
        ag.tipo_agente,
        pa.texto_parecer,
        STRING_AGG(d.titulo_protocolo, ' | ' ORDER BY d.id_diretriz) AS diretrizes_citadas
    FROM sessao_junta s
    JOIN parecer_agente pa ON pa.id_sessao = s.id_sessao
    JOIN agente_ia ag ON ag.id_agente = pa.id_agente
    JOIN fundamenta f ON f.id_sessao = pa.id_sessao AND f.num_parecer = pa.num_parecer
    JOIN diretriz_clinica d ON d.id_diretriz = f.id_diretriz
    WHERE s.id_sessao = p_id_sessao
    GROUP BY s.id_sessao, s.hadm_id, s.indice_discordancia, pa.num_parecer, ag.tipo_agente, pa.texto_parecer
    ORDER BY pa.num_parecer;
END;
$$ LANGUAGE plpgsql STABLE;

-- -----------------------------------------------------------------------------
-- FN-09: buscar_diretrizes_clinicas_ativas(termo_busca)
-- Busca textual (case-insensitive) nos protocolos CONITEC/SUS.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION buscar_diretrizes_clinicas_ativas(
    p_termo_busca TEXT
)
RETURNS TABLE (
    id_diretriz INT,
    titulo_protocolo VARCHAR(250)
) AS $$
BEGIN
    RETURN QUERY
    SELECT d.id_diretriz, d.titulo_protocolo
    FROM diretriz_clinica d
    WHERE d.titulo_protocolo ILIKE '%' || COALESCE(p_termo_busca, '') || '%'
    ORDER BY d.id_diretriz;
END;
$$ LANGUAGE plpgsql STABLE;

-- -----------------------------------------------------------------------------
-- FN-10: calcular_escore_gravidade_sofa(hadm_id)
-- Calcula escore derivado (0 a 24) a partir dos exames anormais do atendimento
-- e atualiza atendimento.escore_sofa.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calcular_escore_gravidade_sofa(
    p_hadm_id INT
)
RETURNS INT AS $$
DECLARE
    v_anormais INT;
    v_novo_sofa INT;
BEGIN
    SELECT COUNT(*)
      INTO v_anormais
      FROM exame_clinico
     WHERE hadm_id = p_hadm_id
       AND flag_anormal = TRUE;

    -- Regra simplificada de pontuação (limitada ao teto clínico 24)
    v_novo_sofa := LEAST(24, v_anormais * 2);

    UPDATE atendimento
       SET escore_sofa = v_novo_sofa
     WHERE hadm_id = p_hadm_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Atendimento hadm_id % não encontrado.', p_hadm_id;
    END IF;

    RETURN v_novo_sofa;
END;
$$ LANGUAGE plpgsql;