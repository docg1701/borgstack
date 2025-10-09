# Solução de Problemas - BorgStack

## Visão Geral

Este guia apresenta soluções para os problemas mais comuns encontrados no BorgStack. Siga as seções na ordem apresentada para diagnosticar e resolver issues rapidamente.

### Fluxo de Diagnóstico

```mermaid
flowchart TD
    A[Problema Identificado] --> B{Sistema<br/>Iniciado?}
    B -->|Não| C[Verificação<br/>de Instalação]
    B -->|Sim| D{Containers<br/>Rodando?}
    D -->|Não| E[Problemas de<br/>Containers]
    D -->|Sim| F{Serviços<br/>Acessíveis?}
    F -->|Não| G[Problemas<br/>de Rede]
    F -->|Sim| H{Banco de<br/>Dados OK?}
    H -->|Não| I[Problemas de<br/>Database]
    H -->|Sim| J{Integração<br/>Funcionando?}
    J -->|Não| K[Problemas de<br/>Integração]
    J -->|Sim| L[Performance/<br/>Otimização]
```

---

## 1. Verificação Rápida do Sistema

### 1.1. Status Geral

```bash
# Verificar todos os containers
docker compose ps

# Resultado esperado: 14 containers com status "Up" e "healthy"
```

**Interpretação dos Status**:
- `Up (healthy)` ✅ - Container rodando e saudável
- `Up` ⚠️ - Container rodando mas sem health check
- `Restarting` ⚠️ - Container reiniciando constantemente (problema)
- `Exit 0` ℹ️ - Container finalizado com sucesso
- `Exit 1` ❌ - Container finalizado com erro

### 1.2. Recursos do Sistema

```bash
# Verificar uso de recursos (CPU, RAM, I/O)
docker stats --no-stream

# Verificar disco
df -h /

# Verificar memória disponível
free -h
```

**Limites Críticos**:
- RAM: > 90% uso = ⚠️ Risco de OOM (Out of Memory)
- Disco: > 85% uso = ⚠️ Espaço insuficiente
- CPU: > 95% sustentado = ⚠️ Gargalo de processamento

### 1.3. Logs Rápidos

```bash
# Ver últimas 50 linhas de cada serviço
docker compose logs --tail=50

# Filtrar apenas erros
docker compose logs | grep -i error

# Monitorar em tempo real
docker compose logs -f
```

---

## 2. Problemas Comuns de Instalação

### Problema 2.1: Bootstrap Script Falha com "Insufficient RAM"

**Sintomas**:
```bash
$ ./scripts/bootstrap.sh
ERROR: Insufficient RAM. Found: 8GB, Required: 16GB minimum
```

**Causa**: Servidor com menos de 16GB de RAM.

**Diagnóstico**:
```bash
# Verificar RAM total
free -h | grep Mem:

# Exemplo de saída:
# Mem:           7.8Gi       2.1Gi       1.2Gi       0.1Gi       4.5Gi       5.4Gi
#                ↑ Total disponível
```

**Soluções**:

**Opção 1: Upgrade de Hardware** (Recomendado)
```bash
# Adicionar mais RAM ao servidor
# Mínimo: 16GB (funcional)
# Recomendado: 36GB (produção)
```

**Opção 2: Reduzir Serviços**
```bash
# Editar docker-compose.yml e comentar serviços não essenciais
# Exemplo: Comentar Lowcoder, FileFlows, Duplicati

nano docker-compose.yml

# Comentar seções:
  # lowcoder-api-service:
  #   ...
  # lowcoder-node-service:
  #   ...
  # lowcoder-frontend:
  #   ...

# Reiniciar
docker compose up -d
```

**Opção 3: Configurar Swap** (Temporário, não ideal)
```bash
# Criar 8GB de swap (use com cautela, degrada performance)
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Tornar permanente
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

---

### Problema 2.2: "Docker installation fails on Ubuntu 22.04"

**Sintomas**:
```bash
ERROR: Wrong OS detected. Ubuntu 24.04 LTS required.
Current: Ubuntu 22.04 LTS
```

**Causa**: Bootstrap script requer Ubuntu 24.04 LTS.

**Soluções**:

**Opção 1: Upgrade para Ubuntu 24.04** (Recomendado)
```bash
# Backup completo primeiro!

# Atualizar sistema
sudo apt update && sudo apt upgrade -y

# Executar upgrade
sudo do-release-upgrade

# Verificar versão
lsb_release -a
```

**Opção 2: Instalação Manual no Ubuntu 22.04**
```bash
# AVISO: Não suportado oficialmente, use por sua conta e risco

# Instalar Docker manualmente
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Adicionar usuário ao grupo docker
sudo usermod -aG docker $USER
newgrp docker

# Instalar Docker Compose
sudo apt update
sudo apt install docker-compose-plugin -y

# Verificar
docker --version
docker compose version

# Prosseguir com deploy manual (pular bootstrap.sh)
```

---

### Problema 2.3: "Permission denied when running docker commands"

**Sintomas**:
```bash
$ docker ps
permission denied while trying to connect to the Docker daemon socket
```

**Causa**: Usuário não está no grupo `docker`.

**Solução**:
```bash
# Adicionar usuário atual ao grupo docker
sudo usermod -aG docker $USER

# Aplicar mudança de grupo (escolha uma opção):

# Opção 1: Fazer logout e login novamente (recomendado)
exit

# Opção 2: Atualizar grupo na sessão atual
newgrp docker

# Opção 3: Rebootar servidor
sudo reboot

# Verificar
groups
# Deve conter: ... docker ...

# Testar
docker ps
```

---

### Problema 2.4: "Ports 80/443 already in use"

**Sintomas**:
```bash
Error starting userland proxy: listen tcp4 0.0.0.0:443: bind: address already in use
```

**Causa**: Outro serviço (Apache, Nginx) usando portas 80/443.

**Diagnóstico**:
```bash
# Identificar processo usando porta 443
sudo lsof -i :443

# Exemplo de saída:
# COMMAND   PID     USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
# apache2  1234     root    4u  IPv6  12345      0t0  TCP *:https (LISTEN)

# Ou usar ss
sudo ss -tlnp | grep :443
```

**Soluções**:

**Opção 1: Parar Serviço Conflitante** (Recomendado)
```bash
# Parar Apache
sudo systemctl stop apache2
sudo systemctl disable apache2

# Parar Nginx
sudo systemctl stop nginx
sudo systemctl disable nginx

# Reiniciar BorgStack
docker compose down
docker compose up -d
```

**Opção 2: Mudar Portas do Caddy**
```bash
# Editar docker-compose.yml
nano docker-compose.yml

# Procurar seção do caddy:
  caddy:
    ports:
      - "8080:80"    # HTTP agora em 8080
      - "8443:443"   # HTTPS agora em 8443

# Atualizar
docker compose up -d caddy

# Acessar via: https://seudominio.com.br:8443
```

---

## 3. Problemas de Containers

### Problema 3.1: Container não inicia (status: Restarting)

**Sintomas**:
```bash
$ docker compose ps
NAME                 STATUS
chatwoot             Restarting (1) 5 seconds ago
```

**Diagnóstico**:
```bash
# Ver logs do container
docker compose logs chatwoot --tail 100

# Ver status de saúde
docker inspect chatwoot --format='{{json .State.Health}}' | jq

# Ver últimas tentativas de restart
docker events --filter 'container=chatwoot' --since 10m
```

**Causas Comuns e Soluções**:

#### Causa 1: Variável de Ambiente Faltando

**Erro no log**:
```
ERROR: Missing required environment variable: POSTGRES_PASSWORD
```

**Solução**:
```bash
# Verificar se .env existe
ls -la .env

# Verificar conteúdo
grep POSTGRES_PASSWORD .env

# Se faltando, regenerar
./scripts/generate-env.sh

# Recriar container
docker compose up -d --force-recreate chatwoot
```

#### Causa 2: Dependência Não Saudável

**Erro no log**:
```
could not connect to server: Connection refused
Is the server running on host "postgresql" (172.x.x.x) and accepting connections?
```

**Solução**:
```bash
# Verificar se PostgreSQL está healthy
docker compose ps postgresql

# Se não healthy, verificar logs
docker compose logs postgresql --tail 50

# Reiniciar dependência
docker compose restart postgresql

# Aguardar healthy
docker compose ps postgresql
# STATUS deve mostrar: Up (healthy)

# Reiniciar container dependente
docker compose restart chatwoot
```

#### Causa 3: Porta Conflitante

**Erro no log**:
```
Error starting userland proxy: listen tcp4 0.0.0.0:5432: bind: address already in use
```

**Solução**:
```bash
# Identificar conflito
sudo lsof -i :5432

# Se PostgreSQL externo, parar ou mudar porta do container
nano docker-compose.yml

# Comentar mapeamento de porta (banco de dados não precisa estar exposto)
  postgresql:
    # ports:
    #   - "5432:5432"  # Comentado - acesso apenas interno

docker compose up -d postgresql
```

---

### Problema 3.2: Container unhealthy após startup

**Sintomas**:
```bash
$ docker compose ps n8n
NAME   STATUS
n8n    Up 2 minutes (unhealthy)
```

**Diagnóstico**:
```bash
# Ver configuração de health check
docker inspect n8n --format='{{json .State.Health}}' | jq

# Ver últimas 5 tentativas
docker inspect n8n --format='{{range .State.Health.Log}}{{.Output}}{{end}}'

# Testar health check manualmente
docker compose exec n8n curl -f http://localhost:5678/healthz || echo "Health check failed"
```

**Causas e Soluções**:

#### Causa 1: Serviço Demora para Iniciar

**Health check falha nos primeiros 30s, mas serviço ainda está iniciando**.

**Solução**:
```bash
# Aumentar intervalo do health check
nano docker-compose.yml

# Editar seção do serviço:
  n8n:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5678/healthz"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s  # Aumentar de 30s para 60s

# Aplicar
docker compose up -d n8n
```

#### Causa 2: Health Check URL Incorreta

**Solução**:
```bash
# Testar diferentes endpoints
docker compose exec n8n curl http://localhost:5678/
docker compose exec n8n curl http://localhost:5678/health
docker compose exec n8n curl http://localhost:5678/healthz

# Atualizar docker-compose.yml com endpoint correto
```

#### Causa 3: Processo Principal Travado

**Solução**:
```bash
# Ver processos dentro do container
docker compose exec n8n ps aux

# Se processo principal travado, restart forçado
docker compose restart n8n

# Se persistir, recriar
docker compose up -d --force-recreate n8n
```

---

### Problema 3.3: "Out of memory" errors

**Sintomas**:
```bash
# No log do container
OOMKilled
Out of memory: Killed process 1234

# Ou no sistema
docker compose logs | grep "Out of memory"
```

**Diagnóstico**:
```bash
# Verificar memória do sistema
free -h

# Verificar uso por container
docker stats --no-stream

# Verificar configuração de limites
docker compose config | grep -A 5 "mem_limit"

# Ver eventos OOM
dmesg | grep -i "out of memory"
```

**Soluções**:

#### Solução 1: Aumentar RAM do Servidor
```bash
# Upgrade de hardware (solução ideal)
# Recomendado: 36GB RAM para todos os serviços
```

#### Solução 2: Configurar Limites de Memória
```bash
# Editar docker-compose.yml
nano docker-compose.yml

# Adicionar limites aos serviços mais pesados:
  n8n:
    mem_limit: 2g
    mem_reservation: 1g

  chatwoot:
    mem_limit: 2g
    mem_reservation: 1g

  postgresql:
    mem_limit: 4g
    mem_reservation: 2g

# Aplicar
docker compose up -d
```

#### Solução 3: Reduzir Workers/Processos
```bash
# Para Chatwoot (Rails)
nano .env

# Adicionar/editar:
RAILS_MAX_THREADS=5  # Reduzir de 10
WEB_CONCURRENCY=2    # Reduzir de 4

# Para n8n
N8N_EXECUTIONS_PROCESS=main
N8N_CONCURRENCY_PRODUCTION_LIMIT=5  # Reduzir de 10

# Reiniciar
docker compose restart chatwoot n8n
```

#### Solução 4: Configurar Swap (Emergência)
```bash
# Criar 8GB swap
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Permanente
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Ajustar swappiness
sudo sysctl vm.swappiness=10
```

---

### Problema 3.4: "Disk space exhausted"

**Sintomas**:
```bash
$ docker compose logs
no space left on device

$ df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1       200G  195G  5.0G  98% /
```

**Diagnóstico**:
```bash
# Verificar uso geral
df -h

# Verificar uso do Docker
docker system df

# Resultado típico:
# TYPE           TOTAL   ACTIVE   SIZE      RECLAIMABLE
# Images         42      14       15.5GB    8.2GB (53%)
# Containers     14      14       2.1GB     0B (0%)
# Local Volumes  18      18       45GB      0B (0%)
# Build Cache    127     0        3.2GB     3.2GB

# Ver maiores diretórios
du -h --max-depth=1 / 2>/dev/null | sort -hr | head -20
```

**Soluções**:

#### Solução 1: Limpar Dados do Docker
```bash
# AVISO: Vai deletar imagens, containers e volumes não usados!

# Limpar apenas itens não usados (seguro)
docker system prune -a

# Limpar incluindo volumes (CUIDADO!)
docker system prune -a --volumes

# Resultado esperado:
# Deleted Images: 28
# Deleted Containers: 5
# Total reclaimed space: 8.5GB
```

#### Solução 2: Limpar Logs
```bash
# Logs do Docker podem crescer indefinidamente

# Ver tamanho dos logs
sudo du -h /var/lib/docker/containers/*/

# Limpar logs manualmente
sudo truncate -s 0 /var/lib/docker/containers/**/*-json.log

# Ou configurar rotação (permanente)
sudo nano /etc/docker/daemon.json

# Adicionar:
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  }
}

# Reiniciar Docker
sudo systemctl restart docker
docker compose up -d
```

#### Solução 3: Mover Dados para Volume Maior
```bash
# Parar tudo
docker compose down

# Mover /var/lib/docker para outro disco
sudo systemctl stop docker
sudo mv /var/lib/docker /mnt/larger-disk/docker
sudo ln -s /mnt/larger-disk/docker /var/lib/docker
sudo systemctl start docker

# Verificar
docker info | grep "Docker Root Dir"

# Reiniciar serviços
docker compose up -d
```

---

## 4. Problemas de Rede

### Problema 4.1: "SSL certificate generation fails"

**Sintomas**:
```bash
$ docker compose logs caddy
unable to get certificate: acme: error: 403 - urn:ietf:params:acme:error:unauthorized
```

**Causa**: DNS não propagado, porta 80/443 bloqueada, ou domínio apontando para IP errado.

**Diagnóstico**:
```bash
# 1. Verificar DNS
dig seudominio.com.br +short
# Deve retornar o IP público do servidor

# 2. Verificar se portas estão abertas (de fora)
nc -zv seudominio.com.br 80
nc -zv seudominio.com.br 443

# 3. Verificar Caddy
docker compose ps caddy
docker compose logs caddy --tail 50

# 4. Testar acesso HTTP local
curl -v http://localhost

# 5. Verificar firewall
sudo ufw status
```

**Soluções**:

#### Solução 1: Aguardar Propagação de DNS
```bash
# DNS pode levar até 24-48h para propagar

# Verificar propagação global
# https://www.whatsmydns.net/#A/seudominio.com.br

# Enquanto aguarda, use staging do Let's Encrypt (certificado inválido, mas testa)
nano docker-compose.yml

# Adicionar ao caddy:
  caddy:
    environment:
      - ACME_AGREE=true
      - ACME_CA=https://acme-staging-v02.api.letsencrypt.org/directory

docker compose up -d caddy
```

#### Solução 2: Abrir Portas no Firewall
```bash
# Verificar UFW
sudo ufw status

# Se bloqueado, abrir
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload

# Verificar novamente
sudo ufw status | grep -E "80|443"

# Testar de fora
curl -I http://seudominio.com.br
```

#### Solução 3: Verificar IP do Domínio
```bash
# Obter IP público do servidor
curl ifconfig.me

# Comparar com DNS
dig seudominio.com.br +short

# Se diferente, atualizar registro A no provedor de DNS
# Exemplo (Cloudflare):
# 1. Acessar painel Cloudflare
# 2. DNS > Manage DNS
# 3. Editar registro A
# 4. Apontar para IP correto
# 5. Desabilitar proxy (nuvem cinza, não laranja)
```

---

### Problema 4.2: "Service cannot reach PostgreSQL"

**Sintomas**:
```bash
# No log do serviço (ex: n8n)
Error: connect ECONNREFUSED 172.18.0.5:5432
could not connect to server: Connection refused
```

**Diagnóstico**:
```bash
# 1. Verificar se PostgreSQL está rodando
docker compose ps postgresql

# 2. Testar conexão de dentro do container
docker compose exec n8n ping -c 3 postgresql

# 3. Testar porta PostgreSQL
docker compose exec n8n nc -zv postgresql 5432

# 4. Verificar redes
docker network ls | grep borgstack
docker network inspect borgstack_internal

# 5. Verificar se serviço está na rede correta
docker inspect n8n --format='{{json .NetworkSettings.Networks}}' | jq
```

**Soluções**:

#### Solução 1: Serviço Não na Rede Correta
```bash
# Verificar docker-compose.yml
nano docker-compose.yml

# Garantir que serviço esteja em borgstack_internal:
  n8n:
    networks:
      - borgstack_internal  # DEVE estar presente

# Recriar container
docker compose up -d --force-recreate n8n
```

#### Solução 2: PostgreSQL Não Aceitando Conexões
```bash
# Ver logs do PostgreSQL
docker compose logs postgresql --tail 100

# Procurar por:
# - "database system is ready to accept connections" ✅ OK
# - "FATAL: password authentication failed" ❌ Problema de auth
# - "too many clients already" ❌ Pool esgotado

# Se não aceita conexões, restart
docker compose restart postgresql

# Aguardar healthy
watch docker compose ps postgresql
```

#### Solução 3: Credenciais Incorretas
```bash
# Verificar .env
cat .env | grep POSTGRES

# Verificar se container usa mesmas credenciais
docker compose config | grep POSTGRES

# Se divergentes, corrigir .env e recriar
docker compose down
docker compose up -d
```

---

### Problema 4.3: "Cannot access service web UI"

**Sintomas**:
```bash
# No navegador:
# ERR_CONNECTION_REFUSED
# ou
# 502 Bad Gateway
```

**Diagnóstico**:
```bash
# 1. Verificar se Caddy está rodando
docker compose ps caddy

# 2. Testar localhost
curl -I http://localhost

# 3. Verificar logs do Caddy
docker compose logs caddy --tail 50

# 4. Verificar se serviço backend está healthy
docker compose ps n8n chatwoot directus

# 5. Testar acesso direto ao backend (bypass Caddy)
curl -I http://localhost:5678  # n8n
```

**Soluções**:

#### Solução 1: Caddy Não Rodando
```bash
# Reiniciar Caddy
docker compose restart caddy

# Se não sobe, verificar config
docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile

# Ver erro
docker compose logs caddy

# Corrigir Caddyfile e recriar
docker compose up -d --force-recreate caddy
```

#### Solução 2: Backend Unhealthy
```bash
# Identificar serviço com problema
docker compose ps

# Reiniciar serviço específico
docker compose restart n8n

# Verificar logs
docker compose logs n8n --tail 100
```

#### Solução 3: DNS Não Resolvendo
```bash
# Testar resolução local
nslookup n8n.seudominio.com.br

# Se não resolve, adicionar em /etc/hosts temporariamente
sudo nano /etc/hosts

# Adicionar:
<IP_DO_SERVIDOR> n8n.seudominio.com.br
<IP_DO_SERVIDOR> chatwoot.seudominio.com.br

# Testar novamente
curl -I https://n8n.seudominio.com.br
```

---

## 5. Problemas de Banco de Dados

### Problema 5.1: "PostgreSQL connection pool exhausted"

**Sintomas**:
```bash
# No log dos serviços
FATAL: sorry, too many clients already
Error: Connection pool timeout
```

**Diagnóstico**:
```bash
# Ver conexões ativas
docker compose exec postgresql psql -U postgres -c "
  SELECT count(*) as connections,
         state,
         application_name
  FROM pg_stat_activity
  GROUP BY state, application_name
  ORDER BY connections DESC;
"

# Ver configuração max_connections
docker compose exec postgresql psql -U postgres -c "SHOW max_connections;"

# Resultado típico: max_connections = 100
```

**Soluções**:

#### Solução 1: Aumentar max_connections
```bash
# Editar config do PostgreSQL
nano config/postgresql/postgresql.conf

# Encontrar e editar:
max_connections = 200  # Aumentar de 100 para 200

# Reiniciar PostgreSQL
docker compose restart postgresql

# Verificar
docker compose exec postgresql psql -U postgres -c "SHOW max_connections;"
```

#### Solução 2: Configurar Connection Pooling
```bash
# Adicionar PgBouncer (futuro)
# Ou configurar pool nos serviços

# Exemplo para Chatwoot (.env):
DB_POOL=10  # Reduzir de 25

# Exemplo para n8n:
DB_POSTGRESDB_POOL_SIZE=10  # Reduzir de 20

# Reiniciar serviços
docker compose restart chatwoot n8n
```

#### Solução 3: Identificar e Matar Conexões Idle
```bash
# Ver conexões idle há mais de 1 hora
docker compose exec postgresql psql -U postgres -c "
  SELECT pid,
         usename,
         application_name,
         state,
         now() - state_change as idle_time
  FROM pg_stat_activity
  WHERE state = 'idle'
    AND state_change < now() - interval '1 hour';
"

# Matar conexões específicas (use com cuidado)
docker compose exec postgresql psql -U postgres -c "
  SELECT pg_terminate_backend(pid)
  FROM pg_stat_activity
  WHERE state = 'idle'
    AND state_change < now() - interval '1 hour';
"
```

---

### Problema 5.2: "Redis out of memory"

**Sintomas**:
```bash
# No log dos serviços
OOM command not allowed when used memory > 'maxmemory'
MISCONF Redis is configured to save RDB snapshots, but it's currently not able to persist on disk
```

**Diagnóstico**:
```bash
# Verificar uso de memória
docker compose exec redis redis-cli INFO memory

# Resultado importante:
# used_memory_human:812.42M
# maxmemory_human:1.00G
# maxmemory_policy:allkeys-lru

# Ver configuração
docker compose exec redis redis-cli CONFIG GET maxmemory
docker compose exec redis redis-cli CONFIG GET maxmemory-policy
```

**Soluções**:

#### Solução 1: Aumentar maxmemory
```bash
# Editar config
nano config/redis/redis.conf

# Encontrar e editar:
maxmemory 2gb  # Aumentar de 1gb para 2gb

# Reiniciar Redis
docker compose restart redis

# Verificar
docker compose exec redis redis-cli CONFIG GET maxmemory
```

#### Solução 2: Configurar Política de Eviction
```bash
# Configurar para remover chaves menos usadas
docker compose exec redis redis-cli CONFIG SET maxmemory-policy allkeys-lru

# Outras opções:
# - volatile-lru: Remove LRU apenas de chaves com TTL
# - allkeys-lru: Remove LRU de todas as chaves (recomendado)
# - volatile-lfu: Remove LFU de chaves com TTL
# - allkeys-lfu: Remove LFU de todas as chaves

# Tornar permanente
nano config/redis/redis.conf

# Adicionar:
maxmemory-policy allkeys-lru

# Reiniciar
docker compose restart redis
```

#### Solução 3: Limpar Cache Manualmente
```bash
# AVISO: Vai limpar todo o cache!

# Ver chaves por banco
for i in {0..3}; do
  echo "Database $i:"
  docker compose exec redis redis-cli -n $i DBSIZE
done

# Limpar banco específico (exemplo: banco 1 - Chatwoot)
docker compose exec redis redis-cli -n 1 FLUSHDB

# Ou limpar tudo (CUIDADO!)
docker compose exec redis redis-cli FLUSHALL
```

---

### Problema 5.3: "MongoDB authentication failed"

**Sintomas**:
```bash
# No log do Lowcoder
MongoServerError: Authentication failed
Error: Could not connect to MongoDB
```

**Diagnóstico**:
```bash
# Verificar credenciais no .env
cat .env | grep MONGO

# Testar conexão
docker compose exec mongodb mongosh \
  -u lowcoder_user \
  -p senha_lowcoder \
  --authenticationDatabase admin \
  lowcoder

# Ver usuários
docker compose exec mongodb mongosh admin -u root -p senha_root --eval "db.getUsers()"
```

**Soluções**:

#### Solução 1: Recrear Usuário
```bash
# Conectar como root
docker compose exec mongodb mongosh -u root -p <MONGO_ROOT_PASSWORD>

# Selecionar banco
use admin

# Dropar usuário existente
db.dropUser("lowcoder_user")

# Recriar
db.createUser({
  user: "lowcoder_user",
  pwd: "senha_lowcoder",
  roles: [
    { role: "readWrite", db: "lowcoder" }
  ]
})

# Sair e testar
exit

# Testar nova conexão
docker compose exec mongodb mongosh -u lowcoder_user -p senha_lowcoder --authenticationDatabase admin lowcoder
```

#### Solução 2: Corrigir String de Conexão
```bash
# Verificar formato da URL no .env
nano .env

# Formato correto:
LOWCODER_MONGODB_URL=mongodb://lowcoder_user:senha_lowcoder@mongodb:27017/lowcoder?authSource=admin

# Componentes:
# - mongodb://              (protocolo)
# - lowcoder_user           (usuário)
# - :senha_lowcoder         (senha)
# - @mongodb                (host)
# - :27017                  (porta)
# - /lowcoder               (database)
# - ?authSource=admin       (auth database)

# Reiniciar Lowcoder
docker compose restart lowcoder-api-service lowcoder-node-service
```

---

## 6. Problemas de Integração

### Problema 6.1: "n8n webhook not receiving messages"

**Sintomas**:
- Mensagens enviadas no WhatsApp não aparecem no Chatwoot
- Logs do n8n não mostram chamadas ao webhook

**Diagnóstico**:
```bash
# 1. Verificar se webhook está registrado na Evolution API
curl -X GET https://evolution.seudominio.com.br/webhook/find/atendimento-principal \
  -H "apikey: SUA_API_KEY"

# 2. Testar webhook manualmente
curl -X POST https://n8n.seudominio.com.br/webhook/whatsapp-incoming \
  -H "Content-Type: application/json" \
  -d '{
    "event": "messages.upsert",
    "instance": "atendimento-principal",
    "data": {
      "key": {"remoteJid": "5511999998888@s.whatsapp.net", "fromMe": false},
      "message": {"conversation": "Teste"},
      "pushName": "Usuario Teste"
    }
  }'

# 3. Ver logs do n8n
docker compose logs n8n | grep "whatsapp-incoming"

# 4. Verificar workflow ativo
docker compose exec n8n n8n workflow:list
```

**Soluções**:

#### Solução 1: Re-registrar Webhook
```bash
# Deletar webhook antigo
curl -X DELETE https://evolution.seudominio.com.br/webhook/atendimento-principal \
  -H "apikey: SUA_API_KEY"

# Criar novo
curl -X POST https://evolution.seudominio.com.br/webhook/set/atendimento-principal \
  -H "apikey: SUA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "enabled": true,
    "url": "https://n8n.seudominio.com.br/webhook/whatsapp-incoming",
    "webhookByEvents": false,
    "events": ["MESSAGES_UPSERT"]
  }'
```

#### Solução 2: Ativar Workflow
```bash
# Listar workflows
docker compose exec n8n n8n workflow:list

# Ativar workflow específico
docker compose exec n8n n8n workflow:activate --id=1

# Ou via UI:
# 1. Acessar n8n
# 2. Workflows > WhatsApp to Chatwoot
# 3. Clicar em "Active" (toggle no canto superior direito)
```

#### Solução 3: Verificar DNS/SSL
```bash
# Testar acesso externo ao n8n
curl -I https://n8n.seudominio.com.br/webhook-test/test

# Se erro SSL, verificar certificado
openssl s_client -connect n8n.seudominio.com.br:443

# Ver logs do Caddy
docker compose logs caddy | grep n8n
```

---

### Problema 6.2: "Chatwoot não criando contatos"

**Sintomas**:
- Workflow executa sem erro
- Mas contatos não aparecem no Chatwoot

**Diagnóstico**:
```bash
# Ver execuções do n8n
docker compose logs n8n | grep "Chatwoot" | tail -50

# Testar API do Chatwoot manualmente
curl -X POST https://chatwoot.seudominio.com.br/api/v1/accounts/1/contacts \
  -H "api_access_token: SEU_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "inbox_id": 1,
    "name": "Teste Manual",
    "phone_number": "+5511999998888"
  }'

# Ver logs do Chatwoot
docker compose logs chatwoot | grep "contacts"
```

**Soluções**:

#### Solução 1: Token Inválido
```bash
# Regenerar token
# 1. Acessar Chatwoot
# 2. Settings > Profile Settings
# 3. Access Token > Copy

# Atualizar .env
nano .env

# Editar:
CHATWOOT_API_TOKEN=novo_token_aqui

# Reiniciar n8n para carregar novo token
docker compose restart n8n
```

#### Solução 2: Formato de Telefone Incorreto
```bash
# Chatwoot espera formato: +5511999998888 (com + e código do país)
# Evolution API retorna: 5511999998888 (sem +)

# Adicionar nó no workflow n8n para normalizar:
# Function Node:
const phone = $json.phone_number;
const normalized = phone.startsWith('+') ? phone : `+${phone}`;

return {
  json: {
    ...$json,
    phone_number: normalized
  }
};
```

---

## 7. Comandos Úteis de Diagnóstico

### 7.1. Docker e Containers

```bash
# Status completo
docker compose ps -a

# Logs de todos os serviços
docker compose logs --tail=100

# Logs de serviço específico
docker compose logs -f n8n

# Entrar no container
docker compose exec n8n sh

# Ver processos dentro do container
docker compose exec n8n ps aux

# Ver variáveis de ambiente
docker compose exec n8n env

# Reiniciar serviço
docker compose restart n8n

# Recriar container
docker compose up -d --force-recreate n8n

# Ver uso de recursos
docker stats --no-stream

# Inspecionar container
docker inspect n8n --format='{{json .State}}' | jq

# Ver redes
docker network ls
docker network inspect borgstack_internal
```

### 7.2. PostgreSQL

```bash
# Conectar ao banco
docker compose exec postgresql psql -U postgres

# Listar bancos
docker compose exec postgresql psql -U postgres -c "\l"

# Ver conexões ativas
docker compose exec postgresql psql -U postgres -c "
  SELECT datname, count(*)
  FROM pg_stat_activity
  GROUP BY datname;
"

# Ver queries lentas
docker compose exec postgresql psql -U postgres -c "
  SELECT pid, now() - pg_stat_activity.query_start AS duration, query
  FROM pg_stat_activity
  WHERE state = 'active'
  ORDER BY duration DESC;
"

# Verificar tamanho dos bancos
docker compose exec postgresql psql -U postgres -c "
  SELECT datname, pg_size_pretty(pg_database_size(datname))
  FROM pg_database
  ORDER BY pg_database_size(datname) DESC;
"

# Vacuum (manutenção)
docker compose exec postgresql psql -U postgres -d chatwoot_db -c "VACUUM ANALYZE;"
```

### 7.3. Redis

```bash
# Conectar ao Redis
docker compose exec redis redis-cli -a senha_redis

# Ver informações
docker compose exec redis redis-cli -a senha_redis INFO

# Ver memória
docker compose exec redis redis-cli -a senha_redis INFO memory

# Ver estatísticas
docker compose exec redis redis-cli -a senha_redis INFO stats

# Listar chaves (cuidado em produção!)
docker compose exec redis redis-cli -a senha_redis KEYS '*'

# Ver tamanho de cada banco
for i in {0..3}; do
  echo "Database $i:"
  docker compose exec redis redis-cli -a senha_redis -n $i DBSIZE
done

# Monitorar comandos em tempo real
docker compose exec redis redis-cli -a senha_redis MONITOR
```

### 7.4. Sistema

```bash
# Uso de disco
df -h

# Maiores diretórios
du -h --max-depth=1 / | sort -hr | head -20

# Memória
free -h

# CPU
top
htop

# Processos do Docker
ps aux | grep docker

# Logs do sistema
sudo journalctl -u docker -n 100

# Verificar portas abertas
sudo ss -tlnp

# Testar conectividade
ping google.com
curl ifconfig.me  # IP público
```

---

## 8. Recuperação de Desastres

### 8.1. Backup Manual de Emergência

```bash
# 1. Parar serviços (evita inconsistência)
docker compose stop

# 2. Backup de volumes
sudo tar -czf /tmp/borgstack-volumes-$(date +%Y%m%d).tar.gz \
  -C /var/lib/docker/volumes/ \
  $(docker volume ls -q | grep borgstack)

# 3. Backup do .env
cp .env /tmp/borgstack-env-$(date +%Y%m%d).backup

# 4. Backup do docker-compose.yml
cp docker-compose.yml /tmp/borgstack-compose-$(date +%Y%m%d).backup

# 5. Reiniciar
docker compose up -d
```

### 8.2. Restaurar de Backup

```bash
# 1. Parar tudo
docker compose down

# 2. Restaurar volumes
cd /var/lib/docker/volumes/
sudo tar -xzf /tmp/borgstack-volumes-YYYYMMDD.tar.gz

# 3. Restaurar configs
cp /tmp/borgstack-env-YYYYMMDD.backup .env
cp /tmp/borgstack-compose-YYYYMMDD.backup docker-compose.yml

# 4. Reiniciar
docker compose up -d

# 5. Verificar
docker compose ps
```

### 8.3. Reset Completo (Última Opção)

```bash
# ⚠️ AVISO: Vai DELETAR TODOS OS DADOS! ⚠️

# 1. Parar e remover tudo
docker compose down -v

# 2. Remover volumes
docker volume ls | grep borgstack | awk '{print $2}' | xargs docker volume rm

# 3. Limpar Docker
docker system prune -a --volumes

# 4. Remover configs locais
rm -rf config/

# 5. Reinstalar do zero
./scripts/bootstrap.sh

# Ou manualmente:
./scripts/generate-env.sh
docker compose up -d
```

### 8.4. Recuperar Banco de Dados Corrompido

#### PostgreSQL

```bash
# 1. Parar serviços dependentes
docker compose stop chatwoot n8n directus evolution

# 2. Parar PostgreSQL
docker compose stop postgresql

# 3. Tentar reparar (se iniciável)
docker compose start postgresql
docker compose exec postgresql pg_resetwal /var/lib/postgresql/data

# 4. Se não reparar, restaurar de backup
# Assumindo backup em /backups/chatwoot_db_20251007.dump
docker compose exec -T postgresql pg_restore \
  -U postgres \
  -d chatwoot_db \
  -v \
  < /backups/chatwoot_db_20251007.dump

# 5. Reiniciar tudo
docker compose restart
```

#### Redis

```bash
# Redis é cache, pode ser recriado

# 1. Parar Redis
docker compose stop redis

# 2. Remover dados corrompidos
docker volume rm borgstack_redis_data

# 3. Recriar volume
docker volume create borgstack_redis_data

# 4. Reiniciar
docker compose up -d redis

# Cache será reconstruído automaticamente
```

---

## 9. Quando Pedir Ajuda

### 9.1. Informações para Coletar

Antes de abrir uma issue, colete:

```bash
# 1. Versões
docker --version
docker compose version
lsb_release -a

# 2. Status dos containers
docker compose ps -a > status.txt

# 3. Logs relevantes (últimas 200 linhas)
docker compose logs --tail=200 > logs.txt

# 4. Configuração sanitizada (SEM SENHAS!)
docker compose config > config-sanitized.txt

# 5. Recursos do sistema
docker stats --no-stream > resources.txt
free -h >> resources.txt
df -h >> resources.txt

# 6. Informações de rede
docker network ls > network.txt
docker network inspect borgstack_internal >> network.txt

# 7. Compactar tudo
tar -czf borgstack-debug-$(date +%Y%m%d).tar.gz \
  status.txt logs.txt config-sanitized.txt resources.txt network.txt
```

### 9.2. Onde Reportar

- **GitHub Issues**: https://github.com/seu-usuario/borgstack/issues
- **Discord/Telegram**: Link na documentação
- **Stack Overflow**: Tag `borgstack`

### 9.3. Template de Issue

```markdown
## Descrição do Problema
[Descreva o problema em detalhes]

## Passos para Reproduzir
1. ...
2. ...
3. ...

## Comportamento Esperado
[O que deveria acontecer]

## Comportamento Atual
[O que está acontecendo]

## Ambiente
- OS: Ubuntu 24.04 LTS
- Docker: 24.0.7
- Docker Compose: 2.21.0
- RAM: 32GB
- BorgStack Version: v1.0

## Logs Relevantes
```
[Cole logs aqui]
```

## Tentativas de Solução
[O que você já tentou]
```

---

## Recursos Adicionais

### Documentação Relacionada

- [Instalação](01-instalacao.md)
- [Configuração](02-configuracao.md)
- [Serviços](03-services/)
- [Integrações](04-integrations/)
- [Manutenção](06-manutencao.md)
- [Segurança](07-seguranca.md)

### Links Úteis

- **Docker**: https://docs.docker.com/
- **PostgreSQL**: https://www.postgresql.org/docs/18/
- **Redis**: https://redis.io/docs/
- **n8n**: https://docs.n8n.io/
- **Chatwoot**: https://www.chatwoot.com/docs/

---

**Última atualização**: 2025-10-08
**Versão do guia**: 1.0
**Compatibilidade**: BorgStack v1.0
