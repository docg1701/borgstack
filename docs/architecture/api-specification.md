# API Specification

**Not Applicable - Infrastructure Project**

BorgStack does not define custom APIs. Each service exposes its own REST/GraphQL APIs as documented by the upstream projects:

| Service | API Type | Documentation |
|---------|----------|---------------|
| n8n | REST | https://docs.n8n.io/api/ |
| Evolution API | REST | https://doc.evolution-api.com/ |
| Chatwoot | REST | https://www.chatwoot.com/developers/api/ |
| Lowcoder | REST | https://docs.lowcoder.cloud/ |
| Directus | REST/GraphQL | https://docs.directus.io/reference/ |
| SeaweedFS | S3-compatible | https://github.com/seaweedfs/seaweedfs/wiki/Amazon-S3-API |
| FileFlows | REST | https://docs.fileflows.com/ |
| Duplicati | REST | https://duplicati.readthedocs.io/ |

**Integration Approach:**

Users configure integrations through **n8n workflows** using HTTP Request nodes and webhook triggers. No custom API gateway or BFF (Backend for Frontend) layer is required. Each service's API is accessed directly through its native endpoints.

---
