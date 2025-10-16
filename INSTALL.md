# Guia de Instalação do BorgStack

---

## Pré-Requisitos

| Recurso | Mínimo | Recomendado |
|---------|--------|-------------|
| **CPU** | 2 vCPUs | 4 vCPUs |
| **RAM** | 8 GB | 18 GB |
| **Disco** | 100 GB SSD | 250 GB SSD |
| **Sistema** | Debian/Ubuntu (bootstrap) ou outra distro Linux (manual) | Debian/Ubuntu |
| **Rede Produção** | IP público + portas 80/443 + 8 subdomínios DNS | |
| **Rede Local** | Apenas LAN (sem domínios necessários) | |

---

## Instalação Modo Local (LAN)

**Ideal para:** Testes, desenvolvimento, demos.
**Acesso:** `http://hostname.local:8080/SERVICE`

### Instalação

```bash
git clone https://github.com/docg1701/borgstack.git
cd borgstack
./scripts/bootstrap.sh
# Selecionar opção 1 (Local Development LAN)
```

### O Que o Script Faz

1. Valida sistema (RAM, CPU, disco)
2. Instala Avahi/mDNS (hostname.local)
3. Instala Docker Engine + Compose v2
4. Configura firewall UFW (22, 80, 443, mDNS)
5. Gera `.env` com senhas fortes
6. Deploy via Docker Compose
7. Valida health checks

**Tempo:** 15-30 minutos

### Acessar Serviços

**mDNS (LAN):**
```
http://hostname.local:8080/n8n
http://hostname.local:8080/chatwoot
http://hostname.local:8080/evolution
http://hostname.local:8080/directus
```

**Localhost:**
```
http://localhost:8080/n8n
http://localhost:5678   # n8n porta direta
```

### Primeiro Login

- **n8n:** Criar conta (primeiro = admin)
- **Chatwoot:** Criar workspace + conta admin
- **Directus:** Credenciais `DIRECTUS_ADMIN_EMAIL/PASSWORD` do `.env`

### Verificar mDNS

```bash
ping $(hostname).local
systemctl status avahi-daemon
```

---

## Instalação Modo Produção

**Ideal para:** Produção, SSL automático.
**Acesso:** `https://service.seu-dominio.com`

### Passo 1: Configurar DNS (ANTES do bootstrap)

Configure 8 registros DNS A → IP público do servidor:

```
n8n.example.com, chatwoot.example.com, evolution.example.com,
lowcoder.example.com, directus.example.com, fileflows.example.com,
duplicati.example.com, seaweedfs.example.com → SEU_IP_PUBLICO
```

Verificar:
```bash
dig n8n.example.com  # Deve retornar seu IP
```

**Propagação:** 5-30 minutos (raramente 24h)

### Passo 2: Executar Bootstrap

```bash
ssh usuario@servidor
git clone https://github.com/docg1701/borgstack.git
cd borgstack
./scripts/bootstrap.sh
# Selecionar opção 2 (Production Deployment)
# Informar: domínio base + email para SSL
```

### O Que o Script Faz

1. Valida sistema
2. Instala Docker
3. Configura firewall (22, 80, 443)
4. Gera `.env` (domínios + senhas)
5. Deploy via docker-compose.prod.yml
6. Caddy gera SSL automático (Let's Encrypt)

**Tempo:** 15-30 minutos + propagação DNS

### Passo 3: Acessar (SSL Automático)

```
https://n8n.seu-dominio.com
https://chatwoot.seu-dominio.com
https://directus.seu-dominio.com
```

**SSL:** Gerado em 30-60s no primeiro acesso.

### Salvar Credenciais

```bash
cat .env | grep PASSWORD
scp usuario@servidor:~/borgstack/.env ~/backup-env.txt
```

**🔒 CRÍTICO:** Guardar `.env` em gerenciador de senhas!

---

## Troubleshooting

### "Insufficient RAM" ou "Unsupported distribution"

```bash
free -h  # Mínimo 8GB
cat /etc/os-release | grep ID  # ubuntu ou debian
```

**Solução:** Upgrade servidor ou instalação manual.

### "Docker not found"

```bash
cat /tmp/borgstack-bootstrap.log
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER && newgrp docker
```

### mDNS não resolve hostname.local

```bash
sudo systemctl restart avahi-daemon
sudo ufw allow 5353/udp
ping $(hostname).local
```

### SSL certificate fails

```bash
dig n8n.seu-dominio.com  # DNS propagou?
sudo ufw status  # 80/443 abertos?
docker compose logs caddy | grep acme
```

**Causas:** DNS não propagou, portas bloqueadas, Let's Encrypt rate limit (5 certs/domínio/semana).

### Container Restarting

```bash
docker compose logs <serviço> --tail 100
docker compose restart <serviço>
```

**Mais:** [TROUBLESHOOTING.md](TROUBLESHOOTING.md) *(em breve)*

---

## Verificação

```bash
docker compose ps  # Todos "Up (healthy)"
./tests/deployment/verify-local-override-configuration.sh
```

### Checklist

- [ ] 14 containers `Up (healthy)`
- [ ] n8n, Chatwoot, Directus acessíveis
- [ ] `.env` salvo (permissões 600)
- [ ] (Produção) DNS + SSL funcionando
- [ ] (Local) mDNS funcionando

---

## Próximos Passos

1. **Configuração:** [CONFIGURATION.md](CONFIGURATION.md) *(em breve)*
2. **Backups:** Configure Duplicati
3. **Segurança:** [docs/architecture/security-and-performance.md](docs/architecture/security-and-performance.md)
4. **Integrações:** [docs/integrations.md](docs/integrations.md) *(em breve)*

**🎉 BorgStack instalado!**

---

**Atualizado:** 2025-10-16
