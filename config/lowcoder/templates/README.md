# Lowcoder Application Templates

This directory contains application templates for common BorgStack use cases. Templates are created in the Lowcoder UI and exported as JSON files for sharing and reuse.

## Table of Contents

1. [How to Create Templates](#how-to-create-templates)
2. [How to Export Templates](#how-to-export-templates)
3. [How to Import Templates](#how-to-import-templates)
4. [Available Templates](#available-templates)
5. [Template Specifications](#template-specifications)

---

## How to Create Templates

Templates are applications built in Lowcoder UI that serve as starting points for common use cases.

### Step 1: Build Your Application

1. **Login to Lowcoder**: `https://lowcoder.{DOMAIN}`
2. **Create New Application**: Click "Create New" → "Application"
3. **Design the Application**:
   - Add datasource connections (PostgreSQL, REST API)
   - Create queries for data retrieval
   - Add UI components (tables, forms, charts)
   - Configure component data bindings
   - Set up interactivity (button actions, form submissions)
4. **Test Thoroughly**: Ensure all features work as expected
5. **Document**: Add comments and descriptions within the app

### Step 2: Prepare for Template Export

1. **Remove Environment-Specific Data**:
   - Remove hardcoded domain names (use placeholders like `{{DOMAIN}}`)
   - Remove test data and dummy credentials
   - Generalize query parameters

2. **Add Template Documentation**:
   - Application description explaining purpose
   - Required datasources list
   - Setup instructions for users

3. **Create Sample Data** (optional):
   - Provide example queries with sample results
   - Document expected data schema

---

## How to Export Templates

### Export from Lowcoder UI

1. **Open Application** in Lowcoder editor
2. **Click "⋯" (More Options)** in top-right corner
3. **Select "Export"**
4. **Choose Export Format**: JSON (recommended)
5. **Download File**: Saves as `{application-name}.json`
6. **Rename File**: Use descriptive name (e.g., `customer-service-dashboard.json`)
7. **Move to Templates Directory**:
   ```bash
   mv ~/Downloads/customer-service-dashboard.json config/lowcoder/templates/
   ```

### Export via Lowcoder API (Advanced)

```bash
# Get Lowcoder API token (from Settings → API Keys)
LOWCODER_API_TOKEN="your-api-token-here"

# Export application by ID
curl -X GET "https://lowcoder.${DOMAIN}/api/v1/applications/{application-id}/export" \
  -H "Authorization: Bearer ${LOWCODER_API_TOKEN}" \
  -o config/lowcoder/templates/my-template.json
```

---

## How to Import Templates

### Import via Lowcoder UI

1. **Login to Lowcoder**: `https://lowcoder.{DOMAIN}`
2. **Click "Import"** button (usually in applications list)
3. **Select JSON File**: Choose template from `config/lowcoder/templates/`
4. **Review Import Preview**: Verify datasources and components
5. **Click "Import"**
6. **Configure Datasources**:
   - Update datasource credentials (if needed)
   - Test datasource connections
7. **Customize Application**:
   - Update branding (colors, logos)
   - Modify queries for your data
   - Adjust UI layout as needed
8. **Publish**: Deploy the application for users

### Import via Lowcoder API (Advanced)

```bash
# Get Lowcoder API token
LOWCODER_API_TOKEN="your-api-token-here"

# Import template
curl -X POST "https://lowcoder.${DOMAIN}/api/v1/applications/import" \
  -H "Authorization: Bearer ${LOWCODER_API_TOKEN}" \
  -F "file=@config/lowcoder/templates/customer-service-dashboard.json"
```

---

## Available Templates

### 1. Customer Service Dashboard
- **File**: `customer-service-dashboard.json` (to be created)
- **Description**: Real-time dashboard for Chatwoot customer service metrics
- **Datasource**: PostgreSQL (`chatwoot_db` via `lowcoder_readonly_user`)
- **Features**:
  - Open conversations table
  - Agent performance metrics
  - Conversation status charts
  - Date range filters

### 2. Workflow Analytics Dashboard
- **File**: `workflow-analytics.json` (to be created)
- **Description**: n8n workflow execution monitoring and analytics
- **Datasource**: PostgreSQL (`n8n_db` via `lowcoder_readonly_user`)
- **Features**:
  - Workflow execution history table
  - Success/failure rate charts
  - Recent errors list
  - Execution time metrics

### 3. WhatsApp Campaign Builder
- **File**: `whatsapp-campaign-builder.json` (to be created)
- **Description**: Send WhatsApp campaigns via Evolution API and n8n
- **Datasource**: REST API (n8n webhook, Evolution API)
- **Features**:
  - Campaign form (message template, recipients)
  - Contact list upload
  - Send button (triggers n8n workflow)
  - Campaign status tracking

---

## Template Specifications

### Template 1: Customer Service Dashboard

**Purpose**: Visualize Chatwoot customer service data for managers and agents

**Datasource Requirements**:
- **PostgreSQL Connection**: `chatwoot_db_readonly`
  - Host: `postgresql`
  - Port: `5432`
  - Database: `chatwoot_db`
  - Username: `lowcoder_readonly_user`
  - Password: `${LOWCODER_READONLY_DB_PASSWORD}`

**Queries**:

1. **get_open_conversations**:
   ```sql
   SELECT
     c.id,
     c.display_id,
     ct.name as contact_name,
     ct.email,
     c.status,
     c.created_at,
     c.updated_at,
     a.name as assignee_name
   FROM conversations c
   LEFT JOIN contacts ct ON c.contact_id = ct.id
   LEFT JOIN users a ON c.assignee_id = a.id
   WHERE c.status = 'open'
   ORDER BY c.created_at DESC
   LIMIT 100
   ```

2. **get_conversation_metrics**:
   ```sql
   SELECT
     status,
     COUNT(*) as count
   FROM conversations
   WHERE created_at >= NOW() - INTERVAL '7 days'
   GROUP BY status
   ```

3. **get_agent_performance**:
   ```sql
   SELECT
     u.name as agent_name,
     COUNT(c.id) as conversations_handled,
     AVG(EXTRACT(EPOCH FROM (c.updated_at - c.created_at))/3600) as avg_resolution_hours
   FROM conversations c
   JOIN users u ON c.assignee_id = u.id
   WHERE c.status = 'resolved'
     AND c.created_at >= NOW() - INTERVAL '30 days'
   GROUP BY u.name
   ORDER BY conversations_handled DESC
   ```

**UI Components**:
- **Header**: Dashboard title, date range filter, refresh button
- **KPI Cards**: Open conversations count, avg resolution time, total contacts
- **Table**: Open conversations list (columns: ID, Contact, Status, Assignee, Created)
- **Bar Chart**: Conversations by status (last 7 days)
- **Table**: Agent performance metrics

**Configuration Steps**:
1. Create PostgreSQL datasource (`chatwoot_db_readonly`)
2. Create 3 queries (open conversations, metrics, agent performance)
3. Add KPI stat components and bind to query aggregates
4. Add table component for open conversations
5. Add chart components for visual metrics
6. Add date range filter and wire to query parameters
7. Test with real Chatwoot data
8. Export as `customer-service-dashboard.json`

---

### Template 2: Workflow Analytics Dashboard

**Purpose**: Monitor n8n workflow executions and identify issues

**Datasource Requirements**:
- **PostgreSQL Connection**: `n8n_db_readonly`
  - Host: `postgresql`
  - Port: `5432`
  - Database: `n8n_db`
  - Username: `lowcoder_readonly_user`
  - Password: `${LOWCODER_READONLY_DB_PASSWORD}`

**Queries**:

1. **get_recent_executions**:
   ```sql
   SELECT
     e.id,
     w.name as workflow_name,
     e.finished,
     e."startedAt",
     e."stoppedAt",
     e."mode",
     EXTRACT(EPOCH FROM (e."stoppedAt" - e."startedAt")) as duration_seconds
   FROM execution_entity e
   JOIN workflow_entity w ON e."workflowId" = w.id
   WHERE e.finished = true
   ORDER BY e."startedAt" DESC
   LIMIT 100
   ```

2. **get_execution_stats**:
   ```sql
   SELECT
     w.name as workflow_name,
     COUNT(*) as total_executions,
     COUNT(*) FILTER (WHERE e.finished = true AND e."stoppedAt" IS NOT NULL) as successful,
     COUNT(*) FILTER (WHERE e.finished = false OR e."stoppedAt" IS NULL) as failed
   FROM execution_entity e
   JOIN workflow_entity w ON e."workflowId" = w.id
   WHERE e."startedAt" >= NOW() - INTERVAL '7 days'
   GROUP BY w.name
   ORDER BY total_executions DESC
   ```

3. **get_recent_errors**:
   ```sql
   SELECT
     e.id,
     w.name as workflow_name,
     e."startedAt",
     e."stoppedAt"
   FROM execution_entity e
   JOIN workflow_entity w ON e."workflowId" = w.id
   WHERE e.finished = false
   ORDER BY e."startedAt" DESC
   LIMIT 50
   ```

**UI Components**:
- **Header**: Dashboard title, workflow filter, time range selector
- **KPI Cards**: Total executions (24h), success rate, avg execution time
- **Table**: Recent executions (columns: Workflow, Status, Start Time, Duration)
- **Pie Chart**: Success vs failure rate (last 7 days)
- **Table**: Recent errors with details

**Configuration Steps**:
1. Create PostgreSQL datasource (`n8n_db_readonly`)
2. Create 3 queries (recent executions, stats, errors)
3. Add KPI components for key metrics
4. Add table for execution history
5. Add chart for success/failure visualization
6. Add error log table with red highlighting
7. Test with real n8n data
8. Export as `workflow-analytics.json`

---

### Template 3: WhatsApp Campaign Builder

**Purpose**: Send WhatsApp campaigns to multiple recipients via Evolution API

**Datasource Requirements**:

1. **n8n Webhook REST API**: `n8n_webhooks`
   - Base URL: `https://n8n.${DOMAIN}/webhook`
   - Method: POST
   - Authentication: None (internal network)

2. **Evolution API REST API**: `evolution_api` (optional, for status checking)
   - Base URL: `https://evolution.${DOMAIN}`
   - Headers:
     - `apikey`: `${EVOLUTION_API_KEY}` (from .env)
     - `Content-Type`: `application/json`

**n8n Workflow Required**:
Create a workflow with webhook trigger (`/whatsapp-campaign`) that:
1. Receives campaign data (message, recipients list)
2. Loops through recipients
3. Sends WhatsApp message via Evolution API for each recipient
4. Returns campaign status

**Queries**:

1. **trigger_campaign** (REST API Query):
   ```javascript
   // Method: POST
   // URL: /whatsapp-campaign
   // Body:
   {
     "campaign_name": "{{ campaignNameInput.value }}",
     "message": "{{ messageTextArea.value }}",
     "recipients": {{ recipientsTable.data }},
     "instance": "{{ instanceSelect.value }}"
   }
   ```

2. **get_instances** (REST API Query to Evolution API):
   ```javascript
   // Method: GET
   // URL: /instance/fetchInstances
   // Headers: { "apikey": "${EVOLUTION_API_KEY}" }
   ```

**UI Components**:
- **Header**: Campaign builder title
- **Form Section**:
  - Campaign name input
  - WhatsApp instance selector (dropdown from `get_instances` query)
  - Message template textarea
  - Recipients upload (CSV or manual entry table)
- **Preview Section**: Message preview with variables
- **Action Buttons**:
  - Send Campaign button (triggers `trigger_campaign` query)
  - Save Draft button
  - Clear Form button
- **Results Section**: Campaign status, delivery count, errors

**Configuration Steps**:
1. Create n8n webhook workflow (`/whatsapp-campaign`)
2. Create REST API datasource for n8n webhooks
3. Create REST API datasource for Evolution API (optional)
4. Create form components for campaign details
5. Create table for recipients list
6. Create send button with query trigger
7. Add result display components
8. Test with small recipient list
9. Export as `whatsapp-campaign-builder.json`

---

## Creating Your Own Templates

### Best Practices

1. **Reusability**: Design for generic use cases, not specific instances
2. **Documentation**: Add descriptions to queries, components, and workflows
3. **Error Handling**: Include validation and error messages
4. **Performance**: Use query limits and pagination for large datasets
5. **Security**: Use read-only datasources, validate inputs, prevent SQL injection

### Template Naming Convention

- Use kebab-case: `customer-service-dashboard.json`
- Include version if needed: `workflow-analytics-v2.json`
- Descriptive names: `whatsapp-campaign-builder.json` (not `app1.json`)

### Template Documentation Checklist

- [ ] Application purpose and use case clearly described
- [ ] Required datasources listed with connection details
- [ ] Required external dependencies documented (n8n workflows, APIs)
- [ ] Setup instructions provided step-by-step
- [ ] Sample data or test scenarios included
- [ ] Known limitations documented
- [ ] Screenshots or diagrams (optional)

---

## Troubleshooting Template Import

### Common Issues

1. **Datasource Not Found**:
   - **Cause**: Template references datasource that doesn't exist
   - **Solution**: Create matching datasource before importing template
   - **Example**: Template expects `chatwoot_db_readonly`, but you haven't created it yet

2. **Import Fails with Error**:
   - **Cause**: JSON file corrupted or invalid format
   - **Solution**: Re-export template or validate JSON syntax
   - **Tool**: `jq . < template.json` (validates JSON)

3. **Application Doesn't Work After Import**:
   - **Cause**: Datasource credentials not configured
   - **Solution**: Open imported app → Datasources → Test connection → Update credentials

4. **Queries Return No Data**:
   - **Cause**: Database schema different or no data in tables
   - **Solution**: Verify table names, column names match your database schema

5. **Components Not Displaying Data**:
   - **Cause**: Data binding references incorrect query or field names
   - **Solution**: Check component data source property, update bindings

---

## Contributing Templates

To contribute a new template to BorgStack:

1. **Build and Test**: Create application in Lowcoder, test thoroughly
2. **Export**: Export as JSON file
3. **Document**: Create specification section in this README
4. **Add to Repository**:
   ```bash
   # Add template file
   cp ~/Downloads/my-template.json config/lowcoder/templates/

   # Update this README with template specification
   # (see Template Specifications section above)

   # Commit changes
   git add config/lowcoder/templates/my-template.json
   git add config/lowcoder/templates/README.md
   git commit -m "Add Lowcoder template: My Template"
   ```

5. **Create Pull Request**: Submit PR with template and documentation

---

## Additional Resources

- **Lowcoder Documentation**: [https://docs.lowcoder.cloud](https://docs.lowcoder.cloud)
- **Template Examples**: [https://github.com/lowcoderorg/lowcoder-templates](https://github.com/lowcoderorg/lowcoder-templates)
- **Community Templates**: [https://lowcoder.cloud/templates](https://lowcoder.cloud/templates)

---

## Support

For template-related issues:
1. Check this README for troubleshooting steps
2. Review `config/lowcoder/README.md` for datasource configuration
3. Test datasources independently before importing templates
4. Verify n8n workflows are active (for webhook-based templates)
