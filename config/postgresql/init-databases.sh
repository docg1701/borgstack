#!/usr/bin/env bash
# ===========================================================================
# BorgStack - PostgreSQL Database Initialization Script
# ===========================================================================
#
# Purpose: Initialize separate databases for each service with dedicated users
# Executed once on first container startup via /docker-entrypoint-initdb.d/
#
# This script substitutes environment variables (${VAR}) and executes SQL
# PostgreSQL .sql files don't support variable substitution natively
#
# Environment Variables Required:
#   - N8N_DB_PASSWORD
#   - CHATWOOT_DB_PASSWORD
#   - DIRECTUS_DB_PASSWORD
#   - EVOLUTION_DB_PASSWORD
# ===========================================================================

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}[BorgStack]${NC} Initializing databases and users..."

# ===========================================================================
# n8n Database Configuration
# ===========================================================================
echo -e "${BLUE}[BorgStack]${NC} Creating n8n_db and n8n_user..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	-- ============================================================================
	-- n8n Database Configuration
	-- ============================================================================
	CREATE DATABASE n8n_db;
	CREATE USER n8n_user WITH ENCRYPTED PASSWORD '${N8N_DB_PASSWORD}';
	GRANT ALL PRIVILEGES ON DATABASE n8n_db TO n8n_user;
	ALTER DATABASE n8n_db OWNER TO n8n_user;
EOSQL

# Enable pgvector extension in n8n_db
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "n8n_db" <<-EOSQL
	CREATE EXTENSION IF NOT EXISTS vector;
EOSQL

echo -e "${GREEN}[BorgStack]${NC} ✓ n8n_db created with pgvector extension"

# ===========================================================================
# Chatwoot Database Configuration
# ===========================================================================
echo -e "${BLUE}[BorgStack]${NC} Creating chatwoot_db and chatwoot_user..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	-- ============================================================================
	-- Chatwoot Database Configuration
	-- ============================================================================
	CREATE DATABASE chatwoot_db;
	CREATE USER chatwoot_user WITH ENCRYPTED PASSWORD '${CHATWOOT_DB_PASSWORD}';
	GRANT ALL PRIVILEGES ON DATABASE chatwoot_db TO chatwoot_user;
	ALTER DATABASE chatwoot_db OWNER TO chatwoot_user;
EOSQL

echo -e "${GREEN}[BorgStack]${NC} ✓ chatwoot_db created"

# ===========================================================================
# Directus Database Configuration
# ===========================================================================
echo -e "${BLUE}[BorgStack]${NC} Creating directus_db and directus_user..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	-- ============================================================================
	-- Directus Database Configuration
	-- ============================================================================
	CREATE DATABASE directus_db;
	CREATE USER directus_user WITH ENCRYPTED PASSWORD '${DIRECTUS_DB_PASSWORD}';
	GRANT ALL PRIVILEGES ON DATABASE directus_db TO directus_user;
	ALTER DATABASE directus_db OWNER TO directus_user;
EOSQL

# Enable pgvector extension in directus_db
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "directus_db" <<-EOSQL
	CREATE EXTENSION IF NOT EXISTS vector;
EOSQL

echo -e "${GREEN}[BorgStack]${NC} ✓ directus_db created with pgvector extension"

# ===========================================================================
# Evolution API Database Configuration
# ===========================================================================
echo -e "${BLUE}[BorgStack]${NC} Creating evolution_db and evolution_user..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	-- ============================================================================
	-- Evolution API Database Configuration
	-- ============================================================================
	CREATE DATABASE evolution_db;
	CREATE USER evolution_user WITH ENCRYPTED PASSWORD '${EVOLUTION_DB_PASSWORD}';
	GRANT ALL PRIVILEGES ON DATABASE evolution_db TO evolution_user;
	ALTER DATABASE evolution_db OWNER TO evolution_user;
EOSQL

echo -e "${GREEN}[BorgStack]${NC} ✓ evolution_db created"

# ===========================================================================
# Initialization Complete
# ===========================================================================
echo -e "${GREEN}[BorgStack]${NC} ============================================"
echo -e "${GREEN}[BorgStack]${NC} PostgreSQL initialization complete!"
echo -e "${GREEN}[BorgStack]${NC} ============================================"
echo -e "${GREEN}[BorgStack]${NC} ✓ 4 databases created"
echo -e "${GREEN}[BorgStack]${NC} ✓ 4 users created with encrypted passwords"
echo -e "${GREEN}[BorgStack]${NC} ✓ pgvector extension enabled in n8n_db and directus_db"
echo -e "${GREEN}[BorgStack]${NC} ============================================"
