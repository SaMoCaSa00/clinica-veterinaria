-- =============================================================================
--  Sistema de Gestão de Clínica Veterinária
--  01_ddl.sql — esquema físico (tabelas, restrições, índices, gatilhos, visões)
-- -----------------------------------------------------------------------------
--  SGBD.......: PostgreSQL (testado nas versões 16 e 18)
--  Banco......: clinica_vet   (criado por 00_criar_banco.sql)
--  Esquema....: clinica
--
--  O script apaga o esquema "clinica" (se existir) e recria tudo do zero,
--  então pode ser executado várias vezes durante o desenvolvimento.
-- =============================================================================

DROP SCHEMA IF EXISTS clinica CASCADE;
CREATE SCHEMA clinica;
COMMENT ON SCHEMA clinica IS 'Objetos do sistema de gestão de clínica veterinária.';

SET search_path TO clinica;


-- -----------------------------------------------------------------------------
-- Validação de CPF (dígitos verificadores, módulo 11)
--  Criada antes das tabelas porque é usada no CHECK de tutor e veterinário.
--
--  Os 2 últimos dígitos do CPF são calculados a partir dos anteriores:
--   1º dígito: multiplica os 9 primeiros pelos pesos 10, 9, ..., 2, soma,
--              faz (soma * 10) % 11 e, se der 10, usa 0.
--   2º dígito: mesma conta com os 10 primeiros e pesos 11, 10, ..., 2.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cpf_valido(p_cpf VARCHAR)
RETURNS BOOLEAN AS
$$
DECLARE
    v_soma INTEGER;
    v_dv1  INTEGER;
    v_dv2  INTEGER;
BEGIN
    -- precisa ter 11 caracteres e todos devem ser dígitos
    -- (TRANSLATE apaga os dígitos; se sobrar algo, havia outro caractere)
    IF LENGTH(p_cpf) <> 11 OR TRANSLATE(p_cpf, '0123456789', '') <> '' THEN
        RETURN FALSE;
    END IF;

    -- sequências repetidas (000..., 111...) passam na conta, mas não existem
    IF p_cpf = REPEAT(SUBSTR(p_cpf, 1, 1), 11) THEN
        RETURN FALSE;
    END IF;

    -- 1º dígito verificador
    v_soma := CAST(SUBSTR(p_cpf, 1, 1) AS INTEGER) * 10
            + CAST(SUBSTR(p_cpf, 2, 1) AS INTEGER) * 9
            + CAST(SUBSTR(p_cpf, 3, 1) AS INTEGER) * 8
            + CAST(SUBSTR(p_cpf, 4, 1) AS INTEGER) * 7
            + CAST(SUBSTR(p_cpf, 5, 1) AS INTEGER) * 6
            + CAST(SUBSTR(p_cpf, 6, 1) AS INTEGER) * 5
            + CAST(SUBSTR(p_cpf, 7, 1) AS INTEGER) * 4
            + CAST(SUBSTR(p_cpf, 8, 1) AS INTEGER) * 3
            + CAST(SUBSTR(p_cpf, 9, 1) AS INTEGER) * 2;
    v_dv1 := (v_soma * 10) % 11;
    IF v_dv1 = 10 THEN
        v_dv1 := 0;
    END IF;

    -- 2º dígito verificador
    v_soma := CAST(SUBSTR(p_cpf, 1, 1) AS INTEGER) * 11
            + CAST(SUBSTR(p_cpf, 2, 1) AS INTEGER) * 10
            + CAST(SUBSTR(p_cpf, 3, 1) AS INTEGER) * 9
            + CAST(SUBSTR(p_cpf, 4, 1) AS INTEGER) * 8
            + CAST(SUBSTR(p_cpf, 5, 1) AS INTEGER) * 7
            + CAST(SUBSTR(p_cpf, 6, 1) AS INTEGER) * 6
            + CAST(SUBSTR(p_cpf, 7, 1) AS INTEGER) * 5
            + CAST(SUBSTR(p_cpf, 8, 1) AS INTEGER) * 4
            + CAST(SUBSTR(p_cpf, 9, 1) AS INTEGER) * 3
            + v_dv1 * 2;
    v_dv2 := (v_soma * 10) % 11;
    IF v_dv2 = 10 THEN
        v_dv2 := 0;
    END IF;

    RETURN v_dv1 = CAST(SUBSTR(p_cpf, 10, 1) AS INTEGER)
       AND v_dv2 = CAST(SUBSTR(p_cpf, 11, 1) AS INTEGER);
END
$$
LANGUAGE plpgsql;

COMMENT ON FUNCTION cpf_valido(VARCHAR) IS
    'TRUE se o CPF (11 dígitos, sem máscara) tem dígitos verificadores válidos e não é uma sequência repetida.';


-- =============================================================================
-- 1. TABELAS DE DOMÍNIO / CATÁLOGO
-- =============================================================================

-- 1.1 Espécie --------------------------------------------------------------
CREATE TABLE especie (
    id_especie  SERIAL,
    nome        VARCHAR(40) CONSTRAINT nn_especie_nome NOT NULL,

    CONSTRAINT pk_especie      PRIMARY KEY (id_especie),
    CONSTRAINT uq_especie_nome UNIQUE (nome)
);
COMMENT ON TABLE  especie      IS 'Espécies atendidas pela clínica (cão, gato, ave...).';
COMMENT ON COLUMN especie.nome IS 'Nome popular da espécie, único.';

-- 1.2 Raça -----------------------------------------------------------------
CREATE TABLE raca (
    id_raca     SERIAL,
    id_especie  INTEGER     CONSTRAINT nn_raca_especie NOT NULL,
    nome        VARCHAR(60) CONSTRAINT nn_raca_nome    NOT NULL,
    porte       CHAR(1),

    CONSTRAINT pk_raca              PRIMARY KEY (id_raca),
    CONSTRAINT fk_raca_especie      FOREIGN KEY (id_especie)
        REFERENCES especie (id_especie) ON DELETE RESTRICT,
    CONSTRAINT uq_raca_especie_nome UNIQUE (id_especie, nome),
    CONSTRAINT ck_raca_porte        CHECK (porte IN ('P', 'M', 'G'))
);
COMMENT ON TABLE  raca       IS 'Raças por espécie. Animais sem raça definida usam a raça "SRD" da espécie.';
COMMENT ON COLUMN raca.porte IS 'Porte típico: P (pequeno), M (médio), G (grande). Nulo quando não se aplica.';

-- 1.3 Especialidade --------------------------------------------------------
CREATE TABLE especialidade (
    id_especialidade SERIAL,
    nome             VARCHAR(60) CONSTRAINT nn_especialidade_nome NOT NULL,

    CONSTRAINT pk_especialidade      PRIMARY KEY (id_especialidade),
    CONSTRAINT uq_especialidade_nome UNIQUE (nome)
);
COMMENT ON TABLE especialidade IS 'Áreas de atuação dos médicos-veterinários.';

-- 1.4 Procedimento (catálogo) ----------------------------------------------
CREATE TABLE procedimento (
    id_procedimento SERIAL,
    nome            VARCHAR(100)  CONSTRAINT nn_procedimento_nome  NOT NULL,
    categoria       VARCHAR(15)   CONSTRAINT nn_procedimento_cat   NOT NULL,
    descricao       TEXT,
    preco_base      NUMERIC(10,2) CONSTRAINT nn_procedimento_preco NOT NULL,
    ativo           BOOLEAN       NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_procedimento       PRIMARY KEY (id_procedimento),
    CONSTRAINT uq_procedimento_nome  UNIQUE (nome),
    CONSTRAINT ck_procedimento_cat   CHECK (categoria IN
        ('CONSULTA', 'EXAME', 'IMAGEM', 'VACINA', 'CIRURGIA', 'TERAPIA', 'INTERNACAO')),
    CONSTRAINT ck_procedimento_preco CHECK (preco_base >= 0)
);
COMMENT ON TABLE  procedimento            IS 'Catálogo de procedimentos oferecidos (consultas, exames, vacinas, cirurgias...).';
COMMENT ON COLUMN procedimento.preco_base IS 'Preço de tabela vigente. O valor efetivamente cobrado fica em atendimento_procedimento.';
COMMENT ON COLUMN procedimento.ativo      IS 'FALSE para procedimentos descontinuados (mantidos por causa do histórico).';

-- 1.5 Medicamento (catálogo) -----------------------------------------------
CREATE TABLE medicamento (
    id_medicamento     SERIAL,
    nome_comercial     VARCHAR(80) CONSTRAINT nn_medicamento_nome      NOT NULL,
    principio_ativo    VARCHAR(80) CONSTRAINT nn_medicamento_principio NOT NULL,
    concentracao       VARCHAR(30) CONSTRAINT nn_medicamento_conc      NOT NULL,
    forma_farmaceutica VARCHAR(15) CONSTRAINT nn_medicamento_forma     NOT NULL,
    fabricante         VARCHAR(60),
    controlado         BOOLEAN     NOT NULL DEFAULT FALSE,

    CONSTRAINT pk_medicamento PRIMARY KEY (id_medicamento),
    CONSTRAINT uq_medicamento_apresentacao
        UNIQUE (nome_comercial, concentracao, forma_farmaceutica),
    CONSTRAINT ck_medicamento_forma CHECK (forma_farmaceutica IN
        ('COMPRIMIDO', 'CAPSULA', 'SUSPENSAO', 'SOLUCAO_ORAL', 'INJETAVEL',
         'POMADA', 'COLIRIO', 'SPRAY', 'PIPETA'))
);
COMMENT ON TABLE  medicamento              IS 'Catálogo de medicamentos (cada linha é uma apresentação comercial).';
COMMENT ON COLUMN medicamento.concentracao IS 'Ex.: "50 mg", "10 mg/mL".';
COMMENT ON COLUMN medicamento.controlado   IS 'TRUE para substâncias sujeitas a controle especial (receita retida).';

-- 1.6 Espécies indicadas para cada procedimento (N:N) ----------------------
--  Procedimento SEM linhas aqui vale para qualquer espécie (ex.: consulta,
--  hemograma). Procedimento COM linhas só pode ser feito nas espécies listadas
--  (ex.: vacina V10 só em cão). Garantido pelo gatilho trg_atproc_valida_especie.
CREATE TABLE procedimento_especie (
    id_procedimento INTEGER,
    id_especie      INTEGER,

    CONSTRAINT pk_procedimento_especie PRIMARY KEY (id_procedimento, id_especie),
    CONSTRAINT fk_procesp_procedimento FOREIGN KEY (id_procedimento)
        REFERENCES procedimento (id_procedimento) ON DELETE CASCADE,
    CONSTRAINT fk_procesp_especie      FOREIGN KEY (id_especie)
        REFERENCES especie (id_especie)           ON DELETE RESTRICT
);
COMMENT ON TABLE procedimento_especie IS
    'Restringe um procedimento às espécies listadas. Sem linhas = permitido para todas as espécies.';

-- 1.7 Espécies indicadas para cada medicamento (N:N) -----------------------
--  Mesma regra: medicamento sem linhas aqui é de uso geral; com linhas, só pode
--  ser prescrito para as espécies listadas (ex.: Simparic só para cão).
CREATE TABLE medicamento_especie (
    id_medicamento INTEGER,
    id_especie     INTEGER,

    CONSTRAINT pk_medicamento_especie PRIMARY KEY (id_medicamento, id_especie),
    CONSTRAINT fk_medesp_medicamento  FOREIGN KEY (id_medicamento)
        REFERENCES medicamento (id_medicamento) ON DELETE CASCADE,
    CONSTRAINT fk_medesp_especie      FOREIGN KEY (id_especie)
        REFERENCES especie (id_especie)         ON DELETE RESTRICT
);
COMMENT ON TABLE medicamento_especie IS
    'Restringe um medicamento às espécies listadas. Sem linhas = permitido para todas as espécies.';


-- =============================================================================
-- 2. PESSOAS E ANIMAIS
-- =============================================================================

-- 2.1 Tutor ----------------------------------------------------------------
CREATE TABLE tutor (
    id_tutor        SERIAL,
    nome            VARCHAR(120) CONSTRAINT nn_tutor_nome     NOT NULL,
    cpf             CHAR(11)     CONSTRAINT nn_tutor_cpf      NOT NULL,
    data_nascimento DATE,
    email           VARCHAR(120),
    telefone        VARCHAR(11)  CONSTRAINT nn_tutor_telefone NOT NULL,
    logradouro      VARCHAR(120),
    numero          VARCHAR(10),
    complemento     VARCHAR(60),
    bairro          VARCHAR(60),
    cidade          VARCHAR(60)  CONSTRAINT nn_tutor_cidade   NOT NULL,
    uf              CHAR(2)      CONSTRAINT nn_tutor_uf       NOT NULL,
    cep             CHAR(8),
    criado_em       TIMESTAMP    NOT NULL DEFAULT now(),

    CONSTRAINT pk_tutor          PRIMARY KEY (id_tutor),
    CONSTRAINT uq_tutor_cpf      UNIQUE (cpf),
    CONSTRAINT uq_tutor_email    UNIQUE (email),
    CONSTRAINT ck_tutor_cpf      CHECK (cpf_valido(cpf)),
    CONSTRAINT ck_tutor_telefone CHECK (LENGTH(telefone) BETWEEN 10 AND 11),
    CONSTRAINT ck_tutor_email    CHECK (email LIKE '%_@_%._%'),
    CONSTRAINT ck_tutor_uf       CHECK (uf = UPPER(uf)),
    CONSTRAINT ck_tutor_cep      CHECK (LENGTH(cep) = 8)
);
COMMENT ON TABLE  tutor          IS 'Responsável legal e financeiro pelos animais.';
COMMENT ON COLUMN tutor.cpf      IS 'CPF somente com dígitos (11), validado por cpf_valido(). Chave candidata.';
COMMENT ON COLUMN tutor.telefone IS 'DDD + número, somente dígitos (10 ou 11).';
COMMENT ON COLUMN tutor.cep      IS 'CEP somente com dígitos (8).';

-- 2.2 Animal ---------------------------------------------------------------
CREATE TABLE animal (
    id_animal       SERIAL,
    id_tutor        INTEGER     CONSTRAINT nn_animal_tutor NOT NULL,
    id_raca         INTEGER     CONSTRAINT nn_animal_raca  NOT NULL,
    nome            VARCHAR(60) CONSTRAINT nn_animal_nome  NOT NULL,
    sexo            CHAR(1)     CONSTRAINT nn_animal_sexo  NOT NULL,
    data_nascimento DATE,
    pelagem         VARCHAR(40),
    castrado        BOOLEAN     NOT NULL DEFAULT FALSE,
    microchip       CHAR(15),
    data_obito      DATE,
    observacoes     TEXT,
    criado_em       TIMESTAMP   NOT NULL DEFAULT now(),

    CONSTRAINT pk_animal           PRIMARY KEY (id_animal),
    CONSTRAINT fk_animal_tutor     FOREIGN KEY (id_tutor)
        REFERENCES tutor (id_tutor) ON DELETE RESTRICT,
    CONSTRAINT fk_animal_raca      FOREIGN KEY (id_raca)
        REFERENCES raca (id_raca)   ON DELETE RESTRICT,
    CONSTRAINT uq_animal_microchip UNIQUE (microchip),
    CONSTRAINT ck_animal_sexo      CHECK (sexo IN ('M', 'F')),
    CONSTRAINT ck_animal_microchip CHECK (LENGTH(microchip) = 15),
    CONSTRAINT ck_animal_obito     CHECK (data_obito IS NULL OR data_obito >= data_nascimento)
);
COMMENT ON TABLE  animal            IS 'Paciente da clínica. Cada animal pertence a exatamente um tutor.';
COMMENT ON COLUMN animal.id_tutor   IS 'Tutor responsável (obrigatório: regra "um animal pertence a apenas um tutor").';
COMMENT ON COLUMN animal.id_raca    IS 'Raça do animal; a espécie é obtida pela raça (evita dependência transitiva).';
COMMENT ON COLUMN animal.microchip  IS 'Código ISO 11784/11785 de 15 dígitos, quando houver.';
COMMENT ON COLUMN animal.data_obito IS 'Preenchida em caso de óbito; o histórico é preservado.';

-- 2.3 Veterinário ----------------------------------------------------------
CREATE TABLE veterinario (
    id_veterinario SERIAL,
    nome           VARCHAR(120) CONSTRAINT nn_veterinario_nome  NOT NULL,
    cpf            CHAR(11)     CONSTRAINT nn_veterinario_cpf   NOT NULL,
    crmv           VARCHAR(8)   CONSTRAINT nn_veterinario_crmv  NOT NULL,
    uf_crmv        CHAR(2)      CONSTRAINT nn_veterinario_uf    NOT NULL,
    email          VARCHAR(120) CONSTRAINT nn_veterinario_email NOT NULL,
    telefone       VARCHAR(11),
    data_admissao  DATE         NOT NULL DEFAULT CURRENT_DATE,
    ativo          BOOLEAN      NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_veterinario       PRIMARY KEY (id_veterinario),
    CONSTRAINT uq_veterinario_cpf   UNIQUE (cpf),
    CONSTRAINT uq_veterinario_crmv  UNIQUE (uf_crmv, crmv),
    CONSTRAINT uq_veterinario_email UNIQUE (email),
    CONSTRAINT ck_veterinario_cpf   CHECK (cpf_valido(cpf)),
    CONSTRAINT ck_veterinario_uf    CHECK (uf_crmv = UPPER(uf_crmv)),
    CONSTRAINT ck_veterinario_tel   CHECK (LENGTH(telefone) BETWEEN 10 AND 11)
);
COMMENT ON TABLE  veterinario       IS 'Médicos-veterinários do corpo clínico.';
COMMENT ON COLUMN veterinario.crmv  IS 'Número de inscrição no CRMV. Único em conjunto com uf_crmv.';
COMMENT ON COLUMN veterinario.ativo IS 'FALSE para profissionais desligados (mantidos por causa do histórico).';

-- 2.4 Veterinário x Especialidade (N:N) ------------------------------------
CREATE TABLE veterinario_especialidade (
    id_veterinario   INTEGER,
    id_especialidade INTEGER,

    CONSTRAINT pk_veterinario_especialidade PRIMARY KEY (id_veterinario, id_especialidade),
    CONSTRAINT fk_vetesp_veterinario   FOREIGN KEY (id_veterinario)
        REFERENCES veterinario (id_veterinario)     ON DELETE CASCADE,
    CONSTRAINT fk_vetesp_especialidade FOREIGN KEY (id_especialidade)
        REFERENCES especialidade (id_especialidade) ON DELETE RESTRICT
);
COMMENT ON TABLE veterinario_especialidade IS 'Associação N:N entre veterinários e especialidades.';


-- =============================================================================
-- 3. AGENDA E ATENDIMENTO CLÍNICO
-- =============================================================================

-- 3.1 Agendamento ----------------------------------------------------------
CREATE TABLE agendamento (
    id_agendamento      SERIAL,
    id_animal           INTEGER      CONSTRAINT nn_agendamento_animal NOT NULL,
    id_veterinario      INTEGER      CONSTRAINT nn_agendamento_vet    NOT NULL,
    data_hora_inicio    TIMESTAMP    CONSTRAINT nn_agendamento_inicio NOT NULL,
    data_hora_fim       TIMESTAMP    CONSTRAINT nn_agendamento_fim    NOT NULL,
    tipo                VARCHAR(12)  NOT NULL DEFAULT 'CONSULTA',
    motivo              VARCHAR(200),
    status              VARCHAR(10)  NOT NULL DEFAULT 'AGENDADO',
    motivo_cancelamento VARCHAR(200),
    criado_em           TIMESTAMP    NOT NULL DEFAULT now(),

    CONSTRAINT pk_agendamento PRIMARY KEY (id_agendamento),
    -- se o animal for apagado, os horários dele somem junto (CASCADE)
    CONSTRAINT fk_agendamento_animal FOREIGN KEY (id_animal)
        REFERENCES animal (id_animal)           ON DELETE CASCADE,
    -- veterinário com horários não pode ser apagado (RESTRICT)
    CONSTRAINT fk_agendamento_veterinario FOREIGN KEY (id_veterinario)
        REFERENCES veterinario (id_veterinario) ON DELETE RESTRICT,
    CONSTRAINT ck_agendamento_periodo CHECK (data_hora_fim > data_hora_inicio),
    CONSTRAINT ck_agendamento_duracao CHECK (data_hora_fim - data_hora_inicio <= INTERVAL '8 hours'),
    CONSTRAINT ck_agendamento_tipo    CHECK (tipo IN
        ('CONSULTA', 'RETORNO', 'VACINACAO', 'EXAME', 'CIRURGIA')),
    CONSTRAINT ck_agendamento_status  CHECK (status IN ('AGENDADO', 'REALIZADO', 'CANCELADO')),
    -- cancelado precisa de motivo; os demais status não podem ter motivo de cancelamento
    CONSTRAINT ck_agendamento_cancel  CHECK (
        (status =  'CANCELADO' AND motivo_cancelamento IS NOT NULL) OR
        (status <> 'CANCELADO' AND motivo_cancelamento IS NULL))
);
COMMENT ON TABLE  agendamento        IS 'Agenda de horários. Ciclo de vida: AGENDADO -> REALIZADO | CANCELADO.';
COMMENT ON COLUMN agendamento.status IS 'AGENDADO, REALIZADO ou CANCELADO. Vira REALIZADO automaticamente quando um atendimento é vinculado.';
COMMENT ON COLUMN agendamento.motivo_cancelamento IS 'Obrigatório se, e somente se, status = CANCELADO.';

-- 3.2 Atendimento ----------------------------------------------------------
CREATE TABLE atendimento (
    id_atendimento   SERIAL,
    id_animal        INTEGER      CONSTRAINT nn_atendimento_animal NOT NULL,
    id_veterinario   INTEGER      CONSTRAINT nn_atendimento_vet    NOT NULL,
    id_agendamento   INTEGER,
    data_hora_inicio TIMESTAMP    NOT NULL DEFAULT now(),
    data_hora_fim    TIMESTAMP,
    carater          VARCHAR(10)  NOT NULL DEFAULT 'ELETIVO',
    status           VARCHAR(10)  NOT NULL DEFAULT 'EM_ABERTO',
    queixa_principal TEXT         CONSTRAINT nn_atendimento_queixa NOT NULL,
    anamnese         TEXT,
    exame_fisico     TEXT,
    diagnostico      TEXT,
    peso_kg          NUMERIC(6,3),
    temperatura_c    NUMERIC(3,1),
    observacoes      TEXT,

    CONSTRAINT pk_atendimento PRIMARY KEY (id_atendimento),
    CONSTRAINT fk_atendimento_animal FOREIGN KEY (id_animal)
        REFERENCES animal (id_animal)             ON DELETE RESTRICT,
    CONSTRAINT fk_atendimento_veterinario FOREIGN KEY (id_veterinario)
        REFERENCES veterinario (id_veterinario)   ON DELETE RESTRICT,
    CONSTRAINT fk_atendimento_agendamento FOREIGN KEY (id_agendamento)
        REFERENCES agendamento (id_agendamento)   ON DELETE RESTRICT,
    -- um agendamento gera no máximo um atendimento
    CONSTRAINT uq_atendimento_agendamento UNIQUE (id_agendamento),
    CONSTRAINT ck_atendimento_carater CHECK (carater IN ('ELETIVO', 'URGENCIA', 'EMERGENCIA')),
    CONSTRAINT ck_atendimento_status  CHECK (status IN ('EM_ABERTO', 'FINALIZADO')),
    -- só o atendimento finalizado tem data/hora de término
    CONSTRAINT ck_atendimento_fim     CHECK (
        (status =  'FINALIZADO' AND data_hora_fim IS NOT NULL) OR
        (status <> 'FINALIZADO' AND data_hora_fim IS NULL)),
    CONSTRAINT ck_atendimento_periodo CHECK (data_hora_fim IS NULL OR data_hora_fim >= data_hora_inicio),
    CONSTRAINT ck_atendimento_peso    CHECK (peso_kg > 0),
    CONSTRAINT ck_atendimento_temp    CHECK (temperatura_c BETWEEN 30 AND 45)
);
COMMENT ON TABLE  atendimento                IS 'Evento clínico realizado por UM veterinário. Compõe o histórico clínico do animal.';
COMMENT ON COLUMN atendimento.id_agendamento IS 'Agendamento de origem (nulo para encaixes, urgências e emergências).';
COMMENT ON COLUMN atendimento.status         IS 'EM_ABERTO (em curso/internação) ou FINALIZADO (com data_hora_fim).';
COMMENT ON COLUMN atendimento.peso_kg        IS 'Peso aferido no atendimento (o peso varia ao longo da vida, por isso fica aqui e não em animal).';
COMMENT ON COLUMN atendimento.temperatura_c  IS 'Temperatura corporal em °C.';

-- 3.3 Procedimentos realizados no atendimento (N:N) ------------------------
CREATE TABLE atendimento_procedimento (
    id_atendimento  INTEGER,
    id_procedimento INTEGER,
    quantidade      INTEGER       NOT NULL DEFAULT 1,
    valor_unitario  NUMERIC(10,2) CONSTRAINT nn_atproc_valor NOT NULL,
    observacao      VARCHAR(200),

    CONSTRAINT pk_atendimento_procedimento PRIMARY KEY (id_atendimento, id_procedimento),
    -- se o atendimento for apagado, os itens dele somem junto
    CONSTRAINT fk_atproc_atendimento  FOREIGN KEY (id_atendimento)
        REFERENCES atendimento (id_atendimento)   ON DELETE CASCADE,
    CONSTRAINT fk_atproc_procedimento FOREIGN KEY (id_procedimento)
        REFERENCES procedimento (id_procedimento) ON DELETE RESTRICT,
    CONSTRAINT ck_atproc_quantidade CHECK (quantidade > 0),
    CONSTRAINT ck_atproc_valor      CHECK (valor_unitario >= 0)
);
COMMENT ON TABLE  atendimento_procedimento                IS 'Procedimentos executados em cada atendimento (0..N por atendimento).';
COMMENT ON COLUMN atendimento_procedimento.valor_unitario IS 'Preço praticado na data do atendimento (fotografia histórica; se omitido, recebe o preco_base).';

-- 3.4 Prescrição -----------------------------------------------------------
CREATE TABLE prescricao (
    id_prescricao     SERIAL,
    id_atendimento    INTEGER      CONSTRAINT nn_prescricao_atendimento NOT NULL,
    id_medicamento    INTEGER      CONSTRAINT nn_prescricao_medicamento NOT NULL,
    dose_quantidade   NUMERIC(8,3) CONSTRAINT nn_prescricao_dose        NOT NULL,
    dose_unidade      VARCHAR(10)  CONSTRAINT nn_prescricao_unidade     NOT NULL,
    via_administracao VARCHAR(13)  CONSTRAINT nn_prescricao_via         NOT NULL,
    frequencia_horas  INTEGER      CONSTRAINT nn_prescricao_freq        NOT NULL,
    duracao_dias      INTEGER,
    instrucoes        TEXT,

    CONSTRAINT pk_prescricao PRIMARY KEY (id_prescricao),
    CONSTRAINT fk_prescricao_atendimento FOREIGN KEY (id_atendimento)
        REFERENCES atendimento (id_atendimento) ON DELETE CASCADE,
    CONSTRAINT fk_prescricao_medicamento FOREIGN KEY (id_medicamento)
        REFERENCES medicamento (id_medicamento) ON DELETE RESTRICT,
    -- o mesmo medicamento não aparece duas vezes na mesma receita
    CONSTRAINT uq_prescricao_item UNIQUE (id_atendimento, id_medicamento),
    CONSTRAINT ck_prescricao_dose CHECK (dose_quantidade > 0),
    CONSTRAINT ck_prescricao_unid CHECK (dose_unidade IN
        ('mg', 'mL', 'comprimido', 'capsula', 'gota', 'UI', 'aplicacao', 'pipeta')),
    CONSTRAINT ck_prescricao_via  CHECK (via_administracao IN
        ('ORAL', 'SUBCUTANEA', 'INTRAMUSCULAR', 'INTRAVENOSA', 'TOPICA', 'OFTALMICA', 'OTOLOGICA')),
    CONSTRAINT ck_prescricao_freq CHECK (frequencia_horas BETWEEN 1 AND 744),
    CONSTRAINT ck_prescricao_dur  CHECK (duracao_dias BETWEEN 1 AND 365)
);
COMMENT ON TABLE  prescricao                  IS 'Itens de prescrição gerados em um atendimento (0..N por atendimento).';
COMMENT ON COLUMN prescricao.frequencia_horas IS 'Intervalo entre doses, em horas (ex.: 12 = a cada 12 h; 720 = mensal).';
COMMENT ON COLUMN prescricao.duracao_dias     IS 'Duração do tratamento em dias; nulo = dose única ou uso contínuo (ver instrucoes).';


-- =============================================================================
-- 4. ÍNDICES
--    PKs e UNIQUEs já criam índices automaticamente. Os índices abaixo cobrem
--    as chaves estrangeiras (o PostgreSQL não indexa FKs sozinho) e as colunas
--    mais usadas em filtros e ordenações nas consultas de gestão.
-- =============================================================================

-- Chaves estrangeiras usadas nas junções
CREATE INDEX ix_animal_tutor            ON animal (id_tutor);
CREATE INDEX ix_animal_raca             ON animal (id_raca);
CREATE INDEX ix_agendamento_animal      ON agendamento (id_animal);
CREATE INDEX ix_atproc_procedimento     ON atendimento_procedimento (id_procedimento);
CREATE INDEX ix_prescricao_medicamento  ON prescricao (id_medicamento);
CREATE INDEX ix_vetesp_especialidade    ON veterinario_especialidade (id_especialidade);
CREATE INDEX ix_procesp_especie         ON procedimento_especie (id_especie);
CREATE INDEX ix_medesp_especie          ON medicamento_especie (id_especie);

-- Histórico clínico: atendimentos de um animal, por data
CREATE INDEX ix_atendimento_animal_data ON atendimento (id_animal, data_hora_inicio);

-- Produtividade: atendimentos de um veterinário em um período
CREATE INDEX ix_atendimento_vet_data    ON atendimento (id_veterinario, data_hora_inicio);

-- Agenda: horários de um veterinário por data (também usado na checagem de conflito)
CREATE INDEX ix_agendamento_vet_data    ON agendamento (id_veterinario, data_hora_inicio);

-- Painel: agendamentos por situação e data / atendimentos em aberto
CREATE INDEX ix_agendamento_status_data ON agendamento (status, data_hora_inicio);
CREATE INDEX ix_atendimento_status      ON atendimento (status);

-- Busca de tutor por nome no balcão
CREATE INDEX ix_tutor_nome              ON tutor (nome);

COMMENT ON INDEX ix_atendimento_animal_data IS 'Acelera a montagem do histórico clínico por animal (ordenado por data).';
COMMENT ON INDEX ix_atendimento_vet_data    IS 'Acelera relatórios de produtividade por veterinário e período.';
COMMENT ON INDEX ix_agendamento_vet_data    IS 'Acelera a agenda de cada veterinário e a verificação de conflito de horário.';
COMMENT ON INDEX ix_agendamento_status_data IS 'Acelera a busca de horários futuros ainda não realizados.';
COMMENT ON INDEX ix_atendimento_status      IS 'Acelera a busca de atendimentos/internações em aberto.';
COMMENT ON INDEX ix_tutor_nome              IS 'Acelera a busca de tutor pelo nome.';


-- =============================================================================
-- 5. REGRAS DE NEGÓCIO EM GATILHOS (TRIGGERS)
-- =============================================================================

-- 5.1 Conflito de agenda ---------------------------------------------------
--  Um veterinário não pode ter dois horários ativos que se sobreponham.
--  Dois intervalos [A, B) e [C, D) se sobrepõem quando A < D e C < B.
--  Horários cancelados não contam.
CREATE OR REPLACE FUNCTION fn_agendamento_conflito()
RETURNS trigger AS
$$
BEGIN
    IF NEW.status <> 'CANCELADO' AND EXISTS (
        SELECT 1
          FROM agendamento a
         WHERE a.id_veterinario   = NEW.id_veterinario
           AND a.id_agendamento  <> NEW.id_agendamento
           AND a.status          <> 'CANCELADO'
           AND a.data_hora_inicio < NEW.data_hora_fim
           AND NEW.data_hora_inicio < a.data_hora_fim
    ) THEN
        RAISE EXCEPTION 'O veterinário % já tem um horário marcado que se sobrepõe a este.',
                        NEW.id_veterinario;
    END IF;

    RETURN NEW;
END
$$
LANGUAGE plpgsql;
COMMENT ON FUNCTION fn_agendamento_conflito() IS
    'Impede horários sobrepostos para o mesmo veterinário (agendamentos cancelados não contam).';

CREATE TRIGGER trg_agendamento_conflito
    BEFORE INSERT OR UPDATE ON agendamento
    FOR EACH ROW EXECUTE FUNCTION fn_agendamento_conflito();

-- 5.2 Vincular atendimento ao agendamento ---------------------------------
--  * o agendamento precisa ser do MESMO animal do atendimento;
--  * não permite atender um agendamento CANCELADO;
--  * marca o agendamento como REALIZADO automaticamente.
CREATE OR REPLACE FUNCTION fn_atendimento_vincula_agendamento()
RETURNS trigger AS
$$
DECLARE
    v_status agendamento.status%TYPE;
    v_animal agendamento.id_animal%TYPE;
BEGIN
    IF NEW.id_agendamento IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT status, id_animal
      INTO v_status, v_animal
      FROM agendamento
     WHERE id_agendamento = NEW.id_agendamento
       FOR UPDATE;

    IF v_animal <> NEW.id_animal THEN
        RAISE EXCEPTION 'Agendamento % é de outro animal e não pode ser usado neste atendimento.',
                        NEW.id_agendamento;
    END IF;

    IF v_status = 'CANCELADO' THEN
        RAISE EXCEPTION 'Agendamento % está CANCELADO e não pode gerar atendimento.',
                        NEW.id_agendamento;
    END IF;

    UPDATE agendamento
       SET status = 'REALIZADO'
     WHERE id_agendamento = NEW.id_agendamento
       AND status <> 'REALIZADO';

    RETURN NEW;
END
$$
LANGUAGE plpgsql;
COMMENT ON FUNCTION fn_atendimento_vincula_agendamento() IS
    'Confere animal e status do agendamento e o marca como REALIZADO.';

CREATE TRIGGER trg_atendimento_vincula_agendamento
    AFTER INSERT OR UPDATE ON atendimento
    FOR EACH ROW EXECUTE FUNCTION fn_atendimento_vincula_agendamento();

-- 5.3 Não atender animal após o óbito -------------------------------------
CREATE OR REPLACE FUNCTION fn_atendimento_valida_animal()
RETURNS trigger AS
$$
DECLARE
    v_obito animal.data_obito%TYPE;
BEGIN
    SELECT data_obito INTO v_obito
      FROM animal
     WHERE id_animal = NEW.id_animal;

    IF v_obito IS NOT NULL AND DATE(NEW.data_hora_inicio) > v_obito THEN
        RAISE EXCEPTION 'Animal % teve óbito registrado em % e não pode receber novo atendimento.',
                        NEW.id_animal, v_obito;
    END IF;

    RETURN NEW;
END
$$
LANGUAGE plpgsql;
COMMENT ON FUNCTION fn_atendimento_valida_animal() IS
    'Bloqueia atendimentos com data posterior ao óbito do animal.';

CREATE TRIGGER trg_atendimento_valida_animal
    BEFORE INSERT OR UPDATE ON atendimento
    FOR EACH ROW EXECUTE FUNCTION fn_atendimento_valida_animal();

-- 5.4 Preço padrão do procedimento ----------------------------------------
--  Se valor_unitario não for informado, usa o preço de tabela vigente.
CREATE OR REPLACE FUNCTION fn_atproc_preco_padrao()
RETURNS trigger AS
$$
BEGIN
    IF NEW.valor_unitario IS NULL THEN
        SELECT preco_base INTO NEW.valor_unitario
          FROM procedimento
         WHERE id_procedimento = NEW.id_procedimento;
    END IF;

    RETURN NEW;
END
$$
LANGUAGE plpgsql;
COMMENT ON FUNCTION fn_atproc_preco_padrao() IS
    'Preenche valor_unitario com o preco_base do procedimento quando omitido.';

CREATE TRIGGER trg_atproc_preco_padrao
    BEFORE INSERT ON atendimento_procedimento
    FOR EACH ROW EXECUTE FUNCTION fn_atproc_preco_padrao();

-- 5.5 Coerência do status do agendamento ----------------------------------
--  Um agendamento que já gerou atendimento não pode voltar a AGENDADO nem
--  ser CANCELADO.
CREATE OR REPLACE FUNCTION fn_agendamento_valida_status()
RETURNS trigger AS
$$
BEGIN
    IF NEW.status <> 'REALIZADO' AND EXISTS (
        SELECT 1 FROM atendimento WHERE id_agendamento = NEW.id_agendamento
    ) THEN
        RAISE EXCEPTION 'Agendamento % já possui atendimento e deve permanecer REALIZADO.',
                        NEW.id_agendamento;
    END IF;

    RETURN NEW;
END
$$
LANGUAGE plpgsql;
COMMENT ON FUNCTION fn_agendamento_valida_status() IS
    'Impede cancelar ou reabrir um agendamento que já gerou atendimento.';

CREATE TRIGGER trg_agendamento_valida_status
    BEFORE UPDATE ON agendamento
    FOR EACH ROW EXECUTE FUNCTION fn_agendamento_valida_status();

-- 5.6 Procedimento compatível com a espécie -------------------------------
--  Se o procedimento tem espécies cadastradas em procedimento_especie, a
--  espécie do animal atendido precisa estar entre elas.
CREATE OR REPLACE FUNCTION fn_atproc_valida_especie()
RETURNS trigger AS
$$
DECLARE
    v_id_especie especie.id_especie%TYPE;
    v_especie    especie.nome%TYPE;
    v_animal     animal.nome%TYPE;
    v_item       procedimento.nome%TYPE;
BEGIN
    -- espécie do animal: atendimento -> animal -> raça -> espécie
    SELECT e.id_especie, e.nome, an.nome
      INTO v_id_especie, v_especie, v_animal
      FROM atendimento at
     INNER JOIN animal  an ON an.id_animal = at.id_animal
     INNER JOIN raca    r  ON r.id_raca    = an.id_raca
     INNER JOIN especie e  ON e.id_especie = r.id_especie
     WHERE at.id_atendimento = NEW.id_atendimento;

    IF EXISTS (SELECT 1 FROM procedimento_especie WHERE id_procedimento = NEW.id_procedimento)
       AND v_id_especie NOT IN (SELECT id_especie
                                  FROM procedimento_especie
                                 WHERE id_procedimento = NEW.id_procedimento) THEN
        SELECT nome INTO v_item FROM procedimento WHERE id_procedimento = NEW.id_procedimento;
        RAISE EXCEPTION 'O procedimento "%" não é indicado para a espécie % (animal: %).',
                        v_item, v_especie, v_animal;
    END IF;

    RETURN NEW;
END
$$
LANGUAGE plpgsql;
COMMENT ON FUNCTION fn_atproc_valida_especie() IS
    'Barra procedimento não indicado para a espécie do animal atendido.';

CREATE TRIGGER trg_atproc_valida_especie
    BEFORE INSERT OR UPDATE ON atendimento_procedimento
    FOR EACH ROW EXECUTE FUNCTION fn_atproc_valida_especie();

-- 5.7 Medicamento compatível com a espécie --------------------------------
CREATE OR REPLACE FUNCTION fn_prescricao_valida_especie()
RETURNS trigger AS
$$
DECLARE
    v_id_especie especie.id_especie%TYPE;
    v_especie    especie.nome%TYPE;
    v_animal     animal.nome%TYPE;
    v_item       medicamento.nome_comercial%TYPE;
BEGIN
    SELECT e.id_especie, e.nome, an.nome
      INTO v_id_especie, v_especie, v_animal
      FROM atendimento at
     INNER JOIN animal  an ON an.id_animal = at.id_animal
     INNER JOIN raca    r  ON r.id_raca    = an.id_raca
     INNER JOIN especie e  ON e.id_especie = r.id_especie
     WHERE at.id_atendimento = NEW.id_atendimento;

    IF EXISTS (SELECT 1 FROM medicamento_especie WHERE id_medicamento = NEW.id_medicamento)
       AND v_id_especie NOT IN (SELECT id_especie
                                  FROM medicamento_especie
                                 WHERE id_medicamento = NEW.id_medicamento) THEN
        SELECT nome_comercial INTO v_item FROM medicamento WHERE id_medicamento = NEW.id_medicamento;
        RAISE EXCEPTION 'O medicamento "%" não é indicado para a espécie % (animal: %).',
                        v_item, v_especie, v_animal;
    END IF;

    RETURN NEW;
END
$$
LANGUAGE plpgsql;
COMMENT ON FUNCTION fn_prescricao_valida_especie() IS
    'Barra prescrição de medicamento não indicado para a espécie do animal atendido.';

CREATE TRIGGER trg_prescricao_valida_especie
    BEFORE INSERT OR UPDATE ON prescricao
    FOR EACH ROW EXECUTE FUNCTION fn_prescricao_valida_especie();


-- =============================================================================
-- 6. VISÕES (VIEWS)
-- =============================================================================

-- 6.1 Animal com espécie, raça, tutor e idade -----------------------------
--  Idade em anos: diferença de datas em dias dividida por 365 (divisão inteira).
CREATE OR REPLACE VIEW vw_animal AS
SELECT a.id_animal,
       a.nome                AS animal,
       e.nome                AS especie,
       r.nome                AS raca,
       a.sexo,
       a.castrado,
       a.data_nascimento,
       (COALESCE(a.data_obito, CURRENT_DATE) - a.data_nascimento) / 365 AS idade_anos,
       (a.data_obito IS NULL) AS vivo,
       t.id_tutor,
       t.nome                AS tutor,
       t.telefone            AS telefone_tutor
  FROM animal a
 INNER JOIN raca    r ON r.id_raca    = a.id_raca
 INNER JOIN especie e ON e.id_especie = r.id_especie
 INNER JOIN tutor   t ON t.id_tutor   = a.id_tutor;
COMMENT ON VIEW vw_animal IS 'Animal enriquecido com espécie, raça, idade e tutor.';

-- 6.2 Histórico clínico ----------------------------------------------------
--  Uma linha por atendimento. Valor total e quantidades vêm de subconsultas
--  escalares correlacionadas (uma por atendimento).
CREATE OR REPLACE VIEW vw_historico_clinico AS
SELECT at.id_atendimento,
       at.id_animal,
       an.nome AS animal,
       e.nome  AS especie,
       t.nome  AS tutor,
       v.nome  AS veterinario,
       at.data_hora_inicio,
       at.data_hora_fim,
       at.status,
       at.carater,
       at.queixa_principal,
       at.diagnostico,
       at.peso_kg,
       at.temperatura_c,
       (SELECT COALESCE(SUM(ap.quantidade * ap.valor_unitario), 0)
          FROM atendimento_procedimento ap
         WHERE ap.id_atendimento = at.id_atendimento) AS valor_total,
       (SELECT COUNT(*)
          FROM atendimento_procedimento ap
         WHERE ap.id_atendimento = at.id_atendimento) AS qtd_procedimentos,
       (SELECT COUNT(*)
          FROM prescricao pr
         WHERE pr.id_atendimento = at.id_atendimento) AS qtd_prescricoes
  FROM atendimento at
 INNER JOIN animal      an ON an.id_animal     = at.id_animal
 INNER JOIN raca        r  ON r.id_raca        = an.id_raca
 INNER JOIN especie     e  ON e.id_especie     = r.id_especie
 INNER JOIN tutor       t  ON t.id_tutor       = an.id_tutor
 INNER JOIN veterinario v  ON v.id_veterinario = at.id_veterinario;
COMMENT ON VIEW vw_historico_clinico IS
    'Histórico clínico: cada atendimento com animal, tutor, veterinário, valor total e quantidade de itens.';
