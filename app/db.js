// Conexão com o PostgreSQL.
// As credenciais vêm do arquivo .env (veja .env.example). O driver "pg" lê
// PGHOST, PGPORT, PGUSER, PGPASSWORD e PGDATABASE automaticamente.
import 'dotenv/config';
import pg from 'pg';

// NUMERIC chega como texto por padrão (para não perder precisão).
// Aqui os valores são pequenos (preços, pesos), então convertemos para número.
pg.types.setTypeParser(pg.types.builtins.NUMERIC, (v) => (v === null ? null : Number(v)));
// DATE (nascimento, óbito) fica como texto 'YYYY-MM-DD': convertê-lo em Date
// aplicaria fuso horário e poderia "voltar" um dia.
pg.types.setTypeParser(pg.types.builtins.DATE, (v) => v);
// COUNT(*) devolve BIGINT, que também chega como texto.
pg.types.setTypeParser(pg.types.builtins.INT8, (v) => (v === null ? null : Number(v)));

export const pool = new pg.Pool({
  database: process.env.PGDATABASE || 'clinica_vet',
  // todas as tabelas ficam no esquema "clinica"
  options: '-c search_path=clinica',
});

export const query = (text, params) => pool.query(text, params);

// Traduz erros do banco para mensagens que fazem sentido na tela.
// As regras continuam no banco: aqui só escolhemos como mostrar o erro.
const MENSAGENS = {
  ck_tutor_cpf: 'CPF inválido: os dígitos verificadores não conferem.',
  ck_veterinario_cpf: 'CPF inválido: os dígitos verificadores não conferem.',
  uq_tutor_cpf: 'Já existe um tutor cadastrado com esse CPF.',
  uq_tutor_email: 'Já existe um tutor cadastrado com esse e-mail.',
  ck_tutor_email: 'E-mail em formato inválido.',
  ck_tutor_telefone: 'Telefone deve ter DDD + número (10 ou 11 dígitos).',
  ck_tutor_cep: 'CEP deve ter 8 dígitos.',
  ck_tutor_uf: 'UF deve ter 2 letras maiúsculas.',
  uq_animal_microchip: 'Já existe um animal com esse microchip.',
  ck_animal_microchip: 'Microchip deve ter 15 dígitos.',
  ck_agendamento_periodo: 'O fim do horário precisa ser depois do início.',
  ck_agendamento_cancel: 'Informe o motivo do cancelamento.',
};

export function mensagemDeErro(err) {
  if (err.constraint && MENSAGENS[err.constraint]) return MENSAGENS[err.constraint];
  // erros levantados pelos gatilhos já vêm em português (RAISE EXCEPTION)
  if (err.message.includes('já tem um horário marcado')) {
    return 'Esse veterinário já tem um horário marcado que se sobrepõe a este.';
  }
  if (err.code === '23514' || err.code === 'P0001') return err.message;
  if (err.code === '23503') return 'Registro relacionado não encontrado ou em uso.';
  if (err.code === '23505') return 'Já existe um registro com esses dados.';
  return 'Erro inesperado no banco de dados.';
}
