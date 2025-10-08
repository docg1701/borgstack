# Guia de Manutenção - BorgStack

## Visão Geral

Este guia apresenta as práticas recomendadas para manutenção contínua do BorgStack, garantindo alta disponibilidade, performance otimizada e operação confiável a longo prazo.

### Ciclo de Manutenção

```mermaid
graph LR
    A[Monitoramento<br/>Contínuo] --> B[Manutenção<br/>Preventiva]
    B --> C[Atualizações<br/>Programadas]
    C --> D[Backups<br/>Regulares]
    D --> E[Testes de<br/>Restauração]
    E --> F[Otimização<br/>de Performance]
    F --> A
```text

### Frequência de Tarefas

| Tarefa | Frequência | Tempo Estimado | Prioridade |
|--------|-----------|----------------|------------|
| Verificar backups | Diário | 5 min | 🔴 Alta |
| Monitorar logs | Diário | 10 min | 🔴 Alta |
| Verificar espaço em disco | Semanal | 5 min | 🟡 Média |
| Atualizar imagens Docker | Mensal | 30-60 min | 🟡 Média |
| Testar restauração de backup | Mensal | 1-2 horas | 🔴 Alta |
| Rotacionar credenciais | Trimestral | 30 min | 🟡 Média |
| Revisar configuração | Trimestral | 1 hora | 🟢 Baixa |
| Auditoria de segurança | Semestral | 2-4 horas | 🔴 Alta |

---

## 1. Manutenção Preventiva

### 1.1. Checklist Diário (5 minutos)

**Execute automaticamente ou manualmente todo dia**:

```bash
#!/bin/bash
# Script: daily-check.sh

echo "=== BorgStack Daily Check - $(date) ==="

# 1. Status dos containers
echo -e "\n📦 Container Status:"
docker compose ps

# 2. Verificar backups Duplicati
echo -e "\n💾 Last Backup Check:"
docker compose exec duplicati ls -lh /backups/ | tail -5

# 3. Espaço em disco
echo -e "\n💿 Disk Space:"
df -h / | grep -v Filesystem

# 4. Uso de memória
echo -e "\n🧠 Memory Usage:"
free -h | grep Mem

# 5. Erros recentes (últimas 24h)
echo -e "\n🚨 Recent Errors:"
docker compose logs --since 24h | grep -i error | tail -10

# 6. Health status
echo -e "\n❤️  Health Status:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "unhealthy|starting"

echo -e "\n✅ Daily check complete"
```text

**Salvar e executar**:
```bash
chmod +x scripts/daily-check.sh
./scripts/daily-check.sh
```text

**Automatizar via cron**:
```bash
# Editar crontab
crontab -e

# Adicionar linha (executa todo dia às 8h, salva resultado)
0 8 * * * /home/usuario/borgstack/scripts/daily-check.sh >> /var/log/borgstack-daily.log 2>&1
```text

---

### 1.2. Checklist Semanal (15 minutos)

**Execute todo domingo**:

```bash
#!/bin/bash
# Script: weekly-check.sh

echo "=== BorgStack Weekly Check - $(date) ==="

# 1. Limpar logs antigos do Docker
echo -e "\n🧹 Cleaning old Docker logs:"
sudo find /var/lib/docker/containers/ -name "*.log" -mtime +7 -exec truncate -s 0 {} \;

# 2. Ver uso de disco por serviço
echo -e "\n📊 Docker Disk Usage:"
docker system df

# 3. Verificar imagens não utilizadas
echo -e "\n🗑️  Unused Images:"
docker images --filter "dangling=true"

# 4. Verificar volumes órfãos
echo -e "\n📦 Orphaned Volumes:"
docker volume ls --filter "dangling=true"

# 5. Estatísticas de uso de recursos (última semana)
echo -e "\n📈 Resource Usage Statistics:"
docker stats --no-stream | head -15

# 6. Verificar atualizações disponíveis
echo -e "\n🔄 Available Updates:"
docker compose pull --dry-run 2>&1 | grep "Pulling"

echo -e "\n✅ Weekly check complete"
```text

**Automatizar via cron**:
```bash
# Executar todo domingo às 10h
0 10 * * 0 /home/usuario/borgstack/scripts/weekly-check.sh >> /var/log/borgstack-weekly.log 2>&1
```text

---

### 1.3. Checklist Mensal (1-2 horas)

**Execute no primeiro domingo de cada mês**:

#### Tarefa 1: Limpar Dados Não Utilizados

```bash
# Parar containers temporariamente
docker compose stop

# Limpar cache do Docker (não remove volumes)
docker system prune -a -f

# Resultado esperado:
# Deleted Images: 15
# Total reclaimed space: 5.2GB

# Reiniciar
docker compose up -d
```text

#### Tarefa 2: Verificar Integridade dos Backups

```bash
# 1. Verificar último backup
docker compose exec duplicati ls -lh /backups/ | tail -1

# 2. Testar restauração (selecionar arquivo aleatório)
# Acessar UI do Duplicati: https://duplicati.seudominio.com.br
# 1. Restore > Restore files
# 2. Selecionar backup recente
# 3. Escolher 1-2 arquivos pequenos
# 4. Restaurar para /tmp/test-restore
# 5. Verificar conteúdo

# 3. Verificar consistência do backup
docker compose exec duplicati duplicati-cli test file:///backups/latest.zip
```text

#### Tarefa 3: Atualizar Imagens Docker

Ver seção 2.2 abaixo para procedimento completo.

#### Tarefa 4: Revisar Logs

```bash
# Exportar logs do último mês para análise
docker compose logs --since 30d > /tmp/borgstack-logs-$(date +%Y%m).txt

# Analisar erros
grep -i error /tmp/borgstack-logs-$(date +%Y%m).txt | sort | uniq -c | sort -nr | head -20

# Analisar warnings
grep -i warn /tmp/borgstack-logs-$(date +%Y%m).txt | sort | uniq -c | sort -nr | head -20
```text

---

### 1.4. Checklist Trimestral (2-3 horas)

**Execute a cada 3 meses**:

#### Tarefa 1: Rotação de Credenciais

Ver seção 1.5 abaixo para procedimento completo.

#### Tarefa 2: Auditoria de Configuração

```bash
# 1. Revisar .env
nano .env

# Verificar:
# - Senhas fortes (mínimo 32 caracteres)
# - Variáveis obsoletas
# - Valores default não alterados

# 2. Revisar docker-compose.yml
nano docker-compose.yml

# Verificar:
# - Versões pinadas das imagens
# - Limites de recursos (mem_limit, cpus)
# - Health checks configurados
# - Redes corretas (internal/external)

# 3. Revisar configurações de serviços
ls -la config/*/

# Verificar mudanças inesperadas
git diff HEAD config/
```text

#### Tarefa 3: Análise de Performance

```bash
# Ver métricas agregadas
docker stats --no-stream > /tmp/docker-stats-$(date +%Y%m%d).txt

# Analisar queries lentas no PostgreSQL
docker compose exec postgresql psql -U postgres -c "
  SELECT
    calls,
    mean_exec_time::int as avg_ms,
    total_exec_time::int as total_ms,
    query
  FROM pg_stat_statements
  ORDER BY mean_exec_time DESC
  LIMIT 10;
"

# Analisar cache hit rate do Redis
docker compose exec redis redis-cli INFO stats | grep -E "keyspace_(hits|misses)"
```text

---

### 1.5. Rotação de Credenciais

**Executar a cada 90 dias (recomendado)**:

#### Passo 1: Gerar Novas Credenciais

```bash
# Backup do .env atual
cp .env .env.backup-$(date +%Y%m%d)

# Gerar novas senhas
./scripts/generate-passwords.sh

# Ou manualmente:
echo "Nova senha PostgreSQL: $(openssl rand -base64 32)"
echo "Nova senha Redis: $(openssl rand -base64 32)"
echo "Nova senha MongoDB: $(openssl rand -base64 32)"
```text

#### Passo 2: Atualizar PostgreSQL

```bash
# 1. Conectar ao PostgreSQL
docker compose exec postgresql psql -U postgres

# 2. Alterar senha do usuário postgres
ALTER USER postgres WITH PASSWORD 'nova_senha_aqui';

# 3. Sair
\q

# 4. Atualizar .env
nano .env
# Editar: POSTGRES_PASSWORD=nova_senha_aqui

# 5. Recriar containers que usam PostgreSQL
docker compose up -d --force-recreate n8n chatwoot directus evolution
```text

#### Passo 3: Atualizar Redis

```bash
# 1. Atualizar config/redis/redis.conf
nano config/redis/redis.conf

# Encontrar e editar:
requirepass nova_senha_redis

# 2. Atualizar .env
nano .env
# Editar: REDIS_PASSWORD=nova_senha_redis

# 3. Reiniciar Redis e dependentes
docker compose restart redis
docker compose restart n8n chatwoot directus lowcoder-api-service
```text

#### Passo 4: Atualizar MongoDB

```bash
# 1. Conectar ao MongoDB
docker compose exec mongodb mongosh -u root -p senha_antiga

# 2. Alterar senha do root
use admin
db.changeUserPassword("root", "nova_senha_mongo")

# 3. Alterar senha do lowcoder_user
db.changeUserPassword("lowcoder_user", "nova_senha_lowcoder")

# 4. Sair
exit

# 5. Atualizar .env
nano .env
# Editar: MONGO_ROOT_PASSWORD=nova_senha_mongo
# Editar string de conexão do Lowcoder

# 6. Reiniciar Lowcoder
docker compose restart lowcoder-api-service lowcoder-node-service lowcoder-frontend
```text

#### Passo 5: Rotacionar API Keys

```bash
# Chatwoot API Token
# 1. Acessar Chatwoot UI
# 2. Settings > Profile Settings > Access Token
# 3. Click "Regenerate"
# 4. Copiar novo token

# Atualizar em workflows n8n que usam Chatwoot
# E atualizar .env se armazenado lá

# Evolution API Key
# 1. Acessar painel da Evolution API
# 2. Gerar nova API key
# 3. Atualizar nos webhooks e workflows n8n

# n8n Webhook Auth
# Se usar autenticação em webhooks, regenerar tokens
```text

#### Passo 6: Verificar Tudo Funcionando

```bash
# Testar conexões
./scripts/test-connections.sh

# Ou manualmente:
docker compose exec n8n wget -O- http://n8n:5678/healthz
docker compose exec chatwoot curl http://chatwoot:3000/health
docker compose exec directus curl http://directus:8055/server/health
```text

---

## 2. Atualizações de Serviços

### 2.1. Estratégia de Atualização

**Filosofia**: Atualização conservadora com testes.

```mermaid
flowchart TD
    A[Nova Versão<br/>Disponível] --> B{Tipo de<br/>Atualização?}
    B -->|Patch| C[Atualização<br/>Rápida]
    B -->|Minor| D[Atualização<br/>Testada]
    B -->|Major| E[Atualização<br/>Planejada]

    C --> F[Backup]
    F --> G[Aplicar Update]
    G --> H[Testar]

    D --> I[Backup]
    I --> J[Criar Staging]
    J --> K[Testar em Staging]
    K --> L{Sucesso?}
    L -->|Sim| M[Aplicar em Prod]
    L -->|Não| N[Rollback]

    E --> O[Planejar Janela]
    O --> P[Backup Completo]
    P --> Q[Revisar Breaking<br/>Changes]
    Q --> R[Atualizar]
    R --> S[Testes Extensivos]
```text

**Tipos de atualização**:
- **Patch** (1.0.0 → 1.0.1): Bug fixes, sem breaking changes
- **Minor** (1.0.0 → 1.1.0): Novas features, backward compatible
- **Major** (1.0.0 → 2.0.0): Breaking changes, requer planejamento

---

### 2.2. Procedimento de Atualização Segura

#### Passo 1: Verificar Atualizações Disponíveis

```bash
# Ver versões atuais
docker compose images

# Verificar atualizações disponíveis (não baixa)
docker compose pull --dry-run
```text

#### Passo 2: Revisar Changelogs

```bash
# Para cada serviço com atualização, revisar:
# - n8n: https://github.com/n8n-io/n8n/releases
# - Chatwoot: https://github.com/chatwoot/chatwoot/releases
# - Directus: https://github.com/directus/directus/releases
# - PostgreSQL: https://www.postgresql.org/docs/18/release.html
# - Redis: https://github.com/redis/redis/releases

# Procurar por:
# - Breaking changes (BREAKING:, ⚠️)
# - Database migrations
# - Configuration changes
# - Deprecated features
```text

#### Passo 3: Backup Completo

```bash
# 1. Parar serviços (exceto bancos de dados)
docker compose stop n8n chatwoot directus evolution lowcoder-api-service lowcoder-node-service lowcoder-frontend fileflows

# 2. Backup de bancos de dados
./scripts/backup-databases.sh

# Ou manualmente:
docker compose exec postgresql pg_dumpall -U postgres -c > /backups/postgres_all_$(date +%Y%m%d).sql
docker compose exec mongodb mongodump --archive=/backups/mongodb_all_$(date +%Y%m%d).archive --gzip
docker compose exec redis redis-cli SAVE

# 3. Backup de volumes
sudo tar -czf /backups/volumes_$(date +%Y%m%d).tar.gz -C /var/lib/docker/volumes/ \
  $(docker volume ls -q | grep borgstack | tr '\n' ' ')

# 4. Backup de configurações
tar -czf /backups/configs_$(date +%Y%m%d).tar.gz docker-compose.yml .env config/
```text

#### Passo 4: Atualizar Imagens

```bash
# Baixar novas imagens
docker compose pull

# Resultado esperado:
# Pulling postgresql ... done
# Pulling redis ... done
# Pulling n8n ... done
# ...
```text

#### Passo 5: Aplicar Atualizações

```bash
# Recriar containers com novas imagens
docker compose up -d --force-recreate

# Monitorar logs durante startup
docker compose logs -f
```text

#### Passo 6: Verificar Saúde

```bash
# Aguardar todos ficarem healthy (pode levar 2-5 minutos)
watch docker compose ps

# Verificar logs de erro
docker compose logs --since 10m | grep -i error

# Testar acessos
curl -f https://n8n.seudominio.com.br/healthz
curl -f https://chatwoot.seudominio.com.br/health
curl -f https://directus.seudominio.com.br/server/health
```text

#### Passo 7: Testes Funcionais

```bash
# Checklist manual:
# [ ] Acessar cada serviço via browser
# [ ] Fazer login
# [ ] Executar ação básica (ex: criar workflow no n8n)
# [ ] Verificar integrações funcionando (WhatsApp → Chatwoot)
# [ ] Verificar backups agendados rodando
```text

#### Passo 8: Rollback (se necessário)

```bash
# Se atualização falhar:

# 1. Parar tudo
docker compose down

# 2. Editar docker-compose.yml para versões anteriores
nano docker-compose.yml

# Exemplo - reverter versão do n8n:
  n8n:
    image: n8nio/n8n:1.62.3  # Versão anterior (era 1.63.0)

# 3. Restaurar backup de banco de dados (se houve migration)
docker compose up -d postgresql
docker compose exec -T postgresql psql -U postgres < /backups/postgres_all_20251007.sql

# 4. Recriar containers
docker compose up -d

# 5. Verificar
docker compose ps
```text

---

### 2.3. Atualização Individual de Serviço

Se quiser atualizar apenas um serviço:

```bash
# Exemplo: Atualizar apenas n8n

# 1. Backup
docker compose exec postgresql pg_dump -U postgres n8n_db > /backups/n8n_db_$(date +%Y%m%d).sql

# 2. Editar docker-compose.yml
nano docker-compose.yml

# Mudar versão do n8n:
  n8n:
    image: n8nio/n8n:1.63.0  # Nova versão

# 3. Aplicar
docker compose pull n8n
docker compose up -d --force-recreate n8n

# 4. Verificar
docker compose logs -f n8n
```text

---

## 3. Gerenciamento de Backups

### 3.1. Estratégia de Backup (3-2-1 Rule)

**Regra 3-2-1**:
- **3** cópias dos dados
- **2** tipos de mídia diferentes
- **1** cópia offsite

**Implementação no BorgStack**:

| Cópia | Tipo | Localização | Frequência |
|-------|------|-------------|------------|
| **1ª** (Produção) | Volumes Docker | Servidor | Tempo real |
| **2ª** (Local) | Tar.gz encriptado | Servidor `/backups` | Diário |
| **3ª** (Remoto) | Duplicati backup | S3/Cloud | Diário |

### 3.2. Configurar Backups Automáticos

#### Duplicati (Já configurado no BorgStack)

```bash
# Verificar status do Duplicati
docker compose ps duplicati

# Acessar UI
# https://duplicati.seudominio.com.br

# Configuração típica:
# 1. General > Encryption: AES-256 with passphrase
# 2. Destination: S3 Compatible (SeaweedFS)
# 3. Source Data: /backups (mapeado para volumes)
# 4. Schedule: Daily at 2 AM
# 5. Retention: 7 daily, 4 weekly, 12 monthly
```text

#### Backup Manual Completo

```bash
#!/bin/bash
# Script: full-backup.sh

BACKUP_DIR="/backups/manual"
DATE=$(date +%Y%m%d_%H%M%S)

echo "=== Full Backup Started: $DATE ==="

# Criar diretório
mkdir -p $BACKUP_DIR

# 1. Parar serviços de aplicação (não bancos)
echo "Stopping application services..."
docker compose stop n8n chatwoot directus evolution lowcoder-frontend lowcoder-node-service lowcoder-api-service fileflows

# 2. Backup PostgreSQL (todos os bancos)
echo "Backing up PostgreSQL..."
docker compose exec -T postgresql pg_dumpall -U postgres -c | gzip > "$BACKUP_DIR/postgresql_all_$DATE.sql.gz"

# 3. Backup MongoDB
echo "Backing up MongoDB..."
docker compose exec -T mongodb mongodump --archive --gzip | cat > "$BACKUP_DIR/mongodb_all_$DATE.archive.gz"

# 4. Backup Redis
echo "Backing up Redis..."
docker compose exec redis redis-cli -a $REDIS_PASSWORD BGSAVE
sleep 5
docker cp $(docker compose ps -q redis):/data/dump.rdb "$BACKUP_DIR/redis_$DATE.rdb"

# 5. Backup volumes
echo "Backing up volumes..."
docker run --rm \
  -v borgstack_n8n_data:/source/n8n:ro \
  -v borgstack_chatwoot_storage:/source/chatwoot:ro \
  -v borgstack_directus_uploads:/source/directus:ro \
  -v $BACKUP_DIR:/backup \
  alpine tar czf /backup/volumes_$DATE.tar.gz -C /source .

# 6. Backup configurações
echo "Backing up configs..."
tar czf "$BACKUP_DIR/configs_$DATE.tar.gz" docker-compose.yml .env config/

# 7. Reiniciar serviços
echo "Restarting services..."
docker compose up -d

# 8. Encriptar backup (opcional)
echo "Encrypting backup..."
tar czf - "$BACKUP_DIR"/*_$DATE.* | gpg --symmetric --cipher-algo AES256 -o "$BACKUP_DIR/full_backup_$DATE.tar.gz.gpg"

# 9. Limpar arquivos não encriptados
rm -f "$BACKUP_DIR"/*_$DATE.{sql.gz,archive.gz,rdb,tar.gz}

# 10. Calcular checksum
sha256sum "$BACKUP_DIR/full_backup_$DATE.tar.gz.gpg" > "$BACKUP_DIR/full_backup_$DATE.tar.gz.gpg.sha256"

echo "=== Backup Complete: $BACKUP_DIR/full_backup_$DATE.tar.gz.gpg ==="
```text

### 3.3. Teste de Restauração

**Execute mensalmente para garantir que backups funcionam**:

```bash
#!/bin/bash
# Script: test-restore.sh

TEST_DIR="/tmp/restore-test-$(date +%Y%m%d)"
BACKUP_FILE="/backups/manual/full_backup_20251007.tar.gz.gpg"

echo "=== Testing Backup Restore ==="

# 1. Criar diretório de teste
mkdir -p $TEST_DIR

# 2. Desencriptar backup
gpg --decrypt $BACKUP_FILE | tar xzf - -C $TEST_DIR

# 3. Verificar conteúdo
echo "Backup contents:"
ls -lh $TEST_DIR

# 4. Testar restauração de PostgreSQL (em banco de teste)
echo "Testing PostgreSQL restore..."
gunzip -c $TEST_DIR/postgresql_all_*.sql.gz | head -100

# 5. Verificar integridade
echo "Verifying checksums..."
cd $(dirname $BACKUP_FILE)
sha256sum -c $(basename $BACKUP_FILE).sha256

# 6. Limpar
rm -rf $TEST_DIR

echo "=== Restore Test Complete ==="
```text

### 3.4. Retenção de Backups

```bash
# Script para limpar backups antigos
#!/bin/bash
# Script: cleanup-old-backups.sh

BACKUP_DIR="/backups/manual"

echo "=== Cleaning Old Backups ==="

# Manter:
# - Últimos 7 dias (daily)
# - Últimos 4 domingos (weekly)
# - Último dia de cada mês dos últimos 12 meses (monthly)

# Remover backups com mais de 90 dias
find $BACKUP_DIR -name "full_backup_*.gpg" -mtime +90 -delete

# Listar backups remanescentes
echo "Remaining backups:"
ls -lh $BACKUP_DIR

echo "=== Cleanup Complete ==="
```text

Automatizar limpeza:
```bash
# Executar todo domingo às 4h
0 4 * * 0 /home/usuario/borgstack/scripts/cleanup-old-backups.sh >> /var/log/borgstack-cleanup.log 2>&1
```text

---

## 4. Monitoramento e Logs

### 4.1. Configurar Retenção de Logs

```bash
# Editar /etc/docker/daemon.json
sudo nano /etc/docker/daemon.json

# Adicionar:
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3",
    "compress": "true"
  }
}

# Reiniciar Docker
sudo systemctl restart docker

# Recriar containers para aplicar
docker compose down
docker compose up -d
```text

### 4.2. Exportar Logs para Análise

```bash
# Exportar logs do último mês
docker compose logs --since 30d > /tmp/logs_$(date +%Y%m).txt

# Comprimir
gzip /tmp/logs_$(date +%Y%m).txt

# Mover para arquivo
mv /tmp/logs_$(date +%Y%m).txt.gz /var/log/borgstack/
```text

### 4.3. Alertas por E-mail

```bash
#!/bin/bash
# Script: alert-on-error.sh

# Verificar erros nas últimas 24h
ERRORS=$(docker compose logs --since 24h | grep -i "error\|critical\|fatal" | wc -l)

if [ $ERRORS -gt 10 ]; then
  echo "⚠️  ALERT: $ERRORS errors found in the last 24 hours" | \
    mail -s "BorgStack Error Alert" admin@seudominio.com.br
fi
```text

Automatizar:
```bash
# Executar todo dia às 9h
0 9 * * * /home/usuario/borgstack/scripts/alert-on-error.sh
```text

---

## 5. Scaling e Otimização

### 5.1. Scaling Vertical (Mais Recursos)

```bash
# Aumentar recursos do servidor
# - Adicionar mais RAM
# - Adicionar mais CPU
# - Adicionar mais disco

# Após upgrade, ajustar limites no docker-compose.yml
nano docker-compose.yml

# Exemplo: Aumentar limite do PostgreSQL
  postgresql:
    mem_limit: 8g  # Era 4g
    mem_reservation: 4g  # Era 2g
    cpus: "4.0"  # Era 2.0

# Aplicar
docker compose up -d --force-recreate postgresql
```text

### 5.2. Scaling Horizontal (Mais Workers)

```bash
# Exemplo: Adicionar workers do n8n
nano docker-compose.yml

# Adicionar novo serviço:
  n8n-worker:
    image: n8nio/n8n:1.112.6
    environment:
      - N8N_EXECUTIONS_MODE=queue
      - QUEUE_BULL_REDIS_HOST=redis
    networks:
      - borgstack_internal
    depends_on:
      - redis

# Configurar n8n principal para usar fila
  n8n:
    environment:
      - N8N_EXECUTIONS_MODE=queue

# Aplicar
docker compose up -d
```text

---

## Recursos Adicionais

### Documentação Relacionada

- [Instalação](01-instalacao.md)
- [Configuração](02-configuracao.md)
- [Solução de Problemas](05-solucao-de-problemas.md)
- [Segurança](07-seguranca.md)
- [Performance](08-desempenho.md)

### Scripts Úteis

Todos os scripts de manutenção estão em `scripts/`:
- `daily-check.sh` - Verificação diária
- `weekly-check.sh` - Verificação semanal
- `full-backup.sh` - Backup completo
- `test-restore.sh` - Teste de restauração
- `cleanup-old-backups.sh` - Limpeza de backups antigos

---

**Última atualização**: 2025-10-08
**Versão do guia**: 1.0
**Compatibilidade**: BorgStack v1.0
