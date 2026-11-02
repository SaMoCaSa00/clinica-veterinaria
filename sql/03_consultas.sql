-- =============================================================================
--  Sistema de Gestão de Clínica Veterinária
--  03_consultas.sql — consultas de gestão clínica e administrativa
-- -----------------------------------------------------------------------------
--  Pré-requisito: 01_ddl.sql e 02_dml.sql executados.
--  No pgAdmin, selecione uma consulta e pressione F5 para executar só ela.
--
--  Parâmetros (datas, animal etc.) ficam numa CTE "params" no topo de cada
--  consulta: basta trocar o valor ali, sem mexer no resto do SQL.
-- =============================================================================

SET search_path TO clinica, public;
SET TIME ZONE 'America/Sao_Paulo';


-- =============================================================================
-- Q1. Animais com atendimentos em aberto ou agendamentos futuros
-- -----------------------------------------------------------------------------
-- Uso: painel da recepção — quem está internado/em atendimento agora e quem
-- tem horário marcado. Um mesmo animal pode aparecer nas duas situações.
-- Técnicas: CTEs, UNION ALL, junção com visão, filtro por data relativa.
-- =============================================================================
WITH params AS (
    SELECT now() AS agora
),
em_aberto AS (
    SELECT at.id_animal,
           'Atendimento em aberto'::text           AS situacao,
           at.data_hora_inicio                     AS data_referencia,
           v.nome                                  AS veterinario,
           at.queixa_principal                     AS detalhe
      FROM atendimento at
      JOIN veterinario v ON v.id_veterinario = at.id_veterinario
     WHERE at.status = 'EM_ABERTO'
),
futuros AS (
    SELECT ag.id_animal,
           'Agendamento futuro'::text,
           ag.data_hora_inicio,
           v.nome,
           ag.motivo
      FROM agendamento ag
      JOIN veterinario v ON v.id_veterinario = ag.id_veterinario
      CROSS JOIN params p
     WHERE ag.status = 'AGENDADO'
       AND ag.data_hora_inicio > p.agora
)
SELECT a.animal,
       a.especie,
       a.tutor,
       a.telefone_tutor,
       s.situacao,
       to_char(s.data_referencia, 'DD/MM/YYYY HH24:MI') AS data_hora,
       s.veterinario,
       s.detalhe
  FROM (SELECT * FROM em_aberto
        UNION ALL
        SELECT * FROM futuros) s
  JOIN vw_animal a ON a.id_animal = s.id_animal
 ORDER BY s.situacao DESC,           -- "Atendimento em aberto" primeiro
          s.data_referencia;


-- =============================================================================
-- Q2. Ranking de veterinários por quantidade de atendimentos em um período
-- -----------------------------------------------------------------------------
-- Uso: produtividade da equipe. Veterinários sem atendimento no período também
-- aparecem (LEFT JOIN), com zero. RANK() trata empates (mesma posição).
-- Técnicas: CTE de parâmetros, LEFT JOIN com filtro na cláusula ON,
-- agregação com FILTER, funções de janela RANK() e SUM() OVER ().
-- =============================================================================
WITH params AS (
    SELECT DATE '2026-01-01' AS data_inicio,
           DATE '2026-10-31' AS data_fim
),
contagem AS (
    SELECT v.id_veterinario,
           v.nome,
           v.ativo,
           count(at.id_atendimento)                                          AS atendimentos,
           count(at.id_atendimento) FILTER (WHERE at.carater <> 'ELETIVO')   AS urgencias_emergencias,
           count(DISTINCT at.id_animal)                                      AS pacientes_distintos
      FROM veterinario v
      CROSS JOIN params p
      LEFT JOIN atendimento at
             ON at.id_veterinario    = v.id_veterinario
            AND at.data_hora_inicio >= p.data_inicio
            AND at.data_hora_inicio <  p.data_fim + 1      -- inclui o último dia inteiro
     GROUP BY v.id_veterinario, v.nome, v.ativo
)
SELECT RANK() OVER (ORDER BY atendimentos DESC)                             AS posicao,
       nome                                                                 AS veterinario,
       CASE WHEN ativo THEN 'Ativo' ELSE 'Desligado' END                    AS situacao,
       atendimentos,
       urgencias_emergencias,
       pacientes_distintos,
       round(100.0 * atendimentos / NULLIF(SUM(atendimentos) OVER (), 0), 1) AS percentual
  FROM contagem
 ORDER BY posicao, veterinario;


-- =============================================================================
-- Q3. Tutores com mais de um animal e histórico resumido de procedimentos
-- -----------------------------------------------------------------------------
-- Uso: relacionamento com clientes de maior vínculo (planos família,
-- campanhas). Para cada tutor: animais, nº de atendimentos, último
-- atendimento, valor total e os procedimentos realizados com a quantidade.
-- Técnicas: HAVING, CTEs encadeadas, string_agg ordenado, LEFT JOIN para
-- incluir animais que ainda não tiveram atendimento.
-- =============================================================================
WITH tutores_multi AS (
    SELECT id_tutor
      FROM animal
     GROUP BY id_tutor
    HAVING count(*) > 1
),
animais AS (
    SELECT a.id_tutor,
           string_agg(a.nome || ' (' || e.nome || ')', ', ' ORDER BY a.nome) AS animais,
           count(*)                                                          AS qtd_animais
      FROM animal a
      JOIN raca    r ON r.id_raca    = a.id_raca
      JOIN especie e ON e.id_especie = r.id_especie
     WHERE a.id_tutor IN (SELECT id_tutor FROM tutores_multi)
     GROUP BY a.id_tutor
),
atend AS (
    SELECT a.id_tutor,
           count(at.id_atendimento)  AS atendimentos,
           max(at.data_hora_inicio)  AS ultimo_atendimento
      FROM animal a
      LEFT JOIN atendimento at ON at.id_animal = a.id_animal
     WHERE a.id_tutor IN (SELECT id_tutor FROM tutores_multi)
     GROUP BY a.id_tutor
),
proc AS (
    SELECT a.id_tutor,
           p.nome,
           SUM(ap.quantidade)                     AS qtd,
           SUM(ap.quantidade * ap.valor_unitario) AS valor
      FROM animal a
      JOIN atendimento              at ON at.id_animal       = a.id_animal
      JOIN atendimento_procedimento ap ON ap.id_atendimento  = at.id_atendimento
      JOIN procedimento             p  ON p.id_procedimento  = ap.id_procedimento
     WHERE a.id_tutor IN (SELECT id_tutor FROM tutores_multi)
     GROUP BY a.id_tutor, p.nome
)
SELECT t.nome                                                         AS tutor,
       an.qtd_animais,
       an.animais,
       ate.atendimentos,
       to_char(ate.ultimo_atendimento, 'DD/MM/YYYY') AS ultimo_atendimento,
       COALESCE(SUM(pr.valor), 0)                                     AS valor_total,
       string_agg(pr.nome || ' ×' || pr.qtd, '; ' ORDER BY pr.qtd DESC, pr.nome) AS procedimentos
  FROM tutor t
  JOIN animais an  ON an.id_tutor  = t.id_tutor
  JOIN atend   ate ON ate.id_tutor = t.id_tutor
  LEFT JOIN proc pr ON pr.id_tutor = t.id_tutor
 GROUP BY t.id_tutor, t.nome, an.qtd_animais, an.animais, ate.atendimentos, ate.ultimo_atendimento
 ORDER BY an.qtd_animais DESC, valor_total DESC;


-- =============================================================================
-- Q4. Medicamentos mais prescritos por espécie de animal
-- -----------------------------------------------------------------------------
-- Uso: planejamento de estoque e farmacovigilância. Mostra o top 3 de cada
-- espécie (com empates). A espécie vem pela cadeia
-- prescricao -> atendimento -> animal -> raca -> especie.
-- Técnicas: junção de 6 tabelas, agregação, DENSE_RANK() particionado.
-- =============================================================================
WITH contagem AS (
    SELECT e.nome                         AS especie,
           m.nome_comercial || ' ' || m.concentracao AS medicamento,
           m.principio_ativo,
           count(*)                       AS prescricoes,
           count(DISTINCT an.id_animal)   AS animais_distintos
      FROM prescricao  pr
      JOIN medicamento m  ON m.id_medicamento = pr.id_medicamento
      JOIN atendimento at ON at.id_atendimento = pr.id_atendimento
      JOIN animal      an ON an.id_animal     = at.id_animal
      JOIN raca        r  ON r.id_raca        = an.id_raca
      JOIN especie     e  ON e.id_especie     = r.id_especie
     GROUP BY e.nome, m.id_medicamento, m.nome_comercial, m.concentracao, m.principio_ativo
),
ranking AS (
    SELECT c.*,
           DENSE_RANK() OVER (PARTITION BY especie ORDER BY prescricoes DESC) AS posicao
      FROM contagem c
)
SELECT especie, posicao, medicamento, principio_ativo, prescricoes, animais_distintos
  FROM ranking
 WHERE posicao <= 3
 ORDER BY especie, posicao, medicamento;


-- =============================================================================
-- Q5. Junção de 3+ tabelas + agregação + subconsulta
--     "Pacientes cujo gasto total supera a média de gasto por paciente"
-- -----------------------------------------------------------------------------
-- Uso: identificar pacientes de alto custo (doenças crônicas, cirurgias) para
-- acompanhamento e oferta de planos de saúde pet.
-- Técnicas: junção de 6 tabelas, SUM/COUNT, subconsulta em tabela derivada
-- (média por paciente) usada no HAVING e no SELECT.
-- =============================================================================
SELECT an.nome                                            AS animal,
       e.nome                                             AS especie,
       t.nome                                             AS tutor,
       count(DISTINCT at.id_atendimento)                  AS atendimentos,
       SUM(ap.quantidade * ap.valor_unitario)             AS gasto_total,
       round(m.media, 2)                                  AS media_geral,
       round(100.0 * (SUM(ap.quantidade * ap.valor_unitario) / m.media - 1), 1) AS acima_da_media_pct
  FROM animal an
  JOIN raca                     r  ON r.id_raca        = an.id_raca
  JOIN especie                  e  ON e.id_especie     = r.id_especie
  JOIN tutor                    t  ON t.id_tutor       = an.id_tutor
  JOIN atendimento              at ON at.id_animal     = an.id_animal
  JOIN atendimento_procedimento ap ON ap.id_atendimento = at.id_atendimento
  CROSS JOIN (
        -- subconsulta: gasto médio por paciente atendido
        SELECT avg(gasto) AS media
          FROM (SELECT at2.id_animal,
                       SUM(ap2.quantidade * ap2.valor_unitario) AS gasto
                  FROM atendimento at2
                  JOIN atendimento_procedimento ap2 ON ap2.id_atendimento = at2.id_atendimento
                 GROUP BY at2.id_animal) gasto_por_animal
       ) m
 GROUP BY an.id_animal, an.nome, e.nome, t.nome, m.media
HAVING SUM(ap.quantidade * ap.valor_unitario) > m.media
 ORDER BY gasto_total DESC;


-- =============================================================================
-- CONSULTAS COMPLEMENTARES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- C1. Histórico clínico completo de um animal (prontuário)
--     Usa a visão vw_historico_clinico. Troque o nome do animal em params.
-- -----------------------------------------------------------------------------
WITH params AS (SELECT 'Zeus'::varchar AS animal)
SELECT to_char(h.data_hora_inicio, 'DD/MM/YYYY') AS data,
       h.veterinario,
       h.queixa_principal,
       h.diagnostico,
       h.peso_kg,
       h.procedimentos,
       h.prescricoes,
       h.valor_total
  FROM vw_historico_clinico h
  JOIN params p ON h.animal = p.animal
 ORDER BY h.data_hora_inicio DESC;

-- -----------------------------------------------------------------------------
-- C2. Faturamento mensal por categoria de procedimento (ano corrente dos dados)
--     Pivot com FILTER: uma coluna por categoria.
-- -----------------------------------------------------------------------------
SELECT to_char(date_trunc('month', at.data_hora_inicio), 'YYYY-MM')                     AS mes,
       SUM(ap.quantidade * ap.valor_unitario) FILTER (WHERE p.categoria = 'CONSULTA')   AS consultas,
       SUM(ap.quantidade * ap.valor_unitario) FILTER (WHERE p.categoria IN ('EXAME', 'IMAGEM')) AS exames,
       SUM(ap.quantidade * ap.valor_unitario) FILTER (WHERE p.categoria = 'VACINA')     AS vacinas,
       SUM(ap.quantidade * ap.valor_unitario) FILTER (WHERE p.categoria = 'CIRURGIA')   AS cirurgias,
       SUM(ap.quantidade * ap.valor_unitario) FILTER (WHERE p.categoria IN ('TERAPIA', 'INTERNACAO')) AS terapia_internacao,
       SUM(ap.quantidade * ap.valor_unitario)                                           AS total
  FROM atendimento at
  JOIN atendimento_procedimento ap ON ap.id_atendimento  = at.id_atendimento
  JOIN procedimento             p  ON p.id_procedimento  = ap.id_procedimento
 WHERE at.data_hora_inicio >= DATE '2026-01-01'
   AND at.data_hora_inicio <  DATE '2027-01-01'
 GROUP BY 1
 ORDER BY 1;

-- -----------------------------------------------------------------------------
-- C3. Pacientes vivos sem vacina nos últimos 12 meses (cães e gatos)
--     Usa NOT EXISTS (anti-join) para achar quem precisa ser chamado.
-- -----------------------------------------------------------------------------
SELECT a.animal,
       a.especie,
       a.tutor,
       a.telefone_tutor,
       (SELECT to_char(max(at.data_hora_inicio), 'DD/MM/YYYY')
          FROM atendimento at
          JOIN atendimento_procedimento ap ON ap.id_atendimento = at.id_atendimento
          JOIN procedimento p              ON p.id_procedimento = ap.id_procedimento
         WHERE at.id_animal = a.id_animal
           AND p.categoria  = 'VACINA')                       AS ultima_vacina
  FROM vw_animal a
 WHERE a.vivo
   AND a.especie IN ('Cão', 'Gato')
   AND NOT EXISTS (
        SELECT 1
          FROM atendimento at
          JOIN atendimento_procedimento ap ON ap.id_atendimento = at.id_atendimento
          JOIN procedimento p              ON p.id_procedimento = ap.id_procedimento
         WHERE at.id_animal        = a.id_animal
           AND p.categoria         = 'VACINA'
           AND at.data_hora_inicio >= now() - INTERVAL '12 months')
 ORDER BY a.especie, a.animal;

-- -----------------------------------------------------------------------------
-- C4. Taxa de cancelamento de agendamentos por veterinário
-- -----------------------------------------------------------------------------
SELECT v.nome                                                  AS veterinario,
       count(*)                                                AS agendamentos,
       count(*) FILTER (WHERE ag.status = 'REALIZADO')         AS realizados,
       count(*) FILTER (WHERE ag.status = 'CANCELADO')         AS cancelados,
       count(*) FILTER (WHERE ag.status = 'AGENDADO')          AS pendentes,
       round(100.0 * count(*) FILTER (WHERE ag.status = 'CANCELADO') / count(*), 1) AS taxa_cancelamento_pct
  FROM agendamento ag
  JOIN veterinario v ON v.id_veterinario = ag.id_veterinario
 GROUP BY v.id_veterinario, v.nome
 ORDER BY taxa_cancelamento_pct DESC, agendamentos DESC;

-- -----------------------------------------------------------------------------
-- C5. Itens restritos por espécie (o que cada espécie pode receber)
--     Lista procedimentos e medicamentos com restrição, agrupados por espécie.
--     Itens sem restrição valem para todas e não aparecem aqui.
-- -----------------------------------------------------------------------------
SELECT e.nome                                                          AS especie,
       string_agg(DISTINCT p.nome, '; ')                               AS procedimentos_restritos,
       string_agg(DISTINCT m.nome_comercial || ' ' || m.concentracao, '; ') AS medicamentos_restritos
  FROM especie e
  LEFT JOIN procedimento_especie pe ON pe.id_especie      = e.id_especie
  LEFT JOIN procedimento         p  ON p.id_procedimento  = pe.id_procedimento
  LEFT JOIN medicamento_especie  me ON me.id_especie      = e.id_especie
  LEFT JOIN medicamento          m  ON m.id_medicamento   = me.id_medicamento
 GROUP BY e.id_especie, e.nome
 ORDER BY e.id_especie;
