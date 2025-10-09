# PostgreSQL - Banco de Dados Relacional

## Visão Geral

### O que é PostgreSQL?

PostgreSQL é um sistema de gerenciamento de banco de dados relacional objeto-relacional (ORDBMS) de código aberto, conhecido por sua confiabilidade, robustez de recursos e alto desempenho. Com mais de 30 anos de desenvolvimento ativo, é uma das bases de dados mais avançadas disponíveis.

No contexto do BorgStack, o PostgreSQL serve como banco de dados **compartilhado** para múltiplos serviços:
- **n8n**: Workflows, credenciais, execuções
- **Chatwoot**: Conversas, contatos, mensagens, agentes
- **Directus**: Conteúdo, coleções, usuários
- **Evolution API**: Instâncias, mensagens, contatos do WhatsApp

### Versão no BorgStack

- **Versão**: PostgreSQL 18.0 com extensão **pgvector**
- **Extensão pgvector**: Suporte a embeddings vetoriais para AI/ML

### Casos de Uso no BorgStack

1. **Banco de Dados Compartilhado**: 4 databases isolados para diferentes serviços
2. **Armazenamento Transacional**: ACID compliance para integridade de dados
3. **Pesquisa Vetorial**: pgvector para embeddings e similarity search
4. **Analytics**: Queries complexas para relatórios e dashboards
5. **Backup Centralizado**: Estratégia unificada de backup via Duplicati

---

## Configuração Inicial

### Localização dos Arquivos

```bash
# Dados do PostgreSQL (volume Docker)
docker volume inspect borgstack_postgresql_data

# Configuração customizada
config/postgresql/postgresql.conf

# Logs
docker compose logs -f postgresql

# Verificar status
docker compose ps postgresql
```

### Organização dos Bancos de Dados

O BorgStack mantém **4 databases separados**:

```sql
-- n8n (workflow automation)
n8n_db

-- Chatwoot (customer service)
chatwoot_db

-- Directus (headless CMS)
directus_db

-- Evolution API (WhatsApp)
evolution_db
```

**Estratégia de Isolamento**:
- Cada serviço tem seu próprio database
- Credenciais separadas por serviço
- Facilita backup/restore seletivo
- Permite migração independente

### Credenciais e Conexão

As credenciais estão no arquivo `.env`:

```bash
# Superusuário (apenas para administração)
POSTGRES_USER=postgres
POSTGRES_PASSWORD=senha_super_segura

# n8n database
N8N_DB_NAME=n8n_db
N8N_DB_USER=n8n_user
N8N_DB_PASSWORD=senha_n8n

# Chatwoot database
CHATWOOT_DB_NAME=chatwoot_db
CHATWOOT_DB_USER=chatwoot_user
CHATWOOT_DB_PASSWORD=senha_chatwoot

# Directus database
DIRECTUS_DB_NAME=directus_db
DIRECTUS_DB_USER=directus_user
DIRECTUS_DB_PASSWORD=senha_directus

# Evolution API database
EVOLUTION_DB_NAME=evolution_db
EVOLUTION_DB_USER=evolution_user
EVOLUTION_DB_PASSWORD=senha_evolution
```

### Conectar ao PostgreSQL

#### Via psql (Container)

```bash
# Conectar como superusuário
docker compose exec postgresql psql -U postgres

# Conectar a database específico
docker compose exec postgresql psql -U postgres -d n8n_db

# Conectar com usuário específico
docker compose exec postgresql psql -U n8n_user -d n8n_db

# Listar databases
docker compose exec postgresql psql -U postgres -c "\l"

# Listar usuários (roles)
docker compose exec postgresql psql -U postgres -c "\du"
```

#### Connection String

Formato para conexão de aplicações:

```bash
# n8n
postgresql://n8n_user:senha_n8n@postgresql:5432/n8n_db

# Chatwoot
postgresql://chatwoot_user:senha_chatwoot@postgresql:5432/chatwoot_db

# Directus
postgresql://directus_user:senha_directus@postgresql:5432/directus_db

# Evolution API
postgresql://evolution_user:senha_evolution@postgresql:5432/evolution_db
```

---

## Conceitos Fundamentais

### 1. Database

Um **database** é um container lógico isolado para dados:

```sql
-- Criar novo database
CREATE DATABASE meu_database;

-- Listar databases
\l

-- Conectar a database
\c meu_database

-- Deletar database (CUIDADO!)
DROP DATABASE meu_database;
```

### 2. Schema

Um **schema** é um namespace dentro de um database:

```sql
-- Criar schema
CREATE SCHEMA meu_schema;

-- Listar schemas
\dn

-- Definir search_path (schemas padrão)
SET search_path TO meu_schema, public;

-- Ver search_path atual
SHOW search_path;
```

### 3. Tables

**Tables** armazenam dados estruturados:

```sql
-- Criar tabela
CREATE TABLE usuarios (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Listar tabelas
\dt

-- Descrever estrutura de tabela
\d usuarios

-- Ver dados
SELECT * FROM usuarios LIMIT 10;
```

### 4. Roles (Usuários)

**Roles** controlam autenticação e permissões:

```sql
-- Criar role (usuário)
CREATE ROLE meu_usuario WITH LOGIN PASSWORD 'senha_segura';

-- Listar roles
\du

-- Conceder permissões
GRANT CONNECT ON DATABASE meu_database TO meu_usuario;
GRANT USAGE ON SCHEMA public TO meu_usuario;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO meu_usuario;

-- Revogar permissões
REVOKE DELETE ON ALL TABLES IN SCHEMA public FROM meu_usuario;

-- Alterar senha
ALTER ROLE meu_usuario WITH PASSWORD 'nova_senha';
```

### 5. Indexes

**Indexes** aceleram queries:

```sql
-- Criar index
CREATE INDEX idx_usuarios_email ON usuarios(email);

-- Criar index único
CREATE UNIQUE INDEX idx_usuarios_email_unique ON usuarios(email);

-- Criar index composto
CREATE INDEX idx_usuarios_nome_email ON usuarios(nome, email);

-- Listar indexes
\di

-- Ver indexes de uma tabela
\d usuarios

-- Analisar uso de index
EXPLAIN ANALYZE SELECT * FROM usuarios WHERE email = 'teste@example.com';
```

### 6. Views

**Views** são queries salvas:

```sql
-- Criar view
CREATE VIEW usuarios_ativos AS
SELECT id, nome, email
FROM usuarios
WHERE ativo = true;

-- Listar views
\dv

-- Usar view
SELECT * FROM usuarios_ativos;

-- Deletar view
DROP VIEW usuarios_ativos;
```

### 7. Transactions

**Transactions** garantem atomicidade:

```sql
-- Iniciar transação
BEGIN;

-- Executar comandos
INSERT INTO usuarios (nome, email) VALUES ('João', 'joao@example.com');
UPDATE usuarios SET nome = 'João Silva' WHERE email = 'joao@example.com';

-- Confirmar (salvar)
COMMIT;

-- Ou reverter (cancelar)
ROLLBACK;
```

---

## Tutorial Passo a Passo: Gerenciamento Básico

### Passo 1: Verificar Status do PostgreSQL

```bash
# Container está rodando?
docker compose ps postgresql

# Health check
docker inspect postgresql | grep -A 10 "Health"

# Logs recentes
docker compose logs --tail=50 postgresql

# Conectividade
docker compose exec postgresql pg_isready -U postgres
```

### Passo 2: Explorar Databases Existentes

```bash
# Conectar como superusuário
docker compose exec postgresql psql -U postgres

# Listar databases
\l

# Ver tamanho de cada database
SELECT
    pg_database.datname AS database_name,
    pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database
ORDER BY pg_database_size(pg_database.datname) DESC;

# Conectar ao database do n8n
\c n8n_db

# Listar tabelas
\dt

# Ver estrutura de uma tabela
\d workflow_entity
```

### Passo 3: Consultar Dados

```sql
-- Exemplo: n8n workflows
SELECT id, name, active, created_at
FROM workflow_entity
ORDER BY created_at DESC
LIMIT 10;

-- Exemplo: Chatwoot conversas
\c chatwoot_db

SELECT
    id,
    account_id,
    inbox_id,
    status,
    created_at
FROM conversations
WHERE status = 'open'
ORDER BY created_at DESC
LIMIT 20;

-- Exemplo: Directus collections
\c directus_db

SELECT collection, note, archived
FROM directus_collections
WHERE archived = false;
```

### Passo 4: Monitorar Conexões Ativas

```sql
-- Ver todas as conexões
SELECT
    pid,
    usename,
    datname,
    state,
    query_start,
    query
FROM pg_stat_activity
WHERE state <> 'idle'
ORDER BY query_start;

-- Contar conexões por database
SELECT
    datname,
    count(*) AS connections
FROM pg_stat_activity
GROUP BY datname
ORDER BY connections DESC;

-- Ver conexões longas (>1 minuto)
SELECT
    pid,
    usename,
    datname,
    now() - query_start AS duration,
    query
FROM pg_stat_activity
WHERE state <> 'idle'
    AND now() - query_start > interval '1 minute'
ORDER BY duration DESC;
```

### Passo 5: Analisar Performance

```sql
-- Tabelas maiores
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;

-- Queries mais lentas (requer pg_stat_statements)
SELECT
    calls,
    mean_exec_time,
    max_exec_time,
    query
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Cache hit ratio (idealmente > 95%)
SELECT
    sum(heap_blks_read) as heap_read,
    sum(heap_blks_hit) as heap_hit,
    sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) * 100 AS cache_hit_ratio
FROM pg_statio_user_tables;
```

---

## Backup e Restore

### Backup Individual de Database

#### Usando pg_dump (Formato Custom)

```bash
# Backup do database n8n (formato custom, comprimido)
docker compose exec postgresql pg_dump -U postgres -Fc n8n_db > backups/n8n_db_$(date +%Y%m%d).dump

# Backup do database Chatwoot
docker compose exec postgresql pg_dump -U postgres -Fc chatwoot_db > backups/chatwoot_db_$(date +%Y%m%d).dump

# Backup do database Directus
docker compose exec postgresql pg_dump -U postgres -Fc directus_db > backups/directus_db_$(date +%Y%m%d).dump

# Backup do database Evolution API
docker compose exec postgresql pg_dump -U postgres -Fc evolution_db > backups/evolution_db_$(date +%Y%m%d).dump
```

#### Usando pg_dump (Formato SQL)

```bash
# Backup em SQL puro (maior, mas legível)
docker compose exec postgresql pg_dump -U postgres n8n_db > backups/n8n_db_$(date +%Y%m%d).sql

# Backup com compressão gzip
docker compose exec postgresql pg_dump -U postgres n8n_db | gzip > backups/n8n_db_$(date +%Y%m%d).sql.gz
```

#### Backup Paralelo (Mais Rápido)

```bash
# Backup paralelo usando 4 threads (formato directory)
docker compose exec postgresql pg_dump -U postgres -j 4 -Fd -f /tmp/n8n_backup n8n_db

# Copiar do container
docker cp postgresql:/tmp/n8n_backup ./backups/n8n_backup_$(date +%Y%m%d)
```

### Backup de Todos os Databases

```bash
# Backup de todo o cluster (todos os databases + roles)
docker compose exec postgresql pg_dumpall -U postgres > backups/cluster_full_$(date +%Y%m%d).sql

# Backup apenas de roles e tablespaces (sem dados)
docker compose exec postgresql pg_dumpall -U postgres --globals-only > backups/globals_$(date +%Y%m%d).sql
```

### Restore de Database

#### Restore com pg_restore (Formato Custom)

```bash
# Criar database vazio
docker compose exec postgresql psql -U postgres -c "CREATE DATABASE n8n_db_restore;"

# Restore do backup
docker compose exec postgresql pg_restore -U postgres -d n8n_db_restore /path/to/backup.dump

# Restore com jobs paralelos (mais rápido)
docker compose exec postgresql pg_restore -U postgres -j 4 -d n8n_db_restore /path/to/backup.dump
```

#### Restore com psql (Formato SQL)

```bash
# Criar database
docker compose exec postgresql psql -U postgres -c "CREATE DATABASE n8n_db_restore;"

# Restore do SQL
docker compose exec postgresql psql -U postgres -d n8n_db_restore < backups/n8n_db_20250108.sql

# Restore de arquivo gzip
gunzip -c backups/n8n_db_20250108.sql.gz | docker compose exec -T postgresql psql -U postgres -d n8n_db_restore
```

#### Restore Completo (Recrear Database)

```bash
# CUIDADO: Isso DELETA o database existente!

# Parar serviços que usam o database
docker compose stop n8n

# Deletar database existente
docker compose exec postgresql psql -U postgres -c "DROP DATABASE n8n_db;"

# Restore com criação automática do database
docker compose exec postgresql pg_restore -U postgres -C -d postgres /path/to/backup.dump

# Reiniciar serviços
docker compose start n8n
```

### Restore Seletivo

```bash
# Listar conteúdo do backup
docker compose exec postgresql pg_restore -l /path/to/backup.dump > backup_contents.list

# Editar backup_contents.list para comentar (;) itens não desejados

# Restore apenas itens selecionados
docker compose exec postgresql pg_restore -U postgres -d n8n_db -L backup_contents.list /path/to/backup.dump

# Restore apenas schema (sem dados)
docker compose exec postgresql pg_restore -U postgres -d n8n_db --section=pre-data --section=post-data /path/to/backup.dump

# Restore apenas dados (sem schema)
docker compose exec postgresql pg_restore -U postgres -d n8n_db --section=data /path/to/backup.dump
```

### Script de Backup Automatizado

```bash
#!/bin/bash
# backups/backup-postgresql.sh

set -e

BACKUP_DIR="/path/to/backups/postgresql"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

mkdir -p "$BACKUP_DIR"

# Backup de cada database
for DB in n8n_db chatwoot_db directus_db evolution_db; do
    echo "Backing up $DB..."
    docker compose exec -T postgresql pg_dump -U postgres -Fc "$DB" > "$BACKUP_DIR/${DB}_${TIMESTAMP}.dump"

    # Verificar integridade
    if [ -f "$BACKUP_DIR/${DB}_${TIMESTAMP}.dump" ]; then
        echo "✅ $DB backup completed: $(du -h "$BACKUP_DIR/${DB}_${TIMESTAMP}.dump" | cut -f1)"
    else
        echo "❌ $DB backup failed!"
        exit 1
    fi
done

# Backup de roles e globals
echo "Backing up globals..."
docker compose exec -T postgresql pg_dumpall -U postgres --globals-only > "$BACKUP_DIR/globals_${TIMESTAMP}.sql"

# Remover backups antigos
echo "Cleaning old backups (older than $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -name "*.dump" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "*.sql" -mtime +$RETENTION_DAYS -delete

echo "✅ All backups completed successfully!"
```

---

## Otimização de Performance

### Tuning do postgresql.conf

Para servidor com **36GB RAM** e **8 vCPUs**:

```conf
# config/postgresql/postgresql.conf

# Connections
max_connections = 200
superuser_reserved_connections = 3
reserved_connections = 10

# Memory
shared_buffers = 8GB                    # 25% da RAM
effective_cache_size = 24GB             # 66% da RAM
maintenance_work_mem = 2GB              # Para VACUUM, CREATE INDEX
work_mem = 20MB                         # Por operação de sort
huge_pages = try

# WAL (Write-Ahead Log)
wal_buffers = 16MB
min_wal_size = 1GB
max_wal_size = 4GB
checkpoint_completion_target = 0.9
wal_compression = on

# Query Planning
random_page_cost = 1.1                  # SSD (padrão 4.0 para HDD)
effective_io_concurrency = 200          # SSD
default_statistics_target = 100

# Logging
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d.log'
log_rotation_age = 1d
log_rotation_size = 100MB
log_min_duration_statement = 1000       # Log queries > 1s
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '

# Autovacuum
autovacuum = on
autovacuum_max_workers = 3
autovacuum_naptime = 1min

# Statistics
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.max = 10000
pg_stat_statements.track = all
compute_query_id = on
```

Aplicar configuração:

```bash
# Editar configuração
nano config/postgresql/postgresql.conf

# Reiniciar PostgreSQL
docker compose restart postgresql

# Verificar configuração ativa
docker compose exec postgresql psql -U postgres -c "SHOW shared_buffers;"
docker compose exec postgresql psql -U postgres -c "SHOW effective_cache_size;"
```

### Analisar e Otimizar Queries

```sql
-- Ver query plan
EXPLAIN SELECT * FROM usuarios WHERE email = 'teste@example.com';

-- Ver query plan com estatísticas reais
EXPLAIN ANALYZE SELECT * FROM usuarios WHERE email = 'teste@example.com';

-- Ver query plan visual (formato JSON)
EXPLAIN (FORMAT JSON) SELECT * FROM usuarios WHERE email = 'teste@example.com';
```

**Interpretando EXPLAIN**:
- **Seq Scan**: Leitura completa da tabela (lento para tabelas grandes)
- **Index Scan**: Usa index (rápido)
- **Cost**: Estimativa de custo (menor é melhor)
- **Rows**: Número estimado de linhas

### Criar Indexes Estratégicos

```sql
-- Index para queries WHERE
CREATE INDEX idx_usuarios_email ON usuarios(email);

-- Index para queries ORDER BY
CREATE INDEX idx_usuarios_criado_em ON usuarios(criado_em DESC);

-- Index composto para queries complexas
CREATE INDEX idx_conversas_status_criado ON conversations(status, created_at DESC);

-- Index parcial (apenas subset)
CREATE INDEX idx_conversas_abertas ON conversations(created_at DESC)
WHERE status = 'open';

-- Index GIN para JSONB
CREATE INDEX idx_dados_jsonb ON tabela USING GIN (dados_json);

-- Index para full-text search
CREATE INDEX idx_usuarios_busca ON usuarios USING GIN (to_tsvector('portuguese', nome || ' ' || email));
```

### VACUUM e ANALYZE

```sql
-- VACUUM recupera espaço de linhas deletadas
VACUUM usuarios;

-- VACUUM FULL reescreve tabela inteira (offline, mais agressivo)
VACUUM FULL usuarios;

-- ANALYZE atualiza estatísticas do query planner
ANALYZE usuarios;

-- VACUUM + ANALYZE juntos
VACUUM ANALYZE usuarios;

-- VACUUM todas as tabelas do database
VACUUM;

-- Ver quando tabelas foram vacu
umadas pela última vez
SELECT
    schemaname,
    relname,
    last_vacuum,
    last_autovacuum,
    n_dead_tup
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;
```

### Monitorar Locks

```sql
-- Ver locks ativos
SELECT
    locktype,
    database,
    relation::regclass,
    pid,
    mode,
    granted
FROM pg_locks
WHERE NOT granted
ORDER BY pid;

-- Matar query travada (CUIDADO!)
SELECT pg_terminate_backend(pid);

-- Ver queries aguardando locks
SELECT
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_statement,
    blocking_activity.query AS blocking_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
```

---

## Integração com Serviços BorgStack

### n8n

```bash
# Connection string
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=postgresql
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n_db
DB_POSTGRESDB_USER=n8n_user
DB_POSTGRESDB_PASSWORD=senha_n8n
```

**Tabelas principais**:
- `workflow_entity`: Workflows salvos
- `execution_entity`: Histórico de execuções
- `credentials_entity`: Credenciais criptografadas

### Chatwoot

```bash
# Connection string
POSTGRES_HOST=postgresql
POSTGRES_PORT=5432
POSTGRES_DATABASE=chatwoot_db
POSTGRES_USERNAME=chatwoot_user
POSTGRES_PASSWORD=senha_chatwoot
```

**Tabelas principais**:
- `conversations`: Conversas com clientes
- `messages`: Mensagens enviadas/recebidas
- `contacts`: Contatos (clientes)
- `inboxes`: Canais de comunicação

### Directus

```bash
# Connection string
DB_CLIENT=pg
DB_HOST=postgresql
DB_PORT=5432
DB_DATABASE=directus_db
DB_USER=directus_user
DB_PASSWORD=senha_directus
```

**Tabelas principais**:
- `directus_collections`: Coleções criadas
- `directus_fields`: Campos das coleções
- `directus_files`: Arquivos carregados
- `directus_users`: Usuários do CMS

### Evolution API

```bash
# Connection string
DATABASE_ENABLED=true
DATABASE_CONNECTION_URI=postgresql://evolution_user:senha_evolution@postgresql:5432/evolution_db
```

**Tabelas principais**:
- `evolution_instances`: Instâncias WhatsApp
- `evolution_messages`: Mensagens WhatsApp
- `evolution_contacts`: Contatos importados

---

## Extensões PostgreSQL

### pgvector - Vector Embeddings

Instalado no BorgStack para suporte a AI/ML:

```sql
-- Habilitar extensão (já habilitada no BorgStack)
CREATE EXTENSION IF NOT EXISTS vector;

-- Criar tabela com embeddings
CREATE TABLE documentos (
    id SERIAL PRIMARY KEY,
    conteudo TEXT,
    embedding vector(1536)  -- OpenAI embeddings dimension
);

-- Inserir embedding
INSERT INTO documentos (conteudo, embedding)
VALUES (
    'PostgreSQL é um banco de dados relacional',
    '[0.1, 0.2, 0.3, ...]'::vector
);

-- Buscar por similaridade (cosine distance)
SELECT
    conteudo,
    1 - (embedding <=> '[0.15, 0.25, 0.35, ...]'::vector) AS similarity
FROM documentos
ORDER BY embedding <=> '[0.15, 0.25, 0.35, ...]'::vector
LIMIT 10;

-- Criar index para busca vetorial rápida
CREATE INDEX ON documentos USING ivfflat (embedding vector_cosine_ops);
```

### Outras Extensões Úteis

```sql
-- UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
SELECT uuid_generate_v4();

-- Full-text search em português
CREATE EXTENSION IF NOT EXISTS unaccent;
SELECT unaccent('São Paulo'); -- Retorna: Sao Paulo

-- Trigram similarity
CREATE EXTENSION IF NOT EXISTS pg_trgm;
SELECT similarity('João Silva', 'Joao Silva'); -- Retorna: 0.8

-- Crypto functions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
SELECT crypt('minha_senha', gen_salt('bf'));
```

---

## Solução de Problemas

### 1. Não Consigo Conectar ao PostgreSQL

**Sintomas**: Erro "could not connect to server"

**Soluções**:

```bash
# Verificar container está rodando
docker compose ps postgresql

# Verificar logs
docker compose logs -f postgresql

# Testar conectividade
docker compose exec postgresql pg_isready -U postgres

# Verificar porta (interna, não exposta externamente)
docker inspect postgresql | grep -A 5 "Ports"

# Verificar rede
docker inspect postgresql | grep -A 10 "Networks"

# Tentar conexão do host (deve falhar - rede interna)
psql -h localhost -U postgres
# ❌ Esperado: Connection refused (segurança correta)

# Conectar via docker exec (correto)
docker compose exec postgresql psql -U postgres
# ✅ Esperado: Conecta normalmente
```

### 2. Database Está Lento

**Sintomas**: Queries demoradas, timeouts

**Soluções**:

```sql
-- Verificar conexões ativas
SELECT count(*) FROM pg_stat_activity;

-- Ver queries lentas em execução
SELECT
    pid,
    now() - query_start AS duration,
    state,
    query
FROM pg_stat_activity
WHERE state <> 'idle'
    AND now() - query_start > interval '10 seconds'
ORDER BY duration DESC;

-- Verificar cache hit ratio
SELECT
    sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) * 100 AS cache_hit_ratio
FROM pg_statio_user_tables;
-- ✅ Esperado: > 95%
-- ❌ Se < 90%: Aumentar shared_buffers

-- Verificar tabelas precisando VACUUM
SELECT
    schemaname,
    relname,
    n_dead_tup,
    n_live_tup,
    round(n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_ratio
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY dead_ratio DESC;

-- Executar VACUUM em tabelas problemáticas
VACUUM ANALYZE nome_da_tabela;
```

### 3. Disco Cheio

**Sintomas**: Erro "No space left on device"

**Soluções**:

```bash
# Verificar uso de disco do volume
docker system df -v | grep postgresql

# Ver tamanho de cada database
docker compose exec postgresql psql -U postgres -c "
SELECT
    pg_database.datname,
    pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database
ORDER BY pg_database_size(pg_database.datname) DESC;
"

# Ver tabelas maiores
docker compose exec postgresql psql -U postgres -d n8n_db -c "
SELECT
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;
"

# Limpar tabelas antigas (exemplo: execuções n8n > 30 dias)
docker compose exec postgresql psql -U postgres -d n8n_db -c "
DELETE FROM execution_entity
WHERE finished_at < NOW() - INTERVAL '30 days';
"

# VACUUM FULL para recuperar espaço
docker compose exec postgresql psql -U postgres -d n8n_db -c "VACUUM FULL;"

# Limpar logs antigos
docker compose exec postgresql sh -c "find /var/lib/postgresql/data/log -name '*.log' -mtime +7 -delete"
```

### 4. Conexões Esgotadas

**Sintomas**: Erro "remaining connection slots are reserved"

**Soluções**:

```sql
-- Ver conexões atuais
SELECT
    datname,
    count(*) AS connections,
    max_conn,
    max_conn - count(*) AS available
FROM pg_stat_activity
CROSS JOIN (SELECT setting::int AS max_conn FROM pg_settings WHERE name = 'max_connections') AS mc
GROUP BY datname, max_conn
ORDER BY connections DESC;

-- Identificar aplicações com muitas conexões
SELECT
    application_name,
    count(*) AS connections
FROM pg_stat_activity
GROUP BY application_name
ORDER BY connections DESC;

-- Matar conexões idle
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle'
    AND state_change < NOW() - INTERVAL '10 minutes';

-- Aumentar max_connections (temporário)
ALTER SYSTEM SET max_connections = 300;
SELECT pg_reload_conf();

-- Permanente: editar postgresql.conf
# max_connections = 300
```

### 5. Backup Falha

**Sintomas**: pg_dump retorna erro

**Soluções**:

```bash
# Verificar espaço em disco
df -h

# Backup com verbose para ver progresso
docker compose exec postgresql pg_dump -U postgres -Fc -v n8n_db > backup.dump 2>&1 | tee backup.log

# Se tabela específica falha, excluir
docker compose exec postgresql pg_dump -U postgres -Fc -v \
    --exclude-table=problema_table \
    n8n_db > backup.dump

# Backup com compressão maior (nível 9)
docker compose exec postgresql pg_dump -U postgres -Fc -Z 9 n8n_db > backup.dump

# Backup paralelo (mais rápido, mais memória)
docker compose exec postgresql pg_dump -U postgres -Fd -j 4 -f /tmp/backup n8n_db
```

### 6. Restore Falha

**Sintomas**: pg_restore retorna erro

**Soluções**:

```bash
# Ver conteúdo do backup
docker compose exec postgresql pg_restore -l backup.dump | head -20

# Restore com --single-transaction (tudo ou nada)
docker compose exec postgresql pg_restore -U postgres -d n8n_db --single-transaction backup.dump

# Restore ignorando erros (continua mesmo com falhas)
docker compose exec postgresql pg_restore -U postgres -d n8n_db --exit-on-error=false backup.dump

# Restore apenas dados (assume schema já existe)
docker compose exec postgresql pg_restore -U postgres -d n8n_db --data-only backup.dump

# Restore limpando objetos existentes primeiro
docker compose exec postgresql pg_restore -U postgres -d n8n_db --clean --if-exists backup.dump
```

### 7. Database Corrompido

**Sintomas**: Erros de I/O, tabelas inacessíveis

**Soluções**:

```bash
# Verificar integridade
docker compose exec postgresql pg_dump -U postgres n8n_db > /dev/null
# Se falhar: database corrompido

# Tentar VACUUM com FULL
docker compose exec postgresql psql -U postgres -d n8n_db -c "VACUUM FULL;"

# Reindexar database
docker compose exec postgresql psql -U postgres -d n8n_db -c "REINDEX DATABASE n8n_db;"

# Se tudo falhar: restore do backup
docker compose stop n8n
docker compose exec postgresql dropdb -U postgres n8n_db
docker compose exec postgresql createdb -U postgres -O n8n_user n8n_db
docker compose exec postgresql pg_restore -U postgres -d n8n_db /path/to/backup.dump
docker compose start n8n
```

---

## Comandos Úteis

### Administração

```sql
-- Ver versão do PostgreSQL
SELECT version();

-- Ver configurações ativas
SHOW ALL;

-- Ver configuração específica
SHOW shared_buffers;
SHOW max_connections;

-- Recarregar configuração (sem restart)
SELECT pg_reload_conf();

-- Ver tempo de uptime
SELECT
    now() - pg_postmaster_start_time() AS uptime;

-- Ver databases e tamanhos
SELECT
    pg_database.datname,
    pg_size_pretty(pg_database_size(pg_database.datname)) AS size,
    pg_database_size(pg_database.datname) AS size_bytes
FROM pg_database
ORDER BY size_bytes DESC;
```

### Monitoramento

```bash
# Ver estatísticas do container
docker stats postgresql

# Logs em tempo real
docker compose logs -f postgresql

# Últimos 100 logs
docker compose logs --tail=100 postgresql

# Filtrar por erro
docker compose logs postgresql | grep -i error

# Ver processos PostgreSQL
docker compose exec postgresql ps aux | grep postgres
```

### Manutenção

```sql
-- VACUUM todas as tabelas
VACUUM;

-- ANALYZE todas as tabelas
ANALYZE;

-- VACUUM + ANALYZE
VACUUM ANALYZE;

-- REINDEX database
REINDEX DATABASE n8n_db;

-- REINDEX tabela específica
REINDEX TABLE usuarios;

-- Ver progresso do VACUUM
SELECT
    p.pid,
    now() - a.xact_start AS duration,
    a.query
FROM pg_stat_progress_vacuum p
JOIN pg_stat_activity a ON p.pid = a.pid;
```

---

## 8. Dicas e Melhores Práticas

### 8.1 Configuração Otimizada
**Connection pooling com pgbouncer** (para alta carga):
```yaml
# docker-compose.yml
services:
  pgbouncer:
    image: edoburu/pgbouncer:latest
    environment:
      DATABASE_URL: postgres://postgres:password@postgresql:5432/postgres
      MAX_CLIENT_CONN: 1000
      DEFAULT_POOL_SIZE: 25
```

**Recursos para produção:**
- CPU: 2 vCPUs (4+ para produção)
- RAM: 4GB (8GB+ para produção)
- Disco: SSD obrigatório

### 8.2 Performance
**Indexes:**
```sql
-- Criar índice em colunas de busca frequente
CREATE INDEX idx_conversations_status ON chatwoot_db.conversations(status);
CREATE INDEX idx_messages_created ON chatwoot_db.messages(created_at);
```

**VACUUM regular:**
```bash
# Adicionar ao cron (semanal)
docker compose exec postgresql vacuumdb --all --analyze
```

### 8.3 Backup e Restore
**Backup incremental:**
```bash
# Backup de database específica
docker compose exec -T postgresql pg_dump -U postgres chatwoot_db > chatwoot-$(date +%Y%m%d).sql
```

**Teste de restore mensal obrigatório!**

### 8.4 Monitoramento
- Conexões ativas: `SELECT count(*) FROM pg_stat_activity;`
- Tamanho DBs: `SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) FROM pg_database;`
- Queries lentas: verificar `pg_stat_statements`

---

## Recursos Adicionais

### Documentação Oficial
- [PostgreSQL 18 Docs](https://www.postgresql.org/docs/18/)
- [pgvector Extension](https://github.com/pgvector/pgvector)
- [PostgreSQL Performance](https://wiki.postgresql.org/wiki/Performance_Optimization)

### Ferramentas
- [pgAdmin](https://www.pgadmin.org/) - GUI de administração
- [PgHero](https://github.com/ankane/pghero) - Dashboard de performance
- [pg_stat_statements](https://www.postgresql.org/docs/current/pgstatstatements.html) - Query analytics

---

## Próximos Passos

Depois de configurar o PostgreSQL, você pode:

1. **Configurar Backups Automatizados**: Ver [docs/06-manutencao.md](../06-manutencao.md)
2. **Otimizar Queries**: Ver [docs/08-desempenho.md](../08-desempenho.md)
3. **Integrar com n8n**: Ver [docs/03-services/n8n.md](./n8n.md)
4. **Monitorar Performance**: Configurar alertas e dashboards

---

## Referências Técnicas

### Variáveis de Ambiente

```bash
# Superusuário
POSTGRES_USER=postgres
POSTGRES_PASSWORD=senha_super_segura

# Databases e usuários
N8N_DB_NAME=n8n_db
N8N_DB_USER=n8n_user
N8N_DB_PASSWORD=senha_n8n

CHATWOOT_DB_NAME=chatwoot_db
CHATWOOT_DB_USER=chatwoot_user
CHATWOOT_DB_PASSWORD=senha_chatwoot

DIRECTUS_DB_NAME=directus_db
DIRECTUS_DB_USER=directus_user
DIRECTUS_DB_PASSWORD=senha_directus

EVOLUTION_DB_NAME=evolution_db
EVOLUTION_DB_USER=evolution_user
EVOLUTION_DB_PASSWORD=senha_evolution
```

### Portas

| Serviço | Porta Interna | Porta Externa | Descrição |
|---------|---------------|---------------|-----------|
| PostgreSQL | 5432 | - | Não exposta (rede interna apenas) |

### Volumes

```yaml
volumes:
  borgstack_postgresql_data:  # Dados do PostgreSQL (/var/lib/postgresql/data)
```

### Limites e Configurações

| Recurso | Configuração | Valor Recomendado |
|---------|--------------|-------------------|
| Max Connections | max_connections | 200 |
| Shared Buffers | shared_buffers | 8GB (25% RAM) |
| Effective Cache | effective_cache_size | 24GB (66% RAM) |
| Work Mem | work_mem | 20MB |
| Maintenance Work Mem | maintenance_work_mem | 2GB |

---

**Última atualização**: 2025-10-08
**Versão do BorgStack**: 1.0
**Versão do PostgreSQL**: 18.0 + pgvector
