# Requirements

## Functional Requirements

FR1: The system shall provide a unified Docker Compose configuration that deploys all 13 components (PostgreSQL, MongoDB, Redis, SeaweedFS, n8n, Evolution API, Chatwoot, Lowcoder, Directus, Caddy, FileFlows, Duplicati), requiring manual configuration and environment setup.

FR2: The system shall include a bootstrap script that automatically prepares Ubuntu 24.04 LTS servers with all required dependencies and configurations.

FR3: The system shall provide integration capabilities between n8n, Evolution API, and Chatwoot for WhatsApp workflow automation and customer service, requiring custom HTTP node development in n8n and webhook configuration between components.

FR4: The system shall include automated backup functionality via Duplicati with configurable schedules and external storage destinations.

FR5: The system shall provide automatic SSL/TLS certificate generation and management via Caddy for all web interfaces, requiring proper domain configuration and DNS setup.

FR6: The system shall include comprehensive Portuguese documentation covering installation, configuration, and troubleshooting.

FR7: The system shall provide shared PostgreSQL 18.x database with pgvector extension for RAG and LLM integrations, used by n8n, Chatwoot, Directus, and Evolution API requiring persistent SQL storage.

FR7b: The system shall provide MongoDB 7.0 database dedicated to Lowcoder for metadata and configuration storage.

FR8: The system shall include Redis 8.2.x for session management, caching, and message queuing across components.

FR9: The system shall provide SeaweedFS S3-compatible object storage for file handling and media processing.

FR10: The system shall include monitoring and logging capabilities to track system health and performance across all components.

FR11: The system shall support development and production deployment modes with configurable network isolation.

FR12: The system shall provide administrative access methods including SSH tunneling for secure backend component management in production mode.

FR13: The system shall include intellectual property protection features including automated backup of workflows and configurations.

## Non-Functional Requirements

NFR1: The system must achieve complete deployment within 4-6 hours on a clean Ubuntu 24.04 LTS VPS meeting minimum requirements (8 vCPUs, 36GB RAM, 500GB SSD), assuming no troubleshooting required.

NFR2: The system must provide high availability on single server with automatic container restart on failure.

Note: Multi-server HA clustering is out of scope for MVP.

NFR3: All components must use officially maintained Docker images with stable versions to ensure security and reliability.

NFR4: The system must support data sovereignty requirements by enabling self-hosted deployment on any infrastructure.

NFR5: The system must support horizontal scaling for n8n and Chatwoot to handle increased workload.

NFR6: The system must provide comprehensive logging and monitoring for troubleshooting and performance optimization.

NFR7: The system must implement security best practices including network isolation, regular updates, and secure configuration defaults.

NFR8: The system must maintain backward compatibility for existing deployments when updating component versions.

NFR9: The system must provide Portuguese language support for all user-facing interfaces and comprehensive Portuguese documentation.

NFR10: The system must minimize resource usage while maintaining performance for small to medium-sized deployments.

NFR11: The system must support basic network isolation via Docker networks for service communication.

NFR12: The system must include comprehensive documentation for production deployment and security configuration.

NFR13: The system must implement automated backup and configuration management features.

NFR14: The system must provide centralized log access via docker compose logs command for troubleshooting across all components.

NFR15: The system must store credentials securely in .env files with restricted permissions (600), with .env excluded from version control. Production deployments should consider Docker secrets or external secret management.
