# Epic Details

## Epic 1 Foundation & Core Infrastructure

**Epic Goal:** Establish the foundational infrastructure including project setup, core services (PostgreSQL, Redis), network configuration, and reverse proxy to provide a solid base for all subsequent components.

### Story 1.1 Project Repository Structure
As a developer, I want a monorepo structure with proper directory organization and initial configuration files, so that I can maintain consistency across all components and easily manage deployments.

**Acceptance Criteria:**
1. Repository created with standard monorepo structure
2. Root directory contains docker-compose.yml as centerpiece
3. Separate directories for configuration, documentation, and scripts
4. .gitignore file properly configured for Docker projects
5. .env.example template with all required variables
6. .gitignore configured to exclude .env files
7. README.md with project overview and quick start instructions
8. Initial version control setup with proper branching strategy

### Story 1.2 Docker Network Configuration
As a system administrator, I want internal Docker networks configured for secure inter-service communication, so that components can communicate safely while maintaining proper isolation.

**Acceptance Criteria:**
1. Internal network `borgstack_internal` validated in docker-compose.yml
2. External network `borgstack_external` validated for reverse proxy connectivity
3. Network security policies documented between networks
4. Service discovery via DNS names documented (validation deferred to Story 6.1 when services exist)
5. Network isolation configuration documented and verified in docker-compose.yml (service-level testing deferred to Stories 1.3-1.7)
6. Port mapping strategy documented for external access

### Story 1.3 PostgreSQL Database Setup
As a database administrator, I want PostgreSQL 18.0 with pgvector extension properly configured for SQL-compatible services, so that n8n, Chatwoot, Directus, and Evolution API have reliable data storage with vector search capabilities for RAG and LLM integrations.

**Acceptance Criteria:**
1. PostgreSQL 18.0 container running with pgvector extension
2. pgvector extension installed and verified for RAG/LLM support
3. Database initialization scripts executed on first run
4. Database isolation strategy implemented:
   - Separate databases: n8n_db, chatwoot_db, directus_db, evolution_db
   - Separate users with role-based permissions
   - Schema naming conflicts prevented
5. Database connection strings documented for each service
6. Persistent volume mounted for data storage
7. Connection pooling and timeout settings optimized
8. Health checks implemented for database monitoring
9. Backup strategy documented for data protection

### Story 1.4 Redis Cache Configuration
As a performance engineer, I want Redis 8.2 configured for caching and queuing, so that applications can achieve optimal performance and reliable message processing.

**Acceptance Criteria:**
1. Redis 8.2 container running with production settings
2. Persistent volume for Redis data configured
3. Memory limits and eviction policies properly set
4. Health checks and monitoring endpoints available
5. Connection security with password protection
6. Performance baseline established for cache hit rates

### Story 1.5 Caddy Reverse Proxy
As a DevOps engineer, I want Caddy 2.10 configured as reverse proxy with automatic SSL, so that all web services have secure HTTPS access with zero configuration overhead.

**Acceptance Criteria:**
1. Caddy container running with latest stable version
2. Automatic SSL certificate generation working
3. Reverse proxy rules for all services configured
4. HTTP to HTTPS redirection enforced
5. Security headers and CORS policies implemented
6. Caddyfile properly structured for maintainability

### Story 1.6 Bootstrap Script Development
As a deployment specialist, I want an automated bootstrap script for GNU/Linux, so that users can deploy the entire stack with minimal manual intervention.

**Acceptance Criteria:**
1. Bootstrap script checks system requirements
2. Docker and Docker Compose v2 automatically installed
3. Required system dependencies installed
4. Environment variables template (.env.example) created with prompts
5. Script validates installation with health checks
6. Script outputs next steps for SSL configuration via Caddy
7. Documentation for manual SSL setup provided

### Story 1.7 MongoDB Database Setup
As a database administrator, I want MongoDB 7.0 properly configured for Lowcoder, so that Lowcoder has reliable metadata and configuration storage.

**Acceptance Criteria:**
1. MongoDB 7.0 container running with production settings
2. Database initialization with root user credentials
3. Dedicated database 'lowcoder' created with authentication
4. Persistent volume mounted for data storage
5. Connection string configured for Lowcoder service
6. Health checks implemented for database monitoring
7. Backup strategy documented for data protection

## Epic 2 Automation & Communication Layer

**Epic Goal:** Implement workflow automation with n8n and WhatsApp integration via Evolution API, enabling businesses to create automated workflows that include WhatsApp communication capabilities.

### Story 2.1 n8n Workflow Platform
As a business analyst, I want n8n 1.112.6 deployed with proper database connections, so that I can create and manage automated business workflows.

**Acceptance Criteria:**
1. n8n container running with specified version
2. Database connection to PostgreSQL working
3. Redis connection for session management configured
4. Webhook functionality properly accessible
5. Environment variables for n8n configuration set
6. Basic workflow templates available for testing

### Story 2.2 Evolution API Integration
As a communication specialist, I want Evolution API v2.2.3 deployed with WhatsApp connectivity, so that workflows can send and receive WhatsApp messages.

**Acceptance Criteria:**
1. Evolution API container running with specified version
2. WhatsApp Business API connection configured
3. Multi-instance support for different businesses
4. Database connection for message storage
5. Webhook endpoints for message events
6. Basic message sending/receiving functionality tested
7. Integration with n8n documented via HTTP/webhook patterns

## Epic 3 Customer Service & Application Platform

**Epic Goal:** Deploy Chatwoot for omnichannel customer service and Lowcoder for custom application development including login interface, providing businesses with complete customer engagement and application building capabilities.

### Story 3.1 Chatwoot Customer Service
As a customer service manager, I want Chatwoot v4.6.0-ce deployed with database integration, so that I can manage customer communications across multiple channels.

**Acceptance Criteria:**
1. Chatwoot container running with specified version
2. Database connection to PostgreSQL working
3. Redis connection for session management configured
4. Email and SMS channel integration setup
5. Agent user management system working
6. Basic customer conversation flow tested

### Story 3.2 Lowcoder Application Platform
As an application developer, I want Lowcoder 2.7.4 deployed with external MongoDB and Redis connections, so that I can build custom applications with proper metadata storage.

**Acceptance Criteria:**
1. Lowcoder container running with specified version
2. Connection to external MongoDB working (LOWCODER_MONGODB_URL)
3. Connection to external Redis working (LOWCODER_REDIS_URL)
4. Application deployment and management working
5. User authentication and authorization functional
6. Basic application templates available

### Story 3.3 Lowcoder Application Platform Setup
As a business user, I want Lowcoder configured as an optional application development platform, so that I can build custom business applications as needed.

**Acceptance Criteria:**
1. Lowcoder platform deployed and accessible via Caddy
2. Database connection to PostgreSQL working for application data
3. Redis connection for session management within Lowcoder applications
4. Application development and deployment functionality working
5. Documentation for building applications with Lowcoder
6. Security best practices implemented for Lowcoder applications

## Epic 4 Data Management & Media Processing

**Epic Goal:** Implement Directus for headless CMS functionality and FileFlows for media processing, providing businesses with robust data management and automated media workflow capabilities.

### Story 4.1 Directus Headless CMS
As a content manager, I want Directus 11 deployed with proper configuration, so that I can manage and deliver content across all applications.

**Acceptance Criteria:**
1. Directus container running with specified version
2. Database connection to PostgreSQL working
3. Redis connection for caching configured
4. Admin user and role management setup
5. Content models and collections configured
6. API endpoints accessible for applications

### Story 4.2 FileFlows Media Processing
As a media specialist, I want FileFlows 25.09 deployed with storage integration, so that I can automate media processing workflows.

**Acceptance Criteria:**
1. FileFlows container running with specified version
2. Connection to SeaweedFS for storage working
3. Media processing workflows configured
4. Input/output directories properly mapped
5. Processing nodes and libraries initialized
6. Basic media conversion flows tested

### Story 4.3 Directus-FileFlows Integration
As an integration specialist, I want Directus to utilize FileFlows for media processing, so that content management includes automated media optimization.

**Acceptance Criteria:**
1. Directus can trigger FileFlows workflows
2. Media files automatically processed on upload
3. Processing results reflected in Directus
4. Error handling for failed processes
5. Performance monitoring for media operations
6. Storage optimization through automated processing

## Epic 5 Storage & Backup Systems

**Epic Goal:** Configure SeaweedFS for S3-compatible object storage and Duplicati for automated backup solutions, ensuring reliable file storage and comprehensive data protection.

### Story 5.1 SeaweedFS Object Storage
As a storage administrator, I want SeaweedFS 3.97 deployed with S3 compatibility, so that all applications have reliable object storage with standard APIs.

**Acceptance Criteria:**
1. SeaweedFS container running with specified version
2. S3 API compatibility enabled and working
3. Volume and server topology configured
4. Replication and redundancy setup
5. Storage quotas and limits configured
6. Basic file upload/download tested

### Story 5.2 Duplicati Backup System
As a backup specialist, I want Duplicati 2.1.1.102 deployed with automation, so that all critical data is regularly backed up to external storage.

**Acceptance Criteria:**
1. Duplicati container running with specified version
2. Backup sources properly configured (databases, files)
3. Backup destinations and schedules set
4. Encryption and compression enabled
5. Backup verification and testing procedures
6. Restoration procedure documented and tested
7. Full restore test performed successfully from backup
8. Restore time benchmarks established

### Story 5.3 Storage Integration Testing
As a quality assurance engineer, I want all storage systems working together seamlessly, so that applications can reliably store and retrieve data across all components.

**Acceptance Criteria:**
1. n8n configured to use SeaweedFS for workflow attachments
2. Directus configured to use SeaweedFS for asset storage
3. Basic S3 compatibility tested with standard S3 client
4. FileFlows uses SeaweedFS for input/output
5. Storage performance benchmarks established
6. Storage capacity monitoring implemented

## Epic 6 Integration & Documentation

**Epic Goal:** Create comprehensive Portuguese documentation and ensure all components work together seamlessly with proper integrations, providing users with complete deployment and usage guidance.

### Story 6.1 Integration Testing Suite
As a test engineer, I want comprehensive integration tests for all components, so that I can verify the entire stack works together as expected.

**Acceptance Criteria:**
1. End-to-end smoke tests for all major workflows
2. Integration tests between all components
3. Basic functionality verified across all services
4. Common failure scenarios tested and documented
5. Test results documented and analyzed

Note: Advanced performance testing, load testing, and security vulnerability assessments are marked as post-MVP enhancements.

### Story 6.2 Portuguese Documentation
As a technical writer, I want comprehensive Portuguese documentation covering all aspects of the system, so that Brazilian users can successfully deploy and use BorgStack.

**Acceptance Criteria:**
1. Installation guide for GNU/Linux
2. Configuration documentation for all components
3. Integration guides for common workflows
4. Troubleshooting section with common issues
5. Security and maintenance guidelines
6. Performance optimization recommendations
7. Logging and troubleshooting guide with docker compose logs examples

### Story 6.3 User Guides and Tutorials
As a user experience specialist, I want step-by-step guides and tutorials in Portuguese, so that users can quickly learn to use all components effectively.

**Acceptance Criteria:**
1. Getting started tutorial for new users
2. Component-specific guides for each tool
3. Common workflow examples and templates
4. Best practices and optimization tips
5. Community contribution guidelines

### Story 6.4 Component Update Procedures
As a system administrator, I want documented procedures for updating individual components, so that I can maintain the system without breaking integrations.

**Acceptance Criteria:**
1. Individual component update process documented
2. Version pinning strategy documented in docker-compose.yml
3. Rollback procedure for failed updates
4. Pre-update backup verification checklist
5. Common update issues and solutions documented
6. Update notification strategy defined

### Story 6.5 Final Deployment Verification
As a deployment engineer, I want a final verification that the complete stack deploys successfully, so that I can confidently deliver on the core project promise.

**Acceptance Criteria:**
1. Clean GNU/Linux deployment tested
2. Deployment within 4-6 hours verified on clean GNU/Linux
3. All components functional after deployment
4. Basic workflows tested and working
5. Performance metrics within expected ranges
6. Documentation accuracy verified

## Epic 7 Documentation Simplification

**Epic Goal:** Simplify BorgStack documentation from ~32,000 lines across 29 files to ~1,400 lines in 6 essential files, eliminating redundancies, removing third-party tool documentation, and maintaining only critical information for installation, configuration, and maintenance.

**CRITICAL: Files to NEVER modify or delete:**
- docs/brief.md
- docs/prd.md
- docs/architecture.md
- All files in docs/prd/ directory
- All files in docs/architecture/ directory
- All files in docs/qa/ directory
- All files in docs/stories/ directory
- CLAUDE.md
- CONTRIBUTING.md
- LICENSE

**Scope:** Only modify/delete user-facing documentation files in root and docs/ (excluding protected directories above).

### Story 7.1 Consolidate Installation Documentation
As a new user, I want streamlined installation documentation, so that I can understand and deploy BorgStack in 30 minutes instead of reading 6 hours of documentation.

**Files to DELETE:**
- docs/README.md
- docs/00-inicio-rapido.md
- docs/01-instalacao.md

**Files to CREATE/UPDATE:**
- README.md (root) - replace existing
- INSTALL.md (root) - create new

**Acceptance Criteria:**
1. README.md (100-150 lines) contains: project description, service list, Quick Start (5 commands), documentation links
2. INSTALL.md (150-200 lines) contains: local mode installation, production mode installation, installation troubleshooting
3. Zero overlap or repetition between README.md and INSTALL.md
4. All installation commands tested and functional
5. Old files deleted: docs/README.md, docs/00-inicio-rapido.md, docs/01-instalacao.md
6. Protected files untouched: docs/prd/, docs/architecture/, docs/qa/, docs/stories/, CLAUDE.md, CONTRIBUTING.md, LICENSE

### Story 7.2 Remove Third-Party Documentation and Consolidate Configuration
As a system administrator, I want BorgStack-specific configuration documentation only, so that I don't waste time reading PostgreSQL/Redis tutorials that already have official documentation.

**Files to DELETE:**
- docs/02-configuracao.md
- docs/03-services/ (entire directory with 14 files)

**Files to CREATE:**
- CONFIGURATION.md (root)
- docs/services.md

**Acceptance Criteria:**
1. CONFIGURATION.md (100-150 lines) documents only BorgStack .env variables
2. docs/services.md (200-300 lines) contains links to official documentation plus BorgStack-specific configurations only
3. Zero detailed tutorials for third-party tools (PostgreSQL, Redis, MongoDB, Caddy, etc.)
4. BorgStack-specific configurations clearly identified (e.g., POSTGRES_DATABASES, internal network names)
5. Old files deleted: docs/02-configuracao.md, entire docs/03-services/ directory
6. Protected files untouched: docs/prd/, docs/architecture/, docs/qa/, docs/stories/, docs/brief.md, docs/prd.md, docs/architecture.md

### Story 7.3 Consolidate Operations and Complete Cleanup
As a DevOps engineer, I want concise operational documentation, so that I can maintain BorgStack without reading hundreds of pages.

**Files to DELETE:**
- docs/04-integrations/ (entire directory)
- docs/05-solucao-de-problemas.md
- docs/06-manutencao.md
- docs/07-seguranca.md
- docs/08-desempenho.md
- docs/09-workflows-exemplo.md
- docs/POST_MVP_MULTI_TENANT_ARCHITECTURE.md

**Files to CREATE:**
- TROUBLESHOOTING.md (root)
- docs/integrations.md
- docs/maintenance.md

**Files that MUST remain in docs/ after cleanup:**
- docs/services.md (created in Story 7.2)
- docs/integrations.md (created in this story)
- docs/maintenance.md (created in this story)
- docs/brief.md (PROTECTED - do not touch)
- docs/prd.md (PROTECTED - do not touch)
- docs/architecture.md (PROTECTED - do not touch)
- docs/prd/ directory (PROTECTED - do not touch)
- docs/architecture/ directory (PROTECTED - do not touch)
- docs/qa/ directory (PROTECTED - do not touch)
- docs/stories/ directory (PROTECTED - do not touch)

**Acceptance Criteria:**
1. TROUBLESHOOTING.md (100-150 lines) covers 10 most common BorgStack problems
2. docs/integrations.md (150-200 lines) explains how BorgStack services integrate with each other
3. docs/maintenance.md (100-150 lines) has concise checklists for backup, updates, basic security
4. docs/ directory contains user-facing files (services.md, integrations.md, maintenance.md) plus protected development files
5. All internal links updated and functional
6. Total user-facing documentation < 1,500 lines verified
7. Old files deleted: docs/04-integrations/, docs/05-09, docs/POST_MVP_MULTI_TENANT_ARCHITECTURE.md
8. PROTECTED files confirmed untouched: docs/brief.md, docs/prd.md, docs/architecture.md, docs/prd/, docs/architecture/, docs/qa/, docs/stories/
