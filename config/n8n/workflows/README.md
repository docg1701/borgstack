# n8n Example Workflows

This directory contains example workflow templates to help you get started with n8n automation.

## Available Workflows

### 01-webhook-test.json
**Purpose:** Simple webhook receiver that accepts POST requests and returns a JSON response

**Features:**
- Accepts POST requests at `/webhook/test` endpoint
- Returns JSON response with success status and timestamp
- Echoes back received data
- Great for testing webhook connectivity

**Test Command:**
```bash
curl -X POST https://n8n.${DOMAIN}/webhook/test \
  -H "Content-Type: application/json" \
  -d '{"test": "data", "message": "Hello n8n"}'
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Webhook received successfully",
  "timestamp": "2025-10-02T12:00:00.000Z",
  "data": {
    "test": "data",
    "message": "Hello n8n"
  }
}
```

### 02-schedule-test.json
**Purpose:** Scheduled workflow that runs every hour and logs a timestamp

**Features:**
- Triggers automatically every 1 hour
- Generates current timestamp
- Logs execution to n8n console
- Demonstrates cron-based automation

**Use Cases:**
- Periodic data synchronization
- Scheduled reports
- Maintenance tasks
- Health checks

### 03-whatsapp-evolution-incoming.json
**Purpose:** Receives incoming WhatsApp messages from Evolution API via webhook

**Features:**
- Webhook trigger at `/webhook/whatsapp-incoming` endpoint
- Processes Evolution API message payloads
- Extracts sender phone number, message text, and metadata
- Filters incoming messages (ignores messages sent by you - `fromMe: true`)
- Returns success response to Evolution API

**Workflow Nodes:**
1. **Evolution Webhook** - Receives POST requests from Evolution API
2. **Process Message** - Extracts WhatsApp message data (phone, text, sender name)
3. **Filter Incoming Messages** - Only processes messages FROM contacts (not your sent messages)
4. **Respond to Webhook** - Sends 200 OK response back to Evolution API

**Message Format (Evolution API):**
```json
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
    "pushName": "João Silva"
  }
}
```

**Workflow Output:**
```json
{
  "event": "messages.upsert",
  "instance": "customer_support",
  "remoteJid": "5511987654321@s.whatsapp.net",
  "phoneNumber": "5511987654321",
  "messageText": "Olá, preciso de ajuda com meu pedido #12345",
  "messageId": "3EB0C8F3E7E3A7D8C0F1",
  "timestamp": 1735632000,
  "senderName": "João Silva",
  "fromMe": false
}
```

**Integration with Evolution API:**
1. Evolution API sends incoming WhatsApp messages to this webhook
2. Configure webhook in Evolution API: `EVOLUTION_WEBHOOK_URL=https://n8n.${DOMAIN}/webhook/whatsapp-incoming`
3. Webhook is automatically configured during bootstrap (Story 1.6)
4. Evolution API instance creation sets webhook URL (Story 2.2)

**Next Steps (Extend This Workflow):**
- Connect to Chatwoot (Story 3.1): Create conversations for incoming messages
- Add keyword-based routing: "support" → Chatwoot, "status" → Database query
- Implement auto-reply logic: Send automated responses via Evolution API
- Add CRM integration: Store message history in Directus
- Create ticket tracking: Log customer requests in database

**Documentation:**
- Evolution API setup: `config/evolution/README.md`
- Evolution API webhook configuration: See Story 2.2 documentation
- Message sending via Evolution API: See `config/evolution/README.md` → "Message Sending/Receiving Test"

**Test Webhook:**
```bash
# Test webhook manually (simulate Evolution API message)
curl -X POST https://n8n.${DOMAIN}/webhook/whatsapp-incoming \
  -H "Content-Type: application/json" \
  -d '{
    "event": "messages.upsert",
    "instance": "customer_support",
    "data": {
      "key": {
        "remoteJid": "5511987654321@s.whatsapp.net",
        "fromMe": false,
        "id": "TEST123"
      },
      "message": {
        "conversation": "Test message from n8n workflow verification"
      },
      "messageTimestamp": 1735632000,
      "pushName": "Test User"
    }
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "received": "TEST123",
  "instance": "customer_support"
}
```

## How to Import Workflows

### Method 1: Via n8n Web UI (Recommended)

1. Access n8n web interface:
   ```
   https://n8n.${DOMAIN}
   ```

2. Log in with your credentials (from `.env` file):
   - Username: Value of `N8N_BASIC_AUTH_USER` (default: `admin`)
   - Password: Value of `N8N_BASIC_AUTH_PASSWORD`

3. Import workflow:
   - Click **"Add workflow"** button (top right)
   - Click **"Import from file"**
   - Select the workflow JSON file (e.g., `01-webhook-test.json`)
   - Click **"Import"**

4. Activate the workflow:
   - Click the **"Inactive"** toggle in the top right
   - The workflow is now **"Active"** and ready to use

### Method 2: Via n8n CLI (Advanced)

If you have shell access to the n8n container:

```bash
# Copy workflow file to n8n container
docker compose cp config/n8n/workflows/01-webhook-test.json n8n:/tmp/

# Import via n8n CLI (inside container)
docker compose exec n8n n8n import:workflow --input=/tmp/01-webhook-test.json
```

### Method 3: Via API (Automation)

Use n8n REST API to import workflows programmatically:

```bash
# Get n8n API key from Web UI: Settings → API Keys

# Import workflow via API
curl -X POST https://n8n.${DOMAIN}/api/v1/workflows \
  -H "X-N8N-API-KEY: your-api-key" \
  -H "Content-Type: application/json" \
  -d @config/n8n/workflows/01-webhook-test.json
```

## Workflow Customization

### Webhook Workflow Customization

Edit `01-webhook-test.json` to:
- Change webhook path (default: `/webhook/test`)
- Modify response format
- Add data validation
- Connect to other services (databases, APIs)

### Schedule Workflow Customization

Edit `02-schedule-test.json` to:
- Change schedule interval (default: 1 hour)
- Use cron expressions for complex schedules
- Add service integrations (databases, APIs, notifications)
- Process data from external sources

## Webhook URL Format

All webhook workflows are accessible at:

```
https://n8n.${DOMAIN}/webhook/{workflow-path}
```

Examples:
- `https://n8n.example.com.br/webhook/test`
- `https://n8n.example.com.br/webhook/evolution-incoming`
- `https://n8n.example.com.br/webhook/chatwoot-event`

## Troubleshooting

### Webhook Not Responding

1. Verify workflow is **Active** (toggle in top right)
2. Check webhook path in workflow settings
3. Verify DNS is configured: `dig n8n.${DOMAIN}`
4. Check Caddy logs: `docker compose logs caddy`
5. Check n8n logs: `docker compose logs n8n`

### Schedule Not Triggering

1. Verify workflow is **Active**
2. Check schedule configuration (interval or cron expression)
3. Verify timezone setting in docker-compose.yml: `GENERIC_TIMEZONE=America/Sao_Paulo`
4. Check execution history in n8n UI: **Executions** tab

### Import Fails

1. Verify JSON syntax is valid: `jq . workflow.json`
2. Check n8n version compatibility (workflows created for v1.112.6)
3. Ensure file encoding is UTF-8
4. Check n8n logs for detailed error: `docker compose logs n8n`

## Next Steps

After importing example workflows:

1. **Explore n8n Nodes**: Browse 400+ integrations in the n8n node library
2. **Create Custom Workflows**: Build workflows for your specific use cases
3. **Connect Services**: Integrate with Evolution API, Chatwoot, Directus, etc.
4. **Set Up Credentials**: Add API keys and authentication for external services
5. **Monitor Executions**: Use the Executions panel to debug and optimize workflows

## Resources

- **n8n Documentation**: https://docs.n8n.io
- **n8n Community**: https://community.n8n.io
- **Workflow Templates**: https://n8n.io/workflows
- **BorgStack Docs**: ../../../docs/03-services/n8n.md
