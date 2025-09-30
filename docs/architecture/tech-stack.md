# Tech Stack

This section defines the **DEFINITIVE technology selection** for BorgStack. All deployment and integration work must use these exact versions. This is an infrastructure project deploying pre-built Docker images, not a custom application development project.

## Technology Stack Table

| Category | Technology | Version | Purpose | Rationale |
|----------|-----------|---------|---------|-----------|
| **Core Infrastructure** |
| Orchestration | Docker Compose | v2 (latest) | Container orchestration and service management | Industry standard for multi-container applications; simpler than Kubernetes for single-server deployments |
| Operating System | Ubuntu Server LTS | 24.04 | Host operating system | Long-term support until 2029; excellent Docker compatibility; widespread documentation |
| Reverse Proxy | Caddy | 2.10-alpine | HTTPS termination and routing | Zero-configuration automatic SSL/TLS; simpler than nginx for this use case |
| **Databases & Caching** |
| Relational Database | PostgreSQL + pgvector | 18.0 (pgvector/pgvector:pg18) | Primary database for n8n, Chatwoot, Directus, Evolution API | Latest PostgreSQL with vector search for RAG/LLM integrations; shared to reduce infrastructure complexity |
| NoSQL Database | MongoDB | 7.0 (mongo:7.0) | Dedicated database for Lowcoder metadata | Required by Lowcoder; isolated to prevent schema conflicts with SQL services |
| Cache/Queue | Redis | 8.2-alpine | Session management, caching, message queuing | Shared across all services; Alpine image for minimal footprint |
| Object Storage | SeaweedFS | 3.97 (chrislusf/seaweedfs:3.97) | S3-compatible distributed file storage | Self-hosted alternative to AWS S3; needed for media processing and CMS assets |
| **Application Services** |
| Workflow Automation | n8n | 1.112.6 (n8nio/n8n:1.112.6) | Workflow orchestration hub | Central integration platform; connects all services via HTTP/webhook patterns |
| WhatsApp Integration | Evolution API | v2.2.3 (atendai/evolution-api:v2.2.3) | Multi-instance WhatsApp Business API | Enables WhatsApp workflows; supports multiple business accounts |
| Customer Service | Chatwoot | v4.6.0-ce (chatwoot/chatwoot:v4.6.0-ce) | Omnichannel customer communication | Open source alternative to Intercom/Zendesk; integrates with Evolution API for WhatsApp |
| Application Builder | Lowcoder | 2.7.4 (lowcoderorg/lowcoder-ce:2.7.4) | Low-code internal tools platform | Optional custom app development; connects to PostgreSQL and Redis |
| Headless CMS | Directus | 11 (directus/directus:11) | Data management and content delivery | Flexible CMS with REST/GraphQL APIs; uses PostgreSQL and SeaweedFS |
| Media Processing | FileFlows | 25.09 (revenz/fileflows:25.09) | Automated media conversion workflows | File processing automation; integrates with SeaweedFS |
| Backup System | Duplicati | 2.1.1.102 (duplicati/duplicati:2.1.1.102) | Encrypted backup automation | Protects workflows and configurations; supports external storage destinations |
| **Development & Operations** |
| Container Runtime | Docker Engine | Latest stable | Container execution environment | Required by Docker Compose; installed by bootstrap script |
| Version Control | Git | Latest stable | Configuration management | Tracks docker-compose.yml and configuration changes |
| Scripting | Bash | 5.x (Ubuntu default) | Bootstrap and automation scripts | Native to Ubuntu; used for setup automation |
| **Monitoring & Logging** |
| Log Aggregation | Docker Logs | Native (docker compose logs) | Centralized log access | Built-in; no additional infrastructure needed per NFR14 |
| Health Checks | Docker Healthcheck | Native | Container availability monitoring | Built-in Docker Compose feature |
| **Security** |
| SSL/TLS | Let's Encrypt (via Caddy) | Automatic | Certificate management | Automatic renewal; zero-configuration |
| Secret Management | .env files | N/A | Environment variable storage | Simple file-based approach with 600 permissions; production should consider Docker secrets |
| Network Isolation | Docker Networks | Native | Service segmentation | borgstack_internal for service communication; borgstack_external for proxy access |
| **Backup & Storage** |
| Volume Management | Docker Volumes | Native | Persistent data storage | Named volumes for databases, configs, and application data |
| Backup Destination | External Storage | Configurable | Off-site backup target | Customer-configured (S3, FTP, local drive) via Duplicati |

---
