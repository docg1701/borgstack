#!/usr/bin/env bash

#===============================================================================
# BorgStack - Interactive Restoration Script
#===============================================================================
# Interactive script for restoring data from Duplicati backups
#
# Usage:
#   ./scripts/restore.sh
#
# Features:
#   - Interactive menu-driven interface
#   - Restore individual files, services, or complete system
#   - Safety checks and confirmations
#   - Backup of current data before restoration
#
# Exit codes:
#   0 = Restoration completed successfully
#   1 = Error occurred or user cancelled
#===============================================================================

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Restoration options
RESTORE_TYPE=""
SERVICE_NAME=""
BACKUP_VERSION=""
RESTORE_PATH=""

#===============================================================================
# Helper Functions
#===============================================================================

print_header() {
    echo ""
    echo "========================================================================"
    echo -e "${CYAN}$1${NC}"
    echo "========================================================================"
}

print_section() {
    echo ""
    echo -e "${BLUE}━━━ $1 ━━━${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  INFO${NC}: $1"
}

print_success() {
    echo -e "${GREEN}✅ SUCCESS${NC}: $1"
}

print_error() {
    echo -e "${RED}❌ ERROR${NC}: $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️  WARNING${NC}: $1"
}

print_critical() {
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}⚠️  CRITICAL WARNING ⚠️${NC}"
    echo -e "${RED}$1${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

confirm_action() {
    local prompt="$1"
    local default="${2:-n}"

    if [ "$default" = "y" ]; then
        read -p "$(echo -e ${YELLOW}${prompt}${NC}) [Y/n]: " -r
        [[ $REPLY =~ ^[Nn]$ ]] && return 1 || return 0
    else
        read -p "$(echo -e ${YELLOW}${prompt}${NC}) [y/N]: " -r
        [[ $REPLY =~ ^[Yy]$ ]] && return 0 || return 1
    fi
}

press_enter_to_continue() {
    echo ""
    read -p "Press ENTER to continue..." -r
}

#===============================================================================
# Prerequisite Checks
#===============================================================================

check_prerequisites() {
    print_section "Checking Prerequisites"

    # Check if in project root
    if [ ! -f "docker-compose.yml" ]; then
        print_error "docker-compose.yml not found"
        echo "  Run this script from the BorgStack project root"
        exit 1
    fi

    # Check if Duplicati is running
    if ! docker compose ps duplicati | grep -q "healthy"; then
        print_error "Duplicati container is not healthy"
        echo ""
        echo "  Start Duplicati first:"
        echo "    docker compose up -d duplicati"
        echo ""
        echo "  Check status:"
        echo "    docker compose ps duplicati"
        echo "    docker compose logs duplicati"
        exit 1
    fi

    print_success "Prerequisites check passed"
}

#===============================================================================
# Main Menu
#===============================================================================

show_main_menu() {
    print_header "BorgStack - Interactive Restoration"

    cat << EOF

Select restoration type:

  ${GREEN}1${NC}) Restore Individual File or Directory
  ${GREEN}2${NC}) Restore Complete Service (n8n, Chatwoot, etc.)
  ${GREEN}3${NC}) Restore Database (PostgreSQL, MongoDB, Redis)
  ${GREEN}4${NC}) Restore Complete System (Disaster Recovery)
  ${GREEN}5${NC}) List Available Backups
  ${RED}0${NC}) Exit

EOF

    read -p "Enter your choice [0-5]: " choice

    case $choice in
        1) restore_individual_files ;;
        2) restore_service ;;
        3) restore_database ;;
        4) restore_complete_system ;;
        5) list_available_backups ;;
        0) exit 0 ;;
        *)
            print_error "Invalid choice"
            sleep 2
            show_main_menu
            ;;
    esac
}

#===============================================================================
# List Available Backups
#===============================================================================

list_available_backups() {
    print_header "Available Backups"

    print_info "Fetching backup list from Duplicati..."
    echo ""
    echo "  Please access Duplicati web UI to view available backups:"
    echo "    https://duplicati.{YOUR_DOMAIN}"
    echo ""
    echo "  In the web UI:"
    echo "    1. Select backup job"
    echo "    2. Click 'Restore'"
    echo "    3. View available backup versions with dates/times"
    echo ""

    press_enter_to_continue
    show_main_menu
}

#===============================================================================
# Restore Individual Files
#===============================================================================

restore_individual_files() {
    print_header "Restore Individual File or Directory"

    print_critical "DATA RESTORATION IN PROGRESS"
    echo "  This operation will restore files from backup"
    echo "  Existing files may be overwritten"

    if ! confirm_action "Do you want to continue?"; then
        print_info "Restoration cancelled"
        show_main_menu
        return
    fi

    cat << EOF

Available source paths:
  ${CYAN}/source/postgresql${NC}       - PostgreSQL databases
  ${CYAN}/source/mongodb${NC}          - MongoDB databases
  ${CYAN}/source/redis${NC}            - Redis data
  ${CYAN}/source/n8n${NC}              - n8n workflows and credentials
  ${CYAN}/source/evolution${NC}        - Evolution API WhatsApp sessions
  ${CYAN}/source/chatwoot_storage${NC} - Chatwoot uploads
  ${CYAN}/source/directus_uploads${NC} - Directus media files
  ${CYAN}/source/caddy${NC}            - SSL certificates

EOF

    read -p "Enter source path to restore (e.g., /source/n8n/workflows/my-workflow.json): " source_path
    read -p "Enter destination path (e.g., /tmp/restored-files): " dest_path

    print_section "Restoration Summary"
    echo "  Source: $source_path"
    echo "  Destination: $dest_path"
    echo ""

    if ! confirm_action "Proceed with restoration?"; then
        print_info "Restoration cancelled"
        show_main_menu
        return
    fi

    print_info "Starting restoration..."
    echo ""
    echo "  MANUAL STEPS REQUIRED:"
    echo "  1. Access Duplicati web UI: https://duplicati.{YOUR_DOMAIN}"
    echo "  2. Select backup job"
    echo "  3. Click 'Restore'"
    echo "  4. Choose backup version"
    echo "  5. Navigate to: $source_path"
    echo "  6. Restore to: $dest_path"
    echo "  7. Click 'Restore'"
    echo ""

    press_enter_to_continue
    show_main_menu
}

#===============================================================================
# Restore Complete Service
#===============================================================================

restore_service() {
    print_header "Restore Complete Service"

    print_critical "SERVICE RESTORATION IN PROGRESS"
    echo "  This operation will:"
    echo "  - Stop the service"
    echo "  - Backup current data (safety measure)"
    echo "  - Restore data from backup"
    echo "  - Restart the service"

    if ! confirm_action "Do you want to continue?"; then
        print_info "Restoration cancelled"
        show_main_menu
        return
    fi

    cat << EOF

Available services:
  ${CYAN}1${NC}) n8n              - Workflow automation
  ${CYAN}2${NC}) chatwoot         - Customer service platform
  ${CYAN}3${NC}) evolution        - WhatsApp API gateway
  ${CYAN}4${NC}) lowcoder         - Low-code app builder
  ${CYAN}5${NC}) directus         - Headless CMS
  ${CYAN}6${NC}) fileflows        - Media processing
  ${CYAN}0${NC}) Back to main menu

EOF

    read -p "Select service [0-6]: " service_choice

    case $service_choice in
        1) SERVICE_NAME="n8n" ;;
        2) SERVICE_NAME="chatwoot" ;;
        3) SERVICE_NAME="evolution" ;;
        4) SERVICE_NAME="lowcoder" ;;
        5) SERVICE_NAME="directus" ;;
        6) SERVICE_NAME="fileflows" ;;
        0) show_main_menu; return ;;
        *)
            print_error "Invalid choice"
            sleep 2
            restore_service
            return
            ;;
    esac

    print_section "Restoring: $SERVICE_NAME"

    # Safety backup of current data
    print_info "Creating safety backup of current $SERVICE_NAME data..."
    local backup_file="/tmp/${SERVICE_NAME}-pre-restore-$(date +%Y%m%d-%H%M%S).tar.gz"

    if docker compose exec -T "$SERVICE_NAME" tar czf "$backup_file" / 2>/dev/null; then
        print_success "Safety backup created: $backup_file"
    else
        print_warning "Could not create safety backup (service may not be running)"
    fi

    # Stop service
    print_info "Stopping $SERVICE_NAME service..."
    docker compose stop "$SERVICE_NAME"

    print_section "Restoration Instructions"
    echo ""
    echo "  ${YELLOW}MANUAL STEPS REQUIRED:${NC}"
    echo ""
    echo "  1. Access Duplicati web UI: https://duplicati.{YOUR_DOMAIN}"
    echo "  2. Select backup job: 'BorgStack-Backup-Completo'"
    echo "  3. Click 'Restore'"
    echo "  4. Choose backup version (date/time)"
    echo "  5. Navigate to: /source/${SERVICE_NAME}"
    echo "  6. Select entire directory"
    echo "  7. Restore to original location"
    echo "  8. Click 'Restore' and wait for completion"
    echo ""
    echo "  After restoration completes, return here"
    echo ""

    press_enter_to_continue

    # Restart service
    print_info "Starting $SERVICE_NAME service..."
    docker compose start "$SERVICE_NAME"

    print_info "Waiting for service to become healthy..."
    sleep 10

    if docker compose ps "$SERVICE_NAME" | grep -q "healthy"; then
        print_success "$SERVICE_NAME service is healthy"
    else
        print_warning "$SERVICE_NAME service may not be fully healthy yet"
        echo "  Check status: docker compose ps $SERVICE_NAME"
        echo "  Check logs: docker compose logs $SERVICE_NAME"
    fi

    print_section "Restoration Complete"
    echo ""
    echo "  Next steps:"
    echo "  - Test $SERVICE_NAME functionality"
    echo "  - Verify data was restored correctly"
    echo "  - Monitor logs for any errors"
    echo ""

    press_enter_to_continue
    show_main_menu
}

#===============================================================================
# Restore Database
#===============================================================================

restore_database() {
    print_header "Restore Database"

    print_critical "DATABASE RESTORATION IN PROGRESS"
    echo "  This operation will restore database data from backup"
    echo "  All dependent services will be stopped during restoration"

    if ! confirm_action "Do you want to continue?"; then
        print_info "Restoration cancelled"
        show_main_menu
        return
    fi

    cat << EOF

Available databases:
  ${CYAN}1${NC}) PostgreSQL - All databases (n8n, chatwoot, directus, evolution)
  ${CYAN}2${NC}) MongoDB    - Lowcoder database
  ${CYAN}3${NC}) Redis      - Cache and queue data
  ${CYAN}0${NC}) Back to main menu

EOF

    read -p "Select database [0-3]: " db_choice

    case $db_choice in
        1) restore_postgresql ;;
        2) restore_mongodb ;;
        3) restore_redis ;;
        0) show_main_menu; return ;;
        *)
            print_error "Invalid choice"
            sleep 2
            restore_database
            return
            ;;
    esac
}

restore_postgresql() {
    print_section "Restoring PostgreSQL Database"

    print_warning "This will stop: n8n, chatwoot, directus, evolution, postgresql"

    if ! confirm_action "Continue with PostgreSQL restoration?"; then
        restore_database
        return
    fi

    # Stop dependent services
    print_info "Stopping dependent services..."
    docker compose stop n8n chatwoot directus evolution postgresql

    # Create safety backup
    print_info "Creating safety backup..."
    docker compose start postgresql
    sleep 5
    docker compose exec postgresql pg_dumpall -U postgres > "/tmp/postgres-pre-restore-$(date +%Y%m%d-%H%M%S).sql" 2>/dev/null || true
    docker compose stop postgresql

    print_section "PostgreSQL Restoration Instructions"
    echo ""
    echo "  ${YELLOW}MANUAL STEPS REQUIRED:${NC}"
    echo ""
    echo "  1. Access Duplicati web UI"
    echo "  2. Restore /source/postgresql to original location"
    echo "  3. Wait for restoration to complete"
    echo ""

    press_enter_to_continue

    # Restart services
    print_info "Restarting services..."
    docker compose start postgresql
    sleep 15
    docker compose start n8n chatwoot directus evolution

    print_success "PostgreSQL restoration complete"
    press_enter_to_continue
    show_main_menu
}

restore_mongodb() {
    print_section "Restoring MongoDB Database"

    print_warning "This will stop: lowcoder-api-service, lowcoder-node-service, lowcoder-frontend, mongodb"

    if ! confirm_action "Continue with MongoDB restoration?"; then
        restore_database
        return
    fi

    # Similar process as PostgreSQL
    print_info "Stopping dependent services..."
    docker compose stop lowcoder-api-service lowcoder-node-service lowcoder-frontend mongodb

    print_section "MongoDB Restoration Instructions"
    echo ""
    echo "  ${YELLOW}MANUAL STEPS REQUIRED:${NC}"
    echo ""
    echo "  1. Access Duplicati web UI"
    echo "  2. Restore /source/mongodb to original location"
    echo "  3. Wait for restoration to complete"
    echo ""

    press_enter_to_continue

    print_info "Restarting services..."
    docker compose start mongodb
    sleep 10
    docker compose start lowcoder-api-service lowcoder-node-service lowcoder-frontend

    print_success "MongoDB restoration complete"
    press_enter_to_continue
    show_main_menu
}

restore_redis() {
    print_section "Restoring Redis Database"

    print_warning "This will stop all services temporarily"

    if ! confirm_action "Continue with Redis restoration?"; then
        restore_database
        return
    fi

    print_info "Stopping services..."
    docker compose stop

    print_section "Redis Restoration Instructions"
    echo ""
    echo "  ${YELLOW}MANUAL STEPS REQUIRED:${NC}"
    echo ""
    echo "  1. Access Duplicati web UI"
    echo "  2. Restore /source/redis to original location"
    echo "  3. Wait for restoration to complete"
    echo ""

    press_enter_to_continue

    print_info "Restarting all services..."
    docker compose up -d

    print_success "Redis restoration complete"
    press_enter_to_continue
    show_main_menu
}

#===============================================================================
# Restore Complete System
#===============================================================================

restore_complete_system() {
    print_header "Restore Complete System (Disaster Recovery)"

    print_critical "COMPLETE SYSTEM RESTORATION"
    echo "  This is a FULL DISASTER RECOVERY operation"
    echo ""
    echo "  This operation will:"
    echo "  - Stop ALL BorgStack services"
    echo "  - Restore ALL data from backup"
    echo "  - Restart all services"
    echo ""
    echo "  ${RED}DOWNTIME: 4-8 hours expected${NC}"
    echo ""

    if ! confirm_action "Are you ABSOLUTELY SURE you want to proceed?"; then
        print_info "Disaster recovery cancelled"
        show_main_menu
        return
    fi

    # Double confirmation
    echo ""
    print_warning "This action cannot be undone easily"
    if ! confirm_action "Type 'yes' to confirm COMPLETE SYSTEM RESTORATION"; then
        print_info "Disaster recovery cancelled"
        show_main_menu
        return
    fi

    print_section "Disaster Recovery Procedure"
    echo ""
    echo "  ${CYAN}Follow the complete disaster recovery guide:${NC}"
    echo "    docs/04-integrations/backup-strategy.md"
    echo ""
    echo "  ${YELLOW}Key steps:${NC}"
    echo "  1. Keep ONLY Duplicati running"
    echo "  2. Access Duplicati web UI"
    echo "  3. Restore ALL /source/* directories"
    echo "  4. Wait for complete restoration (may take hours)"
    echo "  5. Start all services: docker compose up -d"
    echo "  6. Verify all services are healthy"
    echo "  7. Test functionality of each service"
    echo ""

    if confirm_action "Start disaster recovery now?"; then
        print_info "Stopping all services except Duplicati..."
        docker compose stop $(docker compose ps --services | grep -v duplicati | tr '\n' ' ')

        print_section "Disaster Recovery In Progress"
        echo ""
        echo "  Access Duplicati web UI: https://duplicati.{YOUR_DOMAIN}"
        echo ""
        echo "  ${RED}DO NOT CLOSE THIS TERMINAL${NC}"
        echo "  Return here after restoration completes in Duplicati"
        echo ""

        press_enter_to_continue

        print_info "Starting all services..."
        docker compose up -d

        print_info "Waiting for services to initialize (this may take 5-10 minutes)..."
        sleep 60

        print_section "Disaster Recovery Status"
        docker compose ps

        echo ""
        print_info "Verify each service manually:"
        echo "  - Check health status above"
        echo "  - Test each service web UI"
        echo "  - Check logs for errors"
        echo ""
    fi

    press_enter_to_continue
    show_main_menu
}

#===============================================================================
# Main Execution
#===============================================================================

main() {
    # Change to project root
    cd "$(dirname "$0")/.." || exit 1

    # Run prerequisite checks
    check_prerequisites

    # Show main menu
    show_main_menu
}

# Trap Ctrl+C
trap 'echo ""; print_info "Operation cancelled by user"; exit 1' INT

# Run main function
main
