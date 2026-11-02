-- =============================================================================
--  Sistema de Gestão de Clínica Veterinária
--  03_consultas.sql — consultas de gestão clínica e administrativa
-- -----------------------------------------------------------------------------
--  Pré-requisito: 01_ddl.sql e 02_dml.sql executados.
--  No pgAdmin, selecione uma consulta e pressione F5 para executar só ela.
-- =============================================================================

SET search_path TO clinica;


-- =============================================================================
-- Q1. Animais com atendimentos em aberto ou agendamentos futuros
-- -----------------------------------------------------------------------------
-- Uso: painel da recepção — quem está internado/em atendimento agora e quem
-- tem horário marcado. As duas condições ficam no WHERE com IN + subconsulta;
-- as colunas de detalhe são subconsultas escalares correlacionadas.
-- =============================================================================
SELECT a.animal,
       a.especie,
       a.tutor,
       a.telefone_tutor,
       (SELECT COUNT(*)
          FROM atendimento at
         WHERE at.id_animal = a.id_animal
           AND at.status    = 'EM_ABERTO')          AS atendimentos_em_aberto,
       (SELECT MIN(ag.data_hora_inicio)
          FROM agendamento ag
         WHERE ag.id_animal = a.id_animal
           AND ag.status    = 'AGENDADO'
           AND ag.data_hora_inicio > now())         AS proximo_agendamento
  FROM vw_animal a
 WHERE a.id_animal IN (SELECT id_animal
                         FROM atendimento
                        WHERE status = 'EM_ABERTO')
    OR a.id_animal IN (SELECT id_animal
                         FROM agendamento
                        WHERE status = 'AGENDADO'
                          AND data_hora_inicio > now())
 ORDER BY atendimentos_em_aberto DESC, proximo_agendamento;


-- =============================================================================
-- Q2. Ranking de veterinários por quantidade de atendimentos em um período
-- -----------------------------------------------------------------------------
-- Uso: produtividade da equipe. Período: 01/01/2026 a 31/10/2026 (para mudar,
-- troque as datas nos três lugares). O filtro de data fica no ON do LEFT JOIN
-- para que veterinários sem atendimento no período também apareçam, com zero.
-- =============================================================================
SELECT v.nome                         AS veterinario,
       v.ativo,
       COUNT(at.id_atendimento)       AS atendimentos,
       COUNT(DISTINCT at.id_animal)   AS pacientes_distintos,
       (SELECT COUNT(*)
          FROM atendimento a2
         WHERE a2.id_veterinario   = v.id_veterinario
           AND a2.carater         <> 'ELETIVO'
           AND a2.data_hora_inicio >= '2026-01-01'
           AND a2.data_hora_inicio <  '2026-11-01') AS urgencias_emergencias,
       ROUND(100.0 * COUNT(at.id_atendimento) /
             (SELECT COUNT(*)
                FROM atendimento
               WHERE data_hora_inicio >= '2026-01-01'
                 AND data_hora_inicio <  '2026-11-01'), 1) AS percentual
  FROM veterinario v
  LEFT JOIN atendimento at
         ON at.id_veterinario    = v.id_veterinario
        AND at.data_hora_inicio >= '2026-01-01'
        AND at.data_hora_inicio <  '2026-11-01'     -- até 31/10 inclusive
 GROUP BY v.id_veterinario, v.nome, v.ativo
 ORDER BY atendimentos DESC, v.nome;


-- =============================================================================
-- Q3. Tutores que possuem mais de um animal e o histórico resumido de
--     procedimentos
-- -----------------------------------------------------------------------------
-- Uso: relacionamento com clientes de maior vínculo (planos família). Para
-- cada tutor com 2+ animais: cada procedimento já feito nos animais dele,
-- quantas vezes, quanto custou e quando foi a última vez.
-- A subconsulta com GROUP BY + HAVING seleciona os tutores com mais de um animal.
-- =============================================================================
SELECT t.nome                                   AS tutor,
       (SELECT COUNT(*)
          FROM animal a2
         WHERE a2.id_tutor = t.id_tutor)        AS qtd_animais,
       p.nome                                   AS procedimento,
       SUM(ap.quantidade)                       AS vezes,
       SUM(ap.quantidade * ap.valor_unitario)   AS valor_total,
       DATE(MAX(at.data_hora_inicio))           AS ultima_vez
  FROM tutor t
 INNER JOIN animal                   a  ON a.id_tutor         = t.id_tutor
 INNER JOIN atendimento              at ON at.id_animal       = a.id_animal
 INNER JOIN atendimento_procedimento ap ON ap.id_atendimento  = at.id_atendimento
 INNER JOIN procedimento             p  ON p.id_procedimento  = ap.id_procedimento
 WHERE t.id_tutor IN (SELECT id_tutor
                        FROM animal
                       GROUP BY id_tutor
                      HAVING COUNT(*) > 1)
 GROUP BY t.id_tutor, t.nome, p.nome
 ORDER BY t.nome, vezes DESC, p.nome;


-- =============================================================================
-- Q4. Medicamentos mais prescritos por espécie de animal
-- -----------------------------------------------------------------------------
-- Uso: planejamento de estoque da farmácia. A espécie não está na prescrição:
-- é alcançada pela cadeia prescrição -> atendimento -> animal -> raça -> espécie
-- (junção de 6 tabelas). Dentro de cada espécie, do mais prescrito ao menos.
-- =============================================================================
SELECT e.nome                         AS especie,
       m.nome_comercial,
       m.concentracao,
       m.principio_ativo,
       COUNT(*)                       AS prescricoes,
       COUNT(DISTINCT an.id_animal)   AS animais
  FROM prescricao pr
 INNER JOIN medicamento m  ON m.id_medicamento  = pr.id_medicamento
 INNER JOIN atendimento at ON at.id_atendimento = pr.id_atendimento
 INNER JOIN animal      an ON an.id_animal      = at.id_animal
 INNER JOIN raca        r  ON r.id_raca         = an.id_raca
 INNER JOIN especie     e  ON e.id_especie      = r.id_especie
 GROUP BY e.nome, m.id_medicamento, m.nome_comercial, m.concentracao, m.principio_ativo
 ORDER BY e.nome, prescricoes DESC, m.nome_comercial;


-- =============================================================================
-- Q5. Consulta com junção de 3+ tabelas + agregação + subconsulta
--     "Pacientes cujo gasto total supera a média de gasto por paciente"
-- -----------------------------------------------------------------------------
-- Uso: identificar pacientes de alto custo (doenças crônicas, cirurgias).
-- Junção de 6 tabelas, SUM/COUNT e, no HAVING, uma subconsulta que calcula a
-- média dos gastos por paciente a partir de uma tabela derivada.
-- =============================================================================
SELECT an.nome                                AS animal,
       e.nome                                 AS especie,
       t.nome                                 AS tutor,
       COUNT(DISTINCT at.id_atendimento)      AS atendimentos,
       SUM(ap.quantidade * ap.valor_unitario) AS gasto_total
  FROM animal an
 INNER JOIN raca                     r  ON r.id_raca         = an.id_raca
 INNER JOIN especie                  e  ON e.id_especie      = r.id_especie
 INNER JOIN tutor                    t  ON t.id_tutor        = an.id_tutor
 INNER JOIN atendimento              at ON at.id_animal      = an.id_animal
 INNER JOIN atendimento_procedimento ap ON ap.id_atendimento = at.id_atendimento
 GROUP BY an.id_animal, an.nome, e.nome, t.nome
HAVING SUM(ap.quantidade * ap.valor_unitario) > (
        SELECT AVG(gasto)
          FROM (SELECT SUM(ap2.quantidade * ap2.valor_unitario) AS gasto
                  FROM atendimento at2
                 INNER JOIN atendimento_procedimento ap2
                         ON ap2.id_atendimento = at2.id_atendimento
                 GROUP BY at2.id_animal) gastos
       )
 ORDER BY gasto_total DESC;


-- =============================================================================
-- CONSULTAS COMPLEMENTARES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- C1. Prontuário de um animal (usa a visão vw_historico_clinico)
-- -----------------------------------------------------------------------------
SELECT data_hora_inicio,
       veterinario,
       queixa_principal,
       diagnostico,
       peso_kg,
       qtd_procedimentos,
       qtd_prescricoes,
       valor_total
  FROM vw_historico_clinico
 WHERE animal = 'Zeus'
 ORDER BY data_hora_inicio DESC;

-- -----------------------------------------------------------------------------
-- C2. Receitas de um animal: medicamentos prescritos em cada atendimento
-- -----------------------------------------------------------------------------
SELECT DATE(at.data_hora_inicio) AS data,
       m.nome_comercial,
       m.concentracao,
       pr.dose_quantidade,
       pr.dose_unidade,
       pr.frequencia_horas,
       pr.duracao_dias
  FROM prescricao pr
 INNER JOIN atendimento at ON at.id_atendimento = pr.id_atendimento
 INNER JOIN animal      an ON an.id_animal      = at.id_animal
 INNER JOIN medicamento m  ON m.id_medicamento  = pr.id_medicamento
 WHERE an.nome = 'Zeus'
 ORDER BY at.data_hora_inicio DESC, m.nome_comercial;

-- -----------------------------------------------------------------------------
-- C3. Faturamento mensal por categoria de procedimento (2026)
-- -----------------------------------------------------------------------------
SELECT DATE(date_trunc('month', at.data_hora_inicio)) AS mes,
       p.categoria,
       SUM(ap.quantidade * ap.valor_unitario)         AS faturamento
  FROM atendimento at
 INNER JOIN atendimento_procedimento ap ON ap.id_atendimento = at.id_atendimento
 INNER JOIN procedimento             p  ON p.id_procedimento = ap.id_procedimento
 WHERE at.data_hora_inicio >= '2026-01-01'
   AND at.data_hora_inicio <  '2027-01-01'
 GROUP BY mes, p.categoria
 ORDER BY mes, faturamento DESC;

-- -----------------------------------------------------------------------------
-- C4. Cães e gatos vivos sem vacina nos últimos 12 meses
--     NOT IN encontra quem NÃO tem vacina recente; a subconsulta escalar
--     mostra a data da última vacina (vazia se nunca vacinou).
-- -----------------------------------------------------------------------------
SELECT a.animal,
       a.especie,
       a.tutor,
       a.telefone_tutor,
       (SELECT DATE(MAX(at.data_hora_inicio))
          FROM atendimento at
         INNER JOIN atendimento_procedimento ap ON ap.id_atendimento = at.id_atendimento
         INNER JOIN procedimento             p  ON p.id_procedimento = ap.id_procedimento
         WHERE at.id_animal = a.id_animal
           AND p.categoria  = 'VACINA') AS ultima_vacina
  FROM vw_animal a
 WHERE a.vivo
   AND a.especie IN ('Cão', 'Gato')
   AND a.id_animal NOT IN (
        SELECT at.id_animal
          FROM atendimento at
         INNER JOIN atendimento_procedimento ap ON ap.id_atendimento = at.id_atendimento
         INNER JOIN procedimento             p  ON p.id_procedimento = ap.id_procedimento
         WHERE p.categoria = 'VACINA'
           AND at.data_hora_inicio >= now() - INTERVAL '12 months')
 ORDER BY a.especie, a.animal;

-- -----------------------------------------------------------------------------
-- C5. Agendamentos por veterinário e situação
-- -----------------------------------------------------------------------------
SELECT v.nome    AS veterinario,
       ag.status,
       COUNT(*)  AS quantidade
  FROM agendamento ag
 INNER JOIN veterinario v ON v.id_veterinario = ag.id_veterinario
 GROUP BY v.nome, ag.status
 ORDER BY v.nome, ag.status;

-- -----------------------------------------------------------------------------
-- C6. Procedimentos restritos por espécie
--     Itens que não aparecem aqui valem para todas as espécies.
-- -----------------------------------------------------------------------------
SELECT e.nome AS especie,
       p.nome AS procedimento
  FROM procedimento_especie pe
 INNER JOIN especie      e ON e.id_especie      = pe.id_especie
 INNER JOIN procedimento p ON p.id_procedimento = pe.id_procedimento
 ORDER BY e.id_especie, p.nome;

-- -----------------------------------------------------------------------------
-- C7. Medicamentos restritos por espécie
-- -----------------------------------------------------------------------------
SELECT e.nome AS especie,
       m.nome_comercial,
       m.concentracao
  FROM medicamento_especie me
 INNER JOIN especie     e ON e.id_especie     = me.id_especie
 INNER JOIN medicamento m ON m.id_medicamento = me.id_medicamento
 ORDER BY e.id_especie, m.nome_comercial;
