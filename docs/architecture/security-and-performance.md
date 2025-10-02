# Security and Performance

## Security Requirements

**Frontend Security:**

- **CSP Headers:** Configured via Caddy for all services
  ```
  Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' wss:
  ```
  Note: `'unsafe-inline'` and `'unsafe-eval'` required by some services (n8n, Lowcoder) for their admin UIs

- **XSS Prevention:**
  - Caddy automatically adds `X-Content-Type-Options: nosniff` header
  - `X-Frame-Options: SAMEORIGIN` prevents clickjacking
  - Each service implements input sanitization internally
  - No custom frontend code to inject vulnerabilities

- **Secure Storage:**
  - Browser localStorage/sessionStorage managed by each service
  - Authentication tokens use httpOnly cookies where supported
  - SSL/TLS encrypts all traffic in transit

**Backend Security:**

- **Input Validation:**
  - Each service implements its own validation (Rails validators, Express middleware, etc.)
  - PostgreSQL prepared statements prevent SQL injection
  - MongoDB parameterized queries prevent NoSQL injection
  - API rate limiting configured per service

- **Rate Limiting:**
  - Rate limiting handled at application level by individual services:
    - n8n: Configurable via environment variables (N8N_EXECUTIONS_TIMEOUT, N8N_EXECUTIONS_PROCESS)
    - Chatwoot: Built-in rate limiting for API endpoints
    - Evolution API: Built-in rate limiting for WhatsApp API compliance
  - Note: Caddy 2.x does not include built-in rate limiting. If proxy-level rate limiting becomes required in the future, consider using a custom Caddy build with the `mholt/caddy-ratelimit` module via xcaddy

- **CORS Policy:**
  - Caddy CORS configuration for API endpoints:
    ```
    @cors_preflight {
        method OPTIONS
    }
    handle @cors_preflight {
        header Access-Control-Allow-Origin "*"
        header Access-Control-Allow-Methods "GET, POST, PUT, PATCH, DELETE"
        header Access-Control-Allow-Headers "Content-Type, Authorization"
        respond 204
    }
    ```
  - Production deployments should restrict origins to known domains
  - Each service has CORS configuration for its specific needs

**Authentication Security:**

- **Token Storage:**
  - JWTs stored in httpOnly cookies (Chatwoot, Directus)
  - Session tokens stored in Redis with expiration
  - API keys stored encrypted in PostgreSQL (n8n credentials)
  - No tokens in localStorage where avoidable

- **Session Management:**
  - Redis-backed sessions with configurable TTL (default 7 days)
  - Session invalidation on password change
  - Concurrent session limits per service configuration
  - Force logout on suspicious activity

- **Password Policy:**
  - Minimum 12 characters (enforced during bootstrap .env generation)
  - Must include uppercase, lowercase, numbers, special characters
  - Bcrypt hashing for stored passwords (Rails default)
  - Password rotation recommended every 90 days
  - No password reuse across services

**Network Security:**

- **Firewall Rules (UFW):**
  ```bash
  # Default deny incoming, allow outgoing
  sudo ufw default deny incoming
  sudo ufw default allow outgoing

  # Allow SSH (change port if using non-standard)
  sudo ufw allow 22/tcp

  # Allow HTTP/HTTPS for Caddy
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp

  # Enable firewall
  sudo ufw enable
  ```

- **Docker Network Isolation:**
  - `borgstack_internal` network: Service-to-service communication only (not exposed to host)
  - `borgstack_external` network: Only Caddy attached (public-facing)
  - Database ports (5432, 27017, 6379) never exposed to host in production
  - SeaweedFS S3 API accessible only via internal network

**Data Security:**

- **Encryption at Rest Strategy:**

  **Mandatory (MVP):**
  - ✅ **Duplicati backups**: AES-256 encryption before upload to external storage
    ```bash
    # Configured in Duplicati web UI
    Encryption: AES-256
    Passphrase: ${DUPLICATI_PASSPHRASE} from .env
    Encryption before upload: Yes
    ```
  - ✅ **.env file security**: 600 permissions, excluded from git
    ```bash
    chmod 600 .env
    # For production, consider: ansible-vault encrypt .env
    ```

  **Recommended (Production Hardening):**
  - 🔒 **PostgreSQL sensitive columns** using pgcrypto extension:
    ```sql
    -- Enable pgcrypto extension
    CREATE EXTENSION IF NOT EXISTS pgcrypto;

    -- n8n credentials encryption
    \c n8n_db
    ALTER TABLE credentials ADD COLUMN data_encrypted BYTEA;
    UPDATE credentials SET data_encrypted = pgp_sym_encrypt(data::text, '${N8N_ENCRYPTION_KEY}');

    -- Evolution API session tokens encryption
    \c evolution_db
    ALTER TABLE sessions ADD COLUMN token_encrypted BYTEA;
    UPDATE sessions SET token_encrypted = pgp_sym_encrypt(token, '${EVOLUTION_ENCRYPTION_KEY}');

    -- Query encrypted data
    SELECT pgp_sym_decrypt(data_encrypted, '${N8N_ENCRYPTION_KEY}')::text FROM credentials;
    ```
  - 🔒 **Full disk encryption (LUKS)** for production VPS:
    ```bash
    # During Ubuntu installation, enable LUKS encryption
    # Or for existing volumes:
    cryptsetup luksFormat /dev/vdb
    cryptsetup luksOpen /dev/vdb borgstack_encrypted
    mkfs.ext4 /dev/mapper/borgstack_encrypted
    ```
  - 🔒 **Redis persistence files** on encrypted volume:
    - Store `dump.rdb` and `appendonly.aof` on encrypted filesystem
    - Docker volume backed by LUKS-encrypted partition

  **Optional/Deferred:**
  - MongoDB encryption at rest requires **Enterprise edition** (out of scope for MVP)
  - SeaweedFS file encryption optional (files are primarily media/public assets)
  - Consider SeaweedFS encryption for sensitive documents in production

  **Key Management:**
  - **Development**: Encryption keys in .env file (600 permissions)
  - **Production**: Consider external secret management:
    ```bash
    # HashiCorp Vault integration
    export N8N_ENCRYPTION_KEY=$(vault kv get -field=key secret/borgstack/n8n)

    # AWS Secrets Manager (if using EC2)
    export N8N_ENCRYPTION_KEY=$(aws secretsmanager get-secret-value --secret-id borgstack/n8n --query SecretString --output text)

    # Docker Secrets (Docker Swarm)
    echo "encryption-key-value" | docker secret create n8n_encryption_key -
    ```
  - **Key rotation policy**: Rotate encryption keys every 90 days in production
  - **Key backup**: Store encryption keys separately from encrypted data

- **Encryption in Transit:**
  - All external traffic encrypted via HTTPS/TLS 1.3 (Caddy with Let's Encrypt)
  - Internal service communication unencrypted (Docker internal network assumed secure)
  - WhatsApp Business API uses end-to-end encryption (Meta managed)
  - Optional: Enable TLS for internal PostgreSQL connections in high-security environments

- **Secret Management Best Practices:**
  - Never commit .env files to git (.gitignore configured)
  - Use strong, unique passwords for each service (minimum 12 characters)
  - Rotate credentials regularly (recommended: every 90 days)
  - Store .env backup in encrypted external location (separate from data backups)
  - Use password manager (e.g., 1Password, Bitwarden) for admin credential storage

---

## Performance Optimization

**Backend Performance:**

- **Response Time Target:**
  - API endpoints: < 200ms (p95)
  - Database queries: < 50ms (p95)
  - Webhook delivery: < 500ms (p95)
  - File uploads: Limited by network bandwidth

- **Database Optimization:**
  - **PostgreSQL tuning** (for 36GB RAM server):
    ```conf
    # postgresql.conf
    shared_buffers = 8GB
    effective_cache_size = 24GB
    maintenance_work_mem = 2GB
    checkpoint_completion_target = 0.9
    wal_buffers = 16MB
    default_statistics_target = 100
    random_page_cost = 1.1  # SSD optimization
    effective_io_concurrency = 200
    work_mem = 20MB
    min_wal_size = 1GB
    max_wal_size = 4GB
    max_connections = 200
    max_parallel_workers_per_gather = 2
    max_parallel_workers = 8
    ```

- **Caching Strategy (Backend):**
  - **Redis caching layers:**
    - n8n: Workflow definitions cached (TTL 300s)
    - Chatwoot: Conversation metadata cached (TTL 600s)
    - Directus: Collection schemas cached (TTL 3600s)
    - Lowcoder: Application definitions cached (TTL 1800s)
  - **Application-level caching**: Managed by each service
  - **Cache invalidation**: Services handle via Redis pub/sub or TTL expiration
  - **Cache hit ratio target**: > 80% for frequently accessed data

---
