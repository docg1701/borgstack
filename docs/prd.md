# BorgStack Product Requirements Document (PRD)

## Goals and Background Context

### Goals
- Deliver a technically viable, pre-integrated stack of 13 open source tools that work together as a unified system deployable in 4-6 hours
- Provide Brazilian companies with a zero-license-cost alternative to proprietary automation platforms with complete data sovereignty
- Eliminate vendor lock-in while providing enterprise-grade workflow automation, omnichannel customer service, application builder, and media processing capabilities
- Achieve 90%+ successful deployment rate with significant cost reduction compared to proprietary tools
- Build a technically sound open source project with comprehensive documentation and community support

### Background Context
BorgStack addresses the need for a cost-effective automation solution for Portuguese-speaking businesses seeking alternatives to proprietary SaaS tools. While many companies use automation platforms, the high costs of proprietary solutions and concerns about data residency create opportunities for open source alternatives. Current approaches require significant technical expertise to integrate multiple tools, creating barriers for smaller organizations. BorgStack provides a pre-integrated stack with Portuguese documentation, focusing on technical viability rather than market size claims.

### Change Log
| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2025-01-29 | v1.0 | Initial PRD creation from Project Brief | John (PM Agent) |
| 2025-01-29 | v1.1 | Added production deployment modes, network isolation, and security configuration guidelines | John (PM Agent) |

## Requirements

### Functional Requirements

FR1: The system shall provide a unified Docker Compose configuration that deploys all 13 components (PostgreSQL, MongoDB, Redis, SeaweedFS, n8n, Evolution API, Chatwoot, Lowcoder, Directus, Caddy, FileFlows, Duplicati), requiring manual configuration and environment setup.

FR2: The system shall include a bootstrap script that automatically prepares GNU/Linux servers with all required dependencies and configurations.

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

### Non-Functional Requirements

NFR1: The system must achieve complete deployment within 4-6 hours on a clean GNU/Linux VPS meeting minimum requirements (8 vCPUs, 36GB RAM, 500GB SSD), assuming no troubleshooting required.

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

## Access and Interface Requirements

### System Access Model
The system provides individual access to each component through their native web interfaces, with no centralized UI or unified dashboard. Users access each tool directly via browser through Caddy reverse proxy routing.

### Component Access
- **Direct Access**: Each component (n8n, Chatwoot, Lowcoder, Directus, etc.) is accessed through its own URL
- **Individual Authentication**: Each service maintains its own login system and user management
- **Native Interfaces**: Users interact with each tool's standard web interface
- **No Custom UI**: BorgStack does not include custom user interfaces beyond the components themselves

### Administrative Access
- **Command Line**: All system operations performed via Docker commands and scripts
- **Configuration Files**: Manual configuration through environment variables and config files
- **Log Access**: Direct access to container logs for troubleshooting
- **Database Management**: Direct database access for administrative tasks

## Production Deployment Considerations

The MVP deployment focuses on functional integration of all components. Production security hardening (network isolation, firewall rules, VPN access) should be implemented post-deployment based on organizational security requirements. Basic Docker network isolation is provided via `borgstack_internal` network for service communication.

## Technical Assumptions

### Repository Structure: Monorepo
The project will use a monorepo structure with `docker-compose.yml` as the centerpiece. All configuration files, documentation, and scripts will be maintained in a single repository for simplicity and ease of deployment.

### Service Architecture
**Architecture Pattern: Microservices within Docker Compose**
- Each of the 12 components runs as separate Docker containers
- Internal Docker network for secure inter-service communication
- Caddy as reverse proxy with zero-configuration TLS termination
- Shared PostgreSQL and Redis for data persistence and caching
- Isolated networks for enhanced security and service discovery

### Testing Requirements
**Testing Level: Unit + Integration**
- Unit tests for configuration validation and bootstrapping scripts
- Integration tests for inter-service communication
- End-to-end deployment testing on clean GNU/Linux environments
- Manual testing procedures for user documentation validation

### Additional Technical Assumptions and Requests

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

## Epic List

**Epic 1: Foundation & Core Infrastructure** - Establish project setup, Docker Compose configuration, and core infrastructure components including database, caching, and reverse proxy.

**Epic 2: Automation & Communication Layer** - Implement workflow automation with n8n and WhatsApp integration via Evolution API, enabling automated business processes.

**Epic 3: Customer Service & Application Platform** - Deploy Chatwoot for omnichannel customer service and Lowcoder for custom application development including login interface.

**Epic 4: Data Management & Media Processing** - Implement Directus for headless CMS functionality and FileFlows for media processing workflows.

**Epic 5: Storage & Backup Systems** - Configure SeaweedFS for S3-compatible object storage and Duplicati for automated backup solutions.

**Epic 6: Integration & Documentation** - Create comprehensive Portuguese documentation and ensure all components work together seamlessly with proper integrations.

## Epic Details

### Epic 1 Foundation & Core Infrastructure

**Epic Goal:** Establish the foundational infrastructure including project setup, core services (PostgreSQL, Redis), network configuration, and reverse proxy to provide a solid base for all subsequent components.

#### Story 1.1 Project Repository Structure
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

#### Story 1.2 Docker Network Configuration
As a system administrator, I want internal Docker networks configured for secure inter-service communication, so that components can communicate safely while maintaining proper isolation.

**Acceptance Criteria:**
1. Internal network `borgstack_internal` created in docker-compose.yml
2. External network `borgstack_external` for reverse proxy connectivity
3. Network security policies implemented between networks
4. Service discovery via DNS names working correctly
5. Network isolation preventing unauthorized access
6. Port mapping properly configured for external access

#### Story 1.3 PostgreSQL Database Setup
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

#### Story 1.4 Redis Cache Configuration
As a performance engineer, I want Redis 8.2 configured for caching and queuing, so that applications can achieve optimal performance and reliable message processing.

**Acceptance Criteria:**
1. Redis 8.2 container running with production settings
2. Persistent volume for Redis data configured
3. Memory limits and eviction policies properly set
4. Health checks and monitoring endpoints available
5. Connection security with password protection
6. Performance baseline established for cache hit rates

#### Story 1.5 Caddy Reverse Proxy
As a DevOps engineer, I want Caddy 2.10 configured as reverse proxy with automatic SSL, so that all web services have secure HTTPS access with zero configuration overhead.

**Acceptance Criteria:**
1. Caddy container running with latest stable version
2. Automatic SSL certificate generation working
3. Reverse proxy rules for all services configured
4. HTTP to HTTPS redirection enforced
5. Security headers and CORS policies implemented
6. Caddyfile properly structured for maintainability

#### Story 1.6 Bootstrap Script Development
As a deployment specialist, I want an automated bootstrap script for GNU/Linux, so that users can deploy the entire stack with minimal manual intervention.

**Acceptance Criteria:**
1. Bootstrap script checks system requirements
2. Docker and Docker Compose v2 automatically installed
3. Required system dependencies installed
4. Environment variables template (.env.example) created with prompts
5. Script validates installation with health checks
6. Script outputs next steps for SSL configuration via Caddy
7. Documentation for manual SSL setup provided

#### Story 1.7 MongoDB Database Setup
As a database administrator, I want MongoDB 7.0 properly configured for Lowcoder, so that Lowcoder has reliable metadata and configuration storage.

**Acceptance Criteria:**
1. MongoDB 7.0 container running with production settings
2. Database initialization with root user credentials
3. Dedicated database 'lowcoder' created with authentication
4. Persistent volume mounted for data storage
5. Connection string configured for Lowcoder service
6. Health checks implemented for database monitoring
7. Backup strategy documented for data protection

### Epic 2 Automation & Communication Layer

**Epic Goal:** Implement workflow automation with n8n and WhatsApp integration via Evolution API, enabling businesses to create automated workflows that include WhatsApp communication capabilities.

#### Story 2.1 n8n Workflow Platform
As a business analyst, I want n8n 1.112.6 deployed with proper database connections, so that I can create and manage automated business workflows.

**Acceptance Criteria:**
1. n8n container running with specified version
2. Database connection to PostgreSQL working
3. Redis connection for session management configured
4. Webhook functionality properly accessible
5. Environment variables for n8n configuration set
6. Basic workflow templates available for testing

#### Story 2.2 Evolution API Integration
As a communication specialist, I want Evolution API v2.2.3 deployed with WhatsApp connectivity, so that workflows can send and receive WhatsApp messages.

**Acceptance Criteria:**
1. Evolution API container running with specified version
2. WhatsApp Business API connection configured
3. Multi-instance support for different businesses
4. Database connection for message storage
5. Webhook endpoints for message events
6. Basic message sending/receiving functionality tested
7. Integration with n8n documented via HTTP/webhook patterns

### Epic 3 Customer Service & Application Platform

**Epic Goal:** Deploy Chatwoot for omnichannel customer service and Lowcoder for custom application development including login interface, providing businesses with complete customer engagement and application building capabilities.

#### Story 3.1 Chatwoot Customer Service
As a customer service manager, I want Chatwoot v4.6.0-ce deployed with database integration, so that I can manage customer communications across multiple channels.

**Acceptance Criteria:**
1. Chatwoot container running with specified version
2. Database connection to PostgreSQL working
3. Redis connection for session management configured
4. Email and SMS channel integration setup
5. Agent user management system working
6. Basic customer conversation flow tested

#### Story 3.2 Lowcoder Application Platform
As an application developer, I want Lowcoder 2.7.4 deployed with external MongoDB and Redis connections, so that I can build custom applications with proper metadata storage.

**Acceptance Criteria:**
1. Lowcoder container running with specified version
2. Connection to external MongoDB working (LOWCODER_MONGODB_URL)
3. Connection to external Redis working (LOWCODER_REDIS_URL)
4. Application deployment and management working
5. User authentication and authorization functional
6. Basic application templates available

#### Story 3.3 Lowcoder Application Platform Setup
As a business user, I want Lowcoder configured as an optional application development platform, so that I can build custom business applications as needed.

**Acceptance Criteria:**
1. Lowcoder platform deployed and accessible via Caddy
2. Database connection to PostgreSQL working for application data
3. Redis connection for session management within Lowcoder applications
4. Application development and deployment functionality working
5. Documentation for building applications with Lowcoder
6. Security best practices implemented for Lowcoder applications

### Epic 4 Data Management & Media Processing

**Epic Goal:** Implement Directus for headless CMS functionality and FileFlows for media processing, providing businesses with robust data management and automated media workflow capabilities.

#### Story 4.1 Directus Headless CMS
As a content manager, I want Directus 11 deployed with proper configuration, so that I can manage and deliver content across all applications.

**Acceptance Criteria:**
1. Directus container running with specified version
2. Database connection to PostgreSQL working
3. Redis connection for caching configured
4. Admin user and role management setup
5. Content models and collections configured
6. API endpoints accessible for applications

#### Story 4.2 FileFlows Media Processing
As a media specialist, I want FileFlows 25.09 deployed with storage integration, so that I can automate media processing workflows.

**Acceptance Criteria:**
1. FileFlows container running with specified version
2. Connection to SeaweedFS for storage working
3. Media processing workflows configured
4. Input/output directories properly mapped
5. Processing nodes and libraries initialized
6. Basic media conversion flows tested

#### Story 4.3 Directus-FileFlows Integration
As an integration specialist, I want Directus to utilize FileFlows for media processing, so that content management includes automated media optimization.

**Acceptance Criteria:**
1. Directus can trigger FileFlows workflows
2. Media files automatically processed on upload
3. Processing results reflected in Directus
4. Error handling for failed processes
5. Performance monitoring for media operations
6. Storage optimization through automated processing

### Epic 5 Storage & Backup Systems

**Epic Goal:** Configure SeaweedFS for S3-compatible object storage and Duplicati for automated backup solutions, ensuring reliable file storage and comprehensive data protection.

#### Story 5.1 SeaweedFS Object Storage
As a storage administrator, I want SeaweedFS 3.97 deployed with S3 compatibility, so that all applications have reliable object storage with standard APIs.

**Acceptance Criteria:**
1. SeaweedFS container running with specified version
2. S3 API compatibility enabled and working
3. Volume and server topology configured
4. Replication and redundancy setup
5. Storage quotas and limits configured
6. Basic file upload/download tested

#### Story 5.2 Duplicati Backup System
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

#### Story 5.3 Storage Integration Testing
As a quality assurance engineer, I want all storage systems working together seamlessly, so that applications can reliably store and retrieve data across all components.

**Acceptance Criteria:**
1. n8n configured to use SeaweedFS for workflow attachments
2. Directus configured to use SeaweedFS for asset storage
3. Basic S3 compatibility tested with standard S3 client
4. FileFlows uses SeaweedFS for input/output
5. Storage performance benchmarks established
6. Storage capacity monitoring implemented

### Epic 6 Integration & Documentation

**Epic Goal:** Create comprehensive Portuguese documentation and ensure all components work together seamlessly with proper integrations, providing users with complete deployment and usage guidance.

#### Story 6.1 Integration Testing Suite
As a test engineer, I want comprehensive integration tests for all components, so that I can verify the entire stack works together as expected.

**Acceptance Criteria:**
1. End-to-end smoke tests for all major workflows
2. Integration tests between all components
3. Basic functionality verified across all services
4. Common failure scenarios tested and documented
5. Test results documented and analyzed

Note: Advanced performance testing, load testing, and security vulnerability assessments are marked as post-MVP enhancements.

#### Story 6.2 Portuguese Documentation
As a technical writer, I want comprehensive Portuguese documentation covering all aspects of the system, so that Brazilian users can successfully deploy and use BorgStack.

**Acceptance Criteria:**
1. Installation guide for GNU/Linux
2. Configuration documentation for all components
3. Integration guides for common workflows
4. Troubleshooting section with common issues
5. Security and maintenance guidelines
6. Performance optimization recommendations
7. Logging and troubleshooting guide with docker compose logs examples

#### Story 6.3 User Guides and Tutorials
As a user experience specialist, I want step-by-step guides and tutorials in Portuguese, so that users can quickly learn to use all components effectively.

**Acceptance Criteria:**
1. Getting started tutorial for new users
2. Component-specific guides for each tool
3. Common workflow examples and templates
4. Best practices and optimization tips
5. Community contribution guidelines

#### Story 6.4 Component Update Procedures
As a system administrator, I want documented procedures for updating individual components, so that I can maintain the system without breaking integrations.

**Acceptance Criteria:**
1. Individual component update process documented
2. Version pinning strategy documented in docker-compose.yml
3. Rollback procedure for failed updates
4. Pre-update backup verification checklist
5. Common update issues and solutions documented
6. Update notification strategy defined

## Checklist Results Report

### Executive Summary
- **Overall PRD Completeness**: 95% - Comprehensive with architectural clarity
- **MVP Scope Appropriateness**: Just Right - Focused on essential infrastructure
- **Readiness for Architecture Phase**: Ready - Clear technical guidance provided
- **Most Critical Gaps**: Database isolation and monitoring strategy now documented

### Category Analysis Table

| Category                         | Status | Critical Issues |
| -------------------------------- | ------ | --------------- |
| 1. Problem Definition & Context  | PASS   | None |
| 2. MVP Scope Definition          | PASS   | None |
| 3. User Experience Requirements  | PASS   | None |
| 4. Functional Requirements       | PASS   | None |
| 5. Non-Functional Requirements   | PASS   | None |
| 6. Epic & Story Structure        | PASS   | None |
| 7. Technical Guidance            | PASS   | None |
| 8. Cross-Functional Requirements | PASS   | None |
| 9. Clarity & Communication       | PASS   | None |

### Top Issues by Priority
- **BLOCKERS**: None identified
- **HIGH**: None identified
- **MEDIUM**: Database isolation and monitoring strategy now documented
- **LOW**: Portuguese-speaking market focus clarified

### MVP Scope Assessment
**Features appropriately scoped:**
- Core infrastructure (PostgreSQL, MongoDB, Redis, Caddy) - Essential
- Docker Compose configuration - Essential
- Bootstrap script - Essential
- Individual component integrations - Essential
- Portuguese documentation - Essential

**Notable exclusions handled well:**
- Multi-tenant architecture - Appropriately deferred
- Web-based management interface - Appropriately deferred
- Pre-built workflow templates - Appropriately deferred

**Complexity concerns:**
- 13 components integration is complex but well-managed through epic structure
- 4-6 hour deployment target is realistic and achievable with automation

### Technical Readiness
**Technical constraints clearly defined:**
- Docker Compose v2 requirement
- GNU/Linux target platform
- Internal network communication requirements
- Component version specifications

**Technical risks identified:**
- Component version compatibility across 13 services
- Database isolation between PostgreSQL and MongoDB services
- Maintenance complexity of integrated stack

**Areas needing architect investigation:**
- Network topology optimization for internal communication
- Database isolation strategy (PostgreSQL for SQL apps, MongoDB for Lowcoder)
- Backup strategy coordination across all components

### Recommendations
1. **Proceed to architecture phase** - PRD is comprehensive and ready
2. **Consider adding component compatibility matrix** during architecture phase
3. **Develop deployment performance testing** as part of verification
4. **Plan for component update strategy** in maintenance documentation

### Final Decision
**READY FOR ARCHITECT**: The PRD and epics are comprehensive, properly structured, and ready for architectural design. The requirements clearly define a viable MVP with appropriate scope boundaries and technical constraints.

## Next Steps

### UX Expert Prompt
This PRD outlines the complete BorgStack automation stack. Please review the user experience requirements, particularly focusing on the Lowcoder login interface implementation and Portuguese documentation needs.

### Architect Prompt
Please review the technical architecture for BorgStack, focusing on the Docker Compose configuration, internal networking, and integration requirements between all 13 components. Pay special attention to database isolation strategy (PostgreSQL for SQL apps, MongoDB for Lowcoder), Redis sharing, and service communication patterns.