# Integração WhatsApp → Chatwoot via n8n

## Visão Geral

Este guia documenta a integração completa entre WhatsApp Business, Evolution API, n8n e Chatwoot no BorgStack. Esta integração permite gerenciar conversas de WhatsApp através de uma interface de atendimento profissional, com sincronização bidirecional de mensagens, criação automática de contatos e histórico completo de conversas.

### Arquitetura da Integração

```mermaid
sequenceDiagram
    participant Cliente
    participant WhatsApp
    participant Evolution API
    participant n8n
    participant Chatwoot
    participant PostgreSQL
    participant Redis

    Note over Cliente,Redis: Fluxo de Mensagem Recebida
    Cliente->>WhatsApp: Envia mensagem
    WhatsApp->>Evolution API: Webhook delivery
    Evolution API->>n8n: POST /webhook/whatsapp-incoming
    n8n->>PostgreSQL: Consulta dados do contato
    PostgreSQL-->>n8n: Retorna registro do contato
    n8n->>Chatwoot: POST /api/v1/accounts/{id}/conversations
    Chatwoot-->>n8n: Conversa criada
    n8n->>Chatwoot: POST /api/v1/accounts/{id}/conversations/{id}/messages
    Chatwoot->>PostgreSQL: Salva mensagem
    Chatwoot->>Redis: Cache da conversa
    Chatwoot-->>n8n: Mensagem adicionada

    Note over Cliente,Redis: Fluxo de Resposta do Agente
    Chatwoot->>n8n: POST /webhook/chatwoot-message-created
    n8n->>Evolution API: POST /message/sendText/{instance}
    Evolution API->>WhatsApp: Envia mensagem via API
    WhatsApp->>Cliente: Entrega mensagem
```text

### Componentes Envolvidos

| Componente | Função | Porta/URL |
|------------|--------|-----------|
| **Evolution API** | Gateway WhatsApp Business | `evolution.seudominio.com.br` |
| **n8n** | Orquestrador de workflows | `n8n.seudominio.com.br` |
| **Chatwoot** | Plataforma de atendimento | `chatwoot.seudominio.com.br` |
| **PostgreSQL** | Banco de dados compartilhado | `postgresql:5432` (interno) |
| **Redis** | Cache e fila de mensagens | `redis:6379` (interno) |

### Pré-requisitos

Antes de configurar esta integração, certifique-se de que:

- ✅ Todos os serviços estão rodando e saudáveis (`docker compose ps`)
- ✅ Você tem acesso admin ao n8n, Chatwoot e Evolution API
- ✅ Uma conta WhatsApp Business está disponível para conexão
- ✅ DNS configurado e SSL ativo para todos os domínios
- ✅ Credenciais de API anotadas para cada serviço

---

## Conceitos Fundamentais

### 1. Webhook vs Polling

**Webhook (Usado nesta integração)**:
- Evolution API notifica n8n instantaneamente quando uma mensagem chega
- n8n processa e envia para Chatwoot em tempo real
- **Vantagem**: Latência baixa (~100-500ms)
- **Requisito**: n8n deve estar acessível publicamente

**Polling (Não recomendado)**:
- n8n consultaria periodicamente a Evolution API por novas mensagens
- **Desvantagem**: Latência alta, uso desnecessário de recursos

### 2. Sincronização Bidirecional

Esta integração implementa dois fluxos independentes:

**Fluxo 1: WhatsApp → Chatwoot**
- Cliente envia mensagem no WhatsApp
- Evolution API recebe via webhook do WhatsApp
- n8n cria/atualiza conversa no Chatwoot
- Agente vê mensagem na inbox

**Fluxo 2: Chatwoot → WhatsApp**
- Agente responde no Chatwoot
- Chatwoot notifica n8n via webhook
- n8n envia mensagem via Evolution API
- Cliente recebe no WhatsApp

### 3. Gerenciamento de Contatos

O n8n mantém sincronização de contatos entre sistemas:

- **Criação automática**: Novos números WhatsApp viram contatos no Chatwoot
- **Deduplicação**: Verifica se contato já existe antes de criar
- **Enriquecimento**: Adiciona nome do perfil WhatsApp e avatar
- **Atualização**: Sincroniza mudanças de nome/foto quando detectadas

### 4. Estados de Conversa

| Estado | Descrição | Ação |
|--------|-----------|------|
| **open** | Conversa ativa, aguardando resposta do agente | Aparece na inbox |
| **pending** | Aguardando atribuição a um agente | Fila de atendimento |
| **resolved** | Conversa encerrada pelo agente | Arquivada |
| **snoozed** | Pausada temporariamente | Retorna à inbox após prazo |

---

## Tutorial: Configuração Passo a Passo

### Etapa 1: Configurar Evolution API

#### 1.1. Criar Instância WhatsApp

Acesse a interface web da Evolution API ou use a API REST:

```bash
curl -X POST https://evolution.seudominio.com.br/instance/create \
  -H "apikey: SUA_API_KEY_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "instanceName": "atendimento-principal",
    "qrcode": true,
    "integration": "WHATSAPP-BAILEYS"
  }'
```text

**Resposta esperada**:
```json
{
  "instance": {
    "instanceName": "atendimento-principal",
    "status": "created"
  },
  "qrcode": {
    "code": "base64_qr_code_here",
    "base64": "data:image/png;base64,..."
  }
}
```text

#### 1.2. Conectar WhatsApp via QR Code

1. Abra WhatsApp Business no celular
2. Vá em **Configurações > Aparelhos conectados**
3. Toque em **Conectar um aparelho**
4. Escaneie o QR code retornado pela API
5. Aguarde confirmação de conexão

Verifique o status:
```bash
curl -X GET https://evolution.seudominio.com.br/instance/connectionState/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI"
```text

**Resposta esperada** (conectado):
```json
{
  "instance": "atendimento-principal",
  "state": "open"
}
```text

#### 1.3. Configurar Webhook para n8n

Configure o webhook que notificará o n8n de novos eventos:

```bash
curl -X POST https://evolution.seudominio.com.br/webhook/set/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "enabled": true,
    "url": "https://n8n.seudominio.com.br/webhook/whatsapp-incoming",
    "webhookByEvents": false,
    "events": [
      "MESSAGES_UPSERT",
      "MESSAGES_UPDATE",
      "CONNECTION_UPDATE"
    ]
  }'
```text

**Parâmetros importantes**:
- `enabled: true` - Ativa o webhook
- `url` - URL do webhook no n8n (será criado na Etapa 2)
- `webhookByEvents: false` - Envia todos os eventos para o mesmo endpoint
- `events` - Lista de eventos a monitorar

**Teste o webhook**:
```bash
# Envie uma mensagem de teste para o número WhatsApp
# Verifique os logs do n8n para confirmar recebimento
docker compose logs n8n | grep "whatsapp-incoming"
```text

---

### Etapa 2: Configurar Chatwoot

#### 2.1. Criar Conta e Inbox

1. Acesse `https://chatwoot.seudominio.com.br`
2. Faça login como admin
3. Vá em **Settings > Inboxes**
4. Clique em **Add Inbox**
5. Selecione **API** como tipo de canal
6. Configure:
   - **Inbox Name**: `WhatsApp Principal`
   - **Channel Name**: `whatsapp-principal`
   - **Webhook URL**: `https://n8n.seudominio.com.br/webhook/chatwoot-message-created`

#### 2.2. Obter Credenciais da API

1. Vá em **Settings > Profile Settings**
2. Role até **Access Token**
3. Clique em **Copy** para copiar o token
4. Anote também o **Account ID** (visível na URL: `/app/accounts/{ACCOUNT_ID}/...`)

**Exemplo de credenciais**:
```plaintext
Account ID: 1
API Token: abcdef1234567890abcdef1234567890
Base URL: https://chatwoot.seudominio.com.br
```text

#### 2.3. Criar Equipe de Atendimento

1. Vá em **Settings > Teams**
2. Clique em **Create new team**
3. Configure:
   - **Team Name**: `Suporte WhatsApp`
   - **Description**: `Equipe de atendimento via WhatsApp`
4. Adicione agentes à equipe
5. Atribua a inbox `WhatsApp Principal` à equipe

#### 2.4. Configurar Atribuição Automática

1. Vá em **Settings > Inboxes > WhatsApp Principal**
2. Na aba **Collaborators**, adicione a equipe criada
3. Na aba **Settings**, configure:
   - **Auto Assignment**: `Enabled`
   - **Auto Assignment Limit**: `10` (conversas por agente)

---

### Etapa 3: Criar Workflows no n8n

#### 3.1. Workflow 1: WhatsApp → Chatwoot (Mensagens Recebidas)

1. Acesse `https://n8n.seudominio.com.br`
2. Clique em **+ New Workflow**
3. Nomeie como `WhatsApp to Chatwoot`

**Adicione os seguintes nós**:

##### Nó 1: Webhook Trigger
- **Node**: `Webhook`
- **Configuration**:
  - HTTP Method: `POST`
  - Path: `whatsapp-incoming`
  - Authentication: `None` (Evolution API não suporta auth em webhooks)
  - Respond: `Immediately`

##### Nó 2: Filter - Apenas Mensagens Recebidas
- **Node**: `IF`
- **Configuration**:
  - Condition: `{{$json.event}} === "messages.upsert"`
  - AND: `{{$json.data.key.fromMe}} === false`

##### Nó 3: Extract Contact Info
- **Node**: `Function`
- **Configuration**:
```javascript
// Extrai informações do contato
const message = $input.item.json.data;
const contact = {
  phone: message.key.remoteJid.replace('@s.whatsapp.net', ''),
  name: message.pushName || message.key.remoteJid.split('@')[0],
  instanceName: $input.item.json.instance
};

// Extrai conteúdo da mensagem
let messageContent = '';
if (message.message.conversation) {
  messageContent = message.message.conversation;
} else if (message.message.extendedTextMessage) {
  messageContent = message.message.extendedTextMessage.text;
} else if (message.message.imageMessage) {
  messageContent = '[📷 Imagem]';
} else if (message.message.videoMessage) {
  messageContent = '[🎥 Vídeo]';
} else if (message.message.audioMessage) {
  messageContent = '[🎵 Áudio]';
} else if (message.message.documentMessage) {
  messageContent = '[📄 Documento]';
}

return {
  json: {
    contact: contact,
    message: {
      content: messageContent,
      timestamp: message.messageTimestamp,
      id: message.key.id
    }
  }
};
```text

##### Nó 4: Check if Contact Exists in Chatwoot
- **Node**: `HTTP Request`
- **Configuration**:
  - Method: `POST`
  - URL: `https://chatwoot.seudominio.com.br/api/v1/accounts/1/contacts/search`
  - Headers:
    - `api_access_token`: `{{$env.CHATWOOT_API_TOKEN}}`
    - `Content-Type`: `application/json`
  - Body:
    ```json
    {
      "q": "{{$json.contact.phone}}"
    }
    ```
  - Options > Response > Always Output Data: `true`

##### Nó 5: Create Contact if Not Exists
- **Node**: `IF`
- **Configuration**:
  - Condition: `{{$json.payload.length}} === 0`

**Branch TRUE** (contato não existe):

##### Nó 5a: Create New Contact
- **Node**: `HTTP Request`
- **Configuration**:
  - Method: `POST`
  - URL: `https://chatwoot.seudominio.com.br/api/v1/accounts/1/contacts`
  - Headers:
    - `api_access_token`: `{{$env.CHATWOOT_API_TOKEN}}`
    - `Content-Type`: `application/json`
  - Body:
    ```json
    {
      "inbox_id": 1,
      "name": "{{$node["Extract Contact Info"].json.contact.name}}",
      "phone_number": "+{{$node["Extract Contact Info"].json.contact.phone}}",
      "custom_attributes": {
        "whatsapp_instance": "{{$node["Extract Contact Info"].json.contact.instanceName}}"
      }
    }
    ```

**Branch FALSE** (contato existe):

##### Nó 5b: Use Existing Contact
- **Node**: `Set`
- **Configuration**:
  - Keep Only Set: `true`
  - Values:
    - `payload`: `{{$json.payload[0]}}`

##### Nó 6: Merge Branches
- **Node**: `Merge`
- **Configuration**:
  - Mode: `Combine`
  - Merge By: `Index`

##### Nó 7: Create or Get Conversation
- **Node**: `HTTP Request`
- **Configuration**:
  - Method: `POST`
  - URL: `https://chatwoot.seudominio.com.br/api/v1/accounts/1/conversations`
  - Headers:
    - `api_access_token`: `{{$env.CHATWOOT_API_TOKEN}}`
    - `Content-Type`: `application/json`
  - Body:
    ```json
    {
      "source_id": "{{$node["Extract Contact Info"].json.contact.phone}}",
      "inbox_id": 1,
      "contact_id": "{{$json.payload.id}}",
      "status": "open"
    }
    ```
  - Options > Response:
    - Response Format: `JSON`
    - Ignore SSL Issues: `false`

##### Nó 8: Add Message to Conversation
- **Node**: `HTTP Request`
- **Configuration**:
  - Method: `POST`
  - URL: `https://chatwoot.seudominio.com.br/api/v1/accounts/1/conversations/{{$json.id}}/messages`
  - Headers:
    - `api_access_token`: `{{$env.CHATWOOT_API_TOKEN}}`
    - `Content-Type`: `application/json`
  - Body:
    ```json
    {
      "content": "{{$node["Extract Contact Info"].json.message.content}}",
      "message_type": "incoming",
      "private": false,
      "source_id": "{{$node["Extract Contact Info"].json.message.id}}"
    }
    ```

##### Nó 9: Error Handler
- **Node**: `Function`
- **Configuration** (conecte como `On Error` workflow):
```javascript
// Log erro para debugging
console.error('Erro no workflow WhatsApp→Chatwoot:', {
  error: $input.item.json,
  timestamp: new Date().toISOString()
});

// Retorna resposta para Evolution API
return {
  json: {
    status: 'error',
    message: 'Falha ao processar mensagem'
  }
};
```text

**Salve e ative o workflow**.

---

#### 3.2. Workflow 2: Chatwoot → WhatsApp (Respostas do Agente)

1. Crie um novo workflow: `Chatwoot to WhatsApp`

**Adicione os seguintes nós**:

##### Nó 1: Webhook Trigger
- **Node**: `Webhook`
- **Configuration**:
  - HTTP Method: `POST`
  - Path: `chatwoot-message-created`
  - Authentication: `Header Auth`
    - Name: `api_access_token`
    - Value: `{{$env.CHATWOOT_WEBHOOK_TOKEN}}`
  - Respond: `Immediately`

##### Nó 2: Filter - Apenas Mensagens de Agentes
- **Node**: `IF`
- **Configuration**:
  - Condition: `{{$json.message_type}} === "outgoing"`
  - AND: `{{$json.private}} === false`
  - AND: `{{$json.event}} === "message_created"`

##### Nó 3: Get Contact Phone
- **Node**: `HTTP Request`
- **Configuration**:
  - Method: `GET`
  - URL: `https://chatwoot.seudominio.com.br/api/v1/accounts/1/contacts/{{$json.conversation.contact_id}}`
  - Headers:
    - `api_access_token`: `{{$env.CHATWOOT_API_TOKEN}}`

##### Nó 4: Send Message via Evolution API
- **Node**: `HTTP Request`
- **Configuration**:
  - Method: `POST`
  - URL: `https://evolution.seudominio.com.br/message/sendText/atendimento-principal`
  - Headers:
    - `apikey`: `{{$env.EVOLUTION_API_KEY}}`
    - `Content-Type`: `application/json`
  - Body:
    ```json
    {
      "number": "{{$json.payload.phone_number.replace('+', '')}}",
      "text": "{{$node["Webhook"].json.content}}"
    }
    ```

##### Nó 5: Log Success
- **Node**: `Function`
- **Configuration**:
```javascript
console.log('Mensagem enviada com sucesso:', {
  contact: $json.phone_number,
  message_id: $node["Webhook"].json.id,
  timestamp: new Date().toISOString()
});

return { json: { status: 'sent' } };
```text

**Salve e ative o workflow**.

---

### Etapa 4: Configurar Variáveis de Ambiente no n8n

Para evitar hardcoding de credenciais, configure variáveis de ambiente:

1. Edite o arquivo `.env` no servidor:
```bash
nano /home/usuario/borgstack/.env
```text

2. Adicione as seguintes variáveis:
```bash
# Chatwoot API
CHATWOOT_API_TOKEN=abcdef1234567890abcdef1234567890
CHATWOOT_ACCOUNT_ID=1
CHATWOOT_WEBHOOK_TOKEN=token_seguro_para_webhooks

# Evolution API
EVOLUTION_API_KEY=sua_api_key_evolution
EVOLUTION_INSTANCE_NAME=atendimento-principal
```text

3. Reinicie o n8n para carregar as novas variáveis:
```bash
docker compose restart n8n
```text

4. No n8n, acesse as variáveis via:
```javascript
{{$env.CHATWOOT_API_TOKEN}}
{{$env.EVOLUTION_API_KEY}}
```text

---

### Etapa 5: Testes End-to-End

#### Teste 1: Mensagem WhatsApp → Chatwoot

1. **Envie uma mensagem** do WhatsApp para o número conectado
2. **Verifique no n8n**:
   ```bash
   docker compose logs n8n | grep "whatsapp-incoming" | tail -20
   ```
   - Deve aparecer: `Webhook received: POST /webhook/whatsapp-incoming`
3. **Verifique no Chatwoot**:
   - Acesse a inbox `WhatsApp Principal`
   - Deve aparecer uma nova conversa com a mensagem recebida
4. **Verifique o contato**:
   - Vá em **Contacts**
   - Deve existir um contato com o número do WhatsApp

**Logs esperados (n8n)**:
```text
2025-10-08 10:15:32 Webhook received: POST /webhook/whatsapp-incoming
2025-10-08 10:15:32 Processing message from +5511999998888
2025-10-08 10:15:33 Contact created in Chatwoot: ID 42
2025-10-08 10:15:33 Conversation created: ID 101
2025-10-08 10:15:33 Message added to conversation 101
```text

#### Teste 2: Resposta Chatwoot → WhatsApp

1. **Responda à conversa** no Chatwoot como agente
2. **Verifique no n8n**:
   ```bash
   docker compose logs n8n | grep "chatwoot-message-created" | tail -20
   ```
   - Deve aparecer: `Webhook received: POST /webhook/chatwoot-message-created`
3. **Verifique no WhatsApp**:
   - A mensagem deve chegar no WhatsApp do cliente em ~1-3 segundos

**Logs esperados (n8n)**:
```text
2025-10-08 10:16:45 Webhook received: POST /webhook/chatwoot-message-created
2025-10-08 10:16:45 Sending message to Evolution API: +5511999998888
2025-10-08 10:16:46 Message sent successfully: ID wamid.xyz123
```text

#### Teste 3: Múltiplas Conversas Simultâneas

1. Envie mensagens de **3 números WhatsApp diferentes**
2. Verifique se aparecem **3 conversas distintas** no Chatwoot
3. Responda a todas as 3 conversas
4. Confirme que cada resposta chegou ao número correto

#### Teste 4: Tipos de Mídia

Teste envio de diferentes tipos de conteúdo:

| Tipo | De WhatsApp → Chatwoot | De Chatwoot → WhatsApp |
|------|------------------------|------------------------|
| Texto | ✅ Suportado | ✅ Suportado |
| Imagem | ⚠️ Aparece como `[📷 Imagem]` | ❌ Não suportado (v1) |
| Áudio | ⚠️ Aparece como `[🎵 Áudio]` | ❌ Não suportado (v1) |
| Vídeo | ⚠️ Aparece como `[🎥 Vídeo]` | ❌ Não suportado (v1) |
| Documento | ⚠️ Aparece como `[📄 Documento]` | ❌ Não suportado (v1) |

> **Nota**: Suporte completo a mídias requer workflow adicional para download/upload de arquivos via Evolution API e Chatwoot API. Isso será implementado em versões futuras.

---

## Integração Avançada

### Respostas Automáticas (Fora do Horário)

Adicione lógica ao workflow `WhatsApp to Chatwoot` para responder automaticamente fora do expediente:

**Nó adicional após "Extract Contact Info"**:

##### Check Business Hours
- **Node**: `Function`
- **Configuration**:
```javascript
const now = new Date();
const hour = now.getHours();
const day = now.getDay(); // 0 = Domingo, 6 = Sábado

const isWeekend = (day === 0 || day === 6);
const isBusinessHours = (hour >= 9 && hour < 18);

if (isWeekend || !isBusinessHours) {
  return {
    json: {
      sendAutoReply: true,
      message: 'Olá! Nosso horário de atendimento é de segunda a sexta, das 9h às 18h. Sua mensagem será respondida no próximo dia útil. 🕐'
    }
  };
} else {
  return {
    json: {
      sendAutoReply: false
    }
  };
}
```text

##### Send Auto Reply
- **Node**: `IF` (branch TRUE de sendAutoReply)
- **Action**: `HTTP Request` para Evolution API enviando mensagem automática

---

### Tags Automáticas por Palavra-Chave

Adicione nó para classificar conversas automaticamente:

##### Auto-Tag Conversation
- **Node**: `Function`
- **Configuration**:
```javascript
const content = $node["Extract Contact Info"].json.message.content.toLowerCase();
let tags = [];

// Regras de classificação
if (content.includes('suporte') || content.includes('ajuda') || content.includes('problema')) {
  tags.push('suporte');
}
if (content.includes('venda') || content.includes('comprar') || content.includes('preço')) {
  tags.push('vendas');
}
if (content.includes('cancelar') || content.includes('reembolso')) {
  tags.push('financeiro');
}
if (content.includes('urgente') || content.includes('importante')) {
  tags.push('prioridade-alta');
}

return {
  json: {
    tags: tags,
    conversationId: $node["Create or Get Conversation"].json.id
  }
};
```text

##### Apply Tags to Conversation
- **Node**: `HTTP Request`
- **Configuration**:
  - Method: `POST`
  - URL: `https://chatwoot.seudominio.com.br/api/v1/accounts/1/conversations/{{$json.conversationId}}/labels`
  - Body: `{"labels": {{$json.tags}}}`

---

### Notificações para o Agente (Via Telegram)

Notifique agentes em caso de mensagens urgentes:

##### Detect Urgent Keywords
- **Node**: `IF`
- **Condition**: `{{$json.tags}}` contains `prioridade-alta`

##### Send Telegram Notification
- **Node**: `HTTP Request` (Telegram Bot API)
- **Configuration**:
  - Method: `POST`
  - URL: `https://api.telegram.org/bot{{$env.TELEGRAM_BOT_TOKEN}}/sendMessage`
  - Body:
    ```json
    {
      "chat_id": "{{$env.TELEGRAM_CHAT_ID}}",
      "text": "🚨 URGENTE: Nova mensagem prioritária de {{$node["Extract Contact Info"].json.contact.name}}\n\nMensagem: {{$node["Extract Contact Info"].json.message.content}}",
      "parse_mode": "Markdown"
    }
    ```

---

## Solução de Problemas

### Problema 1: Webhook não recebe mensagens

**Sintomas**:
- Mensagens enviadas no WhatsApp não aparecem no Chatwoot
- Logs do n8n não mostram chamadas ao webhook

**Diagnóstico**:
```bash
# 1. Verifique se o webhook está registrado
curl -X GET https://evolution.seudominio.com.br/webhook/find/atendimento-principal \
  -H "apikey: SUA_API_KEY"

# 2. Teste o webhook manualmente
curl -X POST https://n8n.seudominio.com.br/webhook/whatsapp-incoming \
  -H "Content-Type: application/json" \
  -d '{
    "event": "messages.upsert",
    "instance": "atendimento-principal",
    "data": {
      "key": {"remoteJid": "5511999998888@s.whatsapp.net", "fromMe": false, "id": "TEST123"},
      "message": {"conversation": "Teste manual"},
      "pushName": "Usuario Teste",
      "messageTimestamp": "1696777200"
    }
  }'

# 3. Verifique logs do n8n
docker compose logs n8n --tail 50 | grep webhook
```text

**Soluções**:

1. **Webhook não registrado**:
   ```bash
   # Re-registre o webhook
   curl -X POST https://evolution.seudominio.com.br/webhook/set/atendimento-principal \
     -H "apikey: SUA_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "enabled": true,
       "url": "https://n8n.seudominio.com.br/webhook/whatsapp-incoming",
       "webhookByEvents": false,
       "events": ["MESSAGES_UPSERT"]
     }'
   ```

2. **n8n não acessível**:
   - Verifique DNS: `dig n8n.seudominio.com.br`
   - Verifique SSL: `curl -I https://n8n.seudominio.com.br`
   - Verifique container: `docker compose ps n8n`

3. **Workflow desativado**:
   - Acesse n8n UI
   - Verifique se workflow `WhatsApp to Chatwoot` está **Active**

---

### Problema 2: Mensagens duplicadas no Chatwoot

**Sintomas**:
- Mesma mensagem aparece 2-3 vezes na conversa
- Múltiplas conversas criadas para o mesmo contato

**Causa**:
- Evolution API enviando webhook múltiplas vezes
- n8n processando evento duplicado
- Falta de idempotência no workflow

**Solução**:

Adicione nó de deduplicação antes de criar mensagem:

##### Check if Message Already Exists
- **Node**: `HTTP Request`
- **Configuration**:
  - Method: `GET`
  - URL: `https://chatwoot.seudominio.com.br/api/v1/accounts/1/conversations/{{$json.id}}/messages`
  - Headers: `api_access_token: {{$env.CHATWOOT_API_TOKEN}}`

##### Filter Duplicates
- **Node**: `Function`
- **Configuration**:
```javascript
const messages = $json.payload;
const newMessageId = $node["Extract Contact Info"].json.message.id;

// Verifica se message.source_id já existe
const exists = messages.some(msg => msg.source_id === newMessageId);

if (exists) {
  console.log('Mensagem duplicada detectada, ignorando:', newMessageId);
  return null; // Interrompe o fluxo
}

return $input.item;
```text

---

### Problema 3: Respostas não chegam no WhatsApp

**Sintomas**:
- Agente responde no Chatwoot
- Webhook é acionado no n8n
- Mensagem não chega no WhatsApp do cliente

**Diagnóstico**:
```bash
# 1. Verifique logs do workflow Chatwoot→WhatsApp
docker compose logs n8n | grep "chatwoot-message-created"

# 2. Verifique se Evolution API recebeu a request
docker compose logs evolution | grep "sendText"

# 3. Teste envio manual via Evolution API
curl -X POST https://evolution.seudominio.com.br/message/sendText/atendimento-principal \
  -H "apikey: SUA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "number": "5511999998888",
    "text": "Teste de envio manual"
  }'
```text

**Soluções**:

1. **Número de telefone incorreto**:
   - Evolution API espera formato: `5511999998888` (sem `+` ou espaços)
   - Chatwoot armazena como: `+55 11 99999-8888`
   - **Fix**: Adicione normalização no workflow:
     ```javascript
     const phone = $json.phone_number.replace(/\D/g, ''); // Remove tudo que não é dígito
     ```

2. **WhatsApp desconectado**:
   ```bash
   # Verifique status da conexão
   curl -X GET https://evolution.seudominio.com.br/instance/connectionState/atendimento-principal \
     -H "apikey: SUA_API_KEY"
   ```
   - Se `state !== "open"`, reconecte via QR code

3. **Janela de 24 horas expirada** (WhatsApp Business Policy):
   - WhatsApp permite respostas apenas **24h após última mensagem do cliente**
   - Após 24h, só é possível enviar **template messages aprovados**
   - **Solução**: Solicite que cliente envie nova mensagem

---

### Problema 4: Contatos não sincronizados

**Sintomas**:
- Contatos criados no Chatwoot sem nome (só número)
- Avatar do WhatsApp não aparece
- Duplicação de contatos

**Diagnóstico**:
```bash
# 1. Verifique se API retorna pushName
docker compose logs n8n | grep "pushName"

# 2. Consulte contato no Chatwoot
curl -X POST https://chatwoot.seudominio.com.br/api/v1/accounts/1/contacts/search \
  -H "api_access_token: $TOKEN" \
  -d '{"q": "5511999998888"}'
```text

**Soluções**:

1. **Nome não disponível**:
   - Alguns contatos WhatsApp não têm `pushName` configurado
   - **Fix**: Use número como fallback:
     ```javascript
     const name = message.pushName || `WhatsApp ${contact.phone.slice(-4)}`;
     ```

2. **Avatar não sincronizado**:
   - Adicione nó para baixar foto de perfil:
     ```bash
     curl -X GET https://evolution.seudominio.com.br/chat/fetchProfilePictureUrl/atendimento-principal \
       -H "apikey: $KEY" \
       -d '{"number": "5511999998888"}'
     ```
   - Atualize contato no Chatwoot com `avatar_url`

3. **Deduplicação falhou**:
   - Busca por telefone não encontrou contato existente
   - **Causa**: Formatos diferentes (`+5511999998888` vs `5511999998888`)
   - **Fix**: Normalize antes de buscar:
     ```javascript
     const normalizedPhone = phone.replace(/\D/g, '');
     ```

---

### Problema 5: Performance degradada com alto volume

**Sintomas**:
- Latência alta (>5s) entre mensagem WhatsApp e aparecimento no Chatwoot
- n8n mostrando execuções em fila
- Timeouts em chamadas API

**Diagnóstico**:
```bash
# 1. Verifique carga do n8n
docker stats n8n --no-stream

# 2. Verifique execuções em fila
curl -X GET https://n8n.seudominio.com.br/rest/executions?status=running \
  -H "X-N8N-API-KEY: $KEY"

# 3. Verifique latência do PostgreSQL
docker compose exec postgresql psql -U postgres -d chatwoot_db -c "
  SELECT count(*) as active_connections
  FROM pg_stat_activity
  WHERE state = 'active';
"
```text

**Soluções**:

1. **Aumentar workers do n8n**:
   - Edite `docker-compose.yml`:
     ```yaml
     n8n:
       environment:
         - EXECUTIONS_PROCESS=main
         - N8N_CONCURRENCY_PRODUCTION_LIMIT=10  # Aumentar de 5 para 10
     ```
   - Reinicie: `docker compose restart n8n`

2. **Otimizar consultas ao PostgreSQL**:
   - Adicione índice em `chatwoot_db.contacts.phone_number`:
     ```sql
     CREATE INDEX idx_contacts_phone ON contacts(phone_number);
     ```

3. **Implementar cache no Redis**:
   - Cache contatos recentes para evitar consultas repetidas ao banco
   - TTL: 600s (10 minutos)
   - **Nó adicional antes de "Check if Contact Exists"**:
     ```javascript
     // Verificar cache Redis
     const redis = require('redis').createClient({url: 'redis://redis:6379'});
     const cached = await redis.get(`contact:${phone}`);
     if (cached) return JSON.parse(cached);
     ```

4. **Rate limiting na Evolution API**:
   - Limite webhook delivery para 10 req/s
   - Configure no `.env` da Evolution API:
     ```bash
     WEBHOOK_RATE_LIMIT=10
     WEBHOOK_RATE_INTERVAL=1000
     ```

---

### Problema 6: Erros de autenticação

**Sintomas**:
- `401 Unauthorized` em chamadas ao Chatwoot ou Evolution API
- Workflow falha em nós de HTTP Request

**Diagnóstico**:
```bash
# 1. Teste token Chatwoot
curl -X GET https://chatwoot.seudominio.com.br/api/v1/accounts/1/conversations \
  -H "api_access_token: $CHATWOOT_API_TOKEN"

# 2. Teste API key Evolution
curl -X GET https://evolution.seudominio.com.br/instance/fetchInstances \
  -H "apikey: $EVOLUTION_API_KEY"

# 3. Verifique variáveis de ambiente no n8n
docker compose exec n8n env | grep -E "(CHATWOOT|EVOLUTION)"
```text

**Soluções**:

1. **Token expirado/inválido**:
   - Regenere token no Chatwoot: **Settings > Profile > Access Token > Regenerate**
   - Atualize `.env`:
     ```bash
     CHATWOOT_API_TOKEN=novo_token_aqui
     ```
   - Reinicie n8n: `docker compose restart n8n`

2. **API key não carregada**:
   - Verifique se `.env` está no diretório correto
   - Confirme permissões: `chmod 600 .env`
   - Force reload: `docker compose down && docker compose up -d`

3. **Credenciais hardcoded no workflow**:
   - **Problema de segurança!**
   - Substitua por variáveis de ambiente:
     - Antes: `"api_access_token": "abc123"`
     - Depois: `"api_access_token": "{{$env.CHATWOOT_API_TOKEN}}"`

---

## Monitoramento e Logs

### Comandos Úteis de Diagnóstico

```bash
# Ver últimos 100 webhooks recebidos no n8n
docker compose logs n8n --tail 100 | grep "Webhook received"

# Ver execuções com erro
docker compose logs n8n --tail 100 | grep "ERROR"

# Ver mensagens enviadas via Evolution API
docker compose logs evolution --tail 50 | grep "sendText"

# Ver novas conversas criadas no Chatwoot
docker compose logs chatwoot --tail 50 | grep "Conversation created"

# Monitorar em tempo real (todos os serviços)
docker compose logs -f n8n evolution chatwoot | grep -E "(webhook|message|error)"
```text

### Métricas de Performance

Monitore estas métricas para garantir saúde da integração:

| Métrica | Comando | Alvo | Crítico |
|---------|---------|------|---------|
| **Latência E2E** | Tempo entre envio WhatsApp e aparição no Chatwoot | < 2s | > 10s |
| **Taxa de Erro** | `docker compose logs n8n | grep ERROR | wc -l` | < 1% | > 5% |
| **Webhooks pendentes** | `curl -X GET n8n.../rest/executions?status=running` | < 5 | > 20 |
| **Conexões PostgreSQL** | `SELECT count(*) FROM pg_stat_activity WHERE state='active'` | < 100 | > 180 |
| **Uso de Redis** | `docker compose exec redis redis-cli INFO memory` | < 500MB | > 2GB |

---

## Segurança

### Boas Práticas

1. **Proteja webhooks com autenticação**:
   ```yaml
   # No workflow Chatwoot→WhatsApp
   Webhook Authentication: Header Auth
   Header Name: X-Webhook-Token
   Header Value: {{$env.CHATWOOT_WEBHOOK_TOKEN}}
   ```

2. **Use HTTPS em todos os endpoints**:
   - Caddy gerencia SSL automaticamente
   - Nunca use `http://` para webhooks

3. **Rotacione credenciais regularmente**:
   - A cada 90 dias: tokens de API, API keys
   - Documente processo de rotação

4. **Limite acesso à Evolution API**:
   - Configure IP whitelist se possível
   - Use API keys diferentes para staging/produção

5. **Monitore logs de segurança**:
   ```bash
   # Detectar tentativas de acesso não autorizado
   docker compose logs caddy | grep "401\|403"
   ```

### Conformidade LGPD

Esta integração processa dados pessoais (números de telefone, mensagens). Garanta:

1. **Consentimento explícito**:
   - Informe usuários que mensagens são armazenadas no Chatwoot
   - Implemente opt-out se necessário

2. **Retenção de dados**:
   - Configure política de exclusão automática de conversas antigas
   - Chatwoot: **Settings > Account Settings > Auto-resolve conversations after X days**

3. **Direito ao esquecimento**:
   - Implemente processo para deletar dados de um contato:
     ```bash
     # Deletar contato e todas as suas conversas
     curl -X DELETE https://chatwoot.seudominio.com.br/api/v1/accounts/1/contacts/{contact_id} \
       -H "api_access_token: $TOKEN"
     ```

4. **Criptografia**:
   - Dados em trânsito: HTTPS (Caddy)
   - Dados em repouso: PostgreSQL em volume criptografado (LUKS recomendado para produção)

---

## Recursos Adicionais

### Documentação Oficial

- **Evolution API**: https://doc.evolution-api.com/
- **Chatwoot**: https://www.chatwoot.com/docs/
- **n8n Webhooks**: https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.webhook/
- **WhatsApp Business Policy**: https://developers.facebook.com/docs/whatsapp/messaging-limits

### Guias Relacionados

- [n8n - Automação de Workflows](../03-services/n8n.md)
- [Chatwoot - Plataforma de Atendimento](../03-services/chatwoot.md)
- [Evolution API - Gateway WhatsApp](../03-services/evolution-api.md)
- [PostgreSQL - Banco de Dados](../03-services/postgresql.md)
- [Redis - Cache e Filas](../03-services/redis.md)

### Suporte e Comunidade

- **BorgStack Issues**: https://github.com/seu-usuario/borgstack/issues
- **n8n Community**: https://community.n8n.io/
- **Chatwoot Discord**: https://discord.gg/chatwoot
- **Evolution API Telegram**: https://t.me/evolutionapi

---

## Próximos Passos

Após concluir esta integração básica, considere:

1. **Suporte a mídias** - Implementar download/upload de imagens, áudios, vídeos
2. **Chatbot integrado** - Adicionar respostas automáticas via n8n AI nodes
3. **Métricas e dashboards** - Exportar dados para Grafana/Prometheus
4. **Integração com CRM** - Sincronizar contatos com Directus ou outro CRM
5. **Multi-atendentes** - Configurar distribuição round-robin de conversas
6. **Templates WhatsApp** - Criar templates aprovados para mensagens proativas

---

**Última atualização**: 2025-10-08
**Versão do guia**: 1.0
**Compatibilidade**: BorgStack v1.0, Evolution API v2.2.3, Chatwoot v4.6.0, n8n 1.112.6
