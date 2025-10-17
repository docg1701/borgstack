# Guia de Serviços do BorgStack

Referência rápida dos 12 serviços integrados no BorgStack com links para documentação oficial e configurações específicas do BorgStack.

---

## Visão Geral dos Serviços

| Serviço | Versão | Documentação Oficial | Finalidade no BorgStack |
|---------|--------|---------------------|------------------------|
| **n8n** | 1.112.6 | https://docs.n8n.io/ | Hub central de integração - conecta todos os serviços via workflows |
| **Evolution API** | v2.2.3 | https://doc.evolution-api.com/ | Gateway WhatsApp Business - multi-instâncias via QR code |
| **Chatwoot** | v4.6.0-ce | https://www.chatwoot.com/docs/ | Plataforma omnichannel de atendimento ao cliente |
| **Lowcoder** | 2.7.4 | https://docs.lowcoder.cloud/ | Construtor low-code para aplicações internas |
| **Directus** | 11 | https://docs.directus.io/ | CMS headless com APIs REST/GraphQL |
| **FileFlows** | 25.09 | https://fileflows.com/docs | Processamento automatizado de mídia via FFmpeg |
| **Duplicati** | 2.1.1.102 | https://docs.duplicati.com/ | Backup automatizado com encriptação AES-256 |
| **PostgreSQL** | 18.0 | https://www.postgresql.org/docs/18/ | Banco relacional compartilhado + extensão pgvector |
| **MongoDB** | 7.0 | https://www.mongodb.com/docs/v7.0/ | Banco NoSQL dedicado ao Lowcoder |
| **Redis** | 8.2 | https://redis.io/docs/ | Cache e fila compartilhados entre serviços |
| **SeaweedFS** | 3.97 | https://github.com/seaweedfs/seaweedfs/wiki | Object storage S3-compatible |
| **Caddy** | 2.10 | https://caddyserver.com/docs/ | Reverse proxy com SSL automático via Let's Encrypt |

---

## Infraestrutura Core

### PostgreSQL - Banco Relacional Compartilhado

**Documentação Oficial:** https://www.postgresql.org/docs/18/

**Configuração BorgStack:**
- **Imagem:** `pgvector/pgvector:pg18`
- **Extensão pgvector:** Habilitada para suporte a embeddings vetoriais (RAG/LLM)
- **Multi-database:** 4 databases isolados com usuários dedicados
  - `n8n_db` → usuário `n8n_user`
  - `chatwoot_db` → usuário `chatwoot_user`
  - `directus_db` → usuário `directus_user`
  - `evolution_db` → usuário `evolution_user`
- **Rede:** `borgstack_internal` (sem exposição de portas ao host)
- **Volume:** `borgstack_postgresql_data`

**Acesso:**
```bash
# Conectar ao PostgreSQL
docker compose exec postgresql psql -U postgres

# Conectar a database específico
docker compose exec postgresql psql -U postgres -d n8n_db
```

### MongoDB - Banco NoSQL para Lowcoder

**Documentação Oficial:** https://www.mongodb.com/docs/v7.0/

**Configuração BorgStack:**
- **Imagem:** `mongo:7.0`
- **Uso exclusivo:** Lowcoder (metadata de aplicações)
- **Autenticação:** Usuário `lowcoder_user` com permissões restritas ao database `lowcoder`
- **Rede:** `borgstack_internal`
- **Volume:** `borgstack_mongodb_data`

**Acesso:**
```bash
# Conectar ao MongoDB
docker compose exec mongodb mongosh -u admin -p ${MONGODB_ROOT_PASSWORD} --authenticationDatabase admin
```

### Redis - Cache e Fila Compartilhados

**Documentação Oficial:** https://redis.io/docs/

**Configuração BorgStack:**
- **Imagem:** `redis:8.2-alpine`
- **Compartilhado:** Todos os serviços usam DB 0 com prefixos de chave para isolamento
  - n8n: `bull:*` (queue de workflows)
  - Chatwoot: `sidekiq:*` (background jobs)
  - Lowcoder: `session:*` (sessões)
  - Directus: `cache:*` (schema cache)
- **Persistência:** AOF (Append Only File) habilitado
- **Rede:** `borgstack_internal`
- **Volume:** `borgstack_redis_data`

**Acesso:**
```bash
# Conectar ao Redis
docker compose exec redis redis-cli -a ${REDIS_PASSWORD}
```

### SeaweedFS - Object Storage S3-Compatible

**Documentação Oficial:** https://github.com/seaweedfs/seaweedfs/wiki

**Configuração BorgStack:**
- **Imagem:** `chrislusf/seaweedfs:3.97`
- **API S3:** Endpoint interno `http://seaweedfs:8333`
- **Filer API:** Endpoint interno `http://seaweedfs:8888`
- **Credenciais:** `SEAWEEDFS_ACCESS_KEY` / `SEAWEEDFS_SECRET_KEY`
- **Rede:** `borgstack_internal`
- **Volume:** `borgstack_seaweedfs_data`

**Uso com n8n:** HTTP Request node para upload/download via Filer API

### Caddy - Reverse Proxy com SSL Automático

**Documentação Oficial:** https://caddyserver.com/docs/

**Configuração BorgStack:**
- **Imagem:** `caddy:2.10-alpine`
- **SSL/TLS:** Let's Encrypt automático para todos os subdomínios
- **Roteamento:** Proxy reverso para todos os serviços web
- **Redes:** `borgstack_external` + `borgstack_internal`
- **Portas expostas:** 80 (HTTP), 443 (HTTPS)
- **Volume:** `borgstack_caddy_data` (certificados SSL)

**Requisitos:**
- Domínio configurado com registros DNS A para todos os subdomínios
- Portas 80/443 abertas no firewall

---

## Serviços de Aplicação

### n8n - Automação de Workflows

**Documentação Oficial:** https://docs.n8n.io/

**Configuração BorgStack:**
- **Imagem:** `n8nio/n8n:1.112.6`
- **Função:** Hub central de integração - conecta todos os serviços
- **Database:** PostgreSQL (`n8n_db`)
- **Queue:** Redis (Bull/BullMQ)
- **Webhook base:** `https://n8n.${DOMAIN}/webhook/`
- **Encriptação:** `N8N_ENCRYPTION_KEY` protege credenciais (BACKUP OBRIGATÓRIO!)

**Padrões de integração:**
- Evolution API → n8n (webhook de mensagens WhatsApp)
- n8n → Chatwoot (criar conversas via API)
- Directus → n8n (webhooks de eventos CMS)
- n8n → SeaweedFS (upload/download via HTTP)

### Evolution API - Gateway WhatsApp Business

**Documentação Oficial:** https://doc.evolution-api.com/

**Configuração BorgStack:**
- **Imagem:** `atendai/evolution-api:v2.2.3`
- **Função:** Multi-instâncias WhatsApp via QR code
- **Database:** PostgreSQL (`evolution_db`)
- **Autenticação:** Header `apikey: ${EVOLUTION_API_KEY}`
- **Webhook:** Envia mensagens recebidas para n8n
- **Admin UI:** `https://evolution.${DOMAIN}/manager`

**Integração com n8n:**
1. Criar instância via API Evolution
2. Escanear QR code com WhatsApp
3. Configurar webhook apontando para n8n
4. n8n recebe mensagens e roteia para Chatwoot

### Chatwoot - Atendimento ao Cliente

**Documentação Oficial:** https://www.chatwoot.com/docs/

**Configuração BorgStack:**
- **Imagem:** `chatwoot/chatwoot:v4.6.0-ce`
- **Função:** Plataforma omnichannel (WhatsApp, web chat)
- **Database:** PostgreSQL (`chatwoot_db`)
- **Cache:** Redis (Sidekiq + sessões)
- **API Token:** Obter via UI após primeiro login (Settings → Access Tokens)

**Integração com WhatsApp:**
1. n8n recebe mensagem do Evolution API
2. n8n cria/atualiza conversa no Chatwoot via API
3. Agente responde pelo Chatwoot
4. n8n envia resposta de volta via Evolution API

### Lowcoder - Construtor Low-Code

**Documentação Oficial:** https://docs.lowcoder.cloud/

**Configuração BorgStack:**
- **Imagem:** `lowcoderorg/lowcoder-ce:2.7.4`
- **Função:** Construir aplicações internas custom
- **Database:** MongoDB (database `lowcoder`)
- **Cache:** Redis (sessões)
- **Encriptação:** `LOWCODER_ENCRYPTION_PASSWORD` protege credenciais de datasources

**Casos de uso:**
- Dashboards admin conectando aos databases BorgStack
- Formulários internos com webhooks para n8n
- Aplicações custom para equipes

### Directus - CMS Headless

**Documentação Oficial:** https://docs.directus.io/

**Configuração BorgStack:**
- **Imagem:** `directus/directus:11`
- **Função:** CMS headless com APIs REST/GraphQL
- **Database:** PostgreSQL (`directus_db`)
- **Cache:** Redis (schemas + permissões)
- **Storage:** Volume local (migração para SeaweedFS em breve)
- **Admin UI:** `https://directus.${DOMAIN}/admin`

**Integração com FileFlows:**
- Upload de mídia no Directus dispara webhook
- n8n aciona FileFlows para processar mídia
- FileFlows retorna mídia processada
- n8n atualiza Directus com novo arquivo

### FileFlows - Processamento de Mídia

**Documentação Oficial:** https://fileflows.com/docs

**Configuração BorgStack:**
- **Imagem:** `revenz/fileflows:25.09`
- **Função:** Processamento automatizado via FFmpeg
- **Storage:** Volumes locais (migração para SeaweedFS em breve)
- **Timezone:** `TZ` (afeta logs e agendamentos)
- **UI:** `https://fileflows.${DOMAIN}`

**Capacidades:**
- Vídeo: H.264/H.265, redimensionamento, otimização de bitrate
- Áudio: Normalização, conversão de formato
- Imagem: WebP, redimensionamento, compressão

### Duplicati - Sistema de Backup

**Documentação Oficial:** https://docs.duplicati.com/

**Configuração BorgStack:**
- **Imagem:** `duplicati/duplicati:2.1.1.102`
- **Função:** Backup automatizado com encriptação AES-256
- **Encriptação:** `DUPLICATI_PASSPHRASE` (BACKUP OBRIGATÓRIO!)
- **Destinos:** S3, Backblaze B2, FTP, WebDAV, local
- **UI:** `https://duplicati.${DOMAIN}`

**Estratégia de backup:**
- Backup incremental (apenas dados alterados)
- Retenção: 7 diários + 4 semanais + 12 mensais
- Fontes: PostgreSQL, MongoDB, Redis, volumes de aplicação

---

## Padrões de Integração

### Hub n8n - Modelo Central

**n8n conecta todos os serviços:**

```
WhatsApp (Evolution API)
    ↓ webhook
n8n (workflow)
    ↓ HTTP API
Chatwoot (conversa)
```

```
Directus (upload mídia)
    ↓ webhook
n8n (workflow)
    ↓ HTTP API
FileFlows (processar)
    ↓ webhook
n8n (workflow)
    ↓ HTTP API
Directus (atualizar)
```

### Compartilhamento de Database

**PostgreSQL compartilhado (isolamento por database):**
- n8n, Chatwoot, Directus, Evolution API usam o mesmo PostgreSQL
- Cada serviço tem seu próprio database e usuário
- Facilita backup centralizado

**Redis compartilhado (isolamento por prefixo de chave):**
- Todos os serviços usam DB 0 com prefixos diferentes
- Exemplo: `bull:*`, `sidekiq:*`, `cache:*`

---

## Configurações Específicas BorgStack

### Versão Pinning (Crítico)

**Todos os serviços usam versões exatas no docker-compose.yml:**

```yaml
# ✅ Correto
image: n8nio/n8n:1.112.6

# ❌ Errado
image: n8nio/n8n:latest
```

**Motivo:** Garante deployments reproduzíveis e previne breaking changes inesperadas.

### Nomenclatura de Volumes

**Todos os volumes usam prefixo `borgstack_`:**

```yaml
volumes:
  borgstack_postgresql_data:
  borgstack_mongodb_data:
  borgstack_redis_data:
  borgstack_n8n_data:
```

**Motivo:** Previne conflitos com outros stacks Docker no mesmo host.

### Isolamento de Rede

**Duas redes Docker:**

1. **borgstack_internal** (isolada):
   - PostgreSQL, MongoDB, Redis (SEM exposição de portas)
   - Comunicação serviço-a-serviço via DNS Docker

2. **borgstack_external**:
   - Caddy (ÚNICA porta exposta: 80/443)
   - Todos os serviços web conectam para receber tráfego do Caddy

**Motivo:** Defense in depth - databases nunca acessíveis diretamente do host.

### Health Checks Obrigatórios

**Todos os serviços têm health checks definidos:**

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres"]
  interval: 10s
  timeout: 5s
  retries: 5
```

**Motivo:** Habilita startup ordering correto com `depends_on: condition: service_healthy`.

### Dependency Management

**Serviços aguardam dependências estarem saudáveis:**

```yaml
n8n:
  depends_on:
    postgresql:
      condition: service_healthy
    redis:
      condition: service_healthy
```

**Motivo:** Previne falhas de startup por dependências indisponíveis.

---

## Configuração de Desenvolvimento Local

**docker-compose.override.yml** (carregado automaticamente):
- Portas diretas expostas para debugging (5432, 6379, 27017)
- Logs em nível debug
- Caddy sem SSL (localhost)

**⚠️ NUNCA use override.yml em produção!**

**Produção (explícito):**
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

---

## Próximos Passos

1. **Configurar variáveis:** Ver `CONFIGURATION.md`
2. **Iniciar stack:** `docker compose up -d`
3. **Primeiro acesso:** Criar contas admin em cada serviço
4. **Configurar integrações:** Ver `docs/integrations.md` *(em breve)*
5. **Setup de backups:** Ver `docs/maintenance.md` *(em breve)*

---

## Troubleshooting Rápido

| Problema | Solução |
|----------|---------|
| Serviço não inicia | Verificar health check: `docker compose ps` |
| Erro de conexão database | Aguardar database ficar healthy |
| SSL não gera | Verificar DNS propagado: `dig n8n.${DOMAIN}` |
| Webhook 404 | Verificar workflow ativo no n8n |

**Logs detalhados:**
```bash
# Ver logs de todos os serviços
docker compose logs -f

# Ver logs de serviço específico
docker compose logs -f n8n
```

---

**Documentação adicional:** Para detalhes de troubleshooting, ver `TROUBLESHOOTING.md` *(em breve)*
