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

### 04-whatsapp-chatwoot-integration.json
**Purpose:** Complete WhatsApp → Chatwoot integration workflow for customer service automation

**Features:**
- Receives incoming WhatsApp messages from Evolution API webhook
- Automatically finds or creates Chatwoot contacts (by phone number)
- Finds existing open conversation or creates new one
- Posts WhatsApp message content to Chatwoot conversation
- Handles multiple message types (text, image, video, audio, documents)
- Returns detailed success response to Evolution API

**Workflow Nodes:**
1. **Evolution Webhook** - Receives POST requests at `/webhook/whatsapp-incoming`
2. **Extract WhatsApp Data** - Parses Evolution API payload (phone, message, sender name)
3. **Find Chatwoot Contact** - Searches for existing contact by phone number (API: GET /contacts/search)
4. **Contact Exists?** - Conditional branch: use existing or create new contact
5. **Create Chatwoot Contact** - Creates new contact if not found (API: POST /contacts)
6. **Use Existing Contact** - Extracts contact ID from search results
7. **Find Open Conversation** - Searches for existing open conversation (API: POST /conversations/filter)
8. **Open Conversation Exists?** - Conditional branch: use existing or create new conversation
9. **Create Conversation** - Creates new conversation in Chatwoot inbox (API: POST /conversations)
10. **Use Existing Conversation** - Extracts conversation ID from search results
11. **Post Message to Chatwoot** - Adds incoming message to conversation (API: POST /conversations/{id}/messages)
12. **Webhook Response** - Returns success response to Evolution API

**Prerequisites:**
- ✅ Evolution API deployed and configured (Story 2.2)
- ✅ Chatwoot deployed with API token generated (Story 3.1)
- ✅ CHATWOOT_API_TOKEN configured in .env file
- ✅ WhatsApp instance connected to Evolution API
- ✅ WhatsApp Inbox created in Chatwoot (Inbox ID: 1)

**CRITICAL Setup Step - API Token:**

The workflow requires a Chatwoot API token. This **MUST be manually generated** from the Chatwoot admin UI:

1. Login to Chatwoot: `https://chatwoot.${DOMAIN}/app`
2. Go to **Settings → Account Settings → Access Tokens**
3. Click **"Add New Token"**
4. Name: `n8n Integration`
5. **Copy token immediately** (shown only once)
6. Add to .env file: `CHATWOOT_API_TOKEN=<your-token>`
7. Restart Chatwoot: `docker compose restart chatwoot`

**Configure n8n Credential:**

1. In n8n UI: Go to **Credentials → New Credential**
2. Select **"HTTP Header Auth"** credential type
3. **Name:** `Chatwoot API Token`
4. **Header Name:** `api_access_token`
5. **Header Value:** Paste your `CHATWOOT_API_TOKEN` value
6. Click **"Create"**
7. The workflow will automatically use this credential for all Chatwoot API calls

**Supported Message Types:**

The workflow handles all common WhatsApp message types:

| Message Type | Chatwoot Display | Evolution API Field |
|--------------|------------------|---------------------|
| Simple Text | Plain text | `message.conversation` |
| Extended Text | Plain text (with mentions/links) | `message.extendedTextMessage.text` |
| Image with Caption | `[Image] Caption text` | `message.imageMessage.caption` |
| Video with Caption | `[Video] Caption text` | `message.videoMessage.caption` |
| Voice Message | `[Voice Message]` | `message.audioMessage` |
| Document | `[Document: filename.pdf]` | `message.documentMessage.fileName` |
| Unsupported | `[Unsupported message type]` | N/A |

**Integration Flow:**

```
┌─────────────┐   Webhook   ┌──────────────┐   API Call   ┌─────────────┐
│  WhatsApp   │─────────────>│ Evolution    │─────────────>│   n8n       │
│  Customer   │              │     API      │              │  Workflow   │
│             │   Message    │              │   Payload    │             │
└─────────────┘              └──────────────┘              └──────┬──────┘
                                                                  │
                                                                  │ API Calls
                                                                  │
                                                                  v
                                                           ┌─────────────┐
                                                           │  Chatwoot   │
                                                           │     API     │
                                                           │             │
                                                           │ • Contact   │
                                                           │ • Convo     │
                                                           │ • Message   │
                                                           └─────────────┘
```

**Workflow Logic:**

1. **Contact Management:**
   - Search for contact by phone number
   - If found: Use existing contact ID
   - If not found: Create new contact with name and phone

2. **Conversation Management:**
   - Search for open conversation with source_id (WhatsApp remoteJid)
   - If found: Use existing conversation ID (continue conversation)
   - If not found: Create new conversation (fresh support request)

3. **Message Handling:**
   - Post message to conversation as `message_type: incoming`
   - Message appears in Chatwoot agent dashboard instantly
   - Agent can reply via Chatwoot UI (see outgoing workflow below)

**Chatwoot API Endpoints Used:**

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/accounts/1/contacts/search?q={phone}` | GET | Find existing contact by phone number |
| `/api/v1/accounts/1/contacts` | POST | Create new contact |
| `/api/v1/accounts/1/conversations/filter` | POST | Search for open conversations |
| `/api/v1/accounts/1/conversations` | POST | Create new conversation |
| `/api/v1/accounts/1/conversations/{id}/messages` | POST | Add message to conversation |

**Environment Variables Used:**

| Variable | Usage | Example |
|----------|-------|---------|
| `CHATWOOT_HOST` | Chatwoot API base URL | `chatwoot.example.com.br` |
| `CHATWOOT_API_TOKEN` | API authentication token | Stored in n8n credential |

**Testing the Workflow:**

1. **Activate workflow in n8n UI:**
   - Import workflow → Toggle "Inactive" to "Active"

2. **Send test WhatsApp message:**
   - Send message from your phone to Evolution API connected number
   - Message should appear in Chatwoot within 2-5 seconds

3. **Verify in Chatwoot:**
   - Login to Chatwoot: `https://chatwoot.${DOMAIN}/app`
   - Go to **Conversations**
   - New conversation should appear with WhatsApp message

4. **Check n8n execution logs:**
   - n8n UI → **Executions** tab
   - Click latest execution to see node-by-node results
   - Verify no errors in API calls

**Troubleshooting:**

| Problem | Solution |
|---------|----------|
| Webhook not triggered | Verify Evolution API `EVOLUTION_WEBHOOK_URL` points to n8n |
| Contact not created | Check `CHATWOOT_API_TOKEN` is valid (test with curl) |
| Conversation not created | Verify Inbox ID is correct (check Chatwoot Settings → Inboxes) |
| Message not posted | Check conversation ID is valid and conversation is open |
| 401 Unauthorized | Regenerate `CHATWOOT_API_TOKEN` and update n8n credential |

**Next Steps:**

After setting up incoming messages, configure **outgoing messages** (agent replies):

1. **Chatwoot → WhatsApp** (Agent replies to customer):
   - Create Chatwoot webhook: Settings → Integrations → Webhooks
   - Webhook URL: `https://n8n.${DOMAIN}/webhook/chatwoot-outgoing`
   - Events: `message_created`
   - Create n8n workflow to POST replies to Evolution API

2. **Extend functionality:**
   - Add keyword-based auto-replies (e.g., "hello" → "Welcome! How can I help?")
   - Implement business hours auto-responder
   - Add conversation tagging based on message content
   - Store message history in Directus for analytics

**Documentation References:**

- Evolution API setup: `config/evolution/README.md`
- Chatwoot setup: `config/chatwoot/README.md`
- Chatwoot API: https://www.chatwoot.com/developers/api/

**Test Command (Manual Webhook Call):**

```bash
# Simulate Evolution API message (for testing)
curl -X POST https://n8n.${DOMAIN}/webhook/whatsapp-incoming \
  -H "Content-Type: application/json" \
  -d '{
    "event": "messages.upsert",
    "instance": "customer_support",
    "data": {
      "key": {
        "remoteJid": "5511987654321@s.whatsapp.net",
        "fromMe": false,
        "id": "TEST456"
      },
      "message": {
        "conversation": "Olá, preciso de suporte urgente!"
      },
      "messageTimestamp": 1735632000,
      "pushName": "Maria Santos"
    }
  }'
```

**Expected Response:**

```json
{
  "success": true,
  "message": "WhatsApp message delivered to Chatwoot",
  "contact_id": 42,
  "conversation_id": 123,
  "message_id": 789
}
```

### 05-lowcoder-webhook-integration.json
**Purpose:** Receives webhook calls from Lowcoder applications and processes different action types

**Features:**
- Webhook trigger at `/webhook/lowcoder-trigger` endpoint
- Validates payload structure (requires `action` field)
- Processes multiple action types (create_record, send_notification, trigger_workflow)
- Returns structured JSON response to Lowcoder application
- Error handling for invalid payloads (400 Bad Request)

**Workflow Nodes:**
1. **Lowcoder Webhook Trigger** - Receives POST requests from Lowcoder apps
2. **Validate Payload** - Checks for required `action` field
3. **Process Action** - Handles different action types with custom logic
4. **Success Response** - Returns processed result to Lowcoder
5. **Error Response** - Returns error for invalid requests

**Supported Actions:**

| Action | Description | Response |
|--------|-------------|----------|
| `create_record` | Initiates record creation | Returns generated record ID |
| `send_notification` | Queues notification for delivery | Returns notification ID |
| `trigger_workflow` | Starts workflow execution | Returns workflow ID |
| Custom | Any custom action type | Returns success message |

**Request Format (from Lowcoder):**

```json
{
  "action": "create_record",
  "data": {
    "name": "John Doe",
    "email": "john@example.com",
    "department": "Sales"
  }
}
```

**Response Format:**

```json
{
  "success": true,
  "action": "create_record",
  "processedAt": "2025-10-03T22:30:00.000Z",
  "message": "Record creation initiated",
  "recordId": "REC-1735938600000",
  "originalData": {
    "name": "John Doe",
    "email": "john@example.com",
    "department": "Sales"
  }
}
```

**Error Response (Missing Action):**

```json
{
  "success": false,
  "error": "Missing 'action' field in request body",
  "timestamp": "2025-10-03T22:30:00.000Z"
}
```

**Integration with Lowcoder:**

1. **Create REST API Data Source in Lowcoder:**
   - Name: `n8n_webhooks`
   - Base URL: `https://n8n.${DOMAIN}/webhook`
   - No authentication required (internal network)

2. **Create Query in Lowcoder Application:**
   ```javascript
   // Query configuration
   Method: POST
   URL: /lowcoder-trigger
   Body: {
     "action": "create_record",
     "data": {
       "name": {{ textInput1.value }},
       "email": {{ textInput2.value }},
       "department": {{ dropdown1.value }}
     }
   }
   ```

3. **Trigger Query from Button Click:**
   - Add Button component to Lowcoder app
   - Button onClick event: Run query `webhook_trigger`
   - Display response in Table or Text component

**Use Cases:**

1. **Form Submission Handler:**
   - Lowcoder form collects user data
   - Button triggers n8n workflow via webhook
   - n8n validates data and stores in database

2. **Workflow Orchestration:**
   - Lowcoder dashboard button starts complex workflow
   - n8n executes multi-step automation
   - Returns execution status to Lowcoder

3. **Notification System:**
   - Lowcoder app triggers notification send
   - n8n handles delivery via email/SMS/WhatsApp
   - Returns tracking ID to Lowcoder app

**Customization:**

Edit `05-lowcoder-webhook-integration.json` to:
- Add new action types in `Process Action` node
- Integrate with databases (PostgreSQL, MongoDB)
- Send emails, SMS, or WhatsApp messages
- Call external APIs (Evolution API, Chatwoot, etc.)
- Store workflow execution logs in Directus

**Test Command:**

```bash
# Test from command line
curl -X POST https://n8n.${DOMAIN}/webhook/lowcoder-trigger \
  -H "Content-Type: application/json" \
  -d '{
    "action": "create_record",
    "data": {
      "name": "Test User",
      "email": "test@example.com"
    }
  }'
```

**Test Invalid Payload:**

```bash
# Missing 'action' field - should return 400 error
curl -X POST https://n8n.${DOMAIN}/webhook/lowcoder-trigger \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "name": "Test User"
    }
  }'
```

**Documentation References:**

- Lowcoder setup: `config/lowcoder/README.md`
- Lowcoder API integration guide: Lowcoder → Data Sources → REST API
- n8n webhook documentation: https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.webhook/

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

## Lowcoder Integration Patterns

### Pattern 1: Lowcoder → n8n Webhook Trigger

**Use Case**: Trigger n8n workflows from Lowcoder applications (button clicks, form submissions)

**Setup in Lowcoder:**

1. **Create REST API Datasource:**
   - Name: `n8n_webhooks`
   - Base URL: `https://n8n.${DOMAIN}/webhook`
   - Authentication: None (internal network)

2. **Create Query:**
   ```javascript
   // Query Name: trigger_workflow
   Method: POST
   URL: /lowcoder-trigger
   Body: {
     "action": "{{ actionSelect.value }}",
     "data": {
       "customer_id": {{ customerTable.selectedRow.id }},
       "message": {{ messageInput.value }}
     }
   }
   ```

3. **Add Button to Trigger:**
   - Button text: "Execute Workflow"
   - onClick event: Run query `trigger_workflow`
   - Success callback: Display `{{ trigger_workflow.data }}`

**n8n Workflow Example:**

See `05-lowcoder-webhook-integration.json` for webhook receiver template.

---

### Pattern 2: Lowcoder → Evolution API (Send WhatsApp)

**Use Case**: Send WhatsApp messages from Lowcoder applications via Evolution API

**Option A: Direct REST API Call to Evolution API**

1. **Create REST API Datasource in Lowcoder:**
   - Name: `evolution_api`
   - Base URL: `https://evolution.${DOMAIN}`
   - Headers:
     - `apikey`: `${EVOLUTION_API_KEY}` (from .env)
     - `Content-Type`: `application/json`

2. **Create Query (Send WhatsApp Text):**
   ```javascript
   // Query Name: send_whatsapp_message
   Method: POST
   URL: /message/sendText/{{ instanceName.value }}
   Body: {
     "number": {{ phoneNumberInput.value }},
     "text": {{ messageTextArea.value }}
   }
   ```

3. **Add UI Components:**
   - Input: `instanceName` (e.g., "customer_support")
   - Input: `phoneNumberInput` (e.g., "5511987654321")
   - TextArea: `messageTextArea`
   - Button: "Send WhatsApp" → onClick: Run query `send_whatsapp_message`

**Option B: Via n8n Workflow (Recommended for Complex Logic)**

1. **Create n8n Workflow:**
   - Webhook trigger: `/webhook/send-whatsapp`
   - HTTP Request node: POST to Evolution API `/message/sendText/{instance}`
   - Error handling and logging

2. **Lowcoder Query:**
   ```javascript
   Method: POST
   URL: https://n8n.${DOMAIN}/webhook/send-whatsapp
   Body: {
     "instance": {{ instanceSelect.value }},
     "phone": {{ phoneInput.value }},
     "message": {{ messageText.value }}
   }
   ```

**Evolution API Endpoints:**

| Endpoint | Method | Purpose | Response |
|----------|--------|---------|----------|
| `/message/sendText/{instance}` | POST | Send text message | `{ key: {...}, message: {...} }` |
| `/message/sendMedia/{instance}` | POST | Send image/video | `{ key: {...}, message: {...} }` |
| `/instance/fetchInstances` | GET | List WhatsApp instances | `[{ instance: "name", ... }]` |

**Request Body (sendText):**

```json
{
  "number": "5511987654321",
  "text": "Hello from Lowcoder application!"
}
```

**Response:**

```json
{
  "key": {
    "remoteJid": "5511987654321@s.whatsapp.net",
    "fromMe": true,
    "id": "3EB0C8F3E7E3A7D8C0F1"
  },
  "message": {
    "conversation": "Hello from Lowcoder application!"
  },
  "messageTimestamp": 1735632000
}
```

**Example Use Cases:**

- **Customer Notification System**: Select customer from table → Send WhatsApp notification
- **Bulk Messaging**: Upload CSV with phone numbers → Loop and send via n8n workflow
- **Order Confirmation**: After order creation → Trigger WhatsApp confirmation message

---

### Pattern 3: Lowcoder → Chatwoot API (Create Contacts/Conversations)

**Use Case**: Create Chatwoot contacts and conversations from Lowcoder applications

**Setup in Lowcoder:**

1. **Create REST API Datasource:**
   - Name: `chatwoot_api`
   - Base URL: `https://chatwoot.${DOMAIN}/api/v1`
   - Headers:
     - `api_access_token`: `${CHATWOOT_API_TOKEN}` (from .env)
     - `Content-Type`: `application/json`

2. **Create Contact Query:**
   ```javascript
   // Query Name: create_chatwoot_contact
   Method: POST
   URL: /accounts/1/contacts
   Body: {
     "name": {{ customerNameInput.value }},
     "email": {{ customerEmailInput.value }},
     "phone_number": {{ customerPhoneInput.value }},
     "custom_attributes": {
       "source": "Lowcoder App",
       "created_by": {{ currentUser.email }}
     }
   }
   ```

3. **Create Conversation Query:**
   ```javascript
   // Query Name: create_chatwoot_conversation
   Method: POST
   URL: /accounts/1/conversations
   Body: {
     "contact_id": {{ create_chatwoot_contact.data.payload.contact.id }},
     "inbox_id": 1,
     "status": "open",
     "message": {
       "content": {{ initialMessageText.value }},
       "message_type": "incoming"
     }
   }
   ```

4. **Add Form Components:**
   - Input: `customerNameInput`
   - Input: `customerEmailInput`
   - Input: `customerPhoneInput`
   - TextArea: `initialMessageText`
   - Button: "Create Contact & Conversation" → Sequential queries:
     1. Run `create_chatwoot_contact`
     2. On success, run `create_chatwoot_conversation`

**Chatwoot API Endpoints:**

| Endpoint | Method | Purpose | Response |
|----------|--------|---------|----------|
| `/accounts/1/contacts` | POST | Create new contact | `{ payload: { contact: { id, name, ... } } }` |
| `/accounts/1/contacts/search?q={query}` | GET | Search existing contacts | `{ payload: [{ id, name, ... }] }` |
| `/accounts/1/conversations` | POST | Create new conversation | `{ id, status, inbox_id, ... }` |
| `/accounts/1/conversations/{id}/messages` | POST | Add message to conversation | `{ id, content, sender, ... }` |

**Create Contact Request:**

```json
{
  "name": "João Silva",
  "email": "joao@example.com",
  "phone_number": "+5511987654321",
  "custom_attributes": {
    "source": "Lowcoder CRM",
    "vip_customer": true
  }
}
```

**Create Conversation Request:**

```json
{
  "contact_id": 42,
  "inbox_id": 1,
  "status": "open",
  "message": {
    "content": "Customer inquiry from Lowcoder app: Need help with order #12345",
    "message_type": "incoming"
  }
}
```

**Example Use Cases:**

- **CRM Integration**: Create Chatwoot contact when new lead is added in Lowcoder CRM
- **Support Ticket Creation**: Form submission → Creates Chatwoot conversation
- **Contact Import**: Upload CSV → Bulk create contacts via n8n workflow

**Advanced Pattern: Via n8n Workflow**

For complex logic (validation, duplicate check, multi-step):

1. **Create n8n Workflow:**
   - Webhook: `/webhook/chatwoot-contact-manager`
   - Search existing contact (avoid duplicates)
   - Create or update contact
   - Create conversation
   - Return contact and conversation IDs

2. **Lowcoder Query:**
   ```javascript
   Method: POST
   URL: https://n8n.${DOMAIN}/webhook/chatwoot-contact-manager
   Body: {
     "action": "create_or_update",
     "contact": {
       "name": {{ nameInput.value }},
       "email": {{ emailInput.value }},
       "phone": {{ phoneInput.value }}
     },
     "conversation": {
       "inbox_id": 1,
       "initial_message": {{ messageText.value }}
     }
   }
   ```

---

### Pattern 4: n8n Workflow Triggered by Lowcoder Form Submission

**Use Case**: Complex multi-step automation triggered by Lowcoder form

**Example: Order Processing Workflow**

**Lowcoder Form:**
- Customer details (name, email, phone)
- Order items (table component)
- Delivery address (text inputs)
- Submit button

**n8n Workflow Steps:**

1. **Webhook Trigger** (`/webhook/process-order`)
   - Receives order data from Lowcoder

2. **Validate Order Data**
   - Check required fields
   - Validate email format
   - Verify phone number

3. **Create Chatwoot Contact**
   - Search for existing contact
   - Create if not found

4. **Store Order in Database**
   - PostgreSQL INSERT query
   - Store order details in custom table

5. **Send WhatsApp Confirmation**
   - Evolution API: Send order confirmation via WhatsApp

6. **Create Chatwoot Conversation**
   - Create conversation for order tracking
   - Link to contact created in step 3

7. **Send Email Notification**
   - Email node: Send confirmation email

8. **Return Response to Lowcoder**
   - Success: Return order ID and tracking info
   - Error: Return validation errors

**Lowcoder Query:**

```javascript
// Query Name: submit_order
Method: POST
URL: https://n8n.${DOMAIN}/webhook/process-order
Body: {
  "customer": {
    "name": {{ customerNameInput.value }},
    "email": {{ customerEmailInput.value }},
    "phone": {{ customerPhoneInput.value }}
  },
  "order_items": {{ orderItemsTable.data }},
  "delivery_address": {
    "street": {{ streetInput.value }},
    "city": {{ cityInput.value }},
    "state": {{ stateSelect.value }},
    "zip": {{ zipInput.value }}
  },
  "total_amount": {{ orderSummary.totalAmount }}
}
```

**n8n Response:**

```json
{
  "success": true,
  "order_id": "ORD-1735938600000",
  "contact_id": 42,
  "conversation_id": 123,
  "tracking_number": "BR123456789",
  "estimated_delivery": "2025-10-10",
  "whatsapp_sent": true,
  "email_sent": true
}
```

**Lowcoder Success Handler:**

```javascript
// Display success message
{{ `Order ${submit_order.data.order_id} created successfully! Tracking: ${submit_order.data.tracking_number}` }}

// Show in modal or notification
showSuccessModal({
  title: "Order Confirmed",
  message: `Your order has been confirmed. Tracking number: ${submit_order.data.tracking_number}`,
  orderId: submit_order.data.order_id
})
```

---

### Integration Testing

**Test Lowcoder → n8n Integration:**

```bash
# Test webhook manually (simulate Lowcoder request)
curl -X POST https://n8n.${DOMAIN}/webhook/lowcoder-trigger \
  -H "Content-Type: application/json" \
  -d '{
    "action": "test",
    "data": {
      "source": "Lowcoder",
      "timestamp": "2025-10-04T00:00:00Z"
    }
  }'
```

**Test Lowcoder → Evolution API:**

```bash
# Test WhatsApp send directly
curl -X POST https://evolution.${DOMAIN}/message/sendText/customer_support \
  -H "apikey: ${EVOLUTION_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "number": "5511987654321",
    "text": "Test from Lowcoder integration"
  }'
```

**Test Lowcoder → Chatwoot API:**

```bash
# Test contact creation
curl -X POST https://chatwoot.${DOMAIN}/api/v1/accounts/1/contacts \
  -H "api_access_token: ${CHATWOOT_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Contact",
    "email": "test@example.com",
    "phone_number": "+5511987654321"
  }'
```

---

### Troubleshooting Lowcoder Integrations

| Problem | Solution |
|---------|----------|
| Webhook not triggered from Lowcoder | Verify n8n workflow is Active, check webhook URL in Lowcoder query |
| CORS error in Lowcoder | Add `CORS_ALLOWED_ORIGINS=*` to .env (or specific origin) |
| Evolution API 401 Unauthorized | Verify `EVOLUTION_API_KEY` in datasource headers |
| Chatwoot API 401 Unauthorized | Verify `CHATWOOT_API_TOKEN` is valid (regenerate if needed) |
| Query returns no data | Check n8n execution logs for errors, verify request format |
| Network timeout | Increase timeout in Lowcoder query settings (default: 30s) |

---

### Best Practices for Lowcoder-n8n Integration

1. **Use n8n as Orchestration Layer:**
   - Complex logic in n8n workflows (validation, error handling, retries)
   - Lowcoder focuses on UI and user interaction
   - n8n handles integrations (Evolution API, Chatwoot, databases)

2. **Error Handling:**
   - n8n workflows should return structured error responses
   - Lowcoder displays errors to users with retry options
   - Log all errors for debugging

3. **Security:**
   - Never expose API keys in Lowcoder frontend code
   - Store credentials in n8n or Lowcoder datasource config
   - Use internal network for n8n → Lowcoder communication

4. **Performance:**
   - Use async workflows for long-running tasks
   - Return immediate response to Lowcoder, process in background
   - Implement status polling for long operations

5. **Documentation:**
   - Document all webhook endpoints in n8n workflows
   - Provide example request/response in workflow descriptions
   - Maintain integration testing scripts

---

## Resources

- **n8n Documentation**: https://docs.n8n.io
- **n8n Community**: https://community.n8n.io
- **Workflow Templates**: https://n8n.io/workflows
- **BorgStack Docs**: ../../../docs/03-services/n8n.md
- **Lowcoder Integration Guide**: ../../lowcoder/README.md
- **Evolution API Documentation**: ../../evolution/README.md
- **Chatwoot API Documentation**: https://www.chatwoot.com/developers/api/
