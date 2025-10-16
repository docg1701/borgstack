# Development Workflow

This section defines the deployment setup and operational workflow for BorgStack. Note: This is an infrastructure deployment project, not an application development project, so "development" refers to deploying and configuring the stack.

## Local Development Setup

**Note:** BorgStack is designed for server deployment. "Local development" means deploying on a local GNU/Linux VM or test server for learning/testing purposes before production deployment.

### Industry-Standard Local Development with Docker Compose Override

BorgStack follows Docker's official industry-standard patterns for local development using `docker-compose.override.yml`. This approach provides automatic configuration loading and seamless switching between local and production environments.

**How Docker Compose Override Works:**

Docker Compose automatically loads and merges `docker-compose.override.yml` when you run `docker compose up` (without explicit file arguments). This is the recommended pattern for local development per Docker's official documentation.

**Local vs Production Deployment:**

| Feature | Local Development (LAN + mDNS) | Production Deployment |
|---------|----------------------------------|----------------------|
| **Command** | `docker compose up -d` | `docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d` |
| **Configuration** | Automatic override loading | Explicit file loading |
| **Domain** | `hostname.local` / `localhost` | `your-domain.com` |
| **Ports** | 8080 (HTTP), 4433 (HTTPS) | 80 (HTTP), 443 (HTTPS) |
| **SSL** | HTTP only (development) | HTTPS auto-generated |
| **Database Access** | Direct ports exposed (5432, 6379, 27017) | Internal only |
| **File Mounting** | Live config editing | Production images only |
| **Network Access** | LAN + localhost (mDNS) | Internet (DNS) |
| **Setup Required** | `sudo apt install avahi-daemon` | DNS configuration |

**Local Development Workflow:**

```bash
# 1. Clone and setup
cd ~/borgstack
git clone https://github.com/your-org/borgstack.git
cd borgstack

# 2. Generate environment for local development
cp .env.example .env
# Edit .env with mDNS/hostname configuration:
# HOSTNAME=$(hostname)
# BORGSTACK_DOMAIN=$HOSTNAME.local
# CADDY_EMAIL=admin@localhost
# (other passwords and settings)

# 3. Install Avahi for mDNS hostname discovery
sudo apt install avahi-daemon
sudo systemctl enable avahi-daemon
sudo systemctl start avahi-daemon

# 4. Test mDNS resolution
ping $(hostname).local

# 5. Start local development (automatic override loading)
docker compose up -d

# 6. Access services via mDNS (recommended)
# Via reverse proxy: http://$(hostname).local:8080/n8n, http://$(hostname).local:8080/chatwoot, etc.
# Via localhost: http://localhost:8080/n8n, http://localhost:8080/chatwoot, etc.
# Via direct ports: http://localhost:5678 (n8n), http://localhost:3000 (chatwoot), etc.

# 7. Stop when done
docker compose down
```

**Override Configuration Benefits:**

- **Zero configuration**: Works automatically with `docker compose up`
- **Development friendly**: Exposes database ports for debugging
- **mDNS hostname discovery**: `hostname.local` access from any LAN device
- **No SSL**: HTTP-only simplifies development
- **Live editing**: Config files mounted for real-time changes
- **Industry standard**: Follows Docker Compose best practices

### mDNS/Avahi Configuration for LAN Access

**What is mDNS?**

Multicast DNS (mDNS) is a zero-configuration networking protocol that allows devices on the same local network to resolve hostnames to IP addresses without a central DNS server. When combined with Avahi (Linux implementation), your BorgStack services become accessible via `hostname.local` from any device on the network.

**Installation and Setup:**

```bash
# 1. Install Avahi daemon
sudo apt update
sudo apt install avahi-daemon avahi-utils

# 2. Enable and start the service
sudo systemctl enable avahi-daemon
sudo systemctl start avahi-daemon

# 3. Verify Avahi is running
sudo systemctl status avahi-daemon

# 4. Test mDNS resolution
hostname=$(hostname)
ping -c 2 $hostname.local

# 5. Discover services on the network
avahi-browse -a -t
```

**Configuration Verification:**

```bash
# Test hostname resolution
nslookup $hostname.local
dig $hostname.local

# Test service access
curl -I http://$hostname.local:8080
curl http://$hostname.local:8080

# Verify mDNS service advertising
avahi-browse -r _http._tcp
```

**Troubleshooting mDNS:**

| Issue | Cause | Solution |
|-------|-------|----------|
| `hostname.local` not resolving | Avahi not running | `sudo systemctl start avahi-daemon` |
| Can't access from other devices | Firewall blocking mDNS | `sudo ufw allow 5353/udp` |
| mDNS works intermittently | Network switch configuration | Ensure multicast traffic allowed |
| Services not accessible | Caddy not binding to all interfaces | Verify `BIND_ALL_INTERFACES: "true"` |

**Client-Side Configuration:**

**Linux/Mac:**
```bash
# Test mDNS resolution (should work automatically)
ping hostname.local

# If not working, ensure Avahi/Bonjour is installed
# Ubuntu/Debian: sudo apt install avahi-daemon
# macOS: Built-in Bonjour support
```

**Windows:**
```powershell
# Install Bonjour Print Services (includes mDNS)
# Or use third-party mDNS responders
# Test resolution:
ping hostname.local
```

**Advanced Configuration:**

```bash
# Edit Avahi configuration for custom hostname
sudo nano /etc/avahi/avahi-daemon.conf

# Example configuration:
[server]
host-name=borgstack-dev
domain-name=local
use-ipv4=yes
use-ipv6=yes

# Restart Avahi after changes
sudo systemctl restart avahi-daemon
```

**Network Requirements:**

- **Multicast Support**: Network switches must allow multicast traffic
- **UDP Port 5353**: mDNS uses UDP port 5353 for discovery
- **Same Subnet**: Devices must be on the same network segment
- **No VLAN Isolation**: mDNS traffic shouldn't be blocked by VLANs

### Prerequisites

```bash
# Target system requirements
# - GNU/Linux (clean installation)
# - 8 vCPUs (minimum 4 for testing)
# - 36GB RAM (minimum 16GB for testing)
# - 500GB SSD (minimum 200GB for testing)
# - Static IP or domain name with DNS configured

# Verify system resources
lscpu | grep "CPU(s)"              # Check CPU count
free -h                             # Check RAM
df -h                               # Check disk space
cat /etc/os-release                 # Verify GNU/Linux
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