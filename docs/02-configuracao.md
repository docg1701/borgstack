# Guia de Configuração do BorgStack

Guia completo para configurar todos os componentes do BorgStack após a instalação.

---

## Índice

1. [Visão Geral do Arquivo .env](#visão-geral-do-arquivo-env)
2. [Configuração de Domínios](#configuração-de-domínios)
3. [Configuração de Bancos de Dados](#configuração-de-bancos-de-dados)
4. [Configuração de Redes Docker](#configuração-de-redes-docker)
5. [Configuração de Volumes](#configuração-de-volumes)
6. [Configurações Avançadas](#configurações-avançadas)

---

## Visão Geral do Arquivo .env

O arquivo `.env` é o coração da configuração do BorgStack. Ele contém todas as credenciais, senhas e configurações necessárias para executar o sistema.

### Estrutura do Arquivo .env

O arquivo `.env` está organizado em seções lógicas:

```text
.env
├── PostgreSQL Database (5 senhas)
├── MongoDB Database (2 senhas)
├── Redis Cache (1 senha)
├── Caddy Reverse Proxy (domínio, email, CORS)
└── Serviços Individuais (n8n, Chatwoot, Evolution API, etc.)
```text

### Segurança do Arquivo .env

**⚠️ CRÍTICO - Práticas de Segurança Obrigatórias:**

```bash
# 1. Definir permissões restritas (OBRIGATÓRIO)
chmod 600 .env

# 2. Verificar permissões
ls -la .env
# Deve mostrar: -rw------- (somente proprietário pode ler/escrever)

# 3. Verificar que está no .gitignore
cat .gitignore | grep .env
# Deve mostrar: .env

# 4. NUNCA commitar ao Git
# O .env já está listado no .gitignore do projeto
```text

**Práticas Recomendadas:**

1. **Backup Seguro:**
   ```bash
   # Copie o .env para local seguro FORA do servidor
   # Use um gerenciador de senhas (1Password, Bitwarden, LastPass)
   # OU armazenamento criptografado (VeraCrypt, BitLocker)
   ```

2. **Rotação de Credenciais:**
   - Troque todas as senhas a cada 90 dias (recomendado para produção)
   - Após trocar senhas no `.env`, reinicie os serviços afetados
   - Documente quando cada senha foi alterada

3. **Geração de Senhas Fortes:**
   ```bash
   # Gerar senha de 32 caracteres
   openssl rand -base64 32 | tr -d "=+/" | cut -c1-32

   # Gerar múltiplas senhas de uma vez
   for i in {1..10}; do openssl rand -base64 32 | tr -d "=+/" | cut -c1-32; done
   ```

### Variáveis Obrigatórias vs. Opcionais

| Categoria | Variáveis | Status | Impacto se Omitido |
|-----------|-----------|--------|-------------------|
| **PostgreSQL** | `POSTGRES_PASSWORD`, `N8N_DB_PASSWORD`, `CHATWOOT_DB_PASSWORD`, `DIRECTUS_DB_PASSWORD`, `EVOLUTION_DB_PASSWORD` | ✅ **Obrigatório** | Serviços não iniciam |
| **MongoDB** | `MONGODB_ROOT_PASSWORD`, `LOWCODER_DB_PASSWORD` | ✅ **Obrigatório** | Lowcoder não inicia |
| **Redis** | `REDIS_PASSWORD` | ✅ **Obrigatório** | Todos os serviços falham |
| **Domínios** | `DOMAIN`, `EMAIL` | ✅ **Obrigatório** | SSL não funciona |
| **n8n** | `N8N_ENCRYPTION_KEY`, `N8N_BASIC_AUTH_PASSWORD` | ✅ **Obrigatório** | Credenciais não salvas |
| **Chatwoot** | `CHATWOOT_SECRET_KEY_BASE` | ✅ **Obrigatório** | Sessões não funcionam |
| **CORS** | `CORS_ALLOWED_ORIGINS` | 🟡 Opcional | Usa padrão `*` (todos) |

### Geração Automática vs. Manual

**Automático (via bootstrap.sh):**
- ✅ Todas as senhas de bancos de dados (10 senhas)
- ✅ Chaves de encriptação (n8n, Chatwoot, Lowcoder)
- ✅ Permissões corretas do arquivo (chmod 600)
- ❌ Domínios (você deve configurar manualmente)

**Manual (quando você copia .env.example):**
- ❌ Todas as senhas (você deve gerar)
- ❌ Chaves de encriptação (você deve gerar)
- ❌ Domínios (você deve configurar)
- ❌ Permissões do arquivo (você deve configurar)

### Exemplo de .env Mínimo Funcional

```bash
# PostgreSQL
POSTGRES_PASSWORD=xK9mP2vL7nR4wQ8sT3fH6jD1gC5yE0zA
N8N_DB_PASSWORD=aB2cD4eF6gH8iJ0kL1mN3oP5qR7sT9uV
CHATWOOT_DB_PASSWORD=wX1yZ3aB5cD7eF9gH2iJ4kL6mN8oP0qR
DIRECTUS_DB_PASSWORD=sT1uV3wX5yZ7aB9cD2eF4gH6iJ8kL0mN
EVOLUTION_DB_PASSWORD=oP1qR3sT5uV7wX9yZ2aB4cD6eF8gH0iJ

# MongoDB
MONGODB_ROOT_PASSWORD=kL1mN3oP5qR7sT9uV2wX4yZ6aB8cD0eF
LOWCODER_DB_PASSWORD=gH1iJ3kL5mN7oP9qR2sT4uV6wX8yZ0aB

# Redis
REDIS_PASSWORD=cD1eF3gH5iJ7kL9mN2oP4qR6sT8uV0wX

# Caddy
DOMAIN=mycompany.com.br
EMAIL=admin@mycompany.com.br
CORS_ALLOWED_ORIGINS=*

# n8n
N8N_ENCRYPTION_KEY=yZ1aB3cD5eF7gH9iJ2kL4mN6oP8qR0sT
N8N_BASIC_AUTH_PASSWORD=uV1wX3yZ5aB7cD9eF2gH4iJ6kL8mN0oP

# Chatwoot
CHATWOOT_SECRET_KEY_BASE=qR1sT3uV5wX7yZ9aB2cD4eF6gH8iJ0kL

# Lowcoder
LOWCODER_DB_ENCRYPTION_PASSWORD=mN1oP3qR5sT7uV9wX2yZ4aB6cD8eF0gH
LOWCODER_DB_ENCRYPTION_SALT=iJ1kL3mN5oP7qR9sT2uV4wX6yZ8aB0cD
```text

---

## Configuração de Domínios

O BorgStack usa um modelo de **subdomínios** para organizar os serviços. Todos os serviços são acessados via HTTPS com certificados SSL automáticos.

### Modelo de Domínios

**Estrutura recomendada: `servico.seudominio.com.br`**

```text
Domínio Base: mycompany.com.br

Subdomínios dos Serviços:
├── n8n.mycompany.com.br        → Automação de workflows
├── chatwoot.mycompany.com.br   → Atendimento ao cliente
├── evolution.mycompany.com.br  → API WhatsApp Business
├── lowcoder.mycompany.com.br   → Construtor de apps
├── directus.mycompany.com.br   → CMS headless
├── fileflows.mycompany.com.br  → Processamento de mídia
├── duplicati.mycompany.com.br  → Sistema de backup
└── seaweedfs.mycompany.com.br  → Armazenamento S3
```text

### Configurar Variável DOMAIN

No arquivo `.env`:

```bash
# Seu domínio raiz (sem 'www', sem 'http://', sem subdomínio)
DOMAIN=mycompany.com.br

# Email para notificações do Let's Encrypt
EMAIL=admin@mycompany.com.br
```text

**⚠️ IMPORTANTE:** A variável `DOMAIN` é usada em TODOS os serviços. Não inclua `http://`, `https://` ou qualquer subdomínio aqui.

### Configurar DNS (Registros A)

Você precisa criar **8 registros DNS tipo A** no seu provedor de DNS (Cloudflare, GoDaddy, Route 53, Registro.br, etc.).

**Passos no Painel DNS:**

1. Acesse o painel do seu provedor DNS
2. Vá para gerenciamento de registros DNS
3. Crie 8 registros tipo A:

| Tipo | Nome/Host | Valor/Destino | TTL |
|------|-----------|---------------|-----|
| A | `n8n` | `SEU_IP_SERVIDOR` | 300 |
| A | `chatwoot` | `SEU_IP_SERVIDOR` | 300 |
| A | `evolution` | `SEU_IP_SERVIDOR` | 300 |
| A | `lowcoder` | `SEU_IP_SERVIDOR` | 300 |
| A | `directus` | `SEU_IP_SERVIDOR` | 300 |
| A | `fileflows` | `SEU_IP_SERVIDOR` | 300 |
| A | `duplicati` | `SEU_IP_SERVIDOR` | 300 |
| A | `seaweedfs` | `SEU_IP_SERVIDOR` | 300 |

**Exemplo prático (Cloudflare):**

```text
Tipo: A
Nome: n8n
Conteúdo: 198.51.100.42
Proxy: Desabilitado (nuvem cinza, não laranja)
TTL: 5 minutos (300 segundos)
```text

**💡 Dica:** Use TTL 300 (5 minutos) durante a configuração inicial para mudanças rápidas. Após tudo funcionar, aumente para 3600 (1 hora) para melhor cache DNS.

### Verificar Propagação DNS

Aguarde 5-15 minutos (até 24h em casos raros) e verifique:

```bash
# Verificar um domínio de cada vez
dig n8n.mycompany.com.br

# Deve retornar seu IP na seção ANSWER:
# ;; ANSWER SECTION:
# n8n.mycompany.com.br. 300 IN A 198.51.100.42
```text

**Verificar todos de uma vez:**
```bash
for service in n8n chatwoot evolution lowcoder directus fileflows duplicati seaweedfs; do
  echo "=== $service.mycompany.com.br ==="
  dig +short $service.mycompany.com.br
  echo ""
done
```text

**Ferramentas online para verificação global:**
- https://dnschecker.org/ (verifica propagação em múltiplos países)
- https://www.whatsmydns.net/ (verifica em múltiplos servidores DNS)

### Certificados SSL Automáticos

**Como funciona:**

1. **Você acessa** `https://n8n.mycompany.com.br` pela primeira vez
2. **Caddy detecta** que não há certificado para este domínio
3. **Let's Encrypt** recebe requisição ACME HTTP-01 challenge
4. **Let's Encrypt** acessa `http://n8n.mycompany.com.br/.well-known/acme-challenge/TOKEN`
5. **Caddy responde** com o token de validação (porta 80 deve estar aberta!)
6. **Let's Encrypt** emite certificado SSL válido por 90 dias
7. **Caddy instala** o certificado e configura HTTPS
8. **Caddy renova** automaticamente 30 dias antes da expiração

**Tempo estimado:** 30-60 segundos por domínio no primeiro acesso.

**Requisitos para SSL funcionar:**

```bash
# 1. DNS configurado e propagado
dig n8n.mycompany.com.br
# Deve retornar seu IP público

# 2. Portas 80 e 443 abertas
sudo ufw status | grep -E "80|443"
# Deve mostrar:
# 80/tcp         ALLOW       Anywhere
# 443/tcp        ALLOW       Anywhere

# 3. Caddy rodando e saudável
docker compose ps caddy
# Deve mostrar: Up X minutes (healthy)
```text

**Verificar certificado SSL:**

```bash
# Verificar via navegador
# Clicar no cadeado na barra de endereço → Ver certificado
# Emissor: Let's Encrypt
# Válido até: [data 90 dias no futuro]

# Verificar via comando
openssl s_client -connect n8n.mycompany.com.br:443 -servername n8n.mycompany.com.br < /dev/null 2>&1 | grep -A 2 "Verify return code"
# Deve mostrar: Verify return code: 0 (ok)
```text

### Solução de Problemas DNS/SSL

**Problema: DNS não propaga**

```bash
# Verificar configuração no provedor DNS
# Certifique-se que:
# - Tipo é "A" (não CNAME, não AAAA)
# - Nome é correto ("n8n", não "n8n.mycompany.com.br")
# - Valor é o IP público do servidor (não IP privado 192.168.x.x ou 10.x.x.x)
# - Proxy está DESABILITADO (se Cloudflare)
```text

**Problema: SSL não gera**

```bash
# Ver logs do Caddy
docker compose logs caddy --tail 100 | grep acme

# Erros comuns:
# - "acme: error: 403": DNS não aponta para seu servidor
# - "timeout": Porta 80 bloqueada
# - "too many certificates": Limite Let's Encrypt atingido (5 por semana)
```text

### Domínios Alternativos

**Usar domínios diferentes para cada serviço:**

```bash
# No .env, você pode sobrescrever domínios individuais
DOMAIN=mycompany.com.br
N8N_HOST=workflows.mycompany.net
CHATWOOT_HOST=suporte.mycompany.com
EVOLUTION_HOST=whatsapp-api.mycompany.io
# ... etc
```text

**⚠️ ATENÇÃO:** Se usar domínios diferentes, você precisa configurar DNS A record para CADA domínio separadamente.

---

## Configuração de Bancos de Dados

O BorgStack usa três sistemas de banco de dados:
- **PostgreSQL** (banco relacional compartilhado)
- **MongoDB** (NoSQL dedicado ao Lowcoder)
- **Redis** (cache e fila compartilhados)

### PostgreSQL: Banco de Dados Compartilhado

**Visão geral:**
- **Imagem:** `pgvector/pgvector:pg18` (PostgreSQL 18.0 + extensão pgvector)
- **Rede:** `borgstack_internal` (isolado, sem exposição de portas)
- **Volume:** `borgstack_postgresql_data`
- **Portas:** Nenhuma exposta ao host (segurança)

**Organização de Bancos de Dados:**

O PostgreSQL hospeda **4 bancos de dados isolados**:

| Banco de Dados | Usuário | Senha (.env) | Usado Por | Finalidade |
|----------------|---------|--------------|-----------|------------|
| `n8n_db` | `n8n_user` | `N8N_DB_PASSWORD` | n8n | Workflows, credenciais, execuções |
| `chatwoot_db` | `chatwoot_user` | `CHATWOOT_DB_PASSWORD` | Chatwoot | Conversas, contatos, mensagens |
| `directus_db` | `directus_user` | `DIRECTUS_DB_PASSWORD` | Directus | Coleções CMS, arquivos metadata |
| `evolution_db` | `evolution_user` | `EVOLUTION_DB_PASSWORD` | Evolution API | Instâncias WhatsApp, mensagens |

**Diagrama de Isolamento:**

```text
┌─────────────────────────────────────────┐
│     PostgreSQL Container (pg18)         │
│  ┌────────────┐  ┌─────────────────┐   │
│  │  postgres  │  │ init-databases  │   │
│  │ (superuser)│  │   .sh script    │   │
│  └────────────┘  └─────────────────┘   │
│                                          │
│  ┌─────────────────────────────────┐   │
│  │ Database: n8n_db                │   │
│  │ Owner: n8n_user                 │   │
│  │ Password: N8N_DB_PASSWORD       │   │
│  │ Extensions: pgvector, uuid-ossp │   │
│  └─────────────────────────────────┘   │
│                                          │
│  ┌─────────────────────────────────┐   │
│  │ Database: chatwoot_db           │   │
│  │ Owner: chatwoot_user            │   │
│  └─────────────────────────────────┘   │
│                                          │
│  ┌─────────────────────────────────┐   │
│  │ Database: directus_db           │   │
│  │ Owner: directus_user            │   │
│  │ Extensions: pgvector            │   │
│  └─────────────────────────────────┘   │
│                                          │
│  ┌─────────────────────────────────┐   │
│  │ Database: evolution_db          │   │
│  │ Owner: evolution_user           │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```text

**Strings de Conexão:**

Os serviços se conectam ao PostgreSQL usando Docker DNS:

```bash
# n8n
postgres://n8n_user:${N8N_DB_PASSWORD}@postgresql:5432/n8n_db

# Chatwoot
Host: postgresql
Port: 5432
Database: chatwoot_db
Username: chatwoot_user
Password: ${CHATWOOT_DB_PASSWORD}

# Directus
DB_CLIENT=pg
DB_HOST=postgresql
DB_PORT=5432
DB_DATABASE=directus_db
DB_USER=directus_user
DB_PASSWORD=${DIRECTUS_DB_PASSWORD}

# Evolution API
DATABASE_CONNECTION_URI=postgres://evolution_user:${EVOLUTION_DB_PASSWORD}@postgresql:5432/evolution_db
```text

**Acessar PostgreSQL via CLI:**

```bash
# Conectar como superuser postgres
docker compose exec postgresql psql -U postgres

# Conectar a banco específico
docker compose exec postgresql psql -U postgres -d n8n_db

# Listar todos os bancos
docker compose exec postgresql psql -U postgres -c "\l"

# Listar todos os usuários
docker compose exec postgresql psql -U postgres -c "\du"

# Verificar tamanho dos bancos
docker compose exec postgresql psql -U postgres -c "SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) FROM pg_database ORDER BY pg_database_size(pg_database.datname) DESC;"
```text

**Tuning de Performance:**

O PostgreSQL está otimizado para servidor com **36GB RAM**:

```conf
# config/postgresql/postgresql.conf
shared_buffers = 8GB              # 25% da RAM
effective_cache_size = 24GB       # 66% da RAM
maintenance_work_mem = 2GB
work_mem = 20MB
max_connections = 200
random_page_cost = 1.1            # Otimizado para SSD
```text

**Alterar configuração de performance:**

```bash
# 1. Editar arquivo de configuração
nano config/postgresql/postgresql.conf

# 2. Reiniciar PostgreSQL
docker compose restart postgresql

# 3. Verificar configuração aplicada
docker compose exec postgresql psql -U postgres -c "SHOW shared_buffers;"
```text

### MongoDB: Banco NoSQL para Lowcoder

**Visão geral:**
- **Imagem:** `mongo:7.0`
- **Rede:** `borgstack_internal`
- **Volume:** `borgstack_mongodb_data`
- **Uso:** Exclusivo do Lowcoder (metadata de aplicações)

**Organização:**

```text
MongoDB Container (7.0)
├── Database: admin (sistema)
│   └── User: admin (root) → MONGODB_ROOT_PASSWORD
│
└── Database: lowcoder
    └── User: lowcoder_user → LOWCODER_DB_PASSWORD
        Permissions: readWrite + dbAdmin (lowcoder DB apenas)
```text

**Por que MongoDB separado?**

- Lowcoder requer NoSQL para flexibilidade de schemas
- Isolamento previne conflitos com PostgreSQL
- MongoDB otimizado para documentos JSON complexos

**String de Conexão:**

```bash
# Lowcoder usa esta URI
LOWCODER_MONGODB_URL=mongodb://lowcoder_user:${LOWCODER_DB_PASSWORD}@mongodb:27017/lowcoder?authSource=lowcoder
```text

**Acessar MongoDB via CLI:**

```bash
# Conectar como admin
docker compose exec mongodb mongosh -u admin -p ${MONGODB_ROOT_PASSWORD} --authenticationDatabase admin

# Conectar ao banco lowcoder
docker compose exec mongodb mongosh -u lowcoder_user -p ${LOWCODER_DB_PASSWORD} --authenticationDatabase lowcoder lowcoder

# Listar bancos de dados
docker compose exec mongodb mongosh -u admin -p ${MONGODB_ROOT_PASSWORD} --authenticationDatabase admin --eval "show dbs"

# Ver estatísticas do banco lowcoder
docker compose exec mongodb mongosh -u admin -p ${MONGODB_ROOT_PASSWORD} --authenticationDatabase admin --eval "db.getSiblingDB('lowcoder').stats()"
```text

### Redis: Cache e Fila Compartilhados

**Visão geral:**
- **Imagem:** `redis:8.2-alpine`
- **Rede:** `borgstack_internal`
- **Volume:** `borgstack_redis_data`
- **Memória:** 8GB (configurável)

**Uso por Serviço:**

| Serviço | Uso | Banco Redis | Finalidade |
|---------|-----|-------------|------------|
| **n8n** | Queue | DB 0 | Bull queue para execução de workflows |
| **Chatwoot** | Queue + Cache | DB 0 | Sidekiq jobs + cache de sessões |
| **Lowcoder** | Session | DB 0 | Armazenamento de sessões |
| **Directus** | Cache | DB 0 | Schema cache + collection cache |

**Por que todos usam DB 0?**

- Simplifica configuração (um único banco Redis)
- Namespacing via prefixos de chave previne conflitos
- Exemplo: `n8n:bull:queue`, `chatwoot:session:123`, `directus:cache:schema`

**Strings de Conexão:**

```bash
# n8n (formato específico Bull Queue)
QUEUE_BULL_REDIS_HOST=redis
QUEUE_BULL_REDIS_PORT=6379
QUEUE_BULL_REDIS_PASSWORD=${REDIS_PASSWORD}

# Chatwoot
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=${REDIS_PASSWORD}

# Lowcoder
LOWCODER_REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379

# Directus
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=${REDIS_PASSWORD}
```text

**Acessar Redis via CLI:**

```bash
# Conectar ao Redis
docker compose exec redis redis-cli -a ${REDIS_PASSWORD}

# Comando dentro do redis-cli:
redis> INFO stats          # Estatísticas de uso
redis> INFO memory         # Uso de memória
redis> DBSIZE              # Número de chaves
redis> KEYS n8n:*          # Listar chaves do n8n (cuidado em produção!)
redis> MONITOR             # Ver comandos em tempo real (debug)
```text

**Monitoramento de Performance:**

```bash
# Taxa de acerto de cache (hit rate)
docker compose exec redis redis-cli -a ${REDIS_PASSWORD} INFO stats | grep -E "keyspace_hits|keyspace_misses"

# Uso de memória
docker compose exec redis redis-cli -a ${REDIS_PASSWORD} INFO memory | grep used_memory_human

# Operações por segundo
docker compose exec redis redis-cli -a ${REDIS_PASSWORD} INFO stats | grep instantaneous_ops_per_sec

# Clientes conectados
docker compose exec redis redis-cli -a ${REDIS_PASSWORD} INFO clients | grep connected_clients
```text

**Benchmark de Performance:**

```bash
# Executar benchmark (100k operações GET/SET)
docker compose exec redis redis-benchmark -h localhost -p 6379 -a ${REDIS_PASSWORD} -t get,set -n 100000 -q

# Saída esperada:
# SET: 65000.00 requests per second
# GET: 70000.00 requests per second
```text

---

## Configuração de Redes Docker

O BorgStack usa **2 redes Docker isoladas** para segurança e organização.

### Arquitetura de Redes

```mermaid
graph TB
    subgraph "Internet"
        User[👤 Usuário]
    end

    subgraph "borgstack_external (Bridge)"
        Caddy[🔒 Caddy<br/>Reverse Proxy<br/>Portas: 80, 443]
    end

    subgraph "borgstack_internal (Bridge, ISOLADA)"
        N8N[n8n<br/>:5678]
        Chatwoot[Chatwoot<br/>:3000]
        Evolution[Evolution API<br/>:8080]
        Lowcoder[Lowcoder<br/>:3000]
        Directus[Directus<br/>:8055]
        FileFlows[FileFlows<br/>:5000]
        Duplicati[Duplicati<br/>:8200]
        SeaweedFS[SeaweedFS<br/>:8888]

        PG[(PostgreSQL<br/>:5432)]
        Mongo[(MongoDB<br/>:27017)]
        RedisDB[(Redis<br/>:6379)]
    end

    User -->|HTTPS| Caddy
    Caddy -->|HTTP| N8N
    Caddy -->|HTTP| Chatwoot
    Caddy -->|HTTP| Evolution
    Caddy -->|HTTP| Lowcoder
    Caddy -->|HTTP| Directus
    Caddy -->|HTTP| FileFlows
    Caddy -->|HTTP| Duplicati
    Caddy -->|HTTP| SeaweedFS

    N8N --> PG
    N8N --> RedisDB
    Chatwoot --> PG
    Chatwoot --> RedisDB
    Evolution --> PG
    Lowcoder --> Mongo
    Lowcoder --> RedisDB
    Directus --> PG
    Directus --> RedisDB
```text

### Rede 1: borgstack_external

**Propósito:** Expor serviços ao mundo externo via Caddy

**Configuração:**
```yaml
networks:
  external:
    driver: bridge
    name: borgstack_external
```text

**Serviços Conectados:**
- ✅ Caddy (único serviço com portas 80/443 expostas ao host)
- ✅ Todos os serviços web (n8n, Chatwoot, etc.) para receber tráfego do Caddy

**Características:**
- **Driver:** Bridge (padrão Docker)
- **Isolamento:** NÃO (pode comunicar com internet via Caddy)
- **Exposição de Portas:** SIM (Caddy expõe 80/443 ao host)

### Rede 2: borgstack_internal

**Propósito:** Comunicação interna entre serviços e bancos de dados

**Configuração:**
```yaml
networks:
  internal:
    driver: bridge
    name: borgstack_internal
    internal: false  # Permite saída para internet (para downloads, APIs externas)
```text

**Serviços Conectados:**
- ✅ PostgreSQL, MongoDB, Redis (bancos de dados)
- ✅ Todos os serviços de aplicação (n8n, Chatwoot, etc.)
- ❌ Caddy NÃO está nesta rede (só em external)

**Características:**
- **Driver:** Bridge
- **Isolamento:** Parcial (pode sair para internet, mas sem portas expostas)
- **Exposição de Portas:** NÃO (nenhum serviço expõe portas ao host)

### Matriz de Conectividade

| Serviço | borgstack_external | borgstack_internal | Portas Expostas ao Host |
|---------|-------------------|-------------------|------------------------|
| **Caddy** | ✅ | ❌ | 80, 443 |
| **n8n** | ✅ | ✅ | ❌ |
| **Chatwoot** | ✅ | ✅ | ❌ |
| **Evolution API** | ✅ | ✅ | ❌ |
| **Lowcoder** | ✅ | ✅ | ❌ |
| **Directus** | ✅ | ✅ | ❌ |
| **FileFlows** | ✅ | ✅ | ❌ |
| **Duplicati** | ✅ | ✅ | ❌ |
| **SeaweedFS** | ✅ | ✅ | ❌ |
| **PostgreSQL** | ❌ | ✅ | ❌ |
| **MongoDB** | ❌ | ✅ | ❌ |
| **Redis** | ❌ | ✅ | ❌ |

### Segurança de Redes

**Princípios Implementados:**

1. **Defense in Depth:**
   - Bancos de dados SEM acesso externo (apenas `borgstack_internal`)
   - Aplicações SEM portas expostas ao host (apenas via Caddy)
   - Caddy como único ponto de entrada (SSL termination)

2. **Least Privilege:**
   - Cada serviço só acessa redes necessárias
   - Bancos de dados isolados em rede interna

3. **Zero Trust:**
   - Nenhum serviço confia em outro por padrão
   - Autenticação via senhas/tokens mesmo em rede interna

**Verificar Configuração de Redes:**

```bash
# Listar redes
docker network ls | grep borgstack

# Inspecionar rede external
docker network inspect borgstack_external

# Ver quais containers estão em cada rede
docker network inspect borgstack_external --format '{{range .Containers}}{{.Name}} {{end}}'
docker network inspect borgstack_internal --format '{{range .Containers}}{{.Name}} {{end}}'

# Verificar que PostgreSQL NÃO está em external
docker network inspect borgstack_external --format '{{range .Containers}}{{.Name}} {{end}}' | grep -q postgresql && echo "❌ ERRO: PostgreSQL em external!" || echo "✅ OK: PostgreSQL isolado"
```text

### Comunicação Entre Serviços

Os serviços usam **Docker DNS** para se comunicar:

```bash
# n8n se conecta a PostgreSQL
Host: postgresql  (não localhost, não IP)
Port: 5432

# Chatwoot se conecta a Redis
Host: redis
Port: 6379

# Directus se conecta a SeaweedFS Filer API
URL: http://seaweedfs:8888/
```text

**⚠️ IMPORTANTE:** Use sempre nomes de serviços do docker-compose.yml, NUNCA IPs!

**Testar conectividade interna:**

```bash
# De dentro do container n8n, pingar PostgreSQL
docker compose exec n8n ping -c 3 postgresql

# De dentro do Chatwoot, testar conexão Redis
docker compose exec chatwoot sh -c 'nc -zv redis 6379'

# De dentro do Directus, testar SeaweedFS
docker compose exec directus wget -qO- http://seaweedfs:8888/
```text

---

## Configuração de Volumes

O BorgStack usa **volumes Docker nomeados** para persistência de dados. Todos seguem a convenção de nomenclatura `borgstack_<servico>_<finalidade>`.

### Lista Completa de Volumes

| Volume | Tamanho Aprox. | Crescimento | Backup Crítico? | Usado Por |
|--------|---------------|-------------|-----------------|-----------|
| `borgstack_postgresql_data` | 5-50 GB | Alto | ✅ **SIM** | PostgreSQL (4 databases) |
| `borgstack_mongodb_data` | 1-10 GB | Médio | ✅ **SIM** | MongoDB (Lowcoder) |
| `borgstack_redis_data` | 0.5-2 GB | Baixo | 🟡 Opcional | Redis (cache/queue) |
| `borgstack_n8n_data` | 0.5-5 GB | Médio | ✅ **SIM** | n8n (workflows locais) |
| `borgstack_chatwoot_storage` | 1-20 GB | Alto | ✅ **SIM** | Chatwoot (uploads) |
| `borgstack_directus_uploads` | 5-100 GB | Alto | ✅ **SIM** | Directus (media files) |
| `borgstack_fileflows_data` | 10-500 GB | Muito Alto | 🟡 Opcional | FileFlows (processamento) |
| `borgstack_duplicati_config` | <100 MB | Muito Baixo | ✅ **SIM** | Duplicati (config) |
| `borgstack_duplicati_data` | Variável | Variável | ✅ **SIM** | Duplicati (backups locais) |
| `borgstack_seaweedfs_data` | 10-1000 GB | Muito Alto | ✅ **SIM** | SeaweedFS (object storage) |
| `borgstack_lowcoder_data` | 0.5-5 GB | Baixo | ✅ **SIM** | Lowcoder (apps) |
| `borgstack_caddy_data` | <500 MB | Muito Baixo | 🟡 Opcional | Caddy (SSL certs) |
| `borgstack_caddy_config` | <10 MB | Muito Baixo | ❌ Não | Caddy (auto-config) |

**Total estimado (instalação nova):** ~35-50 GB
**Total estimado (produção 1 ano):** 100-2000 GB (depende de uso de mídia/storage)

### Localização dos Volumes no Host

```bash
# Docker armazena volumes em:
/var/lib/docker/volumes/

# Listar todos os volumes do BorgStack
docker volume ls | grep borgstack

# Ver detalhes de um volume
docker volume inspect borgstack_postgresql_data

# Ver caminho físico no host
docker volume inspect borgstack_postgresql_data --format '{{.Mountpoint}}'
# Saída: /var/lib/docker/volumes/borgstack_postgresql_data/_data
```text

**⚠️ ATENÇÃO:** NÃO edite arquivos diretamente em `/var/lib/docker/volumes/`. Use sempre comandos Docker ou acesse via container.

### Backup de Volumes

**Método 1: Via Duplicati (Recomendado)**

O Duplicati já está configurado para fazer backup automático de todos os volumes críticos.

```bash
# Ver configuração de backup
# Acesse: https://duplicati.mycompany.com.br
# Login com credenciais configuradas durante instalação
```text

Ver `docs/03-services/duplicati.md` para guia completo.

**Método 2: Backup Manual de Volume Específico**

```bash
# Parar o serviço (para consistência)
docker compose stop postgresql

# Criar backup do volume
docker run --rm \
  -v borgstack_postgresql_data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/postgresql_backup_$(date +%Y%m%d).tar.gz -C /data .

# Reiniciar serviço
docker compose start postgresql
```text

**Método 3: Backup do Banco via pg_dump (PostgreSQL)**

```bash
# Backup de banco específico (SEM parar serviço)
docker compose exec postgresql pg_dump -U postgres n8n_db > n8n_backup_$(date +%Y%m%d).sql

# Backup de TODOS os bancos
docker compose exec postgresql pg_dumpall -U postgres > all_databases_$(date +%Y%m%d).sql
```text

### Restauração de Volumes

**Restaurar volume do backup tar.gz:**

```bash
# Parar serviço
docker compose stop postgresql

# Restaurar backup
docker run --rm \
  -v borgstack_postgresql_data:/data \
  -v $(pwd):/backup \
  alpine sh -c "rm -rf /data/* && tar xzf /backup/postgresql_backup_20251008.tar.gz -C /data"

# Reiniciar serviço
docker compose start postgresql
```text

**Restaurar banco PostgreSQL do SQL:**

```bash
# Restaurar banco específico
docker compose exec -T postgresql psql -U postgres n8n_db < n8n_backup_20251008.sql

# Restaurar todos os bancos
docker compose exec -T postgresql psql -U postgres < all_databases_20251008.sql
```text

### Limpeza de Volumes

**⚠️ PERIGO - Ação Destrutiva!**

```bash
# Remover volume específico (PERDE TODOS OS DADOS!)
docker volume rm borgstack_redis_data

# Remover TODOS os volumes não utilizados (cuidado!)
docker volume prune

# Remover TODOS os volumes do BorgStack (RESET COMPLETO!)
docker compose down -v
# Isto remove TODOS os dados! Use apenas se quiser começar do zero.
```text

### Monitoramento de Uso de Disco

```bash
# Ver uso de disco de todos os volumes
docker system df -v | grep borgstack

# Ver tamanho de volume específico
du -sh /var/lib/docker/volumes/borgstack_postgresql_data/_data

# Ver top 10 volumes por tamanho
docker system df -v --format "table {{.Name}}\t{{.Size}}" | grep borgstack | sort -k 2 -h -r | head -10

# Alerta se disco > 80% cheio
df -h / | awk 'NR==2 {if (int($5) > 80) print "⚠️  ALERTA: Disco "$5" cheio!"}'
```text

---

## Configurações Avançadas

### Modificar Configurações de Serviço

Cada serviço tem arquivos de configuração em `config/<servico>/`:

```text
config/
├── postgresql/
│   ├── init-databases.sh    # Script de inicialização
│   ├── postgresql.conf      # Performance tuning
│   └── pg_hba.conf          # Autenticação
├── redis/
│   └── redis.conf           # Configuração Redis
├── caddy/
│   └── Caddyfile            # Rotas e SSL
├── n8n/
│   └── workflows/           # Workflows exemplo
└── duplicati/
    └── backup-config.json   # Jobs de backup
```text

**Alterar configuração:**

```bash
# 1. Editar arquivo
nano config/postgresql/postgresql.conf

# 2. Validar sintaxe (se aplicável)
docker compose config  # Valida docker-compose.yml

# 3. Reiniciar serviço específico
docker compose restart postgresql

# 4. Verificar logs para confirmar
docker compose logs postgresql --tail 50
```text

### Validar Configuração Docker Compose

```bash
# Ver configuração final (com variáveis .env substituídas)
docker compose config

# Salvar configuração renderizada
docker compose config > docker-compose-rendered.yml

# Validar sintaxe
docker compose config --quiet && echo "✅ Configuração válida" || echo "❌ Erro na configuração"
```text

### Sobrescrever Configurações (docker-compose.override.yml)

Para desenvolvimento ou customização local:

```bash
# Criar docker-compose.override.yml
nano docker-compose.override.yml
```text

Exemplo de override para expor porta PostgreSQL em dev:

```yaml
# docker-compose.override.yml (NÃO commitar ao Git!)
version: '3.8'

services:
  postgresql:
    ports:
      - "5432:5432"  # Expor PostgreSQL ao host (apenas dev!)

  redis:
    ports:
      - "6379:6379"  # Expor Redis ao host (apenas dev!)
```text

**⚠️ IMPORTANTE:** O `docker-compose.override.yml` é automaticamente carregado se existir. NUNCA use em produção!

### Limites de Recursos

Configurar limites de CPU e memória:

```yaml
# docker-compose.override.yml
services:
  postgresql:
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 16G
        reservations:
          cpus: '2'
          memory: 8G
```text

**Aplicar limites:**

```bash
docker compose up -d
```text

### Variáveis de Ambiente Adicionais

Algumas configurações avançadas via variáveis de ambiente:

**n8n:**
```bash
# .env
N8N_LOG_LEVEL=debug           # Logs detalhados
N8N_DIAGNOSTICS_ENABLED=false # Desabilitar telemetria
N8N_METRICS=true              # Habilitar métricas Prometheus
```text

**Chatwoot:**
```bash
# .env
RAILS_LOG_LEVEL=warn          # Reduzir verbosidade de logs
RAILS_MAX_THREADS=5           # Threads de processamento
```text

**Redis:**
```bash
# config/redis/redis.conf
maxmemory 8gb
maxmemory-policy allkeys-lru  # Política de eviction
save 900 1                    # Snapshot a cada 15min se 1+ key mudou
```text

### CORS (Cross-Origin Resource Sharing)

Configurar origens permitidas para APIs:

```bash
# .env
# Desenvolvimento (permite tudo)
CORS_ALLOWED_ORIGINS=*

# Produção (apenas domínios específicos)
CORS_ALLOWED_ORIGINS=https://app.mycompany.com.br,https://admin.mycompany.com.br
```text

Afeta:
- Evolution API (WhatsApp Business API)
- Directus (CMS API)

### Atualizar Versões de Imagens

**⚠️ SEMPRE faça backup antes de atualizar!**

```bash
# 1. Backup completo
./scripts/backup-now.sh  # Se tiver script
# OU
docker compose exec postgresql pg_dumpall -U postgres > backup_pre_update.sql

# 2. Editar docker-compose.yml
nano docker-compose.yml
# Mudar: image: n8nio/n8n:1.112.6
# Para:  image: n8nio/n8n:1.115.0

# 3. Baixar nova imagem
docker compose pull n8n

# 4. Recriar container com nova imagem
docker compose up -d n8n

# 5. Verificar logs
docker compose logs n8n --tail 100

# 6. Testar funcionamento
# Acessar https://n8n.mycompany.com.br
```text

### Recarregar Configuração Sem Downtime

**Caddy (recarregar Caddyfile):**

```bash
# Editar Caddyfile
nano config/caddy/Caddyfile

# Recarregar configuração SEM reiniciar
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile

# OU reiniciar (breve downtime ~1s)
docker compose restart caddy
```text

**PostgreSQL (recarregar postgresql.conf):**

```bash
# Editar configuração
nano config/postgresql/postgresql.conf

# Recarregar configuração (sem reiniciar)
docker compose exec postgresql pg_ctl reload

# Verificar configuração foi aplicada
docker compose exec postgresql psql -U postgres -c "SHOW shared_buffers;"
```text

---

## Próximos Passos

Após configurar o sistema:

1. **Configure cada serviço individualmente:** Ver `docs/03-services/`
2. **Configure integrações:** Ver `docs/04-integrations/`
3. **Configure backups:** Ver `docs/03-services/duplicati.md`
4. **Revise segurança:** Ver `docs/07-seguranca.md`
5. **Otimize performance:** Ver `docs/08-desempenho.md`

---

## Navegação

- **Anterior:** [Instalação](01-instalacao.md)
- **Próximo:** [Guias de Serviços](03-services/)
- **Índice:** [Documentação Completa](README.md)

---

**Última atualização:** 2025-10-08
**Versão do guia:** 1.0
**Compatível com:** BorgStack v4+, Ubuntu 24.04 LTS
