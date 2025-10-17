# Configuração do BorgStack

Guia de referência rápida para as variáveis de ambiente do BorgStack.

---

## Visão Geral

O BorgStack usa um arquivo `.env` para configurar todos os serviços. Este arquivo contém credenciais, domínios e configurações específicas do BorgStack.

**⚠️ SEGURANÇA CRÍTICA:**
- **NUNCA** commit o arquivo `.env` para controle de versão
- Defina permissões restritas: `chmod 600 .env`
- Faça backup seguro do `.env` e das chaves de encriptação

**Documentação Completa:**
- Para instalação: ver `INSTALL.md`
- Para configuração Docker Compose: ver [documentação oficial](https://docs.docker.com/compose/environment-variables/)

---

## Infraestrutura Core

### Domínio e SSL

| Variável | Descrição | Exemplo |
|----------|-----------|---------|
| `DOMAIN` | Domínio base para todos os serviços | `example.com.br` |
| `EMAIL` | Email para notificações Let's Encrypt | `admin@example.com.br` |

**Subdomínios gerados automaticamente:**
- `n8n.${DOMAIN}` - Automação de workflows
- `chatwoot.${DOMAIN}` - Atendimento ao cliente
- `evolution.${DOMAIN}` - API WhatsApp Business
- `lowcoder.${DOMAIN}` - Construtor de apps
- `directus.${DOMAIN}` - CMS headless
- `fileflows.${DOMAIN}` - Processamento de mídia
- `duplicati.${DOMAIN}` - Sistema de backup

### Redes Docker

**BorgStack usa 2 redes isoladas:**
- `borgstack_internal` - Comunicação entre serviços (bancos de dados não expostos)
- `borgstack_external` - Caddy reverse proxy (única porta exposta: 80/443)

### Volumes Docker

**Convenção de nomenclatura:** Todos os volumes usam prefixo `borgstack_*`

Exemplos:
- `borgstack_postgresql_data`
- `borgstack_mongodb_data`
- `borgstack_redis_data`

---

## Credenciais de Bancos de Dados

### PostgreSQL (Banco Compartilhado)

**PostgreSQL 18.0 com extensão pgvector** - usado por n8n, Chatwoot, Directus, Evolution API

| Variável | Descrição | Banco de Dados |
|----------|-----------|----------------|
| `POSTGRES_PASSWORD` | Senha do superusuário postgres | - |
| `N8N_DB_PASSWORD` | Senha do usuário n8n_user | `n8n_db` |
| `CHATWOOT_DB_PASSWORD` | Senha do usuário chatwoot_user | `chatwoot_db` |
| `DIRECTUS_DB_PASSWORD` | Senha do usuário directus_user | `directus_db` |
| `EVOLUTION_DB_PASSWORD` | Senha do usuário evolution_user | `evolution_db` |

**Estratégia de isolamento:** Cada serviço tem seu próprio database e usuário com permissões restritas.

### MongoDB (Dedicado ao Lowcoder)

**MongoDB 7.0** - usado exclusivamente pelo Lowcoder

| Variável | Descrição |
|----------|-----------|
| `MONGODB_ROOT_PASSWORD` | Senha do usuário admin (root) |
| `LOWCODER_DB_PASSWORD` | Senha do usuário lowcoder_user (database: lowcoder) |

### Redis (Cache e Fila Compartilhados)

**Redis 8.2** - usado por n8n, Chatwoot, Lowcoder, Directus

| Variável | Descrição |
|----------|-----------|
| `REDIS_PASSWORD` | Senha compartilhada para todos os serviços |

**Uso por serviço:**
- n8n: Queue Bull (execução de workflows)
- Chatwoot: Sidekiq jobs + cache
- Lowcoder: Sessões
- Directus: Cache de schemas

---

## Segredos de Aplicações

### n8n

| Variável | Descrição |
|----------|-----------|
| `N8N_ENCRYPTION_KEY` | **CRÍTICO** - Encripta credenciais de workflows (backup obrigatório!) |
| `N8N_BASIC_AUTH_USER` | Usuário para autenticação básica (padrão: admin) |
| `N8N_BASIC_AUTH_PASSWORD` | Senha para autenticação básica |

**⚠️ ATENÇÃO:** Sem o `N8N_ENCRYPTION_KEY`, você perde acesso a TODAS as credenciais salvas.

### Chatwoot

| Variável | Descrição |
|----------|-----------|
| `CHATWOOT_SECRET_KEY_BASE` | Rails secret (128 caracteres hex) - protege sessões |
| `CHATWOOT_API_TOKEN` | Token API para integração n8n (obter via UI após primeiro login) |

### Directus

| Variável | Descrição |
|----------|-----------|
| `DIRECTUS_KEY` | UUID de identificação da instância |
| `DIRECTUS_SECRET` | Segredo para assinatura de tokens JWT |
| `DIRECTUS_ADMIN_EMAIL` | Email da conta admin (criada no primeiro startup) |
| `DIRECTUS_ADMIN_PASSWORD` | Senha da conta admin inicial |

### Evolution API

| Variável | Descrição |
|----------|-----------|
| `EVOLUTION_API_KEY` | Chave global de autenticação (header: apikey) |
| `EVOLUTION_JWT_SECRET` | Segredo para assinatura de tokens JWT |

### Lowcoder

| Variável | Descrição |
|----------|-----------|
| `LOWCODER_ADMIN_EMAIL` | Email da conta admin (criada no primeiro startup) |
| `LOWCODER_ADMIN_PASSWORD` | Senha da conta admin inicial |
| `LOWCODER_ENCRYPTION_PASSWORD` | **CRÍTICO** - Encripta credenciais de datasources (32 chars) |
| `LOWCODER_ENCRYPTION_SALT` | Salt adicional para encriptação (32 chars) |

### Duplicati

| Variável | Descrição |
|----------|-----------|
| `DUPLICATI_PASSWORD` | Senha para acessar UI web do Duplicati |
| `DUPLICATI_ENCRYPTION_KEY` | Chave que encripta configurações de jobs |
| `DUPLICATI_PASSPHRASE` | **CRÍTICO** - Encripta TODOS os backups (backup obrigatório!) |

**⚠️ ATENÇÃO:** Sem o `DUPLICATI_PASSPHRASE`, você NÃO pode restaurar backups!

---

## Variáveis de Integração

### Webhooks

| Variável | Descrição |
|----------|-----------|
| `EVOLUTION_WEBHOOK_URL` | URL do webhook n8n para mensagens WhatsApp |

Formato: `https://${N8N_HOST}/webhook/whatsapp-incoming`

### SeaweedFS (Object Storage S3)

| Variável | Descrição |
|----------|-----------|
| `SEAWEEDFS_ACCESS_KEY` | Chave de acesso S3 (gerar com: `openssl rand -base64 24`) |
| `SEAWEEDFS_SECRET_KEY` | Chave secreta S3 (gerar com: `openssl rand -base64 48`) |

**Endpoint interno:** `http://seaweedfs:8333` (acesso via borgstack_internal)

### Timezone

| Variável | Descrição | Padrão |
|----------|-----------|--------|
| `TZ` | Timezone para logs e agendamentos | `America/Sao_Paulo` |

---

## Configurações Opcionais

### SMTP (Notificações por Email)

```bash
# Descomente e configure para habilitar emails
# SMTP_HOST=smtp.example.com
# SMTP_PORT=587
# SMTP_USER=notifications@example.com
# SMTP_PASSWORD=CHANGE_ME
# SMTP_FROM_EMAIL=noreply@example.com
```

### CORS (Cross-Origin Resource Sharing)

| Variável | Descrição | Padrão |
|----------|-----------|--------|
| `CORS_ALLOWED_ORIGINS` | Origens permitidas para APIs | `*` (MUDAR EM PRODUÇÃO!) |

**⚠️ PRODUÇÃO:** Substituir `*` por domínios específicos: `https://app.example.com,https://admin.example.com`

---

## Geração de Senhas Seguras

```bash
# Senha de 32 caracteres
openssl rand -base64 32 | tr -d "=+/" | cut -c1-32

# Chave hex de 128 caracteres (Chatwoot SECRET_KEY_BASE)
openssl rand -hex 64

# UUID (Directus KEY)
uuidgen
```

---

## Próximos Passos

Após configurar o `.env`:

1. **Iniciar serviços:** `docker compose up -d`
2. **Verificar logs:** `docker compose logs -f`
3. **Configurar serviços individuais:** Ver `docs/services.md`
4. **Configurar backups:** Ver `docs/maintenance.md`

---

**Referência:** `.env.example` contém todas as variáveis com comentários detalhados e valores de exemplo.
