# Database Schema

BorgStack uses a **shared database infrastructure with logical isolation** strategy. Each service manages its own schema internally, but the architecture defines the database organization to prevent conflicts and enable independent updates.

## PostgreSQL Database Organization

**Server:** PostgreSQL 18.0 with pgvector extension
**Image:** `pgvector/pgvector:pg18`
**Host:** `postgresql:5432` on `borgstack_internal` network

**Database Isolation Strategy:**

```sql
-- Root superuser (for administration only)
-- Username: postgres
-- Password: ${POSTGRES_PASSWORD} from .env

-- Service-specific databases with dedicated users
CREATE DATABASE n8n_db;
CREATE USER n8n_user WITH ENCRYPTED PASSWORD '${N8N_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE n8n_db TO n8n_user;
ALTER DATABASE n8n_db OWNER TO n8n_user;

CREATE DATABASE chatwoot_db;
CREATE USER chatwoot_user WITH ENCRYPTED PASSWORD '${CHATWOOT_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE chatwoot_db TO chatwoot_user;
ALTER DATABASE chatwoot_db OWNER TO chatwoot_user;

CREATE DATABASE directus_db;
CREATE USER directus_user WITH ENCRYPTED PASSWORD '${DIRECTUS_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE directus_db TO directus_user;
ALTER DATABASE directus_db OWNER TO directus_user;

CREATE DATABASE evolution_db;
CREATE USER evolution_user WITH ENCRYPTED PASSWORD '${EVOLUTION_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE evolution_db TO evolution_user;
ALTER DATABASE evolution_db OWNER TO evolution_user;

-- Enable pgvector extension for each database requiring vector operations
\c n8n_db
CREATE EXTENSION IF NOT EXISTS vector;

\c directus_db
CREATE EXTENSION IF NOT EXISTS vector;
```

**Schema Ownership:**

Each service owns and manages its schema through migrations:

| Database | Service | Schema Management | Migration Tool |
|----------|---------|-------------------|----------------|
| `n8n_db` | n8n | Automatic on startup | TypeORM migrations |
| `chatwoot_db` | Chatwoot | Rails migrations | Rails ActiveRecord |
| `directus_db` | Directus | Automatic on startup | Knex.js migrations |
| `evolution_db` | Evolution API | Prisma migrations | Prisma ORM |

**Performance Configuration:**

```conf
# PostgreSQL 18 tuning for 36GB RAM server
shared_buffers = 8GB
effective_cache_size = 24GB
maintenance_work_mem = 2GB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 20MB
min_wal_size = 1GB
max_wal_size = 4GB
max_connections = 200
```

---

## MongoDB Database Organization

**Server:** MongoDB 7.0
**Image:** `mongo:7.0`
**Host:** `mongodb:27017` on `borgstack_internal` network

**Database Structure:**

```javascript
// Root admin user
// Username: admin
// Password: ${MONGODB_ROOT_PASSWORD} from .env

// Lowcoder dedicated database
use lowcoder;
db.createUser({
  user: "lowcoder_user",
  pwd: "${LOWCODER_DB_PASSWORD}",
  roles: [
    { role: "readWrite", db: "lowcoder" },
    { role: "dbAdmin", db: "lowcoder" }
  ]
});
```

**Schema Management:**

Lowcoder manages its MongoDB schema internally. Key collections include:

- `applications` - Low-code app definitions
- `queries` - Database queries and API configurations
- `users` - Lowcoder user accounts
- `organizations` - Multi-tenant organization data
- `datasources` - External data source connections

---

## Redis Data Organization

**Server:** Redis 8.2
**Image:** `redis:8.2-alpine`
**Host:** `redis:6379` on `borgstack_internal` network

**Key Namespace Strategy:**

Redis is shared across services using key prefixes to prevent collisions:

```
n8n:session:{sessionId}           # n8n user sessions
n8n:cache:{workflowId}            # n8n workflow caches
n8n:bull:{queueName}              # n8n job queues (Bull MQ)

chatwoot:sidekiq:{queue}          # Chatwoot background jobs
chatwoot:cache:{key}              # Chatwoot application cache
chatwoot:session:{userId}         # Chatwoot user sessions

directus:cache:{collection}       # Directus collection cache
directus:session:{token}          # Directus authentication tokens

lowcoder:session:{sessionId}      # Lowcoder user sessions
lowcoder:cache:{key}              # Lowcoder application cache
```

**Configuration:**

```conf
# redis.conf optimizations
maxmemory 4gb
maxmemory-policy allkeys-lru
appendonly yes
appendfsync everysec
save 900 1
save 300 10
save 60 10000
```

---

## SeaweedFS Storage Organization

**Server:** SeaweedFS 3.97
**Image:** `chrislusf/seaweedfs:3.97`
**Components:** Master (9333), Volume (8080), Filer (8888), S3 API (8333)

**Bucket Structure:**

```
/borgstack/
  ├── n8n/                    # n8n workflow attachments
  ├── chatwoot/               # Chatwoot conversation attachments
  │   ├── avatars/
  │   ├── messages/
  │   └── uploads/
  ├── directus/               # Directus CMS assets
  │   ├── originals/
  │   ├── thumbnails/
  │   └── documents/
  ├── fileflows/              # FileFlows processing
  │   ├── input/
  │   ├── output/
  │   └── temp/
  ├── lowcoder/               # Lowcoder app assets
  └── duplicati/              # Backup staging area
```

---