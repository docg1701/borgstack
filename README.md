# BorgStack

> **EN** | [PT-BR](#borgstack-português)

⬛ BorgStack is the ultimate cube of business automation - a collective of 12 open source tools assimilated into a single Docker Compose consciousness. Like the Borg Collective, we absorb superior technologies from the Alpha quadrant of the internet: PostgreSQL, Redis, n8n, Chatwoot, Directus, Evolution API, and others. Each component works as a synchronized drone, its technological distinctiveness added to our collective perfection. We eliminate the chaotic individuality of manual configurations. Deploy in 30 minutes. Lower your shields. Your infrastructure will be automated.

---

## 🚀 Quick Start

### System Requirements

- **Operating System:** Ubuntu Server 24.04 LTS
- **CPU:** 8 vCPU cores (minimum)
- **RAM:** 36 GB (minimum)
- **Storage:** 500 GB SSD (recommended)
- **Network:** Public IP address with ports 80 and 443 accessible
- **Docker:** Docker Engine with Compose V2

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/borgstack.git
   cd borgstack
   ```

2. **Run the automated bootstrap script (Recommended):**
   ```bash
   ./scripts/bootstrap.sh
   ```

   The bootstrap script will:
   - Validate system requirements (Ubuntu 24.04, RAM, CPU, disk)
   - Install Docker Engine and Docker Compose v2
   - Configure UFW firewall (ports 22, 80, 443)
   - Generate `.env` file with strong passwords
   - Deploy all services
   - Validate health checks
   - Display DNS/SSL configuration instructions

3. **Manual setup (Alternative):**
   ```bash
   # Copy environment template
   cp .env.example .env

   # Edit .env with your configuration
   nano .env

   # Start the stack
   docker compose up -d

   # Check service status
   docker compose ps
   ```

4. **Access your services:**
   - Each service will be available at its configured domain
   - See `.env.example` for domain configuration

---

## 🎯 Bootstrap Script Details

The automated bootstrap script (`scripts/bootstrap.sh`) handles the complete setup process for Ubuntu 24.04 LTS servers.

### What It Does

1. **System Validation:**
   - Checks Ubuntu version (requires 24.04 LTS)
   - Validates RAM (minimum 16GB, recommended 36GB)
   - Validates disk space (minimum 200GB, recommended 500GB)
   - Validates CPU cores (minimum 4, recommended 8)

2. **Software Installation:**
   - Installs Docker Engine (latest stable)
   - Installs Docker Compose v2 plugin
   - Installs system utilities (curl, wget, git, ufw, dig, htop, sysstat)
   - Adds user to docker group for non-root access

3. **Security Configuration:**
   - Configures UFW firewall with default deny incoming policy
   - Opens ports: 22 (SSH), 80 (HTTP), 443 (HTTPS)
   - Generates strong random passwords (32 characters) for all services
   - Sets .env file permissions to 600 (owner read/write only)

4. **Service Deployment:**
   - Pulls all Docker images
   - Starts all services via `docker compose up -d`
   - Waits for service initialization
   - Validates health checks for core services

5. **Post-Installation:**
   - Displays DNS configuration instructions
   - Explains Let's Encrypt SSL automatic generation
   - Provides service access URLs
   - Shows troubleshooting commands

### Prerequisites

- Fresh Ubuntu 24.04 LTS server
- Non-root user with sudo privileges
- Internet connection
- Public IP address (for SSL certificates)

### Usage

```bash
# Make executable (if needed)
chmod +x scripts/bootstrap.sh

# Run the script
./scripts/bootstrap.sh

# Follow interactive prompts for:
# - Domain name (e.g., example.com.br)
# - Email for SSL notifications (e.g., admin@example.com.br)
```

### After Bootstrap

1. **Configure DNS:** Add A records for 7 subdomains pointing to your server IP
2. **Verify DNS:** Wait 5-30 minutes for propagation, then test with `dig`
3. **Access Services:** Visit `https://<service>.<domain>` (SSL auto-generated on first access)
4. **Save Credentials:** Store generated passwords from `.env` in a password manager
5. **Production Security:** Change `CORS_ALLOWED_ORIGINS` from `*` to specific origins

### Troubleshooting

- **View logs:** `cat /tmp/borgstack-bootstrap.log`
- **Check services:** `docker compose ps`
- **View service logs:** `docker compose logs [service_name]`
- **Restart service:** `docker compose restart [service_name]`

### Idempotency

The script is safe to run multiple times:
- Skips Docker installation if already present
- Warns before overwriting existing `.env` file
- Detects existing firewall rules
- No destructive operations without confirmation

---

## 📦 Included Services

| Service | Purpose | Version |
|---------|---------|---------|
| **n8n** | Workflow automation platform | 1.112.6 |
| **Evolution API** | WhatsApp Business API gateway | v2.2.3 |
| **Chatwoot** | Omnichannel customer communication | v4.6.0-ce |
| **Lowcoder** | Low-code application builder | 2.7.4 |
| **Directus** | Headless CMS and data management | 11 |
| **FileFlows** | Automated media processing | 25.09 |
| **SeaweedFS** | S3-compatible object storage | 3.97 |
| **Duplicati** | Encrypted backup automation | 2.1.1.102 |
| **PostgreSQL** | Primary relational database (with pgvector) | 18.0 |
| **MongoDB** | NoSQL database (Lowcoder only) | 7.0 |
| **Redis** | Cache and message queue | 8.2 |
| **Caddy** | Reverse proxy with automatic HTTPS | 2.10 |

---

## 📚 Documentation

Comprehensive documentation is available in the `docs/` directory:

- **Installation Guide:** [docs/01-installation.md](docs/01-installation.md)
- **Configuration Guide:** [docs/02-configuration.md](docs/02-configuration.md)
- **Service Guides:** [docs/03-services/](docs/03-services/)
- **Integration Tutorials:** [docs/04-integrations/](docs/04-integrations/)
- **Troubleshooting:** [docs/05-troubleshooting.md](docs/05-troubleshooting.md)
- **Maintenance & Updates:** [docs/06-maintenance.md](docs/06-maintenance.md)
- **Security Hardening:** [docs/07-security.md](docs/07-security.md)
- **Performance Optimization:** [docs/08-performance.md](docs/08-performance.md)

---

## 🔧 Configuration

All configuration is managed through environment variables in the `.env` file:

```bash
# Copy the template
cp .env.example .env

# Edit with your configuration
nano .env
```

**Important:** Never commit your `.env` file to version control. It contains sensitive credentials.

---

## 🛠️ Development

### Local Development

Local development uses `docker-compose.override.yml` automatically:

```bash
# Start with local overrides
docker compose up -d

# View logs
docker compose logs -f

# Stop services
docker compose down
```

### Production Deployment

Production deployment uses `docker-compose.prod.yml`:

```bash
# Start with production configuration
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Check service health
docker compose -f docker-compose.yml -f docker-compose.prod.yml ps
```

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

### Branching Strategy

- **Main branch:** `main` (protected, production-ready code)
- **Feature branches:** `feature/<descriptive-name>`
- **Bug fix branches:** `fix/<descriptive-name>`

### Commit Message Format

Use imperative mood for commit messages:

- ✅ Correct: `add health checks to all services`
- ❌ Wrong: `added health checks to all services`

### Pull Request Process

1. Fork the repository
2. Create a feature branch from `main`
3. Make your changes
4. Ensure all CI checks pass
5. Submit a pull request with a clear description

---

## 📝 License

BorgStack is open source software licensed under the [MIT License](LICENSE).

---

## 🌟 Support

- **Issues:** Report bugs or request features via [GitHub Issues](https://github.com/yourusername/borgstack/issues)
- **Documentation:** Check the [docs/](docs/) directory first
- **Community:** Join our discussions (coming soon)

---

## ⚠️ Security

- Never commit `.env` files or secrets to version control
- Regularly update Docker images to patch security vulnerabilities
- Follow security best practices in [docs/07-security.md](docs/07-security.md)
- Use strong, unique passwords for all services
- Enable firewall rules to restrict access to sensitive ports

---

<a name="borgstack-português"></a>

# BorgStack (Português)

> [EN](#borgstack) | **PT-BR**

⬛ BorgStack é o cubo definitivo de automação empresarial - um coletivo de 12 ferramentas open source assimiladas em uma única consciência Docker Compose. Como o Coletivo Borg, absorvemos as tecnologias superiores do quadrante Alpha da internet: PostgreSQL, Redis, n8n, Chatwoot, Directus, Evolution API e outras. Cada componente trabalha como drone sincronizado, sua distintividade tecnológica adicionada à nossa perfeição coletiva. Eliminamos a individualidade caótica de configurações manuais. Deploy em 30 minutos. Baixe seus escudos. Sua infraestrutura será automatizada.

---

## 🚀 Início Rápido

### Requisitos do Sistema

- **Sistema Operacional:** Ubuntu Server 24.04 LTS
- **CPU:** 8 núcleos vCPU (mínimo)
- **RAM:** 36 GB (mínimo)
- **Armazenamento:** 500 GB SSD (recomendado)
- **Rede:** Endereço IP público com portas 80 e 443 acessíveis
- **Docker:** Docker Engine com Compose V2

### Instalação

1. **Clone o repositório:**
   ```bash
   git clone https://github.com/yourusername/borgstack.git
   cd borgstack
   ```

2. **Execute o script de bootstrap automatizado (Recomendado):**
   ```bash
   ./scripts/bootstrap.sh
   ```

   O script de bootstrap irá:
   - Validar requisitos do sistema (Ubuntu 24.04, RAM, CPU, disco)
   - Instalar Docker Engine e Docker Compose v2
   - Configurar firewall UFW (portas 22, 80, 443)
   - Gerar arquivo `.env` com senhas fortes
   - Fazer deploy de todos os serviços
   - Validar health checks
   - Exibir instruções de configuração DNS/SSL

3. **Configuração manual (Alternativa):**
   ```bash
   # Copie o template de variáveis de ambiente
   cp .env.example .env

   # Edite .env com sua configuração
   nano .env

   # Inicie a stack
   docker compose up -d

   # Verifique o status dos serviços
   docker compose ps
   ```

4. **Acesse seus serviços:**
   - Cada serviço estará disponível em seu domínio configurado
   - Veja `.env.example` para configuração de domínios

---

## 🎯 Detalhes do Script Bootstrap

O script de bootstrap automatizado (`scripts/bootstrap.sh`) cuida de todo o processo de configuração para servidores Ubuntu 24.04 LTS.

### O Que Ele Faz

1. **Validação do Sistema:**
   - Verifica versão do Ubuntu (requer 24.04 LTS)
   - Valida RAM (mínimo 16GB, recomendado 36GB)
   - Valida espaço em disco (mínimo 200GB, recomendado 500GB)
   - Valida núcleos de CPU (mínimo 4, recomendado 8)

2. **Instalação de Software:**
   - Instala Docker Engine (última versão estável)
   - Instala plugin Docker Compose v2
   - Instala utilitários do sistema (curl, wget, git, ufw, dig, htop, sysstat)
   - Adiciona usuário ao grupo docker para acesso não-root

3. **Configuração de Segurança:**
   - Configura firewall UFW com política padrão de negar entrada
   - Abre portas: 22 (SSH), 80 (HTTP), 443 (HTTPS)
   - Gera senhas aleatórias fortes (32 caracteres) para todos os serviços
   - Define permissões do arquivo .env para 600 (apenas leitura/escrita do proprietário)

4. **Deploy de Serviços:**
   - Baixa todas as imagens Docker
   - Inicia todos os serviços via `docker compose up -d`
   - Aguarda inicialização dos serviços
   - Valida health checks dos serviços principais

5. **Pós-Instalação:**
   - Exibe instruções de configuração DNS
   - Explica geração automática de SSL via Let's Encrypt
   - Fornece URLs de acesso aos serviços
   - Mostra comandos de troubleshooting

### Pré-requisitos

- Servidor Ubuntu 24.04 LTS novo
- Usuário não-root com privilégios sudo
- Conexão com internet
- Endereço IP público (para certificados SSL)

### Uso

```bash
# Torne executável (se necessário)
chmod +x scripts/bootstrap.sh

# Execute o script
./scripts/bootstrap.sh

# Siga os prompts interativos para:
# - Nome do domínio (ex: exemplo.com.br)
# - Email para notificações SSL (ex: admin@exemplo.com.br)
```

### Após o Bootstrap

1. **Configurar DNS:** Adicione registros A para os 7 subdomínios apontando para o IP do seu servidor
2. **Verificar DNS:** Aguarde 5-30 minutos para propagação, depois teste com `dig`
3. **Acessar Serviços:** Visite `https://<serviço>.<domínio>` (SSL gerado automaticamente no primeiro acesso)
4. **Salvar Credenciais:** Armazene senhas geradas do `.env` em um gerenciador de senhas
5. **Segurança em Produção:** Altere `CORS_ALLOWED_ORIGINS` de `*` para origens específicas

### Solução de Problemas

- **Ver logs:** `cat /tmp/borgstack-bootstrap.log`
- **Verificar serviços:** `docker compose ps`
- **Ver logs de serviço:** `docker compose logs [nome_serviço]`
- **Reiniciar serviço:** `docker compose restart [nome_serviço]`

### Idempotência

O script é seguro para executar múltiplas vezes:
- Ignora instalação do Docker se já presente
- Avisa antes de sobrescrever arquivo `.env` existente
- Detecta regras de firewall existentes
- Nenhuma operação destrutiva sem confirmação

---

## 📦 Serviços Incluídos

| Serviço | Propósito | Versão |
|---------|-----------|--------|
| **n8n** | Plataforma de automação de fluxos de trabalho | 1.112.6 |
| **Evolution API** | Gateway de API WhatsApp Business | v2.2.3 |
| **Chatwoot** | Comunicação omnichannel com clientes | v4.6.0-ce |
| **Lowcoder** | Construtor de aplicativos low-code | 2.7.4 |
| **Directus** | CMS headless e gestão de dados | 11 |
| **FileFlows** | Processamento automatizado de mídia | 25.09 |
| **SeaweedFS** | Armazenamento de objetos compatível com S3 | 3.97 |
| **Duplicati** | Automação de backup criptografado | 2.1.1.102 |
| **PostgreSQL** | Banco de dados relacional primário (com pgvector) | 18.0 |
| **MongoDB** | Banco de dados NoSQL (apenas Lowcoder) | 7.0 |
| **Redis** | Cache e fila de mensagens | 8.2 |
| **Caddy** | Proxy reverso com HTTPS automático | 2.10 |

---

## 📚 Documentação

Documentação abrangente está disponível no diretório `docs/`:

- **Guia de Instalação:** [docs/01-installation.md](docs/01-installation.md)
- **Guia de Configuração:** [docs/02-configuration.md](docs/02-configuration.md)
- **Guias de Serviços:** [docs/03-services/](docs/03-services/)
- **Tutoriais de Integração:** [docs/04-integrations/](docs/04-integrations/)
- **Solução de Problemas:** [docs/05-troubleshooting.md](docs/05-troubleshooting.md)
- **Manutenção e Atualizações:** [docs/06-maintenance.md](docs/06-maintenance.md)
- **Hardening de Segurança:** [docs/07-security.md](docs/07-security.md)
- **Otimização de Desempenho:** [docs/08-performance.md](docs/08-performance.md)

---

## 🔧 Configuração

Toda configuração é gerenciada através de variáveis de ambiente no arquivo `.env`:

```bash
# Copie o template
cp .env.example .env

# Edite com sua configuração
nano .env
```

**Importante:** Nunca commite seu arquivo `.env` no controle de versão. Ele contém credenciais sensíveis.

---

## 🛠️ Desenvolvimento

### Desenvolvimento Local

Desenvolvimento local usa `docker-compose.override.yml` automaticamente:

```bash
# Inicie com overrides locais
docker compose up -d

# Visualize logs
docker compose logs -f

# Pare os serviços
docker compose down
```

### Deploy de Produção

Deploy de produção usa `docker-compose.prod.yml`:

```bash
# Inicie com configuração de produção
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Verifique a saúde dos serviços
docker compose -f docker-compose.yml -f docker-compose.prod.yml ps
```

---

## 🤝 Contribuindo

Contribuições são bem-vindas! Por favor, siga estas diretrizes:

### Estratégia de Branches

- **Branch principal:** `main` (protegida, código pronto para produção)
- **Branches de features:** `feature/<nome-descritivo>`
- **Branches de correções:** `fix/<nome-descritivo>`

### Formato de Mensagem de Commit

Use modo imperativo para mensagens de commit:

- ✅ Correto: `add health checks to all services`
- ❌ Errado: `added health checks to all services`

### Processo de Pull Request

1. Faça fork do repositório
2. Crie uma branch de feature a partir da `main`
3. Faça suas alterações
4. Garanta que todas as verificações de CI passem
5. Submeta um pull request com uma descrição clara

---

## 📝 Licença

BorgStack é software de código aberto licenciado sob a [Licença MIT](LICENSE).

---

## 🌟 Suporte

- **Issues:** Reporte bugs ou solicite recursos via [GitHub Issues](https://github.com/yourusername/borgstack/issues)
- **Documentação:** Verifique o diretório [docs/](docs/) primeiro
- **Comunidade:** Junte-se às nossas discussões (em breve)

---

## ⚠️ Segurança

- Nunca commite arquivos `.env` ou secrets no controle de versão
- Atualize regularmente as imagens Docker para corrigir vulnerabilidades de segurança
- Siga as melhores práticas de segurança em [docs/07-security.md](docs/07-security.md)
- Use senhas fortes e únicas para todos os serviços
- Habilite regras de firewall para restringir acesso a portas sensíveis

---

**Built with ❤️ for the open source community**
