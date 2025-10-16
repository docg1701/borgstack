# Source Tree

BorgStack uses a simple monorepo structure optimized for Docker Compose deployment and Portuguese documentation.

```
borgstack/
├── .github/
│   └── workflows/
│       └── ci.yml                    # CI validation (docker-compose config lint)
│
├── config/                           # Service-specific configuration files
│   ├── postgresql/
│   │   ├── init-databases.sql        # Database initialization script
│   │   └── postgresql.conf           # Performance tuning
│   ├── redis/
│   │   └── redis.conf                # Cache/queue configuration
│   ├── seaweedfs/
│   │   └── filer.toml                # Filer configuration
│   ├── caddy/
│   │   ├── Caddyfile                 # Production reverse proxy + SSL config
│   │   └── Caddyfile.dev             # Development localhost config
│   ├── n8n/
│   │   └── workflows/                # Example workflow templates
│   ├── chatwoot/
│   │   └── .env.example              # Chatwoot-specific vars
│   ├── evolution/
│   │   └── .env.example              # Evolution API config
│   └── duplicati/
│       └── backup-config.json        # Backup job definitions
│
├── scripts/
│   ├── bootstrap.sh                  # GNU/Linux automated setup
│   ├── healthcheck.sh                # Post-deployment verification
│   ├── backup-now.sh                 # Manual backup trigger
│   ├── restore.sh                    # Disaster recovery script
│   ├── update-service.sh             # Individual service update
│   └── generate-env.sh               # Interactive .env generator
│
├── docs/                             # Portuguese documentation
│   ├── prd.md                        # Product requirements (source)
│   ├── architecture.md               # This document
│   ├── 01-installation.md            # Guia de instalação
│   ├── 02-configuration.md           # Configuração inicial
│   ├── 03-services/                  # Service-specific guides
│   │   ├── n8n.md                    # Como usar n8n
│   │   ├── chatwoot.md               # Guia Chatwoot
│   │   ├── evolution-api.md          # Integração WhatsApp
│   │   ├── lowcoder.md               # Construir aplicativos
│   │   ├── directus.md               # CMS e gestão de dados
│   │   ├── fileflows.md              # Processamento de mídia
│   │   └── duplicati.md              # Backups e restauração
│   ├── 04-integrations/              # Integration tutorials
│   │   ├── whatsapp-chatwoot.md      # WhatsApp → Chatwoot via n8n
│   │   ├── directus-fileflows.md     # CMS → Media processing
│   │   └── backup-strategy.md        # Estratégia de backup
│   ├── 05-troubleshooting.md         # Solução de problemas
│   ├── 06-maintenance.md             # Manutenção e atualizações
│   ├── 07-security.md                # Hardening de segurança
│   └── 08-performance.md             # Otimização de desempenho
│
├── tests/
│   ├── integration/                  # Integration test scripts
│   │   ├── test-n8n-evolution.sh     # n8n → Evolution API
│   │   ├── test-chatwoot-api.sh      # Chatwoot API connectivity
│   │   └── test-backup-restore.sh    # Backup/restore validation
│   └── deployment/                   # Deployment validation
│       ├── check-dns.sh              # DNS configuration check
│       ├── check-resources.sh        # RAM/disk validation
│       ├── verify-services.sh        # Health check all services
│       └── verify-local-override-configuration.sh  # Local development config validation
│
├── .env.example                      # Environment variable template
├── .gitignore                        # Exclude .env, volumes, logs
├── docker-compose.yml                # Main orchestration file
├── docker-compose.override.yml       # Local development overrides
├── docker-compose.prod.yml           # Production-specific config
├── LICENSE                           # Open source license
└── README.md                         # Quick start (bilingual EN/PT-BR)
```

---