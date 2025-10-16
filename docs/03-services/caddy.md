# Caddy - Reverse Proxy e Gerenciamento SSL

## Visão Geral

### O que é Caddy?

Caddy é um servidor web e reverse proxy moderno, poderoso e extensível, escrito em Go. Sua principal característica é a **geração automática de certificados SSL/TLS** via Let's Encrypt, sem necessidade de configuração manual.

No contexto do BorgStack, o Caddy funciona como:
- **Ponto de entrada único**: Todas as requisições HTTPS passam pelo Caddy
- **Gerenciador de SSL**: Obtém e renova certificados automaticamente
- **Reverse Proxy**: Roteia tráfego para os serviços corretos
- **Camada de segurança**: Aplica headers de segurança, CORS, rate limiting

### Casos de Uso no BorgStack

1. **Automatic HTTPS**: Certificados SSL gratuitos via Let's Encrypt, renovação automática
2. **Roteamento de Domínios**: Cada serviço tem seu próprio subdomínio (n8n.exemplo.com.br, chatwoot.exemplo.com.br)
3. **Isolamento de Rede**: Único serviço na rede `borgstack_external`, protegendo serviços internos
4. **Headers de Segurança**: CSP, HSTS, X-Frame-Options aplicados automaticamente
5. **HTTP/2 e HTTP/3**: Suporte nativo para protocolos modernos

---

## Configuração Inicial

### Localização dos Arquivos

```bash
# Caddyfile principal (produção)
config/caddy/Caddyfile

# Caddyfile de desenvolvimento (localhost)
config/caddy/Caddyfile.dev

# Logs do Caddy
docker compose logs -f caddy

# Verificar status
docker compose ps caddy
```

### Configuração de Desenvolvimento Local

Para desenvolvimento local sem domínio configurado, o BorgStack usa `docker-compose.override.yml` automaticamente:

```bash
# Iniciar modo desenvolvimento local
docker compose up -d

# Acesso local: http://localhost:8080/n8n, /chatwoot, etc.
```

**Configuração Local Diferenças:**

| Característica | Produção | Desenvolvimento Local |
|---------------|-----------|----------------------|
| **Domínio** | seu-dominio.com | localhost |
| **Portas** | 80/443 | 8080/4433 (evita conflitos) |
| **SSL** | Automático Let's Encrypt | HTTP apenas (AUTO_HTTPS=off) |
| **Caddyfile** | Caddyfile (produção) | Caddyfile.dev (localhost) |
| **Comando** | `-f docker-compose.yml -f docker-compose.prod.yml up` | `docker compose up` (automático) |

**Exemplo de Caddyfile.dev:**

```caddyfile
# Desenvolvimento Local - HTTP apenas
{
    auto_https off  # Desabilitar SSL para localhost
    email admin@localhost
}

localhost:8080 {
    handle /n8n* {
        reverse_proxy n8n:5678
    }

    handle /chatwoot* {
        reverse_proxy chatwoot:3000
    }

    handle /evolution* {
        reverse_proxy evolution:8080
    }

    handle /lowcoder* {
        reverse_proxy lowcoder-frontend:3000
    }

    handle /directus* {
        reverse_proxy directus:8055
    }

    handle /fileflows* {
        reverse_proxy fileflows:5000
    }

    handle /duplicati* {
        reverse_proxy duplicati:8200
    }

    # Resposta padrão
    respond "BorgStack Local Mode - Access services: /n8n, /chatwoot, /evolution, /lowcoder, /directus, /fileflows, /duplicati" 200
}
```

**Alternar Entre Modos:**

```bash
# Para modo local (testes/desenvolvimento)
docker compose up -d
# Acesso: http://localhost:8080/*

# Para modo produção (domínios reais)
docker compose down
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
# Acesso: https://seu-dominio.com/*
```

### Estrutura do Caddyfile no BorgStack

O Caddyfile do BorgStack segue este padrão:

```caddyfile
# Configurações globais
{
    email admin@example.com
    # Staging para testes (comentar em produção)
    # acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
}

# n8n - Workflow Automation
n8n.exemplo.com.br {
    reverse_proxy n8n:5678
}

# Chatwoot - Customer Service
chatwoot.exemplo.com.br {
    reverse_proxy chatwoot:3000
}

# Evolution API - WhatsApp
evolution.exemplo.com.br {
    reverse_proxy evolution-api:8080
}

# Directus - Headless CMS
directus.exemplo.com.br {
    reverse_proxy directus:8055
}

# FileFlows - Media Processing
fileflows.exemplo.com.br {
    reverse_proxy fileflows:5000
}

# Lowcoder - Low-code Platform
lowcoder.exemplo.com.br {
    reverse_proxy lowcoder-frontend:3000
}

# Duplicati - Backup System
duplicati.exemplo.com.br {
    reverse_proxy duplicati:8200
}

# SeaweedFS S3 Gateway
s3.exemplo.com.br {
    reverse_proxy seaweedfs:8333
}
```

### Verificando Configuração

```bash
# Validar sintaxe do Caddyfile
docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile

# Recarregar configuração (sem downtime)
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile

# Verificar certificados SSL
docker compose exec caddy caddy list-certificates
```

---

## Conceitos Fundamentais

### 1. Caddyfile

O **Caddyfile** é o arquivo de configuração do Caddy. Sintaxe simples e legível:

```caddyfile
# Comentários começam com #

# Site block: domínio + configurações
exemplo.com.br {
    # Diretivas de configuração
    reverse_proxy localhost:8080
    encode gzip
    log
}
```

**Características**:
- Formato declarativo e hierárquico
- Suporte a variáveis e placeholders
- Importação de snippets reutilizáveis
- Validação de sintaxe embutida

### 2. Reverse Proxy

O Caddy roteia requisições HTTP(S) para serviços backend:

```caddyfile
# Proxy simples
exemplo.com.br {
    reverse_proxy backend:8080
}

# Proxy com múltiplos backends (load balancing)
api.exemplo.com.br {
    reverse_proxy {
        to backend1:8080
        to backend2:8080
        to backend3:8080
        lb_policy round_robin
    }
}

# Proxy com path matching
exemplo.com.br {
    # API requests
    reverse_proxy /api/* backend-api:9000

    # Frontend requests
    reverse_proxy frontend:3000
}
```

### 3. Automatic HTTPS

O Caddy obtém certificados SSL automaticamente quando você especifica um domínio:

```caddyfile
# ✅ Automatic HTTPS (domínio configurado)
exemplo.com.br {
    reverse_proxy backend:8080
}

# ❌ Sem HTTPS (localhost ou IP)
:8080 {
    reverse_proxy backend:8080
}
```

**Processo**:
1. Caddy detecta domínio no Caddyfile
2. Verifica DNS aponta para o servidor
3. Inicia desafio ACME HTTP-01 (porta 80)
4. Let's Encrypt valida domínio
5. Certificado emitido e instalado
6. Renovação automática 30 dias antes do vencimento

### 4. Matchers

**Matchers** permitem aplicar diretivas condicionalmente:

```caddyfile
exemplo.com.br {
    # Matcher por path
    @api path /api/*
    reverse_proxy @api backend-api:9000

    # Matcher por header
    @websockets {
        header Connection *Upgrade*
        header Upgrade websocket
    }
    reverse_proxy @websockets backend-ws:6001

    # Fallback (sem matcher)
    reverse_proxy frontend:3000
}
```

### 5. Placeholders

**Placeholders** são variáveis dinâmicas:

```caddyfile
exemplo.com.br {
    reverse_proxy backend:8080 {
        # Preservar host original
        header_up Host {http.request.host}

        # Adicionar IP real do cliente
        header_up X-Real-IP {http.request.remote.host}

        # Adicionar protocolo original
        header_up X-Forwarded-Proto {http.request.scheme}
    }
}
```

**Placeholders comuns**:
- `{http.request.host}`: Domínio da requisição
- `{http.request.remote}`: IP do cliente
- `{http.request.uri}`: URI completo
- `{http.request.scheme}`: http ou https
- `{upstream_hostport}`: Host:port do backend

---

## Tutorial Passo a Passo: Adicionar Novo Serviço

### Passo 1: Preparar Serviço no Docker Compose

Adicione o serviço ao `docker-compose.yml`:

```yaml
services:
  meu-servico:
    image: meu-servico:latest
    container_name: meu-servico
    networks:
      - borgstack_internal  # Rede interna apenas
    environment:
      - PORT=8080
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

**Importante**: Serviços **não** devem expor portas (`ports:`) nem estar na rede `borgstack_external`.

### Passo 2: Adicionar Entrada no Caddyfile

Edite `config/caddy/Caddyfile`:

```caddyfile
# Meu Novo Serviço
meu-servico.exemplo.com.br {
    reverse_proxy meu-servico:8080
}
```

### Passo 3: Configurar DNS

Adicione registro A no seu provedor DNS:

```
Type: A
Name: meu-servico
Value: SEU_IP_PUBLICO
TTL: 3600
```

Verificar propagação:

```bash
# Aguardar propagação (pode levar até 48h)
dig meu-servico.exemplo.com.br

# Verificar resposta correta
# ;; ANSWER SECTION:
# meu-servico.exemplo.com.br. 3600 IN A SEU_IP_PUBLICO
```

### Passo 4: Recarregar Caddy

```bash
# Validar configuração
docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile

# Recarregar (sem downtime)
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile

# Verificar logs
docker compose logs -f caddy
```

### Passo 5: Verificar Certificado SSL

```bash
# Aguardar emissão do certificado (1-2 minutos)
docker compose logs caddy | grep "certificate obtained"

# Listar certificados
docker compose exec caddy caddy list-certificates

# Testar acesso HTTPS
curl -I https://meu-servico.exemplo.com.br
```

**Resposta esperada**:
```
HTTP/2 200
server: Caddy
```

---

## Configurações Avançadas

### Headers de Segurança

Adicione headers de segurança a todos os serviços:

```caddyfile
# Snippet reutilizável
(security_headers) {
    header {
        # XSS Protection
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        X-XSS-Protection "1; mode=block"

        # HSTS (6 meses)
        Strict-Transport-Security "max-age=15552000; includeSubDomains; preload"

        # Referrer Policy
        Referrer-Policy "strict-origin-when-cross-origin"

        # Permissions Policy
        Permissions-Policy "geolocation=(), microphone=(), camera=()"

        # Remove Server header
        -Server
    }
}

# Aplicar a todos os serviços
n8n.exemplo.com.br {
    import security_headers
    reverse_proxy n8n:5678
}

chatwoot.exemplo.com.br {
    import security_headers
    reverse_proxy chatwoot:3000
}
```

### Configuração de CORS

Para APIs que precisam de CORS:

```caddyfile
api.exemplo.com.br {
    @options method OPTIONS

    # Responder a preflight requests
    handle @options {
        header {
            Access-Control-Allow-Origin "*"
            Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
            Access-Control-Allow-Headers "Content-Type, Authorization"
            Access-Control-Max-Age "3600"
        }
        respond 204
    }

    # Adicionar headers CORS a todas as respostas
    header {
        Access-Control-Allow-Origin "*"
        Access-Control-Allow-Credentials "true"
    }

    reverse_proxy backend-api:8080
}
```

### Compressão de Respostas

Habilitar compressão para reduzir tamanho de transferência:

```caddyfile
exemplo.com.br {
    # Compressão automática (gzip, brotli, zstd)
    encode {
        gzip 6
        zstd
        minimum_length 1024
    }

    reverse_proxy backend:8080
}
```

### Rate Limiting

Limitar taxa de requisições por IP:

```caddyfile
api.exemplo.com.br {
    # Requer plugin: github.com/mholt/caddy-ratelimit
    rate_limit {
        zone api {
            key {http.request.remote.host}
            events 100
            window 1m
        }
    }

    reverse_proxy backend-api:8080
}
```

### WebSocket Support

Configurar proxy para WebSockets:

```caddyfile
websocket.exemplo.com.br {
    @websockets {
        header Connection *Upgrade*
        header Upgrade websocket
    }

    reverse_proxy @websockets backend-ws:6001 {
        header_up Host {http.request.host}
        header_up X-Real-IP {http.request.remote.host}
    }
}
```

### Múltiplos Domínios para Mesmo Serviço

```caddyfile
# Múltiplos domínios separados por vírgula
exemplo.com.br, www.exemplo.com.br {
    # Redirecionar www para domínio principal
    @www host www.exemplo.com.br
    redir @www https://exemplo.com.br{uri} permanent

    reverse_proxy backend:8080
}
```

### Health Checks e Load Balancing

```caddyfile
api.exemplo.com.br {
    reverse_proxy {
        to backend1:8080
        to backend2:8080
        to backend3:8080

        # Load balancing policy
        lb_policy round_robin
        lb_try_duration 2s
        lb_try_interval 500ms

        # Active health checking
        health_uri /health
        health_interval 30s
        health_timeout 10s
        health_status 200

        # Passive health checking
        fail_duration 30s
        max_fails 3
        unhealthy_status 500 502 503
    }
}
```

### Logging Customizado

```caddyfile
exemplo.com.br {
    # Log de acesso
    log {
        output file /var/log/caddy/exemplo.com.br.log {
            roll_size 100mb
            roll_keep 5
            roll_keep_for 720h
        }
        format json
        level INFO
    }

    reverse_proxy backend:8080
}
```

---

## Gerenciamento de Certificados SSL

### Verificar Status dos Certificados

```bash
# Listar todos os certificados
docker compose exec caddy caddy list-certificates

# Verificar validade de um certificado específico
echo | openssl s_client -connect exemplo.com.br:443 2>/dev/null | openssl x509 -noout -dates
```

### Forçar Renovação de Certificado

```bash
# Parar Caddy
docker compose stop caddy

# Remover certificados existentes (CUIDADO!)
docker compose exec caddy rm -rf /data/caddy/certificates

# Reiniciar Caddy (irá obter novos certificados)
docker compose start caddy

# Verificar logs de renovação
docker compose logs -f caddy | grep "certificate"
```

### Usar Staging Environment (Testes)

Para evitar rate limits durante testes:

```caddyfile
{
    email admin@exemplo.com.br
    # Usar Let's Encrypt Staging (certificados inválidos, mas sem rate limit)
    acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
}

# Seus sites aqui...
```

**Importante**: Remover `acme_ca` em produção para obter certificados válidos.

### Certificados Wildcard

Para múltiplos subdomínios:

```caddyfile
{
    email admin@exemplo.com.br
    # Requer DNS provider plugin (ex: cloudflare)
    acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
}

*.exemplo.com.br {
    # Certificado wildcard cobrirá todos os subdomínios
    reverse_proxy {
        # Roteamento dinâmico baseado no subdomínio
        @n8n host n8n.exemplo.com.br
        @chatwoot host chatwoot.exemplo.com.br

        handle @n8n {
            reverse_proxy n8n:5678
        }

        handle @chatwoot {
            reverse_proxy chatwoot:3000
        }
    }
}
```

### Monitorar Renovação Automática

```bash
# Verificar quando certificado expira
docker compose exec caddy caddy list-certificates | grep -A 5 "exemplo.com.br"

# Caddy renova automaticamente 30 dias antes da expiração
# Verificar logs de renovação
docker compose logs caddy | grep "renew"
```

---

## Integração com Serviços BorgStack

### n8n - Workflow Automation

```caddyfile
n8n.exemplo.com.br {
    # Headers para webhooks
    header {
        # Permitir embedding de n8n (se necessário)
        X-Frame-Options "ALLOWALL"
    }

    reverse_proxy n8n:5678 {
        # Preservar host para webhooks funcionarem
        header_up Host {http.request.host}
        header_up X-Real-IP {http.request.remote.host}
        header_up X-Forwarded-Proto {http.request.scheme}

        # Timeout maior para workflows longos
        transport http {
            response_header_timeout 300s
        }
    }
}
```

### Chatwoot - Customer Service

```caddyfile
chatwoot.exemplo.com.br {
    # WebSocket support para chat em tempo real
    @websockets {
        header Connection *Upgrade*
        header Upgrade websocket
    }

    reverse_proxy @websockets chatwoot:3000 {
        header_up Host {http.request.host}
        header_up Upgrade {http.request.header.Upgrade}
        header_up Connection {http.request.header.Connection}
    }

    reverse_proxy chatwoot:3000 {
        header_up Host {http.request.host}
        header_up X-Real-IP {http.request.remote.host}
    }
}
```

### Evolution API - WhatsApp

```caddyfile
evolution.exemplo.com.br {
    # CORS para webhooks e API calls
    header {
        Access-Control-Allow-Origin "*"
        Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
        Access-Control-Allow-Headers "Content-Type, apikey"
    }

    @options method OPTIONS
    handle @options {
        respond 204
    }

    reverse_proxy evolution-api:8080 {
        # Timeout maior para processamento de mídia
        transport http {
            response_header_timeout 120s
        }
    }
}
```

### Directus - Headless CMS

```caddyfile
directus.exemplo.com.br {
    # Upload de arquivos grandes
    request_body {
        max_size 100MB
    }

    # CORS para API
    header {
        Access-Control-Allow-Origin "*"
        Access-Control-Allow-Credentials "true"
    }

    reverse_proxy directus:8055 {
        # Timeout para upload de arquivos
        transport http {
            response_header_timeout 300s
        }
    }
}
```

### SeaweedFS - Object Storage

```caddyfile
# S3 Gateway
s3.exemplo.com.br {
    # CORS para upload/download direto
    header {
        Access-Control-Allow-Origin "*"
        Access-Control-Allow-Methods "GET, PUT, POST, DELETE, HEAD"
        Access-Control-Allow-Headers "Content-Type, Content-MD5, Authorization"
        Access-Control-Expose-Headers "ETag"
    }

    reverse_proxy seaweedfs:8333 {
        # Timeout maior para uploads
        transport http {
            response_header_timeout 600s
        }
    }
}
```

---

## Práticas de Segurança

### 1. Restringir Acesso por IP

```caddyfile
admin.exemplo.com.br {
    # Permitir apenas IPs específicos
    @allowed {
        remote_ip 203.0.113.0/24 198.51.100.5
    }

    handle @allowed {
        reverse_proxy admin-panel:8080
    }

    # Bloquear outros IPs
    respond "Forbidden" 403
}
```

### 2. Autenticação Básica

```caddyfile
interno.exemplo.com.br {
    # Requer usuário e senha
    basicauth {
        admin $2a$14$Zkx19XLiW6VYouLHR5NmfOFU0z2GTNmpkT/5qqR7hx4S4N4xPOUBG
    }

    reverse_proxy internal-app:8080
}
```

Gerar hash de senha:

```bash
# Instalar caddy localmente ou usar container
docker run --rm caddy:2.10 caddy hash-password --plaintext 'minha_senha_segura'
```

### 3. Rate Limiting Global

```caddyfile
{
    servers {
        # Rate limit global
        timeouts {
            read_body 10s
            read_header 5s
            write 30s
            idle 120s
        }
    }
}
```

### 4. Proteção Contra Clickjacking

```caddyfile
exemplo.com.br {
    header {
        # Impedir embedding em iframes de outros domínios
        X-Frame-Options "DENY"

        # Ou permitir apenas do próprio domínio
        # X-Frame-Options "SAMEORIGIN"

        # CSP moderna (mais flexível)
        Content-Security-Policy "frame-ancestors 'self'"
    }

    reverse_proxy backend:8080
}
```

### 5. HTTPS Obrigatório

```caddyfile
# HTTP (porta 80) redireciona automaticamente para HTTPS
# Para forçar HTTPS em todos os lugares:

{
    # Desabilitar servidor HTTP em alguns casos
    auto_https disable_redirects
}

http://exemplo.com.br {
    redir https://exemplo.com.br{uri} permanent
}

https://exemplo.com.br {
    reverse_proxy backend:8080
}
```

---

## Solução de Problemas

### 1. Certificado SSL Não É Emitido

**Sintomas**: Site não carrega com HTTPS, erro "NET::ERR_CERT_AUTHORITY_INVALID"

**Soluções**:

```bash
# Verificar DNS aponta para servidor
dig exemplo.com.br

# Verificar portas 80 e 443 abertas
sudo ufw status
# Se necessário: sudo ufw allow 80/tcp && sudo ufw allow 443/tcp

# Verificar logs do Caddy
docker compose logs caddy | grep -i "error\|fail"

# Causas comuns:
# 1. DNS não propagado (aguardar até 48h)
# 2. Firewall bloqueando porta 80 (Let's Encrypt precisa validar)
# 3. Outro processo usando porta 80/443
sudo netstat -tulpn | grep :80
sudo netstat -tulpn | grep :443

# 4. Rate limit do Let's Encrypt atingido (usar staging)
# Editar Caddyfile:
# {
#     acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
# }
```

### 2. Serviço Não É Acessível

**Sintomas**: 502 Bad Gateway ou timeout

**Soluções**:

```bash
# Verificar serviço backend está rodando
docker compose ps backend

# Verificar health do serviço
docker inspect backend | grep -A 10 "Health"

# Testar conectividade do Caddy ao backend
docker compose exec caddy wget -O- http://backend:8080/health

# Verificar nome do serviço está correto no Caddyfile
grep "backend" config/caddy/Caddyfile

# Verificar serviço está na rede borgstack_internal
docker inspect backend | grep -A 5 "Networks"

# Verificar logs do backend
docker compose logs -f backend
```

### 3. Redirect Loop (Redirecionamento Infinito)

**Sintomas**: Navegador mostra "ERR_TOO_MANY_REDIRECTS"

**Soluções**:

```bash
# Causa comum: backend fazendo redirect HTTP → HTTPS,
# mas Caddy já está fazendo isso

# Solução 1: Desabilitar redirect no backend
# Editar configuração do backend para aceitar HTTP

# Solução 2: Informar backend que requisição é HTTPS
# Adicionar headers no Caddyfile:

exemplo.com.br {
    reverse_proxy backend:8080 {
        header_up X-Forwarded-Proto {http.request.scheme}
        header_up X-Forwarded-Host {http.request.host}
    }
}

# Solução 3: Se backend espera HTTPS, usar:
exemplo.com.br {
    reverse_proxy https://backend:8443 {
        transport http {
            tls_insecure_skip_verify  # Apenas para desenvolvimento!
        }
    }
}
```

### 4. Configuração Não Recarrega

**Sintomas**: Mudanças no Caddyfile não têm efeito

**Soluções**:

```bash
# Validar sintaxe primeiro
docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile

# Se houver erro de sintaxe, corrigir e validar novamente

# Recarregar configuração
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile

# Se reload falhar, reiniciar container
docker compose restart caddy

# Verificar configuração ativa
docker compose exec caddy caddy adapt --config /etc/caddy/Caddyfile
```

### 5. CORS Não Funciona

**Sintomas**: Erro "CORS policy" no console do navegador

**Soluções**:

```caddyfile
api.exemplo.com.br {
    # Responder a preflight OPTIONS
    @options method OPTIONS
    handle @options {
        header {
            Access-Control-Allow-Origin "*"
            Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
            Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With"
            Access-Control-Max-Age "3600"
        }
        respond 204
    }

    # Adicionar headers CORS a todas as respostas
    header {
        Access-Control-Allow-Origin "*"
        Access-Control-Allow-Credentials "true"
    }

    reverse_proxy backend:8080
}
```

### 6. Upload de Arquivo Falha

**Sintomas**: Erro 413 "Request Entity Too Large"

**Soluções**:

```caddyfile
exemplo.com.br {
    # Aumentar limite de upload (padrão: sem limite no Caddy)
    request_body {
        max_size 500MB
    }

    reverse_proxy backend:8080 {
        # Aumentar timeout para uploads grandes
        transport http {
            response_header_timeout 600s
        }
    }
}
```

Verificar também limite do backend:
```bash
# nginx: client_max_body_size
# node/express: body-parser limit
# etc.
```

### 7. WebSocket Não Conecta

**Sintomas**: Erro "WebSocket connection failed"

**Soluções**:

```caddyfile
exemplo.com.br {
    @websockets {
        header Connection *Upgrade*
        header Upgrade websocket
    }

    reverse_proxy @websockets backend:6001 {
        header_up Host {http.request.host}
        header_up Upgrade {http.request.header.Upgrade}
        header_up Connection {http.request.header.Connection}
        header_up X-Real-IP {http.request.remote.host}

        # Sem timeout para conexões WebSocket
        transport http {
            response_header_timeout 0
        }
    }

    # Requisições HTTP normais
    reverse_proxy backend:8080
}
```

---

## Comandos Úteis

### Gerenciamento de Certificados

```bash
# Listar certificados ativos
docker compose exec caddy caddy list-certificates

# Ver detalhes de um certificado
docker compose exec caddy caddy list-certificates --id exemplo.com.br

# Forçar renovação (apenas se necessário)
docker compose exec caddy caddy reload --force
```

### Diagnóstico

```bash
# Verificar sintaxe do Caddyfile
docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile

# Ver configuração JSON final (após adaptar)
docker compose exec caddy caddy adapt --config /etc/caddy/Caddyfile

# Testar endpoint
curl -I https://exemplo.com.br

# Verificar headers de resposta
curl -v https://exemplo.com.br 2>&1 | grep -i "^<"

# Testar com IP específico (ignorar DNS)
curl -H "Host: exemplo.com.br" https://SEU_IP_PUBLICO
```

### Logs e Monitoramento

```bash
# Logs em tempo real
docker compose logs -f caddy

# Filtrar logs por nível
docker compose logs caddy | grep ERROR

# Logs de certificados
docker compose logs caddy | grep -i "certificate\|acme"

# Logs de uma requisição específica
docker compose logs caddy | grep "exemplo.com.br"

# Estatísticas de uso
docker stats caddy
```

---

## 8. Dicas e Melhores Práticas

### 8.1 Configuração Otimizada
Consulte [docs/02-configuracao.md](../02-configuracao.md) para variáveis de ambiente específicas deste serviço.

### 8.2 Performance
- HTTP/2 habilitado por padrão
- Gzip/Brotli compression
- Rate limiting por IP

### 8.3 Segurança
- SSL automático Let's Encrypt
- Headers de segurança (HSTS, CSP)
- Block IPs suspeitos

### 8.4 Monitoramento
- Status codes 4xx/5xx
- Latência de proxy
- Certificados SSL expirando

### 8.5 Casos de Uso
Ver workflows de exemplo em [docs/09-workflows-exemplo.md](../09-workflows-exemplo.md)

---

## Recursos Adicionais

### Documentação Oficial
- [Caddy Docs](https://caddyserver.com/docs/)
- [Caddyfile Tutorial](https://caddyserver.com/docs/caddyfile-tutorial)
- [Reverse Proxy Guide](https://caddyserver.com/docs/quick-starts/reverse-proxy)
- [Automatic HTTPS](https://caddyserver.com/docs/automatic-https)

### Comunidade
- [Caddy Forum](https://caddy.community/)
- [GitHub Discussions](https://github.com/caddyserver/caddy/discussions)

### Ferramentas
- [SSL Labs Test](https://www.ssllabs.com/ssltest/) - Testar segurança SSL
- [Caddyfile Formatter](https://caddyserver.com/docs/caddyfile/formatter) - Formatar Caddyfile

---

## Próximos Passos

Depois de configurar o Caddy, você pode:

1. **Configurar Serviços Backend**: Ver guias em [docs/03-services/](./README.md)
2. **Otimizar Performance**: Ver [docs/08-desempenho.md](../08-desempenho.md)
3. **Hardening de Segurança**: Ver [docs/07-seguranca.md](../07-seguranca.md)
4. **Monitoramento**: Configurar alertas de expiração de certificados

---

## Referências Técnicas

### Variáveis de Ambiente

```bash
# No docker-compose.yml
environment:
  - CADDY_ADMIN=0.0.0.0:2019  # API de administração
  - ACME_AGREE=true            # Aceitar termos Let's Encrypt
```

### Portas e Endpoints

| Serviço | Porta Interna | Porta Externa | Descrição |
|---------|---------------|---------------|-----------|
| Caddy HTTP | 80 | 80 | Desafio ACME e redirect HTTPS |
| Caddy HTTPS | 443 | 443 | Tráfego HTTPS principal |
| Caddy Admin API | 2019 | - | API de gerenciamento (não exposta) |

### Redes

- **borgstack_external**: Caddy é o único serviço nesta rede
- **borgstack_internal**: Caddy acessa todos os serviços backend aqui

### Volumes

```yaml
volumes:
  borgstack_caddy_data:   # Certificados SSL e configuração
  borgstack_caddy_config: # Estado interno do Caddy
```

**Backup**: Incluir `borgstack_caddy_data` no backup do Duplicati para preservar certificados.

---

**Última atualização**: 2025-10-08
**Versão do BorgStack**: 1.0
**Versão do Caddy**: 2.10
