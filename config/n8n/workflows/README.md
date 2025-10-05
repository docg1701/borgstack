# n8n Workflows for Directus-FileFlows Integration

Este diretório contém os workflows n8n para integração entre Directus CMS e FileFlows Media Processing.

## Workflows Disponíveis

### 1. directus-fileflows-upload.json
**Nome:** Directus → FileFlows Media Processing

**Função:** Recebe uploads de mídia do Directus e copia arquivos para o diretório de entrada do FileFlows.

**Webhook:** `POST https://n8n.${DOMAIN}/webhook/directus-upload`

**Fluxo:**
1. Recebe evento de upload do Directus Flow
2. Extrai metadados do arquivo (filename, type, size)
3. Filtra apenas arquivos de mídia (video/*, audio/*, image/*)
4. Copia arquivo de `/directus/uploads` para `/fileflows/input`
5. Gera ID de rastreamento para processamento
6. Registra sucesso no log

**Configuração Necessária:**
- Nenhuma credencial adicional (usa volumes montados)
- Webhook configurado no Directus Flow (ver Task 2)

---

### 2. directus-fileflows-complete.json
**Nome:** FileFlows → Directus Update Results

**Função:** Recebe notificações de conclusão do FileFlows e atualiza registros no Directus com URLs de mídia processada.

**Webhook:** `POST https://n8n.${DOMAIN}/webhook/fileflows-complete`

**Fluxo:**
1. Recebe webhook de conclusão do FileFlows
2. Extrai dados de processamento (filename, output_path, metadata)
3. Consulta API do Directus para localizar arquivo original
4. Atualiza registro com `processed_url` e `processing_status: completed`
5. Verifica status e registra sucesso ou falha

**Configuração Necessária:**
- **Credencial Directus API:**
  - Tipo: HTTP Request - Bearer Token
  - Nome: "Directus API"
  - Token: Gerar em Directus → Settings → Access Tokens
  - Adicionar ao .env: `DIRECTUS_API_TOKEN=<token>`

---

### 3. directus-fileflows-error.json
**Nome:** FileFlows Error Handler

**Função:** Trata erros de processamento do FileFlows, atualiza status no Directus e envia alertas.

**Webhook:** `POST https://n8n.${DOMAIN}/webhook/fileflows-error`

**Fluxo:**
1. Recebe webhook de erro do FileFlows
2. Categoriza erro (timeout, invalid_format, storage_failure, etc.)
3. Consulta API do Directus para localizar arquivo
4. Atualiza `processing_status: failed` com detalhes do erro
5. Envia alerta para administrador (email ou log)

**Configuração Necessária:**
- **Credencial Directus API** (mesma do workflow #2)
- **Opcional:** Credencial SMTP para envio de emails de alerta

**Categorias de Erro:**
- `timeout`: Processamento excedeu tempo limite
- `invalid_format`: Formato de arquivo não suportado
- `storage_failure`: Falha de espaço em disco
- `memory_failure`: Falha de memória RAM
- `unknown`: Erro não categorizado

---

### 4. media-processing-stats.json
**Nome:** Media Processing Stats Collector

**Função:** Coleta métricas de processamento a cada 15 minutos e alerta sobre filas altas.

**Trigger:** Schedule (a cada 15 minutos)

**Métricas Coletadas:**
- Arquivos pendentes (Directus)
- Arquivos em processamento (Directus)
- Arquivos completados (Directus)
- Arquivos com falha (Directus)
- Taxa de erro (%)
- Profundidade da fila (FileFlows)
- Tempo médio de processamento (FileFlows)

**Alertas:**
- Fila alta: > 20 arquivos pendentes
- Recomendação: Escalar capacidade de processamento do FileFlows

**Configuração Necessária:**
- **Credencial Directus API** (mesma do workflow #2)
- **Credencial FileFlows API:**
  - Tipo: HTTP Basic Auth
  - Nome: "FileFlows API"
  - Usuário/Senha: Configurar no FileFlows → Settings → Security

---

### 5. missed-files-detector.json
**Nome:** Missed Files Detector

**Função:** Detecta e processa novamente arquivos que ficaram presos em status "pending" por mais de 10 minutos (recuperação automática de falhas de webhook).

**Trigger:** Schedule (a cada 30 minutos)

**Fluxo:**
1. Query Directus para arquivos com `processing_status: "pending"` > 10 min
2. Para cada arquivo encontrado:
   - Log tentativa de retry
   - Copia arquivo para `/fileflows/input` novamente
   - Atualiza status para `processing` com metadata de retry
3. FileFlows detecta e processa normalmente

**Casos de Uso:**
- Webhook do Directus falhou ao entregar para n8n
- n8n estava temporariamente indisponível
- Erro transitório no workflow de upload

**Configuração Necessária:**
- **Credencial Directus API** (mesma dos workflows anteriores)
- Permissões: Read/Update em `directus_files`

---

## Instruções de Importação

### 1. Acessar n8n
Acesse o n8n em: `https://n8n.${DOMAIN}`

### 2. Importar Workflows
Para cada arquivo JSON:

1. Clique em **"+"** (New Workflow) no menu superior direito
2. Clique em **"⋮"** (Options) → **"Import from File..."**
3. Selecione o arquivo JSON correspondente
4. Clique em **"Import"**
5. Revise os nós e configurações
6. Clique em **"Save"** para salvar o workflow

### 3. Configurar Credenciais

#### Credencial: Directus API
1. Vá para **Settings → Credentials**
2. Clique em **"Create New Credential"**
3. Selecione **"HTTP Request - Bearer Token"**
4. **Nome:** Directus API
5. **Token:** Gerar em Directus:
   - Acesse `https://directus.${DOMAIN}/admin`
   - Vá para **Settings → Access Tokens**
   - Clique em **"Create Token"**
   - ⚠️ **Permissions:** SCOPED (Principle of Least Privilege)
     - Collection: `directus_files`
     - Permissions: **Read** ✓, **Update** ✓
     - Permissions: Create ✗, Delete ✗
   - Copie o token gerado
   - Cole em n8n e salve
6. Adicione o token ao `.env`:
   ```bash
   DIRECTUS_API_TOKEN=<token-gerado>
   ```

#### Configurar Webhook Security (HMAC)
1. Gere um secret seguro:
   ```bash
   openssl rand -hex 32
   ```
2. Adicione ao `.env`:
   ```bash
   DIRECTUS_WEBHOOK_SECRET=<secret-gerado>
   ```
3. Configure no Directus Flow (Task 2):
   - Ao criar Webhook Operation
   - Adicione Header customizado:
     - Nome: `x-webhook-signature`
     - Valor: `{{$env.DIRECTUS_WEBHOOK_SECRET}}`
   - n8n validará automaticamente a assinatura HMAC

#### Credencial: FileFlows API (opcional para stats)
1. Acesse `https://fileflows.${DOMAIN}`
2. Vá para **Settings → Security**
3. Configure usuário/senha para API
4. Em n8n: **Settings → Credentials → Create New**
5. Selecione **"HTTP Basic Auth"**
6. **Nome:** FileFlows API
7. **Usuário/Senha:** Conforme configurado no FileFlows
8. Salve

### 4. Ativar Workflows
Para cada workflow importado:

1. Abra o workflow
2. Verifique que todos os nós estão configurados corretamente
3. Clique no botão **"Active"** no canto superior direito
4. Workflow agora está ativo e pronto para receber eventos

### 5. Testar Webhooks
Teste cada webhook:

```bash
# Teste webhook de upload
curl -X POST https://n8n.${DOMAIN}/webhook/directus-upload \
  -H "Content-Type: application/json" \
  -d '{
    "payload": {
      "id": "test-123",
      "filename_disk": "test.jpg",
      "filename_download": "test.jpg",
      "type": "image/jpeg",
      "filesize": 1024000
    }
  }'

# Teste webhook de conclusão
curl -X POST https://n8n.${DOMAIN}/webhook/fileflows-complete \
  -H "Content-Type: application/json" \
  -d '{
    "original_filename": "test.jpg",
    "processed_filename": "test-optimized.webp",
    "output_path": "/output/test-optimized.webp",
    "status": "completed",
    "metadata": {}
  }'

# Teste webhook de erro
curl -X POST https://n8n.${DOMAIN}/webhook/fileflows-error \
  -H "Content-Type: application/json" \
  -d '{
    "original_filename": "test.mp4",
    "error_message": "Unsupported codec",
    "metadata": {}
  }'
```

### 6. Verificar Logs
Após testar, verifique os logs de execução:

1. No n8n, clique em **"Executions"** na barra lateral
2. Verifique se os workflows foram executados
3. Clique em cada execução para ver detalhes
4. Confirme que não há erros

---

## Troubleshooting

### Workflow não ativa
- Verifique se todas as credenciais estão configuradas
- Verifique se os serviços Directus e FileFlows estão rodando
- Verifique logs do n8n: `docker compose logs n8n`

### Webhook não recebe eventos
- Verifique se o Directus Flow está configurado (Task 2)
- Verifique se o FileFlows webhook está configurado (Task 5)
- Teste webhook manualmente com curl (ver seção "Testar Webhooks")

### Erro de credencial Directus
- Verifique se `DIRECTUS_API_TOKEN` está definido no `.env`
- Verifique se o token tem permissões Full Access
- Regenere o token se necessário

### Arquivo não copiado para FileFlows
- Verifique se os volumes estão montados corretamente:
  ```bash
  docker compose exec n8n ls -la /directus/uploads /fileflows/input
  ```
- Verifique permissões de arquivo
- Verifique espaço em disco disponível

---

## Próximos Passos

Após importar e ativar todos os workflows:

1. **Task 2:** Configurar Directus Flow para enviar eventos de upload
2. **Task 4:** Adicionar campos customizados no Directus (`processed_url`, `processing_status`, `processing_metadata`)
3. **Task 5:** Configurar FileFlows webhooks para enviar eventos de conclusão/erro
4. **Task 6:** Criar Flows de processamento no FileFlows (Video H.264, Audio Normalization, Image WebP)
5. **Task 10:** Executar testes de integração (`./tests/integration/test-directus-fileflows.sh`)

---

## Referências

- Documentação n8n: https://docs.n8n.io/
- Directus API: https://docs.directus.io/reference/api/
- FileFlows API: https://docs.fileflows.com/
- Integração completa: `docs/04-integrations/directus-fileflows.md`
