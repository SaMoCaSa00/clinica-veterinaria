-- =============================================================================
--  Sistema de Gestão de Clínica Veterinária
--  00_criar_banco.sql — criação do banco de dados
-- -----------------------------------------------------------------------------
--  Execute este script conectado ao banco padrão "postgres".
--  No pgAdmin 4: botão direito em "postgres" > Query Tool > executar (F5).
--  Depois, abra uma Query Tool no banco "clinica_vet" e rode os demais scripts
--  na ordem: 01_ddl.sql -> 02_dml.sql -> 03_consultas.sql.
--
--  CREATE DATABASE não pode rodar dentro de uma transação, por isso fica
--  em um arquivo separado.
-- =============================================================================

-- Descomente a linha abaixo para recriar o banco do zero
-- (feche antes qualquer conexão aberta com ele).
-- DROP DATABASE IF EXISTS clinica_vet;

CREATE DATABASE clinica_vet
    WITH ENCODING = 'UTF8'
         TEMPLATE = template0;

COMMENT ON DATABASE clinica_vet IS
    'Sistema de gestão de clínica veterinária: tutores, animais, veterinários, agendamentos, atendimentos, procedimentos e prescrições.';

-- Fuso horário padrão das sessões neste banco (datas exibidas no horário local).
ALTER DATABASE clinica_vet SET timezone TO 'America/Sao_Paulo';
