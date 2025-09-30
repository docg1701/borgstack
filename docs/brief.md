# Project Brief: BorgStack

<!-- Powered by BMAD™ Core -->

## Executive Summary

BorgStack is a comprehensive open source enterprise automation stack that assimilates 12 best-in-class tools into a unified Docker Compose deployment. It provides Brazilian companies with a zero-license-cost alternative to proprietary automation platforms (Zapier, Make, Intercom, etc.) by offering complete workflow automation, omnichannel customer service, application builder, and media processing capabilities deployable in 30 minutes. The solution eliminates vendor lock-in, keeps data 100% on-premises in Brazil, and provides unlimited usage without artificial constraints.

## Problem Statement

**Current State:** Brazilian companies spend R$ 2,300-11,000 monthly on proprietary automation tools with severe limitations including vendor lock-in, data hosted outside Brazil, usage caps, and restrictive licensing.

**Impact:** This creates significant financial burden, data sovereignty concerns, and operational constraints that limit business growth and innovation.

**Why Existing Solutions Fall Short:**
- Proprietary tools have usage limits and escalating costs
- Data residency violates Brazilian sovereignty requirements
- Fragmented open source alternatives require weeks of specialized integration work
- Lack of Portuguese documentation and support

**Urgency:** With accelerating digital transformation in Brazil, companies need immediate access to enterprise-grade automation without prohibitive costs.

## Proposed Solution

BorgStack delivers a pre-integrated, production-ready stack of 12 open source tools that work together as a unified system. The solution includes:

- **Unified Docker Compose configuration** for single-command deployment
- **Complete integration** between all components (WhatsApp workflows, customer service, databases, etc.)
- **Comprehensive Portuguese documentation** and setup automation
- **Professional backup and maintenance** systems included
- **Zero vendor lock-in** with full data portability

**Key Differentiators:**
- First mover in Brazilian market with integrated PT-BR documentation
- Production-tested integrations vs fragmented DIY approaches
- Enterprise reliability with open source freedom
- Complete deployment in 30 minutes vs weeks of configuration

## Target Users

### Primary User Segment: Digital Agencies
- **Profile:** Agencies serving multiple clients with diverse automation needs
- **Current Behavior:** Using multiple SaaS tools, paying per-client licensing
- **Needs:** Cost-effective multi-tenant solution, white-label capabilities, quick deployment
- **Goals:** Reduce operational costs, scale client services, maintain profit margins

### Primary User Segment: Startups & SMEs
- **Profile:** Growing businesses needing enterprise automation on limited budgets
- **Current Behavior:** Manual processes or limited use of freemium tools
- **Needs:** Unlimited automation, data sovereignty, scalability
- **Goals:** Compete with larger enterprises, reduce operational overhead

### Secondary User Segment: IT Departments
- **Profile:** Enterprise IT teams seeking open source alternatives
- **Current Behavior:** Evaluating and integrating individual open source tools
- **Needs:** Standardized, supported, maintainable solutions
- **Goals:** Reduce licensing costs, maintain control over infrastructure

## Goals & Success Metrics

### Business Objectives
- Achieve 1,000+ GitHub stars within 12 months
- Generate R$ 50,000+ monthly from professional services by month 6
- Establish BorgStack as the reference for automation in Brazil within 2 years
- Build community of 500+ active installations

### User Success Metrics
- 90%+ successful deployment rate for new users
- 80%+ reduction in automation costs compared to proprietary tools
- < 4 hours average time to full deployment
- 95%+ user satisfaction with documentation and setup process

### Key Performance Indicators (KPIs)
- **GitHub Stars**: Measure project visibility and adoption (Target: 1,000+ by year 1)
- **Active Installations**: Track actual usage (Target: 200+ by month 6)
- **Professional Services Revenue**: Monitor business sustainability (Target: R$ 50k/month by month 6)
- **Community Engagement**: Measure ecosystem health (Target: 50+ active Discord members)
- **Documentation Completeness**: Ensure user success (Target: 100% by launch)

## MVP Scope

### Core Features (Must Have)
- **Unified Docker Compose Configuration:** Single file deployment of all 12 components
- **Bootstrap Script:** Automated server preparation and dependency installation
- **Basic Documentation:** Installation guide and component configuration basics
- **Core Integration:** n8n + Evolution API + Chatwoot workflow
- **Backup System:** Automated backups to external storage
- **SSL/TLS Management:** Automatic certificate generation via Caddy

### Out of Scope for MVP
- Multi-tenant architecture
- Web-based management interface
- Pre-built workflow templates
- Advanced monitoring and alerting
- Mobile applications
- Enterprise support SLA
- Cloud marketplace deployments

### MVP Success Criteria
Successful MVP enables any technical user to deploy the complete stack on a clean Ubuntu VPS within 30 minutes, with WhatsApp automation, basic customer service, and workflow capabilities functional.


## Technical Considerations

### Platform Requirements
- **Target Platforms:** Ubuntu 24.04 LTS on any VPS provider
- **Browser/OS Support:** Modern web browsers for management interfaces
- **Performance Requirements:** Minimum 4 vCPUs, 8GB RAM, 80GB SSD
- **Network:** 100+ Mbps bandwidth, static IP, domain name

### Technology Preferences
- **Containerization:** Docker Compose v2 with official images
- **Databases:** PostgreSQL 16.x with pgvector extension
- **Caching:** Redis 7.4.x for session management and queues
- **Storage:** SeaweedFS for S3-compatible object storage
- **Proxy:** Caddy 2.8.x with automatic SSL
- **Automation:** n8n for workflow orchestration
- **Communication:** Evolution API (WhatsApp), Chatwoot (omnichannel)
- **Applications:** Lowcoder (app builder), Directus (headless CMS)
- **Processing:** FileFlows (media), Duplicati (backup)

### Architecture Considerations
- **Repository Structure:** Monorepo with docker-compose.yml as centerpiece
- **Service Architecture:** Microservices with shared PostgreSQL/Redis
- **Integration Requirements:** API-first, webhook-driven communication
- **Security/Compliance:** TLS 1.3, isolated networks, regular updates

## Constraints & Assumptions

### Constraints
- **Budget:** ~200 hours of development time across all phases
- **Timeline:** 6 weeks total for MVP (3 weeks development, 2 weeks documentation, 1 week testing)
- **Resources:** Single developer team, community support model
- **Technical:** Limited to officially maintained Docker images

### Key Assumptions
- Users have basic Linux and Docker knowledge
- Target VPS providers support Ubuntu 24.04 LTS
- Component APIs remain stable during development
- Community will provide support via GitHub/Discord
- Brazilian companies prioritize data sovereignty over convenience
- Professional services model will sustain the project

## Risks & Open Questions

### Key Risks
- **Maintenance Complexity:** High risk - 12 integrated components require ongoing updates
- **Component Version Conflicts:** Medium risk - breaking changes could cause system instability
- **Support Overhead:** High risk - free support expectations could overwhelm team
- **Market Adoption:** Medium risk - may not achieve critical mass in Brazilian market

### Open Questions
- What is the optimal pricing strategy for professional services?
- How to balance community support with paid services?
- Should we focus on specific verticals first?
- What level of testing is required for production readiness?
- How to handle component security updates systematically?

### Areas Needing Further Research
- Competitive landscape in Brazilian automation market
- Regulatory requirements for data processing in Brazil
- Optimal VPS providers and pricing for target market
- Community building strategies for open source projects
- Integration opportunities with popular Brazilian business systems

## Next Steps

### Immediate Actions
1. Finalize component versions and Docker image selection
2. Set up development environment and repository structure
3. Begin implementing unified Docker Compose configuration
4. Create bootstrap script for server preparation
5. Start building documentation structure

### PM Handoff
This Project Brief provides the full context for BorgStack. Please start in 'PRD Generation Mode', review the brief thoroughly to work with the user to create the PRD section by section as the template indicates, asking for any necessary clarification or suggesting improvements.

## Appendices

### A. Technology Stack Reference

| # | Tecnologia | Descrição | Versão | Docker Image Tag | GitHub Repository |
|---|------------|-------------|------------------|-------------------|-------------------|
| 1 | **PostgreSQL** | Banco de dados relacional com extensão vetorial | 18.0 | `pgvector/pgvector:pg18` | pgvector/pgvector |
| 2 | **pgvector** | Extensão para busca por similaridade de vetores | v0.8.1 | Incluído na imagem pgvector/pgvector | pgvector/pgvector |
| 3 | **MongoDB** | Banco de dados NoSQL para Lowcoder | 7.0 | `mongo:7.0` | mongodb/mongo |
| 4 | **Redis** | Cache em memória e filas de processamento | 8.2 | `redis:8.2-alpine` | redis/redis |
| 5 | **SeaweedFS** | Sistema de armazenamento S3-compatible | 3.97 | `chrislusf/seaweedfs:3.97` | seaweedfs/seaweedfs |
| 6 | **n8n** | Plataforma de automação de workflows | 1.112.6 | `n8nio/n8n:1.112.6` | n8n-io/n8n |
| 7 | **Evolution API** | API para integração com WhatsApp multi-instâncias | v2.2.3 | `atendai/evolution-api:v2.2.3` | EvolutionAPI/evolution-api |
| 8 | **Chatwoot** | Plataforma de atendimento omnichannel | v4.6.0-ce | `chatwoot/chatwoot:v4.6.0-ce` | chatwoot/chatwoot |
| 9 | **Lowcoder CE** | Construtor de aplicações low-code | 2.7.4 | `lowcoderorg/lowcoder-ce:2.7.4` | lowcoder-org/lowcoder |
| 10 | **Directus** | Headless CMS e gerenciador de conteúdo | 11 | `directus/directus:11` | directus/directus |
| 11 | **Caddy** | Proxy reverso com HTTPS automático | 2.10 | `caddy:2.10-alpine` | caddyserver/caddy |
| 12 | **FileFlows** | Processamento e conversão de mídia | 25.09 | `revenz/fileflows:25.09` | revenz/FileFlows |
| 13 | **Duplicati** | Sistema de backup automatizado | 2.1.1.102 | `duplicati/duplicati:2.1.1.102` | duplicati/duplicati |