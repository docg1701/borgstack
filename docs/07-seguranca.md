# Guia de Segurança - BorgStack

## Índice
1. [Filosofia de Segurança](#filosofia-de-segurança)
2. [Segurança de Rede](#segurança-de-rede)
3. [Segurança de Dados](#segurança-de-dados)
4. [Segurança de Aplicações](#segurança-de-aplicações)
5. [Segurança de Containers](#segurança-de-containers)
6. [SSL/TLS e Certificados](#ssltls-e-certificados)
7. [Conformidade e Auditoria](#conformidade-e-auditoria)
8. [Monitoramento de Segurança](#monitoramento-de-segurança)
9. [Resposta a Incidentes](#resposta-a-incidentes)
10. [Checklist de Segurança](#checklist-de-segurança)

---

## Filosofia de Segurança

### Princípios de Segurança do BorgStack

```mermaid
graph TD
    A[Defesa em Profundidade] --> B[Isolamento de Rede]
    A --> C[Criptografia]
    A --> D[Controle de Acesso]
    A --> E[Auditoria]

    B --> B1[Redes Docker Separadas]
    B --> B2[Firewall UFW]
    B --> B3[Exposição Mínima]

    C --> C1[TLS/SSL]
    C --> C2[Backups Criptografados]
    C --> C3[Senhas Hash]

    D --> D1[Autenticação Forte]
    D --> D2[Princípio do Menor Privilégio]
    D --> D3[Secrets Management]

    E --> E1[Logs Centralizados]
    E --> E2[Alertas Automáticos]
    E --> E3[Trilha de Auditoria]
```text

### Camadas de Segurança

1. **Perímetro**: Firewall, TLS, rate limiting
2. **Rede**: Isolamento Docker, segmentação
3. **Aplicação**: Autenticação, autorização, validação
4. **Dados**: Criptografia, backups, controle de acesso
5. **Infraestrutura**: Containers isolados, usuários não-root

---

## Segurança de Rede

### 1.1. Arquitetura de Rede Segura

O BorgStack utiliza **duas redes Docker isoladas**:

```yaml
networks:
  borgstack_external:
    driver: bridge
    # Rede exposta ao mundo externo via Caddy

  borgstack_internal:
    driver: bridge
    internal: true  # SEM acesso à internet
    # Rede interna para comunicação entre serviços
```text

**Serviços APENAS na rede interna** (sem acesso direto externo):
- PostgreSQL
- MongoDB
- Redis
- Duplicati

**Serviços em AMBAS as redes** (gateway):
- Caddy (reverse proxy)
- n8n
- Chatwoot
- Directus
- FileFlows
- Lowcoder
- Evolution API
- SeaweedFS

### 1.2. Verificar Isolamento de Rede

```bash
#!/bin/bash
# Script: verify-network-isolation.sh

echo "=== Verificação de Isolamento de Rede ==="
echo ""

# 1. Verificar configuração de rede interna
echo "1. Rede borgstack_internal:"
docker network inspect borgstack_internal --format='{{json .}}' | jq '{
  Name: .Name,
  Internal: .Internal,
  Driver: .Driver
}'

echo ""

# 2. Serviços APENAS em borgstack_internal
echo "2. Serviços isolados (APENAS borgstack_internal):"
docker compose config --format json | jq -r '
  .services | to_entries[] |
  select(.value.networks | keys | length == 1 and has("borgstack_internal")) |
  "  ✅ \(.key)"
'

echo ""

# 3. Testar isolamento (deve falhar)
echo "3. Teste de isolamento - PostgreSQL não deve acessar internet:"
docker compose exec -T postgresql ping -c 2 8.8.8.8 2>&1 | grep -q "Network is unreachable" \
  && echo "  ✅ PostgreSQL corretamente isolado" \
  || echo "  ❌ PostgreSQL TEM acesso à internet (PROBLEMA DE SEGURANÇA)"

echo ""

# 4. Verificar portas expostas
echo "4. Portas expostas ao host:"
docker compose ps --format "table {{.Name}}\t{{.Ports}}" | grep -v "PORTS" | while read line; do
  if echo "$line" | grep -q "0.0.0.0"; then
    echo "  ⚠️  $line"
  fi
done

echo ""
echo "=== Verificação completa ==="
```text

### 1.3. Configurar Firewall UFW

```bash
#!/bin/bash
# Script: setup-firewall.sh

# Instalar UFW
sudo apt update
sudo apt install -y ufw

# Política padrão: negar tudo
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Permitir SSH (IMPORTANTE: fazer ANTES de habilitar)
sudo ufw allow 22/tcp comment 'SSH'

# Permitir HTTP e HTTPS (Caddy)
sudo ufw allow 80/tcp comment 'HTTP (Caddy)'
sudo ufw allow 443/tcp comment 'HTTPS (Caddy)'

# Permitir apenas do Docker
sudo ufw allow from 172.16.0.0/12 to any comment 'Docker networks'

# Habilitar UFW
sudo ufw --force enable

# Status
sudo ufw status verbose
```text

### 1.4. Configurar Rate Limiting no Caddy

Adicione ao `Caddyfile`:

```caddyfile
# Rate limiting para APIs
(rate_limit) {
    rate_limit {
        zone dynamic {
            key {remote_host}
            events 100
            window 1m
        }
    }
}

# Aplicar a APIs sensíveis
api.borgstack.local {
    import rate_limit
    reverse_proxy n8n:5678
}

evolution.borgstack.local {
    import rate_limit
    reverse_proxy evolution-api:8080
}
```text

### 1.5. Bloquear IPs Maliciosos

```bash
#!/bin/bash
# Script: block-malicious-ips.sh

# Lista de IPs a bloquear (exemplo)
BLOCKED_IPS=(
    "192.0.2.1"
    "198.51.100.1"
    # Adicione IPs maliciosos conhecidos
)

for IP in "${BLOCKED_IPS[@]}"; do
    sudo ufw deny from $IP to any comment "Blocked malicious IP"
    echo "✅ Bloqueado: $IP"
done

sudo ufw reload
```text

---

## Segurança de Dados

### 2.1. Proteção do Arquivo .env

**NUNCA commite .env para Git**:

```bash
# Verificar se .env está no .gitignore
if grep -q "^\.env$" .gitignore; then
    echo "✅ .env está no .gitignore"
else
    echo "❌ ADICIONE .env ao .gitignore IMEDIATAMENTE"
    echo ".env" >> .gitignore
fi

# Verificar se .env foi commitado acidentalmente
if git ls-files | grep -q "^\.env$"; then
    echo "⚠️  ALERTA: .env está versionado no Git!"
    echo "Execute: git rm --cached .env && git commit -m 'Remove .env from git'"
fi
```text

**Permissões corretas**:

```bash
# .env deve ser legível apenas pelo proprietário
chmod 600 .env
ls -l .env
# Output esperado: -rw------- 1 user user ... .env
```text

### 2.2. Usar Docker Secrets (Swarm)

Se estiver usando Docker Swarm, migre para secrets:

```bash
# Criar secret a partir do arquivo
echo "senha_super_secreta" | docker secret create postgres_password -

# Usar no docker-compose.yml
services:
  postgresql:
    secrets:
      - postgres_password
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password

secrets:
  postgres_password:
    external: true
```text

### 2.3. Criptografia de Backups

```bash
#!/bin/bash
# Script: encrypted-backup.sh

BACKUP_DIR="/backups/manual"
DATE=$(date +%Y%m%d_%H%M%S)
ENCRYPTION_KEY="/secure/backup-encryption.key"

# 1. Criar chave de criptografia (uma vez)
if [ ! -f "$ENCRYPTION_KEY" ]; then
    openssl rand -base64 32 > "$ENCRYPTION_KEY"
    chmod 400 "$ENCRYPTION_KEY"
    echo "✅ Chave de criptografia criada: $ENCRYPTION_KEY"
fi

# 2. Backup PostgreSQL
echo "Backup PostgreSQL..."
docker compose exec -T postgresql pg_dumpall -U postgres -c | \
    gzip | \
    openssl enc -aes-256-cbc -salt -pbkdf2 -pass file:"$ENCRYPTION_KEY" \
    > "$BACKUP_DIR/postgresql_$DATE.sql.gz.enc"

# 3. Backup MongoDB
echo "Backup MongoDB..."
docker compose exec -T mongodb mongodump --archive --gzip | \
    openssl enc -aes-256-cbc -salt -pbkdf2 -pass file:"$ENCRYPTION_KEY" \
    > "$BACKUP_DIR/mongodb_$DATE.archive.gz.enc"

# 4. Backup volumes (SeaweedFS, uploads)
echo "Backup volumes..."
tar czf - \
    volumes/seaweedfs_data \
    volumes/directus_uploads \
    volumes/fileflows_data | \
    openssl enc -aes-256-cbc -salt -pbkdf2 -pass file:"$ENCRYPTION_KEY" \
    > "$BACKUP_DIR/volumes_$DATE.tar.gz.enc"

echo "✅ Backups criptografados criados"
echo "🔑 Guarde a chave em local seguro: $ENCRYPTION_KEY"
```text

**Restaurar backup criptografado**:

```bash
# PostgreSQL
openssl enc -d -aes-256-cbc -pbkdf2 -pass file:/secure/backup-encryption.key \
    -in postgresql_20251008.sql.gz.enc | \
    gunzip | \
    docker compose exec -T postgresql psql -U postgres

# MongoDB
openssl enc -d -aes-256-cbc -pbkdf2 -pass file:/secure/backup-encryption.key \
    -in mongodb_20251008.archive.gz.enc | \
    docker compose exec -T mongodb mongorestore --archive --gzip
```text

### 2.4. Criptografia de Banco de Dados

#### PostgreSQL: Criptografia em Repouso

```bash
# Habilitar SSL/TLS no PostgreSQL
cat > config/postgresql/postgresql.conf << EOF
# SSL Configuration
ssl = on
ssl_cert_file = '/etc/ssl/certs/server.crt'
ssl_key_file = '/etc/ssl/private/server.key'
ssl_ca_file = '/etc/ssl/certs/ca.crt'

# Forçar SSL para todas conexões
ssl_min_protocol_version = 'TLSv1.2'
EOF

# Gerar certificados auto-assinados (ou use Let's Encrypt)
openssl req -new -x509 -days 365 -nodes -text \
    -out config/postgresql/server.crt \
    -keyout config/postgresql/server.key \
    -subj "/CN=postgresql.borgstack.local"

chmod 600 config/postgresql/server.key
```text

#### MongoDB: Criptografia WiredTiger

```yaml
# docker-compose.yml
services:
  mongodb:
    command: >
      mongod
      --enableEncryption
      --encryptionKeyFile /etc/mongodb/encryption.key
    volumes:
      - ./config/mongodb/encryption.key:/etc/mongodb/encryption.key:ro
```text

```bash
# Criar chave de criptografia MongoDB (uma vez)
openssl rand -base64 32 > config/mongodb/encryption.key
chmod 600 config/mongodb/encryption.key
```text

### 2.5. Criptografia de Dados Sensíveis em Aplicações

#### Lowcoder: Criptografia de Credenciais

```bash
# Configurar no .env
LOWCODER_DB_ENCRYPTION_PASSWORD=$(openssl rand -base64 32)
LOWCODER_DB_ENCRYPTION_SALT=$(openssl rand -base64 16)

echo "LOWCODER_DB_ENCRYPTION_PASSWORD=$LOWCODER_DB_ENCRYPTION_PASSWORD" >> .env
echo "LOWCODER_DB_ENCRYPTION_SALT=$LOWCODER_DB_ENCRYPTION_SALT" >> .env
```text

#### Directus: Hash de Senhas

Directus usa bcrypt automaticamente para senhas. Verificar configuração:

```bash
# Verificar hash de senha no banco
docker compose exec postgresql psql -U directus -d directus -c \
  "SELECT email, password FROM directus_users LIMIT 1;"

# Output esperado: password deve começar com $2b$ (bcrypt)
```text

---

## Segurança de Aplicações

### 3.1. Senhas Fortes

```bash
#!/bin/bash
# Script: generate-strong-passwords.sh

# Gerar senha forte de 32 caracteres
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# Gerar todas as senhas necessárias
echo "# Senhas Geradas - $(date)"
echo ""
echo "POSTGRES_PASSWORD=$(generate_password)"
echo "REDIS_PASSWORD=$(generate_password)"
echo "MONGODB_ROOT_PASSWORD=$(generate_password)"
echo "N8N_ENCRYPTION_KEY=$(generate_password)"
echo "CHATWOOT_SECRET_KEY_BASE=$(openssl rand -hex 64)"
echo "DIRECTUS_KEY=$(openssl rand -hex 16)"
echo "DIRECTUS_SECRET=$(openssl rand -hex 32)"
echo "EVOLUTION_AUTHENTICATION_API_KEY=$(generate_password)"
echo "LOWCODER_DB_ENCRYPTION_PASSWORD=$(generate_password)"
echo "LOWCODER_DB_ENCRYPTION_SALT=$(openssl rand -base64 16)"
```text

**Política de senhas recomendada**:
- Mínimo 16 caracteres para senhas administrativas
- Mínimo 32 caracteres para chaves de criptografia
- Incluir letras maiúsculas, minúsculas, números e símbolos
- Usar gerenciador de senhas (Bitwarden, 1Password, etc.)
- Rotacionar senhas a cada 90 dias (veja [06-manutencao.md](./06-manutencao.md#15-rotação-de-credenciais-trimestral))

### 3.2. Autenticação API

#### Evolution API: API Key

```bash
# Configurar API Key forte no .env
EVOLUTION_AUTHENTICATION_API_KEY=$(openssl rand -base64 32)

# Testar autenticação
curl -X GET https://evolution.borgstack.local/instance/list \
  -H "apikey: $EVOLUTION_AUTHENTICATION_API_KEY"
```text

#### n8n: Webhook Authentication

```javascript
// Workflow n8n - Nó "HTTP Request"
{
  "authentication": "headerAuth",
  "headerAuth": {
    "name": "Authorization",
    "value": "Bearer {{ $env.N8N_WEBHOOK_SECRET }}"
  }
}
```text

#### Directus: JWT Tokens

```bash
# Configurar no .env
DIRECTUS_KEY="chave-secreta-16-bytes"  # 16 bytes hex
DIRECTUS_SECRET="chave-secreta-32-bytes"  # 32 bytes hex
DIRECTUS_ACCESS_TOKEN_TTL="15m"
DIRECTUS_REFRESH_TOKEN_TTL="7d"
DIRECTUS_REFRESH_TOKEN_COOKIE_SECURE="true"
DIRECTUS_REFRESH_TOKEN_COOKIE_SAME_SITE="lax"
```text

### 3.3. CORS - Cross-Origin Resource Sharing

#### Configurar CORS no Caddy

```caddyfile
directus.borgstack.local {
    @cors_preflight {
        method OPTIONS
    }

    header @cors_preflight {
        Access-Control-Allow-Origin "https://app.borgstack.local"
        Access-Control-Allow-Methods "GET, POST, PUT, PATCH, DELETE"
        Access-Control-Allow-Headers "Content-Type, Authorization"
        Access-Control-Max-Age "3600"
    }

    respond @cors_preflight 204

    header {
        Access-Control-Allow-Origin "https://app.borgstack.local"
        Access-Control-Allow-Credentials "true"
    }

    reverse_proxy directus:8055
}
```text

#### Configurar CORS no Directus

```bash
# .env
DIRECTUS_CORS_ENABLED="true"
DIRECTUS_CORS_ORIGIN="https://app.borgstack.local,https://admin.borgstack.local"
DIRECTUS_CORS_METHODS="GET,POST,PATCH,DELETE"
DIRECTUS_CORS_ALLOWED_HEADERS="Content-Type,Authorization"
DIRECTUS_CORS_EXPOSED_HEADERS="Content-Range"
DIRECTUS_CORS_CREDENTIALS="true"
DIRECTUS_CORS_MAX_AGE="3600"
```text

### 3.4. Proteção contra SQL Injection

**Sempre use queries parametrizadas**:

```javascript
// ❌ INSEGURO - SQL Injection
const query = `SELECT * FROM users WHERE email = '${userInput}'`;

// ✅ SEGURO - Query parametrizada (PostgreSQL node no n8n)
const items = $input.all();
const email = items[0].json.email;

// Use PostgreSQL node com parâmetros
// Query: SELECT * FROM users WHERE email = $1
// Parameters: [{{ $json.email }}]
```text

### 3.5. Validação de Input

```javascript
// n8n - Nó "Function" para validar email
const email = $input.item.json.email;

// Validar formato de email
const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
if (!emailRegex.test(email)) {
    throw new Error('Email inválido');
}

// Sanitizar para prevenir XSS
const sanitize = (str) => {
    return str
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#x27;');
};

return {
    json: {
        email: sanitize(email)
    }
};
```text

---

## Segurança de Containers

### 4.1. Executar Containers como Usuário Não-Root

```yaml
# docker-compose.yml
services:
  redis:
    image: redis:7-alpine
    user: "999:999"  # UID:GID não-root
    # ...

  n8n:
    image: n8nio/n8n:latest
    user: "node"  # Usuário não-root pré-configurado
    # ...
```text

**Verificar usuário atual em containers**:

```bash
#!/bin/bash
# Script: check-container-users.sh

echo "=== Verificação de Usuários em Containers ==="
echo ""

for service in $(docker compose ps --services); do
    echo "Service: $service"
    docker compose exec -T $service whoami 2>/dev/null || echo "  (não suporta whoami)"
    docker compose exec -T $service id 2>/dev/null || echo "  (não suporta id)"
    echo ""
done
```text

### 4.2. Limites de Recursos

```yaml
# docker-compose.yml
services:
  postgresql:
    # ...
    deploy:
      resources:
        limits:
          cpus: '2.0'        # Máximo 2 CPUs
          memory: 4G         # Máximo 4GB RAM
        reservations:
          cpus: '1.0'        # Reservar 1 CPU
          memory: 2G         # Reservar 2GB RAM

  chatwoot:
    # ...
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 2G
          pids: 200          # Limitar processos (fork bomb protection)
```text

**Monitorar uso de recursos**:

```bash
# Ver uso em tempo real
docker stats

# Ver limites configurados
docker compose config | grep -A 5 "resources:"
```text

### 4.3. Health Checks de Segurança

```yaml
# docker-compose.yml
services:
  caddy:
    # ...
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "https://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  postgresql:
    # ...
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
```text

### 4.4. Opções de Segurança do Docker

```yaml
# docker-compose.yml
services:
  chatwoot:
    # ...
    security_opt:
      - no-new-privileges:true  # Prevenir escalação de privilégios
      - seccomp:unconfined      # (use com cuidado)

    cap_drop:
      - ALL                     # Remover todas capabilities
    cap_add:
      - NET_BIND_SERVICE        # Adicionar apenas necessárias

    read_only: false            # Filesystem somente leitura (quando possível)
    tmpfs:
      - /tmp                    # Montar /tmp como tmpfs
```text

### 4.5. Scan de Vulnerabilidades

```bash
#!/bin/bash
# Script: scan-vulnerabilities.sh

echo "=== Scanning Docker Images for Vulnerabilities ==="
echo ""

# Instalar Trivy (se necessário)
if ! command -v trivy &> /dev/null; then
    echo "Instalando Trivy..."
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
    echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
    sudo apt update
    sudo apt install -y trivy
fi

# Scan de todas as imagens usadas
IMAGES=$(docker compose config | grep "image:" | awk '{print $2}' | sort -u)

for IMAGE in $IMAGES; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Scanning: $IMAGE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Scan com Trivy (HIGH e CRITICAL apenas)
    trivy image --severity HIGH,CRITICAL "$IMAGE"

    echo ""
done

echo "✅ Scan completo"
```text

---

## SSL/TLS e Certificados

### 5.1. Caddy com Let's Encrypt Automático

O Caddy gerencia certificados SSL automaticamente:

```caddyfile
# Caddyfile
{
    email admin@borgstack.com  # Email para Let's Encrypt

    # Configurações de segurança TLS
    default_sni borgstack.local

    # Protocolo mínimo TLS 1.2
    protocols tls1.2 tls1.3
}

# Todos os serviços automaticamente ganham HTTPS
n8n.borgstack.local {
    reverse_proxy n8n:5678
}

chatwoot.borgstack.local {
    reverse_proxy chatwoot:3000
}
```text

### 5.2. Monitorar Expiração de Certificados

```bash
#!/bin/bash
# Script: check-ssl-expiry.sh

DOMAINS=(
    "n8n.borgstack.local"
    "chatwoot.borgstack.local"
    "directus.borgstack.local"
    "evolution.borgstack.local"
    "lowcoder.borgstack.local"
    "fileflows.borgstack.local"
)

echo "=== Verificação de Certificados SSL ==="
echo ""

for DOMAIN in "${DOMAINS[@]}"; do
    echo "Domain: $DOMAIN"

    # Verificar expiração
    EXPIRY=$(echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | \
             openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)

    if [ -z "$EXPIRY" ]; then
        echo "  ❌ Não foi possível obter certificado"
    else
        # Converter para timestamp
        EXPIRY_TS=$(date -d "$EXPIRY" +%s)
        NOW_TS=$(date +%s)
        DAYS_LEFT=$(( ($EXPIRY_TS - $NOW_TS) / 86400 ))

        if [ $DAYS_LEFT -lt 7 ]; then
            echo "  🔴 CRÍTICO: Expira em $DAYS_LEFT dias - $EXPIRY"
        elif [ $DAYS_LEFT -lt 30 ]; then
            echo "  🟡 ATENÇÃO: Expira em $DAYS_LEFT dias - $EXPIRY"
        else
            echo "  ✅ OK: Expira em $DAYS_LEFT dias - $EXPIRY"
        fi
    fi

    echo ""
done
```text

### 5.3. Forçar HTTPS

```caddyfile
# Redirecionar HTTP para HTTPS automaticamente (padrão Caddy)
http://n8n.borgstack.local {
    redir https://n8n.borgstack.local{uri} permanent
}

# Ou configurar HSTS (HTTP Strict Transport Security)
n8n.borgstack.local {
    header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    reverse_proxy n8n:5678
}
```text

### 5.4. Configurar TLS Mínimo e Ciphers

```caddyfile
# Caddyfile - Configuração global
{
    # Protocolo mínimo TLS 1.2
    protocols tls1.2 tls1.3

    # Ciphers modernos (opcional, Caddy já usa defaults seguros)
    # tls_ciphers TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
}
```text

### 5.5. Renovação Manual de Certificados

Caddy renova automaticamente, mas para forçar:

```bash
# Recarregar configuração Caddy (força renovação se necessário)
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile

# Verificar logs de renovação
docker compose logs caddy | grep -i "renew\|certificate"

# Ver certificados gerenciados
docker compose exec caddy ls -lah /data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/
```text

---

## Conformidade e Auditoria

### 6.1. LGPD - Lei Geral de Proteção de Dados

#### Dados Pessoais Armazenados

O BorgStack pode armazenar:
- **Chatwoot**: Nome, email, telefone, mensagens
- **Evolution API**: Números WhatsApp, mensagens
- **Directus**: Dados de usuários e conteúdo
- **n8n**: Dados processados em workflows

#### Requisitos LGPD

1. **Consentimento**: Obter consentimento explícito para coleta
2. **Finalidade**: Usar dados apenas para fins declarados
3. **Minimização**: Coletar apenas dados necessários
4. **Retenção**: Deletar dados quando não mais necessários
5. **Segurança**: Proteger dados com criptografia e controles de acesso
6. **Direitos do Titular**:
   - Acesso aos dados
   - Correção de dados
   - Exclusão de dados
   - Portabilidade de dados

#### Implementar Política de Retenção

```sql
-- PostgreSQL - Deletar conversas antigas (Chatwoot)
-- ATENÇÃO: Executar apenas após backup!

-- Deletar conversas fechadas há mais de 2 anos
DELETE FROM conversations
WHERE status = 'resolved'
  AND updated_at < NOW() - INTERVAL '2 years';

-- Deletar mensagens de conversas deletadas
DELETE FROM messages
WHERE conversation_id NOT IN (SELECT id FROM conversations);
```text

```javascript
// n8n - Workflow para limpeza automática
// Schedule Trigger (mensal) → PostgreSQL node

// Query SQL
const cleanupQuery = `
DELETE FROM conversations
WHERE status = 'resolved'
  AND updated_at < NOW() - INTERVAL '2 years'
RETURNING id;
`;

return {
    json: {
        query: cleanupQuery
    }
};
```text

### 6.2. Logs de Auditoria

```bash
#!/bin/bash
# Script: audit-logs.sh

AUDIT_LOG="/var/log/borgstack-audit.log"

# Função para registrar evento
audit_log() {
    local EVENT="$1"
    local USER="$2"
    local DETAILS="$3"

    echo "$(date -Iseconds) | $EVENT | User: $USER | $DETAILS" >> "$AUDIT_LOG"
}

# Exemplos de eventos auditados
audit_log "LOGIN" "admin@example.com" "Login successful from IP 192.168.1.100"
audit_log "DATA_ACCESS" "user@example.com" "Accessed customer data ID 12345"
audit_log "DATA_EXPORT" "admin@example.com" "Exported 1000 records to CSV"
audit_log "CONFIG_CHANGE" "root" "Modified .env file"
```text

**Integrar com n8n para auditoria automática**:

```javascript
// n8n - Workflow "Audit Logger"
// Webhook Trigger → Function → PostgreSQL

// Function node
const auditEntry = {
    timestamp: new Date().toISOString(),
    event_type: $input.item.json.event_type,
    user_email: $input.item.json.user_email,
    ip_address: $input.item.json.ip_address,
    details: JSON.stringify($input.item.json.details),
    service: $input.item.json.service || 'unknown'
};

return { json: auditEntry };

// PostgreSQL node - INSERT
// INSERT INTO audit_logs (timestamp, event_type, user_email, ip_address, details, service)
// VALUES ($1, $2, $3, $4, $5, $6)
```text

### 6.3. Relatório de Conformidade

```bash
#!/bin/bash
# Script: compliance-report.sh

REPORT_FILE="compliance-report-$(date +%Y%m%d).txt"

cat > "$REPORT_FILE" << EOF
════════════════════════════════════════════════════════
RELATÓRIO DE CONFORMIDADE - BORGSTACK
Data: $(date)
════════════════════════════════════════════════════════

1. SEGURANÇA DE REDE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

# Verificar isolamento de rede
echo "Rede interna isolada:" >> "$REPORT_FILE"
docker network inspect borgstack_internal --format='{{.Internal}}' >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"
echo "2. CRIPTOGRAFIA" >> "$REPORT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$REPORT_FILE"

# Verificar SSL nos domínios
for DOMAIN in n8n.borgstack.local chatwoot.borgstack.local; do
    echo "SSL para $DOMAIN:" >> "$REPORT_FILE"
    echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | \
        openssl x509 -noout -enddate 2>/dev/null >> "$REPORT_FILE" || echo "  Não configurado" >> "$REPORT_FILE"
done

echo "" >> "$REPORT_FILE"
echo "3. CONTROLE DE ACESSO" >> "$REPORT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$REPORT_FILE"

# Verificar permissões .env
echo "Permissões .env:" >> "$REPORT_FILE"
ls -l .env >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"
echo "4. BACKUPS" >> "$REPORT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$REPORT_FILE"

# Verificar backups recentes
echo "Backups dos últimos 7 dias:" >> "$REPORT_FILE"
find /backups -type f -mtime -7 -ls >> "$REPORT_FILE" 2>/dev/null || echo "  Nenhum backup encontrado" >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"
echo "5. LOGS DE AUDITORIA" >> "$REPORT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$REPORT_FILE"

# Contar eventos de auditoria dos últimos 30 dias
if [ -f /var/log/borgstack-audit.log ]; then
    echo "Eventos nos últimos 30 dias:" >> "$REPORT_FILE"
    awk -v date="$(date -d '30 days ago' -Iseconds)" '$1 > date' /var/log/borgstack-audit.log | \
        wc -l >> "$REPORT_FILE"
else
    echo "  Logs de auditoria não configurados" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"
echo "════════════════════════════════════════════════════════" >> "$REPORT_FILE"
echo "Relatório gerado em: $(date)" >> "$REPORT_FILE"
echo "════════════════════════════════════════════════════════" >> "$REPORT_FILE"

echo "✅ Relatório salvo em: $REPORT_FILE"
cat "$REPORT_FILE"
```text

---

## Monitoramento de Segurança

### 7.1. Analisar Logs para Eventos de Segurança

```bash
#!/bin/bash
# Script: security-log-analysis.sh

echo "=== Análise de Logs de Segurança ==="
echo ""

# 1. Tentativas de login falhas (Chatwoot)
echo "1. Tentativas de login falhas (últimas 24h):"
docker compose logs --since 24h chatwoot 2>/dev/null | \
    grep -i "unauthorized\|authentication failed\|invalid password" | \
    wc -l

echo ""

# 2. Erros HTTP 4xx e 5xx (Caddy)
echo "2. Erros HTTP (últimas 24h):"
docker compose logs --since 24h caddy 2>/dev/null | \
    grep -E "\" (4[0-9]{2}|5[0-9]{2}) " | \
    tail -20

echo ""

# 3. Conexões suspeitas (PostgreSQL)
echo "3. Conexões PostgreSQL falhadas (últimas 24h):"
docker compose logs --since 24h postgresql 2>/dev/null | \
    grep -i "authentication failed\|connection refused" | \
    wc -l

echo ""

# 4. Alterações em arquivos críticos
echo "4. Alterações em arquivos críticos (últimas 24h):"
find . -name ".env" -o -name "docker-compose.yml" -o -name "Caddyfile" | \
    xargs ls -lt | \
    head -10

echo ""

# 5. Containers reiniciados inesperadamente
echo "5. Containers reiniciados (últimas 24h):"
docker compose ps --format json | \
    jq -r 'select(.Status | contains("Restarting")) | "\(.Name): \(.Status)"'
```text

### 7.2. Alertas de Segurança via Email

```bash
#!/bin/bash
# Script: security-alerts.sh

ALERT_EMAIL="admin@borgstack.com"
ALERT_LOG="/tmp/security-alert.log"

# Verificar tentativas de login falhas
FAILED_LOGINS=$(docker compose logs --since 1h chatwoot 2>/dev/null | \
    grep -i "authentication failed" | wc -l)

if [ $FAILED_LOGINS -gt 10 ]; then
    cat > "$ALERT_LOG" << EOF
ALERTA DE SEGURANÇA - BorgStack
Data: $(date)

Detectadas $FAILED_LOGINS tentativas de login falhas na última hora.

Possível ataque de força bruta em andamento.

Ações recomendadas:
1. Verificar logs: docker compose logs chatwoot
2. Verificar IPs suspeitos
3. Bloquear IPs maliciosos: sudo ufw deny from <IP>
4. Considerar implementar rate limiting

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Logs recentes:
$(docker compose logs --since 1h chatwoot 2>/dev/null | grep -i "authentication failed" | tail -10)
EOF

    # Enviar email (requer mailutils configurado)
    mail -s "🔴 ALERTA DE SEGURANÇA - BorgStack" "$ALERT_EMAIL" < "$ALERT_LOG"

    echo "⚠️  ALERTA enviado para $ALERT_EMAIL"
fi
```text

### 7.3. Integração com n8n para Monitoramento

```javascript
// n8n - Workflow "Security Monitor"
// Schedule Trigger (a cada hora) → HTTP Request (logs) → Function → IF → Email/Telegram

// HTTP Request node - Obter logs do Docker via API
// URL: http://localhost:2375/containers/{container_id}/logs?stdout=true&stderr=true&since=3600

// Function node - Análise
const logs = $input.item.binary.data;
const failedLogins = (logs.match(/authentication failed/gi) || []).length;
const errors = (logs.match(/error/gi) || []).length;

const alert = {
    timestamp: new Date().toISOString(),
    service: 'chatwoot',
    failed_logins: failedLogins,
    errors: errors,
    alert: failedLogins > 10 || errors > 50,
    severity: failedLogins > 10 ? 'HIGH' : 'MEDIUM'
};

return { json: alert };

// IF node
// Condition: {{ $json.alert }} equals true

// Email node (se alerta)
// Subject: 🔴 ALERTA DE SEGURANÇA - BorgStack
// Body:
/*
Detectado evento de segurança:

Service: {{ $json.service }}
Failed Logins: {{ $json.failed_logins }}
Errors: {{ $json.errors }}
Severity: {{ $json.severity }}

Timestamp: {{ $json.timestamp }}

Verifique os logs imediatamente.
*/
```text

---

## Resposta a Incidentes

### 8.1. Plano de Resposta a Incidentes

```mermaid
graph TD
    A[Incidente Detectado] --> B{Tipo de Incidente}

    B -->|Acesso não autorizado| C[Isolar Sistema]
    B -->|Vazamento de dados| D[Notificar Autoridades]
    B -->|Ataque DDoS| E[Ativar Proteção DDoS]
    B -->|Ransomware| F[Desconectar da rede]

    C --> G[Investigar Logs]
    D --> G
    E --> G
    F --> G

    G --> H[Identificar Causa]
    H --> I[Remediar Vulnerabilidade]
    I --> J[Restaurar de Backup]
    J --> K[Validar Segurança]
    K --> L[Retomar Operação]
    L --> M[Post-Mortem]
```text

### 8.2. Procedimento de Isolamento

```bash
#!/bin/bash
# Script: emergency-isolation.sh

echo "🚨 ISOLAMENTO DE EMERGÊNCIA - BORGSTACK"
echo "Este script irá PARAR TODOS OS SERVIÇOS"
read -p "Tem certeza? (digite 'CONFIRMO' para continuar): " CONFIRM

if [ "$CONFIRM" != "CONFIRMO" ]; then
    echo "Operação cancelada."
    exit 1
fi

echo "1. Criando backup de emergência..."
docker compose exec -T postgresql pg_dumpall -U postgres -c | \
    gzip > "/backups/emergency-$(date +%Y%m%d_%H%M%S).sql.gz"

echo "2. Parando todos os containers..."
docker compose down

echo "3. Desabilitando UFW (firewall)..."
sudo ufw disable

echo "4. Isolando rede Docker..."
docker network disconnect bridge caddy 2>/dev/null || true
docker network disconnect borgstack_external caddy 2>/dev/null || true

echo ""
echo "✅ Sistema isolado com sucesso"
echo ""
echo "PRÓXIMOS PASSOS:"
echo "1. Investigar logs: ls -lt volumes/*/logs/"
echo "2. Analisar backups: ls -lt /backups/"
echo "3. Verificar integridade: ./scripts/verify-integrity.sh"
echo "4. Restaurar quando seguro: docker compose up -d"
```text

### 8.3. Análise Forense

```bash
#!/bin/bash
# Script: forensic-analysis.sh

FORENSICS_DIR="/tmp/forensics-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$FORENSICS_DIR"

echo "=== Análise Forense - BorgStack ==="
echo "Salvando evidências em: $FORENSICS_DIR"
echo ""

# 1. Snapshot de containers
echo "1. Capturando estado de containers..."
docker compose ps > "$FORENSICS_DIR/containers-state.txt"
docker compose config > "$FORENSICS_DIR/docker-compose-config.yml"

# 2. Logs completos
echo "2. Coletando logs..."
for service in $(docker compose ps --services); do
    docker compose logs "$service" > "$FORENSICS_DIR/logs-$service.txt" 2>&1
done

# 3. Conexões de rede
echo "3. Analisando conexões de rede..."
sudo netstat -tulpn > "$FORENSICS_DIR/network-connections.txt"
docker network inspect borgstack_external > "$FORENSICS_DIR/network-external.json"
docker network inspect borgstack_internal > "$FORENSICS_DIR/network-internal.json"

# 4. Processos
echo "4. Listando processos..."
ps auxf > "$FORENSICS_DIR/processes.txt"

# 5. Arquivos modificados recentemente
echo "5. Detectando alterações em arquivos..."
find . -type f -mtime -1 ! -path "*/node_modules/*" ! -path "*/.git/*" \
    > "$FORENSICS_DIR/recent-file-changes.txt"

# 6. Hash de arquivos críticos
echo "6. Calculando hashes..."
sha256sum .env docker-compose.yml Caddyfile > "$FORENSICS_DIR/file-hashes.txt" 2>/dev/null

# 7. Compactar evidências
echo "7. Compactando evidências..."
tar czf "$FORENSICS_DIR.tar.gz" "$FORENSICS_DIR"

echo ""
echo "✅ Análise forense completa"
echo "📦 Evidências salvas em: $FORENSICS_DIR.tar.gz"
echo ""
echo "PRESERVAR EVIDÊNCIAS:"
echo "  cp $FORENSICS_DIR.tar.gz /secure/location/"
echo "  chmod 400 /secure/location/forensics-*.tar.gz"
```text

---

## Checklist de Segurança

### 9.1. Checklist Pré-Deploy

```markdown
# Checklist de Segurança - Pré-Deploy

## Configuração Inicial
- [ ] .env NÃO está commitado no Git
- [ ] .env tem permissões 600 (somente proprietário)
- [ ] Todas as senhas têm 16+ caracteres
- [ ] Senhas foram geradas aleatoriamente (não reutilizadas)
- [ ] Chaves de criptografia têm 32+ caracteres

## Rede
- [ ] Rede borgstack_internal configurada como `internal: true`
- [ ] Apenas Caddy expõe portas ao host (80, 443)
- [ ] Firewall UFW instalado e configurado
- [ ] SSH tem autenticação por chave (não senha)

## Containers
- [ ] Todos containers executam como usuário não-root
- [ ] Limites de CPU e memória configurados
- [ ] Health checks configurados
- [ ] Scan de vulnerabilidades executado (Trivy)

## SSL/TLS
- [ ] Caddy configurado com email válido para Let's Encrypt
- [ ] DNS configurado corretamente para todos domínios
- [ ] TLS mínimo configurado (1.2 ou 1.3)
- [ ] HSTS habilitado

## Backup
- [ ] Duplicati configurado e testado
- [ ] Backup criptografado
- [ ] Chave de criptografia armazenada separadamente
- [ ] Teste de restauração bem-sucedido
- [ ] Backup off-site configurado

## Monitoramento
- [ ] Logs centralizados
- [ ] Alertas de segurança configurados
- [ ] Monitoramento de certificados SSL
- [ ] Logs de auditoria habilitados

## Compliance
- [ ] Política de privacidade criada
- [ ] Termos de uso criados
- [ ] Política de retenção de dados definida
- [ ] Processo de exclusão de dados documentado
```text

### 9.2. Checklist Mensal de Segurança

```markdown
# Checklist de Segurança - Mensal

## Atualizações
- [ ] Verificar atualizações de imagens Docker
- [ ] Aplicar patches de segurança
- [ ] Atualizar dependências

## Credenciais
- [ ] Revisar usuários ativos
- [ ] Desabilitar usuários inativos
- [ ] Verificar permissões de acesso

## Backups
- [ ] Testar restauração de backup
- [ ] Verificar integridade de backups
- [ ] Confirmar backups off-site

## Logs
- [ ] Revisar logs de segurança
- [ ] Analisar tentativas de login falhas
- [ ] Identificar padrões suspeitos

## Vulnerabilidades
- [ ] Executar scan de vulnerabilidades
- [ ] Remediar vulnerabilidades HIGH/CRITICAL
- [ ] Documentar vulnerabilidades aceitas

## Certificados
- [ ] Verificar expiração de certificados
- [ ] Testar renovação automática
- [ ] Validar cadeia de certificados

## Compliance
- [ ] Revisar logs de auditoria
- [ ] Gerar relatório de conformidade
- [ ] Executar limpeza de dados antigos
```text

### 9.3. Checklist Trimestral de Segurança

```markdown
# Checklist de Segurança - Trimestral

## Rotação de Credenciais
- [ ] Rotacionar senha PostgreSQL
- [ ] Rotacionar senha MongoDB
- [ ] Rotacionar senha Redis
- [ ] Rotacionar API keys
- [ ] Rotacionar chaves de criptografia

## Auditoria
- [ ] Executar auditoria de segurança completa
- [ ] Revisar configurações de firewall
- [ ] Revisar políticas de acesso
- [ ] Atualizar documentação de segurança

## Testes
- [ ] Teste de penetração (pen test)
- [ ] Teste de recuperação de desastres
- [ ] Teste de plano de resposta a incidentes
- [ ] Validação de backups off-site

## Treinamento
- [ ] Treinar equipe em práticas de segurança
- [ ] Revisar plano de resposta a incidentes
- [ ] Simular cenário de incidente

## Compliance
- [ ] Revisar conformidade LGPD
- [ ] Atualizar documentação de compliance
- [ ] Gerar relatório executivo de segurança
```text

---

## Recursos Adicionais

### Ferramentas Recomendadas

- **Trivy**: Scan de vulnerabilidades em imagens Docker
- **fail2ban**: Proteção contra ataques de força bruta
- **Wazuh**: SIEM e detecção de intrusão
- **Vault**: Gerenciamento de secrets (alternativa ao .env)
- **ClamAV**: Antivírus para scan de uploads

### Referências

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [LGPD - Lei 13.709/2018](http://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)

---

**Este guia de segurança deve ser revisado e atualizado trimestralmente.**

**Última atualização**: 2025-10-08
