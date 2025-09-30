# Development Workflow

This section defines the deployment setup and operational workflow for BorgStack. Note: This is an infrastructure deployment project, not an application development project, so "development" refers to deploying and configuring the stack.

## Local Development Setup

**Note:** BorgStack is designed for server deployment. "Local development" means deploying on a local Ubuntu VM or test server for learning/testing purposes before production deployment.

### Prerequisites

```bash
# Target system requirements
# - Ubuntu 24.04 LTS (clean installation)
# - 8 vCPUs (minimum 4 for testing)
# - 36GB RAM (minimum 16GB for testing)
# - 500GB SSD (minimum 200GB for testing)
# - Static IP or domain name with DNS configured

# Verify system resources
lscpu | grep "CPU(s)"              # Check CPU count
free -h                             # Check RAM
df -h                               # Check disk space
cat /etc/os-release                 # Verify Ubuntu 24.04
```

### Initial Setup

```bash
# 1. Clone the repository to home directory
cd ~
git clone https://github.com/your-org/borgstack.git
cd borgstack

# 2. Run interactive bootstrap script
sudo ./scripts/bootstrap.sh

# The bootstrap script will:
# - Install Docker and Docker Compose v2
# - Check system prerequisites (CPU, RAM, disk, DNS)
# - Generate .env file interactively (prompts for passwords, domains)
# - Pull all Docker images (~15GB download)
# - Initialize databases and networks
# - Start all services
# - Generate SSL certificates via Caddy
# - Run health checks
# - Display service URLs and credentials

# 3. Manual alternative: Generate .env from template
cp .env.example .env
nano .env  # Fill in all required values
chmod 600 .env  # Secure permissions

# 4. Start services manually
docker compose pull
docker compose up -d

# 5. Monitor startup logs
docker compose logs -f
```

### Development Commands

```bash
# ============================================
# SERVICE MANAGEMENT
# ============================================

# Start all services
docker compose up -d

# Start specific service
docker compose up -d n8n

# Stop all services
docker compose down

# Stop but keep volumes (data persists)
docker compose stop

# Restart single service
docker compose restart chatwoot

# View running services
docker compose ps

# ============================================
# LOGS AND DEBUGGING
# ============================================

# View all logs
docker compose logs

# Follow logs in real-time
docker compose logs -f

# View specific service logs
docker compose logs n8n

# Last 100 lines from all services
docker compose logs --tail=100

# Logs since timestamp
docker compose logs --since 2024-01-29T10:00:00

# ============================================
# HEALTH CHECKS AND VALIDATION
# ============================================

# Run health check script
./scripts/healthcheck.sh

# Check service health manually
curl -f https://n8n.example.com.br/healthz
curl -f https://chatwoot.example.com.br/api/v1/accounts
curl -f https://directus.example.com.br/server/health

# Check database connectivity
docker compose exec postgresql pg_isready
docker compose exec mongodb mongosh --eval "db.adminCommand('ping')"
docker compose exec redis redis-cli ping

# ============================================
# DATABASE ACCESS (for debugging)
# ============================================

# PostgreSQL shell
docker compose exec postgresql psql -U postgres

# Connect to specific database
docker compose exec postgresql psql -U n8n_user -d n8n_db

# MongoDB shell
docker compose exec mongodb mongosh -u admin -p

# Redis CLI
docker compose exec redis redis-cli -a ${REDIS_PASSWORD}

# ============================================
# BACKUP AND RESTORE
# ============================================

# Manual backup trigger
./scripts/backup-now.sh

# Restore from backup
./scripts/restore.sh /path/to/backup

# ============================================
# UPDATES
# ============================================

# Update single service to new version
./scripts/update-service.sh n8n 1.113.0

# Update all services (edit docker-compose.yml versions first)
docker compose pull
docker compose up -d

# ============================================
# CLEANUP
# ============================================

# Stop and remove containers (keeps volumes)
docker compose down

# Remove everything including volumes (DESTRUCTIVE)
docker compose down -v

# Clean up unused Docker resources
docker system prune -a

# Remove specific volume
docker volume rm borgstack_n8n_data
```

---

## Environment Configuration

### Required Environment Variables

```bash
# ============================================
# FRONTEND ENVIRONMENT (.env for host system)
# ============================================

# Domain configuration (used by Caddy for routing)
BORGSTACK_DOMAIN=example.com.br
N8N_HOST=n8n.${BORGSTACK_DOMAIN}
CHATWOOT_HOST=chatwoot.${BORGSTACK_DOMAIN}
EVOLUTION_HOST=evolution.${BORGSTACK_DOMAIN}
LOWCODER_HOST=lowcoder.${BORGSTACK_DOMAIN}
DIRECTUS_HOST=directus.${BORGSTACK_DOMAIN}
FILEFLOWS_HOST=fileflows.${BORGSTACK_DOMAIN}
DUPLICATI_HOST=duplicati.${BORGSTACK_DOMAIN}

# SSL configuration
CADDY_EMAIL=admin@${BORGSTACK_DOMAIN}  # Let's Encrypt notifications

# ============================================
# BACKEND ENVIRONMENT (service configurations)
# ============================================

# Database credentials (PostgreSQL)
POSTGRES_PASSWORD=                     # Root password
N8N_DB_PASSWORD=                       # n8n database password
CHATWOOT_DB_PASSWORD=                  # Chatwoot database password
DIRECTUS_DB_PASSWORD=                  # Directus database password
EVOLUTION_DB_PASSWORD=                 # Evolution API database password

# Database credentials (MongoDB)
MONGODB_ROOT_PASSWORD=                 # MongoDB root password
LOWCODER_DB_PASSWORD=                  # Lowcoder database password

# Cache credentials (Redis)
REDIS_PASSWORD=                        # Shared Redis password

# Object storage credentials (SeaweedFS)
SEAWEEDFS_ACCESS_KEY=                  # S3 API access key
SEAWEEDFS_SECRET_KEY=                  # S3 API secret key

# Application secrets
N8N_ENCRYPTION_KEY=                    # n8n workflow encryption
CHATWOOT_SECRET_KEY_BASE=              # Rails secret
DIRECTUS_KEY=                          # Directus instance key
DIRECTUS_SECRET=                       # Directus auth secret
EVOLUTION_API_KEY=                     # Evolution API authentication

# Admin credentials
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=               # n8n admin password
DIRECTUS_ADMIN_EMAIL=admin@${BORGSTACK_DOMAIN}
DIRECTUS_ADMIN_PASSWORD=               # Directus admin password
LOWCODER_ADMIN_EMAIL=admin@${BORGSTACK_DOMAIN}
LOWCODER_ADMIN_PASSWORD=               # Lowcoder admin password

# ============================================
# SHARED ENVIRONMENT (used by multiple services)
# ============================================

# Timezone (affects logs, scheduling)
TZ=America/Sao_Paulo

# Webhook URLs (for service integrations)
N8N_WEBHOOK_BASE=https://n8n.${BORGSTACK_DOMAIN}/webhook
EVOLUTION_WEBHOOK_URL=${N8N_WEBHOOK_BASE}/evolution
CHATWOOT_WEBHOOK_URL=${N8N_WEBHOOK_BASE}/chatwoot

# Email configuration (optional)
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=noreply@${BORGSTACK_DOMAIN}
SMTP_PASSWORD=
SMTP_FROM=BorgStack <noreply@${BORGSTACK_DOMAIN}>

# Backup configuration
DUPLICATI_PASSPHRASE=                  # Encryption passphrase
DUPLICATI_BACKUP_DESTINATION=s3://bucket-name/borgstack-backups
DUPLICATI_BACKUP_SCHEDULE=0 2 * * *   # Daily at 2 AM (cron format)
```

---