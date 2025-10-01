-- ============================================================================
-- BorgStack - PostgreSQL Database Initialization Script
-- ============================================================================
--
-- Purpose: Initialize separate databases for each service with dedicated users
-- Executed once on first container startup via /docker-entrypoint-initdb.d/
--
-- Database Organization:
--   - n8n_db       → n8n workflow automation
--   - chatwoot_db  → Chatwoot customer service
--   - directus_db  → Directus headless CMS
--   - evolution_db → Evolution API WhatsApp gateway
--
-- Security Model:
--   - Each service has a dedicated database and user (principle of least privilege)
--   - Each user can only access their own database
--   - Schema isolation prevents naming conflicts between services
--   - Services connect using their dedicated user, NOT the postgres superuser
--
-- Schema Ownership:
--   - BorgStack ONLY creates databases and users
--   - Each service manages its own schema via automatic migrations:
--       • n8n: TypeORM migrations (automatic on startup)
--       • Chatwoot: Rails ActiveRecord migrations (on startup)
--       • Directus: Knex.js migrations (automatic on startup)
--       • Evolution API: Prisma ORM migrations (on startup)
--
-- pgvector Extension:
--   - Enabled for n8n_db and directus_db (RAG/LLM vector search support)
--   - Required for AI/LLM features in workflows and content management
-- ============================================================================

-- ============================================================================
-- n8n Database Configuration
-- ============================================================================
-- Service: n8n workflow automation platform
-- Migration Tool: TypeORM (automatic on container startup)
-- pgvector: Enabled for AI/LLM workflow nodes and vector search operations

CREATE DATABASE n8n_db;
CREATE USER n8n_user WITH ENCRYPTED PASSWORD '${N8N_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE n8n_db TO n8n_user;
ALTER DATABASE n8n_db OWNER TO n8n_user;

-- Enable pgvector extension for vector similarity search (AI/LLM features)
\c n8n_db
CREATE EXTENSION IF NOT EXISTS vector;

-- Connection string for n8n service:
-- postgres://n8n_user:${N8N_DB_PASSWORD}@postgresql:5432/n8n_db

-- ============================================================================
-- Chatwoot Database Configuration
-- ============================================================================
-- Service: Chatwoot customer communication platform
-- Migration Tool: Rails ActiveRecord (migrations run on startup)
-- pgvector: Not required for Chatwoot

\c postgres
CREATE DATABASE chatwoot_db;
CREATE USER chatwoot_user WITH ENCRYPTED PASSWORD '${CHATWOOT_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE chatwoot_db TO chatwoot_user;
ALTER DATABASE chatwoot_db OWNER TO chatwoot_user;

-- Connection string for Chatwoot service:
-- postgres://chatwoot_user:${CHATWOOT_DB_PASSWORD}@postgresql:5432/chatwoot_db

-- ============================================================================
-- Directus Database Configuration
-- ============================================================================
-- Service: Directus headless CMS and data management
-- Migration Tool: Knex.js (automatic migrations on startup)
-- pgvector: Enabled for AI/LLM content features and vector search

\c postgres
CREATE DATABASE directus_db;
CREATE USER directus_user WITH ENCRYPTED PASSWORD '${DIRECTUS_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE directus_db TO directus_user;
ALTER DATABASE directus_db OWNER TO directus_user;

-- Enable pgvector extension for vector similarity search (AI/LLM features)
\c directus_db
CREATE EXTENSION IF NOT EXISTS vector;

-- Connection string for Directus service:
-- postgres://directus_user:${DIRECTUS_DB_PASSWORD}@postgresql:5432/directus_db

-- ============================================================================
-- Evolution API Database Configuration
-- ============================================================================
-- Service: Evolution API WhatsApp Business gateway
-- Migration Tool: Prisma ORM (migrations run on startup)
-- pgvector: Not required for Evolution API

\c postgres
CREATE DATABASE evolution_db;
CREATE USER evolution_user WITH ENCRYPTED PASSWORD '${EVOLUTION_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE evolution_db TO evolution_user;
ALTER DATABASE evolution_db OWNER TO evolution_user;

-- Connection string for Evolution API service:
-- postgres://evolution_user:${EVOLUTION_DB_PASSWORD}@postgresql:5432/evolution_db

-- ============================================================================
-- Initialization Complete
-- ============================================================================
--
-- Summary:
--   ✅ 4 databases created: n8n_db, chatwoot_db, directus_db, evolution_db
--   ✅ 4 users created with encrypted passwords from environment variables
--   ✅ Database ownership assigned to respective users
--   ✅ pgvector extension installed in n8n_db and directus_db
--
-- Next Steps:
--   1. Services will connect using their dedicated user credentials
--   2. Each service will automatically create/migrate its own schema on first startup
--   3. No manual table creation required - services handle their own schema
-- ============================================================================
