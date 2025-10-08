# Chatwoot - Plataforma de Atendimento ao Cliente

Guia completo em português para uso do Chatwoot no BorgStack.

---

## Índice

1. [O que é Chatwoot](#o-que-é-chatwoot)
2. [Configuração Inicial](#configuração-inicial)
3. [Conceitos Fundamentais](#conceitos-fundamentais)
4. [Criando Seu Primeiro Inbox](#criando-seu-primeiro-inbox)
5. [Gerenciamento de Conversas](#gerenciamento-de-conversas)
6. [Agentes e Equipes](#agentes-e-equipes)
7. [Integração com WhatsApp (Evolution API)](#integração-com-whatsapp-evolution-api)
8. [API do Chatwoot](#api-do-chatwoot)
9. [Práticas de Segurança](#práticas-de-segurança)
10. [Solução de Problemas](#solução-de-problemas)

---

## O que é Chatwoot

Chatwoot é uma plataforma de atendimento ao cliente **open-source** e **omnicanal** que centraliza todas as comunicações com clientes em uma única interface.

### Características Principais

- **Omnicanal**: WhatsApp, email, site (widget), Telegram, SMS, API
- **Múltiplos Agentes**: Equipe colaborando em tempo real
- **Inbox Compartilhado**: Todos veem todas as conversas
- **Automação**: Respostas automáticas, atribuição de conversas
- **Integrações**: n8n, Slack, webhooks
- **Self-Hosted**: Dados ficam no seu servidor (conformidade LGPD)

### Casos de Uso no BorgStack

1. **Atendimento WhatsApp Business**
   - Recebe mensagens via Evolution API
   - Agentes respondem pela interface web
   - Histórico completo de conversas

2. **Suporte Multi-canal**
   - Widget de chat no site
   - Email de suporte
   - WhatsApp
   - Telegram (opcional)

3. **Automação de Atendimento**
   - Respostas prontas (canned responses)
   - Atribuição automática de conversas
   - Webhooks para n8n (automações complexas)

4. **Análise e Relatórios**
   - Tempo médio de resposta
   - Satisfação do cliente
   - Volume de conversas por canal

### Acesso ao Sistema

**Interface Web:**
```text
URL: https://chatwoot.{SEU_DOMINIO}
Exemplo: https://chatwoot.mycompany.com.br
```text

**Arquitetura no BorgStack:**

```text
Chatwoot Container
├── Rails Web App (porta 3000)
├── PostgreSQL (chatwoot_db)
│   ├── Accounts
│   ├── Inboxes
│   ├── Conversations
│   ├── Messages
│   ├── Contacts
│   └── Agents
├── Redis (Sidekiq jobs)
│   └── Background jobs (emails, webhooks)
└── Volume Persistente
    └── borgstack_chatwoot_storage
        └── Uploads (imagens, arquivos)
```text

---

## Configuração Inicial

### Primeiro Acesso

1. **Acesse a URL do Chatwoot:**
   ```
   https://chatwoot.mycompany.com.br
   ```

2. **Aguarde geração do certificado SSL** (primeira vez: 30-60s)

3. **Crie sua conta:**
   - **Full Name:** Seu Nome
   - **Email:** seu-email@mycompany.com.br
   - **Password:** [Senha forte, 8+ caracteres]
   - **Confirm Password:** [Mesma senha]

4. **Crie sua Account (Conta/Empresa):**
   ```
   Account Name: Nome da Sua Empresa
   Exemplo: Acme Corporation
   ```

   **💡 O que é uma Account?**
   - Uma "Account" no Chatwoot é como uma **empresa** ou **workspace**
   - Você pode ter múltiplas accounts (ex: uma empresa, vários clientes)
   - Cada account tem seus próprios inboxes, agentes, conversas

5. **Complete o onboarding:**
   - Chatwoot pergunta sobre seu caso de uso
   - Você pode pular ou configurar depois

### Verificar Configuração

**Variáveis de Ambiente (.env):**

```bash
# Domínio do Chatwoot
CHATWOOT_HOST=chatwoot.mycompany.com.br

# Banco de dados PostgreSQL
POSTGRES_DB=chatwoot_db
POSTGRES_USER=chatwoot_user
POSTGRES_PASSWORD=${CHATWOOT_DB_PASSWORD}

# Redis
REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379

# Chave secreta (sessões, cookies)
SECRET_KEY_BASE=${CHATWOOT_SECRET_KEY_BASE}

# Email (opcional - para notificações)
MAILER_SENDER_EMAIL=chatwoot@mycompany.com.br
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=no-reply@mycompany.com.br
SMTP_PASSWORD=[senha-app-gmail]
```text

**⚠️ Configurar Email é Opcional:**
- Chatwoot funciona SEM email configurado
- Email é usado apenas para notificações de agentes
- Se não configurar, agentes precisam checar o painel web

### Adicionar Mais Agentes

1. **Acesse:** Settings → Agents → Add Agent

2. **Configure:**
   - **Name:** Nome do agente
   - **Email:** email@mycompany.com.br
   - **Role:** Administrator ou Agent

3. **Roles (Funções):**
   - **Administrator:** Acesso total (configurações, agentes, inboxes)
   - **Agent:** Apenas conversas e relatórios

4. **Enviar convite:**
   - Se email configurado: Agente recebe convite por email
   - Se email NÃO configurado: Copie o link de convite e envie manualmente

**💡 Dica:** Você pode ter quantos agentes quiser (gratuito em self-hosted)

---

## Conceitos Fundamentais

### Account (Conta/Empresa)

Uma **Account** é um **workspace isolado** com seus próprios:
- Inboxes
- Agentes
- Conversas
- Configurações

**Exemplo:**
- Account 1: "Acme Corporation" (sua empresa)
- Account 2: "Cliente XYZ" (se você gerencia atendimento de clientes)

### Inbox (Caixa de Entrada)

Um **Inbox** é um **canal de comunicação** com clientes.

**Tipos de Inboxes:**

| Tipo | Descrição | Exemplo |
|------|-----------|---------|
| **Website** | Widget de chat no site | Chat bubble no canto da página |
| **Email** | Suporte via email | suporte@mycompany.com.br |
| **WhatsApp** | Via API (Evolution API) | +55 11 98765-4321 |
| **Telegram** | Bot do Telegram | @mycompany_support_bot |
| **SMS** | Via Twilio/Vonage | +55 11 91234-5678 |
| **API** | Canal customizado | Mobile app, sistema interno |

**Cada inbox é independente:**
- Pode ter agentes diferentes
- Pode ter configurações diferentes
- Aparece separado na interface

### Conversation (Conversa)

Uma **Conversation** é um **thread de mensagens** com um cliente específico.

**Estados de uma conversa:**

```text
Open (Aberta)
  ↓
Pending (Pendente - aguardando resposta do cliente)
  ↓
Resolved (Resolvida)
  ↓
[Cliente responde] → Volta para Open
```text

**Atributos importantes:**
- **Status:** Open, Pending, Resolved
- **Assignee:** Agente responsável (ou nenhum)
- **Priority:** None, Low, Medium, High, Urgent
- **Labels:** Tags personalizadas (ex: "Vendas", "Suporte Técnico")

### Contact (Contato)

Um **Contact** é um **cliente** no sistema.

**Informações armazenadas:**
- Nome
- Email
- Telefone
- Atributos customizados (empresa, cargo, etc.)
- Histórico de conversas
- Notas internas

**💡 Contacts são únicos por inbox:**
- Mesmo cliente pode ter contacts diferentes em inboxes diferentes
- WhatsApp: Identificado por número de telefone
- Email: Identificado por email
- Website: Identificado por email ou anônimo

### Agent (Agente)

Um **Agent** é um **membro da equipe** que atende conversas.

**Capabilities por role:**

| Role | Ver conversas | Responder | Configurar inbox | Adicionar agentes | Acessar relatórios |
|------|--------------|-----------|------------------|-------------------|--------------------|
| **Administrator** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Agent** | ✅ | ✅ | ❌ | ❌ | ✅ |

### Team (Equipe)

Uma **Team** é um **grupo de agentes** que trabalham juntos.

**Uso:**
- Dividir agentes por departamento (Vendas, Suporte)
- Atribuir inboxes a equipes específicas
- Relatórios por equipe

---

## Criando Seu Primeiro Inbox

Vamos criar um inbox **Website** (widget de chat para seu site).

### Passo 1: Criar Inbox Website

1. **Acesse:** Settings → Inboxes → Add Inbox

2. **Selecione:** Website

3. **Configure:**
   - **Inbox Name:** Chat do Site
   - **Website Name:** Meu Site
   - **Website Domain:** mycompany.com.br

4. **Clique em:** Create Website Channel

### Passo 2: Configurar Widget

1. **Widget Color:** Escolha a cor do botão de chat

2. **Widget Bubble Text:** Texto no botão
   ```
   Exemplo: "Precisa de ajuda?"
   ```

3. **Welcome Greeting:** Mensagem de boas-vindas
   ```
   Olá! 👋 Como posso ajudar você hoje?
   ```

4. **Clique em:** Create Inbox

### Passo 3: Adicionar Agentes ao Inbox

1. **Na tela de configuração do inbox:**
   - Settings → Inboxes → [Chat do Site] → Settings → Collaborators

2. **Adicione agentes:**
   - Selecione agentes que podem ver este inbox
   - Clique em **Update**

### Passo 4: Instalar Widget no Site

**Copie o código de instalação:**

```html
<script>
(function(d,t) {
  var BASE_URL="https://chatwoot.mycompany.com.br";
  var g=d.createElement(t),s=d.getElementsByTagName(t)[0];
  g.src=BASE_URL+"/packs/js/sdk.js";
  g.defer = true;
  g.async = true;
  s.parentNode.insertBefore(g,s);
  g.onload=function(){
    window.chatwootSDK.run({
      websiteToken: 'YOUR_WEBSITE_TOKEN',
      baseUrl: BASE_URL
    })
  }
})(document,"script");
</script>
```text

**Adicione ao HTML do seu site:**
```html
<!-- Antes do </body> -->
<script>
  (function(d,t) {
    var BASE_URL="https://chatwoot.mycompany.com.br";
    var g=d.createElement(t),s=d.getElementsByTagName(t)[0];
    g.src=BASE_URL+"/packs/js/sdk.js";
    g.defer = true;
    g.async = true;
    s.parentNode.insertBefore(g,s);
    g.onload=function(){
      window.chatwootSDK.run({
        websiteToken: 'WRzxyz123abc',  // SEU TOKEN
        baseUrl: BASE_URL
      })
    }
  })(document,"script");
</script>
</body>
```text

### Passo 5: Testar o Widget

1. **Acesse seu site** onde instalou o código
2. **Veja o botão de chat** aparecer no canto inferior direito
3. **Clique e envie uma mensagem de teste**
4. **No Chatwoot:** Vá para Conversations → veja a mensagem aparecer!

**🎉 Parabéns! Você criou seu primeiro inbox funcional!**

---

## Gerenciamento de Conversas

### Visualizar Conversas

**Filtros disponíveis:**

```text
Conversations
├── Mine (Atribuídas a mim)
├── Unassigned (Sem atribuição)
├── All (Todas)
└── [Por Label] (ex: Vendas, Suporte)
```text

**Ordenação:**
- Mais recentes primeiro
- Por prioridade
- Por status

### Responder Conversas

1. **Clique em uma conversa** na lista
2. **Digite sua mensagem** na caixa de texto
3. **Opções:**
   - **Private Note:** Nota interna (cliente não vê)
   - **Reply:** Resposta pública (cliente vê)

4. **Enviar:**
   - `Enter`: Quebra de linha
   - `Cmd/Ctrl + Enter`: Enviar mensagem

**Anexar arquivos:**
- Clique no ícone de clipe 📎
- Selecione arquivo (imagem, PDF, etc.)
- Arquivo é salvo em `borgstack_chatwoot_storage`

### Atribuir Conversas

**Atribuir a si mesmo:**
1. Clique na conversa
2. Clique em "Assign to me" (canto superior direito)

**Atribuir a outro agente:**
1. Clique em "Assigned Agent" dropdown
2. Selecione o agente
3. Agente recebe notificação (se email configurado)

### Mudar Status da Conversa

**Estados:**

```text
Open → Pending → Resolved
  ↑__________________|
  (Cliente responde)
```text

**Como mudar:**
1. Clique na conversa
2. Botão "Resolve" (marca como resolvida)
3. Botão "Reopen" (reabre conversa resolvida)
4. "Snooze Until" (adiar até data/hora específica)

### Adicionar Labels (Etiquetas)

**Criar label:**
1. Settings → Labels → Add Label
2. Configure:
   - **Label Name:** Vendas
   - **Description:** Conversas de vendas
   - **Color:** #FF5733

**Aplicar label em conversa:**
1. Abra conversa
2. Painel direito → Conversation Labels
3. Selecione ou crie label

**Filtrar por label:**
- Conversations → Filtro no topo → Selecione label

### Usar Respostas Prontas (Canned Responses)

**Criar resposta pronta:**

1. **Settings → Canned Responses → Add Canned Response**

2. **Configure:**
   ```
   Short Code: boas-vindas
   Content:
     Olá! Obrigado por entrar em contato.
     Como posso ajudar você hoje?
   ```

**Usar na conversa:**
1. Digite `/` na caixa de mensagem
2. Digite o short code: `/boas-vindas`
3. Pressione Enter
4. Mensagem é inserida automaticamente

**💡 Dica:** Crie respostas para perguntas frequentes (FAQ)

### Notas Privadas (Private Notes)

**Uso:** Comunicação interna entre agentes, cliente não vê

**Como adicionar:**
1. Clique em conversa
2. Selecione "Private Note" (não "Reply")
3. Digite nota (ex: "Cliente está interessado em plano premium")
4. Enviar

**Quando usar:**
- Passar contexto para outro agente
- Documentar informações importantes
- Anotações internas

---

## Agentes e Equipes

### Adicionar Novo Agente

1. **Settings → Agents → Add Agent**

2. **Preencha:**
   ```
   Name: João Silva
   Email: joao.silva@mycompany.com.br
   Role: Agent
   ```

3. **Enviar convite:**
   - Agente recebe email com link de ativação
   - Ele cria sua própria senha

### Criar Equipe (Team)

1. **Settings → Teams → Create new team**

2. **Configure:**
   ```
   Team Name: Suporte Técnico
   Team Description: Equipe de suporte ao cliente
   Allow auto assign: Sim
   ```

3. **Adicionar agentes:**
   - Selecione agentes que fazem parte desta equipe

### Atribuir Inbox a Equipe

1. **Settings → Inboxes → [Seu Inbox] → Settings → Collaborators**

2. **Adicione a equipe** (não agentes individuais)

3. **Benefício:**
   - Todos os agentes da equipe veem o inbox automaticamente
   - Facilita gerenciamento quando equipe cresce

### Atribuição Automática

**Round Robin (Rodízio):**

1. **Settings → Inboxes → [Inbox] → Settings → Collaborators**

2. **Habilite:** "Enable auto assignment"

3. **Como funciona:**
   - Novas conversas são atribuídas automaticamente
   - Distribui igualmente entre agentes disponíveis
   - Leva em conta carga de trabalho atual

**Configurar disponibilidade:**
1. **Profile → Availability**
2. **Status:**
   - Online (recebe atribuições)
   - Busy (não recebe novas atribuições)
   - Offline (não recebe atribuições)

---

## Integração com WhatsApp (Evolution API)

O BorgStack usa **Evolution API** + **n8n** para conectar WhatsApp ao Chatwoot.

### Arquitetura da Integração

```mermaid
sequenceDiagram
    participant Cliente
    participant WhatsApp
    participant Evolution
    participant n8n
    participant Chatwoot
    participant PostgreSQL

    Cliente->>WhatsApp: Envia mensagem
    WhatsApp->>Evolution: Webhook entrega
    Evolution->>n8n: POST /webhook/whatsapp-incoming
    n8n->>PostgreSQL: Busca dados do contato
    PostgreSQL-->>n8n: Retorna contato
    n8n->>Chatwoot: POST /api/v1/conversations
    Chatwoot-->>n8n: Conversa criada
    n8n->>Chatwoot: POST /api/v1/messages
    Chatwoot-->>n8n: Mensagem adicionada
```text

### Passo 1: Criar Inbox API no Chatwoot

1. **Settings → Inboxes → Add Inbox → API**

2. **Configure:**
   ```
   Inbox Name: WhatsApp Business
   Webhook URL: [Deixe em branco por enquanto]
   ```

3. **Copie o Inbox Identifier:**
   ```
   Exemplo: whatsapp-business-123abc
   ```

4. **Crie API Access Token:**
   - Settings → Profile Settings → Access Token
   - Copie o token (ex: `xyz789token`)

### Passo 2: Configurar Evolution API

1. **Acesse Evolution API:** `https://evolution.mycompany.com.br`

2. **Crie instância WhatsApp:**
   - Nome: `whatsapp-business`
   - Escaneie QR code com WhatsApp Business

3. **Configure webhook:**
   ```
   Webhook URL: https://n8n.mycompany.com.br/webhook/whatsapp-incoming
   Events: messages.upsert
   ```

### Passo 3: Criar Workflow n8n

**Ver documentação completa:**
- `docs/04-integrations/whatsapp-chatwoot.md` (será criado em Task 4)

**Resumo do workflow:**

```text
Webhook Trigger (Evolution API)
    ↓
Function (Processar dados WhatsApp)
    ↓
HTTP Request (Criar/Buscar Contact no Chatwoot)
    ↓
HTTP Request (Criar/Buscar Conversation no Chatwoot)
    ↓
HTTP Request (Adicionar Message no Chatwoot)
```text

### Passo 4: Testar Integração

1. **Envie mensagem para número WhatsApp Business**
2. **No Chatwoot:** Conversations → veja mensagem aparecer
3. **Responda no Chatwoot**
4. **Cliente recebe resposta no WhatsApp**

**⚠️ Limitação WhatsApp:**
- Você só pode responder dentro de **24 horas** após mensagem do cliente
- Após 24h, precisa usar Template Messages aprovados

---

## API do Chatwoot

### Autenticação

**API Access Token:**

```bash
# Obter token
# Chatwoot UI → Profile Settings → Access Token

# Usar em requisições
curl https://chatwoot.mycompany.com.br/api/v1/accounts/1/conversations \
  -H "api_access_token: xyz789token"
```text

### Endpoints Principais

**Listar conversas:**

```bash
GET /api/v1/accounts/{account_id}/conversations
```text

```bash
curl https://chatwoot.mycompany.com.br/api/v1/accounts/1/conversations \
  -H "api_access_token: xyz789token"
```text

**Criar conversa:**

```bash
POST /api/v1/accounts/{account_id}/conversations
```text

```bash
curl -X POST https://chatwoot.mycompany.com.br/api/v1/accounts/1/conversations \
  -H "api_access_token: xyz789token" \
  -H "Content-Type: application/json" \
  -d '{
    "source_id": "+5511987654321",
    "inbox_id": 1,
    "contact_id": 42,
    "status": "open"
  }'
```text

**Enviar mensagem:**

```bash
POST /api/v1/accounts/{account_id}/conversations/{conversation_id}/messages
```text

```bash
curl -X POST https://chatwoot.mycompany.com.br/api/v1/accounts/1/conversations/123/messages \
  -H "api_access_token: xyz789token" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Olá! Como posso ajudar?",
    "message_type": "outgoing",
    "private": false
  }'
```text

**Criar contato:**

```bash
POST /api/v1/accounts/{account_id}/contacts
```text

```bash
curl -X POST https://chatwoot.mycompany.com.br/api/v1/accounts/1/contacts \
  -H "api_access_token: xyz789token" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "João Silva",
    "email": "joao@example.com",
    "phone_number": "+5511987654321",
    "inbox_id": 1
  }'
```text

### Webhooks

**Configurar webhook:**

1. **Settings → Integrations → Webhooks → Add Webhook**

2. **Configure:**
   ```
   Webhook URL: https://n8n.mycompany.com.br/webhook/chatwoot-events
   Events:
     - conversation_created
     - message_created
     - conversation_updated
   ```

**Payload exemplo (message_created):**

```json
{
  "event": "message_created",
  "account": {
    "id": 1,
    "name": "Acme Corporation"
  },
  "conversation": {
    "id": 123,
    "inbox_id": 1,
    "status": "open"
  },
  "message": {
    "id": 456,
    "content": "Olá, preciso de ajuda",
    "message_type": "incoming",
    "created_at": "2025-10-08T14:30:00Z",
    "sender": {
      "id": 789,
      "name": "João Silva",
      "phone_number": "+5511987654321"
    }
  }
}
```text

### Documentação Completa da API

```text
https://chatwoot.mycompany.com.br/swagger
```text

---

## Práticas de Segurança

### 1. Proteger API Tokens

**❌ NUNCA:**
```javascript
// Expor token no código front-end
const token = "xyz789token";
fetch(`https://chatwoot.com/api/...?api_access_token=${token}`)
```text

**✅ SEMPRE:**
```javascript
// Usar proxy backend que esconde o token
fetch(`/api/chatwoot/conversations`)  // Seu backend adiciona token
```text

### 2. Limitar Permissões de Agentes

**Princípio do Menor Privilégio:**
- ✅ Use role "Agent" para maioria dos usuários
- ✅ Reserve "Administrator" apenas para gestores
- ❌ Não dê admin para todos

### 3. Configurar CORS Apropriadamente

**Se usar widget em múltiplos domínios:**

```bash
# .env
ALLOWED_ORIGINS=https://mycompany.com.br,https://app.mycompany.com.br
```text

### 4. Habilitar Autenticação de 2 Fatores (2FA)

**Para administradores:**

1. **Profile Settings → Two Factor Authentication**
2. **Scan QR code** com app autenticador (Google Authenticator, Authy)
3. **Enter verification code**

### 5. Revisar Webhooks Regularmente

**Verificar:**
- ✅ URLs de webhook estão corretas
- ✅ Webhooks não apontam para URLs públicas sem autenticação
- ✅ Desabilite webhooks não utilizados

---

## Solução de Problemas

### Problema: Não consigo fazer login

**Causas comuns:**

1. **Email/senha incorretos:**
   ```bash
   # Resetar senha via console Rails
   docker compose exec chatwoot rails console

   # No console Rails:
   user = User.find_by(email: 'seu-email@company.com')
   user.password = 'NovaSenha123!'
   user.password_confirmation = 'NovaSenha123!'
   user.save!
   exit
   ```

2. **Conta não ativada:**
   - Verifique email de ativação
   - Se não recebeu, peça para admin reenviar convite

### Problema: Widget não aparece no site

**Diagnóstico:**

```javascript
// Abra console do navegador (F12)
// Verifique erros de CORS:
// Access to script at 'https://chatwoot.../sdk.js' has been blocked by CORS

// Verifique se widget está carregando:
console.log(window.chatwootSDK);
// Deve retornar objeto, não undefined
```text

**Soluções:**

1. **Verifique token do website:**
   ```javascript
   websiteToken: 'WRzxyz123abc'  // Deve estar correto
   ```

2. **Verifique CORS:**
   ```bash
   # .env do Chatwoot
   ALLOWED_ORIGINS=https://meusite.com.br
   ```

3. **Limpe cache do navegador** (Ctrl+Shift+Del)

### Problema: Mensagens WhatsApp não aparecem

**Verifique:**

```bash
# 1. Evolution API está recebendo mensagens?
docker compose logs evolution --tail 50 | grep webhook

# 2. n8n está processando webhook?
docker compose logs n8n --tail 50 | grep whatsapp

# 3. Chatwoot está recebendo API calls?
docker compose logs chatwoot --tail 100 | grep "POST /api/v1"
```text

**Debugging n8n workflow:**
- n8n → Executions → Veja execuções falhadas
- Verifique output de cada node
- Teste credenciais do Chatwoot

### Problema: Performance lenta

**Otimizações:**

1. **Verificar uso de recursos:**
   ```bash
   docker stats borgstack-chatwoot-1
   ```

2. **Limpar conversas antigas:**
   ```bash
   # Arquivar conversas resolvidas há mais de 30 dias
   docker compose exec chatwoot rails console

   # No console:
   Conversation.where(status: :resolved)
     .where('updated_at < ?', 30.days.ago)
     .update_all(archived: true)
   exit
   ```

3. **Otimizar PostgreSQL:** Ver `docs/08-desempenho.md`

### Problema: Emails de notificação não enviam

**Verifique configuração SMTP:**

```bash
# Ver configuração atual
docker compose exec chatwoot rails console

# No console:
ENV['SMTP_ADDRESS']
ENV['SMTP_PORT']
ENV['SMTP_USERNAME']
# Deve mostrar valores configurados

# Testar envio
ActionMailer::Base.mail(
  from: 'chatwoot@mycompany.com.br',
  to: 'test@example.com',
  subject: 'Test Email',
  body: 'Testing SMTP configuration'
).deliver_now

exit
```text

**Erro comum: Gmail bloqueia SMTP:**
- Use **App Password**, não senha da conta
- Google Account → Security → 2-Step Verification → App Passwords

### Logs Importantes

```bash
# Ver todos os logs Chatwoot
docker compose logs chatwoot --tail 200

# Seguir logs em tempo real
docker compose logs -f chatwoot

# Filtrar por erro
docker compose logs chatwoot | grep ERROR

# Ver Sidekiq jobs (background)
docker compose logs chatwoot | grep Sidekiq
```text

---

## Recursos Adicionais

**Documentação Oficial:**
- https://www.chatwoot.com/docs/

**API Documentation:**
- https://chatwoot.mycompany.com.br/swagger

**Community Forum:**
- https://github.com/chatwoot/chatwoot/discussions

---

## Navegação

- **Anterior:** [n8n - Automação de Workflows](n8n.md)
- **Próximo:** [Evolution API - WhatsApp Business](evolution-api.md)
- **Índice:** [Documentação Completa](../README.md)

---

**Última atualização:** 2025-10-08
**Versão do guia:** 1.0
**Compatível com:** Chatwoot v4.6.0-ce+, BorgStack v4+
