# Story 4.3: Directus-FileFlows Integration - Tarefas Manuais Pendentes

Este documento lista todas as tarefas que requerem configuração manual via interface de usuário e devem ser completadas antes da entrega final do projeto.

## Status Atual

**Infraestrutura Automatizada:** ✅ Completa
- n8n volume mounts configurados
- Arquivos de workflow criados
- Guias de configuração escritos
- Documentação e testes criados

**Configuração Manual:** ⏸️ PENDENTE
- Tasks 1-8 requerem interação com interfaces web
- Cada task possui guia detalhado em `config/`

---

## Tarefas Manuais Pendentes

### Task 1: Importar Workflow n8n - Directus to FileFlows

**Status:** ⏸️ PENDENTE - Requer importação manual via n8n UI

**Arquivo Criado:** `config/n8n/workflows/directus-fileflows-upload.json`

**Guia de Configuração:** `config/n8n/workflows/README.md` (seção 2)

**Passos para Completar:**
1. Acessar `https://n8n.${DOMAIN}`
2. Clicar em "+" (New Workflow)
3. Clicar em "⋮" (Options) → "Import from File..."
4. Selecionar `directus-fileflows-upload.json`
5. Revisar nós e configurações
6. Salvar workflow
7. Ativar workflow (toggle "Active")

**Tempo Estimado:** 5 minutos

**Critério de Aceitação:** Workflow "Directus → FileFlows Media Processing" aparece ativo em n8n

---

### Task 2: Configurar Directus Flow para Notificação de Upload

**Status:** ⏸️ PENDENTE - Requer criação manual via Directus admin UI

**Guia de Configuração:** `config/directus/README.md` (Task 2)

**Passos para Completar:**
1. Acessar `https://directus.${DOMAIN}/admin`
2. Settings → Flows → Create Flow
3. Nome: "FileFlows Processing Trigger"
4. Trigger: Event Hook - `files.upload` - `directus_files`
5. Adicionar Condition: Filtrar `type` contém `video/`, `audio/` ou `image/`
6. Adicionar Webhook Operation: POST `https://n8n.${DOMAIN}/webhook/directus-upload`
7. Salvar e ativar Flow

**Tempo Estimado:** 10 minutos

**Critério de Aceitação:** Flow ativo que dispara webhook ao fazer upload de arquivo de mídia

---

### Task 3: Importar Workflow n8n - FileFlows Completion Handler

**Status:** ⏸️ PENDENTE - Requer importação manual via n8n UI

**Arquivo Criado:** `config/n8n/workflows/directus-fileflows-complete.json`

**Guia de Configuração:** `config/n8n/workflows/README.md` (seção 2)

**Passos para Completar:**
1. Importar `directus-fileflows-complete.json` via n8n UI
2. Configurar credencial "Directus API" (Bearer Token)
   - Gerar token em Directus → Settings → Access Tokens
   - Permissões: Full Access
   - Adicionar ao .env: `DIRECTUS_API_TOKEN=<token>`
3. Salvar workflow
4. Ativar workflow

**Tempo Estimado:** 8 minutos

**Critério de Aceitação:** Workflow ativo com credencial Directus configurada

---

### Task 4: Adicionar Campos Customizados no Directus

**Status:** ⏸️ PENDENTE - Requer configuração manual via Directus admin UI

**Guia de Configuração:** `config/directus/README.md` (Task 4)

**Passos para Completar:**
1. Acessar Directus → Settings → Data Model → directus_files
2. Adicionar campo `processed_url` (String, Input, max 500 chars)
3. Adicionar campo `processing_status` (String, Dropdown: pending/processing/completed/failed)
4. Adicionar campo `processing_metadata` (JSON, Input Code)
5. Atualizar layout da view de arquivo (opcional)

**Tempo Estimado:** 10 minutos

**Critério de Aceitação:** 3 campos customizados visíveis em qualquer arquivo no Directus

---

### Task 5: Configurar FileFlows Webhooks

**Status:** ⏸️ PENDENTE - Requer configuração manual via FileFlows UI

**Guia de Configuração:** `config/fileflows/README.md` (Task 5)

**Passos para Completar:**
1. Acessar `https://fileflows.${DOMAIN}`
2. Settings → Webhooks
3. Criar webhook "Processing Complete Notification":
   - URL: `https://n8n.${DOMAIN}/webhook/fileflows-complete`
   - Trigger: Flow Execution Complete
   - Payload: original_filename, processed_filename, output_path, metadata
4. Criar webhook "Processing Error Notification":
   - URL: `https://n8n.${DOMAIN}/webhook/fileflows-error`
   - Trigger: Flow Execution Failed
   - Payload: original_filename, error_message, error_code
5. Testar ambos webhooks

**Tempo Estimado:** 15 minutos

**Critério de Aceitação:** 2 webhooks ativos enviando para n8n

---

### Task 6: Criar FileFlows Processing Flows

**Status:** ⏸️ PENDENTE - Requer criação manual via FileFlows Flow Designer

**Guia de Configuração:** `config/fileflows/README.md` (Task 6)

**Passos para Completar:**

**Flow 1: Video Optimization H.264**
- Input: `/input` - `*.mp4, *.avi, *.mkv, *.mov`
- Processing: Transcode H.264, CRF 23, AAC audio, max 1920x1080
- Output: `/output/video/{filename}.mp4`

**Flow 2: Audio Normalization**
- Input: `/input` - `*.mp3, *.wav, *.flac, *.m4a`
- Processing: Loudnorm -16 LUFS, convert MP3 320kbps
- Output: `/output/audio/{filename}.mp3`

**Flow 3: Image WebP Conversion**
- Input: `/input` - `*.jpg, *.png, *.bmp`
- Processing: Convert WebP, max 1920x1080, quality 85%
- Output: `/output/images/{filename}.webp`

**Tempo Estimado:** 30 minutos

**Critério de Aceitação:** 3 flows ativos processando arquivos automaticamente

---

### Task 7: Importar Workflow n8n - Error Handler

**Status:** ⏸️ PENDENTE - Requer importação manual via n8n UI

**Arquivo Criado:** `config/n8n/workflows/directus-fileflows-error.json`

**Guia de Configuração:** `config/n8n/workflows/README.md` (seção 2)

**Passos para Completar:**
1. Importar `directus-fileflows-error.json` via n8n UI
2. Verificar credencial "Directus API" configurada (mesma da Task 3)
3. Salvar workflow
4. Ativar workflow

**Tempo Estimado:** 5 minutos

**Critério de Aceitação:** Workflow ativo tratando erros de processamento

---

### Task 8: Importar Workflow n8n - Performance Monitoring

**Status:** ⏸️ PENDENTE - Requer importação manual via n8n UI

**Arquivo Criado:** `config/n8n/workflows/media-processing-stats.json`

**Guia de Configuração:** `config/n8n/workflows/README.md` (seção 2)

**Passos para Completar:**
1. Importar `media-processing-stats.json` via n8n UI
2. Configurar credenciais:
   - Directus API (mesma das Tasks 3 e 7)
   - FileFlows API (HTTP Basic Auth - configurar em FileFlows → Settings → Security)
3. Salvar workflow
4. Ativar workflow

**Tempo Estimado:** 10 minutos

**Critério de Aceitação:** Workflow executando a cada 15 minutos coletando métricas

---

### Task 9: Importar Workflow n8n - Missed Files Detector

**Status:** ⏸️ PENDENTE - Requer importação manual via n8n UI

**Arquivo Criado:** `config/n8n/workflows/missed-files-detector.json`

**Guia de Configuração:** `config/n8n/workflows/README.md` (seção 5)

**Passos para Completar:**
1. Importar `missed-files-detector.json` via n8n UI
2. Verificar credencial "Directus API" configurada (mesma das Tasks anteriores)
3. Salvar workflow
4. Ativar workflow

**Tempo Estimado:** 5 minutos

**Critério de Aceitação:** Workflow executando a cada 30 minutos detectando arquivos presos

---

## Resumo de Tarefas Manuais

| Task | Descrição | Tempo Est. | Status |
|------|-----------|------------|--------|
| 1 | Importar workflow: Directus → FileFlows (c/ HMAC) | 5 min | ⏸️ PENDENTE |
| 2 | Configurar Directus Flow + Webhook Secret | 12 min | ⏸️ PENDENTE |
| 3 | Importar workflow: FileFlows → Directus | 8 min | ⏸️ PENDENTE |
| 4 | Adicionar campos Directus | 10 min | ⏸️ PENDENTE |
| 5 | Configurar FileFlows webhooks | 15 min | ⏸️ PENDENTE |
| 6 | Criar FileFlows processing flows | 30 min | ⏸️ PENDENTE |
| 7 | Importar workflow: Error Handler | 5 min | ⏸️ PENDENTE |
| 8 | Importar workflow: Performance Monitoring | 10 min | ⏸️ PENDENTE |
| 9 | Importar workflow: Missed Files Detector | 5 min | ⏸️ PENDENTE |
| **TOTAL** | | **100 min (~1.7 horas)** | |

---

## Pré-requisitos

Antes de iniciar as tarefas manuais:

1. ✅ Verificar todos os serviços rodando:
   ```bash
   docker compose ps
   ```
   Esperado: directus, fileflows, n8n todos "healthy"

2. ⏸️ Gerar `DIRECTUS_API_TOKEN`:
   - Acessar Directus admin UI
   - Settings → Access Tokens → Create Token
   - Permissões: Full Access
   - Copiar token
   - Adicionar ao `.env`: `DIRECTUS_API_TOKEN=<token-gerado>`

3. ✅ Verificar guias de configuração disponíveis:
   - `config/n8n/workflows/README.md`
   - `config/directus/README.md`
   - `config/fileflows/README.md`

---

## Teste End-to-End

Após completar todas as tarefas manuais (1-8):

1. **Executar Testes Automatizados:**
   ```bash
   chmod +x tests/integration/test-directus-fileflows.sh
   ./tests/integration/test-directus-fileflows.sh
   ```

2. **Teste Manual Completo:**
   - Upload de imagem no Directus
   - Verificar cópia para `/fileflows/input`
   - Monitorar processamento no FileFlows
   - Verificar atualização no Directus (`processing_status: completed`)
   - Verificar arquivo processado em `/output/images`

3. **Critério de Sucesso:**
   - ✅ Todos testes automatizados passam
   - ✅ Upload → Processamento → Atualização funciona end-to-end
   - ✅ Erro handling testado e funcionando
   - ✅ Métricas sendo coletadas

---

## Documentação de Suporte

- **Integração Completa:** `docs/04-integrations/directus-fileflows.md`
- **Troubleshooting:** Ver seção "Solução de Problemas" na documentação
- **Arquitetura:** `docs/stories/4.3.directus-fileflows-integration.md` (Dev Notes)

---

## Próximos Passos (Após Completar Tasks 1-8)

1. Executar testes de integração
2. Documentar resultado dos testes
3. Marcar story como "Ready for QA"
4. QA Agent executará review completo
5. Se aprovado: Story movida para "Done"

---

**Última Atualização:** 2025-10-05  
**Responsável pela Execução:** Usuário/Operador do sistema  
**Documentado por:** Dev Agent (James)
