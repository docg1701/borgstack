# Backend Architecture

**Not Applicable - Pre-built Service Backends**

BorgStack deploys containerized applications with their own backend implementations:

| Service | Backend Technology | API Type |
|---------|-------------------|----------|
| n8n | Node.js + Express + TypeORM | REST |
| Chatwoot | Ruby on Rails + Sidekiq | REST |
| Evolution API | Node.js + Express + Prisma | REST |
| Lowcoder | Java Spring Boot + Node.js | REST |
| Directus | Node.js + Express + Knex | REST + GraphQL |
| FileFlows | .NET 8 + ASP.NET Core | REST |
| Duplicati | .NET + Nancy Framework | REST |

**No Custom Backend Development:**
- BorgStack does not include custom API development, business logic, or service layers
- Integration occurs through n8n workflows calling existing service APIs
- Each service manages its own data access, authentication, and business logic
- Configuration through environment variables, not code modifications

---
