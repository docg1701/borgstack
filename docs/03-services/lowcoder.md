# Lowcoder - Plataforma de Aplicações Low-Code

Guia completo em português para uso do Lowcoder no BorgStack.

## Índice

1. [O que é Lowcoder](#o-que-é-lowcoder)
2. [Configuração Inicial](#configuração-inicial)
3. [Criando Seu Primeiro Aplicativo](#criando-seu-primeiro-aplicativo)
4. [Trabalhando com Fontes de Dados](#trabalhando-com-fontes-de-dados)
5. [Exemplos de Integração](#exemplos-de-integração)
6. [Práticas de Segurança](#práticas-de-segurança)
7. [Solução de Problemas](#solução-de-problemas)

---

## O que é Lowcoder

Lowcoder é uma plataforma de desenvolvimento low-code que permite criar aplicações de negócio personalizadas usando um construtor visual de arrastar e soltar (drag-and-drop).

### Principais Recursos

- **Construtor Visual**: Interface drag-and-drop para criar aplicações sem código
- **Componentes Prontos**: Tabelas, formulários, gráficos, botões e muito mais
- **Conexão com Dados**: PostgreSQL, REST APIs, MongoDB e outras fontes de dados
- **Integração com n8n**: Acione workflows automatizados a partir de aplicações
- **Consultas SQL**: Editor de queries com suporte a parâmetros dinâmicos
- **Publicação Instantânea**: Deploy de aplicações com um clique

### Casos de Uso Comuns

1. **Dashboards de Atendimento ao Cliente**
   - Visualize dados do Chatwoot em tempo real
   - Acompanhe métricas de atendimento
   - Crie relatórios personalizados

2. **Painéis de Monitoramento de Workflows**
   - Monitore execuções do n8n
   - Analise taxa de sucesso/falha
   - Visualize logs de erros

3. **Construtor de Campanhas WhatsApp**
   - Crie formulários para envio de mensagens
   - Integre com Evolution API via n8n
   - Acompanhe status de entrega

4. **Painel Administrativo de Conteúdo**
   - Gerencie conteúdo do Directus
   - Operações CRUD em coleções
   - Workflow de publicação de conteúdo

---

## Configuração Inicial

### Pré-requisitos

Antes de usar o Lowcoder, verifique:

1. **DNS Configurado**: Registro A para `lowcoder.{SEU_DOMINIO}` apontando para o servidor
2. **SSL Ativo**: Certificado Let's Encrypt gerado automaticamente pelo Caddy
3. **Serviços Rodando**: Container Lowcoder está saudável

```bash
# Verificar DNS
dig lowcoder.exemplo.com.br +short

# Verificar status do container
docker compose ps lowcoder

# Verificar logs do Lowcoder
docker compose logs lowcoder

# Verificar health check
docker compose exec lowcoder curl -f http://localhost:3000/api/health
```

### Primeiro Acesso

1. **Acessar Interface Web**
   - URL: `https://lowcoder.{SEU_DOMINIO}`
   - Aguarde 30-60 segundos na primeira vez (geração de SSL)

2. **Credenciais de Administrador**
   - Email: Valor de `LOWCODER_ADMIN_EMAIL` no arquivo `.env`
   - Senha: Valor de `LOWCODER_ADMIN_PASSWORD` no arquivo `.env`

```bash
# Visualizar credenciais do administrador
grep LOWCODER_ADMIN .env
```

3. **Login Inicial**
   - Clique em "Sign in"
   - Digite email e senha do arquivo `.env`
   - Clique em "Sign in" para entrar

### Alterar Senha do Administrador (Recomendado)

⚠️ **IMPORTANTE**: Altere a senha auto-gerada para uma senha memorável.

1. Faça login no Lowcoder
2. Clique no ícone de perfil (canto superior direito)
3. Selecione "Settings"
4. Navegue até aba "Account"
5. Altere a senha
6. Salve as alterações

**CRÍTICO**: Atualize o arquivo `.env` com a nova senha para evitar confusão durante reinicializações do container.

---

## Criando Seu Primeiro Aplicativo

### Passo 1: Criar Nova Aplicação

1. Faça login no Lowcoder
2. Clique no botão **"Create New"** (canto superior direito)
3. Selecione **"Application"**
4. Escolha um template ou comece com **"Blank App"**
5. Dê um nome à aplicação (ex: "Dashboard de Atendimento")
6. Clique em **"Create"**

### Passo 2: Interface do Construtor

**Componentes Principais**:

- **Canvas** (centro): Área de design drag-and-drop
- **Painel de Componentes** (esquerda): Componentes de UI pré-construídos
- **Painel Inspetor** (direita): Propriedades e binding de dados
- **Painel de Queries** (inferior): Consultas a fontes de dados e APIs

### Passo 3: Adicionar Fonte de Dados

Antes de criar queries, configure uma fonte de dados:

1. Clique em **"Data Sources"** (menu lateral esquerdo)
2. Clique em **"+ New Data Source"**
3. Selecione o tipo (PostgreSQL, REST API, etc.)
4. Configure a conexão (veja seção [Trabalhando com Fontes de Dados](#trabalhando-com-fontes-de-dados))
5. Teste a conexão
6. Salve a fonte de dados

### Passo 4: Criar Consulta (Query)

**Exemplo: Lista de Conversas do Chatwoot**

1. No **Painel de Queries** (inferior), clique em **"+ New Query"**
2. Selecione a fonte de dados PostgreSQL (`chatwoot_db_readonly`)
3. Escreva a query SQL:
   ```sql
   SELECT
     c.id,
     c.display_id,
     ct.name as contact_name,
     c.status,
     c.created_at
   FROM conversations c
   LEFT JOIN contacts ct ON c.contact_id = ct.id
   WHERE c.status = 'open'
   ORDER BY c.created_at DESC
   LIMIT 100
   ```
4. Clique em **"Run"** para testar a query
5. Nomeie a query: `get_conversas_abertas`

### Passo 5: Adicionar Componente de Tabela

1. No **Painel de Componentes**, arraste um componente **"Table"** para o Canvas
2. No **Painel Inspetor** (direita), configure:
   - **Data**: `{{ get_conversas_abertas.data }}`
   - A tabela exibirá automaticamente os dados da query
3. Personalize colunas, filtros e ordenação conforme necessário

### Passo 6: Adicionar Interatividade

**Exemplo: Botão para Atualizar Dados**

1. Arraste um componente **"Button"** para o Canvas
2. Configure o texto do botão: "Atualizar"
3. No evento **onClick**, selecione: **Run Query** → `get_conversas_abertas`
4. Agora o botão atualiza a tabela quando clicado

### Passo 7: Publicar Aplicação

1. Clique em **"Publish"** (canto superior direito)
2. Revise a aplicação no modo preview
3. Confirme a publicação
4. A aplicação estará disponível para usuários

---

## Trabalhando com Fontes de Dados

### PostgreSQL - Bancos de Dados do BorgStack

⚠️ **Prática de Segurança**: Use o usuário somente-leitura (`lowcoder_readonly_user`) para aplicações de consulta (dashboards, relatórios). Isso implementa o princípio do menor privilégio.

#### Configuração Única: Criar Usuário Somente-Leitura

Execute uma única vez no PostgreSQL:

```bash
# Copiar script SQL para container PostgreSQL
docker compose cp config/postgresql/create-lowcoder-readonly-users.sql postgresql:/tmp/

# Executar script com senha do .env
docker compose exec postgresql psql -U postgres \
  -v LOWCODER_READONLY_DB_PASSWORD="$(grep LOWCODER_READONLY_DB_PASSWORD .env | cut -d= -f2)" \
  -f /tmp/create-lowcoder-readonly-users.sql
```

**Verificar Criação do Usuário**:

```bash
# Listar usuários (deve mostrar lowcoder_readonly_user)
docker compose exec postgresql psql -U postgres -c "\du"

# Verificar permissões somente-leitura em n8n_db
docker compose exec postgresql psql -U postgres -d n8n_db \
  -c "SELECT grantee, privilege_type FROM information_schema.role_table_grants WHERE grantee = 'lowcoder_readonly_user';"
```

#### Conectar PostgreSQL no Lowcoder

**Acesso Somente-Leitura (RECOMENDADO)**:

1. **Navegue para "Data Sources"** (menu lateral esquerdo)
2. **Clique em "+ New Data Source"**
3. **Selecione "PostgreSQL"**
4. **Configure a conexão**:
   - **Nome**: `chatwoot_db_readonly` (nome descritivo)
   - **Host**: `postgresql` (nome DNS do Docker)
   - **Port**: `5432`
   - **Database**: `chatwoot_db` (ou `n8n_db`, `evolution_db`, `directus_db`)
   - **Username**: `lowcoder_readonly_user`
   - **Password**: Valor de `LOWCODER_READONLY_DB_PASSWORD` do arquivo `.env`
   - **SSL Mode**: `disable` (rede interna)
5. **Teste a Conexão**: Clique em "Test Connection"
6. **Salvar**: Clique em "Save"

**Recuperar Senha Somente-Leitura**:

```bash
# Visualizar senha do usuário somente-leitura
grep LOWCODER_READONLY_DB_PASSWORD .env
```

#### Bancos de Dados Disponíveis

| Banco de Dados | Usuário Somente-Leitura | Propósito | Casos de Uso |
|----------------|-------------------------|-----------|--------------|
| `n8n_db` | `lowcoder_readonly_user` | Dados de workflows n8n | Dashboard de execuções, análise de automações |
| `chatwoot_db` | `lowcoder_readonly_user` | Conversas de atendimento | Métricas de agentes, histórico de conversas |
| `evolution_db` | `lowcoder_readonly_user` | Histórico de mensagens WhatsApp | Análise de mensagens, relatórios de campanhas |
| `directus_db` | `lowcoder_readonly_user` | Conteúdo CMS | Estatísticas de conteúdo, análise de coleções |

**Formato da String de Conexão** (para referência):
```
postgresql://lowcoder_readonly_user:${LOWCODER_READONLY_DB_PASSWORD}@postgresql:5432/chatwoot_db
```

### REST API - Evolution API, Chatwoot, n8n

#### Conectar Evolution API

1. **Navegue para "Data Sources"**
2. **Clique em "+ New Data Source"**
3. **Selecione "REST API"**
4. **Configure**:
   - **Nome**: `evolution_api`
   - **Base URL**: `https://evolution.{SEU_DOMINIO}`
   - **Headers**:
     - `apikey`: Valor de `EVOLUTION_API_KEY` do arquivo `.env`
     - `Content-Type`: `application/json`
5. **Teste a API**:
   - Crie uma query: `GET /instance/fetchInstances`
   - Clique em "Run" para verificar acesso
6. **Salvar Data Source**

**Exemplo de Query - Enviar Mensagem WhatsApp**:

```javascript
// Nome da Query: enviar_mensagem_whatsapp
// Método: POST
// URL: /message/sendText/{{ instanceName.value }}
// Body:
{
  "number": "{{ phoneNumber.value }}",
  "text": "{{ messageText.value }}"
}
```

#### Conectar Chatwoot API

1. **Criar REST API Data Source**:
   - **Nome**: `chatwoot_api`
   - **Base URL**: `https://chatwoot.{SEU_DOMINIO}/api/v1`
   - **Headers**:
     - `api_access_token`: Valor de `CHATWOOT_API_TOKEN` do arquivo `.env`
     - `Content-Type`: `application/json`

**Exemplo de Query - Criar Contato no Chatwoot**:

```javascript
// Nome da Query: criar_contato_chatwoot
// Método: POST
// URL: /accounts/1/contacts
// Body:
{
  "name": "{{ customerName.value }}",
  "email": "{{ customerEmail.value }}",
  "phone_number": "{{ customerPhone.value }}"
}
```

#### Conectar n8n Webhooks

Lowcoder pode acionar workflows do n8n via webhooks.

1. **Criar webhook no n8n** (veja seção [Exemplos de Integração](#exemplos-de-integração))
2. **No Lowcoder, criar REST API data source**:
   - **Nome**: `n8n_webhooks`
   - **Base URL**: `https://n8n.{SEU_DOMINIO}/webhook`
   - **Authentication**: None (rede interna)

3. **Criar Query na Aplicação**:
   ```javascript
   // Método: POST
   // URL: /lowcoder-trigger
   // Body:
   {
     "action": "{{ actionSelect.value }}",
     "data": {
       "customer_id": {{ customerTable.selectedRow.id }},
       "message": {{ messageInput.value }}
     }
   }
   ```

4. **Acionar via Botão**:
   - Evento onClick do botão → Run query `webhook_trigger`

---

## Exemplos de Integração

### Padrão 1: Lowcoder → n8n Webhook

**Caso de Uso**: Acionar workflows n8n a partir de aplicações Lowcoder

**Configuração no Lowcoder**:

1. **Criar REST API Datasource**:
   - Nome: `n8n_webhooks`
   - Base URL: `https://n8n.{SEU_DOMINIO}/webhook`

2. **Criar Query**:
   ```javascript
   // Nome: trigger_workflow
   // Método: POST
   // URL: /lowcoder-trigger
   // Body:
   {
     "action": "create_record",
     "data": {
       "name": {{ nameInput.value }},
       "email": {{ emailInput.value }}
     }
   }
   ```

3. **Adicionar Botão**:
   - Texto: "Executar Workflow"
   - onClick: Run query `trigger_workflow`

**Workflow n8n Necessário**:

Importe o workflow `config/n8n/workflows/05-lowcoder-webhook-integration.json` no n8n.

### Padrão 2: Lowcoder → Evolution API (Enviar WhatsApp)

**Caso de Uso**: Enviar mensagens WhatsApp a partir de aplicações Lowcoder

**Opção A: Chamada Direta à Evolution API**

1. **Criar REST API Datasource**:
   - Nome: `evolution_api`
   - Base URL: `https://evolution.{SEU_DOMINIO}`
   - Headers: `apikey`: `${EVOLUTION_API_KEY}`

2. **Criar Query**:
   ```javascript
   // Nome: enviar_whatsapp
   // Método: POST
   // URL: /message/sendText/{{ instanceName.value }}
   // Body:
   {
     "number": {{ phoneNumber.value }},
     "text": {{ messageText.value }}
   }
   ```

3. **Componentes de UI**:
   - Input: `instanceName` (ex: "customer_support")
   - Input: `phoneNumber` (ex: "5511987654321")
   - TextArea: `messageText`
   - Button: "Enviar WhatsApp" → onClick: Run query `enviar_whatsapp`

**Opção B: Via Workflow n8n (Recomendado para Lógica Complexa)**

Use workflow n8n para validação, logging e tratamento de erros.

### Padrão 3: Lowcoder → Chatwoot API (Criar Contatos/Conversas)

**Caso de Uso**: Criar contatos e conversas no Chatwoot a partir do Lowcoder

**Configuração**:

1. **Criar REST API Datasource**:
   - Nome: `chatwoot_api`
   - Base URL: `https://chatwoot.{SEU_DOMINIO}/api/v1`
   - Headers: `api_access_token`: `${CHATWOOT_API_TOKEN}`

2. **Query para Criar Contato**:
   ```javascript
   // Nome: criar_contato
   // Método: POST
   // URL: /accounts/1/contacts
   // Body:
   {
     "name": {{ customerName.value }},
     "email": {{ customerEmail.value }},
     "phone_number": {{ customerPhone.value }}
   }
   ```

3. **Query para Criar Conversa**:
   ```javascript
   // Nome: criar_conversa
   // Método: POST
   // URL: /accounts/1/conversations
   // Body:
   {
     "contact_id": {{ criar_contato.data.payload.contact.id }},
     "inbox_id": 1,
     "status": "open",
     "message": {
       "content": {{ initialMessage.value }},
       "message_type": "incoming"
     }
   }
   ```

4. **Formulário**:
   - Inputs: `customerName`, `customerEmail`, `customerPhone`, `initialMessage`
   - Botão: "Criar Contato & Conversa" → Queries sequenciais:
     1. Run `criar_contato`
     2. On success, run `criar_conversa`

### Padrão 4: Workflow n8n Acionado por Formulário Lowcoder

**Caso de Uso**: Automação multi-etapas acionada por envio de formulário

**Exemplo: Workflow de Processamento de Pedido**

**Formulário Lowcoder**:
- Detalhes do cliente (nome, email, telefone)
- Itens do pedido (componente de tabela)
- Endereço de entrega (inputs de texto)
- Botão "Enviar Pedido"

**Etapas do Workflow n8n**:

1. Webhook Trigger (`/webhook/process-order`)
2. Validar dados do pedido
3. Criar contato no Chatwoot
4. Armazenar pedido no banco de dados
5. Enviar confirmação via WhatsApp (Evolution API)
6. Criar conversa no Chatwoot para rastreamento
7. Enviar email de confirmação
8. Retornar resposta ao Lowcoder

**Query Lowcoder**:

```javascript
// Nome: submit_order
// Método: POST
// URL: https://n8n.{SEU_DOMINIO}/webhook/process-order
// Body:
{
  "customer": {
    "name": {{ customerName.value }},
    "email": {{ customerEmail.value }},
    "phone": {{ customerPhone.value }}
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

---

## Práticas de Segurança

### Lista de Verificação de Segurança para Desenvolvedores

Use esta lista ao construir aplicações Lowcoder:

**Segurança de Fontes de Dados:**
- [ ] Use `lowcoder_readonly_user` para aplicações somente-leitura (dashboards, relatórios)
- [ ] Nunca use contas de proprietário de serviço (`n8n_user`, `chatwoot_user`) a menos que absolutamente necessário
- [ ] Armazene todas as senhas de datasources no Lowcoder (criptografadas com `LOWCODER_ENCRYPTION_PASSWORD`)
- [ ] Nunca hardcode credenciais em código de aplicação ou queries
- [ ] Verifique se conexões de datasource usam rede interna (`postgresql:5432`, não IPs externos)

**Segurança de Queries:**
- [ ] Use queries parametrizadas (NÃO concatenação de strings) para prevenir injeção SQL
- [ ] Valide todas as entradas de usuário antes de usar em queries
- [ ] Limite resultados de queries (use cláusula `LIMIT`) para prevenir problemas de performance
- [ ] Evite `SELECT *` - liste explicitamente colunas necessárias
- [ ] Teste queries com entrada maliciosa (ex: `'; DROP TABLE users; --`)

**Controle de Acesso a Aplicações:**
- [ ] Configure permissões apropriadas de aplicação (Owner, Editor, Viewer)
- [ ] Desabilite "Public Access" a menos que necessário para usuários externos
- [ ] Use controle de acesso baseado em funções (RBAC) para aplicações sensíveis
- [ ] Revise lista de usuários regularmente e remova usuários inativos
- [ ] Exija autenticação para todas as aplicações (sem acesso anônimo)

**Proteção de Dados:**
- [ ] Mascare dados sensíveis (senhas, cartões de crédito, PII) em componentes de UI
- [ ] Filtre colunas sensíveis em queries (não exponha ao frontend)
- [ ] Implemente políticas de retenção de dados (auto-deletar registros antigos)
- [ ] Use HTTPS para todas as chamadas de API (webhooks n8n, Evolution API, etc.)
- [ ] Criptografe dados sensíveis em repouso (use extensão pgcrypto do PostgreSQL)

### Princípio do Menor Privilégio

**Acesso a Banco de Dados:**

Sempre conceda **permissões mínimas necessárias** a datasources Lowcoder:

1. **Aplicações Somente-Leitura** (dashboards, relatórios, análises):
   - ✅ Use `lowcoder_readonly_user` (apenas SELECT)
   - ❌ Não use contas de proprietário de serviço com acesso total

2. **Aplicações com Escrita** (formulários, entrada de dados):
   - ✅ Crie usuário dedicado com permissões INSERT/UPDATE apenas em tabelas específicas
   - ❌ Não conceda permissões DELETE ou TRUNCATE a menos que necessário

3. **Aplicações Administrativas** (gerenciamento de usuários, configuração de sistema):
   - ✅ Crie usuário admin separado com permissões completas
   - ✅ Restrinja acesso apenas a usuários admin (não todos os usuários Lowcoder)
   - ❌ Não use superusuário PostgreSQL (`postgres`) no Lowcoder

### Prevenção de Injeção SQL

**Código Vulnerável (NÃO FAÇA ISSO):**

```sql
-- ❌ PERIGOSO: Concatenação de string permite injeção SQL
SELECT * FROM users WHERE email = '{{ textInput1.value }}'
```

**Exemplo de Ataque:**
- Entrada do usuário: `admin@exemplo.com' OR '1'='1`
- Query executada: `SELECT * FROM users WHERE email = 'admin@exemplo.com' OR '1'='1'`
- Resultado: Retorna TODOS os usuários (violação de segurança)

**Código Seguro (USE ISSO):**

```sql
-- ✅ SEGURO: Query parametrizada (Lowcoder trata o escape)
SELECT * FROM users WHERE email = {{ textInput1.value }}
```

**Melhores Práticas do Query Builder:**

1. **Use Variáveis Lowcoder:** `{{ componentName.value }}` (automaticamente escapado)
2. **Valide Entradas:** Use validação de componente (formato de email, padrões regex)
3. **Whitelist de Valores:** Use componentes dropdown/select ao invés de texto livre
4. **Escape de Caracteres Especiais:** Se concatenação de string for inevitável, use função PostgreSQL `quote_literal()`

### Armazenamento Seguro de Credenciais

**Criptografia de Credenciais Lowcoder:**

Todas as credenciais de datasource no Lowcoder são criptografadas usando variáveis de ambiente `LOWCODER_ENCRYPTION_PASSWORD` e `LOWCODER_ENCRYPTION_SALT`.

**Melhores Práticas:**

1. **Chaves de Criptografia Fortes:**
   ```bash
   # Gerar chaves de criptografia fortes (32 caracteres)
   openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
   ```

2. **Backup de Chaves de Criptografia:**
   - Armazene `LOWCODER_ENCRYPTION_PASSWORD` em gerenciador de senhas
   - Armazene `LOWCODER_ENCRYPTION_SALT` em gerenciador de senhas
   - Sem essas chaves, todas as credenciais de datasource ficam inacessíveis

3. **Rotação de Chaves (Anual):**
   - Exporte todas as configurações de datasource (backup manual)
   - Gere novas chaves de criptografia
   - Atualize .env com novas chaves
   - Reinicie Lowcoder: `docker compose restart lowcoder`
   - Re-digite todas as senhas de datasource na UI do Lowcoder

4. **Nunca Commit Credenciais:**
   - ✅ Arquivo `.env` está em `.gitignore`
   - ❌ Nunca commit senhas de datasource no git
   - ❌ Nunca compartilhe chaves de criptografia via email/chat

### Gerenciamento de Permissões de Usuários

**Funções de Usuário Lowcoder:**

| Função | Permissões | Caso de Uso |
|--------|------------|-------------|
| **Admin** | Acesso total: Criar/editar/deletar apps, gerenciar usuários, configurações de sistema | Administradores de sistema, equipe de TI |
| **Developer** | Criar/editar próprios apps, visualizar todos os apps | Desenvolvedores de aplicações, power users |
| **Viewer** | Visualizar apps publicados apenas, sem edição | Usuários finais, usuários de negócio |

**Permissões em Nível de Aplicação:**

1. **Aplicação Privada** (padrão):
   - Apenas criador e usuários explicitamente concedidos podem acessar
   - Recomendado para aplicações de dados sensíveis

2. **Aplicação Compartilhada**:
   - Compartilhar com usuários ou grupos específicos
   - Owner: Controle total (pode deletar app)
   - Editor: Pode modificar código da aplicação
   - Viewer: Acesso somente-leitura à versão publicada

3. **Aplicação Pública**:
   - Todos os usuários autenticados do Lowcoder podem acessar
   - ⚠️ AVISO: Não use para dados sensíveis

**Melhores Práticas:**

- Revise permissões de usuários trimestralmente
- Remova usuários que deixaram a organização imediatamente
- Use princípio do menor privilégio (conceda função mínima necessária)
- Documente proprietários e mantenedores de aplicações

---

## Solução de Problemas

### Falha de Conexão com MongoDB

**Sintomas**: UI Lowcoder mostra "Database connection error" ou logs mostram falhas de conexão MongoDB

**Solução**:

```bash
# Verificar se MongoDB está rodando e saudável
docker compose ps mongodb

# Verificar logs do MongoDB
docker compose logs mongodb | tail -n 50

# Testar conexão MongoDB do container Lowcoder
docker compose exec lowcoder curl -f mongodb://lowcoder_user:${LOWCODER_DB_PASSWORD}@mongodb:27017/lowcoder?authSource=lowcoder

# Verificar LOWCODER_MONGODB_URL em docker-compose.yml
docker compose config | grep LOWCODER_MONGODB_URL

# Verificar LOWCODER_DB_PASSWORD em .env
grep LOWCODER_DB_PASSWORD .env
```

**Causas Comuns**:
- Container MongoDB não iniciado: `docker compose up -d mongodb`
- Senha incorreta em `.env`: Regenere ou corrija `LOWCODER_DB_PASSWORD`
- Usuário MongoDB não criado: Verifique script de inicialização `config/mongodb/init-mongo.js`

### Falha de Conexão com Redis

**Sintomas**: UI Lowcoder lenta ou problemas de gerenciamento de sessão

**Solução**:

```bash
# Verificar se Redis está rodando
docker compose ps redis

# Verificar logs do Redis
docker compose logs redis | tail -n 50

# Testar conexão Redis
docker compose exec redis redis-cli -a "$(grep REDIS_PASSWORD .env | cut -d= -f2)" PING

# Verificar LOWCODER_REDIS_URL em docker-compose.yml
docker compose config | grep LOWCODER_REDIS_URL

# Reiniciar Redis se necessário
docker compose restart redis
```

### Login de Admin Não Funciona

**Sintomas**: Erro "Invalid credentials" ao fazer login com conta admin

**Solução**:

```bash
# Verificar credenciais de admin em .env
grep LOWCODER_ADMIN .env

# Verificar logs do Lowcoder para criação de conta admin
docker compose logs lowcoder | grep -i admin

# Reiniciar Lowcoder para recriar conta admin (se primeira inicialização falhou)
docker compose restart lowcoder

# Aguardar inicialização (60 segundos)
sleep 60

# Verificar logs novamente
docker compose logs lowcoder | grep -i "admin"
```

### Falha de Conexão com Datasource

**Sintomas**: Erro "Connection failed" ao testar datasources PostgreSQL ou API

**Solução de Problemas de Conexão PostgreSQL**:

```bash
# Verificar se PostgreSQL está rodando
docker compose ps postgresql

# Testar conexão PostgreSQL do container Lowcoder
docker compose exec lowcoder pg_isready -h postgresql -p 5432

# Verificar se banco de dados existe e usuário tem permissões
docker compose exec postgresql psql -U postgres -c "\l"  # Listar bancos
docker compose exec postgresql psql -U postgres -c "\du"  # Listar usuários

# Testar acesso específico ao banco
docker compose exec postgresql psql -U lowcoder_readonly_user -d chatwoot_db -c "SELECT 1"
```

**Garantir que Lowcoder Pode Alcançar PostgreSQL**:
- Ambos os containers devem estar na rede `borgstack_internal`
- Use hostname `postgresql` (DNS do Docker)
- Verifique senha do usuário do arquivo `.env`

**Solução de Problemas de Conexão REST API**:

```bash
# Testar API do container Lowcoder
docker compose exec lowcoder curl -f https://evolution.exemplo.com.br/instance/fetchInstances \
  -H "apikey: $(grep EVOLUTION_API_KEY .env | cut -d= -f2)"

# Verificar regras de firewall (se API externa)
curl -I https://external-api.exemplo.com
```

### Problemas de Conexão com Usuário Somente-Leitura

**Sintomas**: Erro de permissão ao testar conexão com `lowcoder_readonly_user`

**Solução**:

```bash
# Verificar se lowcoder_readonly_user existe
docker compose exec postgresql psql -U postgres -c "\du" | grep lowcoder_readonly

# Testar conexão de usuário somente-leitura ao n8n_db
docker compose exec postgresql psql -U lowcoder_readonly_user -d n8n_db -c "SELECT 1" 2>&1

# Verificar permissões em banco específico
docker compose exec postgresql psql -U postgres -d chatwoot_db \
  -c "SELECT grantee, privilege_type FROM information_schema.role_table_grants WHERE grantee = 'lowcoder_readonly_user' LIMIT 10;"

# Se usuário não existe, re-executar script de criação
docker compose cp config/postgresql/create-lowcoder-readonly-users.sql postgresql:/tmp/
docker compose exec postgresql psql -U postgres \
  -v LOWCODER_READONLY_DB_PASSWORD="$(grep LOWCODER_READONLY_DB_PASSWORD .env | cut -d= -f2)" \
  -f /tmp/create-lowcoder-readonly-users.sql
```

**Problemas Comuns com Usuário Somente-Leitura**:
- Usuário não criado: Execute script `config/postgresql/create-lowcoder-readonly-users.sql`
- Senha errada: Verifique se `LOWCODER_READONLY_DB_PASSWORD` em `.env` corresponde à senha do usuário PostgreSQL
- Sem permissões em banco: Re-execute script SQL para conceder permissões
- Tabelas criadas após criação do usuário: Execute `GRANT SELECT ON ALL TABLES IN SCHEMA public TO lowcoder_readonly_user;` no banco afetado

### Aplicação Não Salva

**Sintomas**: Alterações na aplicação não persistem após recarregar página

**Solução**:

```bash
# Verificar se volume borgstack_lowcoder_stacks está montado
docker compose config | grep -A5 "borgstack_lowcoder_stacks"

# Verificar permissões do volume
docker compose exec lowcoder ls -la /lowcoder-stacks

# Verificar conexão MongoDB (aplicações armazenadas em MongoDB)
docker compose exec lowcoder curl -f http://localhost:3000/api/health

# Visualizar logs Lowcoder para erros de salvamento
docker compose logs lowcoder | grep -i "save\|error"

# Reiniciar Lowcoder
docker compose restart lowcoder
```

### Health Check Falhando

**Sintomas**: Container Lowcoder mostra status "unhealthy"

**Solução**:

```bash
# Verificar comando de health check
docker compose config | grep -A10 "lowcoder:" | grep -A5 "healthcheck"

# Testar endpoint de health manualmente
docker compose exec lowcoder curl -f http://localhost:3000/api/health

# Visualizar logs de inicialização do Lowcoder
docker compose logs lowcoder | grep -i "started\|ready"

# Verificar se Spring Boot iniciou
docker compose logs lowcoder | grep "Started"

# Verificar se serviço Node.js iniciou
docker compose logs lowcoder | grep "Node service"
```

**Causas Comuns**:
- Servidor lento: Aumente `start_period` para 90s ou 120s em docker-compose.yml
- MongoDB/Redis não prontos: Garanta que dependências iniciem primeiro
- Conflito de porta 3000: Verifique se outro serviço está usando porta 3000

### Problemas de Performance (UI Lenta)

**Sintomas**: UI Lowcoder lenta, execução de query demorada

**Solução**:

```bash
# Verificar uso de recursos do container
docker stats lowcoder

# Verificar performance do MongoDB
docker compose exec mongodb mongosh -u admin -p "$(grep MONGODB_ROOT_PASSWORD .env | cut -d= -f2)" --authenticationDatabase admin --eval "db.serverStatus()"

# Verificar performance do Redis
docker compose exec redis redis-cli -a "$(grep REDIS_PASSWORD .env | cut -d= -f2)" INFO stats

# Reiniciar Lowcoder para limpar cache
docker compose restart lowcoder

# Verificar recursos do servidor (RAM, CPU)
htop
df -h
```

**Ajustes de Performance**:
- **MongoDB**: Adicione índices a campos consultados frequentemente
- **Redis**: Aumente limite de memória se necessário (padrão: 8GB)
- **Lowcoder**: Aumente limite de memória do container em docker-compose.yml

---

## Recursos Adicionais

- **Documentação Oficial Lowcoder**: [https://docs.lowcoder.cloud](https://docs.lowcoder.cloud)
- **Fórum da Comunidade**: [https://github.com/lowcoderorg/lowcoder/discussions](https://github.com/lowcoderorg/lowcoder/discussions)
- **Vídeo Tutoriais**: Busque "Lowcoder tutorials" no YouTube
- **Guia Técnico Completo** (Inglês): `config/lowcoder/README.md`
- **Padrões de Integração n8n**: `config/n8n/workflows/README.md`
- **Documentação Evolution API**: `config/evolution/README.md`
- **Documentação Chatwoot**: `config/chatwoot/README.md`

---

## Suporte

Para problemas específicos do BorgStack:
- Verificar `docker compose logs lowcoder` para mensagens de erro
- Revisar este guia de solução de problemas
- Verificar configuração `.env`
- Garantir que todas as dependências (MongoDB, Redis) estejam saudáveis

Para questões específicas do Lowcoder:
- Documentação oficial Lowcoder
- GitHub Issues: [https://github.com/lowcoderorg/lowcoder/issues](https://github.com/lowcoderorg/lowcoder/issues)
