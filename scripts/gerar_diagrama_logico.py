"""Gera o diagrama lógico (relações, atributos, PK/FK/UQ, nulidade) a partir do catálogo do PostgreSQL.

Tipos de dados ficam de fora de propósito: pertencem ao modelo físico.

Uso:
    python scripts/gerar_diagrama_logico.py "dbname=clinica_vet user=postgres" > docs/diagramas/modelo_logico.dot
    dot -Tsvg docs/diagramas/modelo_logico.dot -o docs/diagramas/modelo_logico.svg

Lendo o próprio banco, o diagrama nunca fica desatualizado em relação ao DDL.
"""
import sys
from collections import defaultdict

import psycopg2

DSN = sys.argv[1] if len(sys.argv) > 1 else "dbname=clinica_vet"
SCHEMA = "clinica"

COLS = """
SELECT c.table_name, c.column_name, c.is_nullable = 'NO',
       CASE WHEN c.data_type IN ('character varying') THEN 'varchar(' || c.character_maximum_length || ')'
            WHEN c.data_type = 'character'            THEN 'char(' || c.character_maximum_length || ')'
            WHEN c.data_type = 'numeric'              THEN 'numeric(' || c.numeric_precision || ',' || c.numeric_scale || ')'
            WHEN c.data_type = 'timestamp with time zone' THEN 'timestamptz'
            ELSE c.data_type END
  FROM information_schema.columns c
  JOIN information_schema.tables t
    ON t.table_schema = c.table_schema AND t.table_name = c.table_name
 WHERE c.table_schema = %s AND t.table_type = 'BASE TABLE'
 ORDER BY c.table_name, c.ordinal_position
"""

KEYS = """
SELECT tc.table_name, kcu.column_name, tc.constraint_type,
       count(*) OVER (PARTITION BY tc.constraint_name) AS ncols
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu
    ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
 WHERE tc.table_schema = %s AND tc.constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY', 'UNIQUE')
"""

FKS = """
SELECT con.conname, src.relname, tgt.relname,
       array_agg(a.attname ORDER BY k.ord) AS cols
  FROM pg_constraint con
  JOIN pg_class src ON src.oid = con.conrelid
  JOIN pg_class tgt ON tgt.oid = con.confrelid
  JOIN pg_namespace n ON n.oid = con.connamespace
  CROSS JOIN LATERAL unnest(con.conkey) WITH ORDINALITY k(attnum, ord)
  JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = k.attnum
 WHERE con.contype = 'f' AND n.nspname = %s
 GROUP BY con.conname, src.relname, tgt.relname
"""

with psycopg2.connect(DSN) as conn, conn.cursor() as cur:
    cur.execute(COLS, (SCHEMA,)); cols = cur.fetchall()
    cur.execute(KEYS, (SCHEMA,)); keys = cur.fetchall()
    cur.execute(FKS, (SCHEMA,)); fks = cur.fetchall()

flags = defaultdict(set)
for tab, col, kind, ncols in keys:
    if kind == "UNIQUE" and ncols > 1:   # UNIQUE composto não torna a coluna única sozinha
        continue
    flags[(tab, col)].add({"PRIMARY KEY": "PK", "FOREIGN KEY": "FK", "UNIQUE": "UQ"}[kind])

tables = defaultdict(list)
notnull = {}
for tab, col, nn, typ in cols:
    tables[tab].append((col, typ))
    notnull[(tab, col)] = nn

out = ['digraph logico {',
       '  graph [rankdir=LR, splines=spline, nodesep=0.4, ranksep=1.1, fontname="Inter", pad=0.3, bgcolor="white"];',
       '  node  [shape=plain, fontname="Inter", fontsize=10];',
       '  edge  [color="#5b6472", penwidth=1.1, arrowsize=0.9, dir=both];']

for tab, columns in tables.items():
    rows = [f'<TR><TD BGCOLOR="#1d3557" COLSPAN="2"><FONT COLOR="white"><B>{tab}</B></FONT></TD></TR>']
    for col, typ in columns:
        f = flags[(tab, col)]
        tag = " ".join(k for k in ("PK", "FK", "UQ") if k in f)
        name = f"<B>{col}</B>" if "PK" in f else col
        if "FK" in f:
            name = f"<I>{name}</I>"
        if not notnull[(tab, col)]:          # coluna opcional (aceita NULL)
            name += ' <FONT COLOR="#8d99ae">∅</FONT>'
        tag_cell = (f'<FONT COLOR="#c1121f" POINT-SIZE="8">{tag}</FONT>' if tag else " ")
        rows.append(f'<TR><TD ALIGN="LEFT" PORT="{col}">{name}</TD>'
                    f'<TD ALIGN="RIGHT">{tag_cell}</TD></TR>')
    out.append(f'  {tab} [label=<<TABLE BORDER="1.2" CELLBORDER="0" CELLSPACING="0" CELLPADDING="3" COLOR="#1d3557">{"".join(rows)}</TABLE>>];')

# Pé-de-galinha: lado "muitos" na tabela que contém a FK.
for name, src, tgt, fcols in fks:
    col = fcols[0]
    optional_src = not all(notnull[(src, c)] for c in fcols)
    # lado da tabela referenciada: (1,1) se FK obrigatória, (0,1) se opcional
    tail = "teeodot" if optional_src else "teetee"
    # lado da FK: muitos (0..N); se a FK também é UNIQUE, a relação é 1:1 -> (0,1)
    unique = "UQ" in flags[(src, col)] and "PK" not in flags[(src, col)]
    head = "teeodot" if unique else "crowodot"
    out.append(f'  {tgt} -> {src}:{col} [arrowtail={tail}, arrowhead={head}];')

out.append('}')
print("\n".join(out))
