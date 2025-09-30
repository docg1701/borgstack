# Data Models

**Not Applicable - Infrastructure Project**

BorgStack is an infrastructure deployment project that integrates pre-built Docker images of existing applications. There are no custom shared data models or TypeScript interfaces to define, as each service (n8n, Chatwoot, Evolution API, Directus, Lowcoder, FileFlows) maintains its own internal data models defined by those applications.

**Service-Specific Data Models:**
- **n8n**: Workflow definitions, credentials, execution logs (managed internally)
- **Chatwoot**: Conversations, contacts, agents, inboxes (PostgreSQL schema defined by Chatwoot)
- **Evolution API**: WhatsApp instances, messages, webhooks (PostgreSQL schema defined by Evolution API)
- **Directus**: User-defined collections and fields (dynamic schema)
- **Lowcoder**: Applications, queries, components (MongoDB schema defined by Lowcoder)
- **FileFlows**: Media processing flows, libraries, nodes (internal data model)

**Integration Data Exchange:**

Integration between services occurs via HTTP APIs and webhooks with JSON payloads. The data schemas are defined by each service's API documentation:

- **n8n → Evolution API**: WhatsApp message sending (JSON payloads per Evolution API docs)
- **Evolution API → n8n**: Webhook events for incoming messages
- **n8n → Chatwoot**: Contact creation, conversation management (Chatwoot API)
- **Directus → SeaweedFS**: S3-compatible file uploads (standard S3 API)
- **FileFlows → SeaweedFS**: Media file processing (S3 API)

**Integration Payload Examples:**

**1. Evolution API → n8n: Incoming WhatsApp Message Webhook**

```json
POST https://n8n.example.com.br/webhook/whatsapp-incoming
Content-Type: application/json

{
  "event": "messages.upsert",
  "instance": "customer_support",
  "data": {
    "key": {
      "remoteJid": "5511987654321@s.whatsapp.net",
      "fromMe": false,
      "id": "3EB0C8F3E7E3A7D8C0F1"
    },
    "message": {
      "conversation": "Olá, preciso de ajuda com meu pedido #12345"
    },
    "messageTimestamp": 1735632000,
    "pushName": "João Silva",
    "messageType": "conversation",
    "owner": "5511999887766@s.whatsapp.net"
  },
  "destination": "https://n8n.example.com.br/webhook/whatsapp-incoming",
  "date_time": "2025-01-01T12:00:00.000Z",
  "server_url": "https://evolution.example.com.br",
  "apikey": "${EVOLUTION_API_KEY}"
}
```

**2. n8n → Chatwoot: Create Contact**

```json
POST https://chatwoot.example.com.br/api/v1/accounts/1/contacts
Authorization: Bearer ${CHATWOOT_API_TOKEN}
Content-Type: application/json

{
  "inbox_id": 1,
  "name": "João Silva",
  "phone_number": "+5511987654321",
  "identifier": "whatsapp:5511987654321",
  "custom_attributes": {
    "whatsapp_id": "5511987654321@s.whatsapp.net",
    "evolution_instance": "customer_support",
    "source": "whatsapp_evolution_api",
    "last_seen": "2025-01-01T12:00:00.000Z"
  }
}
```

**Response:**

```json
{
  "id": 42,
  "name": "João Silva",
  "phone_number": "+5511987654321",
  "identifier": "whatsapp:5511987654321",
  "email": null,
  "custom_attributes": {
    "whatsapp_id": "5511987654321@s.whatsapp.net",
    "evolution_instance": "customer_support",
    "source": "whatsapp_evolution_api"
  },
  "created_at": "2025-01-01T12:00:01.000Z"
}
```

**3. n8n → Chatwoot: Create Conversation**

```json
POST https://chatwoot.example.com.br/api/v1/accounts/1/conversations
Authorization: Bearer ${CHATWOOT_API_TOKEN}
Content-Type: application/json

{
  "source_id": "evolution_msg_3EB0C8F3E7E3A7D8C0F1",
  "inbox_id": 1,
  "contact_id": 42,
  "status": "open",
  "custom_attributes": {
    "whatsapp_instance": "customer_support",
    "initial_message_id": "3EB0C8F3E7E3A7D8C0F1"
  }
}
```

**Response:**

```json
{
  "id": 1523,
  "account_id": 1,
  "inbox_id": 1,
  "status": "open",
  "contact_id": 42,
  "display_id": 1523,
  "messages": [],
  "created_at": "2025-01-01T12:00:02.000Z"
}
```

**4. n8n → Chatwoot: Add Message to Conversation**

```json
POST https://chatwoot.example.com.br/api/v1/accounts/1/conversations/1523/messages
Authorization: Bearer ${CHATWOOT_API_TOKEN}
Content-Type: application/json

{
  "content": "Olá, preciso de ajuda com meu pedido #12345",
  "message_type": "incoming",
  "private": false,
  "source_id": "3EB0C8F3E7E3A7D8C0F1",
  "content_attributes": {
    "whatsapp_message_type": "conversation",
    "received_at": "2025-01-01T12:00:00.000Z"
  }
}
```

**Response:**

```json
{
  "id": 98234,
  "content": "Olá, preciso de ajuda com meu pedido #12345",
  "conversation_id": 1523,
  "message_type": "incoming",
  "created_at": "2025-01-01T12:00:03.000Z",
  "sender": {
    "id": 42,
    "name": "João Silva",
    "type": "contact"
  }
}
```

**5. Chatwoot → n8n: Outgoing Message Webhook (Agent Reply)**

```json
POST https://n8n.example.com.br/webhook/chatwoot-message-created
Content-Type: application/json

{
  "event": "message_created",
  "id": 98235,
  "content": "Olá João! Vou verificar o status do pedido #12345 para você.",
  "created_at": "2025-01-01T12:02:00.000Z",
  "message_type": "outgoing",
  "content_type": "text",
  "private": false,
  "conversation": {
    "id": 1523,
    "inbox_id": 1,
    "status": "open"
  },
  "sender": {
    "id": 5,
    "name": "Maria Atendente",
    "type": "agent"
  },
  "contact": {
    "id": 42,
    "name": "João Silva",
    "phone_number": "+5511987654321"
  },
  "account": {
    "id": 1,
    "name": "BorgStack Support"
  }
}
```

**6. n8n → Evolution API: Send WhatsApp Text Message**

```json
POST https://evolution.example.com.br/message/sendText/customer_support
apikey: ${EVOLUTION_API_KEY}
Content-Type: application/json

{
  "number": "5511987654321",
  "text": "Olá João! Vou verificar o status do pedido #12345 para você.",
  "delay": 1000
}
```

**Response:**

```json
{
  "key": {
    "remoteJid": "5511987654321@s.whatsapp.net",
    "fromMe": true,
    "id": "BAE5F8D3C2A1B0E9F7D6"
  },
  "message": {
    "conversation": "Olá João! Vou verificar o status do pedido #12345 para você."
  },
  "messageTimestamp": 1735632120,
  "status": "PENDING"
}
```

**7. Evolution API → n8n: Message Status Update Webhook**

```json
POST https://n8n.example.com.br/webhook/whatsapp-status
Content-Type: application/json

{
  "event": "messages.update",
  "instance": "customer_support",
  "data": {
    "key": {
      "remoteJid": "5511987654321@s.whatsapp.net",
      "fromMe": true,
      "id": "BAE5F8D3C2A1B0E9F7D6"
    },
    "status": "READ",
    "messageTimestamp": 1735632150
  }
}
```

**Payload Size Considerations:**

- Typical incoming WhatsApp message webhook: 0.5-2 KB
- Chatwoot conversation creation: 0.3-1 KB
- Media messages (images/videos): 2-10 KB (metadata only, actual media stored in SeaweedFS)
- Webhook retry payloads: Identical to original, cached in Redis for 24 hours
- n8n workflow execution data: Average 5-15 KB per execution, pruned after 336 hours (14 days)

There is no shared TypeScript interface package, as this is a Docker Compose infrastructure stack, not a monorepo application with shared code.

---
