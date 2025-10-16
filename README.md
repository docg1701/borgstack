# BorgStack

⬛ BorgStack é o cubo definitivo de automação empresarial - um coletivo de 12 ferramentas open source assimiladas em uma única consciência Docker Compose. Como o Coletivo Borg, absorvemos as tecnologias superiores do quadrante Alpha da internet: PostgreSQL, Redis, n8n, Chatwoot, Directus, Evolution API e outras. Cada componente trabalha como drone sincronizado, sua distintividade tecnológica adicionada à nossa perfeição coletiva. Eliminamos a individualidade caótica de configurações manuais. Deploy em 30 minutos. Baixe seus escudos. Sua infraestrutura será automatizada.

---

## 🚀 Início Rápido

### Requisitos Mínimos

- **Sistema:** Debian ou Ubuntu (bootstrap automático) ou outra distro Linux (instalação manual)
- **CPU:** 4 núcleos (mínimo 2)
- **RAM:** 18 GB (mínimo 8 GB)
- **Disco:** 250 GB SSD (mínimo 100 GB)
- **Rede:** IP público com portas 80/443 acessíveis (modo produção) ou LAN (modo local)

### Instalação em 5 Comandos

```bash
# 1. Clone o repositório
git clone https://github.com/docg1701/borgstack.git
cd borgstack

# 2. Execute o script de bootstrap automatizado
./scripts/bootstrap.sh

# 3. Selecione modo de instalação
#    [1] Modo Local (LAN) - acesso via http://hostname.local:8080
#    [2] Modo Produção - acesso via https://seu-dominio.com

# 4. Aguarde instalação (15-30 minutos)
#    O script instala Docker, configura firewall, gera senhas,
#    faz deploy dos serviços e valida health checks

# 5. Acesse seus serviços
#    Modo Local: http://hostname.local:8080/n8n
#    Modo Produção: https://n8n.seu-dominio.com
```

**Pronto!** Seu BorgStack está rodando. Consulte [INSTALL.md](INSTALL.md) para instalação detalhada, modos de instalação e troubleshooting.

---

## 📦 Serviços Incluídos

| Serviço | Propósito | Versão |
|---------|-----------|--------|
| **n8n** | Plataforma de automação de workflows | 1.112.6 |
| **Evolution API** | Gateway WhatsApp Business API | v2.2.3 |
| **Chatwoot** | Comunicação omnichannel com clientes | v4.6.0-ce |
| **Lowcoder** | Construtor de aplicativos low-code | 2.7.4 |
| **Directus** | CMS headless e gestão de dados | 11 |
| **FileFlows** | Processamento automatizado de mídia | 25.09 |
| **SeaweedFS** | Armazenamento de objetos compatível com S3 | 3.97 |
| **Duplicati** | Automação de backup criptografado | 2.1.1.102 |
| **PostgreSQL** | Banco de dados relacional (com pgvector) | 18.0 |
| **MongoDB** | Banco de dados NoSQL (Lowcoder) | 7.0 |
| **Redis** | Cache e fila de mensagens | 8.2 |
| **Caddy** | Proxy reverso com SSL automático | 2.10 |

---

## 📚 Documentação

### Documentação Essencial

- **[INSTALL.md](INSTALL.md)** - Guia de instalação completo (local e produção)
- **[CONFIGURATION.md](CONFIGURATION.md)** - Configuração de variáveis de ambiente e serviços *(em breve)*
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Solução de problemas e diagnóstico *(em breve)*

### Guias Detalhados

- **[docs/services.md](docs/services.md)** - Guias específicos de cada serviço *(em breve)*
- **[docs/integrations.md](docs/integrations.md)** - Tutoriais de integração entre serviços *(em breve)*
- **[docs/maintenance.md](docs/maintenance.md)** - Manutenção, atualizações e backups *(em breve)*

### Documentação Técnica

- **[docs/architecture.md](docs/architecture.md)** - Arquitetura e decisões técnicas
- **[docs/prd.md](docs/prd.md)** - Product Requirements Document
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Como contribuir com o projeto

> **Nota:** Alguns guias ainda estão sendo finalizados e estarão disponíveis em breve.

---

## 🤝 Contribuindo

Contribuições são bem-vindas! Consulte [CONTRIBUTING.md](CONTRIBUTING.md) para diretrizes de contribuição, padrões de código e processo de pull requests.

**Diretrizes Rápidas:**
- Use `feature/<nome>` para novas funcionalidades
- Use `fix/<nome>` para correções
- Mensagens de commit em modo imperativo (ex: "add health checks")
- Garanta que todas as verificações de CI passem antes de submeter PR

---

## 📝 Licença

BorgStack é software de código aberto licenciado sob a [Licença MIT](LICENSE).

---

## 🌟 Suporte

- **Issues:** Reporte bugs ou solicite recursos via [GitHub Issues](https://github.com/docg1701/borgstack/issues)
- **Documentação:** Consulte [INSTALL.md](INSTALL.md) e [docs/](docs/) para guias detalhados
- **Segurança:** Para vulnerabilidades de segurança, consulte [docs/architecture/security-and-performance.md](docs/architecture/security-and-performance.md)

---

## ⚠️ Segurança

**Práticas Essenciais:**
- ✅ Nunca commite arquivos `.env` ou secrets no controle de versão
- ✅ Use senhas fortes e únicas para todos os serviços (script bootstrap gera automaticamente)
- ✅ Mantenha as imagens Docker atualizadas regularmente
- ✅ Configure firewall adequadamente (script bootstrap configura UFW automaticamente)
- ✅ Em produção, altere `CORS_ALLOWED_ORIGINS` de `*` para origens específicas

Consulte [docs/architecture/security-and-performance.md](docs/architecture/security-and-performance.md) para hardening completo de segurança.

---

**Built with ❤️ for the open source community**
