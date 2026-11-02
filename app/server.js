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
  // "inicio" vem do formulário como horário local (YYYY-MM-DDTHH:MM).
  // O fim é o início + a duração escolhida, em minutos.
  const { rows } = await query(`
    INSERT INTO agendamento (id_animal, id_veterinario, data_hora_inicio, data_hora_fim, tipo, motivo)
    VALUES ($1, $2, CAST($3 AS TIMESTAMP), CAST($3 AS TIMESTAMP) + CAST($4 AS INTERVAL), $5, $6)
    RETURNING id_agendamento`,
    [id_animal, id_veterinario, inicio, `${Number(duracao_min) || 30} minutes`, tipo, vazioParaNull(motivo)]);
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
  const busca = (req.query.q || '').trim();
  const [tutores, animais] = await Promise.all([
    query(`
      SELECT t.id_tutor, t.nome, t.cpf, t.telefone, t.email, t.cidade, t.uf
        FROM tutor t
       WHERE LOWER(t.nome) LIKE LOWER($1) || '%' OR t.cpf LIKE $1 || '%'
       ORDER BY t.nome`, [busca]),
    query(`SELECT id_tutor, nome FROM animal ORDER BY nome`),
  ]);
  // junta a lista de animais de cada tutor aqui no JavaScript
  return tutores.rows.map((t) => {
    const nomes = animais.rows.filter((a) => a.id_tutor === t.id_tutor).map((a) => a.nome);
    return { ...t, qtd_animais: nomes.length, animais: nomes.join(', ') };
  });
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
  const especie = (req.query.especie || '').trim();
  const busca = (req.query.q || '').trim();
  const { rows } = await query(`
    SELECT a.*,
           (SELECT MAX(data_hora_inicio) FROM atendimento WHERE id_animal = a.id_animal) AS ultimo_atendimento
      FROM vw_animal a
     WHERE (a.especie = $1 OR $1 = '')
       AND (LOWER(a.animal) LIKE LOWER($2) || '%' OR LOWER(a.tutor) LIKE '%' || LOWER($2) || '%')
     ORDER BY a.animal`, [especie, busca]);
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
  const [animal, historico, procedimentos, prescricoes, agenda] = await Promise.all([
    query(`SELECT a.*, an.microchip, an.pelagem, an.data_obito, an.observacoes, t.email AS email_tutor
             FROM vw_animal a
            INNER JOIN animal an ON an.id_animal = a.id_animal
            INNER JOIN tutor  t  ON t.id_tutor   = a.id_tutor
            WHERE a.id_animal = $1`, [id]),
    query(`SELECT * FROM vw_historico_clinico WHERE id_animal = $1 ORDER BY data_hora_inicio DESC`, [id]),
    // procedimentos de todos os atendimentos do animal
    query(`SELECT ap.id_atendimento, p.nome
             FROM atendimento_procedimento ap
            INNER JOIN procedimento p  ON p.id_procedimento = ap.id_procedimento
            INNER JOIN atendimento  at ON at.id_atendimento = ap.id_atendimento
            WHERE at.id_animal = $1
            ORDER BY p.nome`, [id]),
    // prescrições de todos os atendimentos do animal
    query(`SELECT pr.*, m.nome_comercial, m.concentracao
             FROM prescricao pr
            INNER JOIN medicamento m  ON m.id_medicamento  = pr.id_medicamento
            INNER JOIN atendimento at ON at.id_atendimento = pr.id_atendimento
            WHERE at.id_animal = $1
            ORDER BY m.nome_comercial`, [id]),
    query(`SELECT ag.*, v.nome AS veterinario
             FROM agendamento ag
            INNER JOIN veterinario v ON v.id_veterinario = ag.id_veterinario
            WHERE ag.id_animal = $1 AND ag.status = 'AGENDADO' AND ag.data_hora_inicio > now()
            ORDER BY ag.data_hora_inicio`, [id]),
  ]);
  if (!animal.rows.length) throw Object.assign(new Error('Animal não encontrado.'), { code: 'P0001' });

  // pendura os procedimentos e as prescrições em cada atendimento do histórico
  const historicoCompleto = historico.rows.map((h) => ({
    ...h,
    procedimentos: procedimentos.rows.filter((p) => p.id_atendimento === h.id_atendimento).map((p) => p.nome),
    prescricoes: prescricoes.rows.filter((p) => p.id_atendimento === h.id_atendimento),
  }));
  return { animal: animal.rows[0], historico: historicoCompleto, agenda: agenda.rows };
}));


// ---------------------------------------------------------------- relatórios
// Mesmas consultas Q2, Q4 e Q5 de sql/03_consultas.sql.
app.get('/api/relatorios', rota(async (req) => {
  const de = req.query.de || '2026-01-01';
  const ate = req.query.ate || '2026-12-31';
  const [ranking, medicamentos, altoCusto, media] = await Promise.all([
    // Q2: atendimentos por veterinário no período (LEFT JOIN mantém quem tem zero)
    query(`
      SELECT v.nome AS veterinario, v.ativo,
             COUNT(at.id_atendimento) AS atendimentos,
             (SELECT COUNT(*)
                FROM atendimento a2
               WHERE a2.id_veterinario = v.id_veterinario
                 AND a2.carater <> 'ELETIVO'
                 AND a2.data_hora_inicio >= CAST($1 AS DATE)
                 AND a2.data_hora_inicio <  CAST($2 AS DATE) + 1) AS urgencias
        FROM veterinario v
        LEFT JOIN atendimento at
               ON at.id_veterinario    = v.id_veterinario
              AND at.data_hora_inicio >= CAST($1 AS DATE)
              AND at.data_hora_inicio <  CAST($2 AS DATE) + 1
       GROUP BY v.id_veterinario, v.nome, v.ativo
       ORDER BY atendimentos DESC, v.nome`, [de, ate]),
    // Q4: medicamentos por espécie, do mais prescrito ao menos
    query(`
      SELECT e.nome AS especie, m.nome_comercial || ' ' || m.concentracao AS medicamento,
             COUNT(*) AS prescricoes
        FROM prescricao pr
       INNER JOIN medicamento m  ON m.id_medicamento  = pr.id_medicamento
       INNER JOIN atendimento at ON at.id_atendimento = pr.id_atendimento
       INNER JOIN animal an      ON an.id_animal      = at.id_animal
       INNER JOIN raca r         ON r.id_raca         = an.id_raca
       INNER JOIN especie e      ON e.id_especie      = r.id_especie
       GROUP BY e.nome, m.id_medicamento, m.nome_comercial, m.concentracao
       ORDER BY e.nome, prescricoes DESC, medicamento`),
    // Q5: pacientes com gasto acima da média
    query(`
      SELECT an.id_animal, an.nome AS animal, e.nome AS especie, t.nome AS tutor,
             SUM(ap.quantidade * ap.valor_unitario) AS gasto_total
        FROM animal an
       INNER JOIN raca r    ON r.id_raca    = an.id_raca
       INNER JOIN especie e ON e.id_especie = r.id_especie
       INNER JOIN tutor t   ON t.id_tutor   = an.id_tutor
       INNER JOIN atendimento at              ON at.id_animal      = an.id_animal
       INNER JOIN atendimento_procedimento ap ON ap.id_atendimento = at.id_atendimento
       GROUP BY an.id_animal, an.nome, e.nome, t.nome
      HAVING SUM(ap.quantidade * ap.valor_unitario) > (
             SELECT AVG(gasto) FROM (
               SELECT SUM(ap2.quantidade * ap2.valor_unitario) AS gasto
                 FROM atendimento at2
                INNER JOIN atendimento_procedimento ap2 ON ap2.id_atendimento = at2.id_atendimento
                GROUP BY at2.id_animal) gastos)
       ORDER BY gasto_total DESC`),
    query(`
      SELECT ROUND(AVG(gasto), 2) AS media FROM (
        SELECT SUM(ap.quantidade * ap.valor_unitario) AS gasto
          FROM atendimento at
         INNER JOIN atendimento_procedimento ap ON ap.id_atendimento = at.id_atendimento
         GROUP BY at.id_animal) gastos`),
  ]);

  // posição no ranking: empatados ficam na mesma posição (1º, 2º, 3º, 3º, 5º...)
  ranking.rows.forEach((r, i, lista) => {
    r.posicao = i > 0 && r.atendimentos === lista[i - 1].atendimentos ? lista[i - 1].posicao : i + 1;
  });

  // top 3 de cada espécie (empates entram juntos)
  const top = [];
  for (const m of medicamentos.rows) {
    const daEspecie = top.filter((x) => x.especie === m.especie);
    const ultimo = daEspecie[daEspecie.length - 1];
    const nivel = !ultimo ? 1 : ultimo.prescricoes === m.prescricoes ? ultimo.nivel : ultimo.nivel + 1;
    if (nivel <= 3) top.push({ ...m, nivel });
  }

  return { ranking: ranking.rows, medicamentos: top, altoCusto: altoCusto.rows, media: media.rows[0].media };
}));


const PORTA = Number(process.env.PORT) || 3000;
app.listen(PORTA, () => {
  console.log(`Clínica veterinária rodando em http://localhost:${PORTA}`);
});
