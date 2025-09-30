# Monitoring and Observability

BorgStack monitoring focuses on **operational visibility using built-in tools** rather than complex monitoring infrastructure, appropriate for single-server deployments.

## Monitoring Stack

- **Frontend Monitoring:** Not applicable (pre-built service UIs; each service monitors itself)
- **Backend Monitoring:** Docker stats + container logs
- **Error Tracking:** Docker logs with grep/filtering
- **Performance Monitoring:** `docker stats`, `iostat`, `free`, `df`

**Rationale:** Built-in Linux and Docker tools adequate for single-server deployment; no additional infrastructure needed per NFR14 requirement for simplicity.

**Post-MVP Upgrade Path:**
- Add Prometheus + Grafana for metrics visualization
- Add Loki for log aggregation
- Add Uptime Kuma for uptime monitoring
- Add Netdata for real-time system monitoring

---

## Key Metrics

**System Resources:**
```bash
# CPU usage per container
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}"

# Memory usage per container
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}"

# Disk usage
df -h /
docker system df  # Docker-specific disk usage

# Disk I/O
iostat -x 5 3
```

**Service Health:**
```bash
# Container health status
docker compose ps

# Service uptime
docker ps --format "table {{.Names}}\t{{.Status}}"

# Failed health checks
docker ps --filter "health=unhealthy"
```

**Database Performance:**
```bash
# PostgreSQL active connections
docker compose exec postgresql psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# PostgreSQL slow queries (requires pg_stat_statements)
docker compose exec postgresql psql -U postgres -c "
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;"

# MongoDB stats
docker compose exec mongodb mongosh --quiet --eval "db.serverStatus()"

# Redis info
docker compose exec redis redis-cli -a $REDIS_PASSWORD INFO stats
```

---