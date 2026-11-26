-- =============================================================================
-- 01_ddl_tabelas.sql
-- Projeto Físico (Etapa 4) - CDSS-JuntaMed (PostgreSQL)
-- Entidades Fortes, Fracas e Relacionamentos N:M (Regras R1 a R8)
-- =============================================================================

-- Limpeza em ordem reversa de dependência (permite reexecução segura)
DROP TABLE IF EXISTS prescreve CASCADE;
DROP TABLE IF EXISTS medicamento CASCADE;
DROP TABLE IF EXISTS fundamenta CASCADE;
DROP TABLE IF EXISTS diretriz_clinica CASCADE;
DROP TABLE IF EXISTS parecer_agente CASCADE;
DROP TABLE IF EXISTS agente_ia CASCADE;
DROP TABLE IF EXISTS sessao_junta CASCADE;
DROP TABLE IF EXISTS exame_clinico CASCADE;
DROP TABLE IF EXISTS atendimento CASCADE;
DROP TABLE IF EXISTS paciente CASCADE;
DROP TABLE IF EXISTS lota CASCADE;
DROP TABLE IF EXISTS medico CASCADE;
DROP TABLE IF EXISTS unidade_saude CASCADE;

-- 1. UNIDADE_SAUDE (Forte - Fonte: OpenDataSUS / CNES)
CREATE TABLE unidade_saude (
    co_cnes VARCHAR(10) PRIMARY KEY,
    no_fantasia VARCHAR(200) NOT NULL
);

-- 2. MEDICO (Forte - Fonte: OpenDataSUS / CNES)
CREATE TABLE medico (
    crm VARCHAR(20) PRIMARY KEY,
    nome_medico VARCHAR(150) NOT NULL
);

-- 3. LOTA (Relacionamento N:M entre MEDICO e UNIDADE_SAUDE - Regra R1)
CREATE TABLE lota (
    crm VARCHAR(20) NOT NULL REFERENCES medico(crm) ON DELETE CASCADE,
    co_cnes VARCHAR(10) NOT NULL REFERENCES unidade_saude(co_cnes) ON DELETE CASCADE,
    PRIMARY KEY (crm, co_cnes)
);

-- 4. PACIENTE (Forte - Fonte: MIMIC-IV Demo)
CREATE TABLE paciente (
    subject_id INT PRIMARY KEY,
    idade INT NOT NULL CHECK (idade >= 0 AND idade <= 130),
    alergias TEXT[] DEFAULT '{}'
);

-- 5. ATENDIMENTO (Forte - Regras R2, R3)
CREATE TABLE atendimento (
    hadm_id INT PRIMARY KEY,
    subject_id INT NOT NULL REFERENCES paciente(subject_id),
    crm VARCHAR(20) NOT NULL REFERENCES medico(crm),
    admittime TIMESTAMP NOT NULL,
    escore_sofa INT NOT NULL DEFAULT 0 CHECK (escore_sofa BETWEEN 0 AND 24)
);

-- 6. EXAME_CLINICO (Fraca, dependente de ATENDIMENTO - Regra R4)
CREATE TABLE exame_clinico (
    hadm_id INT NOT NULL REFERENCES atendimento(hadm_id) ON DELETE CASCADE,
    seq_exame INT NOT NULL CHECK (seq_exame > 0),
    itemid INT NOT NULL,
    item_name VARCHAR(150) NOT NULL,
    valuenum NUMERIC(10, 3),
    valueuom VARCHAR(30),
    charttime TIMESTAMP NOT NULL,
    flag_anormal BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (hadm_id, seq_exame)
);

-- 7. SESSAO_JUNTA (Forte - Regra R5)
CREATE TABLE sessao_junta (
    id_sessao SERIAL PRIMARY KEY,
    hadm_id INT NOT NULL REFERENCES atendimento(hadm_id) ON DELETE CASCADE,
    indice_discordancia NUMERIC(5, 2) NOT NULL DEFAULT 0.00 CHECK (indice_discordancia BETWEEN 0 AND 100)
);

-- 8. AGENTE_IA (Forte)
CREATE TABLE agente_ia (
    id_agente SERIAL PRIMARY KEY,
    tipo_agente VARCHAR(60) NOT NULL
);

-- 9. PARECER_AGENTE (Fraca, dependente de SESSAO_JUNTA - Regra R6)
CREATE TABLE parecer_agente (
    id_sessao INT NOT NULL REFERENCES sessao_junta(id_sessao) ON DELETE CASCADE,
    num_parecer INT NOT NULL CHECK (num_parecer > 0),
    id_agente INT NOT NULL REFERENCES agente_ia(id_agente),
    texto_parecer TEXT NOT NULL,
    PRIMARY KEY (id_sessao, num_parecer)
);

-- 10. DIRETRIZ_CLINICA (Forte - Protocolos CONITEC/SUS)
CREATE TABLE diretriz_clinica (
    id_diretriz SERIAL PRIMARY KEY,
    titulo_protocolo VARCHAR(250) NOT NULL
);

-- 11. FUNDAMENTA (Relacionamento N:M entre PARECER_AGENTE e DIRETRIZ_CLINICA - Regra R7)
CREATE TABLE fundamenta (
    id_sessao INT NOT NULL,
    num_parecer INT NOT NULL,
    id_diretriz INT NOT NULL REFERENCES diretriz_clinica(id_diretriz),
    PRIMARY KEY (id_sessao, num_parecer, id_diretriz),
    FOREIGN KEY (id_sessao, num_parecer)
        REFERENCES parecer_agente(id_sessao, num_parecer)
        ON DELETE CASCADE
);

-- 12. MEDICAMENTO (Forte - Fonte: ANVISA)
CREATE TABLE medicamento (
    num_registro VARCHAR(13) PRIMARY KEY,
    nome_produto VARCHAR(200) NOT NULL,
    categoria_risco_renal VARCHAR(50) NOT NULL DEFAULT 'BAIXO',
    situacao_registro VARCHAR(50) NOT NULL DEFAULT 'VALIDO'
);

-- 13. PRESCREVE (Relacionamento N:M entre ATENDIMENTO e MEDICAMENTO - Regra R8)
CREATE TABLE prescreve (
    hadm_id INT NOT NULL REFERENCES atendimento(hadm_id) ON DELETE CASCADE,
    num_registro VARCHAR(13) NOT NULL REFERENCES medicamento(num_registro),
    data_prescricao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    posologia VARCHAR(200) NOT NULL,
    alerta_renal BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (hadm_id, num_registro, data_prescricao)
);
