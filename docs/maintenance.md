# Manutenção - BorgStack

## Checklist de Backup

### Configuração Inicial (Duplicati)

**Acesso:** http://localhost:8200

**Configurar job:**
- Destino: S3/FTP/Local
- Criptografia: AES-256 (guardar senha!)
- Schedule: Diário às 02:00
- Retention: 30 dias diários + semanais por 3 meses

**Backup de:**
- PostgreSQL: `n8n_db`, `chatwoot_db`, `directus_db`, `evolution_db`
- MongoDB: `lowcoder`
- Volumes: `borgstack_*`
- Configs: `.env`, `config/`, `docker-compose.yml`

### Verificações

**Semanal:**
```bash
# Verificar último backup
docker compose logs duplicati | grep "Backup completed"

# Tamanho dos backups (não 0 bytes)
ls -lh /path/to/backups/ | tail -5
```

**Mensal - Teste de restauração:**
```bash
# Criar staging + restaurar + validar workflows críticos
docker compose -f docker-compose.staging.yml up -d
```

## Checklist de Atualização

### Pré-Atualização

```bash
# 1. Backup forçado
docker compose exec duplicati duplicati-cli backup --backup-name="Pre-Update-$(date +%Y%m%d)"

# 2. Revisar changelog (breaking changes?)
docker image inspect n8nio/n8n:latest | grep version

# 3. Agendar janela de manutenção
```

### Procedimento

```bash
# 1. Parar
docker compose down

# 2. Backup volumes
tar -czf volumes-backup-$(date +%Y%m%d).tar.gz volumes/

# 3. Atualizar
docker compose pull
docker compose up -d

# 4. Verificar
docker compose ps  # Aguardar "healthy"
docker compose logs --tail=100 | grep -i error
```

### Pós-Atualização

**Validação (30 min):**
- Testar acessos: `curl -I https://n8n.seudominio.com.br`
- Verificar workflows críticos
- Monitorar logs de erro
- Verificar recursos: `docker stats --no-stream`

**Monitorar 24h:** Performance degradada? Erros novos?

### Rollback (Se Falhar)

```bash
docker compose down
git checkout HEAD~1 docker-compose.yml
rm -rf volumes/ && tar -xzf volumes-backup-YYYYMMDD.tar.gz
docker compose pull && docker compose up -d
```

## Checklist de Segurança

### Inicial (Deploy)

```bash
# 1. Alterar TODAS senhas padrão (.env)
openssl rand -base64 32  # Gerar senhas fortes

# 2. Firewall
sudo ufw default deny incoming
sudo ufw allow 22/tcp && sudo ufw allow 80/tcp && sudo ufw allow 443/tcp
sudo ufw enable

# 3. SSH apenas com chave (sem senha)
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# 4. Updates automáticos
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

### Revisão Mensal

```bash
# 1. Revisar usuários ativos (n8n, Chatwoot, Directus)
# 2. Verificar atualizações disponíveis: docker images
# 3. Revisar firewall: sudo ufw status numbered
# 4. Auditar logs: docker compose logs caddy | grep -E "401|403|429"
```

### Trimestral

```bash
# 1. Atualizar imagens: docker compose pull && docker compose up -d --force-recreate
# 2. Verificar SSL: openssl s_client -servername n8n.seudominio.com.br -connect n8n.seudominio.com.br:443 | grep "Not After"
# 3. Testar restauração de backup
# 4. Rotacionar credenciais (tokens API, senhas admin, API keys)
```

## Comandos Úteis

```bash
docker compose ps                        # Status containers
docker stats --no-stream                 # Uso de recursos
docker compose logs --tail=100 <serviço> # Logs específicos
docker compose logs | grep -i error      # Erros
docker compose restart <serviço>         # Reiniciar
docker compose up -d --force-recreate <serviço> # Rebuild
docker system prune -a --volumes         # Limpar (cuidado!)
```

## Recursos

- Duplicati: https://www.duplicati.com/
- Docker Compose: https://docs.docker.com/compose/
- UFW: https://help.ubuntu.com/community/UFW
- Unattended Upgrades: https://wiki.debian.org/UnattendedUpgrades
