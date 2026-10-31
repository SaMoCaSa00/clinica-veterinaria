# Sistema de Gestão de Clínica Veterinária

Banco de dados relacional em **PostgreSQL** para a rotina de uma clínica veterinária: tutores, animais, veterinários, agenda, atendimentos, procedimentos, prescrições e histórico clínico.

Trabalho prático da disciplina de Banco de Dados — Engenharia de Computação, Universidade Federal de Uberlândia (UFU).

📄 **[Relatório completo (PDF)](docs/relatorio.pdf)**: modelos conceitual, lógico e físico, justificativas de normalização, tipos e índices, e a explicação de cada consulta com o resultado.

---

## Destaques

- **13 tabelas em 3FN/FNBC** com PKs, FKs, `UNIQUE`, `NOT NULL` e `CHECK` de domínio, formato e semântica.
- **Regras de negócio no próprio banco**, não só na aplicação:
  - agenda sem conflito por veterinário, via restrição de exclusão GiST (`tstzrange` + `btree_gist`);
  - FK composta que garante que o atendimento vinculado a um agendamento seja do mesmo animal;
  - gatilhos que marcam o agendamento como `REALIZADO`, barram atendimento de horário cancelado ou de animal com óbito e congelam o preço praticado (histórico imune a reajustes).
- **Índices justificados**: compostos, parciais (`WHERE status = 'AGENDADO'`) e de expressão (`lower(nome)`).
- **Visões** `vw_animal` e `vw_historico_clinico` (prontuário consolidado).
- Scripts **idempotentes e transacionais**, com `COMMENT ON` em todos os objetos.
- Diagrama lógico **gerado a partir do catálogo** e relatório PDF **montado executando as consultas**, de modo que a documentação acompanha o código.

## Modelo

| Conceitual (Chen) | Lógico |
|---|---|
| ![DER](docs/diagramas/der_conceitual.svg) | ![Modelo lógico](docs/diagramas/modelo_logico.svg) |

## Estrutura

```
.
├── sql/
│   ├── 00_criar_banco.sql      # CREATE DATABASE (rodar conectado ao banco "postgres")
│   ├── 01_ddl.sql              # esquema, tabelas, restrições, índices, gatilhos, visões
│   ├── 02_dml.sql              # carga de dados + exemplos de UPDATE/DELETE + testes de integridade
│   └── 03_consultas.sql        # 5 consultas obrigatórias + 4 complementares
├── docs/
│   ├── relatorio.pdf           # entregável
│   ├── relatorio/              # fonte do relatório (HTML + CSS)
│   └── diagramas/              # .dot (fonte), .svg e .png
├── scripts/
│   ├── gerar_diagrama_logico.py
│   ├── gerar_relatorio.py
│   └── requirements.txt
└── docker-compose.yml          # PostgreSQL 16 + pgAdmin 4 prontos
```

## Como executar

### pgAdmin 4

1. No banco `postgres`, abra a **Query Tool** e execute `sql/00_criar_banco.sql`.
2. Atualize a árvore, selecione `clinica_vet` e abra uma Query Tool nele.
3. Execute `01_ddl.sql`, depois `02_dml.sql`.
4. Em `03_consultas.sql`, selecione uma consulta e pressione **F5**.

Os objetos ficam em `clinica_vet → Schemas → clinica`. Para não precisar prefixar: `SET search_path TO clinica;`.

### psql

```bash
psql -U postgres -f sql/00_criar_banco.sql
psql -U postgres -d clinica_vet -f sql/01_ddl.sql
psql -U postgres -d clinica_vet -f sql/02_dml.sql
psql -U postgres -d clinica_vet -f sql/03_consultas.sql
```

### Docker

```bash
docker compose up -d
```

Sobe o PostgreSQL 16 em `localhost:5432` (usuário e senha `postgres`) já com esquema e dados, e o pgAdmin em <http://localhost:5050> (`admin@clinica.local` / `admin`). Para recomeçar do zero: `docker compose down -v`.

## Consultas

| # | Pergunta de negócio | Técnicas |
|---|---|---|
| Q1 | Animais com atendimento em aberto ou agendamento futuro | CTEs, `UNION ALL`, visão |
| Q2 | Ranking de veterinários por atendimentos no período | `LEFT JOIN` com filtro no `ON`, `FILTER`, `RANK()`, `SUM() OVER ()` |
| Q3 | Tutores com mais de um animal + resumo de procedimentos | `HAVING`, CTEs por nível de agregação, `string_agg` |
| Q4 | Medicamentos mais prescritos por espécie | junção de 6 tabelas, `DENSE_RANK() OVER (PARTITION BY ...)` |
| Q5 | Pacientes com gasto acima da média | junção de 6 tabelas, agregação, subconsulta em tabela derivada no `HAVING` |
| C1 | Prontuário de um animal | visão com `LEFT JOIN LATERAL` |
| C2 | Faturamento mensal por categoria | pivot com `SUM(...) FILTER` |
| C3 | Cães e gatos sem vacina há 12 meses | anti-join `NOT EXISTS`, subconsulta correlacionada |
| C4 | Taxa de cancelamento por veterinário | agregação condicional |

> Os dados vão de jan/2026 a jan/2027, com 27/10/2026 como "hoje". Q1 e C3 usam `now()`; se rodar bem depois dessa data, troque `now()` por uma data fixa na CTE `params`.

## Regerar diagramas e relatório

Com o banco carregado:

```bash
pip install -r scripts/requirements.txt
DSN="dbname=clinica_vet user=postgres password=postgres host=localhost"

python scripts/gerar_diagrama_logico.py "$DSN" > docs/diagramas/modelo_logico.dot
for f in der_conceitual modelo_logico; do
  dot -Tsvg docs/diagramas/$f.dot -o docs/diagramas/$f.svg
  dot -Tpng -Gdpi=200 docs/diagramas/$f.dot -o docs/diagramas/$f.png
done

python scripts/gerar_relatorio.py "$DSN"    # -> docs/relatorio.pdf
```

Requer [Graphviz](https://graphviz.org/) para os diagramas.

## Autor

**Samuell** — Engenharia de Computação, UFU
