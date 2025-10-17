# Integrações - BorgStack

## Visão Geral

O BorgStack utiliza o **n8n como hub central de integração**. Serviços comunicam-se via HTTP/webhooks orquestrados pelo n8n, nunca diretamente entre si.

**Infraestrutura Compartilhada:**
- **PostgreSQL**: Bancos separados por serviço (n8n_db, chatwoot_db, directus_db, evolution_db)
- **Redis**: Cache e sessões (bancos 0-3 para cada serviço)
- **SeaweedFS**: Object storage S3-compatible para Directus e FileFlows

## Padrões de Integração

### 1. Evolution API → n8n → Chatwoot (Atendimento WhatsApp)

**Fluxo:**
```
Cliente WhatsApp → Evolution API (webhook) → n8n → Chatwoot (inbox)
Agente responde → Chatwoot (webhook) → n8n → Evolution API → Cliente
```

**Configuração:**
- n8n webhook: `/webhook/whatsapp-incoming`
- Evolution envia: `MESSAGES_UPSERT`
- Chatwoot webhook: `/webhook/chatwoot-message-created`
- n8n envia: `POST /message/sendText/{instance}`

**Uso:** Atendimento ao cliente com histórico completo

### 2. Directus → n8n → FileFlows (Processamento de Mídia)

**Fluxo:**
```
Upload Directus → n8n (metadados) → FileFlows (transcode) → SeaweedFS → Directus (atualiza)
```

**Configuração:**
- Directus webhook: `collections.files.create`
- FileFlows acessa arquivo via SeaweedFS S3 API
- Resultado em bucket separado

**Uso:** Transcodificação automática de vídeos, compressão de imagens

### 3. n8n → APIs Externas

**Padrão:**
```
Trigger → n8n (auth + transform) → API Externa → n8n (parse) → Ação
```

**Credenciais n8n:** OAuth 2.0, API Keys, Basic Auth

**Uso:** Google Sheets, Slack, Email, Telegram

### 4. Database Sharing (PostgreSQL Multi-Database)

**Bancos:**
```
PostgreSQL (porta 5432)
  ├── n8n_db (workflows)
  ├── chatwoot_db (conversas)
  ├── directus_db (CMS)
  └── evolution_db (WhatsApp)
```

**Limites:** 100 conexões totais, 20-25 por serviço

### 5. Cache Sharing (Redis)

**Distribuição:**
```
Redis (porta 6379)
  ├── DB 0: n8n (cache workflows)
  ├── DB 1: Chatwoot (sessões)
  ├── DB 2: Lowcoder (apps)
  └── DB 3: Directus (queries)
```

**Config:** maxmemory 2GB, policy allkeys-lru, TTL 600s

### 6. Object Storage (SeaweedFS S3)

**Buckets:**
```
SeaweedFS (porta 8333)
  ├── directus-uploads
  ├── fileflows-input
  ├── fileflows-output
  └── backups
```

**Credenciais:** `SEAWEEDFS_ACCESS_KEY`, endpoint `http://seaweedfs:8333`

## Exemplos de Workflows

### Exemplo 1: Atendimento Automatizado WhatsApp

**Objetivo:** Mensagem WhatsApp → Verificar horário → Resposta automática OU criar ticket

**Workflow:**
1. Webhook Evolution API
2. Verificar horário (9h-18h, seg-sex)
3. SE fora: Resposta automática via Evolution
4. SE dentro: Criar conversa no Chatwoot

**Nós:** Webhook → Function (check hours) → IF → HTTP Request (Evolution/Chatwoot)

### Exemplo 2: Pipeline de Processamento de Mídia

**Objetivo:** Upload vídeo → Transcoding → Notificar usuário

**Workflow:**
1. Webhook Directus (`file.create`)
2. Verificar tipo de arquivo
3. Disparar job FileFlows
4. Aguardar conclusão (polling)
5. Atualizar Directus com URL processado
6. Notificar via email/Telegram

**Nós:** Webhook → Switch → HTTP Request (FileFlows) → Wait → HTTP Request (Directus) → Email

### Exemplo 3: Dashboard Low-Code com Lowcoder

**Objetivo:** Botão Lowcoder → Workflow n8n → Resultado em tempo real

**Fluxo:**
1. Botão "Gerar Relatório" no Lowcoder
2. POST `/webhook/generate-report`
3. n8n consulta PostgreSQL (múltiplos bancos)
4. Agrega dados
5. Cache Redis (TTL 1h)
6. Retorna JSON para Lowcoder

**Config Lowcoder:**
```javascript
{
  url: "http://n8n:5678/webhook/generate-report",
  method: "POST",
  body: {
    department: "{{currentUser.department}}"
  }
}
```

## Boas Práticas

### Segurança
- Webhooks protegidos com Header Auth
- Credenciais no n8n Credentials Manager
- HTTPS obrigatório (Caddy)
- Rate limiting no Caddy

### Performance
- **Webhooks > Polling** (latência < 500ms)
- **Retries exponenciais** (1s, 2s, 4s)
- **Timeouts** (5s DB, 30s APIs)
- **Cache Redis** para queries repetidas

### Monitoramento
- Logs: `docker compose logs -f n8n | grep ERROR`
- Métricas: n8n UI > Executions
- Alertas: Webhooks de erro para Telegram
- Health checks: `/healthz` endpoints

### Error Handling
- Error Trigger nodes em workflows críticos
- Dead Letter Queue (salvar payloads com erro no PostgreSQL)
- Notificações imediatas
- Procedimento de rollback documentado

### Documentação
- Fluxogramas atualizados (Mermaid)
- Changelog de integrações
- Runbooks de troubleshooting
- Lista de env vars no README

## Criando Novas Integrações

1. Identificar trigger (webhook, cron, manual)
2. Desenhar fluxo no papel
3. Configurar credenciais no n8n
4. Implementar workflow iterativamente
5. Adicionar error handling
6. Documentar neste arquivo
7. Configurar monitoramento

## Recursos

- n8n Workflows: https://docs.n8n.io/workflows/
- Webhook Testing: https://webhook.site
- SeaweedFS S3: https://github.com/seaweedfs/seaweedfs/wiki/Amazon-S3-API
- Directus Webhooks: https://docs.directus.io/reference/system/webhooks.html
- Evolution API: https://doc.evolution-api.com/
- Chatwoot API: https://www.chatwoot.com/developers/api/
