#!/usr/bin/env bash
#
# BorgStack Bootstrap Script
# Automated setup for GNU/Linux
#
# This script:
# 1. Validates system requirements (OS, RAM, CPU, disk)
# 2. Installs Docker Engine and Docker Compose v2
# 3. Configures UFW firewall
# 4. Generates .env file with strong passwords
# 5. Deploys all services
# 6. Validates health checks
# 7. Displays next steps for DNS/SSL configuration
#

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="/tmp/borgstack-bootstrap.log"

# Deployment mode: local-lan or production
DEPLOYMENT_MODE=""

# System requirements
MIN_RAM_GB=8
RECOMMENDED_RAM_GB=18
MIN_DISK_GB=100
RECOMMENDED_DISK_GB=250
MIN_CPU_CORES=2
RECOMMENDED_CPU_CORES=4

# ============================================================================
# COLOR OUTPUT FUNCTIONS
# ============================================================================

# Check if terminal supports colors
if [[ -t 1 ]]; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    MAGENTA=$(tput setaf 5)
    CYAN=$(tput setaf 6)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    MAGENTA=""
    CYAN=""
    BOLD=""
    RESET=""
fi

log_info() {
    echo "${BLUE}ℹ${RESET} $*" | tee -a "${LOG_FILE}"
}

log_success() {
    echo "${GREEN}✓${RESET} $*" | tee -a "${LOG_FILE}"
}

log_warning() {
    echo "${YELLOW}⚠${RESET} $*" | tee -a "${LOG_FILE}"
}

log_error() {
    echo "${RED}✗${RESET} $*" | tee -a "${LOG_FILE}"
}

log_section() {
    echo "" | tee -a "${LOG_FILE}"
    echo "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}" | tee -a "${LOG_FILE}"
    echo "${BOLD}${CYAN}$*${RESET}" | tee -a "${LOG_FILE}"
    echo "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}" | tee -a "${LOG_FILE}"
    echo "" | tee -a "${LOG_FILE}"
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Generate strong password (32 characters, alphanumeric)
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get total RAM in GB
get_total_ram_gb() {
    local ram_kb
    ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    echo $((ram_kb / 1024 / 1024))
}

# Get total disk space in GB for root partition
get_total_disk_gb() {
    df -BG / | awk 'NR==2 {print $2}' | sed 's/G//'
}

# Get CPU cores
get_cpu_cores() {
    nproc
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

validate_linux_distribution() {
    log_section "Validating Linux Distribution"

    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot detect OS version. /etc/os-release not found."
        log_error "This script requires Debian or Ubuntu."
        exit 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release

    if [[ "${ID}" == "ubuntu" ]]; then
        log_success "Ubuntu ${VERSION_ID} detected"
    elif [[ "${ID}" == "debian" ]]; then
        log_success "Debian ${VERSION_ID} detected"
    else
        log_error "Unsupported distribution: ${NAME}"
        log_error "This script only supports Debian and Ubuntu."
        log_error "For other distributions, see docs/01-instalacao.md (Manual Installation)"
        exit 1
    fi
}

validate_system_requirements() {
    log_section "Validating System Requirements"

    local ram_gb disk_gb cpu_cores
    local requirements_met=true

    # Check RAM
    ram_gb=$(get_total_ram_gb)
    log_info "RAM: ${ram_gb}GB (min: ${MIN_RAM_GB}GB, recommended: ${RECOMMENDED_RAM_GB}GB)"

    if [[ ${ram_gb} -lt ${MIN_RAM_GB} ]]; then
        log_error "Insufficient RAM: ${ram_gb}GB < ${MIN_RAM_GB}GB minimum"
        requirements_met=false
    elif [[ ${ram_gb} -lt ${RECOMMENDED_RAM_GB} ]]; then
        log_warning "RAM below recommended: ${ram_gb}GB < ${RECOMMENDED_RAM_GB}GB recommended"
    else
        log_success "RAM sufficient: ${ram_gb}GB"
    fi

    # Check disk space
    disk_gb=$(get_total_disk_gb)
    log_info "Disk: ${disk_gb}GB (min: ${MIN_DISK_GB}GB, recommended: ${RECOMMENDED_DISK_GB}GB)"

    if [[ ${disk_gb} -lt ${MIN_DISK_GB} ]]; then
        log_error "Insufficient disk space: ${disk_gb}GB < ${MIN_DISK_GB}GB minimum"
        requirements_met=false
    elif [[ ${disk_gb} -lt ${RECOMMENDED_DISK_GB} ]]; then
        log_warning "Disk space below recommended: ${disk_gb}GB < ${RECOMMENDED_DISK_GB}GB recommended"
    else
        log_success "Disk space sufficient: ${disk_gb}GB"
    fi

    # Check CPU cores
    cpu_cores=$(get_cpu_cores)
    log_info "CPU cores: ${cpu_cores} (min: ${MIN_CPU_CORES}, recommended: ${RECOMMENDED_CPU_CORES})"

    if [[ ${cpu_cores} -lt ${MIN_CPU_CORES} ]]; then
        log_error "Insufficient CPU cores: ${cpu_cores} < ${MIN_CPU_CORES} minimum"
        requirements_met=false
    elif [[ ${cpu_cores} -lt ${RECOMMENDED_CPU_CORES} ]]; then
        log_warning "CPU cores below recommended: ${cpu_cores} < ${RECOMMENDED_CPU_CORES} recommended"
    else
        log_success "CPU cores sufficient: ${cpu_cores}"
    fi

    if [[ "${requirements_met}" == "false" ]]; then
        log_error "System requirements not met. Please upgrade your server."
        exit 1
    fi

    log_success "All system requirements validated"
}

# ============================================================================
# DOCKER INSTALLATION
# ============================================================================

install_docker() {
    log_section "Installing Docker Engine and Docker Compose v2"

    # Check if Docker is already installed
    if command_exists docker; then
        local docker_version
        docker_version=$(docker --version)
        log_info "Docker already installed: ${docker_version}"

        if command_exists docker && docker compose version >/dev/null 2>&1; then
            local compose_version
            compose_version=$(docker compose version)
            log_info "Docker Compose already installed: ${compose_version}"
            log_success "Docker installation verified (skipping reinstall)"
            return 0
        fi
    fi

    log_info "Installing Docker Engine using official script..."

    # Use Docker's official installation script for cross-platform compatibility
    if ! curl -fsSL https://get.docker.com | sh; then
        log_error "Failed to install Docker using official script"
        log_error "Please install Docker manually for your distribution"
        exit 1
    fi

    # Add user to docker group
    log_info "Adding user '${USER}' to docker group..."
    sudo usermod -aG docker "${USER}"

    # Start and enable Docker service
    log_info "Starting Docker service..."
    if command_exists systemctl; then
        sudo systemctl start docker
        sudo systemctl enable docker >/dev/null 2>&1
    elif command_exists service; then
        sudo service docker start
    fi

    # Verify installation
    local docker_version compose_version
    docker_version=$(docker --version)
    compose_version=$(docker compose version)

    log_success "Docker installed: ${docker_version}"
    log_success "Docker Compose installed: ${compose_version}"

    log_warning "NOTE: You may need to log out and back in for docker group membership to take effect."
    log_warning "If you get permission errors, run: newgrp docker"
}

# ============================================================================
# SYSTEM DEPENDENCIES
# ============================================================================

install_system_dependencies() {
    log_section "Installing System Dependencies"

    log_info "Installing system packages with APT..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq curl wget git ufw dnsutils htop sysstat

    log_success "System dependencies installed"
}

# ============================================================================
# FIREWALL CONFIGURATION
# ============================================================================

configure_firewall() {
    log_section "Configuring Firewall (UFW)"

    configure_ufw
}

configure_ufw() {
    # Check if UFW is already enabled
    if sudo ufw status | grep -q "Status: active"; then
        log_info "UFW firewall already active"

        # Check if required rules exist
        if sudo ufw status | grep -q "22/tcp" && \
           sudo ufw status | grep -q "80/tcp" && \
           sudo ufw status | grep -q "443/tcp"; then
            log_success "Required firewall rules already configured"
            return 0
        fi
    fi

    log_info "Configuring UFW rules..."

    # Set default policies
    sudo ufw default deny incoming >/dev/null
    sudo ufw default allow outgoing >/dev/null

    # Allow SSH (port 22)
    log_info "Allowing SSH (port 22)..."
    sudo ufw allow 22/tcp >/dev/null
    log_warning "If you use a custom SSH port, adjust UFW rules manually"

    # Allow HTTP (port 80) for Let's Encrypt ACME challenge
    log_info "Allowing HTTP (port 80)..."
    sudo ufw allow 80/tcp >/dev/null

    # Allow HTTPS (port 443)
    log_info "Allowing HTTPS (port 443)..."
    sudo ufw allow 443/tcp >/dev/null

    # Enable firewall
    log_info "Enabling UFW firewall..."
    sudo ufw --force enable >/dev/null

    # Display status
    echo ""
    sudo ufw status verbose
    echo ""

    log_success "Firewall configured"
}

# ============================================================================
# .ENV FILE GENERATION
# ============================================================================

generate_env_file() {
    log_section "Generating .env File"

    local env_file="${PROJECT_ROOT}/.env"

    # Check if .env already exists
    if [[ -f "${env_file}" ]]; then
        log_warning ".env file already exists"

        read -rp "${YELLOW}⚠${RESET} Overwrite existing .env file? (y/N): " confirm
        if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
            log_info "Keeping existing .env file"
            return 0
        fi

        # Backup existing .env
        local backup_file="${env_file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "${env_file}" "${backup_file}"
        log_info "Backed up existing .env to ${backup_file}"
    fi

    # Mode-specific configuration
    if [[ "${DEPLOYMENT_MODE}" == "local-lan" ]]; then
        generate_local_env_file
    else
        generate_production_env_file
    fi

    # Set secure permissions
    chmod 600 "${env_file}"
    log_success ".env file created with secure permissions (600)"

    # Display credential summary
    display_credentials_summary
}

generate_local_env_file() {
    log_info "Configuring for Local Development (LAN) mode..."

    local hostname domain email
    hostname=$(hostname)
    domain="${hostname}.local"
    email="admin@localhost"

    log_info "Using hostname: ${hostname}"
    log_info "Using domain: ${domain}"
    log_info "Using email: ${email}"

    echo ""
    log_info "Generating strong passwords..."

    # Generate passwords
    local postgres_password=$(generate_password)
    local n8n_db_password=$(generate_password)
    local n8n_basic_auth_password=$(generate_password)
    local n8n_encryption_key=$(openssl rand -base64 32)
    local chatwoot_db_password=$(generate_password)
    local directus_db_password=$(generate_password)
    local evolution_db_password=$(generate_password)
    local mongo_root_password=$(generate_password)
    local lowcoder_db_password=$(generate_password)
    local redis_password=$(generate_password)
    local chatwoot_secret_key_base=$(openssl rand -hex 64)
    local directus_key=$(openssl rand -hex 16)
    local directus_secret=$(openssl rand -base64 32)
    local directus_admin_password=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-24)
    local evolution_jwt_secret=$(generate_password)
    local evolution_api_key=$(openssl rand -base64 32)
    local lowcoder_admin_password=$(generate_password)
    local lowcoder_encryption_password=$(generate_password)
    local lowcoder_encryption_salt=$(generate_password)
    local lowcoder_readonly_db_password=$(generate_password)

    # Get IP for fallback access
    local vps_ip
    vps_ip=$(hostname -I | awk '{print $1}')

    # Create .env file for local mode
    log_info "Writing .env file for Local Development (LAN) mode..."

    cat > "${env_file}" <<EOF
# BorgStack Environment Variables - Local Development (LAN) Mode
# Generated: $(date)
# WARNING: Keep this file secure and never commit to version control

# ============================================================================
# LOCAL DEVELOPMENT CONFIGURATION
# ============================================================================
# Local development with mDNS hostname discovery
HOSTNAME=${hostname}
BORGSTACK_DOMAIN=${domain}
VPS_IP=${vps_ip}
CADDY_EMAIL=admin@localhost

# CORS Configuration
# Allow all origins for local development
CORS_ALLOWED_ORIGINS=*

# ============================================================================
# POSTGRESQL DATABASE
# ============================================================================
POSTGRES_PASSWORD=${postgres_password}

# Database credentials for services
N8N_DB_PASSWORD=${n8n_db_password}
CHATWOOT_DB_PASSWORD=${chatwoot_db_password}
DIRECTUS_DB_PASSWORD=${directus_db_password}
EVOLUTION_DB_PASSWORD=${evolution_db_password}

# ============================================================================
# MONGODB DATABASE
# ============================================================================
MONGODB_ROOT_PASSWORD=${mongo_root_password}
LOWCODER_DB_PASSWORD=${lowcoder_db_password}

# ============================================================================
# REDIS CACHE
# ============================================================================
REDIS_PASSWORD=${redis_password}

# ============================================================================
# n8n CONFIGURATION
# ============================================================================
N8N_HOST=n8n.${domain}
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=${n8n_basic_auth_password}
N8N_ENCRYPTION_KEY=${n8n_encryption_key}

# ============================================================================
# CHATWOOT CONFIGURATION
# ============================================================================
CHATWOOT_HOST=chatwoot.${domain}
CHATWOOT_SECRET_KEY_BASE=${chatwoot_secret_key_base}
CHATWOOT_API_TOKEN=<obtain-from-admin-ui-after-first-login>

# ============================================================================
# DIRECTUS CONFIGURATION
# ============================================================================
DIRECTUS_HOST=directus.${domain}
DIRECTUS_KEY=${directus_key}
DIRECTUS_SECRET=${directus_secret}
DIRECTUS_ADMIN_EMAIL=admin@localhost
DIRECTUS_ADMIN_PASSWORD=${directus_admin_password}

# ============================================================================
# OTHER APPLICATION SECRETS
# ============================================================================
EVOLUTION_JWT_SECRET=${evolution_jwt_secret}

# ============================================================================
# EVOLUTION API CONFIGURATION
# ============================================================================
EVOLUTION_HOST=evolution.${domain}
EVOLUTION_API_KEY=${evolution_api_key}
EVOLUTION_WEBHOOK_URL=http://n8n.${domain}:8080/webhook/whatsapp-incoming
DATABASE_CONNECTION_CLIENT_NAME=evolution_api

# ============================================================================
# LOWCODER CONFIGURATION
# ============================================================================
LOWCODER_HOST=lowcoder.${domain}
LOWCODER_ADMIN_EMAIL=admin@localhost
LOWCODER_ADMIN_PASSWORD=${lowcoder_admin_password}
LOWCODER_ENCRYPTION_PASSWORD=${lowcoder_encryption_password}
LOWCODER_ENCRYPTION_SALT=${lowcoder_encryption_salt}
LOWCODER_READONLY_DB_PASSWORD=${lowcoder_readonly_db_password}

# ============================================================================
# ADDITIONAL CONFIGURATION
# ============================================================================
# Timezone (affects logs, scheduling)
TZ=America/Sao_Paulo

# Backup configuration
DUPLICATI_PASSPHRASE=$(generate_password)
EOF
}

generate_production_env_file() {
    log_info "Configuring for Production mode..."

    # Prompt for DOMAIN
    local domain
    read -rp "${CYAN}Enter your domain (e.g., example.com.br):${RESET} " domain
    while [[ -z "${domain}" ]]; do
        log_error "Domain cannot be empty"
        read -rp "${CYAN}Enter your domain:${RESET} " domain
    done

    # Prompt for EMAIL
    local email
    read -rp "${CYAN}Enter your email for SSL notifications (e.g., admin@${domain}):${RESET} " email
    while [[ -z "${email}" ]]; do
        log_error "Email cannot be empty"
        read -rp "${CYAN}Enter your email:${RESET} " email
    done

    echo ""
    log_info "Using domain: ${domain}"
    log_info "Using email: ${email}"

    echo ""
    log_info "Generating strong passwords..."

    # Generate passwords
    local postgres_password=$(generate_password)
    local n8n_db_password=$(generate_password)
    local n8n_basic_auth_password=$(generate_password)
    local n8n_encryption_key=$(openssl rand -base64 32)
    local chatwoot_db_password=$(generate_password)
    local directus_db_password=$(generate_password)
    local evolution_db_password=$(generate_password)
    local mongo_root_password=$(generate_password)
    local lowcoder_db_password=$(generate_password)
    local redis_password=$(generate_password)
    local chatwoot_secret_key_base=$(openssl rand -hex 64)
    local directus_key=$(openssl rand -hex 16)
    local directus_secret=$(openssl rand -base64 32)
    local directus_admin_password=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-24)
    local evolution_jwt_secret=$(generate_password)
    local evolution_api_key=$(openssl rand -base64 32)
    local lowcoder_admin_password=$(generate_password)
    local lowcoder_encryption_password=$(generate_password)
    local lowcoder_encryption_salt=$(generate_password)
    local lowcoder_readonly_db_password=$(generate_password)

    # Create .env file for production mode
    log_info "Writing .env file for Production mode..."

    cat > "${env_file}" <<EOF
# BorgStack Environment Variables - Production Mode
# Generated: $(date)
# WARNING: Keep this file secure and never commit to version control

# ============================================================================
# DOMAIN CONFIGURATION
# ============================================================================
DOMAIN=${domain}
EMAIL=${email}

# CORS Configuration
# WARNING: Change "*" to specific origins in production
# Example: CORS_ALLOWED_ORIGINS=https://n8n.${domain},https://chatwoot.${domain}
CORS_ALLOWED_ORIGINS=*

# ============================================================================
# POSTGRESQL DATABASE
# ============================================================================
POSTGRES_PASSWORD=${postgres_password}

# Database credentials for services
N8N_DB_PASSWORD=${n8n_db_password}
CHATWOOT_DB_PASSWORD=${chatwoot_db_password}
DIRECTUS_DB_PASSWORD=${directus_db_password}
EVOLUTION_DB_PASSWORD=${evolution_db_password}

# ============================================================================
# MONGODB DATABASE
# ============================================================================
MONGODB_ROOT_PASSWORD=${mongo_root_password}
LOWCODER_DB_PASSWORD=${lowcoder_db_password}

# ============================================================================
# REDIS CACHE
# ============================================================================
REDIS_PASSWORD=${redis_password}

# ============================================================================
# n8n CONFIGURATION
# ============================================================================
N8N_HOST=n8n.${domain}
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=${n8n_basic_auth_password}
N8N_ENCRYPTION_KEY=${n8n_encryption_key}

# ============================================================================
# CHATWOOT CONFIGURATION
# ============================================================================
CHATWOOT_HOST=chatwoot.${domain}
CHATWOOT_SECRET_KEY_BASE=${chatwoot_secret_key_base}
CHATWOOT_API_TOKEN=<obtain-from-admin-ui-after-first-login>

# ============================================================================
# DIRECTUS CONFIGURATION
# ============================================================================
DIRECTUS_HOST=directus.${domain}
DIRECTUS_KEY=${directus_key}
DIRECTUS_SECRET=${directus_secret}
DIRECTUS_ADMIN_EMAIL=admin@${domain}
DIRECTUS_ADMIN_PASSWORD=${directus_admin_password}

# ============================================================================
# OTHER APPLICATION SECRETS
# ============================================================================
EVOLUTION_JWT_SECRET=${evolution_jwt_secret}

# ============================================================================
# EVOLUTION API CONFIGURATION
# ============================================================================
EVOLUTION_HOST=evolution.${domain}
EVOLUTION_API_KEY=${evolution_api_key}
EVOLUTION_WEBHOOK_URL=https://n8n.${domain}/webhook/whatsapp-incoming
DATABASE_CONNECTION_CLIENT_NAME=evolution_api

# ============================================================================
# LOWCODER CONFIGURATION
# ============================================================================
LOWCODER_HOST=lowcoder.${domain}
LOWCODER_ADMIN_EMAIL=admin@${domain}
LOWCODER_ADMIN_PASSWORD=${lowcoder_admin_password}
LOWCODER_ENCRYPTION_PASSWORD=${lowcoder_encryption_password}
LOWCODER_ENCRYPTION_SALT=${lowcoder_encryption_salt}
LOWCODER_READONLY_DB_PASSWORD=${lowcoder_readonly_db_password}

# ============================================================================
# ADDITIONAL CONFIGURATION
# ============================================================================
# Timezone (affects logs, scheduling)
TZ=America/Sao_Paulo

# Backup configuration
DUPLICATI_PASSPHRASE=$(generate_password)
EOF
}

display_credentials_summary() {
    echo ""
    log_section "Generated Credentials Summary"
    echo "${BOLD}${YELLOW}⚠ IMPORTANT: Save these credentials in a secure password manager!${RESET}"
    echo ""

    if [[ "${DEPLOYMENT_MODE}" == "local-lan" ]]; then
        local hostname
        hostname=$(hostname)
        echo "${CYAN}Mode:${RESET} Local Development (LAN)"
        echo "${CYAN}Hostname:${RESET} ${hostname}"
        echo "${CYAN}Domain:${RESET} ${hostname}.local"
        echo "${CYAN}IP Address:${RESET} $(hostname -I | awk '{print $1}')"
        echo ""
        echo "${CYAN}Access URLs (via mDNS):${RESET}"
        echo "  http://${hostname}.local:8080/n8n"
        echo "  http://${hostname}.local:8080/chatwoot"
        echo "  http://${hostname}.local:8080/evolution"
        echo "  http://${hostname}.local:8080/lowcoder"
        echo "  http://${hostname}.local:8080/directus"
        echo "  http://${hostname}.local:8080/fileflows"
        echo "  http://${hostname}.local:8080/duplicati"
        echo ""
        echo "${CYAN}Access URLs (via IP):${RESET}"
        echo "  http://$(hostname -I | awk '{print $1}'):8080/n8n"
        echo "  http://$(hostname -I | awk '{print $1}'):8080/chatwoot"
        echo "  (and so on for all services)"
        echo ""
        echo "${CYAN}n8n Basic Auth:${RESET} admin / ${n8n_basic_auth_password}"
        echo "${CYAN}PostgreSQL Root:${RESET} postgres / ${postgres_password}"
        echo "${CYAN}MongoDB Root:${RESET} admin / ${mongo_root_password}"
        echo "${CYAN}Redis:${RESET} ${redis_password}"
        echo ""
        echo "${BOLD}${YELLOW}📚 Documentation for troubleshooting:${RESET}"
        echo "  → docs/02-configuracao.md (Configuração de Hostname Local)"
        echo "  → docs/architecture/development-workflow.md (mDNS/Avahi Configuration)"
        echo "  → README.md (mDNS Setup)"
        echo ""
    else
        echo "${CYAN}Mode:${RESET} Production"
        echo "${CYAN}Domain:${RESET} ${domain}"
        echo "${CYAN}Email:${RESET} ${email}"
        echo ""
        echo "${CYAN}n8n Web UI:${RESET} https://n8n.${domain}"
        echo "${CYAN}n8n Basic Auth:${RESET} admin / ${n8n_basic_auth_password}"
        echo ""
        echo "${CYAN}Chatwoot Admin UI:${RESET} https://chatwoot.${domain}/app"
        echo "${CYAN}Directus Admin UI:${RESET} https://directus.${domain}/admin"
        echo "${CYAN}Evolution API Admin:${RESET} https://evolution.${domain}/manager"
        echo "${CYAN}Lowcoder Admin:${RESET} https://lowcoder.${domain}"
        echo ""
        echo "${CYAN}Database Access:${RESET}"
        echo "  PostgreSQL: postgres / ${postgres_password}"
        echo "  MongoDB: admin / ${mongo_root_password}"
        echo "  Redis: ${redis_password}"
        echo ""
        echo "${BOLD}${YELLOW}⚠️  IMPORTANT: CHATWOOT_API_TOKEN requires manual generation:${RESET}"
        echo "${YELLOW}   1. Login to Chatwoot: https://chatwoot.${domain}/app${RESET}"
        echo "${YELLOW}   2. Go to Settings → Account Settings → Access Tokens${RESET}"
        echo "${YELLOW}   3. Create New Token and add to .env as CHATWOOT_API_TOKEN${RESET}"
        echo "${YELLOW}   4. Restart chatwoot: docker compose restart chatwoot${RESET}"
        echo ""
    fi

    echo "${YELLOW}All credentials are stored in: ${env_file}${RESET}"
    echo "${YELLOW}File permissions: -rw------- (600)${RESET}"
    echo ""
}

# ============================================================================
# DEPLOYMENT
# ============================================================================

deploy_services() {
    log_section "Deploying BorgStack Services"

    cd "${PROJECT_ROOT}"

    # Pull Docker images
    log_info "Pulling Docker images (this may take several minutes)..."
    if ! docker compose pull; then
        log_error "Failed to pull Docker images"
        log_error "Check your internet connection and try again"
        exit 1
    fi

    log_success "All Docker images pulled successfully"

    # Start services
    log_info "Starting services..."
    if ! docker compose up -d; then
        log_error "Failed to start services"
        log_error "Check logs: docker compose logs"
        exit 1
    fi

    log_success "Services started"

    # Wait for initialization
    log_info "Waiting for services to initialize (60 seconds)..."
    sleep 60

    log_success "Deployment complete"
}

# ============================================================================
# HEALTH CHECKS
# ============================================================================

validate_health_checks() {
    log_section "Validating Service Health"

    cd "${PROJECT_ROOT}"

    # Get service status
    log_info "Checking service status..."
    echo ""
    docker compose ps
    echo ""

    local all_healthy=true

    # Check Caddy
    log_info "Checking Caddy..."
    if docker compose ps caddy | grep -q "Up"; then
        log_success "Caddy is running"
    else
        log_error "Caddy is not running"
        all_healthy=false
    fi

    # Check PostgreSQL
    log_info "Checking PostgreSQL..."
    if docker compose exec -T postgresql pg_isready -U postgres >/dev/null 2>&1; then
        log_success "PostgreSQL is healthy"
    else
        log_warning "PostgreSQL health check failed (may still be initializing)"
        all_healthy=false
    fi

    # Check Redis
    log_info "Checking Redis..."
    if docker compose exec -T redis redis-cli -a "${REDIS_PASSWORD:-redis}" ping >/dev/null 2>&1; then
        log_success "Redis is healthy"
    else
        log_warning "Redis health check failed"
        all_healthy=false
    fi

    # Check MongoDB
    log_info "Checking MongoDB..."
    if docker compose ps mongodb | grep -q "Up"; then
        log_success "MongoDB is running"
    else
        log_warning "MongoDB is not running"
        all_healthy=false
    fi

    echo ""

    if [[ "${all_healthy}" == "false" ]]; then
        log_warning "Some services are not fully healthy yet"
        log_info "Services may still be initializing. Check status with:"
        log_info "  docker compose ps"
        log_info "  docker compose logs [service_name]"
    else
        log_success "All core services are healthy"
    fi
}

# ============================================================================
# NEXT STEPS INSTRUCTIONS
# ============================================================================

display_next_steps() {
    log_section "Next Steps"

    echo "${BOLD}${GREEN}🎉 BorgStack bootstrap completed successfully!${RESET}"
    echo ""

    if [[ "${DEPLOYMENT_MODE}" == "local-lan" ]]; then
        display_local_next_steps
    else
        display_production_next_steps
    fi

    echo "${BOLD}General Commands:${RESET}"
    echo "   View logs: ${YELLOW}docker compose logs [service_name]${RESET}"
    echo "   Check status: ${YELLOW}docker compose ps${RESET}"
    echo "   Restart service: ${YELLOW}docker compose restart [service_name]${RESET}"
    echo "   Bootstrap log: ${YELLOW}${LOG_FILE}${RESET}"
    echo ""
}

display_local_next_steps() {
    local hostname
    hostname=$(hostname)
    local vps_ip
    vps_ip=$(hostname -I | awk '{print $1}')

    echo "${BOLD}Local Development (LAN) - Next Steps:${RESET}"
    echo ""

    echo "${BOLD}1. Test mDNS Resolution${RESET}"
    echo "   Verify that mDNS is working properly:"
    echo ""
    echo "   ${CYAN}ping ${hostname}.local${RESET}"
    echo "   ${CYAN}curl http://${hostname}.local:8080${RESET}"
    echo "   ${CYAN}avahi-browse -a -t${RESET} (discover services on network)"
    echo ""

    echo "${BOLD}2. Access Your Services${RESET}"
    echo "   Your BorgStack is accessible via:"
    echo ""
    echo "   ${GREEN}Via mDNS (recommended):${RESET}"
    echo "     http://${hostname}.local:8080/n8n"
    echo "     http://${hostname}.local:8080/chatwoot"
    echo "     http://${hostname}.local:8080/evolution"
    echo "     http://${hostname}.local:8080/lowcoder"
    echo "     http://${hostname}.local:8080/directus"
    echo "     http://${hostname}.local:8080/fileflows"
    echo "     http://${hostname}.local:8080/duplicati"
    echo ""
    echo "   ${GREEN}Via IP address (fallback):${RESET}"
    echo "     http://${vps_ip}:8080/n8n"
    echo "     http://${vps_ip}:8080/chatwoot"
    echo "     (and so on for all services)"
    echo ""
    echo "   ${GREEN}Via localhost (on server):${RESET}"
    echo "     http://localhost:8080/n8n"
    echo "     http://localhost:8080/chatwoot"
    echo "     (and so on for all services)"
    echo ""

    echo "${BOLD}3. Client-Side Configuration${RESET}"
    echo "   From other devices on your network:"
    echo ""
    echo "   ${CYAN}Linux/Mac (usually works automatically):${RESET}"
    echo "     ping ${hostname}.local"
    echo "     # If not working, install Avahi/Bonjour"
    echo ""
    echo "   ${CYAN}Windows (requires installation):${RESET}"
    echo "     1. Install Bonjour Print Services from Apple"
    echo "     2. Test: ping ${hostname}.local"
    echo ""
    echo "   ${CYAN}Manual configuration (alternative):${RESET}"
    echo "     # Add to /etc/hosts on client machines:"
    echo "     echo '${vps_ip} ${hostname} ${hostname}.local' | sudo tee -a /etc/hosts"
    echo ""

    echo "${BOLD}4. Troubleshooting mDNS${RESET}"
    echo "   If ${hostname}.local doesn't resolve:"
    echo "   • Check if Avahi is running: sudo systemctl status avahi-daemon"
    echo "   • Check firewall: sudo ufw status | grep 5353"
    echo "   • Check network: ping ${vps_ip}"
    echo "   • See docs/02-configuracao.md for detailed troubleshooting"
    echo ""

    echo "${BOLD}5. Security Recommendations${RESET}"
    echo "   ${YELLOW}⚠${RESET} This is for local development only"
    echo "   ${YELLOW}⚠${RESET} Do not expose to internet without proper security"
    echo "   ${YELLOW}⚠${RESET} Save all passwords from .env to a secure password manager"
    echo "   ${YELLOW}⚠${RESET} Consider changing CORS_ALLOWED_ORIGINS from '*' in production"
    echo ""

    echo "${BOLD}📚 Documentation for Local Development:${RESET}"
    echo "   → docs/02-configuracao.md (Configuração de Hostname Local)"
    echo "   → docs/architecture/development-workflow.md (mDNS/Avahi Configuration)"
    echo "   → README.md (mDNS Setup)"
    echo "   → tests/deployment/verify-local-override-configuration.sh (verification script)"
    echo ""
}

display_production_next_steps() {
    # Load domain from .env
    local domain
    if [[ -f "${PROJECT_ROOT}/.env" ]]; then
        domain=$(grep "^DOMAIN=" "${PROJECT_ROOT}/.env" | cut -d= -f2)
    fi

    echo "${BOLD}Production Deployment - Next Steps:${RESET}"
    echo ""

    echo "${BOLD}1. Configure DNS A Records${RESET}"
    echo "   Add the following DNS records pointing to your server IP:"
    echo ""
    echo "   ${CYAN}n8n.${domain}${RESET}        → Your Server IP"
    echo "   ${CYAN}chatwoot.${domain}${RESET}   → Your Server IP"
    echo "   ${CYAN}evolution.${domain}${RESET}  → Your Server IP"
    echo "   ${CYAN}lowcoder.${domain}${RESET}   → Your Server IP"
    echo "   ${CYAN}directus.${domain}${RESET}   → Your Server IP"
    echo "   ${CYAN}fileflows.${domain}${RESET}  → Your Server IP"
    echo "   ${CYAN}duplicati.${domain}${RESET}  → Your Server IP"
    echo ""

    echo "${BOLD}2. Verify DNS Configuration${RESET}"
    echo "   Wait for DNS propagation (5-30 minutes), then verify:"
    echo ""
    echo "   ${YELLOW}dig n8n.${domain} +short${RESET}"
    echo "   ${YELLOW}dig chatwoot.${domain} +short${RESET}"
    echo "   ${YELLOW}# ... etc for all subdomains${RESET}"
    echo ""

    echo "${BOLD}3. SSL Certificates (Automatic)${RESET}"
    echo "   Caddy will automatically generate Let's Encrypt SSL certificates"
    echo "   when you first access each subdomain via HTTPS."
    echo ""
    echo "   ${CYAN}First access may take 30-60 seconds per domain${RESET}"
    echo "   ${CYAN}Certificates automatically renew before expiration${RESET}"
    echo ""

    echo "${BOLD}4. Access Your Services${RESET}"
    echo "   Once DNS is configured, access services at:"
    echo ""
    echo "   ${GREEN}https://n8n.${domain}${RESET}"
    echo "   ${GREEN}https://chatwoot.${domain}${RESET}"
    echo "   ${GREEN}https://evolution.${domain}${RESET}"
    echo "   ${GREEN}https://lowcoder.${domain}${RESET}"
    echo "   ${GREEN}https://directus.${domain}${RESET}"
    echo "   ${GREEN}https://fileflows.${domain}${RESET}"
    echo "   ${GREEN}https://duplicati.${domain}${RESET}"
    echo ""

    echo "${BOLD}5. Security Recommendations${RESET}"
    echo "   ${YELLOW}⚠${RESET} Change CORS_ALLOWED_ORIGINS from '*' to specific origins in production"
    echo "   ${YELLOW}⚠${RESET} Save all passwords from .env to a secure password manager"
    echo "   ${YELLOW}⚠${RESET} Consider enabling full disk encryption (LUKS) for production"
    echo "   ${YELLOW}⚠${RESET} Set up regular backups (Duplicati configuration)"
    echo ""

    echo "${BOLD}📚 Documentation for Production:${RESET}"
    echo "   → docs/02-configuracao.md (Configuração de Domínios)"
    echo "   → README.md (production setup)"
    echo "   → docs/architecture/development-workflow.md (production deployment)"
    echo ""
}

# ============================================================================
# AVAHI/MDNS INSTALLATION (Local LAN Mode)
# ============================================================================

install_avahi_daemon() {
    log_section "Installing Avahi for mDNS (Local LAN Mode)"

    # Check if Avahi is already installed
    if command_exists avahi-daemon; then
        log_info "Avahi daemon is already installed"

        # Check if service is running
        if sudo systemctl is-active --quiet avahi-daemon; then
            log_success "Avahi daemon is already running"
            return 0
        else
            log_info "Starting Avahi daemon..."
            sudo systemctl start avahi-daemon
            sudo systemctl enable avahi-daemon
        fi
    else
        log_info "Installing Avahi daemon for mDNS hostname discovery..."

        # Install Avahi packages
        sudo apt-get update -qq
        sudo apt-get install -y -qq avahi-daemon avahi-utils

        # Enable and start Avahi service
        log_info "Enabling and starting Avahi daemon..."
        sudo systemctl enable avahi-daemon
        sudo systemctl start avahi-daemon

        # Verify installation
        if sudo systemctl is-active --quiet avahi-daemon; then
            log_success "Avahi daemon installed and started successfully"
        else
            log_error "Failed to start Avahi daemon"
            exit 1
        fi
    fi

    # Test mDNS resolution
    local hostname
    hostname=$(hostname)
    log_info "Testing mDNS resolution for ${hostname}.local..."

    if ping -c 2 "${hostname}.local" >/dev/null 2>&1; then
        log_success "mDNS resolution working: ${hostname}.local"
    else
        log_warning "mDNS resolution not working yet (may take a few moments)"
        log_info "You can test later with: ping ${hostname}.local"
    fi

    log_success "Avahi/mDNS configuration completed"
}

configure_firewall_for_mdns() {
    log_section "Configuring Firewall for mDNS (Local LAN Mode)"

    log_info "Configuring UFW for mDNS..."

    # Allow mDNS (UDP port 5353)
    sudo ufw allow 5353/udp comment "mDNS" >/dev/null

    log_success "mDNS firewall rules configured"
}

# ============================================================================
# DEPLOYMENT MODE SELECTION
# ============================================================================

select_deployment_mode() {
    log_section "Selecting Deployment Mode"

    echo ""
    echo "${BOLD}${CYAN}🚀 BorgStack Installation Mode${RESET}"
    echo ""
    echo "${BOLD}Choose your installation type:${RESET}"
    echo ""
    echo "${GREEN}1)${RESET} ${BOLD}Local Development (LAN)${RESET}"
    echo "   • Access via hostname.local (e.g., debian13-lxc.local:8080/n8n)"
    echo "   • Automatic mDNS/Avahi setup"
    echo "   • HTTP only (no SSL)"
    echo "   • Database ports exposed for debugging"
    echo "   • Perfect for local development and testing"
    echo ""
    echo "${BLUE}2)${RESET} ${BOLD}Production Deployment${RESET}"
    echo "   • Access via public domain (e.g., n8n.yourdomain.com)"
    echo "   • Requires DNS configuration"
    echo "   • Automatic HTTPS with Let's Encrypt SSL"
    echo "   • Secure configuration for production use"
    echo ""
    echo "${YELLOW}3)${RESET} ${BOLD}Cancel${RESET} - Exit the script"
    echo ""

    local choice
    while true; do
        read -rp "${CYAN}Enter your choice (1, 2, or 3):${RESET} " choice

        case $choice in
            1)
                DEPLOYMENT_MODE="local-lan"
                log_success "Selected: Local Development (LAN) mode"
                echo ""
                echo "${GREEN}✓${RESET} Local Development (LAN) mode selected"
                echo "  → Access URLs will use hostname.local"
                echo "  → mDNS/Avahi will be configured automatically"
                break
                ;;
            2)
                DEPLOYMENT_MODE="production"
                log_success "Selected: Production mode"
                echo ""
                echo "${GREEN}✓${RESET} Production mode selected"
                echo "  → You will be asked for your domain name"
                echo "  → SSL certificates will be configured automatically"
                break
                ;;
            3)
                log_info "Installation cancelled by user"
                echo ""
                echo "${YELLOW}Installation cancelled.${RESET}"
                exit 0
                ;;
            *)
                log_error "Invalid choice. Please enter 1, 2, or 3."
                echo ""
                echo "${RED}✗${RESET} Invalid choice. Please enter 1, 2, or 3."
                ;;
        esac
    done

    echo ""
    log_info "Deployment mode: ${DEPLOYMENT_MODE}"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    # Initialize log file
    echo "BorgStack Bootstrap Log - $(date)" > "${LOG_FILE}"
    echo "============================================" >> "${LOG_FILE}"
    echo "" >> "${LOG_FILE}"

    # Display banner
    clear
    echo "${BOLD}${MAGENTA}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║                  BorgStack Bootstrap Script                    ║"
    echo "║                                                                ║"
    echo "║              Automated GNU/Linux Setup                        ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo "${RESET}"
    echo ""

    log_info "Starting BorgStack bootstrap..."
    log_info "Log file: ${LOG_FILE}"
    echo ""

    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should NOT be run as root"
        log_error "Run as a regular user with sudo privileges"
        exit 1
    fi

    # Check if sudo available
    if ! sudo -n true 2>/dev/null; then
        log_info "This script requires sudo privileges"
        sudo -v
    fi

    # Select deployment mode
    select_deployment_mode

    # Execute bootstrap steps based on mode
    validate_linux_distribution
    validate_system_requirements
    install_system_dependencies
    install_docker

    # Mode-specific steps
    if [[ "${DEPLOYMENT_MODE}" == "local-lan" ]]; then
        install_avahi_daemon
        configure_firewall_for_mdns
    fi

    configure_firewall
    generate_env_file
    deploy_services
    validate_health_checks
    display_next_steps

    log_success "Bootstrap completed! Estimated setup time: 4-6 hours for full configuration"
}

# Run main function
main "$@"
