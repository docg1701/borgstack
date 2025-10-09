# BorgStack

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

**Documentação completa em Português Brasileiro está disponível →** [**docs/README.md**](docs/README.md)

### Guias Principais

- 📖 **[Guia de Instalação](docs/01-instalacao.md)** - Instalação completa passo a passo
- ⚙️ **[Guia de Configuração](docs/02-configuracao.md)** - Configuração de variáveis de ambiente e serviços
- 🔧 **[Guias de Serviços](docs/03-services/)** - Documentação detalhada de cada serviço
- 🔗 **[Guias de Integração](docs/04-integrations/)** - Tutoriais de integração (WhatsApp, n8n, etc.)
- 🚨 **[Solução de Problemas](docs/05-solucao-de-problemas.md)** - Troubleshooting e diagnóstico
- 🔐 **[Guia de Segurança](docs/07-seguranca.md)** - Hardening e melhores práticas de segurança
- 🛠️ **[Guia de Manutenção](docs/06-manutencao.md)** - Manutenção preventiva e atualizações
- ⚡ **[Otimização de Desempenho](docs/08-desempenho.md)** - Tuning e otimização de performance

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
