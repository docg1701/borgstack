# Redis - Cache e Message Broker

## Visão Geral

### O que é Redis?

Redis (Remote Dictionary Server) é um armazenamento de estrutura de dados em memória, de código aberto, usado como banco de dados, cache e message broker. É conhecido por sua alta performance, suportando milhões de operações por segundo com latência sub-milissegundo.

No contexto do BorgStack, o Redis serve como **cache e queue compartilhado** para múltiplos serviços:
- **n8n**: Cache de workflows, queue de execuções
- **Chatwoot**: Cache de conversas, filas Sidekiq (background jobs)
- **Directus**: Cache de schemas, sessões
- **Lowcoder**: Cache de aplicações, sessões de usuários

### Versão no BorgStack

- **Versão**: Redis 8.2
- **Modo**: Standalone (sem replicação/cluster por simplicidade)
- **Persistência**: AOF (Append Only File) habilitado

### Características Principais

1. **In-Memory**: Dados armazenados na RAM para acesso ultrarrápido
2. **Estruturas de Dados Ricas**: Strings, hashes, lists, sets, sorted sets, bitmaps, hyperloglogs, streams
3. **Persistência**: AOF e RDB para durabilidade de dados
4. **Pub/Sub**: Sistema de mensageria publish/subscribe
5. **Atomic Operations**: Todas as operações são atômicas

---

## Configuração Inicial

### Localização dos Arquivos

```bash
# Dados do Redis (volume Docker)
docker volume inspect borgstack_redis_data

# Configuração customizada
config/redis/redis.conf

# Logs
docker compose logs -f redis

# Verificar status
docker compose ps redis
```

### Organização dos Dados

Redis usa **databases numerados** (0-15 por padrão):

```bash
# Database 0 (padrão): n8n
# Database 1: Chatwoot
# Database 2: Directus
# Database 3: Lowcoder
# Database 4-15: Disponíveis
```

**Estratégia de Isolamento**:
- Cada serviço usa database separado
- Evita conflitos de chaves entre serviços
- Facilita limpeza seletiva de cache

### Credenciais e Conexão

Credenciais no arquivo `.env`:

```bash
# Senha do Redis
REDIS_PASSWORD=senha_super_segura_redis

# URL de conexão (formato)
redis://:senha@redis:6379/0
```

### Conectar ao Redis

#### Via redis-cli (Container)

```bash
# Conectar sem autenticação (se não houver senha)
docker compose exec redis redis-cli

# Conectar com senha
docker compose exec redis redis-cli -a senha_super_segura_redis

# Conectar e selecionar database
docker compose exec redis redis-cli -a senha_super_segura_redis -n 1

# Testar conectividade
docker compose exec redis redis-cli -a senha_super_segura_redis PING
# Resposta esperada: PONG

# Ver informações do servidor
docker compose exec redis redis-cli -a senha_super_segura_redis INFO
```

#### Connection String

Formato para conexão de aplicações:

```bash
# n8n (database 0)
redis://:senha_super_segura_redis@redis:6379/0

# Chatwoot (database 1)
redis://:senha_super_segura_redis@redis:6379/1

# Directus (database 2)
redis://:senha_super_segura_redis@redis:6379/2

# Lowcoder (database 3)
redis://:senha_super_segura_redis@redis:6379/3
```

---

## Conceitos Fundamentais

### 1. Keys e Values

Redis armazena pares **chave-valor**:

```bash
# Conectar ao redis-cli
docker compose exec redis redis-cli -a senha

# Definir valor
SET minhaChave "meuValor"

# Obter valor
GET minhaChave

# Verificar se chave existe
EXISTS minhaChave

# Deletar chave
DEL minhaChave

# Definir com expiração (TTL em segundos)
SETEX sessao:123 3600 "dados_da_sessao"

# Ver tempo restante
TTL sessao:123

# Listar todas as chaves (CUIDADO em produção!)
KEYS *

# Listar chaves por padrão
KEYS user:*
KEYS sessao:*
```

### 2. Data Types

#### String

```bash
# String simples
SET contador 0
GET contador

# Incrementar
INCR contador
# Retorna: 1

# Incrementar por valor
INCRBY contador 10
# Retorna: 11

# Decrementar
DECR contador
```

#### Hash

Ideal para objetos:

```bash
# Definir campos de hash
HSET usuario:1 nome "João" email "joao@example.com" idade 30

# Obter campo específico
HGET usuario:1 nome

# Obter todos os campos
HGETALL usuario:1

# Obter múltiplos campos
HMGET usuario:1 nome email

# Verificar se campo existe
HEXISTS usuario:1 nome

# Deletar campo
HDEL usuario:1 idade
```

#### List

Listas ordenadas:

```bash
# Adicionar ao final
RPUSH fila:jobs "job1" "job2" "job3"

# Adicionar ao início
LPUSH fila:jobs "job0"

# Ver todos os itens
LRANGE fila:jobs 0 -1

# Obter tamanho
LLEN fila:jobs

# Remover do início (queue FIFO)
LPOP fila:jobs

# Remover do final (stack LIFO)
RPOP fila:jobs

# Obter elemento por índice
LINDEX fila:jobs 0
```

#### Set

Conjuntos únicos não ordenados:

```bash
# Adicionar membros
SADD tags:post:1 "redis" "cache" "database"

# Ver todos os membros
SMEMBERS tags:post:1

# Verificar se membro existe
SISMEMBER tags:post:1 "redis"

# Remover membro
SREM tags:post:1 "database"

# Contar membros
SCARD tags:post:1

# Operações de conjunto
SADD tags:post:2 "redis" "nosql"
SINTER tags:post:1 tags:post:2  # Interseção
SUNION tags:post:1 tags:post:2  # União
SDIFF tags:post:1 tags:post:2   # Diferença
```

#### Sorted Set

Conjuntos ordenados por score:

```bash
# Adicionar membros com score
ZADD ranking 100 "usuario1" 200 "usuario2" 150 "usuario3"

# Ver todos (ordenado por score)
ZRANGE ranking 0 -1 WITHSCORES

# Ver em ordem reversa
ZREVRANGE ranking 0 -1 WITHSCORES

# Ver por range de score
ZRANGEBYSCORE ranking 100 200

# Obter posição
ZRANK ranking "usuario1"

# Obter score
ZSCORE ranking "usuario1"

# Incrementar score
ZINCRBY ranking 50 "usuario1"
```

### 3. Expiração e TTL

```bash
# Definir expiração em segundos
EXPIRE minhaChave 60

# Definir expiração em milissegundos
PEXPIRE minhaChave 60000

# Definir timestamp Unix de expiração
EXPIREAT minhaChave 1735689600

# Ver tempo restante (segundos)
TTL minhaChave

# Ver tempo restante (milissegundos)
PTTL minhaChave

# Remover expiração (tornar persistente)
PERSIST minhaChave
```

### 4. Pub/Sub (Publish/Subscribe)

```bash
# Terminal 1: Subscriber
SUBSCRIBE canal:notificacoes

# Terminal 2: Publisher
PUBLISH canal:notificacoes "Nova mensagem!"

# Subscribe a múltiplos canais
SUBSCRIBE canal:1 canal:2 canal:3

# Subscribe com padrão
PSUBSCRIBE canal:*

# Unsubscribe
UNSUBSCRIBE canal:notificacoes
```

### 5. Transactions

```bash
# Iniciar transação
MULTI

# Comandos (enfileirados)
SET chave1 "valor1"
SET chave2 "valor2"
INCR contador

# Executar transação
EXEC

# Ou cancelar
DISCARD

# Watch (otimistic locking)
WATCH minhaChave
MULTI
SET minhaChave "novo_valor"
EXEC
# Se minhaChave foi modificada, EXEC retorna null
```

---

## Tutorial Passo a Passo: Gerenciamento Básico

### Passo 1: Verificar Status do Redis

```bash
# Container está rodando?
docker compose ps redis

# Health check
docker inspect redis | grep -A 10 "Health"

# Logs recentes
docker compose logs --tail=50 redis

# Conectividade
docker compose exec redis redis-cli -a senha PING
# Esperado: PONG

# Ver informações do servidor
docker compose exec redis redis-cli -a senha INFO server
```

### Passo 2: Explorar Databases e Chaves

```bash
# Conectar ao redis-cli
docker compose exec redis redis-cli -a senha

# Dentro do redis-cli:
```

```redis
# Ver database atual
SELECT 0

# Ver informações
INFO keyspace

# Listar chaves (n8n - database 0)
SELECT 0
KEYS *

# Ver chaves do Chatwoot (database 1)
SELECT 1
KEYS *

# Ver chaves do Directus (database 2)
SELECT 2
KEYS *

# Contar chaves em cada database
SELECT 0
DBSIZE

SELECT 1
DBSIZE

SELECT 2
DBSIZE
```

### Passo 3: Monitorar Operações em Tempo Real

```bash
# Ver comandos em tempo real (CUIDADO: impacta performance!)
docker compose exec redis redis-cli -a senha MONITOR

# Exemplo de saída:
# 1710364800.123456 [0 172.18.0.5:51234] "GET" "workflow:cache:123"
# 1710364801.234567 [1 172.18.0.6:51235] "SETEX" "session:abc" "3600" "{...}"
```

### Passo 4: Analisar Uso de Memória

```bash
# Ver uso total de memória
docker compose exec redis redis-cli -a senha INFO memory

# Ver memória usada por cada database
docker compose exec redis redis-cli -a senha --bigkeys

# Analisar chaves grandes
docker compose exec redis redis-cli -a senha --memkeys

# Ver estatísticas detalhadas
docker compose exec redis redis-cli -a senha MEMORY STATS
```

### Passo 5: Gerenciar Cache

```bash
# Limpar database específico (CUIDADO!)
docker compose exec redis redis-cli -a senha -n 0 FLUSHDB

# Limpar TODOS os databases (MUITO CUIDADO!)
docker compose exec redis redis-cli -a senha FLUSHALL

# Deletar chaves por padrão
docker compose exec redis redis-cli -a senha --scan --pattern "cache:*" | xargs docker compose exec -T redis redis-cli -a senha DEL

# Ver chaves expiradas
docker compose exec redis redis-cli -a senha --scan | while read key; do
    ttl=$(docker compose exec redis redis-cli -a senha TTL "$key")
    if [ "$ttl" -gt 0 ]; then
        echo "$key: ${ttl}s"
    fi
done
```

---

## Persistência e Backup

### Estratégias de Persistência

Redis suporta duas formas de persistência:

#### RDB (Redis Database)

Snapshots point-in-time:

```bash
# Forçar snapshot síncrono (bloqueia clientes)
docker compose exec redis redis-cli -a senha SAVE

# Forçar snapshot assíncrono (background)
docker compose exec redis redis-cli -a senha BGSAVE

# Ver último save
docker compose exec redis redis-cli -a senha LASTSAVE

# Configurar snapshot automático (redis.conf)
# save 900 1       # Após 900s se >= 1 chave mudou
# save 300 10      # Após 300s se >= 10 chaves mudaram
# save 60 10000    # Após 60s se >= 10000 chaves mudaram
```

#### AOF (Append Only File)

Log de todas as operações de escrita (padrão no BorgStack):

```bash
# Reescrever AOF (compactar)
docker compose exec redis redis-cli -a senha BGREWRITEAOF

# Verificar status do AOF
docker compose exec redis redis-cli -a senha INFO persistence

# Configuração AOF (redis.conf)
# appendonly yes
# appendfsync everysec  # fsync a cada segundo (padrão)
# appendfsync always    # fsync a cada operação (mais lento, mais seguro)
# appendfsync no        # deixa o OS decidir (mais rápido, menos seguro)
```

### Backup Manual

#### Backup via RDB

```bash
# Gerar snapshot
docker compose exec redis redis-cli -a senha BGSAVE

# Aguardar conclusão
docker compose exec redis redis-cli -a senha INFO persistence | grep rdb_bgsave_in_progress
# 0 = concluído

# Copiar dump.rdb do container
docker cp redis:/data/dump.rdb ./backups/redis_$(date +%Y%m%d).rdb
```

#### Backup via AOF

```bash
# Se AOF habilitado
docker compose exec redis redis-cli -a senha CONFIG GET appendonly
# appendonly: yes

# Copiar arquivos AOF
docker cp redis:/data/appendonlydir ./backups/redis_aof_$(date +%Y%m%d)
```

#### Backup via redis-cli --rdb

```bash
# Backup remoto (recomendado)
docker compose exec redis redis-cli -a senha --rdb ./backups/dump_$(date +%Y%m%d).rdb
```

### Restore

```bash
# Parar Redis
docker compose stop redis

# Copiar backup para volume
docker cp ./backups/dump_20250108.rdb redis:/data/dump.rdb

# Se AOF habilitado, copiar AOF também
docker cp ./backups/redis_aof_20250108 redis:/data/appendonlydir

# Iniciar Redis
docker compose start redis

# Verificar restauração
docker compose exec redis redis-cli -a senha DBSIZE
```

### Script de Backup Automatizado

```bash
#!/bin/bash
# backups/backup-redis.sh

set -e

BACKUP_DIR="/path/to/backups/redis"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

mkdir -p "$BACKUP_DIR"

echo "Starting Redis backup..."

# Forçar snapshot em background
docker compose exec redis redis-cli -a "$REDIS_PASSWORD" BGSAVE

# Aguardar conclusão (timeout 5 minutos)
for i in {1..60}; do
    IN_PROGRESS=$(docker compose exec redis redis-cli -a "$REDIS_PASSWORD" INFO persistence | grep "rdb_bgsave_in_progress:1" || echo "")

    if [ -z "$IN_PROGRESS" ]; then
        echo "✅ Snapshot completed"
        break
    fi

    if [ $i -eq 60 ]; then
        echo "❌ Timeout waiting for snapshot"
        exit 1
    fi

    echo "Waiting for snapshot... ($i/60)"
    sleep 5
done

# Copiar dump.rdb
docker cp redis:/data/dump.rdb "$BACKUP_DIR/dump_${TIMESTAMP}.rdb"

# Verificar integridade
if [ -f "$BACKUP_DIR/dump_${TIMESTAMP}.rdb" ]; then
    SIZE=$(du -h "$BACKUP_DIR/dump_${TIMESTAMP}.rdb" | cut -f1)
    echo "✅ Backup completed: $SIZE"
else
    echo "❌ Backup failed!"
    exit 1
fi

# Remover backups antigos
echo "Cleaning old backups (older than $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -name "*.rdb" -mtime +$RETENTION_DAYS -delete

echo "✅ Backup process completed successfully!"
```

---

## Otimização de Performance

### Configurações de Memória

```bash
# Ver uso de memória
docker compose exec redis redis-cli -a senha INFO memory

# Definir limite de memória (config/redis/redis.conf)
# maxmemory 2gb

# Ver limite atual
docker compose exec redis redis-cli -a senha CONFIG GET maxmemory

# Definir política de eviction
# maxmemory-policy allkeys-lru  # Remove chaves menos usadas
# maxmemory-policy volatile-lru  # Remove chaves com TTL menos usadas
# maxmemory-policy allkeys-lfu  # Remove chaves menos frequentes
# maxmemory-policy volatile-lfu  # Remove chaves com TTL menos frequentes
# maxmemory-policy allkeys-random  # Remove chaves aleatórias
# maxmemory-policy volatile-ttl  # Remove chaves com TTL menor

# Ver política atual
docker compose exec redis redis-cli -a senha CONFIG GET maxmemory-policy
```

### Políticas de Eviction Explicadas

| Política | Descrição | Caso de Uso |
|----------|-----------|-------------|
| `allkeys-lru` | Remove chaves menos usadas recentemente | Cache geral |
| `volatile-lru` | Remove chaves com TTL menos usadas | Cache com dados permanentes |
| `allkeys-lfu` | Remove chaves menos frequentes | Cache com padrões de acesso |
| `volatile-lfu` | Remove chaves com TTL menos frequentes | Cache misto |
| `allkeys-random` | Remove chaves aleatórias | Sem preferência |
| `volatile-ttl` | Remove chaves com menor TTL | Expiração prioritária |
| `noeviction` | Retorna erro quando memória cheia | Sem cache |

### Comandos Lentos

```bash
# Ver slowlog (comandos lentos)
docker compose exec redis redis-cli -a senha SLOWLOG GET 10

# Limpar slowlog
docker compose exec redis redis-cli -a senha SLOWLOG RESET

# Configurar threshold (microsegundos)
# slowlog-log-slower-than 10000  # 10ms
docker compose exec redis redis-cli -a senha CONFIG SET slowlog-log-slower-than 10000
```

### Pipeline e Batching

Em vez de executar comandos um por um, use pipeline:

```bash
# SEM pipeline (lento - múltiplas roundtrips)
redis-cli SET key1 value1
redis-cli SET key2 value2
redis-cli SET key3 value3

# COM pipeline (rápido - uma roundtrip)
echo -e "SET key1 value1\nSET key2 value2\nSET key3 value3" | redis-cli -a senha --pipe
```

---

## Monitoramento

### Comandos de Monitoramento

```bash
# Informações gerais
docker compose exec redis redis-cli -a senha INFO

# Seções específicas
docker compose exec redis redis-cli -a senha INFO server
docker compose exec redis redis-cli -a senha INFO clients
docker compose exec redis redis-cli -a senha INFO memory
docker compose exec redis redis-cli -a senha INFO persistence
docker compose exec redis redis-cli -a senha INFO stats
docker compose exec redis redis-cli -a senha INFO replication
docker compose exec redis redis-cli -a senha INFO cpu
docker compose exec redis redis-cli -a senha INFO keyspace

# Estatísticas em tempo real
docker compose exec redis redis-cli -a senha --stat

# Latência
docker compose exec redis redis-cli -a senha --latency

# Ver clientes conectados
docker compose exec redis redis-cli -a senha CLIENT LIST

# Ver comandos executados
docker compose exec redis redis-cli -a senha INFO commandstats
```

### Métricas Importantes

```bash
# Uso de memória
used_memory_human: 2.5G
used_memory_peak_human: 3.2G

# Taxa de hit do cache
keyspace_hits: 1000000
keyspace_misses: 50000
# hit_rate = hits / (hits + misses) = 95.2%

# Operações por segundo
instantaneous_ops_per_sec: 5000

# Conexões
connected_clients: 15
blocked_clients: 0

# Persistência
rdb_last_save_time: 1710364800
aof_current_size: 1048576
```

---

## Integração com Serviços BorgStack

### n8n

```bash
# Connection string (database 0)
QUEUE_BULL_REDIS_DB=0
QUEUE_BULL_REDIS_HOST=redis
QUEUE_BULL_REDIS_PORT=6379
QUEUE_BULL_REDIS_PASSWORD=senha_redis
```

**Uso**:
- Cache de workflows
- Queue de execuções (Bull/BullMQ)
- Rate limiting

**Chaves típicas**:
```bash
# Ver chaves do n8n
docker compose exec redis redis-cli -a senha -n 0 KEYS bull:*
docker compose exec redis redis-cli -a senha -n 0 KEYS cache:*
```

### Chatwoot

```bash
# Connection string (database 1)
REDIS_URL=redis://:senha_redis@redis:6379/1
```

**Uso**:
- Sidekiq jobs (background workers)
- Cache de conversas
- Pub/Sub para real-time

**Chaves típicas**:
```bash
# Ver jobs Sidekiq
docker compose exec redis redis-cli -a senha -n 1 KEYS queue:*
docker compose exec redis redis-cli -a senha -n 1 LLEN queue:default

# Ver canais Pub/Sub
docker compose exec redis redis-cli -a senha -n 1 PUBSUB CHANNELS
```

### Directus

```bash
# Connection string (database 2)
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=senha_redis
CACHE_REDIS_DB=2
```

**Uso**:
- Cache de schemas
- Cache de permissões
- Sessões de usuários

**Chaves típicas**:
```bash
# Ver cache do Directus
docker compose exec redis redis-cli -a senha -n 2 KEYS cache:*
docker compose exec redis redis-cli -a senha -n 2 KEYS session:*
```

### Lowcoder

```bash
# Connection string (database 3)
REDIS_URL=redis://:senha_redis@redis:6379/3
```

**Uso**:
- Cache de aplicações
- Sessões
- Rate limiting

**Chaves típicas**:
```bash
# Ver cache do Lowcoder
docker compose exec redis redis-cli -a senha -n 3 KEYS *
```

---

## Solução de Problemas

### 1. Não Consigo Conectar ao Redis

**Sintomas**: Erro "Connection refused" ou "Authentication failed"

**Soluções**:

```bash
# Verificar container está rodando
docker compose ps redis

# Verificar logs
docker compose logs -f redis

# Verificar senha no .env
grep REDIS_PASSWORD .env

# Testar conexão
docker compose exec redis redis-cli PING
# Se erro "NOAUTH": senha necessária

# Testar com senha
docker compose exec redis redis-cli -a senha_redis PING
# Esperado: PONG

# Verificar porta (interna, não exposta)
docker inspect redis | grep "Ports"
# Esperado: 6379/tcp (sem mapeamento externo)

# Verificar rede
docker inspect redis | grep -A 5 "Networks"
# Esperado: borgstack_internal
```

### 2. Redis Está Lento

**Sintomas**: Comandos demorados, timeouts

**Soluções**:

```bash
# Ver comandos lentos
docker compose exec redis redis-cli -a senha SLOWLOG GET 10

# Ver latência
docker compose exec redis redis-cli -a senha --latency

# Ver uso de memória
docker compose exec redis redis-cli -a senha INFO memory | grep used_memory_human

# Se memória cheia: ver política de eviction
docker compose exec redis redis-cli -a senha CONFIG GET maxmemory-policy

# Ver hit rate do cache
docker compose exec redis redis-cli -a senha INFO stats | grep keyspace

# Se hit rate baixo (<80%): revisar TTLs e padrões de acesso

# Ver operações por segundo
docker compose exec redis redis-cli -a senha INFO stats | grep instantaneous_ops_per_sec

# Desabilitar AOF temporariamente (CUIDADO!)
docker compose exec redis redis-cli -a senha CONFIG SET appendonly no
# Testar performance
# Reabilitar:
docker compose exec redis redis-cli -a senha CONFIG SET appendonly yes
```

### 3. Memória Esgotada

**Sintomas**: Erro "OOM command not allowed"

**Soluções**:

```bash
# Ver uso de memória
docker compose exec redis redis-cli -a senha INFO memory

# Ver chaves grandes
docker compose exec redis redis-cli -a senha --bigkeys

# Limpar databases não utilizados
docker compose exec redis redis-cli -a senha -n 4 FLUSHDB

# Analisar chaves antigas sem TTL
docker compose exec redis redis-cli -a senha --scan --pattern "*" | while read key; do
    ttl=$(docker compose exec redis redis-cli -a senha TTL "$key")
    if [ "$ttl" -eq -1 ]; then
        echo "$key: SEM TTL"
    fi
done

# Configurar maxmemory maior (redis.conf)
# maxmemory 4gb

# Ou via comando (temporário)
docker compose exec redis redis-cli -a senha CONFIG SET maxmemory 4gb

# Configurar política de eviction
docker compose exec redis redis-cli -a senha CONFIG SET maxmemory-policy allkeys-lru

# Forçar garbage collection
docker compose exec redis redis-cli -a senha BGREWRITEAOF
```

### 4. AOF Corrompido

**Sintomas**: Redis não inicia, erro "Bad file format"

**Soluções**:

```bash
# Ver logs
docker compose logs redis | grep -i aof

# Reparar AOF
docker compose exec redis redis-check-aof --fix /data/appendonlydir/appendonly.aof.1.incr.aof

# Se não funcionar: desabilitar AOF temporariamente
# Editar redis.conf:
# appendonly no

# Reiniciar Redis
docker compose restart redis

# Restaurar do backup RDB
docker cp ./backups/dump_20250108.rdb redis:/data/dump.rdb
docker compose restart redis

# Reabilitar AOF
docker compose exec redis redis-cli -a senha CONFIG SET appendonly yes
docker compose exec redis redis-cli -a senha CONFIG REWRITE
```

### 5. Muitas Conexões

**Sintomas**: Erro "max number of clients reached"

**Soluções**:

```bash
# Ver conexões atuais
docker compose exec redis redis-cli -a senha CLIENT LIST | wc -l

# Ver limite
docker compose exec redis redis-cli -a senha CONFIG GET maxclients

# Identificar serviço com muitas conexões
docker compose exec redis redis-cli -a senha CLIENT LIST | awk '{print $2}' | sort | uniq -c | sort -rn

# Matar conexões ociosas (CUIDADO!)
docker compose exec redis redis-cli -a senha CLIENT LIST | grep "idle=[0-9][0-9][0-9][0-9]" | awk '{print $2}' | cut -d= -f2 | xargs -I {} docker compose exec redis redis-cli -a senha CLIENT KILL ID {}

# Aumentar limite (temporário)
docker compose exec redis redis-cli -a senha CONFIG SET maxclients 20000

# Permanente: editar redis.conf
# maxclients 20000
```

### 6. Dados Perdidos Após Restart

**Sintomas**: Chaves desaparecem após restart do container

**Soluções**:

```bash
# Verificar persistência habilitada
docker compose exec redis redis-cli -a senha CONFIG GET appendonly
# Esperado: appendonly yes

# Verificar último save
docker compose exec redis redis-cli -a senha LASTSAVE

# Verificar arquivos de persistência
docker compose exec redis ls -lh /data/

# Se AOF habilitado, verificar arquivo existe
docker compose exec redis ls -lh /data/appendonlydir/

# Se RDB habilitado, verificar dump.rdb
docker compose exec redis ls -lh /data/dump.rdb

# Habilitar AOF se não estiver
docker compose exec redis redis-cli -a senha CONFIG SET appendonly yes
docker compose exec redis redis-cli -a senha CONFIG REWRITE

# Forçar save manual
docker compose exec redis redis-cli -a senha BGSAVE
```

### 7. Container Reinicia Constantemente

**Sintomas**: `docker compose ps` mostra container em loop de restart

**Soluções**:

```bash
# Ver logs detalhados
docker compose logs --tail=100 redis

# Verificar permissões do volume
docker volume inspect borgstack_redis_data

# Verificar recursos do sistema
docker stats redis

# Se erro de configuração: validar redis.conf
docker compose exec redis redis-server --test-config

# Se arquivo corrompido: limpar dados (PERDE DADOS!)
# docker compose down redis
# docker volume rm borgstack_redis_data
# docker compose up -d redis
```

---

## Comandos Úteis

### Administração

```bash
# Ver configuração
docker compose exec redis redis-cli -a senha CONFIG GET *

# Alterar configuração (temporário)
docker compose exec redis redis-cli -a senha CONFIG SET maxmemory 2gb

# Salvar configuração no redis.conf
docker compose exec redis redis-cli -a senha CONFIG REWRITE

# Ver informações completas
docker compose exec redis redis-cli -a senha INFO ALL

# Resetar estatísticas
docker compose exec redis redis-cli -a senha CONFIG RESETSTAT

# Ver tempo de uptime
docker compose exec redis redis-cli -a senha INFO server | grep uptime
```

### Manutenção

```bash
# Compactar AOF
docker compose exec redis redis-cli -a senha BGREWRITEAOF

# Criar snapshot
docker compose exec redis redis-cli -a senha BGSAVE

# Verificar integridade do RDB
docker compose exec redis redis-check-rdb /data/dump.rdb

# Verificar integridade do AOF
docker compose exec redis redis-check-aof /data/appendonlydir/appendonly.aof.1.base.rdb

# Limpar database atual
docker compose exec redis redis-cli -a senha -n 0 FLUSHDB

# Limpar TODOS os databases (CUIDADO!)
docker compose exec redis redis-cli -a senha FLUSHALL
```

### Debug

```bash
# Monitorar comandos em tempo real
docker compose exec redis redis-cli -a senha MONITOR

# Ver latência em tempo real
docker compose exec redis redis-cli -a senha --latency

# Ver estatísticas em tempo real
docker compose exec redis redis-cli -a senha --stat

# Ver eventos de latência
docker compose exec redis redis-cli -a senha LATENCY DOCTOR

# Ver intrinsic latency
docker compose exec redis redis-cli -a senha --intrinsic-latency 100

# Analisar memória
docker compose exec redis redis-cli -a senha --bigkeys
docker compose exec redis redis-cli -a senha --memkeys
docker compose exec redis redis-cli -a senha MEMORY DOCTOR
```

---

## 8. Dicas e Melhores Práticas

### 8.1 Configuração Otimizada
Consulte [docs/02-configuracao.md](../02-configuracao.md) para variáveis de ambiente específicas deste serviço.

### 8.2 Performance
- Eviction policy: allkeys-lru (prod) ou volatile-lru
- Max memory: 25% RAM total do servidor
- Persistence: RDB para backup, AOF para durabilidade

### 8.3 Segurança
- requirepass com senha forte
- Desabilitar comandos perigosos: FLUSHALL, FLUSHDB
- Bind apenas rede interna

### 8.4 Monitoramento
- Uso de memória
- Hit rate (target: > 90%)
- Conexões ativas

### 8.5 Casos de Uso
Ver workflows de exemplo em [docs/09-workflows-exemplo.md](../09-workflows-exemplo.md)

---

## Recursos Adicionais

### Documentação Oficial
- [Redis Documentation](https://redis.io/docs/)
- [Redis Commands](https://redis.io/commands/)
- [Redis Persistence](https://redis.io/docs/management/persistence/)

### Ferramentas
- [RedisInsight](https://redis.com/redis-enterprise/redis-insight/) - GUI oficial
- [redis-cli](https://redis.io/docs/ui/cli/) - Cliente command-line
- [Redis Exporter](https://github.com/oliver006/redis_exporter) - Prometheus exporter

---

## Próximos Passos

Depois de configurar o Redis, você pode:

1. **Configurar Serviços**: Ver guias em [docs/03-services/](./README.md)
2. **Configurar Backups Automatizados**: Ver [docs/06-manutencao.md](../06-manutencao.md)
3. **Otimizar Performance**: Ver [docs/08-desempenho.md](../08-desempenho.md)
4. **Monitorar Sistema**: Configurar alertas para uso de memória

---

## Referências Técnicas

### Variáveis de Ambiente

```bash
# Senha
REDIS_PASSWORD=senha_super_segura_redis

# URLs de conexão
N8N_REDIS_URL=redis://:senha@redis:6379/0
CHATWOOT_REDIS_URL=redis://:senha@redis:6379/1
DIRECTUS_REDIS_URL=redis://:senha@redis:6379/2
LOWCODER_REDIS_URL=redis://:senha@redis:6379/3
```

### Portas

| Serviço | Porta Interna | Porta Externa | Descrição |
|---------|---------------|---------------|-----------|
| Redis | 6379 | - | Não exposta (rede interna apenas) |

### Volumes

```yaml
volumes:
  borgstack_redis_data:  # Dados do Redis (/data)
```

### Configurações Recomendadas

| Parâmetro | Valor Recomendado | Descrição |
|-----------|-------------------|-----------|
| maxmemory | 2gb | Limite de memória |
| maxmemory-policy | allkeys-lru | Política de eviction |
| appendonly | yes | Habilitar AOF |
| appendfsync | everysec | Fsync a cada segundo |
| save | 900 1 300 10 60 10000 | Snapshots RDB |

---

**Última atualização**: 2025-10-08
**Versão do BorgStack**: 1.0
**Versão do Redis**: 8.2
