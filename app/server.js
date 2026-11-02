// Servidor da interface web.
// Expõe uma API JSON simples sobre o banco clinica_vet e serve o front-end
// estático da pasta public/. Toda regra de negócio (CPF, conflito de agenda,
// espécie, óbito...) é validada pelo próprio PostgreSQL.
import express from 'express';
import { query, mensagemDeErro } from './db.js';

const app = express();
app.use(express.json());
app.use(express.static('public'));

// Envolve cada rota: se o banco recusar, devolve 400 com a mensagem traduzida.
const rota = (fn) => async (req, res) => {
  try {
    res.json(await fn(req, res));
  } catch (err) {
    console.error(err.message);
    res.status(400).json({ erro: mensagemDeErro(err) });
  }
};

const somenteDigitos = (s) => (s ?? '').toString().replace(/\D/g, '') || null;
const vazioParaNull = (s) => (s === undefined || s === '' ? null : s);


// ---------------------------------------------------------------- opções
// Listas usadas nos formulários (selects).
app.get('/api/opcoes', rota(async () => {
  const [vets, especies, racas, animais] = await Promise.all([
    query(`SELECT id_veterinario AS id, nome FROM veterinario WHERE ativo ORDER BY nome`),
    query(`SELECT id_especie AS id, nome FROM especie ORDER BY id_especie`),
    query(`SELECT id_raca AS id, id_especie, nome FROM raca ORDER BY nome`),
    query(`SELECT id_animal AS id, animal AS nome, especie, tutor FROM vw_animal WHERE vivo ORDER BY animal`),
  ]);
  return { veterinarios: vets.rows, especies: especies.rows, racas: racas.rows, animais: animais.rows };
}));


// ---------------------------------------------------------------- painel
// Mesma lógica da consulta Q1: quem está em atendimento agora e próximos horários.
app.get('/api/painel', rota(async () => {
  const [emAberto, proximos, numeros] = await Promise.all([
    query(`
      SELECT at.id_atendimento, a.id_animal, a.animal, a.especie, a.tutor, a.telefone_tutor,
             v.nome AS veterinario, at.data_hora_inicio, at.carater, at.queixa_principal
        FROM atendimento at
        JOIN vw_animal   a ON a.id_animal      = at.id_animal
        JOIN veterinario v ON v.id_veterinario = at.id_veterinario
       WHERE at.status = 'EM_ABERTO'
       ORDER BY at.data_hora_inicio`),
    query(`
      SELECT ag.id_agendamento, a.id_animal, a.animal, a.especie, a.tutor, a.telefone_tutor,
             v.nome AS veterinario, ag.data_hora_inicio, ag.data_hora_fim, ag.tipo, ag.motivo
        FROM agendamento ag
        JOIN vw_animal   a ON a.id_animal      = ag.id_animal
        JOIN veterinario v ON v.id_veterinario = ag.id_veterinario
       WHERE ag.status = 'AGENDADO' AND ag.data_hora_inicio > now()
       ORDER BY ag.data_hora_inicio
       LIMIT 8`),
    query(`
      SELECT (SELECT count(*) FROM tutor)                                   AS tutores,
             (SELECT count(*) FROM animal WHERE data_obito IS NULL)         AS animais,
             (SELECT count(*) FROM agendamento
               WHERE status = 'AGENDADO' AND data_hora_inicio > now()
                 AND data_hora_inicio < now() + interval '7 days')          AS agendados_7_dias,
             (SELECT count(*) FROM atendimento
               WHERE data_hora_inicio >= now() - interval '30 days')        AS atendimentos_30_dias`),
  ]);
  return { emAberto: emAberto.rows, proximos: proximos.rows, numeros: numeros.rows[0] };
}));


// ---------------------------------------------------------------- agenda
app.get('/api/agenda', rota(async (req) => {
  const { rows } = await query(`
    SELECT ag.id_agendamento, ag.data_hora_inicio, ag.data_hora_fim, ag.tipo, ag.motivo,
           ag.status, ag.motivo_cancelamento,
           a.id_animal, a.animal, a.especie, a.tutor, v.nome AS veterinario
      FROM agendamento ag
      JOIN vw_animal   a ON a.id_animal      = ag.id_animal
      JOIN veterinario v ON v.id_veterinario = ag.id_veterinario
     WHERE ($1::text = 'futuros' AND ag.data_hora_inicio >= date_trunc('day', now()))
        OR ($1::text = 'todos')
     ORDER BY ag.data_hora_inicio`, [req.query.filtro === 'todos' ? 'todos' : 'futuros']);
  return rows;
}));

app.post('/api/agendamentos', rota(async (req) => {
  const { id_animal, id_veterinario, inicio, duracao_min, tipo, motivo } = req.body;
  // "inicio" vem do formulário como horário local (YYYY-MM-DDTHH:MM);
  // o banco interpreta no fuso da sessão (America/Sao_Paulo).
  const { rows } = await query(`
    INSERT INTO agendamento (id_animal, id_veterinario, data_hora_inicio, data_hora_fim, tipo, motivo)
    VALUES ($1, $2, $3::timestamp, $3::timestamp + make_interval(mins => $4), $5, $6)
    RETURNING id_agendamento`,
    [id_animal, id_veterinario, inicio, Number(duracao_min) || 30, tipo, vazioParaNull(motivo)]);
  return rows[0];
}));

app.post('/api/agendamentos/:id/cancelar', rota(async (req) => {
  const { rowCount } = await query(`
    UPDATE agendamento
       SET status = 'CANCELADO', motivo_cancelamento = $2
     WHERE id_agendamento = $1 AND status = 'AGENDADO'`,
    [req.params.id, vazioParaNull(req.body.motivo)]);
  if (!rowCount) throw Object.assign(new Error('Só é possível cancelar horários com status AGENDADO.'), { code: 'P0001' });
  return { ok: true };
}));


// ---------------------------------------------------------------- tutores
app.get('/api/tutores', rota(async (req) => {
  const { rows } = await query(`
    SELECT t.id_tutor, t.nome, t.cpf, t.telefone, t.email, t.cidade, t.uf,
           count(a.id_animal) AS qtd_animais,
           string_agg(a.nome, ', ' ORDER BY a.nome) AS animais
      FROM tutor t
      LEFT JOIN animal a ON a.id_tutor = t.id_tutor
     WHERE $1::text IS NULL OR lower(t.nome) LIKE lower($1) || '%' OR t.cpf LIKE $1 || '%'
     GROUP BY t.id_tutor
     ORDER BY t.nome`, [vazioParaNull(req.query.q)]);
  return rows;
}));

app.post('/api/tutores', rota(async (req) => {
  const b = req.body;
  const { rows } = await query(`
    INSERT INTO tutor (nome, cpf, data_nascimento, email, telefone, logradouro, numero,
                       complemento, bairro, cidade, uf, cep)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
    RETURNING id_tutor`,
    [b.nome?.trim(), somenteDigitos(b.cpf), vazioParaNull(b.data_nascimento), vazioParaNull(b.email?.trim()),
     somenteDigitos(b.telefone), vazioParaNull(b.logradouro), vazioParaNull(b.numero),
     vazioParaNull(b.complemento), vazioParaNull(b.bairro), b.cidade?.trim(),
     b.uf?.trim().toUpperCase(), somenteDigitos(b.cep)]);
  return rows[0];
}));


// ---------------------------------------------------------------- animais
app.get('/api/animais', rota(async (req) => {
  const { rows } = await query(`
    SELECT a.*, (SELECT max(data_hora_inicio) FROM atendimento WHERE id_animal = a.id_animal) AS ultimo_atendimento
      FROM vw_animal a
     WHERE ($1::text IS NULL OR a.especie = $1)
       AND ($2::text IS NULL OR lower(a.animal) LIKE lower($2) || '%' OR lower(a.tutor) LIKE '%' || lower($2) || '%')
     ORDER BY a.animal`, [vazioParaNull(req.query.especie), vazioParaNull(req.query.q)]);
  return rows;
}));

app.post('/api/animais', rota(async (req) => {
  const b = req.body;
  const { rows } = await query(`
    INSERT INTO animal (id_tutor, id_raca, nome, sexo, data_nascimento, pelagem, castrado, microchip)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
    RETURNING id_animal`,
    [b.id_tutor, b.id_raca, b.nome?.trim(), b.sexo, vazioParaNull(b.data_nascimento),
     vazioParaNull(b.pelagem), !!b.castrado, somenteDigitos(b.microchip)]);
  return rows[0];
}));

// Prontuário: dados do animal + histórico clínico (visão) + agenda do animal
app.get('/api/animais/:id', rota(async (req) => {
  const id = req.params.id;
  const [animal, historico, agenda] = await Promise.all([
    query(`SELECT a.*, an.microchip, an.pelagem, an.data_obito, an.observacoes, t.email AS email_tutor
             FROM vw_animal a
             JOIN animal an ON an.id_animal = a.id_animal
             JOIN tutor  t  ON t.id_tutor   = a.id_tutor
            WHERE a.id_animal = $1`, [id]),
    query(`SELECT * FROM vw_historico_clinico WHERE id_animal = $1 ORDER BY data_hora_inicio DESC`, [id]),
    query(`SELECT ag.*, v.nome AS veterinario
             FROM agendamento ag JOIN veterinario v ON v.id_veterinario = ag.id_veterinario
            WHERE ag.id_animal = $1 AND ag.status = 'AGENDADO' AND ag.data_hora_inicio > now()
            ORDER BY ag.data_hora_inicio`, [id]),
  ]);
  if (!animal.rows.length) throw Object.assign(new Error('Animal não encontrado.'), { code: 'P0001' });
  return { animal: animal.rows[0], historico: historico.rows, agenda: agenda.rows };
}));


// ---------------------------------------------------------------- relatórios
// Mesmas consultas Q2, Q4 e Q5 de sql/03_consultas.sql.
app.get('/api/relatorios', rota(async (req) => {
  const de = req.query.de || '2026-01-01';
  const ate = req.query.ate || '2026-12-31';
  const [ranking, medicamentos, altoCusto] = await Promise.all([
    query(`
      SELECT v.nome AS veterinario, v.ativo,
             count(at.id_atendimento)                                        AS atendimentos,
             count(at.id_atendimento) FILTER (WHERE at.carater <> 'ELETIVO') AS urgencias,
             RANK() OVER (ORDER BY count(at.id_atendimento) DESC)            AS posicao
        FROM veterinario v
        LEFT JOIN atendimento at
               ON at.id_veterinario    = v.id_veterinario
              AND at.data_hora_inicio >= $1::date
              AND at.data_hora_inicio <  $2::date + 1
       GROUP BY v.id_veterinario
       ORDER BY posicao, v.nome`, [de, ate]),
    query(`
      WITH contagem AS (
        SELECT e.nome AS especie, m.nome_comercial || ' ' || m.concentracao AS medicamento,
               count(*) AS prescricoes
          FROM prescricao pr
          JOIN medicamento m  ON m.id_medicamento  = pr.id_medicamento
          JOIN atendimento at ON at.id_atendimento = pr.id_atendimento
          JOIN animal an      ON an.id_animal      = at.id_animal
          JOIN raca r         ON r.id_raca         = an.id_raca
          JOIN especie e      ON e.id_especie      = r.id_especie
         GROUP BY e.nome, m.id_medicamento
      )
      SELECT * FROM (
        SELECT c.*, DENSE_RANK() OVER (PARTITION BY especie ORDER BY prescricoes DESC) AS posicao
          FROM contagem c) x
       WHERE posicao <= 3
       ORDER BY especie, posicao, medicamento`),
    query(`
      SELECT an.id_animal, an.nome AS animal, e.nome AS especie, t.nome AS tutor,
             SUM(ap.quantidade * ap.valor_unitario) AS gasto_total, round(m.media, 2) AS media
        FROM animal an
        JOIN raca r    ON r.id_raca    = an.id_raca
        JOIN especie e ON e.id_especie = r.id_especie
        JOIN tutor t   ON t.id_tutor   = an.id_tutor
        JOIN atendimento at              ON at.id_animal      = an.id_animal
        JOIN atendimento_procedimento ap ON ap.id_atendimento = at.id_atendimento
        CROSS JOIN (SELECT avg(gasto) AS media FROM (
               SELECT at2.id_animal, SUM(ap2.quantidade * ap2.valor_unitario) AS gasto
                 FROM atendimento at2
                 JOIN atendimento_procedimento ap2 ON ap2.id_atendimento = at2.id_atendimento
                GROUP BY at2.id_animal) g) m
       GROUP BY an.id_animal, e.nome, t.nome, m.media
      HAVING SUM(ap.quantidade * ap.valor_unitario) > m.media
       ORDER BY gasto_total DESC`),
  ]);
  return { ranking: ranking.rows, medicamentos: medicamentos.rows, altoCusto: altoCusto.rows };
}));


const PORTA = Number(process.env.PORT) || 3000;
app.listen(PORTA, () => {
  console.log(`Clínica veterinária rodando em http://localhost:${PORTA}`);
});
