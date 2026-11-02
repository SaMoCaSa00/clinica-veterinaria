# Interface web

Aplicação em **Node.js + Express** que usa o banco `clinica_vet`. O front-end é HTML, CSS e JavaScript puro, sem framework.

| Tela | O que faz | Regra do banco que aparece |
|---|---|---|
| Painel | Pacientes em atendimento e próximos horários (consulta Q1) | — |
| Agenda | Lista, marca e cancela horários | conflito de agenda (GiST), motivo obrigatório no cancelamento |
| Animais | Lista com filtro por espécie e busca; cadastro | microchip único, raça ligada à espécie |
| Prontuário | Histórico clínico em linha do tempo (`vw_historico_clinico`) | — |
| Tutores | Lista, busca e cadastro com validação de CPF | `cpf_valido()`, CPF e e-mail únicos |
| Relatórios | Ranking de veterinários (Q2), medicamentos por espécie (Q4) e pacientes acima da média (Q5) | — |

As regras ficam no PostgreSQL. A interface só traduz o erro do banco para uma mensagem legível (`db.js`). O CPF também é conferido no navegador enquanto a pessoa digita, mas quem decide é o banco.

## Como rodar

Pré-requisitos: [Node.js 18+](https://nodejs.org) e o banco `clinica_vet` já criado com os scripts da pasta `sql/`.

```bash
cd app
npm install
cp .env.example .env      # no Windows: copy .env.example .env
# edite o .env e coloque a senha do seu PostgreSQL em PGPASSWORD
npm start
```

Depois é só abrir <http://localhost:3000>.

## Arquivos

```
app/
├── server.js        # rotas da API (/api/...) e servidor estático
├── db.js            # conexão com o PostgreSQL e tradução de erros
├── public/
│   ├── index.html   # estrutura da página
│   ├── styles.css   # visual
│   └── app.js       # telas, formulários e roteamento por #hash
└── .env.example     # modelo de configuração (o .env real não vai pro Git)
```
