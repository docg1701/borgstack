# Arquitetura Multi-Tenant BorgStack - Pós-MVP

**Versão**: 1.0
**Data**: 2025-10-09
**Status**: Planejamento Pós-MVP

---

## Sumário Executivo

Este documento descreve a arquitetura de segurança e controle de acesso multi-tenant para deployments BorgStack em ambientes de produção. A arquitetura foi projetada para cenários onde **cada cliente possui seu próprio VPS**, com usuários organizados em **setores/departamentos** da empresa cliente, cada um com acesso controlado a diferentes workflows e aplicações.

### Princípios Fundamentais

1. **Isolamento de Rede**: Serviços internos acessíveis apenas via VPN (NetBird)
2. **Exposição Mínima**: Apenas Chatwoot e Lowcoder expostos publicamente via HTTPS
3. **Autenticação Forte**: OAuth Google (Lowcoder) + 2FA TOTP (Chatwoot)
4. **Controle de Acesso**: RBAC por departamento com apps separados no Lowcoder
5. **Zero-Trust para Admin**: Acesso administrativo completo apenas via VPN

---

## Arquitetura de Rede

### Topologia de Rede

```
┌─────────────────────────────────────────────────────────────────┐
│                      INTERNET (Público)                         │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        │ HTTPS (443)
                        │
        ┌───────────────▼────────────────┐
        │   Caddy Reverse Proxy          │
        │   (borgstack_external network) │
        └───────┬────────────────┬───────┘
                │                │
    ┌───────────▼─────┐    ┌────▼──────────────┐
    │   Chatwoot      │    │   Lowcoder        │
    │   (Público)     │    │   (OAuth Google)  │
    │   2FA TOTP      │    │   Modo ENTERPRISE │
    └─────────────────┘    └───────────────────┘
                │                │
                │                │
        ┌───────▼────────────────▼───────────────────────────┐
        │       borgstack_internal network                   │
        │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐ │
        │  │   n8n    │  │ Directus │  │  Evolution API   │ │
        │  │ (VPN)    │  │  (VPN)   │  │      (VPN)       │ │
        │  └──────────┘  └──────────┘  └──────────────────┘ │
        │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐ │
        │  │FileFlows │  │SeaweedFS │  │    Duplicati     │ │
        │  │  (VPN)   │  │  (VPN)   │  │      (VPN)       │ │
        │  └──────────┘  └──────────┘  └──────────────────┘ │
        │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐ │
        │  │PostgreSQL│  │ MongoDB  │  │      Redis       │ │
        │  │ (interno)│  │ (interno)│  │    (interno)     │ │
        │  └──────────┘  └──────────┘  └──────────────────┘ │
        └────────────────────────────────────────────────────┘
                        ▲
                        │
                        │ NetBird VPN (WireGuard P2P)
                        │ (100.64.0.0/10 range)
                        │
                ┌───────▼──────────┐
                │  SysAdmin Only   │
                │  Acesso Total    │
                └──────────────────┘
```

### Estrutura de Domínios

```yaml
# Domínios Públicos (HTTPS via Caddy)
chat.meuvps.duckdns.org:
  - Serviço: Chatwoot (atendimento ao cliente)
  - Acesso: Público (com 2FA TOTP)
  - Rede: borgstack_external + borgstack_internal

app.meuvps.duckdns.org:
  - Serviço: Lowcoder (dashboards departamentais)
  - Acesso: OAuth Google (usuários pré-cadastrados)
  - Rede: borgstack_external + borgstack_internal

meuvps.duckdns.org:
  - Serviço: Site institucional da empresa
  - Hospedado: Outro VPS (fora do BorgStack)
  - Propósito: Marketing, informações corporativas

# Serviços Internos (VPN apenas)
n8n.internal:
  - IP VPN: 100.64.0.x:5678
  - Acesso: SysAdmin via NetBird VPN
  - Rede: borgstack_internal

directus.internal:
  - IP VPN: 100.64.0.x:8055
  - Acesso: SysAdmin via NetBird VPN
  - Rede: borgstack_internal

evolution.internal:
  - IP VPN: 100.64.0.x:8080
  - Acesso: SysAdmin via NetBird VPN
  - Rede: borgstack_internal

fileflows.internal:
  - IP VPN: 100.64.0.x:5000
  - Acesso: SysAdmin via NetBird VPN
  - Rede: borgstack_internal

duplicati.internal:
  - IP VPN: 100.64.0.x:8200
  - Acesso: SysAdmin via NetBird VPN
  - Rede: borgstack_internal
```

---

## Configuração de Autenticação e Controle de Acesso

### 1. Chatwoot - Atendimento Público com 2FA

#### Configuração de Autenticação

**Tipo**: Email/Senha + 2FA TOTP (Google Authenticator)

**Variáveis de Ambiente**:
```yaml
chatwoot:
  environment:
    # Encryption Keys (CRITICAL - Necessário para 2FA)
    ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY: "${CHATWOOT_ACTIVE_RECORD_PRIMARY_KEY}"
    ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY: "${CHATWOOT_ACTIVE_RECORD_DETERMINISTIC_KEY}"
    ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT: "${CHATWOOT_ACTIVE_RECORD_KEY_DERIVATION_SALT}"

    # Signup Control
    ENABLE_ACCOUNT_SIGNUP: "false"  # Apenas admin cria contas

    # Frontend URL
    FRONTEND_URL: "https://chat.meuvps.duckdns.org"
```

**Processo de Onboarding**:
1. SysAdmin cria conta do funcionário no Chatwoot Admin Panel
2. Define role: Agent, Administrator, etc.
3. Funcionário recebe email com credenciais temporárias
4. No primeiro login, funcionário ativa 2FA via QR Code
5. Google Authenticator gera códigos TOTP de 6 dígitos

**Acesso ao Chatwoot**:
- **Diretamente**: `https://chat.meuvps.duckdns.org`
- **Via Dashboard Lowcoder**: Card clicável "Chatwoot Atendimento"

#### Geração de Chaves de Criptografia

```bash
# Gerar as 3 chaves necessárias para 2FA
CHATWOOT_ACTIVE_RECORD_PRIMARY_KEY=$(openssl rand -hex 32)
CHATWOOT_ACTIVE_RECORD_DETERMINISTIC_KEY=$(openssl rand -hex 32)
CHATWOOT_ACTIVE_RECORD_KEY_DERIVATION_SALT=$(openssl rand -hex 32)

# Adicionar ao .env
cat >> .env <<EOF
CHATWOOT_ACTIVE_RECORD_PRIMARY_KEY=$CHATWOOT_ACTIVE_RECORD_PRIMARY_KEY
CHATWOOT_ACTIVE_RECORD_DETERMINISTIC_KEY=$CHATWOOT_ACTIVE_RECORD_DETERMINISTIC_KEY
CHATWOOT_ACTIVE_RECORD_KEY_DERIVATION_SALT=$CHATWOOT_ACTIVE_RECORD_KEY_DERIVATION_SALT
EOF
```

---

### 2. Lowcoder - Dashboards Departamentais com OAuth Google

#### Modo de Operação: ENTERPRISE

**Características**:
- Workspace único compartilhado por todos os usuários
- Sem signup automático via OAuth
- Admin pré-cadastra usuários manualmente
- Controle de acesso por grupos (departamentos)
- Apps separados por departamento

#### Variáveis de Ambiente

```yaml
lowcoder-api-service:
  environment:
    # Workspace Configuration
    LOWCODER_WORKSPACE_MODE: "ENTERPRISE"
    LOWCODER_CREATE_WORKSPACE_ON_SIGNUP: "false"

    # Signup Control - CRITICAL
    LOWCODER_ENABLE_USER_SIGN_UP: "false"  # ← Bloqueia signup automático
    LOWCODER_EMAIL_SIGNUP_ENABLED: "false"  # ← Remove botão "Sign Up"

    # Authentication
    LOWCODER_EMAIL_AUTH_ENABLED: "true"  # Admin pode usar email/senha

    # Security
    LOWCODER_MARKETPLACE_PRIVATE_MODE: "true"

    # Public URL
    LOWCODER_PUBLIC_URL: "https://app.meuvps.duckdns.org"

    # Database & Encryption
    LOWCODER_MONGODB_URL: "mongodb://mongodb:27017/lowcoder?authSource=admin"
    LOWCODER_REDIS_URL: "redis://redis:6379"
    LOWCODER_DB_ENCRYPTION_PASSWORD: "${LOWCODER_ENCRYPTION_PASSWORD}"
    LOWCODER_DB_ENCRYPTION_SALT: "${LOWCODER_ENCRYPTION_SALT}"

    # SMTP (opcional, para convites via email)
    LOWCODER_ADMIN_SMTP_HOST: "${SMTP_HOST}"
    LOWCODER_ADMIN_SMTP_PORT: "587"
    LOWCODER_ADMIN_SMTP_USERNAME: "${SMTP_USERNAME}"
    LOWCODER_ADMIN_SMTP_PASSWORD: "${SMTP_PASSWORD}"
    LOWCODER_ADMIN_SMTP_AUTH: "true"
    LOWCODER_ADMIN_SMTP_STARTTLS_ENABLED: "true"
    LOWCODER_EMAIL_NOTIFICATIONS_SENDER: "noreply@meuvps.duckdns.org"
```

#### Estrutura de Grupos (Departamentos)

```yaml
Grupos no Lowcoder:
  - SysAdmins:
      Membros: galvani@admin.com
      Role: Admin
      Apps: Dashboard Admin (acesso total via VPN)

  - Departamento Financeiro:
      Membros: joao@minhaempresa.com, maria@minhaempresa.com
      Role: Member
      Apps: Dashboard Financeiro
      Cards Visíveis:
        - Chatwoot Atendimento
        - Workflows N8N Financeiros
        - Relatórios Directus

  - Departamento Operações:
      Membros: pedro@minhaempresa.com, ana@minhaempresa.com
      Role: Member
      Apps: Dashboard Operações
      Cards Visíveis:
        - Chatwoot Atendimento
        - Workflows N8N Operacionais
        - FileFlows Media Processing

  - Departamento Marketing:
      Membros: lucas@minhaempresa.com, carla@minhaempresa.com
      Role: Member
      Apps: Dashboard Marketing
      Cards Visíveis:
        - Chatwoot Atendimento
        - Workflows N8N Marketing
        - Directus Content Management
```

#### Processo de Onboarding de Usuários

**Passo 1: Admin Pré-Cadastra Usuário**
1. SysAdmin acessa `https://app.meuvps.duckdns.org`
2. Login como Admin (email/senha ou OAuth)
3. Navega para: **Settings → Members → "+ Add User"**
4. Preenche:
   - Email: `joao@minhaempresa.com` (DEVE ser email Google)
   - Name: João Silva
   - Group: Departamento Financeiro
5. (Opcional) Envia email de convite via SMTP

**Passo 2: Funcionário Faz Primeiro Login**
1. Funcionário acessa `https://app.meuvps.duckdns.org`
2. Clica em **"Sign in with Google"**
3. Seleciona conta Google `joao@minhaempresa.com`
4. **Validação Lowcoder**:
   - ✅ Email existe no sistema → Login permitido
   - ❌ Email não existe → Erro "Account not found"
5. Redirecionado para Dashboard do Departamento Financeiro

**Passo 3: Usuário Vê Apenas Seus Apps**
- Dashboard Financeiro (criado especificamente para o grupo)
- Cards clicáveis filtrados por departamento
- Sem acesso a apps de outros departamentos

#### Configuração OAuth Google

**Google Cloud Console**:
1. Criar projeto no Google Cloud Console
2. Habilitar Google+ API
3. Criar OAuth 2.0 Client ID:
   - Application type: Web application
   - Authorized redirect URIs:
     ```
     https://app.meuvps.duckdns.org/api/oauth2/callback
     ```
4. Copiar Client ID e Client Secret

**Lowcoder Admin Panel**:
1. Login como Admin
2. Navega para: **Settings → Auth Providers → Add Provider**
3. Seleciona: **Google**
4. Preenche:
   - Client ID: `[copiado do Google Cloud Console]`
   - Client Secret: `[copiado do Google Cloud Console]`
   - Scope: `openid email profile`
5. Salva configuração

---

### 3. Dashboard Admin - Acesso Total via VPN

#### Características

- **Acesso exclusivo**: Apenas SysAdmin via NetBird VPN
- **Funcionalidades**:
  - Acesso direto a todos os serviços internos (N8N, Directus, Evolution, etc.)
  - Cards para cada serviço com links `http://100.64.0.x:PORT`
  - Monitoramento de saúde dos containers
  - Execução de workflows administrativos
  - Gerenciamento de backups (Duplicati)

#### Estrutura de Cards (Dashboard Admin)

```javascript
// Dashboard Admin (Lowcoder App)
// Compartilhado apenas com grupo "SysAdmins"

Cards:
  - Chatwoot:
      URL: https://chat.meuvps.duckdns.org
      Icon: chat
      Color: blue

  - N8N Workflows:
      URL: http://100.64.0.1:5678
      Icon: workflow
      Color: orange
      VPN: Required

  - Directus CMS:
      URL: http://100.64.0.1:8055
      Icon: database
      Color: purple
      VPN: Required

  - Evolution API:
      URL: http://100.64.0.1:8080
      Icon: whatsapp
      Color: green
      VPN: Required

  - FileFlows:
      URL: http://100.64.0.1:5000
      Icon: video
      Color: red
      VPN: Required

  - SeaweedFS S3:
      URL: http://100.64.0.1:8333
      Icon: storage
      Color: teal
      VPN: Required

  - Duplicati Backups:
      URL: http://100.64.0.1:8200
      Icon: backup
      Color: brown
      VPN: Required
```

---

## NetBird VPN - Acesso Administrativo

### Por Que NetBird?

**NetBird** é uma plataforma open-source de Zero Trust Networking que cria redes WireGuard peer-to-peer seguras e de alto desempenho.

**Vantagens**:
- ✅ Open-source (BSD 3-Clause License)
- ✅ Auto-hospedado com controle total
- ✅ Peer-to-peer WireGuard com WebRTC ICE (NAT traversal automático)
- ✅ Interface Web Admin inclusa (Dashboard UI)
- ✅ Setup Keys para provisionamento em massa
- ✅ API pública para automação
- ✅ SSO/MFA integrado (Zitadel, Auth0, Keycloak, Google Workspace, etc.)
- ✅ Access Control Lists (ACL) granular
- ✅ Posture Checks (verificação de estado do dispositivo)
- ✅ DNS privado (MagicDNS)
- ✅ Sem limites de dispositivos ou usuários
- ✅ Gratuito e sem vendor lock-in

### Arquitetura NetBird

```
┌──────────────────────────────────────────────────────────────┐
│                   NetBird Management Server                  │
│                      (VPS BorgStack)                         │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Management Service (33073) - gRPC API                 │ │
│  │  Signal Service (10000) - P2P Coordination             │ │
│  │  Dashboard UI (80/443) - Web Admin Interface           │ │
│  │  Coturn (STUN/TURN) - NAT Traversal                    │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  IP Range: 100.64.0.0/10 (CGNAT range)                      │
│  Auth: SSO Integration (opcional)                           │
└──────────────────┬───────────────────────────────────────────┘
                   │
                   │ WireGuard P2P Mesh Network
                   │ (Direct connections via WebRTC ICE)
                   │
        ┌──────────▼──────────┐
        │  SysAdmin Laptop    │
        │  IP: 100.64.0.2     │
        │  Hostname: admin    │
        │                     │
        │  Acesso direto a:   │
        │  - VPS: 100.64.0.1  │
        │    - n8n:5678       │
        │    - directus:8055  │
        │    - evolution:8080 │
        │    - fileflows:5000 │
        │    - duplicati:8200 │
        └─────────────────────┘
```

### Instalação e Configuração NetBird

#### Passo 1: Instalar NetBird Management Server no VPS

NetBird oferece um **script automatizado** que configura toda a infraestrutura via Docker Compose.

```bash
# Definir domínio público do NetBird
export NETBIRD_DOMAIN=vpn.meuvps.duckdns.org

# Download e executar script de instalação com Zitadel (IdP integrado)
curl -fsSL https://github.com/netbirdio/netbird/releases/latest/download/getting-started-with-zitadel.sh | bash
```

**O que o script faz automaticamente**:
- ✅ Cria `docker-compose.yml` com todos os serviços
- ✅ Configura Management Service (gRPC API)
- ✅ Configura Signal Service (coordenação P2P)
- ✅ Configura Coturn (STUN/TURN para NAT traversal)
- ✅ Configura Zitadel (IdP para SSO - opcional)
- ✅ Configura Dashboard UI (interface web admin)
- ✅ Configura Caddy como reverse proxy com Let's Encrypt
- ✅ Gera certificados SSL automaticamente

**Estrutura de diretórios criada**:
```
/root/netbird/
├── docker-compose.yml
├── Caddyfile
├── management.json
├── turnserver.conf
├── zitadel.env
├── dashboard.env
└── relay.env
```

#### Passo 2: Verificar Serviços Iniciados

```bash
# Verificar containers em execução
docker compose ps

# Output esperado:
# NAME                STATUS              PORTS
# netbird-management  Up 2 minutes        0.0.0.0:33073->33073/tcp
# netbird-signal      Up 2 minutes        0.0.0.0:10000->10000/tcp
# netbird-dashboard   Up 2 minutes
# coturn              Up 2 minutes        0.0.0.0:3478->3478/tcp, 0.0.0.0:3478->3478/udp
# caddy               Up 2 minutes        0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
# zitadel             Up 2 minutes        (opcional se usar SSO)

# Verificar logs
docker compose logs -f netbird-management
```

#### Passo 3: Acessar Dashboard Web Admin

```bash
# Acessar via navegador
https://vpn.meuvps.duckdns.org
```

**Primeiro acesso**:
1. Dashboard vai solicitar login (se Zitadel habilitado)
2. Criar conta admin inicial
3. Dashboard mostra:
   - **Peers**: Dispositivos conectados
   - **Setup Keys**: Chaves para provisionamento
   - **Users**: Usuários (se SSO habilitado)
   - **Groups**: Grupos de acesso
   - **Network Routes**: Rotas de rede
   - **Access Control**: Regras de firewall
   - **DNS**: Configuração MagicDNS

#### Passo 4: Criar Setup Key (Chave de Provisionamento)

**Via Dashboard UI**:
1. Acesse `https://vpn.meuvps.duckdns.org`
2. Navegue para **Setup Keys**
3. Clique em **+ Add Key**
4. Configure:
   - Name: `sysadmin-key`
   - Type: `Reusable` (permite múltiplos devices)
   - Expiration: `Never` ou `30 days`
   - Auto Groups: `admins` (opcional)
5. Copie a chave gerada (ex: `A1B2C3D4-E5F6-G7H8-I9J0-K1L2M3N4O5P6`)

**Via API** (alternativa):
```bash
# Obter token de API no Dashboard: Settings → API Keys
NETBIRD_API_TOKEN="nbp_xxx"

# Criar setup key
curl -X POST https://vpn.meuvps.duckdns.org/api/setup-keys \
  -H "Authorization: Token ${NETBIRD_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "sysadmin-key",
    "type": "reusable",
    "expires_in": 0,
    "auto_groups": ["admins"]
  }'
```

#### Passo 5: Conectar Cliente (Laptop SysAdmin)

**Linux/macOS**:
```bash
# Instalar NetBird client
curl -fsSL https://pkgs.netbird.io/install.sh | sh

# Conectar usando setup key
sudo netbird up --setup-key A1B2C3D4-E5F6-G7H8-I9J0-K1L2M3N4O5P6

# OU conectar usando SSO (se Zitadel habilitado)
sudo netbird up
# Abrirá navegador para login via Zitadel
```

**Windows**:
1. Download NetBird: https://github.com/netbirdio/netbird/releases/latest
2. Instalar `netbird-installer.exe`
3. Abrir PowerShell como Admin:
   ```powershell
   netbird up --setup-key A1B2C3D4-E5F6-G7H8-I9J0-K1L2M3N4O5P6
   ```

**Docker** (para servidores headless):
```bash
docker run -d --name netbird-client \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_ADMIN \
  --cap-add=SYS_RESOURCE \
  -e NB_SETUP_KEY=A1B2C3D4-E5F6-G7H8-I9J0-K1L2M3N4O5P6 \
  -v netbird-client:/etc/netbird \
  netbirdio/netbird:latest
```

#### Passo 6: Verificar Conexão

```bash
# No laptop do SysAdmin
netbird status

# Output esperado:
# OS: darwin/arm64
# Daemon version: 0.30.0
# CLI version: 0.30.0
# Management: Connected
# Signal: Connected
# Relays: 2/2 Available
# FQDN: admin.netbird.cloud
# NetBird IP: 100.64.0.2/16
# Interface type: Kernel
# Peers count: 1/1 Connected

# Verificar detalhes dos peers
netbird status -d

# Testar conectividade ao VPS
ping 100.64.0.1  # IP NetBird do VPS

# Testar acesso a N8N
curl http://100.64.0.1:5678/healthz
```

---

### Expor Serviços Apenas na VPN

**Atualizar `docker-compose.yml`**:

```yaml
services:
  n8n:
    ports:
      - "100.64.0.1:5678:5678"  # ← Bind apenas no IP VPN
    networks:
      - internal
    # REMOVER network 'external'

  directus:
    ports:
      - "100.64.0.1:8055:8055"
    networks:
      - internal

  evolution:
    ports:
      - "100.64.0.1:8080:8080"
    networks:
      - internal

  fileflows:
    ports:
      - "100.64.0.1:5000:5000"
    networks:
      - internal

  duplicati:
    ports:
      - "100.64.0.1:8200:8200"
    networks:
      - internal
```

**Importante**: Substituir `100.64.0.1` pelo IP VPN real do servidor (verificar com `netbird status | grep "NetBird IP"`).

---

## Atualização do Caddyfile - Apenas Chatwoot e Lowcoder

### Remover Blocos de Serviços Internos

**Arquivo**: `config/caddy/Caddyfile`

**REMOVER as seguintes seções**:
```caddyfile
# REMOVER: N8N
n8n.{$DOMAIN} { ... }

# REMOVER: Evolution API
evolution.{$DOMAIN} { ... }

# REMOVER: Directus
directus.{$DOMAIN} { ... }

# REMOVER: FileFlows
fileflows.{$DOMAIN} { ... }

# REMOVER: Duplicati
duplicati.{$DOMAIN} { ... }
```

**MANTER apenas**:
```caddyfile
chatwoot.{$DOMAIN} { ... }
lowcoder.{$DOMAIN} { ... }
# NetBird expõe seu próprio Caddy via script de instalação
# Não precisa adicionar bloco vpn.{$DOMAIN} no Caddyfile do BorgStack
```

### Caddyfile Final Simplificado

```caddyfile
# ============================================================================
# BorgStack - Caddy Reverse Proxy Configuration (Pós-MVP Multi-Tenant)
# ============================================================================

{
    email {$EMAIL}
}

# ----------------------------------------------------------------------------
# Chatwoot - Customer Communication Platform (PÚBLICO)
# ----------------------------------------------------------------------------
chatwoot.{$DOMAIN} {
    reverse_proxy chatwoot:3000

    header {
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
}

# ----------------------------------------------------------------------------
# Lowcoder - Low-Code Application Builder (PÚBLICO com OAuth)
# ----------------------------------------------------------------------------
lowcoder.{$DOMAIN} {
    reverse_proxy lowcoder-frontend:3000

    header {
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
}

# ============================================================================
# NetBird VPN Management Server
# ============================================================================
# NetBird roda seu próprio Caddy via script de instalação
# Domínio: vpn.meuvps.duckdns.org (separado do Caddy do BorgStack)
# Não adicionar configuração aqui
#
# Serviços Internos NÃO são expostos via Caddy
# Acesso via VPN apenas (http://100.64.0.x:PORT)
# ============================================================================
```

---

## Fluxo de Trabalho Completo

### Cenário 1: Cliente Final Acessa Chatwoot

**Ator**: Cliente externo (sem cadastro)

**Fluxo**:
1. Cliente acessa `https://chat.meuvps.duckdns.org`
2. Widget de chat carrega na página
3. Cliente envia mensagem
4. Agente (funcionário) logado no Chatwoot responde
5. Comunicação bidirecional em tempo real

**Autenticação do Agente**:
1. Agente acessa `https://chat.meuvps.duckdns.org/app/login`
2. Insere email/senha
3. Chatwoot solicita código 2FA (Google Authenticator)
4. Agente insere código de 6 dígitos
5. Acesso liberado ao painel de atendimento

---

### Cenário 2: Funcionário do Departamento Financeiro Acessa Dashboard

**Ator**: João Silva (joao@minhaempresa.com) - Departamento Financeiro

**Fluxo**:
1. João acessa `https://app.meuvps.duckdns.org`
2. Página de login mostra apenas botão **"Sign in with Google"**
3. João clica no botão
4. Redirecionado para tela de login Google
5. Seleciona conta `joao@minhaempresa.com`
6. Google valida e retorna token OAuth
7. Lowcoder valida:
   - Email `joao@minhaempresa.com` existe no banco? ✅ Sim
   - Grupo atribuído? ✅ Departamento Financeiro
8. João é redirecionado para **Dashboard Financeiro**
9. João vê apenas cards permitidos:
   - Card "Chatwoot Atendimento" (abre nova aba)
   - Card "Aprovar Notas Fiscais" (executa workflow N8N)
   - Card "Relatório Mensal" (consulta Directus)

**João NÃO vê**:
- Dashboard Admin (exclusivo SysAdmins)
- Dashboard Operações
- Dashboard Marketing

---

### Cenário 3: SysAdmin Acessa Dashboard Admin via VPN

**Ator**: Galvani (galvani@admin.com) - SysAdmin

**Fluxo**:
1. Galvani conecta à VPN NetBird no laptop:
   ```bash
   sudo netbird up --setup-key A1B2C3D4-E5F6-G7H8-I9J0-K1L2M3N4O5P6
   ```
2. IP VPN atribuído: `100.64.0.2`
3. Galvani acessa `https://app.meuvps.duckdns.org`
4. Faz login via OAuth Google ou email/senha
5. Lowcoder valida grupo: ✅ SysAdmins
6. Galvani é redirecionado para **Dashboard Admin**
7. Galvani vê todos os cards:
   - Chatwoot (https://chat.meuvps.duckdns.org)
   - N8N (http://100.64.0.1:5678) ← VPN apenas
   - Directus (http://100.64.0.1:8055) ← VPN apenas
   - Evolution (http://100.64.0.1:8080) ← VPN apenas
   - FileFlows (http://100.64.0.1:5000) ← VPN apenas
   - Duplicati (http://100.64.0.1:8200) ← VPN apenas

**Acesso Direto aos Serviços**:
```bash
# Galvani pode acessar diretamente via navegador
http://100.64.0.1:5678  # N8N
http://100.64.0.1:8055  # Directus
http://100.64.0.1:8080  # Evolution API
```

---

### Cenário 4: Tentativa de Acesso Não Autorizado

**Ator**: Maria Silva (maria@email.pessoal.com) - Usuário NÃO cadastrado

**Fluxo**:
1. Maria acessa `https://app.meuvps.duckdns.org`
2. Clica em **"Sign in with Google"**
3. Seleciona conta `maria@email.pessoal.com`
4. Google valida e retorna token OAuth
5. Lowcoder valida:
   - Email `maria@email.pessoal.com` existe no banco? ❌ Não
   - `LOWCODER_ENABLE_USER_SIGN_UP=false` → Signup bloqueado
6. **Erro exibido**: "Account not found. Please contact your administrator."
7. Maria não consegue acessar

---

## Criação de Dashboards Departamentais no Lowcoder

### Dashboard Financeiro (Exemplo Completo)

**Passo 1: Criar App**
1. Login como Admin no Lowcoder
2. **Apps → + New → Create from blank**
3. Nome: `Dashboard Financeiro`
4. Descrição: `Dashboard para Departamento Financeiro`

**Passo 2: Criar Cards Clicáveis**

**Layout**: Grid com 2 colunas, 3 linhas

**Card 1: Chatwoot Atendimento**
```javascript
// Component: Button (styled como Card)
Text: "Chatwoot Atendimento"
Icon: "chat"
Color: "#1890ff"

// Event Handler: onClick
Action: Go to URL
URL: https://chat.meuvps.duckdns.org
Target: New tab
```

**Card 2: Aprovar Notas Fiscais (Workflow N8N)**
```javascript
// Component: Button
Text: "Aprovar Notas Fiscais"
Icon: "file-check"
Color: "#52c41a"

// Event Handler: onClick
Action: Run query
Query: RestAPI_TriggerN8N

// Query Configuration: RestAPI_TriggerN8N
Method: POST
URL: http://n8n:5678/webhook/aprovar-notas-fiscais
Headers:
  Content-Type: application/json
Body:
{
  "departamento": "financeiro",
  "usuario": "{{ currentUser.email }}",
  "timestamp": "{{ new Date().toISOString() }}"
}

// Success notification
message.success("Workflow de aprovação iniciado!")
```

**Card 3: Relatório Mensal (Directus)**
```javascript
// Component: Button
Text: "Relatório Mensal"
Icon: "file-text"
Color: "#722ed1"

// Event Handler: onClick
Action: Run query
Query: Directus_RelatorioFinanceiro

// Query Configuration: Directus_RelatorioFinanceiro
Method: GET
URL: http://directus:8055/items/relatorios_financeiros
Headers:
  Authorization: Bearer {{ directus_token.value }}
Query Parameters:
  filter[departamento][_eq]: financeiro
  filter[mes][_eq]: {{ utils.getCurrentMonth() }}

// Success: Display data in table
Table_Relatorios.data = Directus_RelatorioFinanceiro.data.data
```

**Passo 3: Compartilhar com Grupo**
1. Clicar em **Share** (canto superior direito)
2. Selecionar **Share to groups**
3. Adicionar grupo: `Departamento Financeiro`
4. Permission level: `Viewer` (somente visualização)
5. Salvar

**Resultado**: Apenas usuários do grupo "Departamento Financeiro" veem este app.

---

### Dashboard Admin (Exemplo Completo)

**Cards com Acesso via VPN**:

```javascript
// Card: N8N Workflows
Text: "N8N Workflows"
URL: http://100.64.0.1:5678
Badge: "VPN Required"
Color: "#ff6b6b"

onClick: () => {
  if (!utils.isVPNConnected()) {
    message.warn("Você precisa estar conectado à VPN para acessar este serviço");
    return;
  }
  utils.openUrl("http://100.64.0.1:5678", { newTab: true });
}

// Helper function (JavaScript Query)
function isVPNConnected() {
  // Verificar se consegue alcançar serviço interno via NetBird VPN
  try {
    fetch("http://100.64.0.1:5678/healthz", { method: "HEAD", timeout: 2000 });
    return true;
  } catch (e) {
    return false;
  }
}

// Nota: Substituir 100.64.0.1 pelo IP real do VPS obtido via:
// netbird status | grep "NetBird IP"
```

---

## Checklist de Implementação Pós-MVP

### Fase 1: Preparação de Ambiente

- [ ] **Domínios DNS configurados**:
  - [ ] `chat.meuvps.duckdns.org` → IP do VPS
  - [ ] `app.meuvps.duckdns.org` → IP do VPS
  - [ ] `vpn.meuvps.duckdns.org` → IP do VPS

- [ ] **Variáveis de ambiente criadas** (`.env`):
  - [ ] `CHATWOOT_ACTIVE_RECORD_PRIMARY_KEY`
  - [ ] `CHATWOOT_ACTIVE_RECORD_DETERMINISTIC_KEY`
  - [ ] `CHATWOOT_ACTIVE_RECORD_KEY_DERIVATION_SALT`
  - [ ] `LOWCODER_ENCRYPTION_PASSWORD`
  - [ ] `LOWCODER_ENCRYPTION_SALT`
  - [ ] `LOWCODER_PUBLIC_URL=https://app.meuvps.duckdns.org`
  - [ ] `DOMAIN=meuvps.duckdns.org`
  - [ ] `EMAIL=admin@meuvps.duckdns.org`

### Fase 2: Configuração de Serviços

- [ ] **Atualizar `docker-compose.yml`**:
  - [ ] Configurar Chatwoot com chaves de criptografia
  - [ ] Configurar Lowcoder modo ENTERPRISE
  - [ ] Remover networks `external` de serviços internos
  - [ ] Bind ports apenas no IP VPN (100.64.0.x)

- [ ] **Atualizar `config/caddy/Caddyfile`**:
  - [ ] Remover blocos: n8n, evolution, directus, fileflows, duplicati
  - [ ] Manter apenas: chatwoot, lowcoder
  - [ ] NetBird usa seu próprio Caddy (não adicionar ao BorgStack Caddyfile)

- [ ] **Rebuild e restart containers**:
  ```bash
  docker compose down
  docker compose up -d --build
  ```

### Fase 3: Configuração NetBird VPN

- [ ] **Instalar NetBird Management Server no VPS**:
  - [ ] Executar script automatizado:
    ```bash
    export NETBIRD_DOMAIN=vpn.meuvps.duckdns.org
    curl -fsSL https://github.com/netbirdio/netbird/releases/latest/download/getting-started-with-zitadel.sh | bash
    ```
  - [ ] Aguardar instalação completa (Docker Compose)
  - [ ] Verificar serviços iniciados: `docker compose ps`

- [ ] **Acessar Dashboard Web Admin**:
  - [ ] Abrir `https://vpn.meuvps.duckdns.org`
  - [ ] Criar conta admin inicial (se Zitadel habilitado)
  - [ ] Explorar interface (Peers, Setup Keys, Groups, ACL, DNS)

- [ ] **Criar Setup Key**:
  - [ ] Dashboard → Setup Keys → + Add Key
  - [ ] Name: `sysadmin-key`, Type: `Reusable`
  - [ ] Copiar chave gerada

- [ ] **Conectar laptop SysAdmin**:
  - [ ] Instalar NetBird client:
    ```bash
    curl -fsSL https://pkgs.netbird.io/install.sh | sh
    ```
  - [ ] Conectar com setup key:
    ```bash
    sudo netbird up --setup-key A1B2C3D4-E5F6-G7H8-I9J0-K1L2M3N4O5P6
    ```
  - [ ] Verificar IP atribuído: `netbird status`

- [ ] **Testar acesso VPN**:
  ```bash
  ping 100.64.0.1  # VPS
  curl http://100.64.0.1:5678/healthz  # N8N
  curl http://100.64.0.1:8055/server/health  # Directus
  ```

### Fase 4: Configuração Chatwoot

- [ ] **Acessar Chatwoot Admin**:
  - [ ] `https://chat.meuvps.duckdns.org`
  - [ ] Criar conta Admin inicial

- [ ] **Criar contas de agentes**:
  - [ ] Departamento Financeiro: João Silva
  - [ ] Departamento Operações: Pedro Costa
  - [ ] Departamento Marketing: Lucas Oliveira

- [ ] **Configurar 2FA**:
  - [ ] Cada agente faz primeiro login
  - [ ] Ativa 2FA via QR Code (Google Authenticator)
  - [ ] Testa login com código 2FA

### Fase 5: Configuração Lowcoder

- [ ] **Configurar OAuth Google**:
  - [ ] Google Cloud Console: Criar OAuth Client
  - [ ] Copiar Client ID e Secret
  - [ ] Lowcoder Admin: Settings → Auth Providers → Add Google

- [ ] **Criar grupos (departamentos)**:
  - [ ] Settings → Groups → Create Group:
    - [ ] SysAdmins
    - [ ] Departamento Financeiro
    - [ ] Departamento Operações
    - [ ] Departamento Marketing

- [ ] **Pré-cadastrar usuários**:
  - [ ] Settings → Members → Add User:
    - [ ] galvani@admin.com → SysAdmins
    - [ ] joao@minhaempresa.com → Departamento Financeiro
    - [ ] pedro@minhaempresa.com → Departamento Operações
    - [ ] lucas@minhaempresa.com → Departamento Marketing

- [ ] **Testar signup bloqueado**:
  - [ ] Logout
  - [ ] Tentar login com email NÃO cadastrado
  - [ ] Verificar erro "Account not found"

### Fase 6: Criação de Dashboards

- [ ] **Dashboard Admin**:
  - [ ] Criar app "Dashboard Admin"
  - [ ] Adicionar cards para todos os serviços
  - [ ] Compartilhar com grupo "SysAdmins"
  - [ ] Testar acesso via VPN

- [ ] **Dashboard Financeiro**:
  - [ ] Criar app "Dashboard Financeiro"
  - [ ] Cards: Chatwoot, Workflows N8N, Relatórios Directus
  - [ ] Compartilhar com grupo "Departamento Financeiro"
  - [ ] Testar como usuário joao@minhaempresa.com

- [ ] **Dashboard Operações**:
  - [ ] Criar app "Dashboard Operações"
  - [ ] Cards: Chatwoot, FileFlows, Workflows Operacionais
  - [ ] Compartilhar com grupo "Departamento Operações"

- [ ] **Dashboard Marketing**:
  - [ ] Criar app "Dashboard Marketing"
  - [ ] Cards: Chatwoot, Directus Content, Workflows Marketing
  - [ ] Compartilhar com grupo "Departamento Marketing"

### Fase 7: Testes de Segurança

- [ ] **Teste de isolamento de rede**:
  - [ ] Sem VPN: Tentar acessar `http://[IP_VPS]:5678` → Timeout
  - [ ] Sem VPN: Tentar acessar `http://n8n.meuvps.duckdns.org` → DNS não resolve
  - [ ] Com VPN: Acessar `http://100.64.0.1:5678` → ✅ Funciona

- [ ] **Teste de controle de acesso Lowcoder**:
  - [ ] Login como joao@minhaempresa.com
  - [ ] Verificar: Vê apenas "Dashboard Financeiro"
  - [ ] Verificar: NÃO vê "Dashboard Admin" nem outros departamentos

- [ ] **Teste de 2FA Chatwoot**:
  - [ ] Login com email/senha corretos
  - [ ] Inserir código 2FA correto → ✅ Acesso liberado
  - [ ] Inserir código 2FA incorreto → ❌ Erro

- [ ] **Teste de signup bloqueado**:
  - [ ] Acessar `https://app.meuvps.duckdns.org`
  - [ ] Login com email aleatório (maria@teste.com)
  - [ ] Verificar: "Account not found"

### Fase 8: Documentação para Cliente

- [ ] **Manual do Usuário Lowcoder**:
  - [ ] Como fazer primeiro login (OAuth Google)
  - [ ] Como navegar pelos cards do dashboard
  - [ ] Como acionar workflows N8N
  - [ ] Suporte: contato do SysAdmin

- [ ] **Manual do Agente Chatwoot**:
  - [ ] Como fazer login com 2FA
  - [ ] Como configurar Google Authenticator
  - [ ] Como atender clientes
  - [ ] Boas práticas de atendimento

- [ ] **Manual do SysAdmin**:
  - [ ] Como conectar à VPN NetBird (setup key + client)
  - [ ] Como adicionar novos peers via Dashboard NetBird
  - [ ] Como adicionar novos usuários no Lowcoder
  - [ ] Como criar novos dashboards
  - [ ] Como monitorar logs e backups

---

## Considerações de Segurança

### Princípios Aplicados

1. **Defense in Depth**: Múltiplas camadas de segurança
   - Firewall (UFW/iptables)
   - Network isolation (Docker networks)
   - VPN (NetBird/WireGuard P2P)
   - OAuth 2.0 (Google)
   - 2FA TOTP (Chatwoot)

2. **Least Privilege**: Cada usuário/serviço tem apenas o acesso mínimo necessário
   - Funcionários: Apenas seus dashboards departamentais
   - SysAdmin: Acesso total apenas via VPN
   - Serviços internos: Sem exposição pública

3. **Zero Trust Network**: Não confiar na rede, validar toda requisição
   - OAuth valida identidade a cada login
   - 2FA adiciona segundo fator
   - VPN criptografa tráfego administrativo

### Hardening Adicional (Opcional)

```bash
# Firewall UFW
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp     # SSH
sudo ufw allow 80/tcp     # HTTP (redireciona para HTTPS)
sudo ufw allow 443/tcp    # HTTPS
sudo ufw allow 33073/tcp  # NetBird Management (gRPC)
sudo ufw allow 10000/tcp  # NetBird Signal (P2P coordination)
sudo ufw allow 3478/tcp   # Coturn STUN
sudo ufw allow 3478/udp   # Coturn STUN
sudo ufw allow 51820/udp  # WireGuard (NetBird peers)
sudo ufw enable

# Fail2Ban para SSH
sudo apt install fail2ban
sudo systemctl enable fail2ban

# Automatic security updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

---

## Manutenção e Monitoramento

### Logs Importantes

```bash
# Chatwoot
docker compose logs -f chatwoot

# Lowcoder
docker compose logs -f lowcoder-api-service

# NetBird Management
cd /root/netbird  # ou diretório de instalação
docker compose logs -f netbird-management

# NetBird Signal
docker compose logs -f netbird-signal

# Caddy (BorgStack)
docker compose logs -f caddy
```

### Backups Críticos

**Via Duplicati** (acesso VPN: `http://100.64.0.1:8200`):
- `/home/borgstack/volumes/postgres_data` (PostgreSQL - Chatwoot, Directus)
- `/home/borgstack/volumes/mongodb_data` (MongoDB - Lowcoder, N8N)
- `/home/borgstack/volumes/directus_uploads` (Arquivos Directus)
- `/home/borgstack/.env` (Variáveis de ambiente - SENSÍVEL!)

**NetBird**:
```bash
# Backup configurações e database NetBird
cd /root/netbird  # ou diretório de instalação
docker compose stop netbird-management
docker compose cp -a netbird-management:/var/lib/netbird/ backup/
docker compose start netbird-management

# Backup arquivos de configuração
tar -czf /backup/netbird-config-$(date +%Y%m%d).tar.gz \
  docker-compose.yml \
  management.json \
  turnserver.conf \
  Caddyfile
```

---

## Próximos Passos

### Melhorias Futuras

1. **Monitoramento**:
   - Grafana + Prometheus para métricas
   - Uptime Kuma para availability monitoring
   - Alertas via webhook N8N

2. **High Availability**:
   - Load balancer (HAProxy ou Caddy com múltiplos backends)
   - PostgreSQL replication
   - Redis Sentinel para HA

3. **Compliance**:
   - Logs centralizados (Loki + Grafana)
   - Auditoria de acessos
   - Retenção de dados conforme LGPD

4. **Automação**:
   - Terraform para infraestrutura como código
   - Ansible para configuração automatizada
   - CI/CD para deploy de dashboards Lowcoder

---

## Referências

- **Lowcoder Docs**: https://docs.lowcoder.cloud
- **Chatwoot Docs**: https://www.chatwoot.com/docs
- **NetBird Docs**: https://docs.netbird.io
- **NetBird GitHub**: https://github.com/netbirdio/netbird
- **NetBird API**: https://docs.netbird.io/api
- **Caddy Docs**: https://caddyserver.com/docs
- **N8N Docs**: https://docs.n8n.io
- **Directus Docs**: https://docs.directus.io

---

**Documento criado em**: 2025-10-09
**Autor**: Galvani (SysAdmin BorgStack)
**Versão**: 1.0 - Arquitetura Pós-MVP Multi-Tenant
**Licença**: MIT (uso interno)
