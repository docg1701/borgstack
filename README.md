# BorgStack

> **EN** | [PT-BR](#borgstack-português)

⬛ BorgStack is the ultimate cube of business automation - a collective of 12 open source tools assimilated into a single Docker Compose consciousness. Like the Borg Collective, we absorb superior technologies from the Alpha quadrant of the internet: PostgreSQL, Redis, n8n, Chatwoot, Directus, Evolution API, and others. Each component works as a synchronized drone, its technological distinctiveness added to our collective perfection. We eliminate the chaotic individuality of manual configurations. Deploy in 30 minutes. Lower your shields. Your infrastructure will be automated.

---

## 🚀 Quick Start

### System Requirements

- **Operating System:** Ubuntu Server 24.04 LTS
- **CPU:** 8 vCPU cores (minimum)
- **RAM:** 36 GB (minimum)
- **Storage:** 500 GB SSD (recommended)
- **Network:** Public IP address with ports 80 and 443 accessible
- **Docker:** Docker Engine with Compose V2

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/borgstack.git
   cd borgstack
   ```

2. **Run the automated bootstrap script (Recommended):**
   ```bash
   ./scripts/bootstrap.sh
   ```

   The bootstrap script will:
   - Validate system requirements (Ubuntu 24.04, RAM, CPU, disk)
   - Install Docker Engine and Docker Compose v2
   - Configure UFW firewall (ports 22, 80, 443)
   - Generate `.env` file with strong passwords
   - Deploy all services
   - Validate health checks
   - Display DNS/SSL configuration instructions

3. **Manual setup (Alternative):**
   ```bash
   # Copy environment template
   cp .env.example .env

   # Edit .env with your configuration
   nano .env

   # Start the stack
   docker compose up -d

   # Check service status
   docker compose ps
   ```

4. **Access your services:**
   - Each service will be available at its configured domain
   - See `.env.example` for domain configuration

---

## 🎯 Bootstrap Script Details

The automated bootstrap script (`scripts/bootstrap.sh`) handles the complete setup process for Ubuntu 24.04 LTS servers.

### What It Does

1. **System Validation:**
   - Checks Ubuntu version (requires 24.04 LTS)
   - Validates RAM (minimum 16GB, recommended 36GB)
   - Validates disk space (minimum 200GB, recommended 500GB)
   - Validates CPU cores (minimum 4, recommended 8)

2. **Software Installation:**
   - Installs Docker Engine (latest stable)
   - Installs Docker Compose v2 plugin
   - Installs system utilities (curl, wget, git, ufw, dig, htop, sysstat)
   - Adds user to docker group for non-root access

3. **Security Configuration:**
   - Configures UFW firewall with default deny incoming policy
   - Opens ports: 22 (SSH), 80 (HTTP), 443 (HTTPS)
   - Generates strong random passwords (32 characters) for all services
   - Sets .env file permissions to 600 (owner read/write only)

4. **Service Deployment:**
   - Pulls all Docker images
   - Starts all services via `docker compose up -d`
   - Waits for service initialization
   - Validates health checks for core services

5. **Post-Installation:**
   - Displays DNS configuration instructions
   - Explains Let's Encrypt SSL automatic generation
   - Provides service access URLs
   - Shows troubleshooting commands

### Prerequisites

- Fresh Ubuntu 24.04 LTS server
- Non-root user with sudo privileges
- Internet connection
- Public IP address (for SSL certificates)

### Usage

```bash
# Make executable (if needed)
chmod +x scripts/bootstrap.sh

# Run the script
./scripts/bootstrap.sh

# Follow interactive prompts for:
# - Domain name (e.g., example.com.br)
# - Email for SSL notifications (e.g., admin@example.com.br)
```

### After Bootstrap

1. **Configure DNS:** Add A records for 7 subdomains pointing to your server IP
2. **Verify DNS:** Wait 5-30 minutes for propagation, then test with `dig`
3. **Access Services:** Visit `https://<service>.<domain>` (SSL auto-generated on first access)
4. **Save Credentials:** Store generated passwords from `.env` in a password manager
5. **Production Security:** Change `CORS_ALLOWED_ORIGINS` from `*` to specific origins

### Service Access

#### n8n Workflow Automation

- **URL:** `https://n8n.<your-domain>`
- **Credentials:**
  - Username: `admin` (from `N8N_BASIC_AUTH_USER` in `.env`)
  - Password: (from `N8N_BASIC_AUTH_PASSWORD` in `.env`)
- **Encryption Key:** Critical - backup `N8N_ENCRYPTION_KEY` securely (required for encrypted credentials)
- **Webhook URL Format:** `https://n8n.<your-domain>/webhook/<workflow-path>`
- **Getting Started:**
  1. Log in to n8n web interface
  2. Import example workflows from `config/n8n/workflows/`
  3. Explore 400+ integrations in the n8n node library
  4. Create your first automation workflow
- **Example Workflows:** See `config/n8n/workflows/README.md` for import instructions

#### Evolution API - WhatsApp Business Gateway

- **URL:** `https://evolution.<your-domain>/manager` (Admin UI)
- **API Documentation:** `https://evolution.<your-domain>/docs`
- **API Key:** (from `EVOLUTION_API_KEY` in `.env`) - Required for ALL API operations
- **Webhook URL:** `https://n8n.<your-domain>/webhook/whatsapp-incoming` (configured automatically)
- **Multi-Instance Support:** Create separate WhatsApp instances for different business accounts
- **Getting Started:**
  1. Access Evolution API Admin UI at `https://evolution.<your-domain>/manager`
  2. Create WhatsApp instance (provide instance name, e.g., `customer_support`)
  3. Scan QR code with WhatsApp (Settings → Linked Devices → Link a Device)
  4. Verify connection status (instance state should be: `open`)
  5. Import n8n webhook workflow: `config/n8n/workflows/03-whatsapp-evolution-incoming.json`
  6. Test message sending/receiving
- **Detailed Setup Guide:** See `config/evolution/README.md` for complete instructions
- **n8n Integration:** Incoming WhatsApp messages → Evolution API → Webhook → n8n → Chatwoot/other services
- **Message Sending:** Use Evolution API HTTP nodes in n8n workflows to send WhatsApp messages

**API Usage Examples:**

```bash
# Create WhatsApp instance
curl -X POST "https://evolution.<your-domain>/instance/create" \
  -H "Content-Type: application/json" \
  -H "apikey: <EVOLUTION_API_KEY>" \
  -d '{"instanceName": "customer_support", "qrcode": true, "integration": "WHATSAPP-BAILEYS"}'

# Send WhatsApp message
curl -X POST "https://evolution.<your-domain>/message/sendText/customer_support" \
  -H "Content-Type: application/json" \
  -H "apikey: <EVOLUTION_API_KEY>" \
  -d '{"number": "5511987654321", "text": "Hello from BorgStack!"}'

# Check instance connection status
curl "https://evolution.<your-domain>/instance/connectionState/customer_support" \
  -H "apikey: <EVOLUTION_API_KEY>"
```

#### Chatwoot - Customer Service Platform

- **URL:** `https://chatwoot.<your-domain>/app` (Admin Dashboard)
- **First Login:** Create admin account on first visit (email becomes your username)
- **API Documentation:** `https://chatwoot.<your-domain>/api/v1`
- **API Token:** **MUST be manually generated** from admin UI after first login
- **WhatsApp Integration:** Evolution API → n8n → Chatwoot API (automated customer service)
- **Getting Started:**
  1. Access Chatwoot: `https://chatwoot.<your-domain>/app`
  2. Create admin account (email + password) on first visit
  3. **Generate API Token (REQUIRED for n8n integration):**
     - Go to Settings → Account Settings → Access Tokens
     - Click "Add New Token" → Name: `n8n Integration`
     - Copy token immediately (shown only once)
     - Add to `.env` file: `CHATWOOT_API_TOKEN=<your-token>`
     - Restart Chatwoot: `docker compose restart chatwoot`
  4. Create WhatsApp Inbox: Settings → Inboxes → Add Inbox → API Channel
  5. Import n8n workflow: `config/n8n/workflows/04-whatsapp-chatwoot-integration.json`
  6. Configure n8n credential: Credentials → New → HTTP Header Auth (see below)
  7. Test WhatsApp → Chatwoot integration
- **Detailed Setup Guide:** See `config/chatwoot/README.md` for complete instructions
- **n8n Integration Flow:** WhatsApp → Evolution API → n8n → Chatwoot (incoming) | Chatwoot → n8n → Evolution API (outgoing)

**n8n Credential Setup for Chatwoot API:**

```plaintext
1. In n8n UI: Credentials → New Credential
2. Type: HTTP Header Auth
3. Name: Chatwoot API Token
4. Header Name: api_access_token
5. Header Value: <paste CHATWOOT_API_TOKEN from .env>
6. Save
```

**Agent Management:**

```plaintext
- Add Agents: Settings → Agents → Add Agent
- Agent Roles: Administrator (full access) | Agent (assigned conversations)
- Conversation Assignment: Manual or auto-assignment (round-robin)
- Working Hours: Settings → Account Settings → Business Hours
```

**API Usage Examples:**

```bash
# Get account details
curl "https://chatwoot.<your-domain>/api/v1/accounts" \
  -H "api_access_token: <CHATWOOT_API_TOKEN>"

# Search for contact by phone
curl "https://chatwoot.<your-domain>/api/v1/accounts/1/contacts/search?q=%2B5511987654321" \
  -H "api_access_token: <CHATWOOT_API_TOKEN>"

# Create conversation
curl -X POST "https://chatwoot.<your-domain>/api/v1/accounts/1/conversations" \
  -H "Content-Type: application/json" \
  -H "api_access_token: <CHATWOOT_API_TOKEN>" \
  -d '{"source_id": "5511987654321@s.whatsapp.net", "inbox_id": 1, "contact_id": 42, "status": "open"}'

# Post message to conversation
curl -X POST "https://chatwoot.<your-domain>/api/v1/accounts/1/conversations/123/messages" \
  -H "Content-Type: application/json" \
  -H "api_access_token: <CHATWOOT_API_TOKEN>" \
  -d '{"content": "Hello! How can I help you?", "message_type": "incoming"}'
```

#### Lowcoder - Low-Code Application Platform

- **URL:** `https://lowcoder.<your-domain>` (Application Builder)
- **First Login:** Admin account created automatically using credentials from `.env` file
- **Admin Email:** Value from `LOWCODER_ADMIN_EMAIL` (default: `admin@<your-domain>`)
- **Admin Password:** Value from `LOWCODER_ADMIN_PASSWORD` (32-char auto-generated by bootstrap)
- **Purpose:** Build custom internal business applications with drag-and-drop UI builder
- **Getting Started:**
  1. Access Lowcoder: `https://lowcoder.<your-domain>`
  2. Login with admin credentials from `.env` file:
     ```bash
     grep LOWCODER_ADMIN .env
     ```
  3. **Change admin password (recommended):** Profile → Settings → Account → Change Password
  4. Create your first application: Click "Create New" → Application → Choose template
  5. Connect to data sources: Data Sources → Add Data Source → PostgreSQL/REST API
  6. Build UI with drag-and-drop components: Tables, Forms, Buttons, Charts
  7. Publish application: Click "Publish" (top-right)
- **Data Sources:**
  - **PostgreSQL:** Connect to BorgStack databases (n8n_db, chatwoot_db, evolution_db)
    - Host: `postgresql`, Port: `5432`
    - Database passwords: From `.env` file (e.g., `CHATWOOT_DB_PASSWORD`)
  - **REST API:** Connect to n8n webhooks, Evolution API, Chatwoot API
    - n8n webhooks: `https://n8n.<your-domain>/webhook/lowcoder-trigger`
    - Evolution API: `https://evolution.<your-domain>` (requires API key)
    - Chatwoot API: `https://chatwoot.<your-domain>/api/v1` (requires token)
- **n8n Integration:**
  - Trigger n8n workflows from Lowcoder buttons (webhook POST requests)
  - Display n8n workflow results in Lowcoder dashboards
  - Example workflow: `config/n8n/workflows/05-lowcoder-webhook-integration.json`
- **Detailed Setup Guide:** See `config/lowcoder/README.md` for complete instructions

**Example Use Cases:**

```plaintext
1. Customer Dashboard:
   - Connect to Chatwoot PostgreSQL database
   - Display conversations table with filters
   - Create custom reports and charts

2. Workflow Trigger App:
   - Create button to trigger n8n workflow
   - Pass form data to n8n webhook
   - Display workflow execution results

3. WhatsApp Campaign Builder:
   - Build form for campaign creation
   - Trigger Evolution API via n8n workflow
   - Track message delivery status
```

**Connecting to PostgreSQL in Lowcoder:**

⚠️ **Security Best Practice:** Use the read-only database user (`lowcoder_readonly_user`) for query-only applications (dashboards, reports). This implements the principle of least privilege.

```plaintext
1. Create read-only database user (one-time setup):
   docker compose cp config/postgresql/create-lowcoder-readonly-users.sql postgresql:/tmp/
   docker compose exec postgresql psql -U postgres \
     -v LOWCODER_READONLY_DB_PASSWORD="$(grep LOWCODER_READONLY_DB_PASSWORD .env | cut -d= -f2)" \
     -f /tmp/create-lowcoder-readonly-users.sql

2. In Lowcoder UI: Data Sources → Add Data Source → PostgreSQL
3. Configuration (Read-Only Access - RECOMMENDED):
   - Name: chatwoot_db_readonly (descriptive name)
   - Host: postgresql
   - Port: 5432
   - Database: chatwoot_db (or n8n_db, evolution_db, directus_db)
   - Username: lowcoder_readonly_user (read-only user with SELECT permissions only)
   - Password: From .env file (LOWCODER_READONLY_DB_PASSWORD)
   - SSL Mode: disable (internal network)
4. Test Connection → Save

Alternative (Write Access - Use with Caution):
   - Username: chatwoot_user (service owner account - full read/write access)
   - Password: From .env file (CHATWOOT_DB_PASSWORD)
   - Note: Only use service owner accounts if write operations are required
```

**For detailed datasource configuration, security best practices, and application templates:**
See `config/lowcoder/README.md` for comprehensive documentation.

**Triggering n8n Workflows from Lowcoder:**

```javascript
// In Lowcoder query editor (REST API data source)
Method: POST
URL: https://n8n.<your-domain>/webhook/lowcoder-trigger
Headers: Content-Type: application/json
Body: {
  "action": "create_record",
  "data": {
    "name": {{ textInput1.value }},
    "email": {{ textInput2.value }},
    "department": {{ dropdown1.value }}
  }
}

// Trigger from button: onClick → Run Query
```

### Troubleshooting

- **View logs:** `cat /tmp/borgstack-bootstrap.log`
- **Check services:** `docker compose ps`
- **View service logs:** `docker compose logs [service_name]`
- **Restart service:** `docker compose restart [service_name]`

#### n8n Connection Issues

**Cannot access n8n web UI:**
```bash
# Check n8n container status
docker compose ps n8n

# Check n8n logs
docker compose logs n8n

# Verify DNS configuration
dig n8n.<your-domain>

# Check Caddy reverse proxy
docker compose logs caddy
```

**Webhook not responding:**
1. Ensure workflow is **Active** (toggle in n8n UI)
2. Verify webhook URL: `https://n8n.<your-domain>/webhook/<path>`
3. Check n8n logs: `docker compose logs n8n | grep webhook`
4. Test internal endpoint: `docker compose exec n8n wget -qO- http://localhost:5678/webhook/test`

**Database connection errors:**
```bash
# Check PostgreSQL health
docker compose ps postgresql

# Verify n8n database exists
docker compose exec postgresql psql -U postgres -c "\l" | grep n8n_db

# Check connection from n8n
docker compose logs n8n | grep -i "database\|postgres"
```

#### Evolution API Connection Issues

**Cannot access Evolution API Admin UI:**
```bash
# Check Evolution API container status
docker compose ps evolution

# Check Evolution API logs
docker compose logs evolution

# Verify DNS configuration
dig evolution.<your-domain>

# Check Caddy reverse proxy
docker compose logs caddy | grep evolution
```

**QR Code not displaying:**
1. Check Evolution API health: `docker compose ps evolution` (should show: healthy)
2. Verify database connection: `docker compose logs evolution | grep -i "database\|prisma"`
3. Check API key configuration: `grep EVOLUTION_API_KEY .env`

**WhatsApp connection fails after QR scan:**
1. Disconnect all WhatsApp Web sessions on your phone
2. Wait 5 minutes, then retry QR code scan
3. Check Evolution API logs: `docker compose logs evolution --tail 100`
4. Restart Evolution API: `docker compose restart evolution`

**Webhooks not delivered to n8n:**
1. Verify n8n webhook is active: `curl https://n8n.<your-domain>/webhook/whatsapp-incoming`
2. Check Evolution API webhook config: See `config/evolution/README.md` → Troubleshooting
3. Test webhook delivery: Send message to WhatsApp, check n8n executions

**For detailed troubleshooting:** See `config/evolution/README.md` → Troubleshooting section

#### Chatwoot Connection Issues

**Cannot access Chatwoot web UI:**
```bash
# Check Chatwoot container status
docker compose ps chatwoot

# Check Chatwoot logs
docker compose logs chatwoot

# Verify DNS configuration
dig chatwoot.<your-domain>

# Check Caddy reverse proxy
docker compose logs caddy | grep chatwoot
```

**Chatwoot container fails to start:**
1. Check Rails migrations: `docker compose logs chatwoot | grep -i migration`
2. Verify SECRET_KEY_BASE is 128 characters: `grep CHATWOOT_SECRET_KEY_BASE .env | wc -c` (should be ~150)
3. Check PostgreSQL connection: `docker compose logs chatwoot | grep -i "database\|postgres"`
4. Check Redis connection: `docker compose logs chatwoot | grep -i "redis\|sidekiq"`
5. Restart with clean state: `docker compose restart chatwoot`

**API token authentication fails (401 Unauthorized):**
1. Verify token is set in .env: `grep CHATWOOT_API_TOKEN .env`
2. Test API manually: `curl https://chatwoot.<your-domain>/api/v1/accounts -H "api_access_token: ${CHATWOOT_API_TOKEN}"`
3. Regenerate token: Chatwoot UI → Settings → Account Settings → Access Tokens → Create New Token
4. Update .env and restart: `docker compose restart chatwoot`

**WhatsApp messages not appearing in Chatwoot:**
1. Verify n8n workflow is active: n8n UI → Workflows → 04 - WhatsApp Chatwoot Integration (should be "Active")
2. Check n8n execution logs: n8n UI → Executions (look for errors in Chatwoot API calls)
3. Verify Chatwoot API token: `grep CHATWOOT_API_TOKEN .env` (should NOT be `<obtain-from-admin-ui...>`)
4. Test Chatwoot API manually: See API Usage Examples above
5. Check webhook delivery: Evolution API → n8n → Chatwoot (verify each step)

**Agent replies not sent to WhatsApp:**
1. Verify Chatwoot webhook configured: Settings → Integrations → Webhooks (should have webhook to n8n)
2. Check n8n outgoing workflow exists and is active
3. Verify Evolution API instance is connected: `curl https://evolution.<your-domain>/instance/connectionState/<instance> -H "apikey: ${EVOLUTION_API_KEY}"`
4. Check n8n execution logs for outgoing workflow errors

**For detailed troubleshooting:** See `config/chatwoot/README.md` → Troubleshooting Guide

#### Lowcoder Connection Issues

**Cannot access Lowcoder web UI:**
```bash
# Check Lowcoder container status
docker compose ps lowcoder

# Check Lowcoder logs
docker compose logs lowcoder

# Verify DNS configuration
dig lowcoder.<your-domain>

# Check Caddy reverse proxy
docker compose logs caddy | grep lowcoder
```

**Lowcoder container fails to start:**
1. Check MongoDB connection: `docker compose logs lowcoder | grep -i "mongodb\|database"`
2. Check Redis connection: `docker compose logs lowcoder | grep -i redis`
3. Verify MongoDB is healthy: `docker compose ps mongodb` (should show: healthy)
4. Verify Redis is healthy: `docker compose ps redis` (should show: healthy)
5. Check initialization logs: `docker compose logs lowcoder | grep -i "started\|ready"`

**Admin login fails:**
```bash
# Verify admin credentials
grep LOWCODER_ADMIN .env

# Check admin account creation logs
docker compose logs lowcoder | grep -i admin

# Restart Lowcoder to recreate admin account
docker compose restart lowcoder
```

**MongoDB connection error:**
```bash
# Verify MongoDB connection string
docker compose config | grep LOWCODER_MONGODB_URL

# Test MongoDB connection manually
docker compose exec mongodb mongosh -u lowcoder_user -p "$(grep LOWCODER_DB_PASSWORD .env | cut -d= -f2)" --authenticationDatabase lowcoder lowcoder

# Check MongoDB logs
docker compose logs mongodb | tail -50
```

**Redis connection error:**
```bash
# Verify Redis connection string
docker compose config | grep LOWCODER_REDIS_URL

# Test Redis connection manually
docker compose exec redis redis-cli -a "$(grep REDIS_PASSWORD .env | cut -d= -f2)" PING

# Check Redis logs
docker compose logs redis | tail -50
```

**Application not saving:**
1. Verify borgstack_lowcoder_stacks volume mounted: `docker compose config | grep lowcoder-stacks`
2. Check volume permissions: `docker compose exec lowcoder ls -la /lowcoder-stacks`
3. Check MongoDB connection (applications stored in MongoDB)
4. View Lowcoder save errors: `docker compose logs lowcoder | grep -i "save\|error"`

**Data source connection failed (PostgreSQL):**
```bash
# Test PostgreSQL connection from Lowcoder container
docker compose exec lowcoder pg_isready -h postgresql -p 5432

# Verify database exists
docker compose exec postgresql psql -U postgres -c "\l" | grep chatwoot_db

# Check database user permissions
docker compose exec postgresql psql -U postgres -c "\du" | grep chatwoot_user
```

**n8n webhook not responding from Lowcoder:**
1. Verify n8n workflow is active: n8n UI → Workflows → 05 - Lowcoder Webhook Integration
2. Test webhook manually: `curl -X POST https://n8n.<your-domain>/webhook/lowcoder-trigger -H "Content-Type: application/json" -d '{"action":"test"}'`
3. Check n8n execution logs: n8n UI → Executions
4. Verify Lowcoder API query configuration (Method: POST, correct URL)

**Encryption keys error:**
```bash
# Verify encryption keys are set and 32 characters
grep LOWCODER_ENCRYPTION_PASSWORD .env | cut -d= -f2 | wc -c  # Should be 33 (32 + newline)
grep LOWCODER_ENCRYPTION_SALT .env | cut -d= -f2 | wc -c  # Should be 33 (32 + newline)

# Regenerate encryption keys if needed (WARNING: Will lose access to existing datasource credentials)
LOWCODER_ENCRYPTION_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
LOWCODER_ENCRYPTION_SALT=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
echo "LOWCODER_ENCRYPTION_PASSWORD=${LOWCODER_ENCRYPTION_PASSWORD}" >> .env
echo "LOWCODER_ENCRYPTION_SALT=${LOWCODER_ENCRYPTION_SALT}" >> .env
docker compose restart lowcoder
```

**For detailed troubleshooting:** See `config/lowcoder/README.md` → Troubleshooting section

**Redis/Queue errors:**
```bash
# Check Redis health
docker compose ps redis

# Test Redis connection
docker compose exec redis redis-cli -a ${REDIS_PASSWORD} ping

# Check n8n queue logs
docker compose logs n8n | grep -i "redis\|queue"
```

### Idempotency

The script is safe to run multiple times:
- Skips Docker installation if already present
- Warns before overwriting existing `.env` file
- Detects existing firewall rules
- No destructive operations without confirmation

---

## 📦 Included Services

| Service | Purpose | Version |
|---------|---------|---------|
| **n8n** | Workflow automation platform | 1.112.6 |
| **Evolution API** | WhatsApp Business API gateway | v2.2.3 |
| **Chatwoot** | Omnichannel customer communication | v4.6.0-ce |
| **Lowcoder** | Low-code application builder | 2.7.4 |
| **Directus** | Headless CMS and data management | 11 |
| **FileFlows** | Automated media processing | 25.09 |
| **SeaweedFS** | S3-compatible object storage | 3.97 |
| **Duplicati** | Encrypted backup automation | 2.1.1.102 |
| **PostgreSQL** | Primary relational database (with pgvector) | 18.0 |
| **MongoDB** | NoSQL database (Lowcoder only) | 7.0 |
| **Redis** | Cache and message queue | 8.2 |
| **Caddy** | Reverse proxy with automatic HTTPS | 2.10 |

---

## 📚 Documentation

Comprehensive documentation is available in the `docs/` directory:

- **Installation Guide:** [docs/01-installation.md](docs/01-installation.md)
- **Configuration Guide:** [docs/02-configuration.md](docs/02-configuration.md)
- **Service Guides:** [docs/03-services/](docs/03-services/)
- **Integration Tutorials:** [docs/04-integrations/](docs/04-integrations/)
- **Troubleshooting:** [docs/05-troubleshooting.md](docs/05-troubleshooting.md)
- **Maintenance & Updates:** [docs/06-maintenance.md](docs/06-maintenance.md)
- **Security Hardening:** [docs/07-security.md](docs/07-security.md)
- **Performance Optimization:** [docs/08-performance.md](docs/08-performance.md)

---

## 🔧 Configuration

All configuration is managed through environment variables in the `.env` file:

```bash
# Copy the template
cp .env.example .env

# Edit with your configuration
nano .env
```

**Important:** Never commit your `.env` file to version control. It contains sensitive credentials.

---

## 🛠️ Development

### Local Development

Local development uses `docker-compose.override.yml` automatically:

```bash
# Start with local overrides
docker compose up -d

# View logs
docker compose logs -f

# Stop services
docker compose down
```

### Production Deployment

Production deployment uses `docker-compose.prod.yml`:

```bash
# Start with production configuration
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Check service health
docker compose -f docker-compose.yml -f docker-compose.prod.yml ps
```

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

### Branching Strategy

- **Main branch:** `main` (protected, production-ready code)
- **Feature branches:** `feature/<descriptive-name>`
- **Bug fix branches:** `fix/<descriptive-name>`

### Commit Message Format

Use imperative mood for commit messages:

- ✅ Correct: `add health checks to all services`
- ❌ Wrong: `added health checks to all services`

### Pull Request Process

1. Fork the repository
2. Create a feature branch from `main`
3. Make your changes
4. Ensure all CI checks pass
5. Submit a pull request with a clear description

---

## 📝 License

BorgStack is open source software licensed under the [MIT License](LICENSE).

---

## 🌟 Support

- **Issues:** Report bugs or request features via [GitHub Issues](https://github.com/yourusername/borgstack/issues)
- **Documentation:** Check the [docs/](docs/) directory first
- **Community:** Join our discussions (coming soon)

---

## ⚠️ Security

- Never commit `.env` files or secrets to version control
- Regularly update Docker images to patch security vulnerabilities
- Follow security best practices in [docs/07-security.md](docs/07-security.md)
- Use strong, unique passwords for all services
- Enable firewall rules to restrict access to sensitive ports

---

<a name="borgstack-português"></a>

# BorgStack (Português)

> [EN](#borgstack) | **PT-BR**

⬛ BorgStack é o cubo definitivo de automação empresarial - um coletivo de 12 ferramentas open source assimiladas em uma única consciência Docker Compose. Como o Coletivo Borg, absorvemos as tecnologias superiores do quadrante Alpha da internet: PostgreSQL, Redis, n8n, Chatwoot, Directus, Evolution API e outras. Cada componente trabalha como drone sincronizado, sua distintividade tecnológica adicionada à nossa perfeição coletiva. Eliminamos a individualidade caótica de configurações manuais. Deploy em 30 minutos. Baixe seus escudos. Sua infraestrutura será automatizada.

---

## 🚀 Início Rápido

### Requisitos do Sistema

- **Sistema Operacional:** Ubuntu Server 24.04 LTS
- **CPU:** 8 núcleos vCPU (mínimo)
- **RAM:** 36 GB (mínimo)
- **Armazenamento:** 500 GB SSD (recomendado)
- **Rede:** Endereço IP público com portas 80 e 443 acessíveis
- **Docker:** Docker Engine com Compose V2

### Instalação

1. **Clone o repositório:**
   ```bash
   git clone https://github.com/yourusername/borgstack.git
   cd borgstack
   ```

2. **Execute o script de bootstrap automatizado (Recomendado):**
   ```bash
   ./scripts/bootstrap.sh
   ```

   O script de bootstrap irá:
   - Validar requisitos do sistema (Ubuntu 24.04, RAM, CPU, disco)
   - Instalar Docker Engine e Docker Compose v2
   - Configurar firewall UFW (portas 22, 80, 443)
   - Gerar arquivo `.env` com senhas fortes
   - Fazer deploy de todos os serviços
   - Validar health checks
   - Exibir instruções de configuração DNS/SSL

3. **Configuração manual (Alternativa):**
   ```bash
   # Copie o template de variáveis de ambiente
   cp .env.example .env

   # Edite .env com sua configuração
   nano .env

   # Inicie a stack
   docker compose up -d

   # Verifique o status dos serviços
   docker compose ps
   ```

4. **Acesse seus serviços:**
   - Cada serviço estará disponível em seu domínio configurado
   - Veja `.env.example` para configuração de domínios

---

## 🎯 Detalhes do Script Bootstrap

O script de bootstrap automatizado (`scripts/bootstrap.sh`) cuida de todo o processo de configuração para servidores Ubuntu 24.04 LTS.

### O Que Ele Faz

1. **Validação do Sistema:**
   - Verifica versão do Ubuntu (requer 24.04 LTS)
   - Valida RAM (mínimo 16GB, recomendado 36GB)
   - Valida espaço em disco (mínimo 200GB, recomendado 500GB)
   - Valida núcleos de CPU (mínimo 4, recomendado 8)

2. **Instalação de Software:**
   - Instala Docker Engine (última versão estável)
   - Instala plugin Docker Compose v2
   - Instala utilitários do sistema (curl, wget, git, ufw, dig, htop, sysstat)
   - Adiciona usuário ao grupo docker para acesso não-root

3. **Configuração de Segurança:**
   - Configura firewall UFW com política padrão de negar entrada
   - Abre portas: 22 (SSH), 80 (HTTP), 443 (HTTPS)
   - Gera senhas aleatórias fortes (32 caracteres) para todos os serviços
   - Define permissões do arquivo .env para 600 (apenas leitura/escrita do proprietário)

4. **Deploy de Serviços:**
   - Baixa todas as imagens Docker
   - Inicia todos os serviços via `docker compose up -d`
   - Aguarda inicialização dos serviços
   - Valida health checks dos serviços principais

5. **Pós-Instalação:**
   - Exibe instruções de configuração DNS
   - Explica geração automática de SSL via Let's Encrypt
   - Fornece URLs de acesso aos serviços
   - Mostra comandos de troubleshooting

### Pré-requisitos

- Servidor Ubuntu 24.04 LTS novo
- Usuário não-root com privilégios sudo
- Conexão com internet
- Endereço IP público (para certificados SSL)

### Uso

```bash
# Torne executável (se necessário)
chmod +x scripts/bootstrap.sh

# Execute o script
./scripts/bootstrap.sh

# Siga os prompts interativos para:
# - Nome do domínio (ex: exemplo.com.br)
# - Email para notificações SSL (ex: admin@exemplo.com.br)
```

### Após o Bootstrap

1. **Configurar DNS:** Adicione registros A para os 7 subdomínios apontando para o IP do seu servidor
2. **Verificar DNS:** Aguarde 5-30 minutos para propagação, depois teste com `dig`
3. **Acessar Serviços:** Visite `https://<serviço>.<domínio>` (SSL gerado automaticamente no primeiro acesso)
4. **Salvar Credenciais:** Armazene senhas geradas do `.env` em um gerenciador de senhas
5. **Segurança em Produção:** Altere `CORS_ALLOWED_ORIGINS` de `*` para origens específicas

### Solução de Problemas

- **Ver logs:** `cat /tmp/borgstack-bootstrap.log`
- **Verificar serviços:** `docker compose ps`
- **Ver logs de serviço:** `docker compose logs [nome_serviço]`
- **Reiniciar serviço:** `docker compose restart [nome_serviço]`

### Idempotência

O script é seguro para executar múltiplas vezes:
- Ignora instalação do Docker se já presente
- Avisa antes de sobrescrever arquivo `.env` existente
- Detecta regras de firewall existentes
- Nenhuma operação destrutiva sem confirmação

---

## 📦 Serviços Incluídos

| Serviço | Propósito | Versão |
|---------|-----------|--------|
| **n8n** | Plataforma de automação de fluxos de trabalho | 1.112.6 |
| **Evolution API** | Gateway de API WhatsApp Business | v2.2.3 |
| **Chatwoot** | Comunicação omnichannel com clientes | v4.6.0-ce |
| **Lowcoder** | Construtor de aplicativos low-code | 2.7.4 |
| **Directus** | CMS headless e gestão de dados | 11 |
| **FileFlows** | Processamento automatizado de mídia | 25.09 |
| **SeaweedFS** | Armazenamento de objetos compatível com S3 | 3.97 |
| **Duplicati** | Automação de backup criptografado | 2.1.1.102 |
| **PostgreSQL** | Banco de dados relacional primário (com pgvector) | 18.0 |
| **MongoDB** | Banco de dados NoSQL (apenas Lowcoder) | 7.0 |
| **Redis** | Cache e fila de mensagens | 8.2 |
| **Caddy** | Proxy reverso com HTTPS automático | 2.10 |

---

## 📚 Documentação

Documentação abrangente está disponível no diretório `docs/`:

- **Guia de Instalação:** [docs/01-installation.md](docs/01-installation.md)
- **Guia de Configuração:** [docs/02-configuration.md](docs/02-configuration.md)
- **Guias de Serviços:** [docs/03-services/](docs/03-services/)
- **Tutoriais de Integração:** [docs/04-integrations/](docs/04-integrations/)
- **Solução de Problemas:** [docs/05-troubleshooting.md](docs/05-troubleshooting.md)
- **Manutenção e Atualizações:** [docs/06-maintenance.md](docs/06-maintenance.md)
- **Hardening de Segurança:** [docs/07-security.md](docs/07-security.md)
- **Otimização de Desempenho:** [docs/08-performance.md](docs/08-performance.md)

---

## 🔧 Configuração

Toda configuração é gerenciada através de variáveis de ambiente no arquivo `.env`:

```bash
# Copie o template
cp .env.example .env

# Edite com sua configuração
nano .env
```

**Importante:** Nunca commite seu arquivo `.env` no controle de versão. Ele contém credenciais sensíveis.

---

## 🛠️ Desenvolvimento

### Desenvolvimento Local

Desenvolvimento local usa `docker-compose.override.yml` automaticamente:

```bash
# Inicie com overrides locais
docker compose up -d

# Visualize logs
docker compose logs -f

# Pare os serviços
docker compose down
```

### Deploy de Produção

Deploy de produção usa `docker-compose.prod.yml`:

```bash
# Inicie com configuração de produção
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Verifique a saúde dos serviços
docker compose -f docker-compose.yml -f docker-compose.prod.yml ps
```

---

## 🤝 Contribuindo

Contribuições são bem-vindas! Por favor, siga estas diretrizes:

### Estratégia de Branches

- **Branch principal:** `main` (protegida, código pronto para produção)
- **Branches de features:** `feature/<nome-descritivo>`
- **Branches de correções:** `fix/<nome-descritivo>`

### Formato de Mensagem de Commit

Use modo imperativo para mensagens de commit:

- ✅ Correto: `add health checks to all services`
- ❌ Errado: `added health checks to all services`

### Processo de Pull Request

1. Faça fork do repositório
2. Crie uma branch de feature a partir da `main`
3. Faça suas alterações
4. Garanta que todas as verificações de CI passem
5. Submeta um pull request com uma descrição clara

---

## 📝 Licença

BorgStack é software de código aberto licenciado sob a [Licença MIT](LICENSE).

---

## 🌟 Suporte

- **Issues:** Reporte bugs ou solicite recursos via [GitHub Issues](https://github.com/yourusername/borgstack/issues)
- **Documentação:** Verifique o diretório [docs/](docs/) primeiro
- **Comunidade:** Junte-se às nossas discussões (em breve)

---

## ⚠️ Segurança

- Nunca commite arquivos `.env` ou secrets no controle de versão
- Atualize regularmente as imagens Docker para corrigir vulnerabilidades de segurança
- Siga as melhores práticas de segurança em [docs/07-security.md](docs/07-security.md)
- Use senhas fortes e únicas para todos os serviços
- Habilite regras de firewall para restringir acesso a portas sensíveis

---

**Built with ❤️ for the open source community**
