# Guia de Instalação do BorgStack

Guia completo para instalação do BorgStack em Ubuntu Server 24.04 LTS.

---

## Índice

1. [Requisitos do Sistema](#requisitos-do-sistema)
2. [Instalação Automatizada (Recomendado)](#instalação-automatizada-recomendado)
3. [Instalação Manual (Alternativa)](#instalação-manual-alternativa)
4. [Configuração Pós-Instalação](#configuração-pós-instalação)
5. [Verificação da Instalação](#verificação-da-instalação)
6. [Solução de Problemas](#solução-de-problemas)

---

## Requisitos do Sistema

### Requisitos de Hardware

O BorgStack requer recursos robustos para executar 14 containers simultaneamente com bom desempenho.

| Componente | Mínimo | Recomendado | Observações |
|------------|--------|-------------|-------------|
| **CPU** | 4 vCPUs | 8 vCPUs | Processadores mais recentes melhoram o desempenho |
| **RAM** | 16 GB | 36 GB | 16GB executa o sistema, 36GB oferece desempenho de produção |
| **Disco** | 200 GB SSD | 500 GB SSD | SSD é obrigatório para bom desempenho de banco de dados |
| **Rede** | 100 Mbps | 1 Gbps | Para integração com WhatsApp e APIs externas |

**💡 Recomendação:** Para ambientes de produção, sempre use as especificações recomendadas. Os requisitos mínimos são adequados apenas para testes e desenvolvimento.

### Requisitos de Software

| Software | Versão | Instalação |
|----------|--------|------------|
| **Sistema Operacional** | Ubuntu Server 24.04 LTS | Obrigatório - versões anteriores não são suportadas |
| **Docker Engine** | Última versão estável | Instalado automaticamente pelo bootstrap |
| **Docker Compose** | v2 (plugin) | Instalado automaticamente pelo bootstrap |
| **Git** | Qualquer versão recente | Para clonar o repositório |

**⚠️ IMPORTANTE:** Este guia é específico para **Ubuntu 24.04 LTS (Noble Numbat)**. Outras distribuições Linux ou versões do Ubuntu não são suportadas pelo script de instalação automática.

### Requisitos de Rede

Para uma instalação completa e funcional, você precisará:

**Obrigatório:**
- ✅ Endereço IP público acessível pela internet
- ✅ Portas 80 e 443 abertas e acessíveis (para SSL via Let's Encrypt)
- ✅ Porta 22 acessível (para SSH, administração remota)
- ✅ Registros DNS configurados para todos os serviços

**Domínios Necessários:**

Você precisará configurar subdomínios para cada serviço. Exemplo usando `example.com`:

```text
n8n.example.com         → n8n (automação de workflows)
chatwoot.example.com    → Chatwoot (atendimento ao cliente)
evolution.example.com   → Evolution API (WhatsApp Business)
lowcoder.example.com    → Lowcoder (construtor de aplicativos)
directus.example.com    → Directus (CMS headless)
fileflows.example.com   → FileFlows (processamento de mídia)
duplicati.example.com   → Duplicati (sistema de backup)
seaweedfs.example.com   → SeaweedFS (armazenamento de objetos)
```text

**💡 Dica:** Recomendamos usar um único domínio raiz com subdomínios, mas você pode usar domínios diferentes para cada serviço se preferir.

---

## Instalação Automatizada (Recomendado)

O script de bootstrap automatiza todo o processo de instalação, desde a validação de requisitos até a implantação dos serviços.

### Visão Geral do Processo

O script `bootstrap.sh` executa as seguintes etapas:

```mermaid
flowchart TD
    A[Início: ./scripts/bootstrap.sh] --> B{Verificar SO}
    B -->|Ubuntu 24.04| C[Verificar Recursos]
    B -->|Outra versão| Z[❌ Erro: SO incorreto]
    C -->|✓ RAM ≥ 16GB<br/>✓ Disk ≥ 200GB<br/>✓ CPU ≥ 4 cores| D[Instalar Docker]
    C -->|✗ Recursos insuficientes| Z
    D --> E[Configurar UFW]
    E --> F[Gerar arquivo .env]
    F --> G[Baixar imagens Docker]
    G --> H[Iniciar serviços]
    H --> I{Todos saudáveis?}
    I -->|Sim| J[✓ Sucesso]
    I -->|Não| K[Mostrar logs]
    K --> L[Verificar manualmente]
```text

**Tempo estimado:** 15-30 minutos (dependendo da velocidade da internet para download das imagens Docker)

### Passo a Passo

#### 1. Preparar o Servidor

Conecte-se ao seu servidor Ubuntu 24.04 via SSH:

```bash
ssh usuario@seu-servidor.com
```text

Certifique-se de estar usando um usuário com privilégios `sudo`. Você será solicitado a inserir sua senha durante a instalação.

#### 2. Clonar o Repositório

Clone o repositório do BorgStack:

```bash
# Navegue até o diretório home
cd ~

# Clone o repositório
git clone https://github.com/yourusername/borgstack.git

# Entre no diretório do projeto
cd borgstack
```text

**💡 Dica:** Se você não tiver o Git instalado, instale-o primeiro:
```bash
sudo apt-get update && sudo apt-get install -y git
```text

#### 3. Executar o Script de Bootstrap

Execute o script de instalação automatizada:

```bash
./scripts/bootstrap.sh
```text

**O que acontece durante a execução:**

**Etapa 1: Validação do Sistema (1-2 minutos)**
```text
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Validating Ubuntu Version
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Ubuntu 24.04 LTS detected

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Validating System Requirements
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ RAM: 36GB (min: 16GB, recommended: 36GB)
✓ RAM sufficient: 36GB
ℹ Disk: 500GB (min: 200GB, recommended: 500GB)
✓ Disk space sufficient: 500GB
ℹ CPU cores: 8 (min: 4, recommended: 8)
✓ CPU cores sufficient: 8
✓ All system requirements validated
```text

**Etapa 2: Instalação do Docker (3-5 minutos)**
```text
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Installing Docker Engine and Docker Compose v2
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ Installing Docker Engine...
ℹ Installing dependencies...
ℹ Adding Docker GPG key...
ℹ Adding Docker repository...
ℹ Installing Docker packages...
ℹ Adding user 'usuario' to docker group...
ℹ Starting Docker service...
✓ Docker installed: Docker version 27.3.1, build ce12230
✓ Docker Compose installed: Docker Compose version v2.29.7
⚠ NOTE: You may need to log out and back in for docker group membership to take effect.
```text

**Etapa 3: Configuração do Firewall (1 minuto)**
```text
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Configuring UFW Firewall
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ Configuring UFW rules...
ℹ Allowing SSH (port 22)...
ℹ Allowing HTTP (port 80)...
ℹ Allowing HTTPS (port 443)...
ℹ Enabling UFW firewall...

Status: active
To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
80/tcp                     ALLOW       Anywhere
443/tcp                    ALLOW       Anywhere

✓ Firewall configured
```text

**Etapa 4: Geração do Arquivo .env (1 minuto)**
```text
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Generating .env File
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ Generating strong passwords (32 characters each)...
ℹ Setting secure file permissions (chmod 600)...
✓ Generated .env file with strong passwords
⚠ IMPORTANT: Save these credentials securely!
⚠ The .env file contains all system passwords
```text

**Etapa 5: Implantação dos Serviços (5-15 minutos)**
```text
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Deploying Services
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ Pulling Docker images (this may take several minutes)...
[+] Pulling 14/14
 ✔ postgresql Pulled
 ✔ redis Pulled
 ✔ mongodb Pulled
 ✔ caddy Pulled
 ✔ n8n Pulled
 ✔ chatwoot Pulled
 ✔ evolution Pulled
 ✔ lowcoder-api-service Pulled
 ✔ lowcoder-node-service Pulled
 ✔ lowcoder-frontend Pulled
 ✔ directus Pulled
 ✔ fileflows Pulled
 ✔ duplicati Pulled
 ✔ seaweedfs Pulled

ℹ Starting services...
✓ All services started successfully
```text

**Etapa 6: Validação de Health Checks (2-5 minutos)**
```text
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Validating Health Checks
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ Waiting for services to become healthy...
✓ postgresql: healthy
✓ redis: healthy
✓ mongodb: healthy
✓ n8n: healthy
✓ chatwoot: healthy
✓ evolution: healthy
✓ All core services are healthy
```text

#### 4. Revisar Informações de Instalação

Após a conclusão, o script exibirá informações importantes:

```text
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Installation Complete!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ BorgStack has been successfully installed

Next Steps:

1. Configure DNS A records for all service domains:
   n8n.example.com         → YOUR_SERVER_IP
   chatwoot.example.com    → YOUR_SERVER_IP
   evolution.example.com   → YOUR_SERVER_IP
   lowcoder.example.com    → YOUR_SERVER_IP
   directus.example.com    → YOUR_SERVER_IP
   fileflows.example.com   → YOUR_SERVER_IP
   duplicati.example.com   → YOUR_SERVER_IP
   seaweedfs.example.com   → YOUR_SERVER_IP

2. Wait for DNS propagation (usually 5-15 minutes)
   Verify with: dig n8n.example.com

3. Access your services:
   - n8n will automatically generate SSL certificates via Let's Encrypt
   - First access may take 30-60 seconds for certificate generation

4. Configure each service:
   - See docs/03-services/ for service-specific setup guides
   - See docs/02-configuracao.md for system configuration

For troubleshooting, see docs/05-solucao-de-problemas.md
Installation log saved to: /tmp/borgstack-bootstrap.log
```text

**⚠️ IMPORTANTE:** Salve o arquivo `.env` em local seguro! Ele contém todas as credenciais do sistema.

---

## Instalação Manual (Alternativa)

Se você preferir instalar manualmente ou está usando um ambiente personalizado, siga estas etapas.

### 1. Validar Requisitos do Sistema

Verifique se seu servidor atende aos requisitos mínimos:

```bash
# Verificar versão do Ubuntu
cat /etc/os-release | grep VERSION_ID
# Deve retornar: VERSION_ID="24.04"

# Verificar RAM (em GB)
free -g | grep Mem: | awk '{print $2}'
# Deve retornar: 16 ou mais

# Verificar espaço em disco (em GB)
df -BG / | awk 'NR==2 {print $2}' | sed 's/G//'
# Deve retornar: 200 ou mais

# Verificar CPU cores
nproc
# Deve retornar: 4 ou mais
```text

### 2. Instalar Docker Engine

Remova versões antigas do Docker (se existirem):

```bash
sudo apt-get remove -y docker docker-engine docker.io containerd runc
```text

Instale as dependências necessárias:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
```text

Adicione a chave GPG oficial do Docker:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```text

Adicione o repositório Docker ao APT:

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```text

Atualize o índice de pacotes e instale o Docker:

```bash
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```text

Adicione seu usuário ao grupo docker:

```bash
sudo usermod -aG docker $USER
```text

Inicie e habilite o serviço Docker:

```bash
sudo systemctl start docker
sudo systemctl enable docker
```text

Verifique a instalação:

```bash
docker --version
# Deve exibir: Docker version 27.3.1 ou superior

docker compose version
# Deve exibir: Docker Compose version v2.29.7 ou superior
```text

**⚠️ IMPORTANTE:** Faça logout e login novamente para que a associação ao grupo docker tenha efeito. Alternativamente, execute `newgrp docker` para atualizar suas permissões de grupo na sessão atual.

### 3. Instalar Dependências do Sistema

Instale utilitários essenciais:

```bash
sudo apt-get install -y curl wget git ufw dnsutils htop sysstat
```text

### 4. Configurar o Firewall UFW

Configure as regras básicas do firewall:

```bash
# Definir políticas padrão
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Permitir SSH (porta 22)
sudo ufw allow 22/tcp

# Permitir HTTP (porta 80) - necessário para Let's Encrypt
sudo ufw allow 80/tcp

# Permitir HTTPS (porta 443)
sudo ufw allow 443/tcp

# Habilitar o firewall
sudo ufw enable

# Verificar status
sudo ufw status verbose
```text

**Saída esperada:**
```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
80/tcp                     ALLOW IN    Anywhere
443/tcp                    ALLOW IN    Anywhere
```text

**⚠️ ATENÇÃO:** Se você usa uma porta SSH personalizada (diferente de 22), ajuste a regra do UFW antes de habilitar o firewall, ou você perderá acesso SSH!

### 5. Clonar o Repositório

```bash
cd ~
git clone https://github.com/yourusername/borgstack.git
cd borgstack
```text

### 6. Criar e Configurar o Arquivo .env

Copie o arquivo de exemplo:

```bash
cp .env.example .env
```text

Edite o arquivo `.env` com suas configurações:

```bash
nano .env
```text

**Você DEVE alterar os seguintes valores:**

**Senhas de Banco de Dados (gere senhas fortes de 32 caracteres):**
```bash
# Gerar senha segura
openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
```text

Execute o comando acima 10 vezes para gerar senhas únicas para:
- `POSTGRES_PASSWORD`
- `N8N_DB_PASSWORD`
- `CHATWOOT_DB_PASSWORD`
- `DIRECTUS_DB_PASSWORD`
- `EVOLUTION_DB_PASSWORD`
- `MONGODB_ROOT_PASSWORD`
- `LOWCODER_DB_PASSWORD`
- `REDIS_PASSWORD`
- `LOWCODER_DB_ENCRYPTION_PASSWORD`
- `LOWCODER_DB_ENCRYPTION_SALT`

**Domínios (substitua `example.com` pelo seu domínio real):**
```bash
# Exemplo: se seu domínio é mycompany.com.br
N8N_HOST=n8n.mycompany.com.br
CHATWOOT_HOST=chatwoot.mycompany.com.br
# ... e assim por diante para todos os serviços
```text

**Configure permissões seguras:**
```bash
chmod 600 .env
```text

**⚠️ CRÍTICO:** Nunca commite o arquivo `.env` ao Git! Ele contém todas as credenciais do sistema.

### 7. Implantar os Serviços

Baixe as imagens Docker:

```bash
docker compose pull
```text

**Tempo estimado:** 5-15 minutos, dependendo da velocidade da internet.

Inicie os serviços:

```bash
docker compose up -d
```text

Verifique o status dos containers:

```bash
docker compose ps
```text

**Saída esperada (após 2-3 minutos):**
```text
NAME                        STATUS              PORTS
borgstack-postgresql-1      Up 2 minutes (healthy)
borgstack-redis-1           Up 2 minutes (healthy)
borgstack-mongodb-1         Up 2 minutes (healthy)
borgstack-caddy-1           Up 2 minutes (healthy)   0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
borgstack-n8n-1             Up 2 minutes (healthy)
borgstack-chatwoot-1        Up 2 minutes (healthy)
borgstack-evolution-1       Up 2 minutes (healthy)
...
```text

**💡 Dica:** Alguns serviços levam até 90 segundos para ficarem "healthy", especialmente o Directus (migrações de banco de dados).

---

## Configuração Pós-Instalação

Após a instalação bem-sucedida, você precisa configurar DNS e acessar os serviços.

### 1. Configurar Registros DNS

Configure registros DNS A para cada serviço apontando para o IP do seu servidor.

**No seu provedor DNS (exemplo: Cloudflare, GoDaddy, Route 53):**

| Tipo | Nome | Valor | TTL |
|------|------|-------|-----|
| A | n8n | `SEU_IP_PUBLICO` | 300 |
| A | chatwoot | `SEU_IP_PUBLICO` | 300 |
| A | evolution | `SEU_IP_PUBLICO` | 300 |
| A | lowcoder | `SEU_IP_PUBLICO` | 300 |
| A | directus | `SEU_IP_PUBLICO` | 300 |
| A | fileflows | `SEU_IP_PUBLICO` | 300 |
| A | duplicati | `SEU_IP_PUBLICO` | 300 |
| A | seaweedfs | `SEU_IP_PUBLICO` | 300 |

**💡 Dica:** Use TTL 300 (5 minutos) durante a configuração inicial. Após tudo funcionar, você pode aumentar para 3600 (1 hora).

### 2. Verificar Propagação DNS

Aguarde a propagação DNS (geralmente 5-15 minutos) e verifique:

```bash
# Verificar um domínio de cada vez
dig n8n.example.com

# Deve retornar seu IP público na seção ANSWER
```text

**Saída esperada:**
```text
;; ANSWER SECTION:
n8n.example.com.    300    IN    A    123.45.67.89
```text

**Ferramentas online para verificar DNS:**
- https://dnschecker.org/
- https://www.whatsmydns.net/

### 3. Geração Automática de Certificados SSL

O Caddy (reverse proxy) gera automaticamente certificados SSL via Let's Encrypt quando você acessa cada serviço pela primeira vez.

**Como funciona:**

1. Você acessa `https://n8n.example.com` no navegador
2. Caddy detecta que não há certificado SSL para esse domínio
3. Caddy se comunica com Let's Encrypt (via ACME HTTP-01 challenge)
4. Let's Encrypt verifica que você controla o domínio (porta 80 deve estar acessível)
5. Let's Encrypt emite o certificado SSL (válido por 90 dias)
6. Caddy instala o certificado e configura HTTPS automaticamente
7. Caddy renova o certificado automaticamente antes de expirar

**Tempo estimado:** 30-60 segundos no primeiro acesso a cada domínio.

**💡 Dica:** A geração de certificados acontece em segundo plano. Se você vê um erro SSL no primeiro acesso, aguarde 30 segundos e recarregue a página.

### 4. Primeiro Acesso aos Serviços

Acesse cada serviço para verificar que está funcionando e gerar certificados SSL:

| Serviço | URL | Primeiro Acesso |
|---------|-----|-----------------|
| **n8n** | `https://n8n.example.com` | Crie conta de administrador |
| **Chatwoot** | `https://chatwoot.example.com` | Crie conta de administrador |
| **Evolution API** | `https://evolution.example.com` | Use API key do .env |
| **Lowcoder** | `https://lowcoder.example.com` | Crie conta de administrador |
| **Directus** | `https://directus.example.com/admin` | Login: credenciais do .env |
| **FileFlows** | `https://fileflows.example.com` | Configure durante o primeiro acesso |
| **Duplicati** | `https://duplicati.example.com` | Configure senha de acesso |
| **SeaweedFS** | `https://seaweedfs.example.com` | Acesso via API (sem UI web) |

### 5. Configurar Contas de Administrador

**n8n:**
```text
1. Acesse https://n8n.example.com
2. Crie conta de administrador (primeiro usuário é automaticamente admin)
3. Email: seu-email@example.com
4. Senha: use uma senha forte (12+ caracteres)
5. Finalize a configuração inicial
```text

**Chatwoot:**
```text
1. Acesse https://chatwoot.example.com
2. Crie conta de administrador
3. Nome da conta: Seu nome ou empresa
4. Email: seu-email@example.com
5. Senha: use uma senha forte (12+ caracteres)
6. Complete o wizard de configuração
```text

**Directus:**
```text
1. Acesse https://directus.example.com/admin
2. Faça login com credenciais do .env:
   Email: valor de DIRECTUS_ADMIN_EMAIL
   Senha: valor de DIRECTUS_ADMIN_PASSWORD
3. Altere a senha padrão no seu perfil
```text

**💡 Dica:** Anote todas as credenciais em um gerenciador de senhas seguro (ex: 1Password, Bitwarden, LastPass).

### 6. Dicas de Segurança Pós-Instalação

**Proteja o arquivo .env:**
```bash
# Verifique permissões
ls -la .env
# Deve mostrar: -rw------- (600)

# Se não estiver correto, corrija:
chmod 600 .env
```text

**Faça backup das credenciais:**
```bash
# Copie o .env para local seguro (fora do servidor)
# Nunca envie por email ou chat!
# Use um gerenciador de senhas ou armazenamento criptografado
```text

**Configure autenticação de dois fatores (2FA):**
- n8n: Habilite 2FA nas configurações de usuário
- Chatwoot: Habilite 2FA nas configurações de perfil
- Directus: Habilite 2FA nas configurações de usuário

---

## Verificação da Instalação

Após a instalação e configuração DNS, execute estas verificações para garantir que tudo está funcionando corretamente.

### 1. Verificar Status dos Containers

```bash
docker compose ps
```text

**Todos os containers devem mostrar:**
- STATUS: `Up X minutes (healthy)` ou `Up X minutes`
- Nenhum container deve estar `Restarting` ou `Exited`

**Se algum container não está saudável:**
```bash
# Ver logs do container específico
docker compose logs nome-do-servico --tail 100

# Exemplo:
docker compose logs n8n --tail 100
```text

### 2. Verificar Volumes Docker

```bash
docker volume ls | grep borgstack
```text

**Saída esperada (15+ volumes):**
```text
local     borgstack_postgresql_data
local     borgstack_redis_data
local     borgstack_mongodb_data
local     borgstack_n8n_data
local     borgstack_chatwoot_storage
local     borgstack_directus_uploads
local     borgstack_fileflows_data
local     borgstack_duplicati_config
local     borgstack_duplicati_data
local     borgstack_seaweedfs_data
local     borgstack_lowcoder_data
...
```text

### 3. Verificar Redes Docker

```bash
docker network ls | grep borgstack
```text

**Saída esperada:**
```text
a1b2c3d4e5f6   borgstack_internal    bridge    local
g7h8i9j0k1l2   borgstack_external    bridge    local
```text

### 4. Executar Scripts de Verificação

O BorgStack inclui scripts de validação para cada componente:

```bash
# Verificar PostgreSQL
./tests/deployment/verify-postgresql.sh

# Verificar Redis
./tests/deployment/verify-redis.sh

# Verificar MongoDB
./tests/deployment/verify-mongodb.sh

# Verificar n8n
./tests/deployment/verify-n8n.sh

# Verificar Chatwoot
./tests/deployment/verify-chatwoot.sh

# Verificar Directus
./tests/deployment/verify-directus.sh

# Executar TODOS os testes de deploy
./tests/run-all-tests.sh
```text

**💡 Dica:** Se algum teste falhar, consulte a seção de [Solução de Problemas](#solução-de-problemas) abaixo.

### 5. Verificar Conectividade de Rede

**Verificar que Caddy está acessível:**
```bash
curl -I https://n8n.example.com
```text

**Saída esperada:**
```text
HTTP/2 200
server: Caddy
content-type: text/html; charset=utf-8
```text

**Verificar SSL:**
```bash
openssl s_client -connect n8n.example.com:443 -servername n8n.example.com < /dev/null
```text

**Deve mostrar:** `Verify return code: 0 (ok)` (certificado válido)

### 6. Checklist de Instalação Completa

Use este checklist para confirmar que tudo está funcionando:

- [ ] Todos os 14 containers estão `Up (healthy)`
- [ ] Todos os volumes `borgstack_*` foram criados
- [ ] Redes `borgstack_internal` e `borgstack_external` existem
- [ ] DNS configurado e propagado para todos os 8 domínios
- [ ] Certificados SSL gerados para todos os domínios (HTTPS funcionando)
- [ ] Acesso bem-sucedido ao n8n via navegador
- [ ] Acesso bem-sucedido ao Chatwoot via navegador
- [ ] Acesso bem-sucedido ao Directus via navegador
- [ ] Contas de administrador criadas em todos os serviços principais
- [ ] Arquivo `.env` salvo em local seguro com permissões 600
- [ ] Firewall UFW ativo com regras corretas (22/80/443)
- [ ] Scripts de verificação executados sem erros

**✅ Se todos os itens estão marcados, sua instalação está completa!**

---

## Solução de Problemas

### Problema: Bootstrap falha com "Insufficient RAM"

**Causa:** Servidor tem menos de 16GB de RAM.

**Solução:**
```bash
# Verificar RAM disponível
free -h

# Se você tem menos de 16GB, você tem 3 opções:
# 1. Fazer upgrade do servidor para 16GB+ (recomendado)
# 2. Reduzir serviços no docker-compose.yml (não recomendado)
# 3. Usar instalação manual e ajustar memory limits (avançado)
```text

### Problema: Docker installation fails

**Causa:** Repositório Docker não acessível ou versão antiga do Ubuntu.

**Solução:**
```bash
# Verificar versão do Ubuntu
cat /etc/os-release

# Deve mostrar VERSION_ID="24.04"
# Se não for 24.04, faça upgrade do sistema operacional

# Se for 24.04, verifique conectividade com o repositório Docker:
curl -I https://download.docker.com/linux/ubuntu/dists/noble/stable/
# Deve retornar HTTP/1.1 200 OK
```text

### Problema: Permission denied ao executar docker commands

**Causa:** Usuário não está no grupo docker.

**Solução:**
```bash
# Adicionar usuário ao grupo docker
sudo usermod -aG docker $USER

# Opção 1: Fazer logout e login novamente
exit
# Faça login via SSH novamente

# Opção 2: Atualizar grupo na sessão atual
newgrp docker

# Verificar que está funcionando
docker ps
# Não deve mais mostrar erro de permissão
```text

### Problema: Ports 80/443 already in use

**Causa:** Outro servidor web (Apache/Nginx) está rodando na porta 80 ou 443.

**Solução:**
```bash
# Verificar o que está usando as portas
sudo ss -tlnp | grep ':80\|:443'

# Se Apache está rodando:
sudo systemctl stop apache2
sudo systemctl disable apache2

# Se Nginx está rodando:
sudo systemctl stop nginx
sudo systemctl disable nginx

# Reiniciar os serviços do BorgStack
docker compose restart caddy
```text

### Problema: Container não está healthy após 5 minutos

**Causa:** Múltiplas possíveis - falta de recursos, erro de configuração, problema de rede.

**Diagnóstico:**
```bash
# Ver logs do container específico
docker compose logs nome-do-container --tail 100

# Exemplo para n8n:
docker compose logs n8n --tail 100

# Ver status detalhado de health
docker inspect --format='{{json .State.Health}}' borgstack-n8n-1 | jq

# Verificar uso de recursos
docker stats
```text

**Soluções comuns:**
- **Erro de banco de dados:** Verifique senhas no `.env`
- **Out of memory:** Aumente RAM ou reduza serviços
- **Connection refused:** Verifique redes Docker

### Problema: SSL certificate generation fails

**Causa:** DNS não propagado, portas 80/443 bloqueadas, ou domínio aponta para IP errado.

**Diagnóstico:**
```bash
# Verificar DNS
dig n8n.example.com

# Verificar que portas 80/443 estão acessíveis externamente
# (execute de outro servidor ou https://www.yougetsignal.com/tools/open-ports/)

# Ver logs do Caddy
docker compose logs caddy | grep "acme"
```text

**Soluções:**
```bash
# Se DNS não propagou, aguarde mais tempo (até 24h em casos raros)

# Se portas bloqueadas, verifique firewall do servidor e cloud provider
sudo ufw status
# E verifique security groups / firewall rules no painel da cloud

# Se domínio aponta para IP errado, corrija no DNS
```text

### Problema: Cannot access service web UI

**Causa:** DNS incorreto, Caddy não está rodando, ou serviço não está healthy.

**Diagnóstico:**
```bash
# 1. Verificar DNS
dig n8n.example.com
# Deve retornar seu IP público

# 2. Verificar Caddy está rodando
docker compose ps caddy

# 3. Verificar serviço está healthy
docker compose ps n8n

# 4. Tentar acessar localmente
curl -I http://localhost:5678  # porta do n8n
```text

**Solução:**
```bash
# Se Caddy não está rodando:
docker compose restart caddy

# Se serviço não está healthy:
docker compose logs nome-do-servico

# Se DNS não está resolvendo:
# Aguarde propagação ou verifique configuração DNS
```text

### Logs Importantes

Todos os logs relevantes estão disponíveis via Docker Compose:

```bash
# Ver logs de todos os serviços
docker compose logs --tail 100

# Ver logs de serviço específico
docker compose logs n8n --tail 100

# Seguir logs em tempo real
docker compose logs -f n8n

# Ver logs de múltiplos serviços
docker compose logs n8n chatwoot directus --tail 50

# Filtrar logs por padrão
docker compose logs n8n | grep ERROR
```text

**Log do bootstrap:**
```bash
# O script de bootstrap salva log completo em:
cat /tmp/borgstack-bootstrap.log
```text

### Obter Ajuda

Se você não conseguiu resolver o problema:

1. **Consulte a documentação detalhada:**
   - Ver `docs/05-solucao-de-problemas.md` para troubleshooting avançado
   - Ver `docs/03-services/` para guias específicos de cada serviço

2. **Execute testes de integração:**
   ```bash
   ./tests/run-all-tests.sh
   ```

3. **Colete informações de diagnóstico:**
   ```bash
   # Salvar informações de sistema
   docker compose ps > diagnostico.txt
   docker compose logs --tail 200 >> diagnostico.txt
   docker stats --no-stream >> diagnostico.txt
   ```

4. **Abra uma issue no GitHub:**
   - Inclua o arquivo `diagnostico.txt`
   - Descreva o problema e os passos que você tentou
   - Inclua versão do Ubuntu, RAM, CPU

---

## Próximos Passos

Após a instalação bem-sucedida:

1. **Configure os serviços:** Ver `docs/02-configuracao.md`
2. **Configure integrações:** Ver `docs/04-integrations/`
3. **Configure backups:** Ver `docs/03-services/duplicati.md`
4. **Otimize performance:** Ver `docs/08-desempenho.md`
5. **Revise segurança:** Ver `docs/07-seguranca.md`

**🎉 Parabéns! Seu BorgStack está instalado e funcionando!**

---

## Navegação

- **Anterior:** [README](../README.md)
- **Próximo:** [Configuração do Sistema](02-configuracao.md)
- **Índice:** [Documentação Completa](README.md)

---

**Última atualização:** 2025-10-08
**Versão do guia:** 1.0
**Compatível com:** BorgStack v4+, Ubuntu 24.04 LTS
