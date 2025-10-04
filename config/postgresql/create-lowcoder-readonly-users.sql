-- Lowcoder Read-Only Database User Creation Script
-- Purpose: Create a read-only PostgreSQL user for Lowcoder applications
-- Security: Follows principle of least privilege - SELECT only, no write permissions
-- Execution: Run manually via psql or add to init-databases.sql for automated setup

-- Create read-only user for Lowcoder applications (idempotent)
-- Password is provided via environment variable LOWCODER_READONLY_DB_PASSWORD
-- Drop existing user if present to allow safe re-execution
DROP USER IF EXISTS lowcoder_readonly_user;
CREATE USER lowcoder_readonly_user WITH ENCRYPTED PASSWORD :'LOWCODER_READONLY_DB_PASSWORD';

-- Grant connection permissions to all BorgStack service databases
GRANT CONNECT ON DATABASE n8n_db TO lowcoder_readonly_user;
GRANT CONNECT ON DATABASE chatwoot_db TO lowcoder_readonly_user;
GRANT CONNECT ON DATABASE directus_db TO lowcoder_readonly_user;
GRANT CONNECT ON DATABASE evolution_db TO lowcoder_readonly_user;

-- Configure read-only access for n8n_db
\c n8n_db
GRANT USAGE ON SCHEMA public TO lowcoder_readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO lowcoder_readonly_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO lowcoder_readonly_user;

-- Configure read-only access for chatwoot_db
\c chatwoot_db
GRANT USAGE ON SCHEMA public TO lowcoder_readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO lowcoder_readonly_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO lowcoder_readonly_user;

-- Configure read-only access for directus_db
\c directus_db
GRANT USAGE ON SCHEMA public TO lowcoder_readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO lowcoder_readonly_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO lowcoder_readonly_user;

-- Configure read-only access for evolution_db
\c evolution_db
GRANT USAGE ON SCHEMA public TO lowcoder_readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO lowcoder_readonly_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO lowcoder_readonly_user;

-- Verification queries (uncomment to test)
-- \c n8n_db
-- SELECT grantee, privilege_type FROM information_schema.role_table_grants WHERE grantee = 'lowcoder_readonly_user';
