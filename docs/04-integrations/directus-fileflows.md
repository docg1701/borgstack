# Integração Directus-FileFlows

Guia completo de integração entre Directus CMS e FileFlows para processamento automatizado de mídia.

## Visão Geral

Esta integração automatiza o processamento de arquivos de mídia (vídeo, áudio, imagem) enviados ao Directus CMS usando FileFlows como motor de processamento, orquestrado via workflows n8n.

### Arquitetura da Integração

```mermaid
sequenceDiagram
    participant User
    participant Directus
    participant n8n
    participant FileFlows
    
    User->>Directus: Upload media file (video.mp4)
    Directus->>Directus: Create file record (processing_status: pending)
    Directus->>n8n: Webhook: files.upload event
    n8n->>n8n: Filter media files (video/*, audio/*, image/*)
    n8n->>FileFlows: Copy file to /input directory
    FileFlows->>FileFlows: Auto-detect file → Process (transcode/optimize)
    FileFlows->>n8n: Webhook: Processing complete
    n8n->>Directus: PATCH /items/directus_files/{id}
    Directus->>Directus: Update (processed_url, processing_status: completed)
    Directus-->>User: Processed media available
```text

### Fluxo de Dados

1. **Upload**: Usuário faz upload de arquivo de mídia no Directus
2. **Trigger**: Directus dispara webhook para n8n ao detectar upload
3. **Filtro**: n8n filtra apenas arquivos de mídia (video/*, audio/*, image/*)
4. **Cópia**: n8n copia arquivo de `/directus/uploads` para `/fileflows/input`
5. **Processamento**: FileFlows detecta novo arquivo e inicia processamento
6. **Conversão**: FileFlows transcodifica/otimiza conforme Flow configurado
7. **Saída**: FileFlows salva arquivo processado em `/fileflows/output`
8. **Notificação**: FileFlows envia webhook de conclusão para n8n
9. **Atualização**: n8n atualiza registro no Directus com URL processada
10. **Disponível**: Arquivo processado disponível para uso

---

## Pré-requisitos

### Serviços Configurados

- ✅ **Directus** (Story 4.1): CMS rodando com PostgreSQL + Redis
- ✅ **FileFlows** (Story 4.2): Processamento de mídia com FFmpeg
- ✅ **n8n** (Story 2.1): Plataforma de workflows para orquestração

### Volumes Docker Configurados

- ✅ **borgstack_directus_uploads**: `/directus/uploads` (fonte de arquivos)
- ✅ **borgstack_fileflows_input**: `/fileflows/input` (entrada para processamento)
- ✅ **borgstack_fileflows_output**: `/fileflows/output` (saída processada)
- ✅ **n8n volume mounts**: Acesso aos volumes Directus e FileFlows (Task 0)

### Variáveis de Ambiente

Configuradas em `.env`:

```bash
# Hostnames
DIRECTUS_HOST=directus.${DOMAIN}
FILEFLOWS_HOST=fileflows.${DOMAIN}
N8N_HOST=n8n.${DOMAIN}

# API Token (gerado após configuração)
DIRECTUS_API_TOKEN=<gerar-no-directus-admin>

# Opcional
FILEFLOWS_DELETE_ORIGINALS=false
DIRECTUS_MEDIA_RETENTION_DAYS=30
```text

---

## Configuração Passo a Passo

### Etapa 1: Importar Workflows n8n (Tasks 1, 3, 7, 8)

Consulte: `config/n8n/workflows/README.md`

**Workflows a importar:**
1. `directus-fileflows-upload.json` → Recebe uploads e copia para FileFlows
2. `directus-fileflows-complete.json` → Atualiza Directus com resultado
3. `directus-fileflows-error.json` → Trata erros de processamento
4. `media-processing-stats.json` → Coleta métricas a cada 15 minutos

**Passos resumidos:**
1. Acesse `https://n8n.${DOMAIN}`
2. Import cada workflow (Options → Import from File)
3. Configure credencial "Directus API" (Bearer Token)
4. Ative todos os workflows (toggle "Active")

### Etapa 2: Configurar Directus Flow (Task 2)

Consulte: `config/directus/README.md`

**Criar Flow:**
1. Acesse `https://directus.${DOMAIN}/admin`
2. Settings → Flows → Create Flow
3. **Nome:** FileFlows Processing Trigger
4. **Trigger:** Event Hook - `files.upload` - `directus_files`
5. **Condição:** Filtrar tipo de arquivo contém `video/`, `audio/` ou `image/`
6. **Webhook:** POST `https://n8n.${DOMAIN}/webhook/directus-upload`
7. Salvar e ativar

### Etapa 3: Adicionar Campos Customizados Directus (Task 4)

Consulte: `config/directus/README.md`

**Campos a criar em `directus_files`:**

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `processed_url` | String | URL do arquivo processado |
| `processing_status` | Dropdown | pending, processing, completed, failed |
| `processing_metadata` | JSON | Metadados de processamento |

### Etapa 4: Configurar Webhooks FileFlows (Task 5)

Consulte: `config/fileflows/README.md`

**Webhooks a criar:**

1. **Processing Complete:**
   - **URL:** `https://n8n.${DOMAIN}/webhook/fileflows-complete`
   - **Trigger:** Flow Execution Complete
   - **Payload:** original_filename, processed_filename, output_path, metadata

2. **Processing Error:**
   - **URL:** `https://n8n.${DOMAIN}/webhook/fileflows-error`
   - **Trigger:** Flow Execution Failed
   - **Payload:** original_filename, error_message, error_code

### Etapa 5: Criar Flows FileFlows (Task 6)

Consulte: `config/fileflows/README.md`

**Flows a criar:**

1. **Video Optimization H.264:**
   - Input: `*.mp4, *.avi, *.mkv, *.mov`
   - Processing: Transcode H.264, CRF 23, AAC audio, max 1920x1080
   - Output: `/output/video/{filename}.mp4`

2. **Audio Normalization:**
   - Input: `*.mp3, *.wav, *.flac, *.m4a`
   - Processing: Loudnorm (-16 LUFS), convert to MP3 320kbps
   - Output: `/output/audio/{filename}.mp3`

3. **Image WebP Conversion:**
   - Input: `*.jpg, *.png, *.bmp`
   - Processing: Convert to WebP, max 1920x1080, quality 85%
   - Output: `/output/images/{filename}.webp`

---

## Uso e Operação

### Upload de Mídia

**Via Interface Directus:**

1. Acesse `https://directus.${DOMAIN}/admin`
2. Navegue até **Content → Files**
3. Clique em **"Upload Files"**
4. Selecione arquivo de mídia (video, audio ou image)
5. Aguarde upload completar
6. Verifique que `processing_status` = `pending`

**Via API Directus:**

```bash
# Upload file
curl -X POST "https://directus.${DOMAIN}/files" \
  -H "Authorization: Bearer ${DIRECTUS_API_TOKEN}" \
  -F "file=@/path/to/video.mp4"

# Response includes file ID
{
  "data": {
    "id": "abc123-uuid",
    "filename_download": "video.mp4",
    "processing_status": "pending"
  }
}
```text

### Monitorar Processamento

**Via Directus UI:**
1. Content → Files
2. Clique no arquivo enviado
3. Veja campo `processing_status`:
   - `pending`: Aguardando processamento
   - `processing`: Sendo processado pelo FileFlows
   - `completed`: Processado com sucesso (veja `processed_url`)
   - `failed`: Falha no processamento (veja `processing_metadata` para erro)

**Via FileFlows UI:**
1. Acesse `https://fileflows.${DOMAIN}`
2. Navegue até **Processing** ou **Jobs**
3. Veja status em tempo real do processamento

**Via n8n Logs:**
1. Acesse `https://n8n.${DOMAIN}`
2. Clique em **Executions**
3. Veja execuções dos workflows:
   - "Directus → FileFlows Media Processing"
   - "FileFlows → Directus Update Results"

### Acessar Arquivo Processado

**Via Directus API:**

```bash
# Query file with processed URL
curl -X GET "https://directus.${DOMAIN}/items/directus_files/abc123-uuid" \
  -H "Authorization: Bearer ${DIRECTUS_API_TOKEN}"

# Response
{
  "data": {
    "id": "abc123-uuid",
    "filename_download": "video.mp4",
    "processing_status": "completed",
    "processed_url": "/output/video/video.mp4",
    "processing_metadata": {
      "processing_time": 45.2,
      "codec": "h264",
      "resolution": "1920x1080",
      "filesize_original": 15728640,
      "filesize_processed": 9437184,
      "compression_ratio": 0.60
    }
  }
}
```text

**Servir Arquivo Processado:**

Atualmente arquivos processados estão em volume Docker `/output`. Para servir via HTTPS:

**Opção 1: Configurar Caddy para servir `/output`**
```caddyfile
# Adicionar em config/caddy/Caddyfile
media.${DOMAIN} {
  root * /output
  file_server browse
}
```text

**Opção 2: Migração para SeaweedFS (Story 5.1)**
- Arquivos processados serão armazenados em SeaweedFS
- URLs S3-compatible substituirão paths locais
- Acesso via HTTPS automaticamente configurado

---

## Tratamento de Erros

### Cenários de Erro Comuns

#### 1. **Timeout de Processamento**

**Sintoma:** Arquivo fica em `processing` por > 30 minutos

**Causa:** Processamento muito lento ou travado

**Solução Automática:**
- n8n workflow "Media Processing Stats" detecta timeout
- Cancela job no FileFlows (se API disponível)
- Marca arquivo como `failed` no Directus
- Envia alerta para admin

**Solução Manual:**
```bash
# Check FileFlows processing queue
docker compose logs fileflows | grep -A 10 "Processing:"

# Cancel stuck job (via FileFlows UI)
# https://fileflows.${DOMAIN} → Processing → Cancel
```text

#### 2. **Formato de Arquivo Não Suportado**

**Sintoma:** `processing_status` = `failed`, erro "Unsupported format"

**Causa:** Codec ou container não suportado pelo FFmpeg

**Solução:**
- Verifique formato suportado: https://ffmpeg.org/general.html#Supported-File-Formats
- Converta arquivo manualmente antes do upload
- Ajuste FileFlows Flow para suportar formato

#### 3. **Espaço em Disco Insuficiente**

**Sintoma:** Erro "Insufficient storage"

**Causa:** Volume `/output` cheio

**Solução:**
```bash
# Check disk usage
df -h

# Clean old processed files
docker compose exec fileflows find /output -type f -mtime +30 -delete

# Enable automatic cleanup (edit .env)
FILEFLOWS_DELETE_ORIGINALS=true
```text

#### 4. **Falha de API Directus (500)**

**Sintoma:** n8n workflow falha ao atualizar Directus

**Causa:** Directus temporariamente indisponível

**Solução Automática:**
- n8n retry logic: 3 tentativas com exponential backoff (5s, 10s, 20s)
- Se todas falharem: payload armazenado em n8n para replay manual
- Admin recebe alerta por email

**Solução Manual:**
```bash
# Check Directus health
docker compose ps directus

# Restart if unhealthy
docker compose restart directus

# Replay failed update (via n8n UI)
# https://n8n.${DOMAIN} → Executions → Retry
```text

#### 5. **Webhook Não Entregue**

**Sintoma:** Arquivo processado mas Directus não atualiza

**Causa:** Webhook do FileFlows falhou ao entregar para n8n

**Solução Automática:**
- n8n "Missed Files Detector" workflow (roda a cada 30 min)
- Query Directus: arquivos com `processing_status` = `pending` > 10 min
- Manualmente triggerprocessamento para arquivos esquecidos

**Solução Manual:**
```bash
# Find missed files
curl -X GET "https://directus.${DOMAIN}/items/directus_files?filter[processing_status][_eq]=pending" \
  -H "Authorization: Bearer ${DIRECTUS_API_TOKEN}"

# Manually trigger processing
# Re-upload file or copy to /input again
```text

---

## Otimização de Performance

### Métricas de Processamento

**Tempos Médios Esperados:**

| Tipo de Mídia | Tamanho | Tempo de Processamento |
|---------------|---------|------------------------|
| **Vídeo 1080p** | 100 MB (2 min) | ~4 minutos (0.5x realtime) |
| **Vídeo 720p** | 50 MB (2 min) | ~2 minutos (1x realtime) |
| **Áudio** | 10 MB (3 min) | ~1 minuto (0.3x realtime) |
| **Imagem** | 5 MB | ~1-2 segundos |

### Gestão de Fila

**Profundidade de Fila Recomendada:**
- **Normal:** 0-10 arquivos pendentes
- **Alta (alerta):** > 20 arquivos pendentes
- **Crítica:** > 50 arquivos pendentes

**Ações ao detectar fila alta:**
1. Escalar capacidade de processamento (aumentar concurrent jobs)
2. Otimizar Flows (usar CRF maior, preset mais rápido)
3. Adicionar servidor FileFlows secundário (future enhancement)

**Configurar Max Concurrent Jobs:**
```text
FileFlows UI → Settings → Processing Nodes → Local Server
Max Concurrent Flows: 3-5 (para servidor 8 vCPU)
```text

### Otimização de Armazenamento

**Economia de Espaço Esperada:**
- **Vídeo H.264:** ~40% redução (com CRF 23)
- **Imagem WebP:** ~40% redução vs. JPEG
- **Áudio MP3:** ~30% redução vs. WAV/FLAC

**Política de Retenção:**

**Arquivos Originais:**
- **Padrão:** Manter indefinidamente (`FILEFLOWS_DELETE_ORIGINALS=false`)
- **Otimizado:** Deletar após processamento bem-sucedido (`FILEFLOWS_DELETE_ORIGINALS=true`)

**Arquivos Processados:**
- Manter indefinidamente (fonte primária após processamento)
- Backup via Duplicati (Story 5.2)

**Limpeza Manual:**
```bash
# Delete originals older than 30 days (if processed successfully)
docker compose exec directus find /directus/uploads -type f -mtime +30 -delete

# Delete failed processing files
docker compose exec fileflows find /input -type f -mtime +7 -delete
```text

---

## Solução de Problemas

### Workflow n8n Não Ativa

**Verificações:**
```bash
# 1. Check n8n is running
docker compose ps n8n

# 2. Check workflow is active (via n8n UI)
# https://n8n.${DOMAIN} → Workflows → Verify "Active" toggle

# 3. Check credentials configured
# n8n → Settings → Credentials → "Directus API" exists

# 4. Test webhook manually
curl -X POST https://n8n.${DOMAIN}/webhook/directus-upload \
  -H "Content-Type: application/json" \
  -d '{"payload":{"id":"test","filename_disk":"test.jpg","type":"image/jpeg"}}'
```text

### Arquivo Não Copiado para FileFlows

**Verificações:**
```bash
# 1. Verify volume mounts
docker compose exec n8n ls -la /directus/uploads /fileflows/input

# 2. Check file exists in Directus
docker compose exec directus ls -la /directus/uploads

# 3. Check permissions
docker compose exec n8n id
docker compose exec fileflows id

# 4. Test manual copy
docker compose exec n8n cp /directus/uploads/test.jpg /fileflows/input/test.jpg
```text

### FileFlows Não Detecta Arquivo

**Verificações:**
```bash
# 1. Check FileFlows is running
docker compose ps fileflows

# 2. Check input directory
docker compose exec fileflows ls -la /input/

# 3. Check FileFlows logs for detection errors
docker compose logs fileflows | grep -i "detecting\|watching"

# 4. Verify Flow is active (via FileFlows UI)
# https://fileflows.${DOMAIN} → Flows → Verify enabled
```text

### Directus Não Atualiza Após Processamento

**Verificações:**
```bash
# 1. Check FileFlows webhook configured
# FileFlows UI → Settings → Webhooks → Verify URL correct

# 2. Test webhook manually
curl -X POST https://n8n.${DOMAIN}/webhook/fileflows-complete \
  -H "Content-Type: application/json" \
  -d '{"original_filename":"test.jpg","status":"completed"}'

# 3. Check n8n execution logs
# n8n → Executions → Look for "FileFlows → Directus Update Results"

# 4. Verify Directus API token valid
curl -X GET "https://directus.${DOMAIN}/users/me" \
  -H "Authorization: Bearer ${DIRECTUS_API_TOKEN}"
```text

---

## Testes End-to-End

Ver: `tests/integration/test-directus-fileflows.sh`

**Executar Testes:**
```bash
chmod +x tests/integration/test-directus-fileflows.sh
./tests/integration/test-directus-fileflows.sh
```text

**Testes Incluídos:**
1. ✅ Workflows n8n ativos
2. ✅ Directus Flow configurado
3. ✅ Upload arquivo → FileFlows processa
4. ✅ Directus atualizado com metadata
5. ✅ Tratamento de erro funciona
6. ✅ Notificação de erro enviada
7. ✅ FileFlows webhooks recebidos
8. ✅ Métricas coletadas
9. ✅ Limpeza de armazenamento
10. ✅ Fluxo completo funcional

---

## Próximos Passos

### Migração para SeaweedFS (Story 5.1)

Atualmente:
- Directus: Local volume `borgstack_directus_uploads`
- FileFlows: Local volumes `borgstack_fileflows_input/output`
- Cópia manual entre volumes via n8n

Após Story 5.1:
- Ambos serviços usam SeaweedFS S3 storage
- Acesso direto ao mesmo objeto via S3 URLs
- Elimina necessidade de cópia de arquivos
- Armazenamento distribuído e escalável

### Recursos Avançados (Post-MVP)

**Horizontal Scaling:**
- Múltiplos nós de processamento FileFlows
- Load balancing de jobs entre nós
- Processamento paralelo massivo

**Advanced Monitoring:**
- Grafana dashboards para métricas
- Prometheus alerting para filas altas
- Histórico de performance trends

**Automatic Retry:**
- Retry automático para jobs falhados
- Backoff exponencial para erros transitórios
- Queue prioritization (priority jobs first)

**Batch Processing:**
- Processamento em lote de múltiplos arquivos
- Otimização de throughput para uploads massivos
- Scheduled processing (off-peak hours)

---

## Referências

### Documentação Oficial

- **Directus:** https://docs.directus.io/
- **FileFlows:** https://docs.fileflows.com/
- **n8n:** https://docs.n8n.io/
- **FFmpeg:** https://ffmpeg.org/documentation.html

### Configuração

- n8n Workflows: `config/n8n/workflows/README.md`
- Directus Setup: `config/directus/README.md`
- FileFlows Setup: `config/fileflows/README.md`

### Testes

- Integration Tests: `tests/integration/test-directus-fileflows.sh`
- Testing Strategy: `docs/architecture/testing-strategy.md`

### Arquitetura

- Core Workflows: `docs/architecture/core-workflows.md`
- Backend Architecture: `docs/architecture/backend-architecture.md`
- Source Tree: `docs/architecture/source-tree.md`
