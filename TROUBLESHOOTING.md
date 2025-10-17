# Solução de Problemas - BorgStack

## Introdução

Este guia cobre os 10 problemas mais comuns do BorgStack. Use `docker compose logs <serviço>` para diagnóstico detalhado.

## Problemas Mais Comuns

### 1. Serviços falham ao iniciar (healthcheck failures)

**Sintoma:** Container reinicia continuamente, status "unhealthy"

**Solução:**
```bash
docker compose logs --tail=100 <serviço>
# Aumentar start_period no docker-compose.yml se necessário
```

### 2. Falha na geração de certificado SSL (Caddy Let's Encrypt)

**Sintoma:** Erro "failed to obtain certificate" no Caddy

**Solução:**
```bash
# Verificar DNS e firewall
nslookup n8n.${DOMAIN}
sudo ufw allow 80/tcp && sudo ufw allow 443/tcp
docker compose logs caddy | grep certificate
```

### 3. Banco de dados inacessível (PostgreSQL connection refused)

**Sintoma:** Serviços não conectam ao PostgreSQL

**Solução:**
```bash
docker compose exec postgresql pg_isready -U postgres
# Aguardar "database system is ready" nos logs
docker compose logs postgresql | grep "ready to accept connections"
```

### 4. Erros de falta de memória (OOM killer)

**Sintoma:** Containers param inesperadamente, sistema lento

**Solução:**
```bash
docker stats --no-stream  # Identificar consumo
dmesg | grep -i "out of memory"
# Adicionar limites no docker-compose.yml:
#   deploy.resources.limits.memory: 4G
```

### 5. Performance lenta / alto uso de CPU

**Sintoma:** Aplicações lentas, CPU > 90%

**Solução:**
```bash
docker stats  # Identificar serviço
# Executar VACUUM no PostgreSQL
docker compose exec postgresql psql -U postgres -c "VACUUM ANALYZE;"
```

### 6. Erros de permissão em volumes

**Sintoma:** "Permission denied" ao acessar volumes

**Solução:**
```bash
# Corrigir proprietário (UID 1000 para maioria dos serviços)
sudo chown -R 1000:1000 volumes/<nome_volume>/
# PostgreSQL usa UID 999
sudo chown -R 999:999 volumes/borgstack_postgresql_data/
```

### 7. Conflito de portas (address already in use)

**Sintoma:** Erro "bind: address already in use"

**Solução:**
```bash
sudo lsof -i :80  # Identificar processo
# Parar serviço conflitante ou alterar porta no docker-compose.yml
```

### 8. Falhas no backup (Duplicati)

**Sintoma:** Backup não executado ou com erros

**Solução:**
```bash
docker compose logs duplicati | grep -i error
df -h  # Verificar espaço em disco
# Acessar interface: http://localhost:8200 e verificar configuração
```

### 9. Crashes específicos de serviços (n8n, Chatwoot, etc.)

**Sintoma:** Serviço específico reinicia ou para de responder

**Solução:**
```bash
docker compose logs --tail=200 <serviço>
# Verificar variáveis de ambiente no .env
docker compose restart <serviço>
# Se persistir: docker compose up -d --force-recreate <serviço>
```

### 10. Falhas em atualizações/migrações

**Sintoma:** Após atualização, serviços não iniciam

**Solução:**
```bash
# Rollback para versão anterior
docker compose down
docker compose pull <imagem>:<tag_anterior>
docker compose up -d

# Verificar changelog antes de atualizar
# Executar migrações: docker compose exec <serviço> npm run migrate
```

## Obtendo Ajuda

**Coletar informações de diagnóstico:**
```bash
docker compose logs > borgstack-logs-$(date +%Y%m%d).txt
docker compose ps
docker stats --no-stream
df -h && free -h
```

**Suporte e Documentação:**
- Issues: https://github.com/borgstack/borgstack/issues
- Documentação: `INSTALL.md`, `CONFIGURATION.md`, `docs/services.md`, `docs/integrations.md`, `docs/maintenance.md`
- Docker Compose: https://docs.docker.com/compose/
