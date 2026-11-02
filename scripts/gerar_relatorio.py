"""Gera docs/relatorio.pdf a partir de docs/relatorio/relatorio.html.

O template contém marcadores que são substituídos por conteúdo vivo:
    {{SQL:Q1}}            código da consulta Q1 extraído de sql/03_consultas.sql (com realce)
    {{RES:Q1}}            resultado da consulta Q1 executada no banco
    {{DDL:agendamento}}   CREATE TABLE da tabela, extraído de sql/01_ddl.sql
    {{FUNC:nome}}         CREATE FUNCTION nome(...) extraído de sql/01_ddl.sql
    {{CONTAGEM}}          quantidade de registros por tabela

Assim o PDF sempre reflete exatamente os scripts entregues.

Uso:
    pip install weasyprint pygments psycopg2-binary
    python scripts/gerar_relatorio.py "dbname=clinica_vet user=postgres password=postgres host=localhost"
"""
import html
import re
import sys
from datetime import date, datetime
from decimal import Decimal
from pathlib import Path

import psycopg2
from pygments import highlight
from pygments.formatters import HtmlFormatter
from pygments.lexers import PostgresLexer
from weasyprint import HTML

ROOT = Path(__file__).resolve().parent.parent
SQL_DIR = ROOT / "sql"
TEMPLATE = ROOT / "docs" / "relatorio" / "relatorio.html"
OUTPUT = ROOT / "docs" / "relatorio.pdf"
DSN = sys.argv[1] if len(sys.argv) > 1 else "dbname=clinica_vet"

LEXER = PostgresLexer()
FORMATTER = HtmlFormatter(nowrap=True)


def code(sql: str) -> str:
    return f'<pre class="code">{highlight(sql.strip(), LEXER, FORMATTER)}</pre>'


# ---------------------------------------------------------------- consultas
def parse_queries(text: str) -> dict:
    """Separa 03_consultas.sql em blocos {id: sql} usando os cabeçalhos '-- Q1.' / '-- C1.'."""
    heads = list(re.finditer(r"^-- ([QC]\d+)\. ", text, re.M))
    blocks = {}
    for i, m in enumerate(heads):
        end = heads[i + 1].start() if i + 1 < len(heads) else len(text)
        lines = text[m.start():end].splitlines()
        # descarta o cabeçalho (linhas de comentário iniciais)
        while lines and (lines[0].startswith("--") or not lines[0].strip()):
            lines.pop(0)
        # descarta separadores/comentários finais
        while lines and (lines[-1].startswith("--") or not lines[-1].strip()):
            lines.pop()
        blocks[m.group(1)] = "\n".join(lines)
    return blocks


def fmt(v) -> str:
    if v is None:
        return '<span class="null">—</span>'
    if isinstance(v, bool):
        return "sim" if v else "não"
    if isinstance(v, Decimal):
        places = max(0, -v.as_tuple().exponent)
        if places > 2:                       # ex.: peso 37.900 -> 37,9
            places = max(1, -v.normalize().as_tuple().exponent)
        s = f"{v:,.{places}f}"
        return s.replace(",", "X").replace(".", ",").replace("X", ".")   # padrão pt-BR
    if isinstance(v, datetime):
        return v.strftime("%d/%m/%Y %H:%M")
    if isinstance(v, date):
        return v.strftime("%d/%m/%Y")
    return html.escape(str(v))


def result_table(cur, sql: str) -> str:
    cur.execute(sql)
    cols = [d.name for d in cur.description]
    rows = cur.fetchall()
    numeric = [all(isinstance(r[i], (int, float, Decimal)) and not isinstance(r[i], bool)
                   for r in rows if r[i] is not None) and any(r[i] is not None for r in rows)
               for i in range(len(cols))]
    head = "".join(f"<th>{html.escape(c)}</th>" for c in cols)
    body = "".join(
        "<tr>" + "".join(f'<td class="{"num" if numeric[i] else ""}">{fmt(v)}</td>'
                         for i, v in enumerate(r)) + "</tr>"
        for r in rows)
    n = len(rows)
    return (f'<table class="result"><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table>'
            f'<p class="rowcount">{n} linha{"s" if n != 1 else ""} retornada{"s" if n != 1 else ""}.</p>')


# ---------------------------------------------------------------- DDL
def ddl_table(ddl: str, name: str) -> str:
    m = re.search(rf"^CREATE TABLE {name} \(.*?^\);", ddl, re.M | re.S)
    return code(m.group(0))


def ddl_function(ddl: str, name: str) -> str:
    m = re.search(rf"^CREATE OR REPLACE FUNCTION {name}\(.*?^LANGUAGE plpgsql;", ddl, re.M | re.S)
    return code(m.group(0))


def n_indices(cur) -> int:
    cur.execute("SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'clinica'")
    return cur.fetchone()[0]


def counts(cur) -> str:
    cur.execute("""
        SELECT c.relname,
               (xpath('/row/n/text()',
                      query_to_xml(format('SELECT count(*) AS n FROM clinica.%I', c.relname), false, true, '')))[1]::text::int
          FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname = 'clinica' AND c.relkind = 'r'
         ORDER BY 2 DESC, 1""")
    rows = cur.fetchall()
    body = "".join(f'<tr><td><code>{t}</code></td><td class="num">{n}</td></tr>' for t, n in rows)
    total = sum(n for _, n in rows)
    return (f'<table class="result narrow"><thead><tr><th>tabela</th><th>registros</th></tr></thead>'
            f'<tbody>{body}<tr class="total"><td>Total</td><td class="num">{total}</td></tr></tbody></table>')


def main():
    tpl = TEMPLATE.read_text(encoding="utf-8")
    ddl = (SQL_DIR / "01_ddl.sql").read_text(encoding="utf-8")
    queries = parse_queries((SQL_DIR / "03_consultas.sql").read_text(encoding="utf-8"))

    with psycopg2.connect(DSN) as conn, conn.cursor() as cur:
        cur.execute("SET search_path TO clinica, public; SET TIME ZONE 'America/Sao_Paulo';")
        repl = {
            "CONTAGEM": lambda _: counts(cur),
            "SQL": lambda k: code(queries[k]),
            "RES": lambda k: result_table(cur, queries[k]),
            "DDL": lambda k: ddl_table(ddl, k),
            "FUNC": lambda k: ddl_function(ddl, k),
            "FUNC2": lambda k: ddl_function(ddl, k),
            "NIDX": lambda _: str(n_indices(cur)),
        }

        def sub(m):
            kind, _, arg = m.group(1).partition(":")
            return repl[kind](arg)

        out = re.sub(r"\{\{([A-Z0-9]+(?::[\w]+)?)\}\}", sub, tpl)
        conn.rollback()

    css = HtmlFormatter(style="friendly").get_style_defs(".code")
    out = out.replace("/*PYGMENTS*/", css)
    HTML(string=out, base_url=str(TEMPLATE.parent)).write_pdf(OUTPUT)
    print(f"PDF gerado em {OUTPUT}")


if __name__ == "__main__":
    main()
