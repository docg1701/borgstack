# Error Handling Strategy

BorgStack error handling focuses on **deployment failures, service unavailability, and integration breakdowns** since this is an infrastructure project rather than application development.

## Error Response Format

**Standardized Error Output:**

```bash
# Error message format used by all scripts

function error_exit() {
    local message="$1"
    local error_code="${2:-1}"
    local context="${3:-}"

    echo "❌ ERROR: ${message}" >&2

    if [ -n "$context" ]; then
        echo "   Context: ${context}" >&2
    fi

    echo "   For help, see: docs/05-troubleshooting.md" >&2
    echo "   Or run: docker compose logs --tail=50" >&2

    exit "$error_code"
}

# Usage example
if ! docker compose ps | grep -q "Up"; then
    error_exit "Services not running" 1 "Run 'docker compose up -d' to start services"
fi
```

**Structured Error Categories:**

| Error Code | Category | Example | Recovery Action |
|------------|----------|---------|-----------------|
| 1 | Configuration Error | Invalid docker-compose.yml, missing .env variables | Fix configuration, re-run deployment |
| 2 | Prerequisite Error | Insufficient RAM/CPU, Docker not installed | Upgrade server or install dependencies |
| 3 | Network Error | Cannot pull images, DNS resolution fails | Check internet connection, retry |
| 4 | Service Startup Error | Container exits immediately, health check fails | Check logs, verify environment variables |
| 5 | Integration Error | Service cannot connect to database, API calls fail | Verify network isolation, check credentials |
| 10 | Data Error | Database corruption, backup restoration fails | Restore from last known good backup |

---

## Service Resilience Patterns

**Circuit Breaker Pattern (n8n Workflows):**

n8n workflows should implement circuit breaker patterns to prevent cascading failures when integrated services become unavailable:

```javascript
// n8n HTTP Request node configuration
{
  "retryOnFail": true,
  "maxTries": 3,
  "waitBetweenTries": 1000,  // Start with 1s
  "backoffMultiplier": 2,     // Exponential: 1s, 2s, 4s
  "timeout": 30000,           // 30s timeout per request

  "circuitBreaker": {
    "enabled": true,
    "failureThreshold": 5,    // Open after 5 consecutive failures
    "resetTimeout": 60000,    // Wait 60s before retry
    "halfOpenRequests": 1     // Test with 1 request when half-open
  }
}
```

**Retry Strategy by Integration:**

| Integration | Max Retries | Backoff | Timeout | Fallback |
|-------------|-------------|---------|---------|----------|
| n8n → Evolution API | 3 | Exponential (1s, 2s, 4s) | 30s | Log to error_queue table |
| n8n → Chatwoot | 3 | Exponential (1s, 2s, 4s) | 30s | Log + email alert |
| Evolution → n8n | 3 | Exponential (2s, 4s, 8s) | 45s | Store in Evolution DB for replay |
| Chatwoot → n8n | 3 | Exponential (1s, 2s, 4s) | 30s | Chatwoot logs failure in app |
| Directus → SeaweedFS | 5 | Linear (2s each) | 60s | Fallback to local storage |

**Webhook Delivery Resilience:**

```bash
# Evolution API webhook delivery with retry
# If n8n webhook endpoint unavailable:
1. Evolution API attempts delivery
2. On failure (timeout, 5xx), retry after 2s
3. On second failure, retry after 4s
4. On third failure, retry after 8s
5. If all retries fail, store webhook payload in evolution_db.failed_webhooks table
6. Manual replay command: docker compose exec evolution node scripts/replay-webhooks.js
```

**Database Connection Retry:**

```yaml
# PostgreSQL connection retry (for all services)
services:
  n8n:
    environment:
      # TypeORM retry configuration
      DB_CONNECTION_RETRY_ATTEMPTS: 30
      DB_CONNECTION_RETRY_DELAY: 2000  # 2s between attempts = 60s total timeout

  chatwoot:
    environment:
      # Rails database.yml configuration
      POSTGRES_CONNECT_TIMEOUT: 60
      POSTGRES_RETRY_ATTEMPTS: 30
      POSTGRES_RETRY_DELAY: 2
```

**Service-to-Service Timeout Configuration:**

```bash
# Recommended timeout values for service communication

# HTTP Request timeouts
n8n HTTP nodes: 30s
Webhook delivery: 45s
API Gateway (Caddy): 60s

# Database query timeouts
PostgreSQL statement_timeout: 30s
MongoDB serverSelectionTimeoutMS: 30000
Redis command timeout: 10s

# Connection pool timeouts
PostgreSQL idle_in_transaction_session_timeout: 60s
Connection acquisition timeout: 30s
```

**Graceful Degradation Strategies:**

- **WhatsApp integration down**: n8n workflows queue messages in Redis sorted set for later processing
- **Chatwoot unavailable**: Evolution API stores messages in database; n8n replays when Chatwoot recovers
- **SeaweedFS unavailable**: Directus/FileFlows fallback to local temporary storage; sync when SeaweedFS recovers
- **Redis unavailable**: Services lose caching but continue operating (cache miss = database query)
- **Database connection pool exhausted**: Queue requests with 30s timeout; alert admin if sustained

---