# Guia de Otimização de Desempenho - BorgStack

## Índice
1. [Filosofia de Otimização](#filosofia-de-otimização)
2. [Monitoramento de Performance](#monitoramento-de-performance)
3. [Otimização de Containers Docker](#otimização-de-containers-docker)
4. [Otimização do PostgreSQL](#otimização-do-postgresql)
5. [Otimização do Redis](#otimização-do-redis)
6. [Otimização do MongoDB](#otimização-do-mongodb)
7. [Otimização de Rede](#otimização-de-rede)
8. [Otimização de Disco e I/O](#otimização-de-disco-e-io)
9. [Benchmarking](#benchmarking)
10. [Troubleshooting de Performance](#troubleshooting-de-performance)

---

## Filosofia de Otimização

### Princípios Fundamentais

```mermaid
graph TD
    A[Performance Problem] --> B{Measured?}
    B -->|No| C[Measure First]
    B -->|Yes| D{Identified Bottleneck?}

    C --> E[Baseline Metrics]
    E --> F[Load Testing]
    F --> D

    D -->|No| G[Profile & Analyze]
    D -->|Yes| H[Optimize]

    G --> H
    H --> I[Measure Again]

    I --> J{Improved?}
    J -->|Yes| K{Target Met?}
    J -->|No| L[Rollback]

    K -->|Yes| M[Document & Done]
    K -->|No| D

    L --> D
```

### Regras de Ouro

1. **Meça antes de otimizar** - Otimização prematura é a raiz de todo mal
2. **Identifique o gargalo** - Otimize o componente mais lento primeiro
3. **Uma mudança por vez** - Isole o impacto de cada otimização
4. **Documente tudo** - Registre métricas antes/depois
5. **Performance vs. Complexidade** - Nem sempre vale a pena

### Ordem de Prioridade

**Lei de Amdahl**: Otimize o que está consumindo mais recursos.

```bash
#!/bin/bash
# Script: identify-bottleneck.sh

echo "=== Identificação de Gargalos - BorgStack ==="
echo ""

# 1. CPU
echo "1. TOP 5 CONTAINERS POR USO DE CPU:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}" | \
    sort -k2 -hr | head -6

echo ""

# 2. Memória
echo "2. TOP 5 CONTAINERS POR USO DE MEMÓRIA:"
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}" | \
    sort -k3 -hr | head -6

echo ""

# 3. Disco I/O
echo "3. DISCO I/O (escrita):"
docker stats --no-stream --format "table {{.Name}}\t{{.BlockIO}}" | \
    sort -k2 -hr | head -6

echo ""

# 4. Rede I/O
echo "4. REDE I/O:"
docker stats --no-stream --format "table {{.Name}}\t{{.NetIO}}" | \
    sort -k2 -hr | head -6

echo ""
echo "✅ Otimize os containers com maiores percentuais primeiro"
```

---

## Monitoramento de Performance

### 2.1. Métricas em Tempo Real

```bash
#!/bin/bash
# Script: monitor-performance.sh

echo "=== Monitor de Performance - BorgStack ==="
echo ""

# Monitoramento contínuo
watch -n 5 '
echo "════════════════════════════════════════════════════════"
echo "Performance Dashboard - $(date)"
echo "════════════════════════════════════════════════════════"
echo ""

# Docker Stats
echo "DOCKER CONTAINERS:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"

echo ""

# Sistema
echo "SISTEMA:"
echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk "{print \$2}" | cut -d"%" -f1)%"
echo "RAM: $(free | grep Mem | awk "{print (\$3/\$2) * 100.0}") %"
echo "Disk: $(df -h / | tail -1 | awk "{print \$5}")"

echo ""

# Rede
echo "CONEXÕES ATIVAS:"
ss -s | grep "TCP:"

echo ""
echo "════════════════════════════════════════════════════════"
'
```

### 2.2. Coletar Métricas Históricas

```bash
#!/bin/bash
# Script: collect-metrics.sh

METRICS_DIR="/var/log/borgstack/metrics"
mkdir -p "$METRICS_DIR"

DATE=$(date +%Y%m%d_%H%M%S)
METRICS_FILE="$METRICS_DIR/metrics_$DATE.csv"

# Header CSV
echo "timestamp,container,cpu_percent,mem_usage,mem_percent,net_in,net_out,block_in,block_out" > "$METRICS_FILE"

# Coletar métricas de todos containers
docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}},{{.NetIO}},{{.BlockIO}}" | \
while IFS=, read -r name cpu mem_usage mem_perc net_io block_io; do
    # Parse valores
    net_in=$(echo "$net_io" | cut -d'/' -f1 | tr -d ' ')
    net_out=$(echo "$net_io" | cut -d'/' -f2 | tr -d ' ')
    block_in=$(echo "$block_io" | cut -d'/' -f1 | tr -d ' ')
    block_out=$(echo "$block_io" | cut -d'/' -f2 | tr -d ' ')

    # Escrever CSV
    echo "$DATE,$name,$cpu,$mem_usage,$mem_perc,$net_in,$net_out,$block_in,$block_out" >> "$METRICS_FILE"
done

echo "✅ Métricas coletadas: $METRICS_FILE"
```

**Automatizar coleta (crontab)**:

```bash
# Coletar métricas a cada 5 minutos
*/5 * * * * /path/to/collect-metrics.sh

# Agregar métricas diárias
0 0 * * * /path/to/aggregate-daily-metrics.sh
```

### 2.3. Dashboard de Performance com n8n

```javascript
// n8n - Workflow "Performance Dashboard"
// Schedule Trigger (a cada 5 min) → Function → PostgreSQL → Email (se threshold)

// Function node - Coletar métricas via Docker API
const containers = await $http.request({
    method: 'GET',
    url: 'http://localhost:2375/containers/json',
    json: true
});

const stats = [];
for (const container of containers) {
    const stat = await $http.request({
        method: 'GET',
        url: `http://localhost:2375/containers/${container.Id}/stats?stream=false`,
        json: true
    });

    // Calcular CPU %
    const cpuDelta = stat.cpu_stats.cpu_usage.total_usage -
                     stat.precpu_stats.cpu_usage.total_usage;
    const systemDelta = stat.cpu_stats.system_cpu_usage -
                        stat.precpu_stats.system_cpu_usage;
    const cpuPercent = (cpuDelta / systemDelta) * 100;

    // Calcular Memory %
    const memPercent = (stat.memory_stats.usage / stat.memory_stats.limit) * 100;

    stats.push({
        timestamp: new Date().toISOString(),
        container: container.Names[0].replace('/', ''),
        cpu_percent: cpuPercent.toFixed(2),
        mem_percent: memPercent.toFixed(2),
        mem_usage_mb: (stat.memory_stats.usage / 1024 / 1024).toFixed(2),
        alert: cpuPercent > 80 || memPercent > 85
    });
}

return stats.map(s => ({ json: s }));

// PostgreSQL node - Inserir métricas
// CREATE TABLE performance_metrics (
//   timestamp TIMESTAMPTZ,
//   container VARCHAR(50),
//   cpu_percent DECIMAL(5,2),
//   mem_percent DECIMAL(5,2),
//   mem_usage_mb DECIMAL(10,2),
//   alert BOOLEAN
// );

// IF node - Se houver alerta
// {{ $json.alert }} equals true

// Email node - Alertar
// Subject: ⚠️ Performance Alert - {{ $json.container }}
// Body: Container {{ $json.container }} está com uso elevado:
// - CPU: {{ $json.cpu_percent }}%
// - Memory: {{ $json.mem_percent }}% ({{ $json.mem_usage_mb }} MB)
```

---

## Otimização de Containers Docker

### 3.1. Limites de Recursos

```yaml
# docker-compose.yml
services:
  postgresql:
    image: pgvector/pgvector:pg18
    deploy:
      resources:
        limits:
          cpus: '4.0'          # Máximo 4 CPUs
          memory: 8G           # Máximo 8GB RAM
        reservations:
          cpus: '2.0'          # Garantir 2 CPUs
          memory: 4G           # Garantir 4GB RAM
    # ...

  chatwoot:
    image: chatwoot/chatwoot:latest
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          cpus: '1.0'
          memory: 2G
    # ...

  n8n:
    image: n8nio/n8n:latest
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
          pids: 200           # Limitar processos
        reservations:
          cpus: '0.5'
          memory: 512M
    # ...

  redis:
    image: redis:7-alpine
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 2G
        reservations:
          cpus: '0.25'
          memory: 512M
    command: >
      redis-server
      --maxmemory 1536mb
      --maxmemory-policy allkeys-lru
    # ...
```

### 3.2. Verificar Limites Configurados

```bash
#!/bin/bash
# Script: check-resource-limits.sh

echo "=== Limites de Recursos - Containers ==="
echo ""

for container in $(docker compose ps -q); do
    NAME=$(docker inspect $container --format='{{.Name}}' | sed 's/\///')

    echo "Container: $NAME"

    # CPU Limit
    CPU_QUOTA=$(docker inspect $container --format='{{.HostConfig.CpuQuota}}')
    CPU_PERIOD=$(docker inspect $container --format='{{.HostConfig.CpuPeriod}}')
    if [ "$CPU_QUOTA" != "0" ]; then
        CPU_LIMIT=$(awk "BEGIN {print $CPU_QUOTA/$CPU_PERIOD}")
        echo "  CPU Limit: $CPU_LIMIT cores"
    else
        echo "  CPU Limit: unlimited"
    fi

    # Memory Limit
    MEM_LIMIT=$(docker inspect $container --format='{{.HostConfig.Memory}}')
    if [ "$MEM_LIMIT" != "0" ]; then
        MEM_LIMIT_MB=$((MEM_LIMIT / 1024 / 1024))
        echo "  Memory Limit: ${MEM_LIMIT_MB} MB"
    else
        echo "  Memory Limit: unlimited"
    fi

    echo ""
done
```

### 3.3. Otimizar Builds Docker

```dockerfile
# Exemplo: Otimizar build do n8n custom

# ❌ LENTO - Reinstala dependências a cada mudança
FROM node:18-alpine
WORKDIR /app
COPY . .
RUN npm install
CMD ["npm", "start"]

# ✅ RÁPIDO - Cache de dependências
FROM node:18-alpine
WORKDIR /app

# 1. Copiar apenas package files primeiro
COPY package*.json ./

# 2. Instalar dependências (cacheable)
RUN npm ci --only=production

# 3. Copiar código (muda frequentemente)
COPY . .

# 4. Multi-stage para reduzir tamanho
FROM node:18-alpine
WORKDIR /app
COPY --from=0 /app .
CMD ["npm", "start"]
```

### 3.4. Health Checks Otimizados

```yaml
# docker-compose.yml
services:
  postgresql:
    # ...
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d postgres"]
      interval: 30s        # Não muito frequente (evita overhead)
      timeout: 5s
      retries: 3
      start_period: 60s    # Tempo para iniciar

  redis:
    # ...
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s        # Pode ser mais frequente (leve)
      timeout: 3s
      retries: 3
      start_period: 5s
```

---

## Otimização do PostgreSQL

### 4.1. Configuração Básica de Performance

```bash
# config/postgresql/postgresql.conf

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MEMORY CONFIGURATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# shared_buffers: 25% da RAM total para servidor dedicado
# Regra: Min 128MB, Max 8GB (além disso, retornos decrescentes)
shared_buffers = 2GB                    # Para 8GB RAM total

# effective_cache_size: 50-75% da RAM total
# Informa ao planner quanto de cache está disponível
effective_cache_size = 6GB              # 75% de 8GB

# work_mem: Memória para operações de sort/hash por operação
# Regra: Total RAM / max_connections / 4
# Para 100 conexões: 8GB / 100 / 4 = 20MB
work_mem = 20MB

# maintenance_work_mem: Para VACUUM, CREATE INDEX, etc.
# Regra: 5-10% da RAM, max 1GB
maintenance_work_mem = 512MB

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# QUERY PLANNER
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Custos de página (SSD vs HDD)
# SSD: random_page_cost = 1.1, seq_page_cost = 1.0
# HDD: random_page_cost = 4.0, seq_page_cost = 1.0
random_page_cost = 1.1                  # Para SSD
seq_page_cost = 1.0

# CPU costs
cpu_tuple_cost = 0.01
cpu_index_tuple_cost = 0.005
cpu_operator_cost = 0.0025

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# WRITE AHEAD LOG (WAL)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# WAL buffer
wal_buffers = 16MB

# WAL checkpoint
max_wal_size = 2GB                      # Checkpoint menos frequentes
min_wal_size = 1GB
checkpoint_completion_target = 0.9      # Distribuir I/O do checkpoint

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONNECTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

max_connections = 100                   # Ajustar conforme necessidade

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PARALLEL QUERY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

max_worker_processes = 8                # Número de CPUs
max_parallel_workers_per_gather = 4     # Parallelismo por query
max_parallel_maintenance_workers = 4    # Para CREATE INDEX, VACUUM
max_parallel_workers = 8

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LOGGING (para análise de performance)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Log queries lentas
log_min_duration_statement = 1000       # Log queries > 1 segundo
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_checkpoints = on
log_connections = off                   # off em produção
log_disconnections = off
log_lock_waits = on
log_temp_files = 0                      # Log todos arquivos temp

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUTOVACUUM
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

autovacuum = on
autovacuum_max_workers = 3
autovacuum_naptime = 1min               # Verificar a cada 1 minuto
autovacuum_vacuum_threshold = 50        # Min 50 tuplas
autovacuum_vacuum_scale_factor = 0.1    # + 10% da tabela
autovacuum_analyze_threshold = 50
autovacuum_analyze_scale_factor = 0.05  # + 5% da tabela
```

### 4.2. Otimização de Queries

#### Identificar Queries Lentas

```sql
-- Habilitar pg_stat_statements (adicionar em postgresql.conf)
-- shared_preload_libraries = 'pg_stat_statements'

-- Ver queries mais lentas
SELECT
    calls,
    total_exec_time / 1000 as total_time_seconds,
    mean_exec_time / 1000 as avg_time_seconds,
    max_exec_time / 1000 as max_time_seconds,
    query
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat_statements%'
ORDER BY mean_exec_time DESC
LIMIT 20;

-- Ver queries que mais consomem tempo total
SELECT
    calls,
    total_exec_time / 1000 as total_time_seconds,
    mean_exec_time / 1000 as avg_time_seconds,
    query
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat_statements%'
ORDER BY total_exec_time DESC
LIMIT 20;

-- Resetar estatísticas
SELECT pg_stat_statements_reset();
```

#### Analisar Plano de Execução

```sql
-- EXPLAIN mostra o plano
EXPLAIN SELECT * FROM conversations WHERE status = 'open';

-- EXPLAIN ANALYZE executa e mostra tempo real
EXPLAIN ANALYZE SELECT * FROM conversations WHERE status = 'open';

-- EXPLAIN com mais detalhes
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT * FROM conversations WHERE status = 'open';
```

**Interpretar EXPLAIN**:

- **Seq Scan**: Varredura completa da tabela (LENTO para tabelas grandes)
  - **Solução**: Criar índice
- **Index Scan**: Usa índice (RÁPIDO)
- **Bitmap Heap Scan**: Usa índice + heap (BOM para múltiplos resultados)
- **Nested Loop**: Join loop aninhado (BOM para pequenos datasets)
- **Hash Join**: Join com hash (BOM para grandes datasets)
- **Merge Join**: Join ordenado (BOM para datasets já ordenados)

#### Criar Índices Estratégicos

```sql
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CHATWOOT INDEXES
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Conversations frequentemente consultadas por status
CREATE INDEX CONCURRENTLY idx_conversations_status
ON conversations (status)
WHERE status IN ('open', 'pending');

-- Messages por conversation_id (foreign key)
CREATE INDEX CONCURRENTLY idx_messages_conversation_id
ON messages (conversation_id);

-- Messages por created_at (para ordenação temporal)
CREATE INDEX CONCURRENTLY idx_messages_created_at
ON messages (created_at DESC);

-- Composite index para queries específicas
CREATE INDEX CONCURRENTLY idx_conversations_account_status
ON conversations (account_id, status, updated_at DESC);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- N8N INDEXES
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Executions por workflowId e status
CREATE INDEX CONCURRENTLY idx_execution_workflow_status
ON execution_entity (workflowId, status, startedAt DESC);

-- Executions por waitTill (cron jobs)
CREATE INDEX CONCURRENTLY idx_execution_waittill
ON execution_entity (waitTill)
WHERE waitTill IS NOT NULL;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- DIRECTUS INDEXES
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Revisions por collection e item (histórico)
CREATE INDEX CONCURRENTLY idx_revisions_collection_item
ON directus_revisions (collection, item);

-- Activity por user (auditoria)
CREATE INDEX CONCURRENTLY idx_activity_user
ON directus_activity (user, timestamp DESC);
```

**IMPORTANTE**: Use `CREATE INDEX CONCURRENTLY` para não bloquear a tabela durante criação do índice.

#### Otimizar Joins

```sql
-- ❌ LENTO - Sem índices nas colunas de join
SELECT c.*, m.content
FROM conversations c
LEFT JOIN messages m ON c.id = m.conversation_id
WHERE c.status = 'open';

-- ✅ RÁPIDO - Com índices apropriados
-- CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);
-- CREATE INDEX idx_conversations_status ON conversations(status);

SELECT c.*, m.content
FROM conversations c
LEFT JOIN messages m ON c.id = m.conversation_id
WHERE c.status = 'open';

-- ✅ AINDA MAIS RÁPIDO - Limitar resultados
SELECT c.*, m.content
FROM conversations c
LEFT JOIN messages m ON c.id = m.conversation_id
WHERE c.status = 'open'
ORDER BY c.updated_at DESC
LIMIT 100;
```

### 4.3. Vacuum e Maintenance

```bash
#!/bin/bash
# Script: postgresql-maintenance.sh

echo "=== PostgreSQL Maintenance ==="
echo ""

# 1. Vacuum completo
echo "1. Executando VACUUM FULL ANALYZE..."
docker compose exec -T postgresql psql -U postgres << EOF
VACUUM (FULL, ANALYZE, VERBOSE);
EOF

echo ""

# 2. Reindex
echo "2. Reindexando bancos de dados..."
for DB in chatwoot n8n directus evolution_api; do
    echo "  Reindexing: $DB"
    docker compose exec -T postgresql psql -U postgres -d $DB -c "REINDEX DATABASE $DB;"
done

echo ""

# 3. Estatísticas de tabelas
echo "3. Atualizando estatísticas..."
docker compose exec -T postgresql psql -U postgres << EOF
ANALYZE VERBOSE;
EOF

echo ""
echo "✅ Manutenção completa"
```

### 4.4. Connection Pooling (PgBouncer)

Para muitas conexões simultâneas, use PgBouncer:

```yaml
# docker-compose.yml
services:
  pgbouncer:
    image: pgbouncer/pgbouncer:latest
    environment:
      - DATABASES_HOST=postgresql
      - DATABASES_PORT=5432
      - DATABASES_USER=postgres
      - DATABASES_PASSWORD=${POSTGRES_PASSWORD}
      - DATABASES_DBNAME=*
      - POOL_MODE=transaction
      - MAX_CLIENT_CONN=1000
      - DEFAULT_POOL_SIZE=25
    networks:
      - borgstack_internal
    depends_on:
      - postgresql

  # Serviços conectam via PgBouncer
  chatwoot:
    environment:
      - POSTGRES_HOST=pgbouncer  # Em vez de postgresql
      - POSTGRES_PORT=5432
    # ...
```

---

## Otimização do Redis

### 5.1. Configuração de Performance

```bash
# config/redis/redis.conf

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MEMORY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Limite de memória (75% do container limit)
maxmemory 1536mb

# Política de eviction (remover chaves menos usadas)
maxmemory-policy allkeys-lru

# Samples para LRU (quanto maior, mais preciso mas mais lento)
maxmemory-samples 5

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PERSISTENCE (Desabilitar se apenas cache)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# RDB: Snapshot periódico
save 900 1          # Após 900 seg (15 min) se >= 1 chave mudou
save 300 10         # Após 300 seg (5 min) se >= 10 chaves mudaram
save 60 10000       # Após 60 seg (1 min) se >= 10000 chaves mudaram

# Compressão RDB
rdbcompression yes
rdbchecksum yes

# AOF: Append-Only File (mais durável, mais lento)
appendonly no       # Desabilitar para melhor performance (usar apenas RDB)

# Se AOF habilitado:
# appendfsync everysec  # Sync a cada segundo (balanço performance/durabilidade)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# NETWORK
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# TCP backlog
tcp-backlog 511

# TCP keepalive
tcp-keepalive 300

# Timeout (0 = desabilitar)
timeout 0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ADVANCED
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Lazy freeing (libera memória em background)
lazyfree-lazy-eviction yes
lazyfree-lazy-expire yes
lazyfree-lazy-server-del yes
replica-lazy-flush yes

# I/O threads (Redis 6+)
io-threads 4
io-threads-do-reads yes
```

### 5.2. Monitorar Performance Redis

```bash
#!/bin/bash
# Script: redis-performance.sh

echo "=== Redis Performance Monitor ==="
echo ""

# 1. Info
echo "1. REDIS INFO:"
docker compose exec redis redis-cli INFO | grep -E "used_memory_human|used_memory_peak_human|connected_clients|instantaneous_ops_per_sec|total_commands_processed"

echo ""

# 2. Slow log
echo "2. SLOW LOG (queries > 10ms):"
docker compose exec redis redis-cli CONFIG SET slowlog-log-slower-than 10000
docker compose exec redis redis-cli SLOWLOG GET 10

echo ""

# 3. Stats por database
echo "3. STATS POR DATABASE:"
for DB in 0 1 2 3; do
    KEYS=$(docker compose exec redis redis-cli -n $DB DBSIZE)
    echo "  Database $DB: $KEYS"
done

echo ""

# 4. Comandos mais usados
echo "4. TOP COMANDOS:"
docker compose exec redis redis-cli INFO commandstats | \
    grep cmdstat | \
    sort -t= -k2 -nr | \
    head -10
```

### 5.3. Otimizar Uso do Redis

#### Pipeline para Múltiplas Operações

```javascript
// n8n - Function node
// ❌ LENTO - Uma operação por vez
const redis = require('redis');
const client = redis.createClient({ url: 'redis://redis:6379' });
await client.connect();

for (let i = 0; i < 1000; i++) {
    await client.set(`key${i}`, `value${i}`);  // 1000 round-trips
}

// ✅ RÁPIDO - Pipeline
const redis = require('redis');
const client = redis.createClient({ url: 'redis://redis:6379' });
await client.connect();

const pipeline = client.multi();
for (let i = 0; i < 1000; i++) {
    pipeline.set(`key${i}`, `value${i}`);
}
await pipeline.exec();  // 1 round-trip

await client.quit();
```

#### Usar Estruturas de Dados Eficientes

```javascript
// ❌ LENTO - Múltiplas chaves
await client.set('user:1:name', 'João');
await client.set('user:1:email', 'joao@example.com');
await client.set('user:1:age', '30');

// ✅ RÁPIDO - Hash (estrutura única)
await client.hSet('user:1', {
    name: 'João',
    email: 'joao@example.com',
    age: '30'
});

// Recuperar
const user = await client.hGetAll('user:1');
```

#### TTL Apropriado

```javascript
// Definir TTL para evitar crescimento infinito
await client.set('session:abc123', sessionData, {
    EX: 3600  // Expira em 1 hora
});

// Verificar TTL
const ttl = await client.ttl('session:abc123');
console.log(`Expira em ${ttl} segundos`);
```

---

## Otimização do MongoDB

### 6.1. Configuração de Performance

```yaml
# docker-compose.yml
services:
  mongodb:
    image: mongo:8
    command: >
      mongod
      --wiredTigerCacheSizeGB 1.5
      --wiredTigerCollectionBlockCompressor snappy
      --wiredTigerJournalCompressor snappy
      --logLevel info
      --profile 1
      --slowms 100
    deploy:
      resources:
        limits:
          memory: 3G
        reservations:
          memory: 2G
```

### 6.2. Índices MongoDB

```javascript
// n8n - MongoDB node ou script externo

// Conectar ao MongoDB
const { MongoClient } = require('mongodb');
const client = new MongoClient('mongodb://root:password@mongodb:27017');
await client.connect();

const db = client.db('lowcoder');

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Criar índices
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// Índice simples
await db.collection('applications').createIndex({ userId: 1 });

// Índice composto
await db.collection('applications').createIndex(
    { userId: 1, createdAt: -1 },
    { background: true }  // Criar em background
);

// Índice único
await db.collection('users').createIndex(
    { email: 1 },
    { unique: true }
);

// Índice TTL (auto-delete após tempo)
await db.collection('sessions').createIndex(
    { createdAt: 1 },
    { expireAfterSeconds: 3600 }  // 1 hora
);

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Listar índices
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const indexes = await db.collection('applications').indexes();
console.log(indexes);

await client.close();
```

### 6.3. Analisar Queries Lentas

```javascript
// Habilitar profiler (já configurado no docker-compose)
// --profile 1 --slowms 100

// Ver queries lentas
db.system.profile.find({ millis: { $gt: 100 } })
    .sort({ ts: -1 })
    .limit(10)
    .pretty();

// Analisar query específica
db.applications.find({ userId: "abc123" }).explain("executionStats");
```

---

## Otimização de Rede

### 7.1. Reduzir Latência entre Containers

```yaml
# docker-compose.yml
# Containers que se comunicam muito devem estar na mesma rede

services:
  n8n:
    networks:
      - borgstack_internal
      - borgstack_external

  postgresql:
    networks:
      - borgstack_internal  # Apenas rede interna (mais rápido)

  # n8n → PostgreSQL: latência mínima (mesma rede)
```

### 7.2. DNS Caching

```yaml
# docker-compose.yml
services:
  n8n:
    dns:
      - 8.8.8.8
      - 8.8.4.4
    dns_search:
      - borgstack.local
```

### 7.3. Otimizar Caddy (Reverse Proxy)

```caddyfile
# Caddyfile

{
    # Global options
    auto_https off  # Desabilitar se em desenvolvimento
    servers {
        timeouts {
            read_body   10s
            read_header 10s
            write       30s
            idle        2m
        }
    }
}

# Compression
(compression) {
    encode gzip zstd {
        level 6  # Balanço compressão/CPU
    }
}

# Caching
(cache) {
    header {
        Cache-Control "public, max-age=3600"
    }
}

# n8n
n8n.borgstack.local {
    import compression
    reverse_proxy n8n:5678 {
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}

        # Timeouts
        transport http {
            dial_timeout 10s
            response_header_timeout 30s
        }
    }
}

# Directus (com cache de assets)
directus.borgstack.local {
    import compression

    # Assets estáticos com cache
    @assets {
        path /assets/*
    }
    handle @assets {
        import cache
        reverse_proxy directus:8055
    }

    # API sem cache
    reverse_proxy directus:8055
}
```

---

## Otimização de Disco e I/O

### 8.1. Usar Volumes Named (mais rápido que bind mounts)

```yaml
# docker-compose.yml
services:
  postgresql:
    volumes:
      # ✅ RÁPIDO - Named volume
      - borgstack_postgresql_data:/var/lib/postgresql/data

      # ❌ LENTO - Bind mount
      # - ./volumes/postgresql_data:/var/lib/postgresql/data

volumes:
  borgstack_postgresql_data:
    driver: local
```

### 8.2. Limitar Logs

```yaml
# docker-compose.yml
services:
  chatwoot:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"      # Máximo 10MB por arquivo
        max-file: "3"        # Manter 3 arquivos (total 30MB)
        compress: "true"     # Comprimir logs antigos
```

### 8.3. Monitorar I/O de Disco

```bash
#!/bin/bash
# Script: disk-io-monitor.sh

echo "=== Disk I/O Monitor ==="
echo ""

# I/O por container
docker stats --no-stream --format "table {{.Name}}\t{{.BlockIO}}" | \
    sort -k2 -hr

echo ""

# I/O do sistema
iostat -x 1 5
```

---

## Benchmarking

### 9.1. Benchmark PostgreSQL

```bash
#!/bin/bash
# Script: benchmark-postgresql.sh

echo "=== PostgreSQL Benchmark ==="
echo ""

# pgbench: Ferramenta oficial de benchmark
docker compose exec postgresql pgbench -i -s 50 postgres  # Inicializar com scale 50

echo "1. Teste READ-ONLY (SELECT):"
docker compose exec postgresql pgbench -c 10 -j 2 -t 1000 -S postgres
# -c 10: 10 clientes
# -j 2: 2 threads
# -t 1000: 1000 transações por cliente
# -S: SELECT apenas

echo ""
echo "2. Teste READ-WRITE (TPC-B):"
docker compose exec postgresql pgbench -c 10 -j 2 -t 1000 postgres

echo ""
echo "3. Teste CONCORRÊNCIA ALTA:"
docker compose exec postgresql pgbench -c 50 -j 4 -t 500 postgres
```

### 9.2. Benchmark Redis

```bash
#!/bin/bash
# Script: benchmark-redis.sh

echo "=== Redis Benchmark ==="
echo ""

# redis-benchmark: Ferramenta oficial
docker compose exec redis redis-benchmark -q -n 100000

# Testes específicos
echo "1. SET:"
docker compose exec redis redis-benchmark -t set -n 100000 -q

echo "2. GET:"
docker compose exec redis redis-benchmark -t get -n 100000 -q

echo "3. LPUSH:"
docker compose exec redis redis-benchmark -t lpush -n 100000 -q

echo "4. PIPELINE (10 comandos):"
docker compose exec redis redis-benchmark -n 100000 -P 10 -q
```

### 9.3. Benchmark HTTP (Caddy/n8n)

```bash
#!/bin/bash
# Script: benchmark-http.sh

echo "=== HTTP Benchmark com Apache Bench ==="
echo ""

# Instalar Apache Bench
sudo apt install -y apache2-utils

# Benchmark n8n
echo "1. n8n webhook:"
ab -n 1000 -c 10 https://n8n.borgstack.local/webhook-test/ping
# -n 1000: 1000 requests
# -c 10: 10 concurrent

echo ""
echo "2. Directus API:"
ab -n 1000 -c 10 -H "Authorization: Bearer $DIRECTUS_TOKEN" \
    https://directus.borgstack.local/items/articles

echo ""
echo "=== Benchmark com wrk (mais avançado) ==="

# Instalar wrk
sudo apt install -y wrk

# Teste de carga
wrk -t4 -c100 -d30s --latency https://n8n.borgstack.local/webhook-test/ping
# -t4: 4 threads
# -c100: 100 conexões
# -d30s: duração 30 segundos
# --latency: mostrar latências
```

---

## Troubleshooting de Performance

### 10.1. Container Usando Muita CPU

```bash
#!/bin/bash
# Script: debug-high-cpu.sh

CONTAINER_NAME="$1"

if [ -z "$CONTAINER_NAME" ]; then
    echo "Uso: $0 <container_name>"
    exit 1
fi

echo "=== Debug High CPU: $CONTAINER_NAME ==="
echo ""

# 1. Ver processos dentro do container
echo "1. TOP processos:"
docker compose exec "$CONTAINER_NAME" top -bn1 | head -20

echo ""

# 2. Strace (rastrear system calls)
echo "2. System calls (5 segundos):"
docker compose exec "$CONTAINER_NAME" sh -c "
    apt update && apt install -y strace 2>/dev/null || apk add strace 2>/dev/null
    PID=\$(ps aux | grep -v grep | head -2 | tail -1 | awk '{print \$1}')
    timeout 5 strace -c -p \$PID 2>&1 || echo 'Strace failed'
"

echo ""

# 3. Verificar threads
echo "3. Threads:"
docker compose exec "$CONTAINER_NAME" ps -eLf

echo ""
echo "DICAS:"
echo "- Se muitos system calls: otimizar I/O"
echo "- Se muitas threads: verificar configuração de workers"
echo "- Se processo específico: investigar aquele processo"
```

### 10.2. Container Usando Muita Memória

```bash
#!/bin/bash
# Script: debug-high-memory.sh

CONTAINER_NAME="$1"

if [ -z "$CONTAINER_NAME" ]; then
    echo "Uso: $0 <container_name>"
    exit 1
fi

echo "=== Debug High Memory: $CONTAINER_NAME ==="
echo ""

# 1. Estatísticas de memória
echo "1. Memory stats:"
docker stats --no-stream "$CONTAINER_NAME" --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}"

echo ""

# 2. Processos ordenados por memória
echo "2. Processos por memória:"
docker compose exec "$CONTAINER_NAME" ps aux --sort=-%mem | head -10

echo ""

# 3. Verificar memory leaks (se Node.js)
echo "3. Node.js heap (se aplicável):"
docker compose exec "$CONTAINER_NAME" sh -c "
    if command -v node &> /dev/null; then
        node -e 'console.log(process.memoryUsage())'
    else
        echo 'Não é um container Node.js'
    fi
"

echo ""
echo "SOLUÇÕES:"
echo "- Aumentar limite de memória no docker-compose.yml"
echo "- Reiniciar container para liberar memória"
echo "- Otimizar aplicação (memory leaks, cache excessivo)"
```

### 10.3. Queries PostgreSQL Lentas

```sql
-- Ver conexões ativas e queries em execução
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    state,
    query_start,
    state_change,
    LEFT(query, 100) as query_preview
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY query_start;

-- Matar query lenta
SELECT pg_cancel_backend(PID);  -- Cancelar
SELECT pg_terminate_backend(PID);  -- Forçar terminar

-- Ver locks
SELECT
    locktype,
    relation::regclass,
    mode,
    granted,
    pid
FROM pg_locks
WHERE NOT granted;
```

### 10.4. Checklist de Performance

```markdown
# Checklist de Otimização de Performance

## Containers Docker
- [ ] Limites de CPU/memória configurados
- [ ] Health checks não muito frequentes
- [ ] Logs com rotation e compressão
- [ ] Volumes named (não bind mounts)

## PostgreSQL
- [ ] shared_buffers = 25% RAM
- [ ] effective_cache_size = 75% RAM
- [ ] work_mem apropriado
- [ ] random_page_cost = 1.1 (SSD)
- [ ] Índices nas colunas de WHERE/JOIN/ORDER BY
- [ ] VACUUM executado regularmente
- [ ] Queries lentas identificadas (pg_stat_statements)
- [ ] Connection pooling (se >100 conexões)

## Redis
- [ ] maxmemory configurado
- [ ] maxmemory-policy definida
- [ ] Persistência apropriada (RDB/AOF/nenhuma)
- [ ] Pipeline para múltiplas operações
- [ ] TTL em chaves temporárias
- [ ] Estruturas de dados eficientes (hashes, sets)

## MongoDB
- [ ] wiredTigerCacheSizeGB configurado
- [ ] Índices em campos consultados
- [ ] Profiler habilitado para queries lentas
- [ ] TTL indexes para dados temporários

## Rede
- [ ] Containers em redes apropriadas
- [ ] Caddy com compression
- [ ] DNS caching
- [ ] Timeouts configurados

## Monitoramento
- [ ] docker stats rodando
- [ ] Métricas coletadas historicamente
- [ ] Alertas de performance configurados
- [ ] Benchmark baseline documentado
```

---

## Recursos Adicionais

### Ferramentas Recomendadas

- **ctop**: Monitor interativo de containers (`docker run --rm -ti -v /var/run/docker.sock:/var/run/docker.sock quay.io/vektorlab/ctop:latest`)
- **pgAdmin**: Interface web para PostgreSQL
- **Redis Insight**: Interface web para Redis
- **MongoDB Compass**: Interface web para MongoDB

### Referências

- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Redis Performance Best Practices](https://redis.io/docs/latest/operate/oss_and_stack/management/optimization/)
- [Docker Performance Best Practices](https://docs.docker.com/config/containers/resource_constraints/)
- [PGTune](https://pgtune.leopard.in.ua/) - Gerador de configuração PostgreSQL

---

**Este guia de performance deve ser revisado após cada atualização significativa do sistema.**

**Última atualização**: 2025-10-08
