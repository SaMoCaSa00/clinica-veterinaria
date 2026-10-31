-- =============================================================================
--  Sistema de Gestão de Clínica Veterinária
--  02_dml.sql — carga de dados + exemplos de UPDATE e DELETE
-- -----------------------------------------------------------------------------
--  Pré-requisito: 01_ddl.sql executado (esquema "clinica" vazio).
--  Os dados são fictícios. CPFs têm dígitos verificadores válidos, mas foram
--  gerados aleatoriamente e não pertencem a ninguém.
--
--  Linha do tempo dos dados: janeiro/2026 a janeiro/2027. Os atendimentos vão
--  até 27/10/2026 (dois ainda EM_ABERTO) e há agendamentos futuros a partir
--  de novembro/2026.
--
--  As chaves são informadas explicitamente para deixar os relacionamentos
--  legíveis; no fim do script as sequências IDENTITY são ajustadas.
-- =============================================================================

BEGIN;
SET search_path TO clinica, public;
SET TIME ZONE 'America/Sao_Paulo';


-- =============================================================================
-- 1. CATÁLOGOS
-- =============================================================================

INSERT INTO especie (id_especie, nome) VALUES
    (1, 'Cão'),
    (2, 'Gato'),
    (3, 'Ave'),
    (4, 'Roedor'),
    (5, 'Coelho');

INSERT INTO raca (id_raca, id_especie, nome, porte) VALUES
    ( 1, 1, 'SRD (sem raça definida)', NULL),
    ( 2, 1, 'Labrador Retriever',      'G'),
    ( 3, 1, 'Shih Tzu',                'P'),
    ( 4, 1, 'Golden Retriever',        'G'),
    ( 5, 1, 'Pinscher',                'P'),
    ( 6, 1, 'Border Collie',           'M'),
    ( 7, 1, 'Bulldog Francês',         'P'),
    ( 8, 2, 'SRD (sem raça definida)', NULL),
    ( 9, 2, 'Siamês',                  NULL),
    (10, 2, 'Persa',                   NULL),
    (11, 2, 'Maine Coon',              NULL),
    (12, 3, 'Calopsita',               NULL),
    (13, 3, 'Periquito-australiano',   NULL),
    (14, 4, 'Hamster-sírio',           NULL),
    (15, 4, 'Porquinho-da-índia',      NULL),
    (16, 5, 'Mini Lop',                NULL),
    (17, 5, 'SRD (sem raça definida)', NULL);

INSERT INTO especialidade (id_especialidade, nome) VALUES
    (1, 'Clínica Geral'),
    (2, 'Cirurgia de Pequenos Animais'),
    (3, 'Dermatologia'),
    (4, 'Cardiologia'),
    (5, 'Ortopedia'),
    (6, 'Animais Silvestres e Exóticos'),
    (7, 'Diagnóstico por Imagem');

INSERT INTO procedimento (id_procedimento, nome, categoria, preco_base, descricao, ativo) VALUES
    ( 1, 'Consulta clínica geral',                 'CONSULTA',     150.00, 'Avaliação clínica completa.', TRUE),
    ( 2, 'Consulta de retorno',                    'CONSULTA',      80.00, 'Reavaliação do mesmo quadro clínico.', TRUE),
    ( 3, 'Consulta especializada',                 'CONSULTA',     220.00, 'Dermatologia, cardiologia, exóticos etc.', TRUE),
    ( 4, 'Hemograma completo',                     'EXAME',         65.00, NULL, TRUE),
    ( 5, 'Perfil bioquímico (renal e hepático)',   'EXAME',        120.00, 'Ureia, creatinina, ALT, FA, albumina.', TRUE),
    ( 6, 'Urinálise',                              'EXAME',         55.00, NULL, TRUE),
    ( 7, 'Eletrocardiograma',                      'EXAME',        140.00, NULL, TRUE),
    ( 8, 'Citologia (pele/ouvido)',                'EXAME',         70.00, NULL, TRUE),
    ( 9, 'Radiografia (2 incidências)',            'IMAGEM',       160.00, NULL, TRUE),
    (10, 'Ultrassonografia abdominal',             'IMAGEM',       180.00, NULL, TRUE),
    (11, 'Vacina polivalente canina (V10)',        'VACINA',       110.00, NULL, TRUE),
    (12, 'Vacina antirrábica',                     'VACINA',        70.00, NULL, TRUE),
    (13, 'Vacina quádrupla felina (V4)',           'VACINA',       120.00, NULL, TRUE),
    (14, 'Castração (OSH/orquiectomia)',           'CIRURGIA',     650.00, 'Inclui anestesia geral.', TRUE),
    (15, 'Profilaxia dentária (tartarectomia)',    'CIRURGIA',     450.00, 'Inclui anestesia geral.', TRUE),
    (16, 'Gastropexia (correção de torção gástrica)', 'CIRURGIA', 2800.00, 'Cirurgia de emergência.', TRUE),
    (17, 'Fluidoterapia',                          'TERAPIA',       90.00, 'Por sessão/dia.', TRUE),
    (18, 'Diária de internação',                   'INTERNACAO',   250.00, NULL, TRUE),
    (19, 'Banho terapêutico',                      'TERAPIA',       80.00, 'Serviço descontinuado em 2025.', FALSE);

INSERT INTO medicamento (id_medicamento, nome_comercial, principio_ativo, concentracao, forma_farmaceutica, fabricante, controlado) VALUES
    ( 1, 'Apoquel',      'oclacitinib',                                   '5,4 mg',     'COMPRIMIDO',   'Zoetis',               FALSE),
    ( 2, 'Maxicam',      'meloxicam',                                     '2 mg',       'COMPRIMIDO',   'Ourofino',             FALSE),
    ( 3, 'Agemoxi CL',   'amoxicilina + clavulanato de potássio',         '250 mg',     'COMPRIMIDO',   'Agener União',         FALSE),
    ( 4, 'Simparic',     'sarolaner',                                     '40 mg',      'COMPRIMIDO',   'Zoetis',               FALSE),
    ( 5, 'Drontal Plus', 'praziquantel + pirantel + febantel',            '10 kg',      'COMPRIMIDO',   'Elanco',               FALSE),
    ( 6, 'Omeprazol',    'omeprazol',                                     '10 mg',      'CAPSULA',      'Farmácia de manipulação', FALSE),
    ( 7, 'Ondansetrona', 'cloridrato de ondansetrona',                    '2 mg/mL',    'INJETAVEL',    'Genérico',             FALSE),
    ( 8, 'Furosemida',   'furosemida',                                    '40 mg',      'COMPRIMIDO',   'Genérico',             FALSE),
    ( 9, 'Prediderm',    'prednisolona',                                  '20 mg',      'COMPRIMIDO',   'Ourofino',             FALSE),
    (10, 'Tramadol',     'cloridrato de tramadol',                        '50 mg',      'COMPRIMIDO',   'Genérico',             TRUE),
    (11, 'Otomax',       'gentamicina + betametasona + clotrimazol',      '15 g',       'POMADA',       'MSD Saúde Animal',     FALSE),
    (12, 'Tobramicina',  'tobramicina',                                   '3 mg/mL',    'COLIRIO',      'Genérico',             FALSE),
    (13, 'Enrofloxacino 2,5%', 'enrofloxacino',                           '25 mg/mL',   'SOLUCAO_ORAL', 'Genérico',             FALSE),
    (14, 'Vetmedin',     'pimobendan',                                    '1,25 mg',    'COMPRIMIDO',   'Boehringer Ingelheim', FALSE),
    (15, 'Revolution',   'selamectina',                                   '6% (45 mg)', 'PIPETA',       'Zoetis',               FALSE),
    (16, 'Gabapentina',  'gabapentina',                                   '100 mg',     'CAPSULA',      'Farmácia de manipulação', TRUE),
    (17, 'Vitamina C',   'ácido ascórbico',                               '200 mg/mL',  'SOLUCAO_ORAL', 'Farmácia de manipulação', FALSE);


-- =============================================================================
-- 2. PESSOAS E ANIMAIS
-- =============================================================================

INSERT INTO tutor (id_tutor, nome, cpf, data_nascimento, email, telefone,
                   logradouro, numero, complemento, bairro, cidade, uf, cep) VALUES
    ( 1, 'Mariana Oliveira Santos',  '10433218100', '1990-03-14', 'mariana.santos@email.com',  '34991234501', 'Av. Rondon Pacheco',     '1520', 'Apto 302', 'Tibery',          'Uberlândia', 'MG', '38405142'),
    ( 2, 'Ricardo Almeida Souza',    '96001338914', '1978-11-02', 'ricardo.souza@email.com',   '34992345602', 'Rua Goiás',              '845',  NULL,       'Centro',          'Uberlândia', 'MG', '38400027'),
    ( 3, 'José Carlos Pereira',      '08386379499', '1955-07-21', NULL,                        '3432345603',  'Rua Bernardo Guimarães', '77',   NULL,       'Fundinho',        'Uberlândia', 'MG', '38400212'),
    ( 4, 'Fernanda Lima Rocha',      '02654235114', '1987-01-30', 'fernanda.rocha@email.com',  '34994567804', 'Av. Nicomedes Alves dos Santos', '3300', 'Casa 12', 'Gávea', 'Uberlândia', 'MG', '38411106'),
    ( 5, 'Lucas Martins Ferreira',   '16155940789', '1995-09-09', 'lucas.ferreira@email.com',  '34995678905', 'Rua Rafael Marino Neto', '600',  'Bloco B',  'Jardim Karaíba',  'Uberlândia', 'MG', '38411186'),
    ( 6, 'Patrícia Gomes Ribeiro',   '81618495950', '1982-05-17', 'patricia.ribeiro@email.com','34996789006', 'Rua Tiradentes',         '1290', NULL,       'Fundinho',        'Uberlândia', 'MG', '38400186'),
    ( 7, 'Gustavo Henrique Silva',   '31034131656', '1999-12-24', 'gustavo.silva@email.com',   '34997890107', 'Av. João Naves de Ávila','2121', 'Apto 1104','Santa Mônica',    'Uberlândia', 'MG', '38408100'),
    ( 8, 'Beatriz Costa Moreira',    '47525534144', '2004-04-08', 'beatriz.moreira@email.com', '34998901208', 'Rua Duque de Caxias',    '310',  NULL,       'Centro',          'Uberlândia', 'MG', '38400142'),
    ( 9, 'André Luiz Cardoso',       '92832764851', '1973-08-15', 'andre.cardoso@email.com',   '34999012309', 'Av. Getúlio Vargas',     '955',  NULL,       'Martins',         'Uberlândia', 'MG', '38400299'),
    (10, 'Juliana Freitas Araújo',   '35030564160', '1992-02-27', 'juliana.araujo@email.com',  '34991122310', 'Rua Machado de Assis',   '48',   NULL,       'Brasil',          'Uberlândia', 'MG', '38400112'),
    (11, 'Helena Barbosa Nunes',     '39537672409', '1960-10-05', 'helena.nunes@email.com',    '34992233411', 'Rua Quinze de Novembro', '1777', NULL,       'Saraiva',         'Uberlândia', 'MG', '38408308'),
    (12, 'Rafael Teixeira Duarte',   '23884969692', '2001-06-19', 'rafael.duarte@email.com',   '34993344512', 'Av. Brasil',             '402',  'Apto 21',  'Centro',          'Araguari',   'MG', '38440000');

INSERT INTO animal (id_animal, id_tutor, id_raca, nome, sexo, data_nascimento, pelagem, castrado, microchip, observacoes) VALUES
    ( 1,  1,  2, 'Thor',     'M', '2019-04-12', 'Amarela',          TRUE,  '981083465787133', NULL),
    ( 2,  1,  8, 'Luna',     'F', '2021-08-03', 'Tricolor',         TRUE,  NULL,              NULL),
    ( 3,  1, 12, 'Pipoca',   'M', '2023-01-20', 'Cinza e amarela',  FALSE, NULL,              NULL),
    ( 4,  2,  3, 'Mel',      'F', '2017-06-15', 'Branca e dourada', TRUE,  '981015098393010', 'Dermatite atópica crônica.'),
    ( 5,  2, 10, 'Simba',    'M', '2020-02-10', 'Creme',            TRUE,  NULL,              NULL),
    ( 6,  3,  1, 'Bidu',     'M', '2014-09-01', 'Caramelo',         TRUE,  NULL,              'Paciente geriátrico.'),
    ( 7,  4,  4, 'Nina',     'F', '2022-03-30', 'Dourada',          FALSE, '981031051834738', NULL),
    ( 8,  4,  8, 'Frajola',  'M', '2012-05-05', 'Preta e branca',   TRUE,  NULL,              'Doença renal crônica.'),
    ( 9,  5,  6, 'Max',      'M', '2020-11-11', 'Preta e branca',   FALSE, '981029973763116', NULL),
    (10,  5, 16, 'Amora',    'F', '2024-02-14', 'Cinza',            FALSE, NULL,              NULL),
    (11,  6,  5, 'Bolt',     'M', '2018-07-07', 'Preta e marrom',   FALSE, NULL,              NULL),
    (12,  7,  7, 'Lola',     'F', '2021-12-01', 'Tigrada',          TRUE,  '981056670106513', 'Braquicefálica.'),
    (13,  7,  9, 'Mingau',   'M', '2019-10-10', 'Seal point',       TRUE,  NULL,              NULL),
    (14,  8, 14, 'Paçoca',   'M', '2025-03-01', 'Dourada',          FALSE, NULL,              NULL),
    (15,  9,  2, 'Zeus',     'M', '2016-01-25', 'Preta',            TRUE,  '981033872624731', 'Cardiopata.'),
    (16,  9, 11, 'Kiara',    'F', '2022-07-19', 'Tabby marrom',     FALSE, '981078108013267', NULL),
    (17, 10, 15, 'Fred',     'M', '2024-05-05', 'Branca e laranja', FALSE, NULL,              NULL),
    (18, 11,  3, 'Belinha',  'F', '2014-04-04', 'Branca',           TRUE,  NULL,              NULL),
    (19, 11,  8, 'Tom',      'M', '2023-09-09', 'Cinza rajada',     TRUE,  NULL,              NULL),
    (20, 12, 13, 'Kiwi',     'F', '2025-01-10', 'Verde',            FALSE, NULL,              NULL);

INSERT INTO veterinario (id_veterinario, nome, cpf, crmv, uf_crmv, email, telefone, data_admissao, ativo) VALUES
    (1, 'Dra. Ana Paula Ferreira',  '53287101269', '12045', 'MG', 'ana.ferreira@clinicavet.com',  '34991110001', '2017-02-01', TRUE),
    (2, 'Dr. Bruno Henrique Costa', '26916697857', '13388', 'MG', 'bruno.costa@clinicavet.com',   '34991110002', '2018-08-15', TRUE),
    (3, 'Dra. Carolina Mendes Rocha','48018451427', '14702', 'MG', 'carolina.rocha@clinicavet.com','34991110003', '2019-03-10', TRUE),
    (4, 'Dr. Diego Alves Martins',  '62704828105', '15921', 'MG', 'diego.martins@clinicavet.com', '34991110004', '2021-01-04', TRUE),
    (5, 'Dra. Elisa Tavares Lima',  '48932528870', '9876',  'GO', 'elisa.lima@clinicavet.com',    '34991110005', '2022-06-01', TRUE),
    (6, 'Dr. Fábio Nogueira Prado', '09570154373', '11230', 'MG', 'fabio.prado@clinicavet.com',   '34991110006', '2016-05-02', TRUE);

INSERT INTO veterinario_especialidade (id_veterinario, id_especialidade) VALUES
    (1, 1), (1, 3),          -- Ana: clínica geral e dermatologia
    (2, 2), (2, 5),          -- Bruno: cirurgia e ortopedia
    (3, 1), (3, 4),          -- Carolina: clínica geral e cardiologia
    (4, 1), (4, 6),          -- Diego: clínica geral e exóticos
    (5, 7),                  -- Elisa: diagnóstico por imagem
    (6, 1);                  -- Fábio: clínica geral


-- =============================================================================
-- 3. AGENDAMENTOS
--    Todos entram como AGENDADO (ou CANCELADO). Quando o atendimento é
--    registrado, o gatilho trg_atendimento_vincula_agendamento muda o status
--    para REALIZADO automaticamente.
-- =============================================================================

INSERT INTO agendamento (id_agendamento, id_animal, id_veterinario, data_hora_inicio, data_hora_fim, tipo, motivo, status, motivo_cancelamento) VALUES
    -- viram atendimento (REALIZADO via gatilho)
    ( 1,  6, 6, '2026-01-08 09:00-03', '2026-01-08 09:30-03', 'CONSULTA',  'Check-up geriátrico',                     'AGENDADO', NULL),
    ( 2,  1, 1, '2026-01-15 10:00-03', '2026-01-15 10:20-03', 'VACINACAO', 'Vacinação anual (V10 e antirrábica)',     'AGENDADO', NULL),
    ( 3,  4, 1, '2026-01-22 14:00-03', '2026-01-22 14:30-03', 'CONSULTA',  'Coceira intensa e lambedura de patas',    'AGENDADO', NULL),
    ( 4,  8, 3, '2026-02-05 09:30-03', '2026-02-05 10:00-03', 'CONSULTA',  'Emagrecimento e muita sede',              'AGENDADO', NULL),
    ( 5,  3, 4, '2026-02-19 15:00-03', '2026-02-19 15:30-03', 'CONSULTA',  'Arrancando as próprias penas',            'AGENDADO', NULL),
    ( 6,  2, 1, '2026-03-03 10:00-03', '2026-03-03 10:20-03', 'VACINACAO', 'Vacinação anual (V4 e antirrábica)',      'AGENDADO', NULL),
    ( 7,  7, 2, '2026-03-12 13:30-03', '2026-03-12 15:30-03', 'CIRURGIA',  'Castração eletiva (OSH)',                 'AGENDADO', NULL),
    ( 8,  5, 1, '2026-03-20 09:00-03', '2026-03-20 09:30-03', 'CONSULTA',  'Olho lacrimejando e avermelhado',         'AGENDADO', NULL),
    ( 9, 15, 3, '2026-03-27 11:00-03', '2026-03-27 11:45-03', 'CONSULTA',  'Tosse e cansaço nos passeios',            'AGENDADO', NULL),
    (10, 10, 4, '2026-04-14 10:30-03', '2026-04-14 11:00-03', 'CONSULTA',  'Check-up e avaliação dentária',           'AGENDADO', NULL),
    (11,  4, 1, '2026-04-23 09:00-03', '2026-04-23 09:20-03', 'RETORNO',   'Retorno da dermatite',                    'AGENDADO', NULL),
    (12, 12, 3, '2026-05-06 14:00-03', '2026-05-06 14:30-03', 'CONSULTA',  'Ronco alto e cansaço',                    'AGENDADO', NULL),
    (13,  8, 3, '2026-05-14 08:30-03', '2026-05-14 09:00-03', 'RETORNO',   'Acompanhamento renal',                    'AGENDADO', NULL),
    (14, 13, 1, '2026-05-20 10:00-03', '2026-05-20 10:20-03', 'VACINACAO', 'Vacinação anual (V4 e antirrábica)',      'AGENDADO', NULL),
    (15, 16, 5, '2026-06-02 15:30-03', '2026-06-02 16:15-03', 'EXAME',     'Ultrassonografia abdominal',              'AGENDADO', NULL),
    (16,  6, 6, '2026-06-09 09:00-03', '2026-06-09 09:20-03', 'RETORNO',   'Retorno do check-up geriátrico',          'AGENDADO', NULL),
    (17, 17, 4, '2026-06-18 11:00-03', '2026-06-18 11:30-03', 'CONSULTA',  'Dificuldade para comer',                  'AGENDADO', NULL),
    (18,  1, 2, '2026-07-01 13:00-03', '2026-07-01 15:00-03', 'CIRURGIA',  'Profilaxia dentária',                     'AGENDADO', NULL),
    (19, 18, 1, '2026-07-15 09:30-03', '2026-07-15 10:00-03', 'CONSULTA',  'Balança a cabeça; ouvido com odor',       'AGENDADO', NULL),
    (20, 19, 1, '2026-07-29 10:00-03', '2026-07-29 10:20-03', 'VACINACAO', 'Primeira vacinação anual',                'AGENDADO', NULL),
    (21,  7, 5, '2026-08-25 14:00-03', '2026-08-25 14:45-03', 'EXAME',     'Radiografia de quadril',                  'AGENDADO', NULL),
    (22, 20, 4, '2026-09-03 09:00-03', '2026-09-03 09:30-03', 'CONSULTA',  'Check-up',                                'AGENDADO', NULL),
    (23, 15, 3, '2026-09-16 10:30-03', '2026-09-16 10:50-03', 'RETORNO',   'Acompanhamento cardiológico',             'AGENDADO', NULL),
    (24, 14, 1, '2026-09-30 15:00-03', '2026-09-30 15:30-03', 'CONSULTA',  'Falhas no pelo e feridas',                'AGENDADO', NULL),
    (25,  5, 5, '2026-10-08 08:30-03', '2026-10-08 09:15-03', 'EXAME',     'Ultrassonografia renal',                  'AGENDADO', NULL),
    (26, 12, 3, '2026-10-27 09:00-03', '2026-10-27 09:30-03', 'CONSULTA',  'Respiração ofegante',                     'AGENDADO', NULL),
    -- cancelados
    (27, 11, 1, '2026-02-20 16:00-03', '2026-02-20 16:30-03', 'CONSULTA',  'Check-up',                                'CANCELADO', 'Tutor em viagem'),
    (28, 16, 2, '2026-05-28 09:00-03', '2026-05-28 11:00-03', 'CIRURGIA',  'Castração eletiva (OSH)',                 'CANCELADO', 'Animal no cio; cirurgia adiada'),
    (29,  1, 1, '2026-09-10 10:00-03', '2026-09-10 10:30-03', 'CONSULTA',  'Check-up',                                'CANCELADO', 'Veterinária em congresso'),
    -- passados sem atendimento (não comparecimento) -> tratados no bloco de UPDATE
    (30,  6, 1, '2026-07-20 09:00-03', '2026-07-20 09:20-03', 'RETORNO',   'Retorno',                                 'AGENDADO', NULL),
    (31, 19, 1, '2026-10-14 14:00-03', '2026-10-14 14:20-03', 'RETORNO',   'Reforço vacinal',                         'AGENDADO', NULL),
    -- futuros
    (32,  4, 1, '2026-11-04 10:00-03', '2026-11-04 10:20-03', 'RETORNO',   'Reavaliação da dermatite',                'AGENDADO', NULL),
    (33, 15, 3, '2026-11-10 10:30-03', '2026-11-10 10:50-03', 'RETORNO',   'Acompanhamento cardiológico',             'AGENDADO', NULL),
    (34, 10, 4, '2026-11-12 14:00-03', '2026-11-12 14:30-03', 'CONSULTA',  'Avaliação dentária',                      'AGENDADO', NULL),
    (35, 16, 2, '2026-11-18 09:00-03', '2026-11-18 11:00-03', 'CIRURGIA',  'Castração eletiva (OSH)',                 'AGENDADO', NULL),
    (36,  7, 5, '2026-11-25 15:00-03', '2026-11-25 15:45-03', 'EXAME',     'Ultrassonografia abdominal',              'AGENDADO', NULL),
    (37,  9, 2, '2026-11-09 14:00-03', '2026-11-09 14:20-03', 'RETORNO',   'Retorno pós-cirúrgico (gastropexia)',     'AGENDADO', NULL),
    (38,  3, 4, '2026-12-02 16:00-03', '2026-12-02 16:30-03', 'RETORNO',   'Retorno comportamental',                  'AGENDADO', NULL),
    (39,  1, 1, '2027-01-14 10:00-03', '2027-01-14 10:20-03', 'VACINACAO', 'Vacinação anual',                         'AGENDADO', NULL),
    (40, 17, 4, '2026-11-20 11:00-03', '2026-11-20 11:30-03', 'RETORNO',   'Retorno',                                 'CANCELADO', 'Tutor desmarcou por telefone'),
    (41,  8, 3, '2026-11-03 08:30-03', '2026-11-03 09:00-03', 'RETORNO',   'Acompanhamento renal',                    'AGENDADO', NULL);


-- =============================================================================
-- 4. ATENDIMENTOS
--    30 atendimentos entre jan e out/2026; 4 sem agendamento (urgência/emergência).
-- =============================================================================

INSERT INTO atendimento (id_atendimento, id_animal, id_veterinario, id_agendamento,
                         data_hora_inicio, data_hora_fim, carater, status,
                         queixa_principal, anamnese, diagnostico, peso_kg, temperatura_c) VALUES
    ( 1,  6, 6,    1, '2026-01-08 09:05-03', '2026-01-08 09:35-03', 'ELETIVO',    'FINALIZADO', 'Check-up geriátrico',                 'Apetite normal, dorme mais que o habitual.', 'Hígido para a idade; solicitado acompanhamento semestral.', 14.500, 38.6),
    ( 2,  1, 1,    2, '2026-01-15 10:00-03', '2026-01-15 10:20-03', 'ELETIVO',    'FINALIZADO', 'Vacinação anual',                     NULL, 'Saudável. Vacinas aplicadas.',                               32.100, 38.4),
    ( 3,  4, 1,    3, '2026-01-22 14:00-03', '2026-01-22 14:35-03', 'ELETIVO',    'FINALIZADO', 'Prurido intenso e lambedura de patas','Piora no verão; sem troca de ração.', 'Dermatite atópica canina.',                               6.200, 38.7),
    ( 4,  8, 3,    4, '2026-02-05 09:30-03', '2026-02-05 10:10-03', 'ELETIVO',    'FINALIZADO', 'Emagrecimento e polidipsia',          'Perdeu cerca de 1 kg em 3 meses.', 'Doença renal crônica (estágio IRIS 2).',                 4.300, 38.2),
    ( 5,  9, 2, NULL, '2026-02-10 08:00-03', '2026-02-10 08:50-03', 'URGENCIA',   'FINALIZADO', 'Claudicação do membro posterior direito', 'Começou após corrida no parque.', 'Distensão muscular; sem fratura na radiografia.',      22.000, 38.9),
    ( 6,  3, 4,    5, '2026-02-19 15:00-03', '2026-02-19 15:30-03', 'ELETIVO',    'FINALIZADO', 'Arrancamento de penas',               'Vive sozinho em gaiola pequena.', 'Picacismo por estresse e infecção bacteriana secundária.', 0.090, 41.5),
    ( 7,  2, 1,    6, '2026-03-03 10:00-03', '2026-03-03 10:20-03', 'ELETIVO',    'FINALIZADO', 'Vacinação anual',                     NULL, 'Saudável. Vacinas aplicadas.',                                4.100, 38.5),
    ( 8,  7, 2,    7, '2026-03-12 13:30-03', '2026-03-12 15:20-03', 'ELETIVO',    'FINALIZADO', 'Castração eletiva',                   NULL, 'OSH sem intercorrências.',                                   27.300, 38.3),
    ( 9,  5, 1,    8, '2026-03-20 09:00-03', '2026-03-20 09:25-03', 'ELETIVO',    'FINALIZADO', 'Epífora e hiperemia ocular',          NULL, 'Conjuntivite bacteriana.',                                    4.800, 38.6),
    (10, 15, 3,    9, '2026-03-27 11:00-03', '2026-03-27 11:50-03', 'ELETIVO',    'FINALIZADO', 'Tosse e intolerância ao exercício',   'Tosse noturna há 2 semanas.', 'Doença valvar mitral (ACVIM B2).',                       38.400, 38.5),
    (11, 11, 1, NULL, '2026-04-07 16:00-03', '2026-04-07 17:30-03', 'URGENCIA',   'FINALIZADO', 'Vômito e diarreia há 24 h',           'Comeu lixo no dia anterior.', 'Gastroenterite aguda por indiscrição alimentar.',        4.100, 39.4),
    (12, 10, 4,   10, '2026-04-14 10:30-03', '2026-04-14 11:00-03', 'ELETIVO',    'FINALIZADO', 'Check-up e avaliação dentária',       NULL, 'Sobrecrescimento leve de incisivos.',                          1.650, 38.8),
    (13,  4, 1,   11, '2026-04-23 09:00-03', '2026-04-23 09:20-03', 'ELETIVO',    'FINALIZADO', 'Retorno da dermatite',                NULL, 'Dermatite atópica controlada.',                               6.300, 38.5),
    (14, 12, 3,   12, '2026-05-06 14:00-03', '2026-05-06 14:30-03', 'ELETIVO',    'FINALIZADO', 'Ronco e cansaço',                     NULL, 'Síndrome braquicefálica leve.',                              11.800, 38.9),
    (15,  8, 3,   13, '2026-05-14 08:30-03', '2026-05-14 09:10-03', 'ELETIVO',    'FINALIZADO', 'Acompanhamento renal',                NULL, 'DRC estável.',                                                4.200, 38.1),
    (16, 13, 1,   14, '2026-05-20 10:00-03', '2026-05-20 10:20-03', 'ELETIVO',    'FINALIZADO', 'Vacinação anual',                     NULL, 'Saudável. Vacinas aplicadas.',                                5.000, 38.4),
    (17, 16, 5,   15, '2026-06-02 15:30-03', '2026-06-02 16:10-03', 'ELETIVO',    'FINALIZADO', 'Ultrassonografia abdominal',          NULL, 'Sem alterações ultrassonográficas.',                          5.600, 38.6),
    (18,  6, 6,   16, '2026-06-09 09:00-03', '2026-06-09 09:25-03', 'ELETIVO',    'FINALIZADO', 'Retorno do check-up',                 'Rigidez ao levantar pela manhã.', 'Sopro cardíaco leve e osteoartrose.',                    14.200, 38.4),
    (19, 17, 4,   17, '2026-06-18 11:00-03', '2026-06-18 11:30-03', 'ELETIVO',    'FINALIZADO', 'Dificuldade para comer',              'Dieta sem suplementação.', 'Hipovitaminose C.',                                          0.950, 38.9),
    (20,  1, 2,   18, '2026-07-01 13:00-03', '2026-07-01 14:40-03', 'ELETIVO',    'FINALIZADO', 'Profilaxia dentária',                 NULL, 'Doença periodontal grau 2; tartarectomia realizada.',        32.800, 38.3),
    (21, 18, 1,   19, '2026-07-15 09:30-03', '2026-07-15 10:00-03', 'ELETIVO',    'FINALIZADO', 'Meneios cefálicos e odor no ouvido',  NULL, 'Otite externa por Malassezia.',                               7.400, 38.8),
    (22, 19, 1,   20, '2026-07-29 10:00-03', '2026-07-29 10:20-03', 'ELETIVO',    'FINALIZADO', 'Vacinação anual',                     NULL, 'Saudável. Vacinas aplicadas.',                                4.400, 38.6),
    (23,  8, 3, NULL, '2026-08-12 17:00-03', '2026-08-14 18:00-03', 'EMERGENCIA', 'FINALIZADO', 'Prostração e anorexia',               'Não come há 2 dias.', 'Crise urêmica (DRC descompensada); internado 2 dias.',          3.700, 37.4),
    (24,  7, 5,   21, '2026-08-25 14:00-03', '2026-08-25 14:40-03', 'ELETIVO',    'FINALIZADO', 'Radiografia de quadril',              NULL, 'Sem sinais de displasia coxofemoral.',                       27.900, 38.5),
    (25, 20, 4,   22, '2026-09-03 09:00-03', '2026-09-03 09:30-03', 'ELETIVO',    'FINALIZADO', 'Check-up',                            NULL, 'Saudável.',                                                   0.035, 41.8),
    (26, 15, 3,   23, '2026-09-16 10:30-03', '2026-09-16 10:55-03', 'ELETIVO',    'FINALIZADO', 'Acompanhamento cardiológico',         NULL, 'Doença valvar mitral compensada.',                           37.900, 38.4),
    (27, 14, 1,   24, '2026-09-30 15:00-03', '2026-09-30 15:30-03', 'ELETIVO',    'FINALIZADO', 'Falhas no pelo e feridas',            NULL, 'Dermatite por ácaros (sarna demodécica).',                    0.140, 37.9),
    -- registrado EM_ABERTO e finalizado no bloco de UPDATE (exemplo)
    (28,  5, 5,   25, '2026-10-08 08:30-03', NULL,                  'ELETIVO',    'EM_ABERTO',  'Ultrassonografia renal',              NULL, NULL,                                                          4.900, 38.5),
    -- em aberto (internações em curso)
    (29,  9, 2, NULL, '2026-10-26 07:30-03', NULL,                  'EMERGENCIA', 'EM_ABERTO',  'Abdômen distendido e ânsia improdutiva', 'Correu logo após comer.', 'Dilatação-vólvulo gástrica; gastropexia realizada, internado.', 22.400, 39.1),
    (30, 12, 3,   26, '2026-10-27 09:00-03', NULL,                  'ELETIVO',    'EM_ABERTO',  'Respiração ofegante',                 'Piora com o calor.', 'Síndrome braquicefálica; internada em observação.',        12.000, 39.6);


-- =============================================================================
-- 5. PROCEDIMENTOS REALIZADOS
--    valor_unitario omitido => gatilho usa o preco_base vigente.
-- =============================================================================

INSERT INTO atendimento_procedimento (id_atendimento, id_procedimento, quantidade) VALUES
    ( 1,  1, 1), ( 1,  4, 1), ( 1,  5, 1),
    ( 2,  1, 1), ( 2, 11, 1), ( 2, 12, 1),
    ( 3,  3, 1), ( 3,  8, 1),
    ( 4,  1, 1), ( 4,  4, 1), ( 4,  5, 1), ( 4,  6, 1),
    ( 5,  1, 1), ( 5,  9, 1),
    ( 6,  3, 1),
    ( 7,  1, 1), ( 7, 13, 1), ( 7, 12, 1),
    ( 8, 14, 1), ( 8,  4, 1), ( 8, 17, 1),
    ( 9,  1, 1),
    (10,  3, 1), (10,  7, 1), (10,  9, 1),
    (11,  1, 1), (11, 17, 1), (11,  4, 1),
    (12,  3, 1), (12,  9, 1),
    (14,  1, 1), (14,  9, 1),
    (15,  2, 1), (15,  5, 1), (15, 17, 1),
    (16,  1, 1), (16, 13, 1), (16, 12, 1),
    (17, 10, 1),
    (18,  2, 1), (18,  7, 1),
    (19,  3, 1),
    (20, 15, 1), (20,  4, 1), (20,  5, 1), (20, 17, 1),
    (21,  1, 1), (21,  8, 1),
    (22,  1, 1), (22, 13, 1), (22, 12, 1),
    (23, 18, 2), (23, 17, 2), (23,  4, 1), (23,  5, 1),
    (24,  9, 1),
    (25,  3, 1),
    (26,  2, 1), (26,  7, 1),
    (27,  3, 1), (27,  8, 1),
    (28, 10, 1), (28,  4, 1),
    (29,  1, 1), (29,  9, 1), (29, 16, 1), (29, 17, 2), (29, 18, 1),
    (30,  1, 1), (30,  9, 1), (30, 18, 1);

-- Valor negociado (sobrescreve o preço de tabela): retorno gratuito em até 30 dias
INSERT INTO atendimento_procedimento (id_atendimento, id_procedimento, quantidade, valor_unitario, observacao) VALUES
    (13, 2, 1, 0.00, 'Retorno gratuito (até 30 dias da consulta)');


-- =============================================================================
-- 6. PRESCRIÇÕES
-- =============================================================================

INSERT INTO prescricao (id_atendimento, id_medicamento, dose_quantidade, dose_unidade, via_administracao, frequencia_horas, duracao_dias, instrucoes) VALUES
    ( 2,  4, 1,    'comprimido', 'ORAL',        720, NULL, 'Antipulgas e carrapatos: repetir todo mês.'),
    ( 2,  5, 3,    'comprimido', 'ORAL',         24,    1, 'Vermífugo em dose única (1 comprimido a cada 10 kg); repetir em 15 dias.'),
    ( 3,  1, 1,    'comprimido', 'ORAL',         12,   14, 'Após 14 dias, reduzir para 1x ao dia.'),
    ( 4,  6, 1,    'capsula',    'ORAL',         24,   30, 'Administrar em jejum.'),
    ( 5,  2, 1,    'comprimido', 'ORAL',         24,    5, 'Dar após a refeição.'),
    ( 5, 10, 1,    'comprimido', 'ORAL',         12,    5, NULL),
    ( 6, 13, 2,    'gota',       'ORAL',         24,    7, 'Pingar direto no bico.'),
    ( 7, 15, 1,    'pipeta',     'TOPICA',      720, NULL, 'Aplicar na nuca, uma vez por mês.'),
    ( 8,  2, 1,    'comprimido', 'ORAL',         24,    3, 'Dar após a refeição.'),
    ( 8,  3, 2,    'comprimido', 'ORAL',         12,    7, NULL),
    ( 8, 10, 2,    'comprimido', 'ORAL',          8,    3, 'Somente se houver sinais de dor.'),
    ( 9, 12, 1,    'gota',       'OFTALMICA',     8,    7, 'Limpar o olho antes de aplicar.'),
    (10, 14, 1,    'comprimido', 'ORAL',         12, NULL, 'Uso contínuo; 1 h antes das refeições.'),
    (10,  8, 1,    'comprimido', 'ORAL',         12,   30, NULL),
    (11,  7, 0.4,  'mL',         'SUBCUTANEA',   12,    2, NULL),
    (11,  6, 1,    'capsula',    'ORAL',         24,    7, 'Administrar em jejum.'),
    (12,  2, 0.25, 'comprimido', 'ORAL',         24,    3, 'Fracionar o comprimido.'),
    (14,  9, 0.5,  'comprimido', 'ORAL',         24,    5, NULL),
    (16, 15, 1,    'pipeta',     'TOPICA',      720, NULL, 'Aplicar na nuca, uma vez por mês.'),
    (18, 14, 1,    'comprimido', 'ORAL',         12, NULL, 'Uso contínuo.'),
    (18, 16, 1,    'capsula',    'ORAL',         12,   30, NULL),
    (19, 17, 0.5,  'mL',         'ORAL',         24,   14, NULL),
    (20,  3, 3,    'comprimido', 'ORAL',         12,    7, NULL),
    (20,  2, 3,    'comprimido', 'ORAL',         24,    3, NULL),
    (21, 11, 4,    'gota',       'OTOLOGICA',    12,   10, 'Limpar o conduto auditivo antes de aplicar.'),
    (22, 15, 1,    'pipeta',     'TOPICA',      720, NULL, 'Aplicar na nuca, uma vez por mês.'),
    (23,  7, 0.3,  'mL',         'SUBCUTANEA',   12,    3, NULL),
    (26, 14, 1.5,  'comprimido', 'ORAL',         12, NULL, 'Uso contínuo; dose ajustada.'),
    (26,  8, 1,    'comprimido', 'ORAL',         12, NULL, 'Uso contínuo.'),
    (29, 10, 2,    'comprimido', 'ORAL',          8,    5, NULL),
    (29,  3, 2,    'comprimido', 'ORAL',         12,   10, NULL),
    (29,  7, 2,    'mL',         'INTRAVENOSA',  12,    3, NULL),
    (30,  9, 0.5,  'comprimido', 'ORAL',         24,    3, NULL);


-- =============================================================================
-- 7. AJUSTE DAS SEQUÊNCIAS IDENTITY
--    Como as chaves foram informadas manualmente, as sequências precisam
--    continuar a partir do maior valor usado.
-- =============================================================================

SELECT setval(pg_get_serial_sequence('clinica.especie',       'id_especie'),       (SELECT max(id_especie)       FROM especie));
SELECT setval(pg_get_serial_sequence('clinica.raca',          'id_raca'),          (SELECT max(id_raca)          FROM raca));
SELECT setval(pg_get_serial_sequence('clinica.especialidade', 'id_especialidade'), (SELECT max(id_especialidade) FROM especialidade));
SELECT setval(pg_get_serial_sequence('clinica.procedimento',  'id_procedimento'),  (SELECT max(id_procedimento)  FROM procedimento));
SELECT setval(pg_get_serial_sequence('clinica.medicamento',   'id_medicamento'),   (SELECT max(id_medicamento)   FROM medicamento));
SELECT setval(pg_get_serial_sequence('clinica.tutor',         'id_tutor'),         (SELECT max(id_tutor)         FROM tutor));
SELECT setval(pg_get_serial_sequence('clinica.animal',        'id_animal'),        (SELECT max(id_animal)        FROM animal));
SELECT setval(pg_get_serial_sequence('clinica.veterinario',   'id_veterinario'),   (SELECT max(id_veterinario)   FROM veterinario));
SELECT setval(pg_get_serial_sequence('clinica.agendamento',   'id_agendamento'),   (SELECT max(id_agendamento)   FROM agendamento));
SELECT setval(pg_get_serial_sequence('clinica.atendimento',   'id_atendimento'),   (SELECT max(id_atendimento)   FROM atendimento));


-- =============================================================================
-- 8. EXEMPLOS DE UPDATE (situações reais do dia a dia da clínica)
-- =============================================================================

-- 8.1 Finalizar um atendimento: o exame do Simba (atendimento 28) foi
--     concluído e o laudo registrado.
UPDATE atendimento
   SET status        = 'FINALIZADO',
       data_hora_fim = '2026-10-08 09:10-03',
       diagnostico   = 'Rins com cistos múltiplos compatíveis com doença renal policística (DRP).'
 WHERE id_atendimento = 28;

-- 8.2 Registrar óbito: o Frajola (animal 8) faleceu em 20/08/2026.
UPDATE animal
   SET data_obito  = '2026-08-20',
       observacoes = observacoes || ' Óbito em 20/08/2026 por complicações da DRC.'
 WHERE id_animal = 8;

-- 8.3 ...e cancelar os agendamentos futuros dele, guardando o motivo.
UPDATE agendamento ag
   SET status              = 'CANCELADO',
       motivo_cancelamento = 'Óbito do paciente'
  FROM animal an
 WHERE an.id_animal      = ag.id_animal
   AND an.data_obito    IS NOT NULL
   AND ag.status         = 'AGENDADO'
   AND ag.data_hora_inicio > an.data_obito;

-- 8.4 Não comparecimento: agendamentos que já passaram, continuam AGENDADO
--     e não geraram atendimento são cancelados automaticamente.
UPDATE agendamento ag
   SET status              = 'CANCELADO',
       motivo_cancelamento = 'Não comparecimento (no-show)'
 WHERE ag.status = 'AGENDADO'
   AND ag.data_hora_fim < TIMESTAMPTZ '2026-10-27 18:00-03'   -- "agora" na linha do tempo dos dados
   AND NOT EXISTS (SELECT 1 FROM atendimento at WHERE at.id_agendamento = ag.id_agendamento);

-- 8.5 Reajuste de 8% na tabela de vacinas. Os atendimentos antigos NÃO
--     mudam, porque o valor cobrado está gravado em atendimento_procedimento.
UPDATE procedimento
   SET preco_base = round(preco_base * 1.08, 2)
 WHERE categoria = 'VACINA';

-- 8.6 Desligamento de profissional: o Dr. Fábio saiu da clínica. O cadastro
--     é inativado (e não apagado) para preservar o histórico de atendimentos.
UPDATE veterinario
   SET ativo = FALSE
 WHERE id_veterinario = 6;

-- 8.7 Atualização cadastral do tutor (mudou de telefone e de e-mail).
UPDATE tutor
   SET telefone = '34988776655',
       email    = 'jose.pereira@email.com'
 WHERE cpf = '08386379499';


-- =============================================================================
-- 9. EXEMPLOS DE DELETE
-- =============================================================================

-- 9.1 Prescrição lançada no atendimento errado: o tramadol foi registrado
--     por engano no atendimento do hamster Paçoca e precisa ser removido.
INSERT INTO prescricao (id_atendimento, id_medicamento, dose_quantidade, dose_unidade, via_administracao, frequencia_horas, duracao_dias)
VALUES (27, 10, 1, 'comprimido', 'ORAL', 12, 5);           -- lançamento indevido

DELETE FROM prescricao
 WHERE id_atendimento = 27
   AND id_medicamento = 10;

-- 9.2 Procedimento cobrado em duplicidade: a citologia foi lançada no
--     atendimento 9, mas não foi realizada.
INSERT INTO atendimento_procedimento (id_atendimento, id_procedimento, quantidade)
VALUES (9, 8, 1);                                         -- lançamento indevido

DELETE FROM atendimento_procedimento
 WHERE id_atendimento  = 9
   AND id_procedimento = 8;

-- 9.3 Cadastro duplicado de tutor, feito no balcão, sem nenhum animal
--     vinculado. A condição NOT EXISTS garante que só cadastros "órfãos"
--     sejam removidos (tutores com animais são protegidos pela FK RESTRICT).
INSERT INTO tutor (nome, cpf, telefone, cidade, uf)
VALUES ('Mariana O. Santos', '03911718284', '34991234501', 'Uberlândia', 'MG');

DELETE FROM tutor t
 WHERE t.nome ILIKE 'Mariana O%'
   AND NOT EXISTS (SELECT 1 FROM animal a WHERE a.id_tutor = t.id_tutor);


-- =============================================================================
-- 10. TESTES DE INTEGRIDADE (descomente para ver cada regra barrando o erro)
-- =============================================================================

-- Conflito de agenda: Dra. Ana já tem horário em 04/11/2026 às 10:00.
-- INSERT INTO agendamento (id_animal, id_veterinario, data_hora_inicio, data_hora_fim)
-- VALUES (2, 1, '2026-11-04 10:10-03', '2026-11-04 10:30-03');
--   -> ERROR: conflicting key value violates exclusion constraint "ex_agendamento_conflito_vet"

-- Atendimento a partir de agendamento cancelado (agendamento 27).
-- INSERT INTO atendimento (id_animal, id_veterinario, id_agendamento, queixa_principal)
-- VALUES (11, 1, 27, 'Teste');
--   -> ERROR: Agendamento 27 está CANCELADO e não pode gerar atendimento.

-- Atendimento vinculado a agendamento de OUTRO animal (agendamento 32 é da Mel).
-- INSERT INTO atendimento (id_animal, id_veterinario, id_agendamento, queixa_principal)
-- VALUES (1, 1, 32, 'Teste');
--   -> ERROR: insert or update on table "atendimento" violates foreign key constraint "fk_atendimento_agendamento"

-- Atendimento após o óbito (Frajola).
-- INSERT INTO atendimento (id_animal, id_veterinario, queixa_principal, data_hora_inicio)
-- VALUES (8, 3, 'Teste', '2026-10-01 10:00-03');
--   -> ERROR: Animal 8 teve óbito registrado em 2026-08-20 ...

-- Remover tutor que possui animais.
-- DELETE FROM tutor WHERE id_tutor = 1;
--   -> ERROR: update or delete on table "tutor" violates foreign key constraint "fk_animal_tutor"

-- Cancelar sem informar o motivo.
-- UPDATE agendamento SET status = 'CANCELADO' WHERE id_agendamento = 32;
--   -> ERROR: new row for relation "agendamento" violates check constraint "ck_agendamento_cancel"

-- Cancelar um agendamento que já virou atendimento (agendamento 2).
-- UPDATE agendamento SET status = 'CANCELADO', motivo_cancelamento = 'Teste' WHERE id_agendamento = 2;
--   -> ERROR: Agendamento 2 já possui atendimento e deve permanecer REALIZADO.

COMMIT;
