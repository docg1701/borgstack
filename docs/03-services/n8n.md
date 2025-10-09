# n8n - Plataforma de Automação de Workflows

Guia completo em português para uso do n8n no BorgStack.

---

## Índice

1. [O que é n8n](#o-que-é-n8n)
2. [Configuração Inicial](#configuração-inicial)
3. [Conceitos Fundamentais](#conceitos-fundamentais)
4. [Criando Seu Primeiro Workflow](#criando-seu-primeiro-workflow)
5. [Trabalhando com Credenciais](#trabalhando-com-credenciais)
6. [Webhooks e Triggers](#webhooks-e-triggers)
7. [Integrações com Outros Serviços BorgStack](#integrações-com-outros-serviços-borgstack)
8. [Práticas de Segurança](#práticas-de-segurança)
9. [Solução de Problemas](#solução-de-problemas)

---

## O que é n8n

n8n é uma plataforma de automação de workflows de código aberto que conecta aplicações e automatiza tarefas repetitivas. No BorgStack, o n8n funciona como o **hub central de integração** entre todos os serviços.

### Características Principais

- **400+ Integrações Nativas**: Conecta com APIs, bancos de dados, serviços de nuvem
- **Editor Visual de Workflows**: Interface drag-and-drop para criar automações
- **Code Nodes**: Escreva JavaScript/Python quando precisar de lógica customizada
- **Webhooks**: Receba eventos de sistemas externos
- **Execução Assíncrona**: Workflows executam em background via Bull Queue (Redis)
- **Self-Hosted**: Dados permanecem no seu servidor (conformidade LGPD)

### Casos de Uso no BorgStack

1. **Automação WhatsApp → Chatwoot**
   - Recebe mensagens do Evolution API
   - Cria conversas no Chatwoot
   - Sincroniza status e respostas

2. **Processamento de Mídia**
   - Recebe webhook do Directus (upload de arquivo)
   - Aciona FileFlows para processamento
   - Atualiza metadata no Directus

3. **Integrações de Negócio**
   - Sincroniza dados entre sistemas (CRM, ERP, e-commerce)
   - Gera relatórios automaticamente
   - Envia notificações via email, Slack, Discord

4. **Gestão de Armazenamento**
   - Upload/download de arquivos no SeaweedFS
   - Organização e catalogação automática
   - Backup incremental de dados críticos

### Acesso ao Sistema

**Interface Web:**
```
URL: https://n8n.{SEU_DOMINIO}
Exemplo: https://n8n.mycompany.com.br
```

**Arquitetura no BorgStack:**

```
n8n Container
├── Editor Web UI (porta 5678)
├── PostgreSQL (n8n_db)
│   ├── Workflows
│   ├── Credenciais (encriptadas)
│   ├── Histórico de execuções
│   └── Configurações
├── Redis Queue (Bull)
│   └── Fila de execução de workflows
└── Volume Persistente
    └── borgstack_n8n_data
        └── Arquivos locais (se usar filesystem storage)
```

---

## Configuração Inicial

### Primeiro Acesso

1. **Acesse a URL do n8n:**
   ```
   https://n8n.mycompany.com.br
   ```

2. **Aguarde a geração do certificado SSL** (primeira vez: 30-60 segundos)

3. **Crie sua conta de proprietário:**
   - n8n usa autenticação **baseada em conta** (não HTTP Basic Auth)
   - O primeiro usuário criado é automaticamente **Owner** (proprietário)
   - Owners têm acesso total a workflows, credenciais e configurações

   ```
   Email: seu-email@mycompany.com.br
   Nome: Seu Nome
   Senha: [Senha forte, 8+ caracteres]
   ```

4. **Complete o onboarding:**
   - n8n perguntará sobre seu caso de uso
   - Você pode pular ou responder para recomendações personalizadas

### Verificar Configuração

**Variáveis de Ambiente Importantes (.env):**

```bash
# Domínio do n8n
N8N_HOST=n8n.mycompany.com.br

# Banco de dados PostgreSQL
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=postgresql
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n_db
DB_POSTGRESDB_USER=n8n_user
DB_POSTGRESDB_PASSWORD=${N8N_DB_PASSWORD}

# Chave de encriptação de credenciais (CRÍTICO - backup!)
N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}

# Redis Queue (Bull)
QUEUE_BULL_REDIS_HOST=redis
QUEUE_BULL_REDIS_PORT=6379
QUEUE_BULL_REDIS_PASSWORD=${REDIS_PASSWORD}

# Webhook URL base
WEBHOOK_URL=https://n8n.mycompany.com.br/
```

**⚠️ CRÍTICO - Backup da Chave de Encriptação:**

```bash
# Ver a chave de encriptação
grep N8N_ENCRYPTION_KEY .env

# IMPORTANTE: Sem essa chave, você PERDE acesso a todas as credenciais!
# Salve em local seguro (gerenciador de senhas, cofre criptografado)
```

### Adicionar Mais Usuários

**n8n Cloud vs. Self-Hosted:**
- **n8n Cloud:** Suporta múltiplos usuários com planos pagos
- **BorgStack (Self-Hosted):** Múltiplos usuários disponíveis GRATUITAMENTE

**Adicionar novo usuário:**

1. Acesse: **Settings → Users**
2. Clique em **Invite User**
3. Configure:
   - Email do novo usuário
   - Role (função):
     - **Owner:** Acesso total (cuidado!)
     - **Admin:** Gerencia workflows e credenciais
     - **Member:** Cria e edita workflows, usa credenciais compartilhadas
   - Send invite: Email será enviado (configure SMTP primeiro)

**Configurar SMTP para convites:**

```bash
# Adicionar ao .env
N8N_EMAIL_MODE=smtp
N8N_SMTP_HOST=smtp.gmail.com
N8N_SMTP_PORT=587
N8N_SMTP_USER=no-reply@mycompany.com.br
N8N_SMTP_PASS=senha-app-gmail
N8N_SMTP_SENDER=n8n@mycompany.com.br
```

Reinicie o n8n:
```bash
docker compose restart n8n
```

---

## Conceitos Fundamentais

### Workflows (Fluxos de Trabalho)

Um workflow é uma **sequência de ações automatizadas** que são executadas quando um evento acontece.

**Estrutura:**
```
Trigger (Gatilho)
    ↓
Node 1 (Ação)
    ↓
Node 2 (Transformação)
    ↓
Node 3 (Ação Final)
```

**Exemplo prático:**
```
Webhook Trigger (recebe mensagem WhatsApp)
    ↓
HTTP Request (busca dados do cliente no CRM)
    ↓
IF Node (verifica se é cliente VIP)
    ↓
Chatwoot Node (cria ticket prioritário)
```

### Nodes (Nós)

Nodes são os **blocos de construção** dos workflows. Cada node executa uma ação específica.

**Tipos de Nodes:**

| Tipo | Descrição | Exemplos |
|------|-----------|----------|
| **Trigger Nodes** | Iniciam workflows | Webhook, Schedule (Cron), Manual Trigger |
| **Action Nodes** | Executam ações | HTTP Request, PostgreSQL, Send Email |
| **Logic Nodes** | Controlam fluxo | IF, Switch, Merge, Loop Over Items |
| **Transform Nodes** | Manipulam dados | Set, Function, Code, Edit Fields |
| **Core Nodes** | Funcionalidades base | Wait, Respond to Webhook, Stop and Error |

**Node mais usados no BorgStack:**

1. **Webhook Trigger:** Receber eventos (Evolution API, Directus, etc.)
2. **HTTP Request:** Chamar APIs (Chatwoot, SeaweedFS, etc.)
3. **PostgreSQL:** Consultar/inserir dados nos bancos
4. **Function (Code):** Lógica customizada em JavaScript
5. **IF:** Ramificação condicional
6. **Set:** Preparar dados para próximo node

### Connections (Conexões)

Conexões ligam nodes e definem o **fluxo de dados**.

**Tipos de Conexões:**

```
Node A ──main──> Node B    (Conexão principal - dados fluem)
Node A ──error─> Node C    (Conexão de erro - só se Node A falhar)
```

**Múltiplas saídas:**
```
IF Node
├──true──> Node B
└──false─> Node C
```

### Executions (Execuções)

Cada vez que um workflow roda, é criada uma **execução** com:
- **Input Data:** Dados que entraram no workflow
- **Output Data:** Dados que saíram de cada node
- **Status:** Success, Error, Waiting
- **Execution Time:** Duração total
- **Logs:** Mensagens de debug/erro

**Ver execuções:**
```
Menu lateral → Executions
Ou: Clique em "Executions" dentro de um workflow
```

### Credentials (Credenciais)

Credenciais armazenam **informações de autenticação** de forma segura.

**Como funciona:**
1. Você cria uma credencial (ex: "Chatwoot Production API")
2. Insere API key, senha, ou OAuth tokens
3. Credencial é **encriptada** com `N8N_ENCRYPTION_KEY`
4. Múltiplos workflows podem reusar a mesma credencial

**Exemplo - Credencial HTTP:**
```
Name: Chatwoot API
Type: Header Auth
Header Name: api_access_token
Header Value: [seu-token-aqui]
```

---

## Criando Seu Primeiro Workflow

Vamos criar um workflow simples que recebe um webhook e salva dados no PostgreSQL.

### Passo 1: Criar Novo Workflow

1. **Acesse n8n:** `https://n8n.mycompany.com.br`
2. **Clique em "New Workflow"** (canto superior direito)
3. **Nomeie o workflow:** "Teste - Webhook to PostgreSQL"

### Passo 2: Adicionar Webhook Trigger

1. **Clique no botão "+"** na tela
2. **Busque:** "Webhook"
3. **Selecione:** "Webhook Trigger"
4. **Configure:**
   - **HTTP Method:** POST
   - **Path:** `test-webhook`
   - **Authentication:** None (para teste)
   - **Respond:** Immediately

5. **Copie a URL do Webhook:**
   ```
   Production URL: https://n8n.mycompany.com.br/webhook/test-webhook
   Test URL: https://n8n.mycompany.com.br/webhook-test/test-webhook
   ```

### Passo 3: Testar o Webhook

**Via curl:**
```bash
curl -X POST https://n8n.mycompany.com.br/webhook-test/test-webhook \
  -H "Content-Type: application/json" \
  -d '{"name": "João Silva", "email": "joao@example.com", "action": "signup"}'
```

**Via navegador (Postman, Insomnia):**
```
Method: POST
URL: https://n8n.mycompany.com.br/webhook-test/test-webhook
Body (JSON):
{
  "name": "João Silva",
  "email": "joao@example.com",
  "action": "signup"
}
```

Você verá os dados aparecerem no n8n!

### Passo 4: Adicionar Node de Transformação (Set)

1. **Clique no "+"** após o Webhook node
2. **Busque:** "Set"
3. **Selecione:** "Edit Fields (Set)"
4. **Configure campos:**
   - **Campo 1:**
     - Name: `timestamp`
     - Value: `{{ $now.toISO() }}`
   - **Campo 2:**
     - Name: `user_name`
     - Value: `{{ $json.name }}`
   - **Campo 3:**
     - Name: `user_email`
     - Value: `{{ $json.email }}`

**💡 Dica:** As chaves duplas `{{ }}` são expressões n8n para acessar dados.

### Passo 5: Adicionar PostgreSQL Node

1. **Clique no "+"** após o Set node
2. **Busque:** "PostgreSQL"
3. **Selecione:** "PostgreSQL"
4. **Configure:**
   - **Operation:** Insert
   - **Credential:** [Criar nova - veja próximo passo]
   - **Schema:** public
   - **Table:** user_signups (vamos criar)
   - **Columns:** name, email, created_at

### Passo 6: Criar Credencial PostgreSQL

1. **No PostgreSQL node, clique em "Create New Credential"**
2. **Configure:**
   ```
   Host: postgresql
   Database: n8n_db
   User: n8n_user
   Password: [valor de N8N_DB_PASSWORD do .env]
   Port: 5432
   SSL: Disabled
   ```

3. **Clique em "Save"**

**⚠️ IMPORTANTE:** Use o password do `.env`, não invente!

### Passo 7: Criar Tabela no PostgreSQL

Antes de executar o workflow, crie a tabela:

```bash
# Conectar ao PostgreSQL
docker compose exec postgresql psql -U n8n_user -d n8n_db

# Criar tabela
CREATE TABLE user_signups (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255),
    email VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW()
);

# Sair
\q
```

### Passo 8: Executar o Workflow

1. **Ative o workflow:** Toggle no canto superior direito
2. **Envie webhook de teste novamente:**
   ```bash
   curl -X POST https://n8n.mycompany.com.br/webhook/test-webhook \
     -H "Content-Type: application/json" \
     -d '{"name": "Maria Santos", "email": "maria@example.com"}'
   ```

3. **Verifique no PostgreSQL:**
   ```bash
   docker compose exec postgresql psql -U n8n_user -d n8n_db -c "SELECT * FROM user_signups;"
   ```

**Saída esperada:**
```
 id |     name      |       email        |         created_at
----+---------------+--------------------+----------------------------
  1 | Maria Santos  | maria@example.com  | 2025-10-08 14:23:45.123456
```

**🎉 Parabéns! Você criou seu primeiro workflow funcional!**

---

## Trabalhando com Credenciais

### Tipos de Credenciais

| Tipo | Uso | Exemplo |
|------|-----|---------|
| **Header Auth** | APIs com token no header | Chatwoot, Evolution API |
| **Basic Auth** | APIs com user/password | APIs antigas |
| **OAuth2** | Autenticação com Google, GitHub | Gmail, Google Drive |
| **API Key** | APIs com chave única | SendGrid, Twilio |
| **Database** | Conexões PostgreSQL/MongoDB | Bancos BorgStack |

### Criar Credencial para Chatwoot

**Exemplo: Conectar n8n ao Chatwoot**

1. **Obter API Key do Chatwoot:**
   - Acesse: `https://chatwoot.mycompany.com.br`
   - Login → Profile Settings → Access Token
   - Copie o token

2. **Criar credencial no n8n:**
   - Settings → Credentials → Add Credential
   - Busque: "Chatwoot"
   - Configure:
     ```
     Name: Chatwoot Production
     URL: https://chatwoot.mycompany.com.br
     API Access Token: [token copiado]
     ```

3. **Testar conexão:**
   - Clique em "Test Credential"
   - Deve retornar: ✅ "Connection successful"

### Criar Credencial para Evolution API

1. **Obter API Key:**
   - Evolution API usa autenticação por API Key
   - Verifique no `.env`: `EVOLUTION_API_KEY`

2. **Criar credencial:**
   - Type: **Header Auth**
   - Configure:
     ```
     Name: Evolution API Production
     Header Name: apikey
     Header Value: [valor de EVOLUTION_API_KEY]
     ```

### Gerenciar Credenciais

**Compartilhar credenciais entre usuários:**

1. Settings → Credentials → [sua credencial]
2. Sharing tab
3. Add users ou "Share with everyone"

**Segurança:**
- ✅ Credenciais são encriptadas no banco de dados
- ✅ Usuários só veem credenciais que têm permissão
- ⚠️ Owners veem TODAS as credenciais
- ⚠️ Se perder `N8N_ENCRYPTION_KEY`, perde TODAS as credenciais

---

## Webhooks e Triggers

### Webhook Trigger (Receber Eventos)

**Use quando:** Sistemas externos precisam acionar workflows

**Exemplo: Evolution API → n8n (mensagem WhatsApp recebida)**

1. **Criar workflow com Webhook Trigger:**
   ```
   Path: whatsapp-incoming
   Method: POST
   Authentication: Header Auth (recomendado para produção)
   ```

2. **Copiar Production URL:**
   ```
   https://n8n.mycompany.com.br/webhook/whatsapp-incoming
   ```

3. **Configurar no Evolution API:**
   - Acesse Evolution API admin
   - Configure webhook para instância WhatsApp
   - URL: [Production URL do n8n]
   - Events: messages.upsert

**💡 Dica:** Sempre use autenticação em webhooks de produção!

### Schedule Trigger (Cron)

**Use quando:** Precisa executar workflows periodicamente

**Exemplo: Backup diário às 2h da manhã**

1. **Adicionar Schedule Trigger:**
   - Busque: "Schedule Trigger"
   - Configure:
     ```
     Trigger Interval: Custom (Cron)
     Cron Expression: 0 2 * * *
     ```

**Expressões Cron comuns:**

| Expressão | Descrição |
|-----------|-----------|
| `*/5 * * * *` | A cada 5 minutos |
| `0 * * * *` | A cada hora (minuto 0) |
| `0 9 * * *` | Todo dia às 9h |
| `0 9 * * 1` | Toda segunda-feira às 9h |
| `0 0 1 * *` | Dia 1 de cada mês à meia-noite |

### Manual Trigger

**Use quando:** Quer executar workflow manualmente ou para testes

1. **Adicionar Manual Trigger:**
   - Workflow começa com "When clicking 'Test workflow'"
   - Clique em "Test workflow" para executar

---

## Integrações com Outros Serviços BorgStack

### Integração: n8n → PostgreSQL

**Cenário:** Consultar dados de clientes

```javascript
// No PostgreSQL node
Operation: Execute Query
Query:
  SELECT * FROM customers
  WHERE email = $1
  LIMIT 1

Query Parameters:
  $1 = {{ $json.email }}
```

### Integração: n8n → Chatwoot

**Cenário:** Criar conversa automaticamente

```
HTTP Request Node:
  Method: POST
  URL: https://chatwoot.mycompany.com.br/api/v1/accounts/1/conversations
  Authentication: Use Credential "Chatwoot Production"
  Body (JSON):
    {
      "source_id": "{{ $json.phone }}",
      "inbox_id": 1,
      "contact_id": "{{ $json.contact_id }}"
    }
```

### Integração: n8n → SeaweedFS (Upload de Arquivo)

**Cenário:** Upload de arquivo via Filer API

```
HTTP Request Node:
  Method: PUT
  URL: http://seaweedfs:8888/my-bucket/{{ $json.filename }}
  Body Type: Binary Data
  Input Binary Field: data
```

### Integração: n8n → Directus

**Cenário:** Criar item em coleção

```
HTTP Request Node:
  Method: POST
  URL: https://directus.mycompany.com.br/items/articles
  Authentication: Use Credential "Directus API"
  Body (JSON):
    {
      "title": "{{ $json.title }}",
      "content": "{{ $json.content }}",
      "status": "published"
    }
```

### Integração: n8n → Evolution API

**Cenário:** Enviar mensagem WhatsApp

```
HTTP Request Node:
  Method: POST
  URL: https://evolution.mycompany.com.br/message/sendText/instance_name
  Headers:
    apikey: {{ $credentials.evolutionApi.apiKey }}
  Body (JSON):
    {
      "number": "{{ $json.phone }}",
      "text": "Olá! Sua solicitação foi processada."
    }
```

---

## Práticas de Segurança

### 1. Proteger Webhooks com Autenticação

**❌ NUNCA faça isso em produção:**
```
Webhook Trigger
  Authentication: None
```

**✅ SEMPRE use autenticação:**
```
Webhook Trigger
  Authentication: Header Auth
  Header Name: X-Webhook-Secret
  Header Value: [senha forte de 32 caracteres]
```

**Exemplo de chamada segura:**
```bash
curl -X POST https://n8n.mycompany.com.br/webhook/secure-endpoint \
  -H "X-Webhook-Secret: xK9mP2vL7nR4wQ8sT3fH6jD1gC5yE0zA" \
  -H "Content-Type: application/json" \
  -d '{"data": "secure"}'
```

### 2. Nunca Logar Dados Sensíveis

**❌ Evite:**
```javascript
// Function Node
console.log("Password:", items[0].json.password);  // MAU!
```

**✅ Faça:**
```javascript
// Function Node
console.log("Processing user:", items[0].json.email);  // Sem senha
```

### 3. Usar Variáveis de Ambiente

**Para valores sensíveis** (API keys, senhas):

1. **Adicione ao docker-compose.yml:**
   ```yaml
   services:
     n8n:
       environment:
         MY_SECRET_KEY: ${MY_SECRET_KEY}
   ```

2. **Adicione ao .env:**
   ```bash
   MY_SECRET_KEY=valor-secreto-aqui
   ```

3. **Use no n8n:**
   ```javascript
   const secretKey = $env.MY_SECRET_KEY;
   ```

### 4. Revisar Permissões de Credenciais

**Princípio do Menor Privilégio:**
- ✅ Compartilhe credenciais apenas com quem precisa
- ✅ Use credenciais diferentes para dev/prod
- ❌ Não compartilhe credenciais de produção com todos

### 5. Fazer Backup Regular

**O que fazer backup:**
- ✅ Workflows (exportar JSON)
- ✅ Credenciais (backup do `N8N_ENCRYPTION_KEY`)
- ✅ Banco de dados PostgreSQL (`n8n_db`)

```bash
# Backup workflows (via API ou UI)
# Settings → Workflows → Export All

# Backup banco de dados
docker compose exec postgresql pg_dump -U n8n_user n8n_db > n8n_backup.sql
```

---

## Solução de Problemas

### Problema: Workflow não executa

**Diagnóstico:**
```bash
# Ver logs do n8n
docker compose logs n8n --tail 100

# Ver execuções falhadas no UI
n8n → Executions → Filter: Failed
```

**Causas comuns:**
- ❌ Workflow não está ativo (toggle OFF)
- ❌ Webhook URL incorreta
- ❌ Credencial inválida
- ❌ Erro de lógica no workflow

### Problema: Credenciais não funcionam

**Teste a credencial:**
1. Settings → Credentials → [sua credencial]
2. Clique em "Test"
3. Veja mensagem de erro específica

**Causas comuns:**
- ❌ API key expirada
- ❌ URL base incorreta (http vs https)
- ❌ Credencial compartilhada com tipo errado de nó

### Problema: Webhook retorna 404

**Verifique:**
```bash
# Webhook deve estar em workflow ATIVO
# URL correta:
# ✅ https://n8n.mycompany.com.br/webhook/seu-path
# ❌ https://n8n.mycompany.com.br/webhook-test/seu-path (só dev)

# Testar webhook
curl -I https://n8n.mycompany.com.br/webhook/seu-path
# Deve retornar: 200 ou 405 (não 404)
```

### Problema: Execução travada (stuck)

**Identificar:**
- Execuções mostram status "Running" por muito tempo
- Workflow não completa

**Causa comum:** Node Wait ou Sleep muito longo

**Solução:**
```bash
# Cancelar execução travada
# UI: Executions → [execução] → Stop Execution

# Ver execuções em andamento
docker compose exec postgresql psql -U n8n_user -d n8n_db -c \
  "SELECT id, workflowId, mode, status, startedAt FROM execution_entity WHERE status = 'running';"
```

### Problema: Performance lenta

**Otimizações:**

1. **Reduzir dados processados:**
   ```javascript
   // Limit items processados
   return items.slice(0, 100);  // Apenas primeiros 100
   ```

2. **Usar Batch Processing:**
   ```
   Split In Batches Node
     Batch Size: 50
   ```

3. **Verificar uso de recursos:**
   ```bash
   docker stats borgstack-n8n-1
   ```

### Problema: Dados não fluem entre nodes

**Debug:**
1. **Ver output de cada node:**
   - Clique no node
   - Tab "Output" mostra dados que saíram

2. **Verificar conexões:**
   - Certifique-se que nodes estão conectados
   - Linhas devem estar visíveis

3. **Verificar expressões:**
   ```
   ❌ {{ json.name }}      (errado - falta $)
   ✅ {{ $json.name }}     (correto)
   ```

### Logs Importantes

```bash
# Ver todos os logs n8n
docker compose logs n8n --tail 200

# Seguir logs em tempo real
docker compose logs -f n8n

# Filtrar por erro
docker compose logs n8n | grep ERROR

# Ver logs de execução específica
# UI: Executions → [execução] → Execution Data → Logs
```

---

## 8. Dicas e Melhores Práticas

### 8.1 Configuração Otimizada

**Produção vs. Desenvolvimento:**
```bash
# .env para produção
N8N_BASIC_AUTH_ACTIVE=false  # Usar OAuth/LDAP
N8N_SECURE_COOKIE=true
N8N_ENCRYPTION_KEY=senha-forte-256bits

# Limites de execução
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_MAX_AGE=336  # 14 dias
```

**Recursos recomendados:**
- CPU: 2 vCPUs mínimo (4+ para produção)
- RAM: 2GB mínimo (4GB+ para produção)
- Disco: 10GB para workflows + logs

### 8.2 Performance

**Otimizar execuções:**
- Limite execuções simultâneas: máx 5-10
- Use sub-workflows para lógica reutilizável
- Evite loops infinitos (sempre adicione limite)
- Use batching para operações em massa

**Exemplo de batching:**
```javascript
// ❌ Ruim: 1000 requests individuais
for (item of items) {
  await httpRequest(item);
}

// ✅ Bom: 1 request com 1000 items
await httpRequest(items, {batch: true});
```

### 8.3 Segurança

**Credenciais:**
- Armazene credenciais no n8n (não hardcode em workflows)
- Use variáveis de ambiente para secrets sensíveis
- Rotacione API keys a cada 90 dias
- Nunca exponha credenciais em logs

**Webhooks seguros:**
```javascript
// Validar HMAC signature
const crypto = require('crypto');
const signature = crypto
  .createHmac('sha256', process.env.WEBHOOK_SECRET)
  .update(JSON.stringify($input.item.json))
  .digest('hex');

if (signature !== $input.item.json.signature) {
  throw new Error('Invalid signature');
}
```

### 8.4 Manutenção

**Backup de workflows:**
```bash
# Exportar todos os workflows (via API)
curl https://n8n.seudominio.com.br/api/v1/workflows \
  -H "X-N8N-API-KEY: $API_KEY" \
  > workflows-backup-$(date +%Y%m%d).json
```

**Limpeza de dados:**
```sql
-- Limpar execuções antigas (PostgreSQL)
DELETE FROM n8n_db.execution_entity
WHERE finished = true
  AND stopped_at < NOW() - INTERVAL '30 days';
```

**Monitoramento:**
- Acompanhe taxa de falhas: alvo < 1%
- Monitore tempo de execução: workflows lentos precisam otimização
- Configure alertas para falhas críticas

### 8.5 Troubleshooting Rápido

| Problema | Solução Rápida |
|----------|----------------|
| Workflow não dispara | Verificar se está ativo (toggle verde) |
| Timeout | Aumentar `EXECUTIONS_TIMEOUT` no .env |
| Credencial inválida | Recriar credencial do zero |
| Memória alta | Reduzir `EXECUTIONS_PROCESS_MAX` |
| Webhook 404 | Verificar URL pública do n8n acessível |

### 8.6 Casos de Uso Comuns

1. **Sincronização bidirecional** (WhatsApp ↔ Chatwoot)
   - Ver: [docs/04-integrations/whatsapp-chatwoot.md](../04-integrations/whatsapp-chatwoot.md)

2. **Processamento de mídia** (Directus → FileFlows)
   - Ver: [docs/04-integrations/directus-fileflows.md](../04-integrations/directus-fileflows.md)

3. **Relatórios automatizados**
   - Ver: [docs/09-workflows-exemplo.md](../09-workflows-exemplo.md#workflow-5-relatório-semanal-automatizado)

4. **Backup automático**
   - Ver: [docs/09-workflows-exemplo.md](../09-workflows-exemplo.md#workflow-2-backup-automático-de-banco-de-dados)

5. **Integração CRM**
   - Ver: [docs/09-workflows-exemplo.md](../09-workflows-exemplo.md#workflow-4-integração-com-crm-externo)

---

## Recursos Adicionais

**Documentação Oficial:**
- https://docs.n8n.io/

**Templates de Workflows:**
- https://n8n.io/workflows/

**Community Nodes:**
- https://www.npmjs.com/search?q=n8n-nodes-

**Forum da Comunidade:**
- https://community.n8n.io/

---

## Navegação

- **Anterior:** [Configuração do Sistema](../02-configuracao.md)
- **Próximo:** [Chatwoot - Atendimento ao Cliente](chatwoot.md)
- **Índice:** [Documentação Completa](../README.md)

---

**Última atualização:** 2025-10-08
**Versão do guia:** 1.0
**Compatível com:** n8n 1.112.6+, BorgStack v4+
