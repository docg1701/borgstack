# Documentação BorgStack

> **Documentação completa em Português Brasileiro**

Bem-vindo à documentação completa do BorgStack! Esta documentação cobre desde a instalação básica até otimização avançada de performance, segurança e integração de serviços.

---

## 📚 Índice Geral

### 1. Introdução e Setup

#### 📖 [01 - Guia de Instalação](01-instalacao.md)
Instalação completa do BorgStack passo a passo.

**Conteúdo:**
- Requisitos de sistema
- Script de bootstrap automatizado
- Instalação manual
- Configuração de DNS e SSL
- Primeiros passos
- Validação de instalação

**Começar aqui se:** Você está instalando o BorgStack pela primeira vez.

---

#### ⚙️ [02 - Guia de Configuração](02-configuracao.md)
Configuração detalhada de variáveis de ambiente e personalização de serviços.

**Conteúdo:**
- Estrutura do arquivo `.env`
- Configuração de domínios
- Senhas e segurança
- Configuração de cada serviço
- Variáveis avançadas
- Troubleshooting de configuração

**Começar aqui se:** Você quer personalizar a configuração padrão ou entender as variáveis de ambiente.

---

### 2. Guias de Serviços

Documentação detalhada de cada serviço incluído no BorgStack.

#### 🔧 [03-services/n8n.md](03-services/n8n.md)
**n8n - Automação de Workflows**

Plataforma de automação visual com 400+ integrações.

- Setup e configuração inicial
- Criação de workflows
- Webhooks e triggers
- Integração com PostgreSQL, Redis, API externa
- Credentials e segurança
- Workflows de exemplo
- Backup e restauração

---

#### 💬 [03-services/chatwoot.md](03-services/chatwoot.md)
**Chatwoot - Atendimento ao Cliente**

Plataforma omnichannel de comunicação com clientes.

- Configuração inicial
- Criação de inboxes (WhatsApp, Email, API)
- Gerenciamento de agentes
- Automações e chatbots
- API e webhooks
- Integração com n8n
- Relatórios e métricas

---

#### 📱 [03-services/evolution-api.md](03-services/evolution-api.md)
**Evolution API - Gateway WhatsApp Business**

API completa para WhatsApp Business com múltiplas instâncias.

- Criação de instâncias WhatsApp
- Autenticação via QR Code
- Envio e recebimento de mensagens
- Webhooks para integração
- Grupos e broadcasts
- Mídia e documentos
- Integração com Chatwoot via n8n

---

#### 🌐 [03-services/caddy.md](03-services/caddy.md)
**Caddy - Reverse Proxy com HTTPS Automático**

Servidor web moderno com SSL automático via Let's Encrypt.

- Configuração do Caddyfile
- SSL/TLS automático
- Reverse proxy para todos os serviços
- Custom domains
- Redirecionamentos e rewrites
- Rate limiting
- Logging e debugging

---

#### 🗄️ [03-services/postgresql.md](03-services/postgresql.md)
**PostgreSQL - Banco de Dados Relacional**

Banco de dados compartilhado por n8n, Chatwoot, Directus e Evolution API.

- Arquitetura de 4 databases isolados
- Backup e restauração
- Tuning de performance
- Índices e otimização de queries
- pgvector para AI/embeddings
- Manutenção (VACUUM, ANALYZE)
- Monitoramento

---

#### 📊 [03-services/mongodb.md](03-services/mongodb.md)
**MongoDB - Banco NoSQL**

Banco de dados dedicado para Lowcoder.

- Configuração e setup
- Backup e restauração
- Aggregation pipeline
- Índices e performance
- Replicação e sharding
- Monitoramento
- Troubleshooting

---

#### ⚡ [03-services/redis.md](03-services/redis.md)
**Redis - Cache e Message Broker**

Cache compartilhado e fila de mensagens para múltiplos serviços.

- Organização de databases (0-3)
- Estruturas de dados (Strings, Hashes, Lists, Sets)
- Persistência (RDB e AOF)
- Eviction policies
- Pub/Sub messaging
- Performance tuning
- Monitoramento

---

### 3. Guias de Integração

Tutoriais práticos de integração entre serviços.

#### 🔗 [04-integrations/whatsapp-chatwoot.md](04-integrations/whatsapp-chatwoot.md)
**Integração WhatsApp → Chatwoot via n8n**

Tutorial completo de integração bidirecional WhatsApp e Chatwoot.

**O que você vai aprender:**
- Arquitetura da integração
- Workflow 1: WhatsApp → Chatwoot (mensagens recebidas)
- Workflow 2: Chatwoot → WhatsApp (respostas de agentes)
- Configuração de webhooks
- Sincronização de contatos
- Tratamento de erros
- Problemas comuns e soluções

**Resultado:** Atendimento completo via WhatsApp no Chatwoot.

---

#### 🔗 [04-integrations/n8n-services.md](04-integrations/n8n-services.md)
**Integrações n8n com Serviços BorgStack**

Guia de integração do n8n com PostgreSQL, Redis, Directus, SeaweedFS, FileFlows e Lowcoder.

**Integrações cobertas:**
1. **n8n → PostgreSQL:** Queries, inserções, relatórios
2. **n8n → Redis:** Cache, filas, pub/sub
3. **n8n → Directus:** CMS, webhooks, automações
4. **n8n → SeaweedFS:** Upload e download de arquivos
5. **n8n → FileFlows:** Processamento de mídia
6. **n8n → Lowcoder:** Trigger de workflows via apps

**Resultado:** Automações avançadas conectando todos os serviços.

---

### 4. Manutenção e Operação

#### 🚨 [05 - Solução de Problemas](05-solucao-de-problemas.md)
**Troubleshooting e Diagnóstico**

Guia completo para resolver problemas comuns e avançados.

**Conteúdo:**
- Fluxo de diagnóstico (flowchart)
- Problemas de instalação
- Problemas de containers Docker
- Problemas de rede
- Problemas de banco de dados
- Problemas de integração
- Disaster recovery
- 23 problemas específicos com soluções passo a passo

**Começar aqui se:** Algo não está funcionando como esperado.

---

#### 🔐 [07 - Guia de Segurança](07-seguranca.md)
**Hardening e Melhores Práticas de Segurança**

Guia completo de segurança para ambientes de produção.

**Conteúdo:**
- Filosofia de segurança (defesa em profundidade)
- Segurança de rede (isolamento, firewall, rate limiting)
- Segurança de dados (criptografia, backups, .env)
- Segurança de aplicações (senhas, API auth, CORS)
- Segurança de containers (non-root, limits, scans)
- SSL/TLS e certificados
- Conformidade LGPD
- Monitoramento de segurança
- Resposta a incidentes
- Checklists de segurança

**Começar aqui se:** Você vai colocar o BorgStack em produção.

---

#### 🛠️ [06 - Guia de Manutenção](06-manutencao.md)
**Manutenção Preventiva e Atualizações**

Procedimentos de manutenção para manter o sistema saudável.

**Conteúdo:**
- Filosofia de manutenção preventiva
- Checklists diários (5 min)
- Checklists semanais (15 min)
- Checklists mensais (1-2h)
- Checklists trimestrais (2-3h)
- Rotação de credenciais
- Procedimento de atualização segura
- Gerenciamento de backups (regra 3-2-1)
- Teste de restauração
- Monitoramento e logs
- Scaling (vertical e horizontal)

**Começar aqui se:** Você quer manter o sistema rodando sem surpresas.

---

#### ⚡ [08 - Otimização de Desempenho](08-desempenho.md)
**Tuning e Otimização de Performance**

Guia avançado de otimização de performance.

**Conteúdo:**
- Filosofia de otimização (medir antes de otimizar)
- Monitoramento de performance
- Otimização de containers Docker (limites de recursos)
- Otimização do PostgreSQL (shared_buffers, work_mem, índices)
- Otimização do Redis (maxmemory, eviction, pipeline)
- Otimização do MongoDB (índices, cache)
- Otimização de rede (DNS, Caddy, compression)
- Otimização de disco e I/O
- Benchmarking (PostgreSQL, Redis, HTTP)
- Troubleshooting de performance

**Começar aqui se:** Você quer melhorar a performance do sistema.

---

## 🗺️ Navegação Rápida

### Por Tarefa

<table>
<tr>
<td><strong>Quero instalar o BorgStack</strong></td>
<td>→ <a href="01-instalacao.md">Guia de Instalação</a></td>
</tr>
<tr>
<td><strong>Quero conectar WhatsApp no Chatwoot</strong></td>
<td>→ <a href="04-integrations/whatsapp-chatwoot.md">Integração WhatsApp-Chatwoot</a></td>
</tr>
<tr>
<td><strong>Algo não está funcionando</strong></td>
<td>→ <a href="05-solucao-de-problemas.md">Solução de Problemas</a></td>
</tr>
<tr>
<td><strong>Quero melhorar a segurança</strong></td>
<td>→ <a href="07-seguranca.md">Guia de Segurança</a></td>
</tr>
<tr>
<td><strong>Quero melhorar a performance</strong></td>
<td>→ <a href="08-desempenho.md">Otimização de Desempenho</a></td>
</tr>
<tr>
<td><strong>Quero fazer manutenção preventiva</strong></td>
<td>→ <a href="06-manutencao.md">Guia de Manutenção</a></td>
</tr>
<tr>
<td><strong>Quero automatizar algo com n8n</strong></td>
<td>→ <a href="03-services/n8n.md">Guia do n8n</a> e <a href="04-integrations/n8n-services.md">Integrações n8n</a></td>
</tr>
<tr>
<td><strong>Quero configurar variáveis do .env</strong></td>
<td>→ <a href="02-configuracao.md">Guia de Configuração</a></td>
</tr>
</table>

---

## 📖 Como Usar Esta Documentação

### Primeira Instalação
1. **[Guia de Instalação](01-instalacao.md)** - Execute o bootstrap
2. **[Guia de Configuração](02-configuracao.md)** - Personalize o `.env`
3. **[Guias de Serviços](03-services/)** - Configure cada serviço
4. **[Guias de Integração](04-integrations/)** - Conecte os serviços

### Manutenção Contínua
1. **[Guia de Manutenção](06-manutencao.md)** - Siga os checklists
2. **[Guia de Segurança](07-seguranca.md)** - Implemente hardening
3. **[Solução de Problemas](05-solucao-de-problemas.md)** - Quando necessário

### Otimização Avançada
1. **[Otimização de Desempenho](08-desempenho.md)** - Tuning de produção
2. **[Guias de Serviços](03-services/)** - Configurações avançadas

---

## 🎯 Casos de Uso Comuns

### Atendimento ao Cliente via WhatsApp

**Documentos relevantes:**
1. [Evolution API](03-services/evolution-api.md) - Setup do WhatsApp
2. [Chatwoot](03-services/chatwoot.md) - Setup da plataforma
3. [n8n](03-services/n8n.md) - Workflows de automação
4. [Integração WhatsApp-Chatwoot](04-integrations/whatsapp-chatwoot.md) - Tutorial completo

**Resultado:** Atendimento completo via WhatsApp gerenciado pelo Chatwoot.

---

### Automação de Processos com Workflows

**Documentos relevantes:**
1. [n8n](03-services/n8n.md) - Criação de workflows
2. [Integrações n8n](04-integrations/n8n-services.md) - Conectar com outros serviços
3. [PostgreSQL](03-services/postgresql.md) - Armazenamento de dados
4. [Redis](03-services/redis.md) - Cache e filas

**Resultado:** Processos empresariais totalmente automatizados.

---

### CMS e Gestão de Conteúdo

**Documentos relevantes:**
1. [Integrações n8n - Directus](04-integrations/n8n-services.md#3-integração-n8n--directus) - Automações com CMS
2. [PostgreSQL](03-services/postgresql.md) - Banco de dados
3. [Caddy](03-services/caddy.md) - Exposição pública

**Resultado:** CMS headless com API REST e GraphQL.

---

## 🆘 Suporte

### Problemas Comuns

**"Não consigo acessar os serviços via HTTPS"**
→ [Solução de Problemas - Seção 3: Problemas de Rede](05-solucao-de-problemas.md#3-problemas-de-rede)

**"Container não inicia (status: Restarting)"**
→ [Solução de Problemas - Seção 3.1](05-solucao-de-problemas.md#problema-31-container-não-inicia-status-restarting)

**"PostgreSQL está lento"**
→ [Otimização de Desempenho - PostgreSQL](08-desempenho.md#4-otimização-do-postgresql)

**"WhatsApp não conecta no Chatwoot"**
→ [Integração WhatsApp-Chatwoot - Troubleshooting](04-integrations/whatsapp-chatwoot.md#6-problemas-comuns)

### Recursos Adicionais

- **README Principal:** [../README.md](../README.md)
- **GitHub Issues:** [Reportar problemas](https://github.com/yourusername/borgstack/issues)
- **Stories de Desenvolvimento:** [docs/stories/](stories/)

---

## 📝 Convenções da Documentação

### Símbolos e Formatação

- **✅ Correto / Recomendado** - Boas práticas
- **❌ Incorreto / Não recomendado** - Práticas a evitar
- **⚠️ Atenção** - Avisos importantes
- **📝 Nota** - Informações adicionais
- **🔍 Dica** - Dicas úteis

### Exemplos de Código

Todos os exemplos de código são testados e funcionais. Você pode copiar e colar diretamente.

```bash
# Este é um exemplo de comando bash
docker compose ps
```text

```yaml
# Este é um exemplo de configuração YAML
services:
  example:
    image: example:latest
```text

---

## 🔄 Atualizações da Documentação

Esta documentação é mantida atualizada com cada release do BorgStack.

**Última atualização:** 2025-10-08
**Versão:** 1.0.0

---

**Documentação criada com ❤️ para a comunidade open source**

[⬆️ Voltar ao topo](#documentação-borgstack)
