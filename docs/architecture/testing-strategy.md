# Testing Strategy

BorgStack testing focuses on **deployment validation and integration verification** rather than unit testing, since all services are pre-built Docker images.

## Testing Pyramid

```
                   E2E/Integration Tests
                   /                    \
          Deployment Validation    Service Integration
          /                                          \
   Configuration Tests                        API Connectivity Tests
```

**Testing Philosophy:**
- **No unit tests**: Services are pre-built; upstream projects maintain their own unit tests
- **Focus on integration**: Verify services communicate correctly
- **Deployment validation**: Ensure clean deployment succeeds
- **Configuration verification**: Validate docker-compose.yml and .env correctness

---

## Performance Testing

Performance testing validates that BorgStack meets NFR1 performance requirements and establishes baselines for capacity planning.

**Testing Tools:**

| Tool | Purpose | Installation |
|------|---------|--------------|
| **wrk** | HTTP load testing for API endpoints | `sudo apt install wrk` |
| **ab (Apache Bench)** | Simple HTTP throughput testing | `sudo apt install apache2-utils` |
| **pgbench** | PostgreSQL performance benchmarking | Included with PostgreSQL |
| **redis-benchmark** | Redis performance testing | Included with Redis |
| **iostat** | Disk I/O performance monitoring | `sudo apt install sysstat` |

**Performance Test Scenarios:**

```bash
#!/bin/bash
# performance-tests.sh - Run performance test suite

echo "=========================================="
echo "BorgStack Performance Test Suite"
echo "=========================================="

# Test 1: n8n webhook throughput
echo ""
echo "Test 1: n8n Webhook Throughput"
wrk -t4 -c100 -d60s https://n8n.example.com.br/webhook/test \
  --latency
# Target: 100 req/s sustained, p95 < 200ms

# Test 2: Chatwoot API response time
echo ""
echo "Test 2: Chatwoot API Response Time"
wrk -t4 -c50 -d30s https://chatwoot.example.com.br/api/v1/accounts \
  -H "api_access_token: ${CHATWOOT_API_TOKEN}" \
  --latency
# Target: p95 < 150ms, p99 < 300ms

# Test 3: PostgreSQL connection pool saturation
echo ""
echo "Test 3: PostgreSQL Connection Pool"
docker compose exec -T postgresql pgbench \
  -c 50 -j 2 -T 300 -U postgres n8n_db
# Target: < 150 concurrent connections, no "too many clients" errors

# Test 4: Redis cache performance
echo ""
echo "Test 4: Redis Operations Throughput"
docker compose exec -T redis redis-benchmark \
  -h localhost -p 6379 -a ${REDIS_PASSWORD} \
  -t get,set -n 100000 -q
# Target: > 10,000 ops/sec

# Test 5: SeaweedFS file upload performance
echo ""
echo "Test 5: SeaweedFS Upload Performance"
for i in {1..100}; do
  time curl -s -F "file=@test-10mb.mp4" \
    -H "Authorization: AWS4-HMAC-SHA256 ..." \
    http://localhost:8333/borgstack/test/ > /dev/null
done | grep real | awk '{print $2}' | sort -n | tail -5
# Target: Consistent upload time < 2s per 10MB file

# Test 6: Database query performance
echo ""
echo "Test 6: PostgreSQL Query Performance"
docker compose exec -T postgresql psql -U postgres -c "
SELECT
  schemaname,
  tablename,
  seq_scan,
  idx_scan,
  ROUND((seq_tup_read / NULLIF(seq_scan, 0))::numeric, 2) as avg_seq_read,
  ROUND((idx_tup_fetch / NULLIF(idx_scan, 0))::numeric, 2) as avg_idx_fetch
FROM pg_stat_user_tables
WHERE seq_scan > 0 OR idx_scan > 0
ORDER BY seq_tup_read DESC
LIMIT 10;
"
# Target: Index scans > Sequential scans for large tables

# Test 7: Disk I/O baseline
echo ""
echo "Test 7: Disk I/O Performance"
sudo iostat -x 5 3
# Target: > 100 MB/s sequential read/write on SSD

# Test 8: API Gateway (Caddy) throughput
echo ""
echo "Test 8: Caddy Reverse Proxy Throughput"
wrk -t8 -c200 -d30s https://directus.example.com.br/server/health \
  --latency
# Target: > 1000 req/s, p95 < 50ms

echo ""
echo "=========================================="
echo "Performance Tests Complete"
echo "=========================================="
```

**Performance Baselines (36GB RAM, 8 vCPU Server):**

| Metric | Target (p95) | Acceptable (p99) | Critical Threshold |
|--------|--------------|------------------|--------------------|
| **API Response Time** | < 200ms | < 500ms | > 1000ms |
| **Webhook Throughput** | 100 req/s | 50 req/s | < 25 req/s |
| **Database Connections** | < 150 concurrent | < 180 concurrent | > 200 (pool exhausted) |
| **Redis Operations** | > 10,000 ops/s | > 5,000 ops/s | < 1,000 ops/s |
| **Disk I/O (SSD)** | > 100 MB/s | > 50 MB/s | < 20 MB/s |
| **Memory Usage** | < 75% | < 85% | > 90% (swap risk) |
| **CPU Usage** | < 70% avg | < 85% avg | > 95% sustained |

**Load Testing Schedule:**

- **Pre-production**: Full suite on staging server before production deployment
- **Post-deployment**: Establish baseline within first week
- **Weekly**: Automated performance monitoring (cron job)
- **Before updates**: Regression testing to detect performance degradation
- **Quarterly**: Full load test to validate scaling strategy

**Performance Monitoring Script:**

```bash
#!/bin/bash
# weekly-performance-check.sh - Automated performance monitoring

BASELINE_FILE="performance-baseline.txt"
CURRENT_FILE="/tmp/performance-current.txt"
ALERT_EMAIL="admin@${BORGSTACK_DOMAIN}"

# Run quick performance checks
docker stats --no-stream > "$CURRENT_FILE"

# Compare against baseline
if [ -f "$BASELINE_FILE" ]; then
  # Alert if CPU usage increased > 20%
  # Alert if memory usage increased > 15%
  # Alert if any container using > 90% memory

  DEGRADATION=$(compare-performance.sh "$BASELINE_FILE" "$CURRENT_FILE")

  if [ $? -ne 0 ]; then
    echo "Performance degradation detected" | \
      mail -s "BorgStack Performance Alert" "$ALERT_EMAIL"
  fi
fi

# Update baseline monthly
if [ $(date +%d) -eq 01 ]; then
  cp "$CURRENT_FILE" "$BASELINE_FILE"
  echo "Performance baseline updated for $(date +%Y-%m)"
fi
```

**Performance Troubleshooting Guide:**

**Issue: High API response times (> 500ms p95)**
- Check: `docker stats` for CPU/memory bottlenecks
- Check: `docker compose logs n8n --tail=100 | grep -i slow`
- Action: Scale up server resources or enable caching

**Issue: Database connection pool exhausted**
- Check: `SELECT count(*) FROM pg_stat_activity;`
- Action: Increase `max_connections` in postgresql.conf
- Action: Review connection leaks in application code

**Issue: Redis memory usage > 80%**
- Check: `docker compose exec redis redis-cli INFO memory`
- Action: Review `maxmemory` setting and eviction policy
- Action: Analyze cache hit ratio and optimize TTL values

**Issue: Disk I/O bottleneck (iowait > 30%)**
- Check: `iostat -x 5` for disk utilization %
- Action: Upgrade to faster SSD
- Action: Enable PostgreSQL connection pooling (pgbouncer)
- Action: Move SeaweedFS volume to dedicated disk

---