# Frontend Architecture

**Not Applicable - Pre-built Service UIs**

BorgStack is an infrastructure deployment project. Each service provides its own frontend interface that is maintained by the upstream project:

| Service | Frontend Technology | Access |
|---------|-------------------|--------|
| n8n | Vue.js 3 | https://n8n.{domain} |
| Chatwoot | Ruby on Rails + Vue.js | https://chatwoot.{domain} |
| Evolution API | Swagger UI (API docs) | https://evolution.{domain} |
| Lowcoder | React | https://lowcoder.{domain} |
| Directus | Vue.js 3 | https://directus.{domain} |
| FileFlows | Blazor WebAssembly | https://fileflows.{domain} |
| Duplicati | Angular | https://duplicati.{domain} |

**No Custom Frontend Development:**
- BorgStack does not include custom UI components, dashboards, or unified interfaces
- Users access each service directly through its native web interface
- Each service handles its own authentication, routing, and state management
- Portuguese language support configured per service (where available)

---
