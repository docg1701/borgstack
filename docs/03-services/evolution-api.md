# Evolution API - Integração WhatsApp Business

## Visão Geral

### O que é Evolution API?

A Evolution API é uma API de integração WhatsApp Business de código aberto que permite conectar aplicações ao WhatsApp de forma programática. Ela fornece endpoints REST completos para gerenciar mensagens, conversas, contatos e grupos do WhatsApp.

No contexto do BorgStack, a Evolution API serve como ponte entre o WhatsApp e os demais serviços da plataforma (n8n, Chatwoot, PostgreSQL), permitindo automação de atendimento, integração omnichannel e workflows complexos.

### Casos de Uso no BorgStack

1. **Atendimento Omnichannel**: Integração com Chatwoot para centralizar atendimento WhatsApp
2. **Automação de Mensagens**: Workflows n8n para respostas automáticas e chatbots
3. **Notificações**: Envio de alertas e notificações via WhatsApp
4. **Gestão de Contatos**: Sincronização de contatos com PostgreSQL
5. **Webhooks**: Recebimento de eventos em tempo real (mensagens, status de conexão)

---

## Configuração Inicial

### Primeiro Acesso

A Evolution API no BorgStack está configurada com as seguintes credenciais padrão:

```bash
URL: https://evolution.seudominio.com.br
API Key: (definida em EVOLUTION_API_KEY no arquivo .env)
```

### Verificando Status da API

```bash
# Verificar se o container está em execução
docker compose ps evolution-api

# Verificar logs
docker compose logs -f evolution-api

# Testar conectividade
curl -X GET https://evolution.seudominio.com.br/instance/fetchInstances \
  -H "apikey: SUA_API_KEY_AQUI"
```

---

## Conceitos Fundamentais

### 1. Instância (Instance)

Uma **instância** representa uma conexão única com o WhatsApp. Cada instância:
- Possui seu próprio QR Code ou código de pareamento
- Mantém uma sessão independente com o WhatsApp
- Pode ter webhooks e integrações específicas
- É identificada por um nome único (instanceName)

**Tipos de Integração**:
- `WHATSAPP-BAILEYS`: WhatsApp pessoal ou business (via QR Code)
- `WHATSAPP-BUSINESS`: WhatsApp Cloud API (requer Business Manager)

### 2. Webhooks

**Webhooks** são URLs que recebem notificações em tempo real sobre eventos da instância:
- Novas mensagens (MESSAGES_UPSERT)
- Atualizações de mensagens (MESSAGES_UPDATE)
- Mudanças de conexão (CONNECTION_UPDATE)
- Atualização de QR Code (QRCODE_UPDATED)
- Novos contatos e grupos

### 3. Integrações

A Evolution API suporta integrações nativas com:
- **Chatwoot**: Sincronização bidirecional de mensagens
- **Typebot**: Chatbots visuais
- **OpenAI**: Transcrição de áudio e respostas automáticas
- **RabbitMQ/SQS**: Filas de eventos
- **S3/Minio**: Armazenamento de mídias

### 4. Eventos

Lista completa de eventos disponíveis para webhooks:
- `APPLICATION_STARTUP`: API iniciada
- `QRCODE_UPDATED`: QR Code atualizado
- `MESSAGES_UPSERT`: Nova mensagem recebida
- `MESSAGES_UPDATE`: Mensagem atualizada (lida, entregue)
- `MESSAGES_DELETE`: Mensagem deletada
- `SEND_MESSAGE`: Mensagem enviada
- `CONTACTS_UPSERT`: Novo contato
- `CONNECTION_UPDATE`: Mudança no status de conexão
- `GROUPS_UPSERT`: Novo grupo
- `CALL`: Chamada recebida

---

## Tutorial Passo a Passo: Criando Primeira Instância

### Passo 1: Criar Instância WhatsApp

```bash
curl -X POST https://evolution.seudominio.com.br/instance/create \
  -H "apikey: SUA_API_KEY_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "instanceName": "atendimento-principal",
    "qrcode": true,
    "integration": "WHATSAPP-BAILEYS"
  }'
```

**Resposta:**
```json
{
  "instance": {
    "instanceName": "atendimento-principal",
    "status": "created"
  },
  "hash": {
    "apikey": "UUID-GERADO-AUTOMATICAMENTE"
  },
  "qrcode": {
    "code": "data:image/png;base64,iVBORw0KG...",
    "base64": "iVBORw0KG..."
  }
}
```

### Passo 2: Escanear QR Code

Existem duas formas de conectar:

**Opção A: QR Code (WhatsApp Pessoal/Business)**
1. Abra o WhatsApp no celular
2. Vá em **Configurações > Aparelhos Conectados**
3. Toque em **Conectar um aparelho**
4. Escaneie o QR Code retornado pela API

**Opção B: Código de Pareamento (WhatsApp Pessoal/Business)**
```bash
curl -X POST https://evolution.seudominio.com.br/instance/create \
  -H "apikey: SUA_API_KEY_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "instanceName": "atendimento-principal",
    "number": "5511987654321",
    "qrcode": false,
    "integration": "WHATSAPP-BAILEYS"
  }'
```

Isso retornará um código de 8 dígitos para inserir no WhatsApp.

### Passo 3: Verificar Status da Conexão

```bash
curl -X GET https://evolution.seudominio.com.br/instance/connectionState/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI"
```

**Resposta:**
```json
{
  "instance": {
    "instanceName": "atendimento-principal",
    "state": "open"
  }
}
```

**Estados Possíveis**:
- `connecting`: Conectando ao WhatsApp
- `open`: Conectado e pronto
- `close`: Desconectado

### Passo 4: Enviar Primeira Mensagem

```bash
curl -X POST https://evolution.seudominio.com.br/message/sendText/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "number": "5511987654321",
    "text": "Olá! Esta é minha primeira mensagem via Evolution API."
  }'
```

---

## Configuração de Webhooks

### Webhook Global (Todas as Instâncias)

Configure no arquivo `.env`:

```bash
# Habilitar webhook global
WEBHOOK_GLOBAL_ENABLED=true

# URL que receberá os eventos
WEBHOOK_GLOBAL_URL=https://n8n.seudominio.com.br/webhook/evolution

# Eventos a serem enviados
WEBHOOK_EVENTS_MESSAGES_UPSERT=true
WEBHOOK_EVENTS_MESSAGES_UPDATE=true
WEBHOOK_EVENTS_CONNECTION_UPDATE=true
WEBHOOK_EVENTS_QRCODE_UPDATED=true
```

Reinicie o container:
```bash
docker compose restart evolution-api
```

### Webhook por Instância

Configure webhook específico para uma instância:

```bash
curl -X POST https://evolution.seudominio.com.br/webhook/set/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://n8n.seudominio.com.br/webhook/whatsapp-atendimento",
    "enabled": true,
    "webhookByEvents": false,
    "events": [
      "QRCODE_UPDATED",
      "MESSAGES_UPSERT",
      "MESSAGES_UPDATE",
      "CONNECTION_UPDATE",
      "SEND_MESSAGE"
    ]
  }'
```

### Verificar Webhook Configurado

```bash
curl -X GET https://evolution.seudominio.com.br/webhook/find/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI"
```

**Resposta:**
```json
{
  "enabled": true,
  "url": "https://n8n.seudominio.com.br/webhook/whatsapp-atendimento",
  "webhookByEvents": false,
  "events": [
    "QRCODE_UPDATED",
    "MESSAGES_UPSERT",
    "MESSAGES_UPDATE",
    "CONNECTION_UPDATE",
    "SEND_MESSAGE"
  ]
}
```

### Exemplo de Payload do Webhook

Quando uma nova mensagem chega, o webhook recebe:

```json
{
  "event": "messages.upsert",
  "instance": "atendimento-principal",
  "data": {
    "key": {
      "remoteJid": "5511987654321@s.whatsapp.net",
      "fromMe": false,
      "id": "3EB0C7F4E93B2D5F1E90"
    },
    "message": {
      "conversation": "Olá, preciso de ajuda!"
    },
    "messageType": "conversation",
    "messageTimestamp": 1710364800,
    "pushName": "João Silva",
    "status": "RECEIVED"
  },
  "destination": "https://n8n.seudominio.com.br/webhook/whatsapp-atendimento",
  "date_time": "2025-03-13T18:00:00.000Z",
  "sender": "5511987654321",
  "server_url": "https://evolution.seudominio.com.br",
  "apikey": "UUID-DA-INSTANCIA"
}
```

---

## Integração com Chatwoot

A Evolution API possui integração nativa com o Chatwoot, permitindo:
- Sincronização bidirecional de mensagens
- Criação automática de conversas
- Importação de histórico de mensagens
- Sincronização de status (lido, entregue)

### Opção 1: Configurar na Criação da Instância

```bash
curl -X POST https://evolution.seudominio.com.br/instance/create \
  -H "apikey: SUA_API_KEY_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "instanceName": "atendimento-chatwoot",
    "qrcode": true,
    "integration": "WHATSAPP-BAILEYS",
    "chatwootAccountId": "1",
    "chatwootToken": "SEU_TOKEN_CHATWOOT",
    "chatwootUrl": "https://chatwoot.seudominio.com.br",
    "chatwootSignMsg": true,
    "chatwootReopenConversation": true,
    "chatwootConversationPending": false,
    "chatwootImportContacts": true,
    "chatwootNameInbox": "WhatsApp Principal",
    "chatwootMergeBrazilContacts": true,
    "chatwootImportMessages": true,
    "chatwootDaysLimitImportMessages": 7,
    "chatwootOrganization": "Minha Empresa",
    "chatwootLogo": "https://seudominio.com.br/logo.png"
  }'
```

### Opção 2: Configurar em Instância Existente

```bash
curl -X POST https://evolution.seudominio.com.br/chatwoot/set/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "enabled": true,
    "accountId": "1",
    "token": "SEU_TOKEN_CHATWOOT",
    "url": "https://chatwoot.seudominio.com.br",
    "signMsg": true,
    "reopenConversation": true,
    "conversationPending": false,
    "nameInbox": "WhatsApp Principal",
    "mergeBrazilContacts": true,
    "importContacts": true,
    "importMessages": true,
    "daysLimitImportMessages": 7,
    "signDelimiter": "\n",
    "autoCreate": true,
    "organization": "Minha Empresa",
    "logo": "https://seudominio.com.br/logo.png"
  }'
```

### Parâmetros da Integração Chatwoot

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `enabled` | boolean | Ativa/desativa a integração |
| `accountId` | string | ID da conta no Chatwoot |
| `token` | string | Token de acesso do Chatwoot (Admin) |
| `url` | string | URL do Chatwoot (sem `/` no final) |
| `signMsg` | boolean | Adiciona assinatura do atendente |
| `reopenConversation` | boolean | Reabre mesma conversa ou cria nova |
| `conversationPending` | boolean | Inicia conversas como pendentes |
| `nameInbox` | string | Nome da inbox no Chatwoot |
| `mergeBrazilContacts` | boolean | Unifica contatos BR com 9º dígito |
| `importContacts` | boolean | Importa contatos do WhatsApp |
| `importMessages` | boolean | Importa histórico de mensagens |
| `daysLimitImportMessages` | number | Limite de dias para importação |
| `autoCreate` | boolean | Cria inbox automaticamente |

### Verificar Integração Chatwoot

```bash
curl -X GET https://evolution.seudominio.com.br/chatwoot/find/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI"
```

---

## Integração com n8n

### Criar Workflow n8n para Receber Mensagens

1. **Criar Webhook Trigger no n8n**:
   - Adicione nó **Webhook**
   - Método: `POST`
   - Caminho: `whatsapp-messages`
   - Copie a URL gerada (ex: `https://n8n.seudominio.com.br/webhook/whatsapp-messages`)

2. **Configurar Webhook na Evolution API**:
```bash
curl -X POST https://evolution.seudominio.com.br/webhook/set/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://n8n.seudominio.com.br/webhook/whatsapp-messages",
    "enabled": true,
    "events": ["MESSAGES_UPSERT"]
  }'
```

3. **Processar Mensagem no n8n**:

Exemplo de workflow:

```
Webhook → Function (Extrair Dados) → PostgreSQL (Salvar) → HTTP Request (Responder)
```

**Function Node (Extrair dados da mensagem)**:
```javascript
// Extrair dados relevantes do webhook
const webhookData = $input.item.json;

return {
  sender: webhookData.sender,
  message: webhookData.data.message.conversation || '',
  timestamp: webhookData.data.messageTimestamp,
  instance: webhookData.instance,
  messageId: webhookData.data.key.id
};
```

**HTTP Request Node (Enviar resposta automática)**:
```json
{
  "method": "POST",
  "url": "https://evolution.seudominio.com.br/message/sendText/{{ $json.instance }}",
  "headers": {
    "apikey": "SUA_API_KEY_AQUI",
    "Content-Type": "application/json"
  },
  "body": {
    "number": "{{ $json.sender }}",
    "text": "Obrigado pela mensagem! Em breve retornaremos."
  }
}
```

### Diagrama de Integração n8n + Evolution API

```mermaid
sequenceDiagram
    participant WA as WhatsApp
    participant EVO as Evolution API
    participant N8N as n8n
    participant PG as PostgreSQL

    WA->>EVO: Nova Mensagem
    EVO->>N8N: Webhook (MESSAGES_UPSERT)
    N8N->>N8N: Processar Mensagem
    N8N->>PG: Salvar no Banco
    N8N->>EVO: Enviar Resposta
    EVO->>WA: Entregar Resposta
```

---

## Envio de Mensagens

### Mensagem de Texto

```bash
curl -X POST https://evolution.seudominio.com.br/message/sendText/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "number": "5511987654321",
    "text": "Olá! Como posso ajudá-lo?"
  }'
```

### Mensagem com Mídia (Imagem)

```bash
curl -X POST https://evolution.seudominio.com.br/message/sendMedia/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "number": "5511987654321",
    "mediatype": "image",
    "media": "https://example.com/imagem.jpg",
    "caption": "Confira nossa nova promoção!"
  }'
```

### Mensagem de Áudio

```bash
curl -X POST https://evolution.seudominio.com.br/message/sendWhatsAppAudio/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "number": "5511987654321",
    "audio": "https://example.com/audio.mp3"
  }'
```

### Mensagem de Documento

```bash
curl -X POST https://evolution.seudominio.com.br/message/sendMedia/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "number": "5511987654321",
    "mediatype": "document",
    "media": "https://example.com/contrato.pdf",
    "fileName": "Contrato_2025.pdf"
  }'
```

### Verificar Número é WhatsApp

```bash
curl -X POST https://evolution.seudominio.com.br/chat/whatsappNumbers/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "numbers": [
      "5511987654321",
      "5511912345678"
    ]
  }'
```

**Resposta:**
```json
[
  {
    "jid": "5511987654321@s.whatsapp.net",
    "exists": true
  },
  {
    "jid": "5511912345678@s.whatsapp.net",
    "exists": false
  }
]
```

---

## Gerenciamento de Instâncias

### Listar Todas as Instâncias

```bash
curl -X GET https://evolution.seudominio.com.br/instance/fetchInstances \
  -H "apikey: SUA_API_KEY_AQUI"
```

### Deletar Instância

```bash
curl -X DELETE https://evolution.seudominio.com.br/instance/delete/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI"
```

### Desconectar Instância (Logout)

```bash
curl -X DELETE https://evolution.seudominio.com.br/instance/logout/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI"
```

### Restart Instância

```bash
curl -X PUT https://evolution.seudominio.com.br/instance/restart/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI"
```

---

## Integração com PostgreSQL

A Evolution API no BorgStack está configurada para salvar dados no PostgreSQL compartilhado:

```bash
# No arquivo .env
DATABASE_ENABLED=true
DATABASE_CONNECTION_URI=postgresql://evolution:senha_segura@postgresql:5432/evolution?sslmode=disable
DATABASE_CONNECTION_DB_PREFIX_NAME=evolution

# Controlar o que é salvo
DATABASE_SAVE_DATA_INSTANCE=true
DATABASE_SAVE_DATA_NEW_MESSAGE=true
DATABASE_SAVE_MESSAGE_UPDATE=true
DATABASE_SAVE_DATA_CONTACTS=true
DATABASE_SAVE_DATA_CHATS=true
```

### Consultar Mensagens no PostgreSQL

```sql
-- Conectar ao banco
docker compose exec postgresql psql -U evolution -d evolution

-- Listar mensagens recentes
SELECT
  instance_name,
  sender,
  message_type,
  message_text,
  created_at
FROM evolution_messages
ORDER BY created_at DESC
LIMIT 10;

-- Mensagens de uma instância específica
SELECT * FROM evolution_messages
WHERE instance_name = 'atendimento-principal'
ORDER BY created_at DESC;

-- Contatos importados
SELECT * FROM evolution_contacts
WHERE instance_name = 'atendimento-principal';
```

---

## Integração com S3/SeaweedFS

Para armazenar mídias (imagens, vídeos, áudios) no SeaweedFS:

```bash
# Configurar no .env
S3_ENABLED=true
S3_ACCESS_KEY=admin
S3_SECRET_KEY=senha_seaweedfs
S3_BUCKET=evolution-media
S3_PORT=8333
S3_ENDPOINT=seaweedfs:8333
S3_USE_SSL=false
```

Reinicie o container:
```bash
docker compose restart evolution-api
```

As mídias serão automaticamente enviadas ao SeaweedFS e os links serão retornados nas mensagens.

---

## Práticas de Segurança

### 1. Proteção da API Key

```bash
# Nunca exponha a API key publicamente
# Use variáveis de ambiente
export EVOLUTION_API_KEY="$(openssl rand -base64 32 | tr -d '=+/')"

# Rotacione a API key periodicamente
# Edite no .env e reinicie:
docker compose restart evolution-api
```

### 2. HTTPS Obrigatório

O Caddy no BorgStack já fornece SSL automático. **Nunca** use HTTP para a Evolution API em produção.

### 3. Webhook Security

Configure um token de validação para webhooks:

```bash
# No .env
WA_BUSINESS_TOKEN_WEBHOOK=meu_token_secreto_webhook
```

Valide o token nos webhooks recebidos:

```javascript
// Exemplo em n8n Function Node
const webhookToken = $input.item.headers['x-webhook-token'];
const expectedToken = $env.WEBHOOK_TOKEN;

if (webhookToken !== expectedToken) {
  throw new Error('Token de webhook inválido');
}

return $input.item;
```

### 4. Limite de Taxa (Rate Limiting)

A Evolution API já possui rate limiting interno. Não exceda:
- 50 mensagens/minuto por instância
- 1000 mensagens/hora por instância

### 5. Validação de Números

**Sempre** valide se o número é WhatsApp antes de enviar mensagens:

```bash
curl -X POST https://evolution.seudominio.com.br/chat/whatsappNumbers/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI" \
  -H "Content-Type: application/json" \
  -d '{"numbers": ["5511987654321"]}'
```

### 6. Backup de Instâncias

As credenciais das instâncias são salvas no PostgreSQL. Certifique-se de que o backup do PostgreSQL está funcionando:

```bash
# Verificar backup do Duplicati
docker compose logs duplicati | grep evolution

# Backup manual
docker compose exec postgresql pg_dump -U evolution evolution > evolution_backup.sql
```

---

## Solução de Problemas

### 1. Instância Não Conecta

**Sintomas**: Status permanece em `connecting` ou muda para `close`

**Soluções**:

```bash
# Verificar logs
docker compose logs -f evolution-api

# Deletar e recriar instância
curl -X DELETE https://evolution.seudominio.com.br/instance/delete/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI"

# Criar novamente
curl -X POST https://evolution.seudominio.com.br/instance/create \
  -H "apikey: SUA_API_KEY_AQUI" \
  -H "Content-Type: application/json" \
  -d '{"instanceName": "atendimento-principal", "qrcode": true, "integration": "WHATSAPP-BAILEYS"}'

# Verificar conectividade com WhatsApp
docker compose exec evolution-api ping -c 3 web.whatsapp.com
```

### 2. Webhook Não Recebe Eventos

**Sintomas**: Webhook configurado mas eventos não chegam

**Soluções**:

```bash
# Verificar configuração do webhook
curl -X GET https://evolution.seudominio.com.br/webhook/find/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI"

# Testar conectividade do webhook
docker compose exec evolution-api curl -X POST https://n8n.seudominio.com.br/webhook/test \
  -H "Content-Type: application/json" \
  -d '{"test": "connectivity"}'

# Reconfigurar webhook
curl -X POST https://evolution.seudominio.com.br/webhook/set/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://n8n.seudominio.com.br/webhook/whatsapp",
    "enabled": true,
    "events": ["MESSAGES_UPSERT", "CONNECTION_UPDATE"]
  }'
```

### 3. Mensagens Não Enviadas

**Sintomas**: API retorna sucesso mas mensagem não chega

**Soluções**:

```bash
# Verificar status da instância
curl -X GET https://evolution.seudominio.com.br/instance/connectionState/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI"

# Verificar se número é WhatsApp
curl -X POST https://evolution.seudominio.com.br/chat/whatsappNumbers/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI" \
  -H "Content-Type: application/json" \
  -d '{"numbers": ["5511987654321"]}'

# Verificar rate limiting nos logs
docker compose logs evolution-api | grep -i "rate"

# Restart da instância
curl -X PUT https://evolution.seudominio.com.br/instance/restart/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI"
```

### 4. Integração Chatwoot Não Funciona

**Sintomas**: Mensagens não aparecem no Chatwoot ou não sincronizam

**Soluções**:

```bash
# Verificar configuração Chatwoot
curl -X GET https://evolution.seudominio.com.br/chatwoot/find/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI"

# Verificar token do Chatwoot
curl -X GET https://chatwoot.seudominio.com.br/api/v1/accounts/1/inboxes \
  -H "api_access_token: SEU_TOKEN_CHATWOOT"

# Reconfigurar integração
curl -X POST https://evolution.seudominio.com.br/chatwoot/set/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "enabled": true,
    "accountId": "1",
    "token": "SEU_TOKEN_CORRETO",
    "url": "https://chatwoot.seudominio.com.br",
    "autoCreate": true
  }'

# Verificar logs de ambos os serviços
docker compose logs -f evolution-api chatwoot
```

### 5. QR Code Não Aparece

**Sintomas**: Criação de instância não retorna QR Code

**Soluções**:

```bash
# Forçar geração de QR Code
curl -X GET https://evolution.seudominio.com.br/instance/connect/atendimento-principal \
  -H "apikey: SUA_API_KEY_AQUI"

# Usar código de pareamento como alternativa
curl -X POST https://evolution.seudominio.com.br/instance/create \
  -H "apikey: SUA_API_KEY_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "instanceName": "atendimento-principal",
    "number": "5511987654321",
    "qrcode": false,
    "integration": "WHATSAPP-BAILEYS"
  }'
```

### 6. Banco de Dados PostgreSQL Não Conecta

**Sintomas**: Logs mostram erro de conexão com PostgreSQL

**Soluções**:

```bash
# Verificar se PostgreSQL está rodando
docker compose ps postgresql

# Testar conectividade
docker compose exec evolution-api pg_isready -h postgresql -p 5432

# Verificar credenciais no .env
grep DATABASE_CONNECTION_URI .env

# Criar banco se não existir
docker compose exec postgresql psql -U postgres -c "CREATE DATABASE evolution;"
docker compose exec postgresql psql -U postgres -c "CREATE USER evolution WITH PASSWORD 'senha_segura';"
docker compose exec postgresql psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE evolution TO evolution;"

# Reiniciar Evolution API
docker compose restart evolution-api
```

### 7. Container Reinicia Constantemente

**Sintomas**: `docker compose ps` mostra container em loop de restart

**Soluções**:

```bash
# Verificar logs detalhados
docker compose logs --tail=100 evolution-api

# Verificar recursos do sistema
docker stats evolution-api

# Aumentar memória se necessário (docker-compose.yml)
# Adicione:
# deploy:
#   resources:
#     limits:
#       memory: 2G

# Limpar cache e reiniciar
docker compose down evolution-api
docker system prune -f
docker compose up -d evolution-api
```

---

## 8. Dicas e Melhores Práticas

### 8.1 Configuração Otimizada
Consulte [docs/02-configuracao.md](../02-configuracao.md) para variáveis de ambiente específicas deste serviço.

### 8.2 Performance
- Máx 3-5 instâncias por servidor
- Rate limiting: máx 15 msg/min para evitar ban Meta
- Sessão persistente: evitar re-scan QR code

### 8.3 Segurança
- API Key rotação mensal
- Webhook com HMAC signature
- Validar origem de webhooks

### 8.4 Monitoramento
- Status de conexão WhatsApp
- Latência de envio (target: < 2s)
- Taxa de entregas

### 8.5 Casos de Uso
Ver workflows de exemplo em [docs/09-workflows-exemplo.md](../09-workflows-exemplo.md)

---

## Recursos Adicionais

### Documentação Oficial
- [Evolution API Docs](https://doc.evolution-api.com/)
- [Evolution API GitHub](https://github.com/EvolutionAPI/evolution-api)
- [WhatsApp Business API](https://developers.facebook.com/docs/whatsapp)

### Comunidade
- [Discord Evolution API](https://evolution-api.com/discord)
- [Grupo Telegram](https://t.me/evolutionapi)

### Exemplos de Código
- [Evolution API Examples](https://github.com/EvolutionAPI/evolution-api-examples)
- [n8n Community Workflows](https://n8n.io/workflows/?search=evolution)

---

## Próximos Passos

Depois de configurar a Evolution API, você pode:

1. **Configurar Chatwoot**: Ver [docs/03-services/chatwoot.md](./chatwoot.md)
2. **Criar Workflows n8n**: Ver [docs/03-services/n8n.md](./n8n.md)
3. **Configurar Backups**: Ver [docs/06-manutencao.md](../06-manutencao.md)
4. **Otimizar Performance**: Ver [docs/08-desempenho.md](../08-desempenho.md)

---

## Referências Técnicas

### Variáveis de Ambiente Principais

```bash
# Autenticação
AUTHENTICATION_API_KEY=chave_api_global

# Database PostgreSQL
DATABASE_ENABLED=true
DATABASE_CONNECTION_URI=postgresql://user:pass@host:5432/dbname
DATABASE_SAVE_DATA_INSTANCE=true
DATABASE_SAVE_DATA_NEW_MESSAGE=true

# Storage S3/SeaweedFS
S3_ENABLED=true
S3_ACCESS_KEY=admin
S3_SECRET_KEY=senha
S3_BUCKET=evolution-media
S3_ENDPOINT=seaweedfs:8333

# Webhooks
WEBHOOK_GLOBAL_ENABLED=true
WEBHOOK_GLOBAL_URL=https://n8n.example.com/webhook/evolution
WEBHOOK_EVENTS_MESSAGES_UPSERT=true

# Chatwoot
CHATWOOT_ENABLED=true
CHATWOOT_MESSAGE_READ=true
CHATWOOT_MESSAGE_DELETE=true

# Redis (Cache)
CACHE_REDIS_ENABLED=true
CACHE_REDIS_URI=redis://redis:6379
CACHE_REDIS_SAVE_INSTANCES=true
```

### Portas e Endpoints

| Serviço | Porta Interna | URL Externa | Descrição |
|---------|---------------|-------------|-----------|
| Evolution API | 8080 | https://evolution.seudominio.com.br | API REST |
| PostgreSQL | 5432 | - | Banco de dados (rede interna) |
| Redis | 6379 | - | Cache (rede interna) |
| SeaweedFS | 8333 | - | Storage S3 (rede interna) |

### Limites e Quotas

| Recurso | Limite | Observações |
|---------|--------|-------------|
| Mensagens/minuto | 50 | Por instância |
| Mensagens/hora | 1000 | Por instância |
| Tamanho de mídia | 16MB | Imagens/vídeos |
| Tamanho de documento | 100MB | PDFs/arquivos |
| Conexões simultâneas | 100 | Por servidor |
| Instâncias por servidor | 50 | Recomendado |

---

**Última atualização**: 2025-10-08
**Versão do BorgStack**: 1.0
**Versão da Evolution API**: 2.x
