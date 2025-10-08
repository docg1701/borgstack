# SeaweedFS Filer API Integration with n8n

**Story**: 5.3 Storage Integration Testing
**Created**: 2025-10-07
**Updated**: 2025-10-07

## Visão Geral

Este documento descreve como integrar n8n com SeaweedFS usando a **Filer HTTP API** - uma solução 100% gratuita que não requer Enterprise License.

### Por que não S3?

- ❌ **n8n S3 External Storage** requer **Enterprise License** (paga)
- ✅ **Filer HTTP API** é 100% gratuita e bem documentada
- ✅ Funciona com Community Edition do n8n
- ✅ Mais flexível - workflows decidem quando usar storage externo

---

## Arquitetura da Solução

```text
┌──────────┐                    ┌─────────────┐
│   n8n    │ ──HTTP Request──>  │  SeaweedFS  │
│          │   (Filer API)       │   Filer     │
│workflows │ <─────────────────  │  :8888      │
└──────────┘                    └─────────────┘
```text

**Como funciona:**
1. n8n usa **filesystem storage** (default) para dados internos
2. Workflows usam **HTTP Request node** para interagir com SeaweedFS
3. Upload/download via Filer HTTP API (REST)
4. Arquivos armazenados em "buckets" (diretórios) no SeaweedFS

---

## Configuração

### 1. Endpoint da Filer API

```text
Interno (containers): http://seaweedfs:8888/
Externo (host):       http://localhost:8888/
```text

### 2. n8n Configuration

n8n usa **filesystem storage** (default, grátis):
```bash
# Nenhuma configuração especial necessária!
# n8n já está pronto para usar
```text

### 3. SeaweedFS Buckets

Criar "buckets" (diretórios) no SeaweedFS:

```bash
# Via Filer API
curl -X POST http://localhost:8888/buckets/my-bucket/

# Verificar
curl http://localhost:8888/buckets/ | grep "my-bucket"
```text

---

## Operações da Filer HTTP API

### Upload de Arquivo

**Usando HTTP Request node no n8n:**

```text
Method: POST
URL: http://seaweedfs:8888/my-bucket/my-file.pdf
Headers:
  Content-Type: multipart/form-data
Body:
  file: [binary data from previous node]
```text

**Exemplo com curl:**
```bash
curl -F file=@document.pdf "http://localhost:8888/my-bucket/document.pdf"
```text

**Response:**
```json
{
  "name": "document.pdf",
  "size": 1024
}
```text

---

### Download de Arquivo

**Usando HTTP Request node no n8n:**

```text
Method: GET
URL: http://seaweedfs:8888/my-bucket/my-file.pdf
```text

**Exemplo com curl:**
```bash
curl "http://localhost:8888/my-bucket/document.pdf" -o downloaded.pdf
```text

---

### Listar Arquivos

**Usando HTTP Request node no n8n:**

```text
Method: GET
URL: http://seaweedfs:8888/my-bucket/?pretty=y
Headers:
  Accept: application/json
```text

**Response:**
```json
{
  "Path": "/my-bucket",
  "Entries": [
    {
      "FullPath": "/my-bucket/document.pdf",
      "Mtime": "2025-10-07T15:30:00-03:00",
      "FileSize": 1024,
      "Mime": "application/pdf"
    }
  ]
}
```text

---

### Deletar Arquivo

**Usando HTTP Request node no n8n:**

```text
Method: DELETE
URL: http://seaweedfs:8888/my-bucket/my-file.pdf
```text

**Exemplo com curl:**
```bash
curl -X DELETE "http://localhost:8888/my-bucket/document.pdf"
```text

---

### Copiar Arquivo (server-side)

**Eficiente! Copia diretamente no servidor sem transferir dados:**

```bash
# Copiar dentro do SeaweedFS
curl -X POST 'http://localhost:8888/destination/file.pdf?cp.from=/source/file.pdf'
```text

---

## Exemplo de Workflow n8n

### Workflow: Upload de Anexo de Email para SeaweedFS

```text
1. Email Trigger (IMAP)
   ↓
2. Extract Attachments
   ↓
3. HTTP Request (Upload to SeaweedFS)
   Method: POST
   URL: http://seaweedfs:8888/email-attachments/{{ $json.filename }}
   Body: {{ $binary.attachment }}
   ↓
4. Save Metadata to Database
```text

### Workflow: Processar Imagem com FileFlows

```text
1. Webhook Trigger (Directus upload)
   ↓
2. HTTP Request (Copy to FileFlows input)
   Method: POST
   URL: http://seaweedfs:8888/fileflows-input/{{ $json.filename }}?cp.from=/directus-uploads/{{ $json.file_id }}
   ↓
3. Trigger FileFlows Processing
   ↓
4. Wait for FileFlows Completion
   ↓
5. HTTP Request (Get processed file)
   Method: GET
   URL: http://seaweedfs:8888/fileflows-output/{{ $json.filename }}
```text

---

## Operações Avançadas

### 1. Upload com TTL (Time To Live)

```bash
# Arquivo expira em 24 horas
curl -F file=@temp.txt "http://localhost:8888/temp/file.txt?ttl=1d"
```text

### 2. Upload com Metadata Customizada

```bash
# Adicionar headers customizados
curl -F file=@doc.pdf \
  -H "Seaweed-Author: John Doe" \
  -H "Seaweed-Category: invoices" \
  "http://localhost:8888/documents/invoice.pdf"

# Metadata retornada no GET:
curl -I "http://localhost:8888/documents/invoice.pdf"
# Seaweed-Author: John Doe
# Seaweed-Category: invoices
```text

### 3. Append to File

```bash
# Adicionar conteúdo ao final do arquivo
curl -F file=@additional-data.txt \
  "http://localhost:8888/logs/application.log?op=append"
```text

### 4. Paginação de Listagem

```bash
# Listar com limit e paginação
curl "http://localhost:8888/my-bucket/?limit=10&lastFileName=file10.txt&pretty=y" \
  -H "Accept: application/json"
```text

---

## Integração com Directus

### Workflow: Sincronizar Assets Directus → SeaweedFS

```javascript
// n8n HTTP Request node
// Quando asset é criado no Directus:

// 1. Get file from Directus
GET https://directus.example.com/assets/{{ $json.id }}
Auth: Bearer {{ $env.DIRECTUS_TOKEN }}

// 2. Upload to SeaweedFS for backup/processing
POST http://seaweedfs:8888/directus-backup/{{ $json.filename_download }}
Body: {{ $binary.data }}

// 3. Save SeaweedFS URL to Directus metadata
PATCH https://directus.example.com/items/files/{{ $json.id }}
Body: {
  "seaweedfs_url": "http://seaweedfs:8888/directus-backup/{{ $json.filename_download }}"
}
```text

---

## Monitoramento e Health Check

### Verificar Status do SeaweedFS

```bash
# Master API (cluster status)
curl http://localhost:9333/cluster/status

# Filer API (health check)
curl http://localhost:8888/

# Volume API
curl http://localhost:8080/status
```text

### Verificar Espaço Disponível

```bash
# Via Master API
curl http://localhost:9333/dir/status | jq '.Topology.Free'
```text

---

## Troubleshooting

### Erro: Connection Refused

**Sintoma**: `curl: (7) Failed to connect to seaweedfs port 8888`

**Solução**:
```bash
# Verificar se SeaweedFS está rodando
docker compose ps seaweedfs

# Verificar portas expostas
docker compose port seaweedfs 8888

# Verificar logs
docker compose logs seaweedfs | tail -50
```text

### Erro: 404 Not Found

**Sintoma**: Upload retorna 404

**Solução**:
```bash
# Criar o bucket primeiro
curl -X POST http://localhost:8888/buckets/my-bucket/

# Verificar buckets existentes
curl http://localhost:8888/buckets/
```text

### Arquivo Muito Grande

**Sintoma**: Upload de arquivo grande falha

**Solução**:
```bash
# Usar chunked upload ou aumentar limites no Caddy
# Para n8n workflows: dividir arquivo em chunks
```text

---

## Referências

- **SeaweedFS Filer API**: https://github.com/seaweedfs/seaweedfs/wiki/Filer-Server-API
- **n8n HTTP Request Node**: https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.httprequest/
- **Story 5.1**: SeaweedFS Object Storage Setup
- **Story 5.3**: Storage Integration Testing

---

## Vantagens desta Solução

✅ **100% Gratuita** - Não requer Enterprise License
✅ **Simples** - REST API padrão HTTP
✅ **Flexível** - Workflows decidem quando usar storage externo
✅ **Bem Documentada** - API oficial do SeaweedFS
✅ **Performática** - Operações server-side (copy)
✅ **Compatível** - Funciona com qualquer cliente HTTP

---

## Próximos Passos

1. ✅ n8n configurado com filesystem storage
2. ✅ SeaweedFS Filer API acessível
3. ⏭️ Criar workflows exemplo
4. ⏭️ Integrar com Directus para backup de assets
5. ⏭️ Integrar com FileFlows para processamento de mídia
