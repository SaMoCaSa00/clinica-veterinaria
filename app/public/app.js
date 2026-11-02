// Front-end da clínica: roteamento por hash (#/painel, #/animais/15...),
// chamadas à API e montagem das telas. Sem framework, só JavaScript.

const $conteudo = document.getElementById('conteudo');
const FUSO = 'America/Sao_Paulo';

// ------------------------------------------------------------ utilidades
const api = async (caminho, opcoes = {}) => {
  const resp = await fetch(`/api/${caminho}`, {
    headers: { 'Content-Type': 'application/json' },
    ...opcoes,
    body: opcoes.body ? JSON.stringify(opcoes.body) : undefined,
  });
  const dados = await resp.json();
  if (!resp.ok) throw new Error(dados.erro || 'Erro ao falar com o servidor.');
  return dados;
};

// escapa texto vindo do banco antes de colocar no HTML
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => (
  { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

const fmt = {
  data: (d) => new Date(d).toLocaleDateString('pt-BR', { timeZone: FUSO }),
  dataCurta: (d) => new Date(d).toLocaleDateString('pt-BR', { timeZone: FUSO, day: '2-digit', month: 'short' }).replace('.', ''),
  ano: (d) => new Date(d).toLocaleDateString('pt-BR', { timeZone: FUSO, year: 'numeric' }),
  hora: (d) => new Date(d).toLocaleTimeString('pt-BR', { timeZone: FUSO, hour: '2-digit', minute: '2-digit' }),
  diaExtenso: (d) => new Date(d).toLocaleDateString('pt-BR', { timeZone: FUSO, weekday: 'long', day: 'numeric', month: 'long' }),
  // datas sem hora (DATE) chegam como 'YYYY-MM-DD'
  dataSimples: (s) => (s ? s.split('-').reverse().join('/') : '—'),
  dinheiro: (v) => (v ?? 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' }),
  peso: (v) => (v == null ? '—' : `${v.toLocaleString('pt-BR', { maximumFractionDigits: 3 })} kg`),
  telefone: (t) => (t?.length === 11 ? `(${t.slice(0, 2)}) ${t.slice(2, 7)}-${t.slice(7)}`
    : t?.length === 10 ? `(${t.slice(0, 2)}) ${t.slice(2, 6)}-${t.slice(6)}` : t ?? ''),
  cpf: (c) => (c ? `${c.slice(0, 3)}.${c.slice(3, 6)}.${c.slice(6, 9)}-${c.slice(9)}` : ''),
  tipo: (t) => ({ CONSULTA: 'Consulta', RETORNO: 'Retorno', VACINACAO: 'Vacinação', EXAME: 'Exame', CIRURGIA: 'Cirurgia' }[t] ?? t),
  status: (s) => ({ AGENDADO: 'Agendado', REALIZADO: 'Realizado', CANCELADO: 'Cancelado', EM_ABERTO: 'Em atendimento', FINALIZADO: 'Finalizado' }[s] ?? s),
  carater: (c) => ({ ELETIVO: 'Eletivo', URGENCIA: 'Urgência', EMERGENCIA: 'Emergência' }[c] ?? c),
};

// Mesma conta da função cpf_valido() do banco, para avisar enquanto digita.
// A validação que vale continua sendo a do banco.
export function cpfValido(cpf) {
  const d = (cpf || '').replace(/\D/g, '');
  if (d.length !== 11 || /^(\d)\1{10}$/.test(d)) return false;
  const dv = (n) => {
    let soma = 0;
    for (let i = 0; i < n; i++) soma += Number(d[i]) * (n + 1 - i);
    const r = (soma * 10) % 11;
    return r === 10 ? 0 : r;
  };
  return dv(9) === Number(d[9]) && dv(10) === Number(d[10]);
}

const mascaraCpf = (v) => v.replace(/\D/g, '').slice(0, 11)
  .replace(/(\d{3})(\d)/, '$1.$2').replace(/(\d{3})(\d)/, '$1.$2').replace(/(\d{3})(\d{1,2})$/, '$1-$2');

// ------------------------------------------------------------ ícones de espécie
const ICONES = {
  'Cão': '<path d="M7 6c-2 0-4 3-4 7 0 1.6 1 2.4 2.2 2.4.9 0 1.5-.6 1.8-1.5V19c0 3 2.4 5 5 5s5-2 5-5v-5.1c.3.9.9 1.5 1.8 1.5 1.2 0 2.2-.8 2.2-2.4 0-4-2-7-4-7-1 0-1.8.5-2.4 1.2C14.8 6.4 13.5 6 12 6s-2.8.4-3.6 1.2C7.8 6.5 7.6 6 7 6Zm2.5 8.5a1.2 1.2 0 1 1 0-2.4 1.2 1.2 0 0 1 0 2.4Zm5 0a1.2 1.2 0 1 1 0-2.4 1.2 1.2 0 0 1 0 2.4ZM12 21c-1 0-1.8-.7-1.8-1.4 0-.6.9-1 1.8-1s1.8.4 1.8 1c0 .7-.8 1.4-1.8 1.4Z" transform="translate(0 -2)"/>',
  'Gato': '<path d="M4 3l4.2 5.1A9 9 0 0 1 12 7.4c1.4 0 2.7.3 3.8.7L20 3v9c.6 1 1 2.2 1 3.5C21 19.6 17 22 12 22s-9-2.4-9-6.5c0-1.3.4-2.5 1-3.5V3Zm5.5 10.2a1.3 1.3 0 1 0 0 2.6 1.3 1.3 0 0 0 0-2.6Zm5 0a1.3 1.3 0 1 0 0 2.6 1.3 1.3 0 0 0 0-2.6ZM12 17.6c-.8 0-1.4.3-1.4.7s.6 1 1.4 1 1.4-.6 1.4-1-.6-.7-1.4-.7Z"/>',
  'Ave': '<path d="M15 3a5 5 0 0 0-5 5v2.2C7 11 4 13.6 3 18c3-1.5 5.5-1.8 7.3-1.5L9 21h2.2l1.2-4c3.9-.5 6.6-3.6 6.6-7.5V8.6L22 7.3 19.6 6A5 5 0 0 0 15 3Zm.6 3.4a1.1 1.1 0 1 1 0 2.2 1.1 1.1 0 0 1 0-2.2Z"/>',
  'Roedor': '<path d="M8.5 5A3.5 3.5 0 0 0 5 8.5c0 1 .4 1.9 1 2.5A8 8 0 0 0 4 16.2C4 19.5 7.6 22 12 22s8-2.5 8-5.8c0-1.9-.7-3.7-2-5.2.6-.6 1-1.5 1-2.5a3.5 3.5 0 0 0-6.6-1.6 8.4 8.4 0 0 0-2.8 0A3.5 3.5 0 0 0 8.5 5Zm1 9a1.2 1.2 0 1 1 0 2.4 1.2 1.2 0 0 1 0-2.4Zm5 0a1.2 1.2 0 1 1 0 2.4 1.2 1.2 0 0 1 0-2.4ZM12 18c.8 0 1.4.3 1.4.7s-.6.9-1.4.9-1.4-.5-1.4-.9.6-.7 1.4-.7Z"/>',
  'Coelho': '<path d="M9 1.5C7.6 1.5 7 4 7 7c0 2 .4 3.6 1 4.6A6.6 6.6 0 0 0 5 17c0 3.3 3.1 5.5 7 5.5s7-2.2 7-5.5c0-2.2-1.2-4.2-3-5.4.6-1 1-2.6 1-4.6 0-3-.6-5.5-2-5.5S13 4 13 7v2.1a7.5 7.5 0 0 0-2 0V7c0-3-.6-5.5-2-5.5Zm.6 13.5a1.2 1.2 0 1 1 0 2.4 1.2 1.2 0 0 1 0-2.4Zm4.8 0a1.2 1.2 0 1 1 0 2.4 1.2 1.2 0 0 1 0-2.4Z"/>',
};
const icone = (especie, classe = '') =>
  `<span class="especie-icone ${classe}" title="${esc(especie)}"><svg viewBox="0 0 24 24" aria-hidden="true">${ICONES[especie] ?? ICONES['Cão']}</svg></span>`;

const plural = (n, um, varios) => (n === 1 ? um : varios);
const statusTag = (s) => `<span class="status ${s}">${fmt.status(s)}</span>`;

// ------------------------------------------------------------ aviso e janela
function avisar(texto) {
  const el = document.getElementById('aviso');
  el.textContent = texto;
  el.classList.add('visivel');
  clearTimeout(avisar.t);
  avisar.t = setTimeout(() => el.classList.remove('visivel'), 3200);
}

// Abre um formulário em janela. "aoEnviar" recebe os dados do form;
// se o banco recusar, a mensagem aparece dentro da própria janela.
function abrirJanela({ titulo, corpo, botao, aoEnviar, aoAbrir }) {
  const dlg = document.getElementById('janela');
  const form = document.getElementById('janela-form');
  const erro = document.getElementById('janela-erro');
  document.getElementById('janela-titulo').textContent = titulo;
  document.getElementById('janela-corpo').innerHTML = corpo;
  document.getElementById('janela-ok').textContent = botao;
  erro.hidden = true;

  form.onsubmit = async (ev) => {
    ev.preventDefault();
    const dados = Object.fromEntries(new FormData(form));
    form.querySelectorAll('input[type=checkbox]').forEach((c) => { dados[c.name] = c.checked; });
    try {
      await aoEnviar(dados);
      dlg.close();
    } catch (e) {
      erro.textContent = e.message;
      erro.hidden = false;
    }
  };
  dlg.querySelectorAll('[data-fechar]').forEach((b) => { b.onclick = () => dlg.close(); });
  dlg.showModal();
  aoAbrir?.(form);
  form.querySelector('input, select, textarea')?.focus();
}

// ------------------------------------------------------------ telas
const telas = {};

// PAINEL --------------------------------------------------------------
telas.painel = async () => {
  const { emAberto, proximos, numeros } = await api('painel');

  // agrupa os próximos horários por dia
  const porDia = {};
  for (const h of proximos) (porDia[fmt.diaExtenso(h.data_hora_inicio)] ??= []).push(h);

  return `
    <div class="cabecalho">
      <div>
        <h1>${esc(fmt.diaExtenso(new Date()).replace(/^./, (c) => c.toUpperCase()))}</h1>
        <p class="resumo"><b>${numeros.agendados_7_dias}</b> ${plural(numeros.agendados_7_dias, 'horário', 'horários')} nos próximos 7 dias,
          <b>${numeros.atendimentos_30_dias}</b> ${plural(numeros.atendimentos_30_dias, 'atendimento', 'atendimentos')} nos últimos 30 dias,
          <b>${numeros.animais}</b> pacientes de <b>${numeros.tutores}</b> tutores.</p>
      </div>
      <button class="botao" data-acao="novo-agendamento">Marcar horário</button>
    </div>

    <div class="painel">
      <section class="bloco">
        <h2>Na clínica agora <small>${emAberto.length} em atendimento</small></h2>
        ${emAberto.length ? emAberto.map((a) => `
          <a class="internado" href="#/animais/${a.id_animal}">
            ${icone(a.especie)}
            <span class="nome">${esc(a.animal)}</span>
            <span class="queixa">${esc(a.queixa_principal)}</span>
            <span class="meta">${fmt.carater(a.carater)} desde ${fmt.dataCurta(a.data_hora_inicio)}, ${fmt.hora(a.data_hora_inicio)}
              · ${esc(a.veterinario)} · tutor ${esc(a.tutor)}, ${fmt.telefone(a.telefone_tutor)}</span>
          </a>`).join('') : '<p class="vazio">Nenhum paciente em atendimento.</p>'}
      </section>

      <section class="bloco">
        <h2>Próximos horários</h2>
        ${Object.keys(porDia).length ? Object.entries(porDia).map(([dia, lista]) => `
          <div class="dia">
            <h3>${esc(dia)}</h3>
            ${lista.map((h) => `
              <div class="horario">
                <time>${fmt.hora(h.data_hora_inicio)}</time>
                <div>
                  <a href="#/animais/${h.id_animal}">${esc(h.animal)}</a> · ${fmt.tipo(h.tipo)}
                  <p>${esc(h.motivo ?? '')}${h.motivo ? ' · ' : ''}${esc(h.veterinario)}</p>
                </div>
              </div>`).join('')}
          </div>`).join('') : '<p class="vazio">Nenhum horário marcado. Use “Marcar horário” para agendar.</p>'}
        <a href="#/agenda">Ver agenda completa</a>
      </section>
    </div>`;
};

// AGENDA --------------------------------------------------------------
telas.agenda = async (params) => {
  const filtro = params.get('filtro') === 'todos' ? 'todos' : 'futuros';
  const lista = await api(`agenda?filtro=${filtro}`);
  return `
    <div class="cabecalho">
      <div>
        <h1>Agenda</h1>
        <p>${filtro === 'todos' ? 'Todos os horários, incluindo realizados e cancelados.' : 'Horários de hoje em diante.'}
          Conflitos de horário do mesmo veterinário são barrados pelo banco.</p>
      </div>
      <button class="botao" data-acao="novo-agendamento">Marcar horário</button>
    </div>
    <div class="filtros chips">
      <a class="chip" href="#/agenda" aria-pressed="${filtro === 'futuros'}">De hoje em diante</a>
      <a class="chip" href="#/agenda?filtro=todos" aria-pressed="${filtro === 'todos'}">Todos</a>
    </div>
    <div class="tabela-wrap">
      <table>
        <thead><tr><th>Quando</th><th>Paciente</th><th>Tipo</th><th>Veterinário</th><th>Status</th><th></th></tr></thead>
        <tbody>
          ${lista.map((h) => `
            <tr>
              <td>${fmt.data(h.data_hora_inicio)}<span class="sub">${fmt.hora(h.data_hora_inicio)} às ${fmt.hora(h.data_hora_fim)}</span></td>
              <td><a href="#/animais/${h.id_animal}">${esc(h.animal)}</a><span class="sub">${esc(h.especie)} · ${esc(h.tutor)}</span></td>
              <td>${fmt.tipo(h.tipo)}<span class="sub">${esc(h.motivo ?? '')}</span></td>
              <td>${esc(h.veterinario)}</td>
              <td>${statusTag(h.status)}${h.motivo_cancelamento ? `<span class="sub">${esc(h.motivo_cancelamento)}</span>` : ''}</td>
              <td>${h.status === 'AGENDADO' ? `<button class="link-botao" data-acao="cancelar" data-id="${h.id_agendamento}" data-nome="${esc(h.animal)}">Cancelar</button>` : ''}</td>
            </tr>`).join('') || '<tr><td colspan="6" class="vazio">Nenhum horário encontrado.</td></tr>'}
        </tbody>
      </table>
    </div>`;
};

// ANIMAIS -------------------------------------------------------------
telas.animais = async (params) => {
  const especie = params.get('especie') || '';
  const q = params.get('q') || '';
  const [lista, opcoes] = await Promise.all([
    api(`animais?especie=${encodeURIComponent(especie)}&q=${encodeURIComponent(q)}`),
    api('opcoes'),
  ]);
  return `
    <div class="cabecalho">
      <div><h1>Animais</h1><p>Clique em um paciente para abrir o prontuário.</p></div>
      <button class="botao" data-acao="novo-animal">Cadastrar animal</button>
    </div>
    <div class="filtros">
      <input type="search" placeholder="Buscar por animal ou tutor" value="${esc(q)}" data-busca="animais" aria-label="Buscar animal ou tutor">
      <div class="chips">
        <a class="chip" href="#/animais" aria-pressed="${!especie}">Todas as espécies</a>
        ${opcoes.especies.map((e) => `<a class="chip" href="#/animais?especie=${encodeURIComponent(e.nome)}" aria-pressed="${especie === e.nome}">${esc(e.nome)}</a>`).join('')}
      </div>
    </div>
    <div class="tabela-wrap">
      <table>
        <thead><tr><th></th><th>Nome</th><th>Raça</th><th class="num">Idade</th><th>Tutor</th><th>Último atendimento</th></tr></thead>
        <tbody>
          ${lista.map((a) => `
            <tr class="clicavel ${a.vivo ? '' : 'inativo'}" data-link="#/animais/${a.id_animal}">
              <td>${icone(a.especie, 'pequeno')}</td>
              <td><a href="#/animais/${a.id_animal}">${esc(a.animal)}</a>${a.vivo ? '' : '<span class="sub">óbito registrado</span>'}</td>
              <td>${esc(a.raca)}<span class="sub">${a.sexo === 'F' ? 'Fêmea' : 'Macho'}${a.castrado ? ', castrad' + (a.sexo === 'F' ? 'a' : 'o') : ''}</span></td>
              <td class="num">${a.idade_anos ?? '—'} ${a.idade_anos === 1 ? 'ano' : 'anos'}</td>
              <td>${esc(a.tutor)}<span class="sub">${fmt.telefone(a.telefone_tutor)}</span></td>
              <td>${a.ultimo_atendimento ? fmt.data(a.ultimo_atendimento) : '—'}</td>
            </tr>`).join('') || '<tr><td colspan="6" class="vazio">Nenhum animal encontrado.</td></tr>'}
        </tbody>
      </table>
    </div>`;
};

// PRONTUÁRIO ----------------------------------------------------------
telas.prontuario = async (params, id) => {
  const { animal: a, historico, agenda } = await api(`animais/${id}`);

  // tendência de peso: compara o atendimento mais recente com o anterior
  const pesos = historico.filter((h) => h.peso_kg != null);
  let tendencia = '';
  if (pesos.length >= 2) {
    const dif = pesos[0].peso_kg - pesos[1].peso_kg;
    tendencia = `<span class="peso-tendencia">${dif > 0 ? '+' : ''}${dif.toLocaleString('pt-BR', { maximumFractionDigits: 3 })} kg</span> desde ${fmt.data(pesos[1].data_hora_inicio)}`;
  }

  return `
    <p><a href="#/animais">Todos os animais</a></p>
    <div class="ficha">
      <div>
        <div class="cabecalho">
          <div class="ficha-nome">
            ${icone(a.especie)}
            <div>
              <h1>${esc(a.animal)}</h1>
              <p>${esc(a.especie)}, ${esc(a.raca)} · ${a.sexo === 'F' ? 'fêmea' : 'macho'} · ${a.idade_anos ?? '?'} anos
                ${a.vivo ? '' : `· <span class="obito">óbito em ${fmt.dataSimples(a.data_obito)}</span>`}</p>
            </div>
          </div>
          ${a.vivo ? `<button class="botao" data-acao="novo-agendamento" data-animal="${a.id_animal}">Marcar horário</button>` : ''}
        </div>

        <h2 style="margin-bottom:1.25rem">Histórico clínico</h2>
        ${historico.length ? `<ol class="linha-tempo">
          ${historico.map((h) => `
            <li class="evento ${h.status}">
              <div class="quando"><b>${fmt.dataCurta(h.data_hora_inicio)}</b><span>${fmt.ano(h.data_hora_inicio)}</span></div>
              <div>
                <h3>${esc(h.queixa_principal)}</h3>
                ${h.status === 'EM_ABERTO' ? statusTag('EM_ABERTO') : ''}
                ${h.diagnostico ? `<p>${esc(h.diagnostico)}</p>` : ''}
                <p class="meta">${esc(h.veterinario)} · ${fmt.carater(h.carater)}${h.peso_kg != null ? ` · ${fmt.peso(h.peso_kg)}` : ''}${h.temperatura_c != null ? ` · ${String(h.temperatura_c).replace('.', ',')} °C` : ''}${h.valor_total ? ` · ${fmt.dinheiro(h.valor_total)}` : ''}</p>
                <ul class="itens">
                  ${(h.procedimentos ?? '').split('; ').filter(Boolean).map((p) => `<li class="proc">${esc(p)}</li>`).join('')}
                  ${(h.prescricoes ?? '').split('; ').filter(Boolean).map((p) => `<li class="med">${esc(p)}</li>`).join('')}
                </ul>
              </div>
            </li>`).join('')}
        </ol>` : '<p class="vazio">Ainda sem atendimentos registrados.</p>'}
      </div>

      <aside>
        <div class="dados">
          <h3 style="margin-bottom:.6rem">Tutor</h3>
          <dl>
            <dt>Nome</dt><dd>${esc(a.tutor)}</dd>
            <dt>Telefone</dt><dd>${fmt.telefone(a.telefone_tutor)}</dd>
            ${a.email_tutor ? `<dt>E-mail</dt><dd>${esc(a.email_tutor)}</dd>` : ''}
          </dl>
        </div>
        <div class="dados">
          <h3 style="margin-bottom:.6rem">Paciente</h3>
          <dl>
            <dt>Nascimento</dt><dd>${fmt.dataSimples(a.data_nascimento)}</dd>
            <dt>Pelagem</dt><dd>${esc(a.pelagem ?? '—')}</dd>
            <dt>Castrado</dt><dd>${a.castrado ? 'Sim' : 'Não'}</dd>
            <dt>Microchip</dt><dd>${esc(a.microchip ?? '—')}</dd>
            <dt>Último peso</dt><dd>${pesos.length ? fmt.peso(pesos[0].peso_kg) : '—'}${tendencia ? `<br><small>${tendencia}</small>` : ''}</dd>
          </dl>
          ${a.observacoes ? `<p style="margin:.8rem 0 0">${esc(a.observacoes)}</p>` : ''}
        </div>
        <div class="dados">
          <h3 style="margin-bottom:.6rem">Próximos horários</h3>
          ${agenda.length ? agenda.map((g) => `<p style="margin:.3rem 0">${fmt.data(g.data_hora_inicio)}, ${fmt.hora(g.data_hora_inicio)}<br><small>${fmt.tipo(g.tipo)} com ${esc(g.veterinario)}</small></p>`).join('') : '<p class="vazio" style="padding:0">Nenhum horário marcado.</p>'}
        </div>
      </aside>
    </div>`;
};

// TUTORES -------------------------------------------------------------
telas.tutores = async (params) => {
  const q = params.get('q') || '';
  const lista = await api(`tutores?q=${encodeURIComponent(q)}`);
  return `
    <div class="cabecalho">
      <div><h1>Tutores</h1><p>O CPF é conferido pelos dígitos verificadores no próprio banco de dados.</p></div>
      <button class="botao" data-acao="novo-tutor">Cadastrar tutor</button>
    </div>
    <div class="filtros">
      <input type="search" placeholder="Buscar por nome ou CPF" value="${esc(q)}" data-busca="tutores" aria-label="Buscar tutor">
    </div>
    <div class="tabela-wrap">
      <table>
        <thead><tr><th>Nome</th><th>CPF</th><th>Contato</th><th>Cidade</th><th>Animais</th></tr></thead>
        <tbody>
          ${lista.map((t) => `
            <tr>
              <td>${esc(t.nome)}</td>
              <td>${fmt.cpf(t.cpf)}</td>
              <td>${fmt.telefone(t.telefone)}<span class="sub">${esc(t.email ?? '')}</span></td>
              <td>${esc(t.cidade)}/${esc(t.uf)}</td>
              <td>${t.qtd_animais ? esc(t.animais) : '<span class="sub">nenhum</span>'}</td>
            </tr>`).join('') || '<tr><td colspan="5" class="vazio">Nenhum tutor encontrado.</td></tr>'}
        </tbody>
      </table>
    </div>`;
};

// RELATÓRIOS ----------------------------------------------------------
telas.relatorios = async (params) => {
  const de = params.get('de') || '2026-01-01';
  const ate = params.get('ate') || '2026-12-31';
  const { ranking, medicamentos, altoCusto } = await api(`relatorios?de=${de}&ate=${ate}`);
  const maior = Math.max(1, ...ranking.map((r) => r.atendimentos));

  const porEspecie = {};
  for (const m of medicamentos) (porEspecie[m.especie] ??= []).push(m);

  return `
    <div class="cabecalho"><div><h1>Relatórios</h1><p>As mesmas consultas do arquivo 03_consultas.sql, executadas ao vivo no banco.</p></div></div>
    <div class="relatorios">
      <section>
        <h2 style="margin-bottom:.8rem">Atendimentos por veterinário</h2>
        <form class="periodo" data-periodo>
          <label>De <input type="date" name="de" value="${de}"></label>
          <label>Até <input type="date" name="ate" value="${ate}"></label>
          <button class="botao secundario">Atualizar</button>
        </form>
        ${ranking.map((r) => `
          <div class="barra-wrap ${r.ativo ? '' : 'inativo'}" title="${r.urgencias} urgências/emergências">
            <span class="rotulo">${r.posicao}º ${esc(r.veterinario.replace(/^Dra?\. /, ''))}</span>
            <span class="barra" style="width:${(r.atendimentos / maior) * 100}%"></span>
            <span class="valor">${r.atendimentos}</span>
          </div>`).join('')}
        <p class="sub" style="color:var(--tinta-suave)">Barra cinza: profissional desligado.</p>
      </section>

      <section>
        <h2 style="margin-bottom:.8rem">Medicamentos mais prescritos</h2>
        ${Object.entries(porEspecie).map(([esp, lista]) => `
          <div class="especie-grupo">
            <h3>${icone(esp, 'pequeno')} ${esc(esp)}</h3>
            <ul>${lista.map((m) => `<li>${esc(m.medicamento)} <span>${m.prescricoes} ${m.prescricoes === 1 ? 'prescrição' : 'prescrições'}</span></li>`).join('')}</ul>
          </div>`).join('')}
      </section>

      <section>
        <h2 style="margin-bottom:.8rem">Pacientes acima do gasto médio</h2>
        <p style="color:var(--tinta-suave);margin-top:0">Média por paciente: ${fmt.dinheiro(altoCusto[0]?.media)}</p>
        <div class="tabela-wrap">
          <table>
            <thead><tr><th>Paciente</th><th class="num">Gasto</th></tr></thead>
            <tbody>
              ${altoCusto.map((p) => `
                <tr class="clicavel" data-link="#/animais/${p.id_animal}">
                  <td><a href="#/animais/${p.id_animal}">${esc(p.animal)}</a><span class="sub">${esc(p.especie)} · ${esc(p.tutor)}</span></td>
                  <td class="num">${fmt.dinheiro(p.gasto_total)}</td>
                </tr>`).join('')}
            </tbody>
          </table>
        </div>
      </section>
    </div>`;
};

// ------------------------------------------------------------ formulários
async function novoAgendamento(idAnimal) {
  const { animais, veterinarios } = await api('opcoes');
  // sugestão: próximo dia útil às 9h
  const amanha = new Date(Date.now() + 86400000);
  const sugestao = `${amanha.toLocaleDateString('sv-SE', { timeZone: FUSO })}T09:00`;
  abrirJanela({
    titulo: 'Marcar horário',
    botao: 'Marcar horário',
    corpo: `
      <div class="campos">
        <label class="largo">Paciente
          <select name="id_animal" required>
            <option value="">Escolha o animal</option>
            ${animais.map((a) => `<option value="${a.id}" ${String(a.id) === String(idAnimal) ? 'selected' : ''}>${esc(a.nome)} (${esc(a.especie)}, tutor ${esc(a.tutor)})</option>`).join('')}
          </select>
        </label>
        <label class="largo">Veterinário
          <select name="id_veterinario" required>
            <option value="">Escolha o profissional</option>
            ${veterinarios.map((v) => `<option value="${v.id}">${esc(v.nome)}</option>`).join('')}
          </select>
        </label>
        <label>Data e hora <input type="datetime-local" name="inicio" value="${sugestao}" required></label>
        <label>Duração
          <select name="duracao_min">
            <option value="20">20 minutos</option><option value="30" selected>30 minutos</option>
            <option value="45">45 minutos</option><option value="60">1 hora</option><option value="120">2 horas</option>
          </select>
        </label>
        <label>Tipo
          <select name="tipo">
            <option value="CONSULTA">Consulta</option><option value="RETORNO">Retorno</option>
            <option value="VACINACAO">Vacinação</option><option value="EXAME">Exame</option><option value="CIRURGIA">Cirurgia</option>
          </select>
        </label>
        <label>Motivo <input name="motivo" maxlength="200" placeholder="Ex.: vacinação anual"></label>
      </div>`,
    aoEnviar: async (d) => {
      await api('agendamentos', { method: 'POST', body: d });
      avisar('Horário marcado.');
      renderizar();
    },
  });
}

function cancelarAgendamento(id, nome) {
  abrirJanela({
    titulo: `Cancelar horário de ${nome}`,
    botao: 'Cancelar horário',
    corpo: `<label>Motivo do cancelamento <span class="dica">obrigatório, fica registrado no histórico</span>
              <input name="motivo" maxlength="200" required placeholder="Ex.: tutor pediu para remarcar"></label>`,
    aoEnviar: async (d) => {
      await api(`agendamentos/${id}/cancelar`, { method: 'POST', body: d });
      avisar('Horário cancelado.');
      renderizar();
    },
  });
}

function novoTutor() {
  abrirJanela({
    titulo: 'Cadastrar tutor',
    botao: 'Cadastrar tutor',
    corpo: `
      <div class="campos">
        <label class="largo">Nome completo <input name="nome" required maxlength="120"></label>
        <label>CPF
          <input name="cpf" required inputmode="numeric" placeholder="000.000.000-00" data-cpf>
          <span class="dica" data-cpf-dica>só números ou com pontos</span></label>
        <label>Telefone <input name="telefone" required inputmode="tel" placeholder="(34) 99999-9999"></label>
        <label>E-mail <input name="email" type="email" maxlength="120"></label>
        <label>Nascimento <input name="data_nascimento" type="date"></label>
        <label class="largo">Endereço <input name="logradouro" maxlength="120" placeholder="Rua, avenida..."></label>
        <label>Número <input name="numero" maxlength="10"></label>
        <label>Bairro <input name="bairro" maxlength="60"></label>
        <label>Cidade <input name="cidade" required maxlength="60" value="Uberlândia"></label>
        <label>UF <input name="uf" required maxlength="2" value="MG"></label>
        <label>CEP <input name="cep" inputmode="numeric" maxlength="9"></label>
      </div>`,
    aoAbrir: (form) => {
      const campo = form.querySelector('[data-cpf]');
      const dica = form.querySelector('[data-cpf-dica]');
      campo.addEventListener('input', () => {
        campo.value = mascaraCpf(campo.value);
        const digitos = campo.value.replace(/\D/g, '').length;
        const ok = cpfValido(campo.value);
        campo.classList.toggle('valido', ok);
        campo.classList.toggle('invalido', digitos === 11 && !ok);
        dica.textContent = digitos < 11 ? 'só números ou com pontos' : ok ? 'CPF válido' : 'dígitos verificadores não conferem';
      });
    },
    aoEnviar: async (d) => {
      await api('tutores', { method: 'POST', body: d });
      avisar('Tutor cadastrado.');
      renderizar();
    },
  });
}

async function novoAnimal() {
  const [{ especies, racas }, tutores] = await Promise.all([api('opcoes'), api('tutores')]);
  abrirJanela({
    titulo: 'Cadastrar animal',
    botao: 'Cadastrar animal',
    corpo: `
      <div class="campos">
        <label class="largo">Tutor
          <select name="id_tutor" required>
            <option value="">Escolha o tutor</option>
            ${tutores.map((t) => `<option value="${t.id_tutor}">${esc(t.nome)} (${fmt.cpf(t.cpf)})</option>`).join('')}
          </select>
        </label>
        <label>Nome <input name="nome" required maxlength="60"></label>
        <label>Sexo
          <select name="sexo" required><option value="F">Fêmea</option><option value="M">Macho</option></select>
        </label>
        <label>Espécie
          <select data-especie required>
            ${especies.map((e) => `<option value="${e.id}">${esc(e.nome)}</option>`).join('')}
          </select>
        </label>
        <label>Raça <select name="id_raca" required data-raca></select></label>
        <label>Nascimento <input name="data_nascimento" type="date"></label>
        <label>Pelagem <input name="pelagem" maxlength="40"></label>
        <label>Microchip <input name="microchip" inputmode="numeric" maxlength="15"><span class="dica">15 dígitos, opcional</span></label>
        <label class="checkbox"><input type="checkbox" name="castrado"> Castrado</label>
      </div>`,
    aoAbrir: (form) => {
      // a lista de raças depende da espécie escolhida
      const selEspecie = form.querySelector('[data-especie]');
      const selRaca = form.querySelector('[data-raca]');
      const preencher = () => {
        selRaca.innerHTML = racas.filter((r) => String(r.id_especie) === selEspecie.value)
          .map((r) => `<option value="${r.id}">${esc(r.nome)}</option>`).join('');
      };
      selEspecie.addEventListener('change', preencher);
      preencher();
    },
    aoEnviar: async (d) => {
      const { id_animal } = await api('animais', { method: 'POST', body: d });
      avisar('Animal cadastrado.');
      location.hash = `#/animais/${id_animal}`;
    },
  });
}

// ------------------------------------------------------------ eventos globais
document.addEventListener('click', (ev) => {
  const alvo = ev.target.closest('[data-acao]');
  if (alvo) {
    const acao = alvo.dataset.acao;
    if (acao === 'novo-agendamento') novoAgendamento(alvo.dataset.animal);
    if (acao === 'cancelar') cancelarAgendamento(alvo.dataset.id, alvo.dataset.nome);
    if (acao === 'novo-tutor') novoTutor();
    if (acao === 'novo-animal') novoAnimal();
    return;
  }
  // linha de tabela clicável (sem atrapalhar cliques em links dentro dela)
  const linha = ev.target.closest('tr[data-link]');
  if (linha && !ev.target.closest('a, button')) location.hash = linha.dataset.link;
});

// busca: atualiza a URL depois que a pessoa para de digitar
let esperaBusca;
document.addEventListener('input', (ev) => {
  const campo = ev.target.closest('[data-busca]');
  if (!campo) return;
  clearTimeout(esperaBusca);
  esperaBusca = setTimeout(() => {
    const p = new URLSearchParams(location.hash.split('?')[1]);
    campo.value ? p.set('q', campo.value) : p.delete('q');
    location.hash = `#/${campo.dataset.busca}${p.toString() ? `?${p}` : ''}`;
  }, 350);
});

document.addEventListener('submit', (ev) => {
  const form = ev.target.closest('[data-periodo]');
  if (!form) return;
  ev.preventDefault();
  const d = new FormData(form);
  location.hash = `#/relatorios?de=${d.get('de')}&ate=${d.get('ate')}`;
});

// ------------------------------------------------------------ roteador
async function renderizar() {
  const [caminho, busca] = location.hash.slice(2).split('?');
  const [secao, id] = (caminho || 'painel').split('/');
  const params = new URLSearchParams(busca);

  document.querySelectorAll('.topo nav a').forEach((a) => {
    a.toggleAttribute('aria-current', a.getAttribute('href') === `#/${secao}`);
    if (a.hasAttribute('aria-current')) a.setAttribute('aria-current', 'page');
  });

  const tela = secao === 'animais' && id ? telas.prontuario : telas[secao];
  if (!tela) { location.hash = '#/painel'; return; }

  // mantém o foco na busca enquanto a pessoa digita
  const buscaAtiva = document.activeElement?.dataset?.busca;
  try {
    $conteudo.innerHTML = await tela(params, id);
  } catch (e) {
    $conteudo.innerHTML = `<h1>Não foi possível carregar</h1><p>${esc(e.message)}</p>
      <p>Confira se o servidor está rodando e se o arquivo <code>.env</code> tem a senha certa do PostgreSQL.</p>`;
  }
  if (buscaAtiva) {
    const campo = $conteudo.querySelector(`[data-busca="${buscaAtiva}"]`);
    campo?.focus();
    campo?.setSelectionRange(campo.value.length, campo.value.length);
  }
  document.title = `${document.querySelector('h1')?.textContent ?? 'Painel'} · Clínica Veterinária`;
}

window.addEventListener('hashchange', renderizar);
renderizar();
