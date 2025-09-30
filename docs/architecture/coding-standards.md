# Coding Standards

BorgStack coding standards focus on **configuration management, shell scripting, and documentation** since this is an infrastructure deployment project, not custom application development.

## Critical Infrastructure Rules

- **Docker Compose Version Pinning:** Always specify exact image versions in docker-compose.yml. Never use `latest` tag.
  ```yaml
  # ✅ Correct
  image: n8nio/n8n:1.112.6

  # ❌ Wrong
  image: n8nio/n8n:latest
  ```
  _Rationale: Ensures reproducible deployments; prevents unexpected breaking changes_

- **Environment Variable Security:** Never commit `.env` files or secrets to git. Always use `.env.example` as template.
  ```bash
  # ✅ Correct - .gitignore includes
  .env
  .env.local
  .env.*.local

  # ❌ Wrong - committing secrets
  git add .env
  ```
  _Rationale: Prevents credential exposure; maintains security posture_

- **Volume Naming Convention:** Prefix all Docker volumes with `borgstack_` for easy identification.
  ```yaml
  # ✅ Correct
  volumes:
    borgstack_postgresql_data:
    borgstack_mongodb_data:

  # ❌ Wrong
  volumes:
    postgres_data:
    mongo_data:
  ```
  _Rationale: Prevents conflicts with other Docker stacks on same host_

- **Network Isolation:** Use `borgstack_internal` for service-to-service communication; never expose database ports to host in production.
  ```yaml
  # ✅ Correct - no ports exposed
  postgresql:
    networks:
      - borgstack_internal

  # ❌ Wrong - database exposed to host
  postgresql:
    ports:
      - "5432:5432"
    networks:
      - borgstack_internal
  ```
  _Rationale: Defense in depth; limits attack surface_

- **Configuration as Code:** Store all configuration files (Caddyfile, postgresql.conf, redis.conf) in version control, not in volumes.
  ```yaml
  # ✅ Correct - config file in repo
  caddy:
    volumes:
      - ./config/caddy/Caddyfile:/etc/caddy/Caddyfile:ro

  # ❌ Wrong - config in named volume (hard to track changes)
  caddy:
    volumes:
      - caddy_config:/etc/caddy
  ```
  _Rationale: Enables change tracking, code review, and rollback_

- **Health Check Requirements:** All long-running services must define health checks in docker-compose.yml.
  ```yaml
  # ✅ Correct
  postgresql:
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ❌ Wrong - no health check
  postgresql:
    image: pgvector/pgvector:pg18
  ```
  _Rationale: Enables proper startup ordering; detects service failures_

- **Dependency Management:** Use `depends_on` with `condition: service_healthy` for proper startup sequencing.
  ```yaml
  # ✅ Correct
  n8n:
    depends_on:
      postgresql:
        condition: service_healthy
      redis:
        condition: service_healthy

  # ❌ Wrong - no dependency management
  n8n:
    image: n8nio/n8n:1.112.6
  ```
  _Rationale: Prevents startup failures due to unavailable dependencies_

- **Backup Before Updates:** Always run backup script before pulling new images or changing configurations.
  ```bash
  # ✅ Correct workflow
  ./scripts/backup-now.sh
  docker compose pull
  docker compose up -d

  # ❌ Wrong - update without backup
  docker compose pull && docker compose up -d
  ```
  _Rationale: Enables rollback if update fails; protects against data loss_

---

## Naming Conventions

| Element | Convention | Example | Rationale |
|---------|-----------|---------|-----------|
| **Docker Services** | lowercase, descriptive | `postgresql`, `n8n`, `chatwoot` | Matches official image names; easy to type |
| **Docker Volumes** | `borgstack_<service>_<purpose>` | `borgstack_postgresql_data`, `borgstack_n8n_data` | Namespace isolation; prevents conflicts |
| **Docker Networks** | `borgstack_<purpose>` | `borgstack_internal`, `borgstack_external` | Namespace isolation; clear purpose |
| **Environment Variables** | SCREAMING_SNAKE_CASE | `POSTGRES_PASSWORD`, `N8N_DB_PASSWORD` | Standard env var convention |
| **Shell Scripts** | kebab-case.sh | `bootstrap.sh`, `backup-now.sh`, `update-service.sh` | Readable; standard Linux convention |
| **Config Files** | Original service naming | `Caddyfile`, `postgresql.conf`, `redis.conf` | Matches upstream documentation |
| **Documentation** | Numbered, kebab-case.md | `01-installation.md`, `02-configuration.md` | Sequential reading order; language-specific |
| **Git Branches** | `feature/<name>`, `fix/<name>` | `feature/add-monitoring`, `fix/caddy-ssl` | Standard Git flow conventions |
| **Git Commits** | Imperative mood, lowercase | `add health checks to all services` | Consistent with Linux kernel style |

---
