# Core Workflows

This section illustrates key system workflows using sequence diagrams to show component interactions and integration patterns.

## Workflow 1: WhatsApp to Chatwoot Customer Service Integration

This workflow demonstrates the core integration pattern connecting Evolution API, n8n, and Chatwoot for automated customer service.

```mermaid
sequenceDiagram
    participant Customer
    participant WhatsApp as WhatsApp<br/>(Meta)
    participant Evolution as Evolution API
    participant n8n as n8n Workflow
    participant Chatwoot
    participant PostgreSQL
    participant Redis

    Customer->>WhatsApp: Send message to business number
    WhatsApp->>Evolution: Deliver message via webhook
    Evolution->>PostgreSQL: Store message (evolution_db)
    Evolution->>n8n: POST /webhook/whatsapp-incoming

    Note over n8n: Workflow: WhatsApp → Chatwoot Sync

    n8n->>Chatwoot: GET /api/v1/accounts/{id}/contacts<br/>Search by phone number
    Chatwoot->>PostgreSQL: Query contacts (chatwoot_db)
    PostgreSQL-->>Chatwoot: Return contact or null
    Chatwoot-->>n8n: Contact data or 404

    alt Contact doesn't exist
        n8n->>Chatwoot: POST /api/v1/accounts/{id}/contacts<br/>Create new contact
        Chatwoot->>PostgreSQL: Insert contact (chatwoot_db)
        PostgreSQL-->>Chatwoot: Contact created
        Chatwoot-->>n8n: Contact ID
    end

    n8n->>Chatwoot: POST /api/v1/accounts/{id}/conversations<br/>Create or get conversation
    Chatwoot->>PostgreSQL: Insert/query conversation (chatwoot_db)
    PostgreSQL-->>Chatwoot: Conversation ID
    Chatwoot-->>n8n: Conversation details

    n8n->>Chatwoot: POST /api/v1/accounts/{id}/conversations/{id}/messages<br/>Add customer message
    Chatwoot->>PostgreSQL: Insert message (chatwoot_db)
    Chatwoot->>Redis: Queue notification job
    Chatwoot-->>n8n: Message created (200 OK)

    Redis-->>Chatwoot: Trigger Sidekiq worker
    Chatwoot->>Chatwoot: Notify assigned agent (WebSocket)

    Note over n8n,Chatwoot: Agent responds via Chatwoot UI

    Chatwoot->>n8n: POST /webhook/chatwoot-message-created<br/>(outgoing message webhook)

    Note over n8n: Workflow: Chatwoot → WhatsApp Reply

    n8n->>Evolution: POST /message/sendText<br/>{instance, phone, text}
    Evolution->>WhatsApp: Send message via WhatsApp API
    WhatsApp->>Customer: Deliver message
    Evolution-->>n8n: Message sent (200 OK)
```

**Key Integration Points:**
- **Webhook triggers**: Evolution API and Chatwoot both webhook to n8n to initiate workflows
- **Bi-directional sync**: n8n maintains contact/conversation state between platforms
- **Async communication**: Redis queues enable background processing in Chatwoot
- **Error handling**: n8n workflows should include error nodes for API failures (retry logic, alert notifications)

**Error Handling Scenarios:**

**Scenario 1: Chatwoot API Returns 500 Error**
- **Trigger**: Chatwoot database connection pool exhausted or internal server error
- **Detection**: n8n HTTP Request node receives 500 status code
- **Response**:
  1. Retry 3 times with exponential backoff (1s, 2s, 4s)
  2. If all retries fail: Log to PostgreSQL `n8n_db.error_queue` table with payload and timestamp
  3. Send alert email to `admin@${BORGSTACK_DOMAIN}` using n8n Send Email node
  4. Continue workflow execution (don't block other messages)
  5. Manual recovery: Admin reviews error_queue and replays failed messages
- **Prevention**: Monitor Chatwoot connection pool usage, scale PostgreSQL max_connections if needed

**Scenario 2: Contact Creation Race Condition**
- **Trigger**: Two simultaneous messages from same WhatsApp number arrive within 100ms
- **Detection**: Both n8n workflow instances attempt to create contact, second receives 422 Unprocessable Entity (duplicate phone number)
- **Response**:
  1. Catch 422 error in n8n workflow
  2. Re-query Chatwoot contacts API to fetch existing contact (GET /api/v1/accounts/{id}/contacts)
  3. Use retrieved contact ID to continue conversation creation
  4. Log race condition occurrence to n8n execution logs
- **Prevention**: Implement distributed lock in Redis before contact creation (SET NX with 5s TTL on key `contact:create:{phone}`)

**Scenario 3: Evolution API Webhook Delivery Failure**
- **Trigger**: n8n server temporarily unavailable (restart, deployment, OOM)
- **Detection**: Evolution API receives connection timeout or 503 from n8n webhook endpoint
- **Response**:
  1. Evolution API retries webhook delivery 5 times over 10 minutes (exponential backoff)
  2. If all retries fail: Message remains in Evolution API database but not synced to Chatwoot
  3. n8n scheduled workflow runs every 15 minutes: Query Evolution API `/message/list` endpoint for messages created in last 30 minutes
  4. Compare against Chatwoot conversation history to identify missing messages
  5. Sync missing messages to Chatwoot
- **Prevention**: Implement n8n high-availability (run 2 instances behind load balancer) or use message queue (RabbitMQ/Redis Streams)

**Scenario 4: WhatsApp Message Send Failure (Rate Limit)**
- **Trigger**: Too many messages sent to WhatsApp API, Meta returns 429 Too Many Requests
- **Detection**: Evolution API receives 429 from Meta Cloud API, returns error to n8n
- **Response**:
  1. n8n workflow catches 429 status code
  2. Wait for time specified in Retry-After header (typically 60s)
  3. Retry message send once after wait period
  4. If retry fails: Log to `n8n_db.failed_messages` table with `status='rate_limited'`
  5. Display warning in Chatwoot conversation: "Message delayed due to WhatsApp rate limits"
  6. n8n scheduled workflow retries rate-limited messages every 5 minutes
- **Prevention**: Implement rate limiting in n8n workflow (max 80 messages/hour per instance using Redis counter)

**Scenario 5: Redis Connection Loss**
- **Trigger**: Redis container restart, network partition, or memory eviction
- **Detection**: Chatwoot Sidekiq workers cannot connect to Redis, jobs fail with connection errors
- **Response**:
  1. Chatwoot logs error to `log/production.log`: "Redis::CannotConnectError"
  2. Sidekiq jobs remain in Redis queue (persist to disk if AOF enabled)
  3. When Redis recovers: Sidekiq workers automatically reconnect and process queued jobs
  4. For new messages during outage: n8n workflow calls Chatwoot API directly (synchronous), bypassing Redis queue
  5. Monitor Redis availability using `/health` endpoint, alert if down > 2 minutes
- **Prevention**: Configure Redis persistence (AOF with everysec fsync), set maxmemory-policy to allkeys-lru to prevent OOM

---

## Workflow 2: Initial Deployment and Bootstrap

This workflow shows the deployment process from clean Ubuntu server to running BorgStack installation.

```mermaid
sequenceDiagram
    participant User
    participant Ubuntu as Ubuntu 24.04 Server
    participant Bootstrap as bootstrap.sh
    participant Docker
    participant Compose as Docker Compose
    participant Services as All Services
    participant Caddy
    participant LetsEncrypt as Let's Encrypt

    User->>Ubuntu: SSH into clean server
    User->>Ubuntu: git clone borgstack repo to ~/borgstack
    User->>Bootstrap: ./scripts/bootstrap.sh

    Note over Bootstrap: System preparation phase

    Bootstrap->>Ubuntu: apt update && apt upgrade
    Bootstrap->>Ubuntu: Install prerequisites:<br/>curl, git, ca-certificates
    Bootstrap->>Ubuntu: Add Docker GPG key and repository
    Bootstrap->>Ubuntu: apt install docker-ce docker-compose-plugin
    Ubuntu-->>Bootstrap: Docker installed

    Bootstrap->>Docker: docker --version (verify)
    Bootstrap->>Compose: docker compose version (verify)
    Docker-->>Bootstrap: Version confirmed

    Bootstrap->>Ubuntu: usermod -aG docker $USER
    Bootstrap->>User: Prompt for environment variables<br/>(domains, passwords, credentials)
    User-->>Bootstrap: Provide configuration values
    Bootstrap->>Ubuntu: Generate .env file from .env.example
    Bootstrap->>Ubuntu: Set .env permissions to 600

    Note over Bootstrap: Validation phase

    Bootstrap->>Bootstrap: Validate required env vars set
    Bootstrap->>Bootstrap: Check DNS records for domains
    Bootstrap->>Bootstrap: Verify disk space (500GB)
    Bootstrap->>Bootstrap: Verify RAM (16GB minimum)

    Bootstrap->>User: Display configuration summary<br/>Request confirmation
    User-->>Bootstrap: Confirm (Y/n)

    Note over Bootstrap: Deployment phase (4-6 hours)

    Bootstrap->>Compose: docker compose pull
    Compose->>Docker: Pull all 12 service images
    Docker-->>Compose: Images downloaded (~15GB)

    Bootstrap->>Compose: docker compose up -d

    par Infrastructure Services
        Compose->>PostgreSQL: Start postgres + pgvector
        Compose->>MongoDB: Start mongodb
        Compose->>Redis: Start redis
        Compose->>SeaweedFS: Start seaweedfs (master, volume, filer)
    end

    Note over Services: Wait for databases ready (healthchecks)

    par Application Services
        Compose->>n8n: Start n8n (depends on postgres, redis)
        Compose->>Evolution: Start evolution-api (depends on postgres)
        Compose->>Chatwoot: Start chatwoot web + worker
        Compose->>Lowcoder: Start lowcoder (depends on mongodb)
        Compose->>Directus: Start directus (depends on postgres)
        Compose->>FileFlows: Start fileflows
        Compose->>Duplicati: Start duplicati
    end

    Compose->>Caddy: Start caddy reverse proxy

    Caddy->>LetsEncrypt: Request SSL certificates for domains
    LetsEncrypt->>Caddy: HTTP-01 challenge request
    Caddy->>LetsEncrypt: Respond with challenge token
    LetsEncrypt-->>Caddy: Issue certificates

    Compose-->>Bootstrap: All services started

    Bootstrap->>Compose: docker compose ps (verify)
    Bootstrap->>Compose: docker compose logs --tail=50

    loop Health check validation
        Bootstrap->>Services: curl https://{service-domain}/health
        Services-->>Bootstrap: 200 OK or retry
    end

    Bootstrap-->>User: ✅ Deployment complete!<br/>Display service URLs and next steps

    User->>Caddy: Navigate to n8n URL
    Caddy-->>User: Redirect to n8n setup wizard
    User->>n8n: Create admin account
```

**Deployment Timing Breakdown:**
- **System prep**: 5-10 minutes (apt updates, Docker install)
- **Image pull**: 30-60 minutes (depends on network speed)
- **Service startup**: 10-20 minutes (database initialization, healthchecks)
- **SSL certificate generation**: 2-5 minutes per domain
- **Initial configuration**: 2-3 hours (user setup of each service)
- **Total**: 4-6 hours per NFR1 requirement

---

## Workflow 3: Automated Backup Process

This workflow demonstrates Duplicati's automated backup protecting all persistent data.

```mermaid
sequenceDiagram
    participant Scheduler as Duplicati Scheduler
    participant Duplicati
    participant Docker as Docker Volumes
    participant PostgreSQL
    participant MongoDB
    participant SeaweedFS
    participant External as External Storage<br/>(S3/B2/FTP)

    Note over Scheduler: Scheduled trigger (e.g., daily 2 AM)

    Scheduler->>Duplicati: Trigger backup job "BorgStack Full Backup"

    Note over Duplicati: Pre-backup phase

    Duplicati->>Duplicati: Check last backup timestamp
    Duplicati->>Duplicati: Calculate incremental changes

    par Database Dumps
        Duplicati->>PostgreSQL: pg_dump n8n_db
        PostgreSQL-->>Duplicati: n8n_db.sql
        Duplicati->>PostgreSQL: pg_dump chatwoot_db
        PostgreSQL-->>Duplicati: chatwoot_db.sql
        Duplicati->>PostgreSQL: pg_dump directus_db
        PostgreSQL-->>Duplicati: directus_db.sql
        Duplicati->>PostgreSQL: pg_dump evolution_db
        PostgreSQL-->>Duplicati: evolution_db.sql

        Duplicati->>MongoDB: mongodump --db lowcoder
        MongoDB-->>Duplicati: lowcoder.bson
    end

    par Volume Snapshots
        Duplicati->>Docker: Read /var/lib/docker/volumes/postgresql_data
        Docker-->>Duplicati: PostgreSQL data files

        Duplicati->>Docker: Read /var/lib/docker/volumes/redis_data
        Docker-->>Duplicati: Redis AOF/RDB files

        Duplicati->>Docker: Read /var/lib/docker/volumes/seaweedfs_*
        Docker-->>Duplicati: SeaweedFS object data

        Duplicati->>Docker: Read /var/lib/docker/volumes/n8n_data
        Docker-->>Duplicati: n8n credentials/workflows

        Duplicati->>Docker: Read /var/lib/docker/volumes/evolution_instances
        Docker-->>Duplicati: WhatsApp session data

        Duplicati->>Docker: Read /var/lib/docker/volumes/caddy_data
        Docker-->>Duplicati: SSL certificates
    end

    Note over Duplicati: Compression & encryption phase

    Duplicati->>Duplicati: Compress backup data (zstd)
    Duplicati->>Duplicati: Encrypt with AES-256<br/>(passphrase from config)
    Duplicati->>Duplicati: Create backup metadata<br/>(timestamp, file list, checksums)

    Note over Duplicati: Upload phase

    Duplicati->>External: Upload encrypted backup chunks
    External-->>Duplicati: Confirm upload (200 OK)

    Duplicati->>External: Upload backup manifest
    External-->>Duplicati: Confirm manifest

    Note over Duplicati: Post-backup phase

    Duplicati->>Duplicati: Verify backup integrity<br/>(compare checksums)
    Duplicati->>Duplicati: Update backup history
    Duplicati->>Duplicati: Prune old backups per retention policy<br/>(e.g., keep 7 daily, 4 weekly, 12 monthly)

    alt Backup successful
        Duplicati->>Duplicati: Log success
        Duplicati->>User: Optional notification (email/webhook)
    else Backup failed
        Duplicati->>Duplicati: Log error details
        Duplicati->>User: Send alert notification
        Duplicati->>Duplicati: Schedule retry in 1 hour
    end
```

**Backup Strategy Details:**
- **Incremental backups**: Only changed data backed up after initial full backup
- **Encryption at rest**: AES-256 encryption ensures data sovereignty even on third-party storage
- **Retention policy**: Configurable (default: 7 daily, 4 weekly, 12 monthly, 5 yearly)
- **Backup size estimation**: ~50GB for full backup (depends on data volume)
- **Network transfer time**: 30-120 minutes depending on bandwidth

---

## Workflow 4: Media File Processing Pipeline

This workflow shows FileFlows processing media files with SeaweedFS storage integration.

```mermaid
sequenceDiagram
    participant User
    participant Directus
    participant SeaweedFS
    participant FileFlows
    participant n8n

    User->>Directus: Upload video file via CMS
    Directus->>SeaweedFS: PUT /raw-uploads/{filename}<br/>(S3 API)
    SeaweedFS->>SeaweedFS: Store file in volume
    SeaweedFS-->>Directus: File URL + metadata
    Directus->>PostgreSQL: Save asset record (directus_db)
    Directus-->>User: Upload complete (201 Created)

    alt Automatic processing trigger
        Directus->>n8n: POST /webhook/directus-upload<br/>(file metadata)
        n8n->>FileFlows: POST /api/flow/trigger<br/>{filename, source_path}
    else Manual processing
        User->>FileFlows: Trigger flow manually via UI
    end

    Note over FileFlows: Processing workflow execution

    FileFlows->>SeaweedFS: GET /raw-uploads/{filename}<br/>Download source file
    SeaweedFS-->>FileFlows: Stream file to /temp

    FileFlows->>FileFlows: Detect file format (FFprobe)
    FileFlows->>FileFlows: Apply flow rules:<br/>- Video: Transcode to H.264<br/>- Audio: Normalize + MP3<br/>- Image: Resize + WebP

    Note over FileFlows: Example: Video transcoding

    FileFlows->>FileFlows: FFmpeg transcode:<br/>-c:v libx264 -crf 23<br/>-preset medium -c:a aac

    alt Processing successful
        FileFlows->>SeaweedFS: PUT /processed/{filename}.mp4<br/>Upload processed file
        SeaweedFS-->>FileFlows: File stored (200 OK)

        FileFlows->>n8n: POST /webhook/fileflows-complete<br/>{original, processed, metadata}

        n8n->>Directus: PATCH /items/assets/{id}<br/>Update with processed URL
        Directus->>PostgreSQL: Update asset record
        Directus-->>n8n: Updated (200 OK)

        n8n->>SeaweedFS: DELETE /raw-uploads/{filename}<br/>Clean up original (optional)

        FileFlows->>FileFlows: Log success + statistics
    else Processing failed
        FileFlows->>FileFlows: Log error details
        FileFlows->>n8n: POST /webhook/fileflows-error<br/>{filename, error}
        n8n->>User: Send alert notification
    end
```

**Processing Capabilities:**
- **Video transcoding**: H.264/H.265 encoding, resolution scaling, bitrate optimization
- **Audio processing**: Normalization, format conversion, silence removal
- **Image optimization**: WebP conversion, resizing, compression
- **Batch processing**: Queue multiple files with priority scheduling

---
