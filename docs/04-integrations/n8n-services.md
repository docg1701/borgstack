# Integrações n8n com Serviços BorgStack

## Visão Geral

Este guia documenta todas as integrações possíveis entre o n8n e os demais serviços do BorgStack. O n8n atua como hub central de automação, conectando-se a PostgreSQL, Redis, SeaweedFS, Directus, FileFlows e outros componentes para criar workflows poderosos.

### Arquitetura de Integração

```mermaid
graph TB
    subgraph "n8n - Hub Central de Automação"
        N8N[n8n Workflows]
    end

    subgraph "Banco de Dados"
        POSTGRES[(PostgreSQL<br/>4 databases)]
        REDIS[(Redis<br/>Cache/Queue)]
        MONGO[(MongoDB<br/>Lowcoder)]
    end

    subgraph "Armazenamento"
        SEAWEED[SeaweedFS<br/>S3-compatible]
    end

    subgraph "Aplicações"
        DIRECTUS[Directus<br/>Headless CMS]
        FILEFLOWS[FileFlows<br/>Media Processing]
        CHATWOOT[Chatwoot<br/>Customer Service]
        EVOLUTION[Evolution API<br/>WhatsApp]
        LOWCODER[Lowcoder<br/>Low-Code Apps]
    end

    N8N -->|SQL Queries| POSTGRES
    N8N -->|Cache/Queue| REDIS
    N8N -->|NoSQL| MONGO
    N8N -->|File Storage| SEAWEED
    N8N -->|CMS API| DIRECTUS
    N8N -->|Media Jobs| FILEFLOWS
    N8N -->|Messages| CHATWOOT
    N8N -->|WhatsApp| EVOLUTION
    N8N -->|App Data| LOWCODER
```text

### Matriz de Integrações

| Serviço | Método de Acesso | Autenticação | Casos de Uso |
|---------|------------------|--------------|--------------|
| **PostgreSQL** | TCP (interno) | Credenciais | Queries, relatórios, sincronização de dados |
| **Redis** | TCP (interno) | Senha | Cache, filas, pub/sub, sessões |
| **MongoDB** | TCP (interno) | Credenciais | Consultas NoSQL, agregações |
| **SeaweedFS** | HTTP S3 API | Access Key/Secret | Upload/download de arquivos, backup |
| **Directus** | REST API | Bearer Token | CRUD de conteúdo, webhooks |
| **FileFlows** | REST API | API Key (futuro) | Trigger de processamento de mídia |
| **Chatwoot** | REST API | API Token | Criação de conversas, mensagens |
| **Evolution API** | REST API | API Key | Envio de WhatsApp, webhooks |
| **Lowcoder** | REST API | Bearer Token | Gestão de aplicações low-code |

---

## 1. Integração n8n → PostgreSQL

### 1.1. Configuração de Credenciais

#### Criar Credencial PostgreSQL no n8n

1. No n8n, vá em **Credentials > New**
2. Busque por `Postgres`
3. Configure:

```plaintext
Name: BorgStack PostgreSQL
Host: postgresql
Port: 5432
Database: n8n_db (ou chatwoot_db, directus_db, evolution_db)
User: postgres
Password: <valor de POSTGRES_PASSWORD do .env>
SSL: Disable (rede interna)
```text

4. Clique em **Test** para validar conexão
5. Salve a credencial

#### Verificar Conectividade

```bash
# Teste conexão do container n8n ao PostgreSQL
docker compose exec n8n sh -c "nc -zv postgresql 5432"

# Resultado esperado:
# postgresql (172.x.x.x:5432) open
```text

### 1.2. Casos de Uso Práticos

#### Caso 1: Consultar Dados de Conversas no Chatwoot

**Objetivo**: Gerar relatório diário de conversas atendidas.

**Workflow**:

##### Nó 1: Schedule Trigger
- **Node**: `Schedule Trigger`
- **Cron Expression**: `0 9 * * *` (todo dia às 9h)

##### Nó 2: PostgreSQL Query - Conversas Resolvidas
- **Node**: `Postgres`
- **Operation**: `Execute Query`
- **Query**:
```sql
SELECT
  DATE(c.created_at) as data,
  COUNT(*) as total_conversas,
  COUNT(DISTINCT c.assignee_id) as agentes_ativos,
  AVG(EXTRACT(EPOCH FROM (c.updated_at - c.created_at))/60) as tempo_medio_minutos
FROM conversations c
WHERE c.status = 'resolved'
  AND c.created_at >= CURRENT_DATE - INTERVAL '1 day'
  AND c.created_at < CURRENT_DATE
GROUP BY DATE(c.created_at);
```text

##### Nó 3: Format Data
- **Node**: `Function`
- **Code**:
```javascript
const data = $input.all()[0].json;

return {
  json: {
    relatorio: `📊 Relatório de Conversas (${data.data})

✅ Conversas Resolvidas: ${data.total_conversas}
👥 Agentes Ativos: ${data.agentes_ativos}
⏱️  Tempo Médio: ${Math.round(data.tempo_medio_minutos)} minutos

Gerado automaticamente às ${new Date().toLocaleTimeString('pt-BR')}`
  }
};
```text

##### Nó 4: Send to Telegram
- **Node**: `Telegram`
- **Operation**: `Send Message`
- **Text**: `{{$json.relatorio}}`

---

#### Caso 2: Sincronizar Contatos entre Chatwoot e CRM Externo

**Objetivo**: Exportar novos contatos do Chatwoot para um CRM externo diariamente.

**Workflow**:

##### Nó 1: PostgreSQL Query - Novos Contatos
- **Node**: `Postgres`
- **Operation**: `Execute Query`
- **Query**:
```sql
SELECT
  id,
  name,
  email,
  phone_number,
  created_at,
  custom_attributes
FROM contacts
WHERE created_at >= CURRENT_DATE - INTERVAL '1 day'
  AND created_at < CURRENT_DATE
ORDER BY created_at DESC;
```text

##### Nó 2: Transform to CRM Format
- **Node**: `Function`
- **Code**:
```javascript
const contacts = $input.all();

return contacts.map(contact => {
  const data = contact.json;
  return {
    json: {
      external_id: `chatwoot_${data.id}`,
      full_name: data.name,
      email: data.email || '',
      phone: data.phone_number ? data.phone_number.replace(/\D/g, '') : '',
      source: 'chatwoot_whatsapp',
      created_date: data.created_at,
      metadata: data.custom_attributes
    }
  };
});
```text

##### Nó 3: HTTP Request - Send to CRM
- **Node**: `HTTP Request`
- **Method**: `POST`
- **URL**: `https://crm-externo.com/api/contacts/batch`
- **Body**:
```json
{
  "contacts": "{{$json}}"
}
```text

---

#### Caso 3: Backup de Workflows do n8n

**Objetivo**: Fazer backup periódico de todos os workflows ativos no PostgreSQL.

**Workflow**:

##### Nó 1: PostgreSQL Query - Export Workflows
- **Node**: `Postgres`
- **Operation**: `Execute Query`
- **Query**:
```sql
SELECT
  id,
  name,
  active,
  nodes,
  connections,
  settings,
  created_at,
  updated_at
FROM n8n_db.workflow_entity
WHERE active = true
ORDER BY updated_at DESC;
```text

##### Nó 2: Convert to JSON Backup
- **Node**: `Function`
- **Code**:
```javascript
const workflows = $input.all();
const timestamp = new Date().toISOString().split('T')[0];

const backup = {
  backup_date: new Date().toISOString(),
  total_workflows: workflows.length,
  workflows: workflows.map(w => w.json)
};

return {
  json: backup,
  binary: {
    data: {
      data: Buffer.from(JSON.stringify(backup, null, 2)).toString('base64'),
      fileName: `n8n_workflows_backup_${timestamp}.json`,
      mimeType: 'application/json'
    }
  }
};
```text

##### Nó 3: Save to SeaweedFS
- **Node**: `HTTP Request`
- **Method**: `POST`
- **URL**: `http://seaweedfs:8888/backups/`
- **Send Binary Data**: `true`
- **Binary Property**: `data`

---

### 1.3. Consultas Úteis para Workflows

#### Listar Conversas Pendentes por Agente
```sql
SELECT
  u.name as agente,
  COUNT(*) as conversas_pendentes,
  MIN(c.created_at) as mais_antiga
FROM conversations c
JOIN users u ON c.assignee_id = u.id
WHERE c.status = 'open'
GROUP BY u.name
ORDER BY conversas_pendentes DESC;
```text

#### Calcular Taxa de Resposta
```sql
SELECT
  DATE(created_at) as dia,
  COUNT(*) as total_mensagens,
  COUNT(*) FILTER (WHERE message_type = 'outgoing') as respostas_agentes,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE message_type = 'outgoing') / COUNT(*),
    2
  ) as taxa_resposta_pct
FROM messages
WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY DATE(created_at)
ORDER BY dia DESC;
```text

#### Verificar Saúde dos Serviços (Connections)
```sql
SELECT
  datname as database,
  count(*) as connections,
  max(backend_start) as oldest_connection
FROM pg_stat_activity
WHERE state = 'active'
GROUP BY datname
ORDER BY connections DESC;
```text

---

## 2. Integração n8n → Redis

### 2.1. Configuração de Credenciais

#### Usar Node Redis no n8n

O n8n não tem nó nativo para Redis, mas podemos usar **HTTP Request** + **Redis REST API** (via webdis) ou **Function Node** com biblioteca Redis.

**Opção 1: Via Function Node (Recomendado)**

##### Nó: Function with Redis
- **Node**: `Function`
- **Code**:
```javascript
// Importar redis (disponível no n8n)
const redis = require('redis');

// Conectar ao Redis
const client = redis.createClient({
  socket: {
    host: 'redis',
    port: 6379
  },
  password: $env.REDIS_PASSWORD
});

await client.connect();

// Exemplo: SET key
await client.set('workflow:last_run', new Date().toISOString());

// Exemplo: GET key
const lastRun = await client.get('workflow:last_run');

// Exemplo: HSET hash
await client.hSet('stats:daily', {
  date: new Date().toISOString().split('T')[0],
  workflows_executed: '42',
  errors: '2'
});

// Exemplo: LPUSH list (fila)
await client.lPush('queue:emails', JSON.stringify({
  to: 'user@example.com',
  subject: 'Test',
  body: 'Hello'
}));

await client.disconnect();

return { json: { success: true, lastRun } };
```text

### 2.2. Casos de Uso Práticos

#### Caso 1: Implementar Rate Limiting

**Objetivo**: Limitar chamadas a APIs externas para 100 req/hora.

**Workflow**:

##### Nó 1: Check Rate Limit
- **Node**: `Function`
- **Code**:
```javascript
const redis = require('redis');
const client = redis.createClient({
  socket: { host: 'redis', port: 6379 },
  password: $env.REDIS_PASSWORD
});

await client.connect();

const key = `rate_limit:external_api:${new Date().getHours()}`;
const current = await client.incr(key);

// Definir TTL de 1 hora na primeira chamada
if (current === 1) {
  await client.expire(key, 3600);
}

await client.disconnect();

if (current > 100) {
  throw new Error(`Rate limit exceeded: ${current}/100 requests this hour`);
}

return { json: { allowed: true, count: current, limit: 100 } };
```text

##### Nó 2: Call External API (somente se rate limit OK)
- Conectado ao nó anterior
- Faz a chamada à API externa

---

#### Caso 2: Cache de Respostas de API

**Objetivo**: Cachear respostas de API externa por 5 minutos.

**Workflow**:

##### Nó 1: Check Cache
- **Node**: `Function`
- **Code**:
```javascript
const redis = require('redis');
const client = redis.createClient({
  socket: { host: 'redis', port: 6379 },
  password: $env.REDIS_PASSWORD
});

await client.connect();

const cacheKey = `api_cache:weather:${$json.city}`;
const cached = await client.get(cacheKey);

await client.disconnect();

if (cached) {
  return {
    json: {
      ...JSON.parse(cached),
      from_cache: true
    }
  };
}

// Se não tem cache, retorna null para continuar workflow
return null;
```text

##### Nó 2: Call Weather API (se cache miss)
- **Node**: `HTTP Request`
- **URL**: `https://api.weather.com/v3/wx/conditions/current?city={{$json.city}}`

##### Nó 3: Store in Cache
- **Node**: `Function`
- **Code**:
```javascript
const redis = require('redis');
const client = redis.createClient({
  socket: { host: 'redis', port: 6379 },
  password: $env.REDIS_PASSWORD
});

await client.connect();

const cacheKey = `api_cache:weather:${$node["Check Cache"].json.city}`;
const data = $json;

// Cachear por 300 segundos (5 minutos)
await client.setEx(cacheKey, 300, JSON.stringify(data));

await client.disconnect();

return { json: { ...data, from_cache: false } };
```text

---

#### Caso 3: Fila de Tarefas Assíncronas

**Objetivo**: Processar e-mails em fila para evitar sobrecarga.

**Workflow 1: Enfileirar E-mails**

##### Nó: Add to Queue
- **Node**: `Function`
- **Code**:
```javascript
const redis = require('redis');
const client = redis.createClient({
  socket: { host: 'redis', port: 6379 },
  password: $env.REDIS_PASSWORD
});

await client.connect();

const emailData = {
  to: $json.email,
  subject: $json.subject,
  body: $json.body,
  timestamp: new Date().toISOString(),
  priority: $json.priority || 'normal'
};

// Adicionar à fila
await client.lPush('queue:emails', JSON.stringify(emailData));

// Incrementar contador
await client.incr('stats:emails:queued');

const queueSize = await client.lLen('queue:emails');

await client.disconnect();

return { json: { queued: true, queue_size: queueSize } };
```text

**Workflow 2: Processar Fila (Worker)**

##### Nó 1: Schedule Trigger
- **Cron**: `*/2 * * * *` (a cada 2 minutos)

##### Nó 2: Pop from Queue
- **Node**: `Function`
- **Code**:
```javascript
const redis = require('redis');
const client = redis.createClient({
  socket: { host: 'redis', port: 6379 },
  password: $env.REDIS_PASSWORD
});

await client.connect();

const items = [];
const batchSize = 10;

// Processar até 10 e-mails por vez
for (let i = 0; i < batchSize; i++) {
  const item = await client.rPop('queue:emails');
  if (!item) break;
  items.push(JSON.parse(item));
}

await client.disconnect();

if (items.length === 0) {
  return null; // Fila vazia, abortar workflow
}

return items.map(item => ({ json: item }));
```text

##### Nó 3: Send Emails
- **Node**: `Send Email`
- **To**: `{{$json.to}}`
- **Subject**: `{{$json.subject}}`
- **Body**: `{{$json.body}}`

---

#### Caso 4: Pub/Sub para Notificações em Tempo Real

**Workflow Publisher: Publicar Evento**

##### Nó: Publish Event
- **Node**: `Function`
- **Code**:
```javascript
const redis = require('redis');
const client = redis.createClient({
  socket: { host: 'redis', port: 6379 },
  password: $env.REDIS_PASSWORD
});

await client.connect();

const event = {
  type: 'new_conversation',
  conversation_id: $json.conversation_id,
  customer: $json.customer_name,
  timestamp: new Date().toISOString()
};

// Publicar no canal
await client.publish('events:conversations', JSON.stringify(event));

await client.disconnect();

return { json: { published: true, event } };
```text

**Workflow Subscriber: Receber Eventos (n8n Trigger)**

> **Nota**: n8n não tem trigger nativo para Redis Pub/Sub. Use polling alternativo:

##### Nó 1: Schedule Trigger
- **Cron**: `* * * * *` (a cada 1 minuto)

##### Nó 2: Check Stream (alternativa ao pub/sub)
- Use Redis Streams (XREAD) para eventos persistentes

---

### 2.3. Comandos Redis Úteis

```javascript
// String Operations
await client.set('key', 'value');
await client.get('key');
await client.setEx('key', 3600, 'value'); // TTL 1 hora

// Hash Operations
await client.hSet('user:1001', { name: 'João', email: 'joao@example.com' });
await client.hGet('user:1001', 'name');
await client.hGetAll('user:1001');

// List Operations (Filas)
await client.lPush('queue', 'item'); // Adicionar ao início
await client.rPush('queue', 'item'); // Adicionar ao fim
await client.lPop('queue'); // Remover do início
await client.rPop('queue'); // Remover do fim
await client.lLen('queue'); // Tamanho da fila

// Set Operations (Conjuntos únicos)
await client.sAdd('tags', 'urgent');
await client.sMembers('tags');
await client.sIsMember('tags', 'urgent');

// Sorted Set (Rankings)
await client.zAdd('leaderboard', { score: 100, value: 'player1' });
await client.zRange('leaderboard', 0, 9); // Top 10

// Pub/Sub
await client.publish('channel', 'message');
await client.subscribe('channel', (message) => console.log(message));

// Expiração
await client.expire('key', 3600); // 1 hora
await client.ttl('key'); // Tempo restante
```text

---

## 3. Integração n8n → Directus

### 3.1. Configuração de Credenciais

#### Criar Credencial Directus no n8n

1. No n8n, vá em **Credentials > New**
2. Busque por `Directus`
3. Configure:

```plaintext
Name: BorgStack Directus
URL: http://directus:8055
Email: admin@example.com
Password: <sua senha admin>
```text

4. Ou use **Access Token** (mais seguro):

```plaintext
Name: BorgStack Directus (Token)
URL: http://directus:8055
Access Token: <seu token estático>
```text

Para gerar token estático:
```bash
# Acessar Directus > User Settings > Generate Static Token
```text

### 3.2. Casos de Uso Práticos

#### Caso 1: Sincronizar Artigos do Directus para E-mail Marketing

**Objetivo**: Quando um artigo for publicado no Directus, enviar para lista de e-mails.

**Workflow**:

##### Nó 1: Directus Trigger
- **Node**: `Directus Trigger`
- **Event**: `items.create`
- **Collection**: `articles`

##### Nó 2: Check if Published
- **Node**: `IF`
- **Condition**: `{{$json.status}} === "published"`

##### Nó 3: Format for Email
- **Node**: `Function`
- **Code**:
```javascript
const article = $json;

return {
  json: {
    subject: `📰 Novo artigo: ${article.title}`,
    body: `
      <h1>${article.title}</h1>
      <p><em>Por ${article.author} em ${new Date(article.date_created).toLocaleDateString('pt-BR')}</em></p>

      ${article.excerpt}

      <p><a href="https://seusite.com.br/blog/${article.slug}">Leia mais →</a></p>
    `,
    article_id: article.id
  }
};
```text

##### Nó 4: Send to Mailchimp/Sendinblue
- **Node**: `HTTP Request` (API do provedor de e-mail)

---

#### Caso 2: Importar Dados de Planilha para Directus

**Objetivo**: Importar produtos de um Google Sheets para coleção no Directus.

**Workflow**:

##### Nó 1: Google Sheets Trigger
- **Node**: `Google Sheets Trigger`
- **Trigger On**: `Row Added`
- **Sheet**: `Products`

##### Nó 2: Transform Data
- **Node**: `Function`
- **Code**:
```javascript
const row = $json;

return {
  json: {
    name: row.ProductName,
    sku: row.SKU,
    price: parseFloat(row.Price),
    category: row.Category,
    stock: parseInt(row.Stock),
    description: row.Description,
    status: row.Stock > 0 ? 'published' : 'draft',
    imported_at: new Date().toISOString()
  }
};
```text

##### Nó 3: Create in Directus
- **Node**: `Directus`
- **Operation**: `Create`
- **Collection**: `products`
- **Data**: `{{$json}}`

---

#### Caso 3: Backup Automático de Conteúdo

**Objetivo**: Exportar todo conteúdo do Directus para JSON diariamente.

**Workflow**:

##### Nó 1: Schedule Trigger
- **Cron**: `0 3 * * *` (3h da manhã)

##### Nó 2: Get All Collections
- **Node**: `HTTP Request`
- **Method**: `GET`
- **URL**: `http://directus:8055/collections`
- **Headers**: `Authorization: Bearer {{$credentials.token}}`

##### Nó 3: Loop Collections
- **Node**: `Split In Batches`

##### Nó 4: Get Collection Items
- **Node**: `Directus`
- **Operation**: `Get All`
- **Collection**: `{{$json.collection}}`
- **Limit**: `1000`

##### Nó 5: Save to File
- **Node**: `Write Binary File`
- **File Path**: `/backups/directus_{{$json.collection}}_{{$now.format('YYYY-MM-DD')}}.json`

---

#### Caso 4: Webhook de Atualização para Rebuild de Site

**Objetivo**: Trigger rebuild do site estático quando conteúdo mudar.

**Workflow**:

##### Nó 1: Directus Trigger
- **Node**: `Directus Trigger`
- **Event**: `items.update`
- **Collections**: `articles, pages, products`

##### Nó 2: Wait (Debounce)
- **Node**: `Wait`
- **Resume On**: `Webhook Call`
- **Wait Time**: `5 minutes`
- **Reason**: Agregar múltiplas mudanças

##### Nó 3: Trigger Vercel Deploy
- **Node**: `HTTP Request`
- **Method**: `POST`
- **URL**: `https://api.vercel.com/v1/integrations/deploy/<hook-id>`

##### Nó 4: Notify Team
- **Node**: `Slack`
- **Message**: `🚀 Site rebuild triggered. ${$json.collection} updated.`

---

### 3.3. API Directus - Endpoints Úteis

#### Listar Itens com Filtro
```bash
GET /items/articles?filter[status][_eq]=published&sort=-date_created&limit=10
```text

#### Criar Item
```bash
POST /items/articles
Content-Type: application/json
Authorization: Bearer TOKEN

{
  "title": "Meu Artigo",
  "content": "Conteúdo...",
  "status": "draft"
}
```text

#### Atualizar Item
```bash
PATCH /items/articles/42
Content-Type: application/json
Authorization: Bearer TOKEN

{
  "status": "published"
}
```text

#### Fazer Upload de Arquivo
```bash
POST /files
Content-Type: multipart/form-data
Authorization: Bearer TOKEN

[binary file data]
```text

#### Buscar com Relacionamentos
```bash
GET /items/articles?fields=*,author.first_name,author.last_name,category.name
```text

---

## 4. Integração n8n → SeaweedFS

### 4.1. Configuração de Credenciais S3

#### Criar Credencial S3 para SeaweedFS

1. No n8n, vá em **Credentials > New**
2. Busque por `S3` (AWS S3 compatible)
3. Configure:

```plaintext
Name: BorgStack SeaweedFS
Access Key ID: <valor de S3_ACCESS_KEY do .env>
Secret Access Key: <valor de S3_SECRET_KEY do .env>
Region: us-east-1 (padrão)
Custom Endpoint: http://seaweedfs:8333
Force Path Style: Yes
```text

### 4.2. Casos de Uso Práticos

#### Caso 1: Upload de Arquivo para Bucket

**Workflow**:

##### Nó 1: Webhook Trigger
- **Node**: `Webhook`
- **Path**: `upload-file`
- **Method**: `POST`

##### Nó 2: Upload to S3
- **Node**: `AWS S3`
- **Operation**: `Upload`
- **Bucket Name**: `documents`
- **File Name**: `{{$json.filename}}`
- **Binary Data**: `true`

##### Nó 3: Return Public URL
- **Node**: `Function`
- **Code**:
```javascript
const filename = $node["Upload to S3"].json.Key;
const publicUrl = `https://seaweedfs.seudominio.com.br/documents/${filename}`;

return {
  json: {
    success: true,
    url: publicUrl,
    filename: filename,
    uploaded_at: new Date().toISOString()
  }
};
```text

---

#### Caso 2: Backup de Banco de Dados para S3

**Workflow**:

##### Nó 1: Schedule Trigger
- **Cron**: `0 2 * * *` (2h da manhã)

##### Nó 2: Create PostgreSQL Dump
- **Node**: `Execute Command`
- **Command**:
```bash
docker compose exec -T postgresql pg_dump -U postgres -Fc chatwoot_db > /tmp/chatwoot_backup_$(date +%Y%m%d).dump
```text

##### Nó 3: Read Dump File
- **Node**: `Read Binary File`
- **File Path**: `/tmp/chatwoot_backup_{{$now.format('YYYYMMDD')}}.dump`

##### Nó 4: Upload to S3
- **Node**: `AWS S3`
- **Operation**: `Upload`
- **Bucket Name**: `database-backups`
- **File Name**: `chatwoot/chatwoot_{{$now.format('YYYYMMDD')}}.dump`

##### Nó 5: Delete Old Backups (> 30 dias)
- **Node**: `AWS S3`
- **Operation**: `List`
- **Bucket**: `database-backups`
- **Prefix**: `chatwoot/`
- Filtrar e deletar arquivos antigos

---

#### Caso 3: Processar Imagens Uploaded

**Objetivo**: Quando imagem for uploaded, gerar thumbnail e salvar.

**Workflow**:

##### Nó 1: S3 Trigger (via Filer API webhook)
- **Node**: `Webhook`
- **Path**: `s3-file-uploaded`

##### Nó 2: Download Original Image
- **Node**: `HTTP Request`
- **Method**: `GET`
- **URL**: `http://seaweedfs:8888/{{$json.filer_path}}`
- **Response Format**: `File`

##### Nó 3: Generate Thumbnail
- **Node**: `Edit Image`
- **Operation**: `Resize`
- **Width**: `300`
- **Height**: `300`
- **Keep Proportions**: `true`

##### Nó 4: Upload Thumbnail
- **Node**: `AWS S3`
- **Operation**: `Upload`
- **Bucket**: `images`
- **File Name**: `thumbnails/{{$json.original_name}}`

---

### 4.3. API SeaweedFS - Endpoints Úteis

#### Upload via Filer API
```bash
curl -F file=@photo.jpg "http://seaweedfs:8888/uploads/"
```text

#### Download via Filer API
```bash
curl "http://seaweedfs:8888/uploads/photo.jpg" -o photo.jpg
```text

#### Listar Diretório
```bash
curl "http://seaweedfs:8888/uploads/?pretty=y"
```text

#### S3 API - Upload (AWS SDK compatible)
```javascript
const AWS = require('aws-sdk');

const s3 = new AWS.S3({
  endpoint: 'http://seaweedfs:8333',
  accessKeyId: 'access_key',
  secretAccessKey: 'secret_key',
  s3ForcePathStyle: true
});

await s3.putObject({
  Bucket: 'my-bucket',
  Key: 'file.txt',
  Body: 'Hello World'
}).promise();
```text

---

## 5. Integração n8n → FileFlows

### 5.1. Configuração

#### Usar HTTP Request Node

FileFlows não tem nó dedicado no n8n. Use **HTTP Request** com API REST.

**Base URL**: `http://fileflows:5000`

### 5.2. Casos de Uso Práticos

#### Caso 1: Trigger de Processamento de Vídeo

**Objetivo**: Quando vídeo for uploaded no Directus, enviar para FileFlows processar.

**Workflow**:

##### Nó 1: Directus Trigger
- **Node**: `Directus Trigger`
- **Event**: `items.create`
- **Collection**: `videos`

##### Nó 2: Get File URL
- **Node**: `Directus`
- **Operation**: `Get`
- **Collection**: `directus_files`
- **ID**: `{{$json.file_id}}`

##### Nó 3: Trigger FileFlows Processing
- **Node**: `HTTP Request`
- **Method**: `POST`
- **URL**: `http://fileflows:5000/api/file`
- **Headers**: `Content-Type: application/json`
- **Body**:
```json
{
  "path": "{{$json.filename_download}}",
  "flow": "video-transcode",
  "library": "directus-uploads"
}
```text

##### Nó 4: Update Directus Status
- **Node**: `Directus`
- **Operation**: `Update`
- **Collection**: `videos`
- **ID**: `{{$node["Directus Trigger"].json.id}}`
- **Data**:
```json
{
  "processing_status": "queued",
  "fileflows_job_id": "{{$json.uid}}"
}
```text

---

#### Caso 2: Monitorar Jobs do FileFlows

**Workflow**:

##### Nó 1: Schedule Trigger
- **Cron**: `*/5 * * * *` (a cada 5 minutos)

##### Nó 2: Get Processing Jobs
- **Node**: `HTTP Request`
- **Method**: `GET`
- **URL**: `http://fileflows:5000/api/library-file/processing`

##### Nó 3: Check for Completed Jobs
- **Node**: `Function`
- **Code**:
```javascript
const jobs = $json;
const completed = jobs.filter(job => job.status === 'Processed');

if (completed.length === 0) return null;

return completed.map(job => ({ json: job }));
```text

##### Nó 4: Update Directus
- **Node**: `Directus`
- **Operation**: `Update`
- **Collection**: `videos`
- **Filter**: `fileflows_job_id={{$json.uid}}`
- **Data**:
```json
{
  "processing_status": "completed",
  "processed_at": "{{$now.toISO()}}"
}
```text

---

## 6. Integração n8n → Lowcoder

### 6.1. Configuração

Use **HTTP Request** com API REST do Lowcoder.

**Base URL**: `http://lowcoder-api-service:3000`

### 6.2. Casos de Uso Práticos

#### Caso 1: Criar Aplicação Dinamicamente

**Workflow**:

##### Nó: Create Lowcoder App
- **Node**: `HTTP Request`
- **Method**: `POST`
- **URL**: `http://lowcoder-api-service:3000/api/applications`
- **Headers**:
  - `Authorization: Bearer {{$env.LOWCODER_TOKEN}}`
  - `Content-Type: application/json`
- **Body**:
```json
{
  "name": "{{$json.app_name}}",
  "orgId": "{{$json.org_id}}",
  "applicationType": "Application",
  "dsl": {}
}
```text

---

## 7. Padrões e Boas Práticas

### 7.1. Tratamento de Erros

#### Padrão Global de Error Handler

Adicione em todos os workflows:

```javascript
// Node: Global Error Handler (On Error)
const error = $input.all()[0].json;

// Log no console
console.error('Workflow Error:', {
  workflow: $workflow.name,
  node: error.node.name,
  error: error.error.message,
  timestamp: new Date().toISOString()
});

// Salvar no PostgreSQL
const errorLog = {
  workflow_id: $workflow.id,
  workflow_name: $workflow.name,
  node_name: error.node.name,
  error_message: error.error.message,
  error_stack: error.error.stack,
  input_data: JSON.stringify(error.json),
  timestamp: new Date().toISOString()
};

// INSERT no banco (usar nó PostgreSQL)

// Notificar time via Slack/Telegram
return {
  json: {
    alert: `🚨 Erro no workflow ${$workflow.name}`,
    error: error.error.message,
    node: error.node.name
  }
};
```text

### 7.2. Retry Logic

```javascript
// Node: Retry with Exponential Backoff
const maxRetries = 3;
const baseDelay = 1000; // 1 segundo

for (let attempt = 1; attempt <= maxRetries; attempt++) {
  try {
    // Sua operação aqui
    const result = await $http.request({
      url: 'https://api.example.com/data',
      method: 'GET'
    });

    return { json: result };
  } catch (error) {
    if (attempt === maxRetries) {
      throw error; // Última tentativa falhou
    }

    // Exponential backoff: 1s, 2s, 4s
    const delay = baseDelay * Math.pow(2, attempt - 1);
    console.log(`Retry ${attempt}/${maxRetries} after ${delay}ms`);
    await new Promise(resolve => setTimeout(resolve, delay));
  }
}
```text

### 7.3. Logging Estruturado

```javascript
// Node: Structured Logger
function log(level, message, metadata = {}) {
  const logEntry = {
    timestamp: new Date().toISOString(),
    level: level, // 'info', 'warn', 'error'
    workflow_id: $workflow.id,
    workflow_name: $workflow.name,
    execution_id: $execution.id,
    message: message,
    ...metadata
  };

  console.log(JSON.stringify(logEntry));

  // Opcional: Salvar no PostgreSQL ou enviar para serviço de logs
  return logEntry;
}

// Uso:
log('info', 'Processing started', { item_count: $json.items.length });
log('error', 'API call failed', { api: 'external', status: 500 });
```text

### 7.4. Validação de Dados

```javascript
// Node: Validate Input
function validateEmail(email) {
  const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return regex.test(email);
}

function validatePhone(phone) {
  const cleaned = phone.replace(/\D/g, '');
  return cleaned.length >= 10 && cleaned.length <= 15;
}

const data = $json;
const errors = [];

if (!data.name || data.name.trim().length < 3) {
  errors.push('Nome deve ter no mínimo 3 caracteres');
}

if (!validateEmail(data.email)) {
  errors.push('E-mail inválido');
}

if (data.phone && !validatePhone(data.phone)) {
  errors.push('Telefone inválido');
}

if (errors.length > 0) {
  throw new Error(`Validação falhou: ${errors.join(', ')}`);
}

return { json: data };
```text

---

## 8. Monitoramento e Debugging

### 8.1. Logs Centralizados

```bash
# Ver logs do n8n em tempo real
docker compose logs -f n8n

# Filtrar por erro
docker compose logs n8n | grep ERROR

# Exportar logs para arquivo
docker compose logs n8n --since 24h > n8n_logs_$(date +%Y%m%d).txt
```text

### 8.2. Métricas de Performance

```javascript
// Node: Track Execution Time
const startTime = Date.now();

// Sua operação aqui
const result = await doSomething();

const endTime = Date.now();
const duration = endTime - startTime;

// Log performance
console.log(JSON.stringify({
  metric: 'execution_time',
  workflow: $workflow.name,
  node: $node.name,
  duration_ms: duration,
  timestamp: new Date().toISOString()
}));

// Alertar se muito lento
if (duration > 5000) {
  console.warn(`Slow execution: ${duration}ms`);
}

return { json: { ...result, _execution_time_ms: duration } };
```text

---

## Recursos Adicionais

### Documentação Oficial

- **n8n**: https://docs.n8n.io/
- **PostgreSQL Node**: https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-base.postgres/
- **Directus Node**: https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-base.directus/
- **AWS S3 Node**: https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-base.awss3/
- **Redis**: https://redis.io/docs/

### Guias Relacionados

- [n8n - Automação de Workflows](../03-services/n8n.md)
- [PostgreSQL - Banco de Dados](../03-services/postgresql.md)
- [Redis - Cache e Filas](../03-services/redis.md)
- [Directus - Headless CMS](../03-services/directus.md)
- [SeaweedFS - Object Storage](../03-services/seaweedfs.md)
- [Integração WhatsApp → Chatwoot](whatsapp-chatwoot.md)

---

**Última atualização**: 2025-10-08
**Versão do guia**: 1.0
**Compatibilidade**: BorgStack v1.0, n8n 1.112.6, PostgreSQL 18, Redis 8.2, Directus 11
