# Technical Assumptions

## Repository Structure: Monorepo
The project will use a monorepo structure with `docker-compose.yml` as the centerpiece. All configuration files, documentation, and scripts will be maintained in a single repository for simplicity and ease of deployment.

## Service Architecture
**Architecture Pattern: Microservices within Docker Compose**
- Each of the 12 components runs as separate Docker containers
- Internal Docker network for secure inter-service communication
- Caddy as reverse proxy with zero-configuration TLS termination
- Shared PostgreSQL and Redis for data persistence and caching
- Isolated networks for enhanced security and service discovery

## Testing Requirements
**Testing Level: Unit + Integration**
- Unit tests for configuration validation and bootstrapping scripts
- Integration tests for inter-service communication
- End-to-end deployment testing on clean GNU/Linux environments
- Manual testing procedures for user documentation validation

## Additional Technical Assumptions and Requests

**Technology Stack Validation (from docs/brief.md):**

| # | Component | Version | Docker Image | GitHub Repository | Purpose |
|---|-----------|---------|--------------|-------------------|---------|
| 1 | PostgreSQL + pgvector | 18.0 | `pgvector/pgvector:pg18` | pgvector/pgvector | Relational database with vector search for n8n, Chatwoot, Directus, Evolution API |
| 2 | MongoDB | 7.0 | `mongo:7.0` | mongodb/mongo | NoSQL database for Lowcoder metadata and configuration storage |
| 3 | Redis | 8.2 | `redis:8.2-alpine` | redis/redis | In-memory cache and queue system shared across all services |
| 4 | SeaweedFS | 3.97 | `chrislusf/seaweedfs:3.97` | seaweedfs/seaweedfs | S3-compatible distributed object storage for media and files |
| 5 | n8n | 1.112.6 | `n8nio/n8n:1.112.6` | n8n-io/n8n | Workflow automation and orchestration platform |
| 6 | Evolution API | v2.2.3 | `atendai/evolution-api:v2.2.3` | EvolutionAPI/evolution-api | WhatsApp multi-instance integration API |
| 7 | Chatwoot | v4.6.0-ce | `chatwoot/chatwoot:v4.6.0-ce` | chatwoot/chatwoot | Omnichannel customer service and communication platform |
| 8 | Lowcoder | 2.7.4 | `lowcoderorg/lowcoder-ce:2.7.4` | lowcoder-org/lowcoder | Low-code application builder and internal tools platform |
| 9 | Directus | 11 | `directus/directus:11` | directus/directus | Headless CMS and data management platform |
| 10 | Caddy | 2.10 | `caddy:2.10-alpine` | caddyserver/caddy | Reverse proxy with automatic HTTPS/SSL certificate management |
| 11 | FileFlows | 25.09 | `revenz/fileflows:25.09` | revenz/FileFlows | Media processing, conversion, and automation system |
| 12 | Duplicati | 2.1.1.102 | `duplicati/duplicati:2.1.1.102` | duplicati/duplicati | Automated encrypted backup system for data protection |

**Note:** Alpine-based images (Redis, Caddy) are used where available for optimized resource usage and smaller container footprint.

**Network Architecture:**
- Internal Docker network `borgstack_internal` for service communication
- Each service accessible via service name (e.g., `http://n8n:5678`)
- Caddy handles external HTTPS routing and service exposure
- n8n has internal network access to all services for workflow integration
- Services should communicate as if on a proprietary paid platform

**Lowcoder Configuration:**
- Lowcoder connects to external MongoDB and Redis instances
- MongoDB dedicated to Lowcoder metadata and configuration
- Redis shared across all services for caching and sessions
- Environment variables LOWCODER_MONGODB_URL and LOWCODER_REDIS_URL configure connections
- Users can optionally create custom applications using Lowcoder for specific business needs
- Lowcoder is an application builder, not an authentication system or SSO gateway
- Each service (Chatwoot, n8n, Directus) maintains its own independent authentication
- Portuguese UX for applications built with Lowcoder, English code comments and configuration

**Language Standards:**
- All code, comments, and configuration files in English
- Portuguese (Brazil) for user documentation and UX text
- Consistent naming conventions across all components

**Infrastructure Requirements:**
- GNU/Linux as target deployment platform
- Docker Compose v2 with official images only
- Static IP and domain name required for SSL certificates

**Hardware Requirements:**
- **Minimum**: 4 vCPUs, 16GB RAM, 200GB SSD - for testing and small workloads
- **Recommended**: 8 vCPUs, 36GB RAM, 500GB SSD - for production deployment with 13 components
