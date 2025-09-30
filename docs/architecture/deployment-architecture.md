# Deployment Architecture

BorgStack uses a **single-server containerized deployment** model optimized for Brazilian businesses requiring data sovereignty and zero licensing costs.

## Deployment Strategy

**Frontend Deployment:**
- **Platform:** Self-hosted via Caddy reverse proxy
- **Build Command:** Not applicable (pre-built Docker images)
- **Output Directory:** Not applicable (containerized services)
- **CDN/Edge:** None (direct server access via HTTPS)
- **Access Pattern:** Users access service URLs directly (e.g., https://n8n.example.com.br)
- **Static Assets:** Each service serves its own static assets from container

**Backend Deployment:**
- **Platform:** Ubuntu 24.04 LTS server (VPS, bare metal, or private cloud)
- **Build Command:** `docker compose pull` (downloads pre-built images)
- **Deployment Method:** Docker Compose orchestration
- **Deployment Directory:** `~/borgstack` (home directory of deployment user)
- **Container Registry:** Docker Hub (official images)
- **Scaling Strategy:** Vertical scaling (increase server resources) or horizontal for n8n/Chatwoot workers

**Infrastructure Deployment:**
- **Provisioning:** Manual server setup or bootstrap script automation
- **Configuration Management:** Environment variables + volume-mounted configs
- **Service Discovery:** Docker DNS (service names resolve automatically)
- **Load Balancing:** Not applicable (single server, Caddy routes by domain)
- **SSL/TLS:** Automatic via Caddy + Let's Encrypt

---

## Deployment Checklist

**Pre-Deployment:**
- [ ] Server provisioned with Ubuntu 24.04 LTS
- [ ] DNS A records configured pointing to server IP
- [ ] Firewall allows ports 80, 443, 22
- [ ] SSH key-based authentication configured
- [ ] Non-root user created with sudo privileges and Docker group membership
- [ ] Server meets resource requirements (8 vCPUs, 36GB RAM, 500GB SSD)
- [ ] Backup destination configured (S3 bucket, FTP server, etc.)

**Deployment:**
- [ ] Clone repository to `~/borgstack`
- [ ] Run `./scripts/bootstrap.sh` or manual installation
- [ ] All Docker images pulled successfully
- [ ] `.env` file generated with strong passwords (chmod 600)
- [ ] All services started (`docker compose ps` shows "Up")
- [ ] SSL certificates generated successfully
- [ ] Health checks passing for all services

**Post-Deployment:**
- [ ] Access each service web UI and verify functionality
- [ ] Configure admin accounts for each service
- [ ] Set up first n8n workflow (e.g., WhatsApp → Chatwoot)
- [ ] Configure Duplicati backup schedule and test backup
- [ ] Test backup restoration on staging/dev server
- [ ] Document admin credentials in secure password manager
- [ ] Configure monitoring/alerting (email notifications)
- [ ] Review security hardening checklist
- [ ] Train users on each service interface

---
