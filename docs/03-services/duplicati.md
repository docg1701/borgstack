# Duplicati - Sistema de Backup Automatizado

## Visão Geral

O Duplicati é um sistema de backup criptografado e automatizado que protege todos os dados críticos do BorgStack. Todos os backups são criptografados com AES-256 **antes** do envio para o destino de armazenamento, garantindo a segurança dos dados independentemente do provedor escolhido.

**Versão:** Duplicati 2.1.1.102

## Acesso à Interface Web

**URL:** `https://duplicati.{SEU_DOMINIO}`

**Autenticação:** Use a senha configurada em `DUPLICATI_PASSWORD` no arquivo `.env`

## Estratégia de Backup

### Backups Incrementais Inteligentes

O Duplicati utiliza backups incrementais eficientes:

- **Primeiro backup**: Backup completo (FULL) de todas as fontes de dados
- **Backups subsequentes**: Apenas arquivos alterados e blocos de dados modificados
- **Deduplicação**: Blocos de dados idênticos são armazenados apenas uma vez (reduz custos em 30-60%)
- **Compressão**: Compressão zstd para equilíbrio otimizado entre velocidade e taxa de compressão

### Política de Retenção Recomendada

- **7 backups diários**: Mantém últimos 7 dias de backups diários
- **4 backups semanais**: Mantém últimas 4 semanas de backups semanais
- **12 backups mensais**: Mantém últimos 12 meses de backups mensais

**Estimativa de armazenamento**: Aproximadamente 2-3x o tamanho atual dos dados (varia conforme taxa de mudança)

### Agendamento de Backup Recomendado

- **Frequência**: Backups diários
- **Horário**: 2:00 da manhã (horário de Brasília - America/Sao_Paulo)
- **Motivo**: Agendado durante horário de baixo tráfego para minimizar impacto no desempenho

## Fontes de Backup

O Duplicati faz backup dos seguintes volumes de dados críticos:

### Bancos de Dados

| Fonte | Conteúdo | Prioridade |
|-------|----------|------------|
| PostgreSQL | n8n_db, chatwoot_db, directus_db, evolution_db | **CRÍTICO** |
| MongoDB | Base de dados Lowcoder | **CRÍTICO** |
| Redis | Snapshots RDB, arquivos AOF | **ALTA** |

### Armazenamento de Objetos (SeaweedFS)

| Fonte | Conteúdo | Prioridade |
|-------|----------|------------|
| SeaweedFS Master | Topologia de volumes, metadados do cluster | **CRÍTICO** |
| SeaweedFS Volume | Conteúdo real dos arquivos (maior volume) | **CRÍTICO** |
| SeaweedFS Filer | Estrutura de diretórios, mapeamento de caminhos S3 | **CRÍTICO** |

### Dados de Aplicações

| Fonte | Conteúdo | Prioridade |
|-------|----------|------------|
| n8n | Workflows, credenciais criptografadas | **CRÍTICO** |
| Evolution API | Sessões WhatsApp, QR codes | **CRÍTICO** |
| Chatwoot | Uploads, anexos, avatares | **ALTA** |
| Lowcoder | Definições de aplicativos | **ALTA** |
| Directus | Arquivos de mídia do CMS | **ALTA** |
| FileFlows | Definições de fluxos, configurações | **MÉDIA** |
| Caddy | Certificados SSL, dados ACME | **ALTA** |

## Configuração Inicial do Backup

### Passo 1: Acessar Interface Web do Duplicati

1. Navegue para: `https://duplicati.{SEU_DOMINIO}`
2. Faça login com a senha do arquivo `.env` (`DUPLICATI_PASSWORD`)

### Passo 2: Criar Trabalho de Backup

#### 2.1 Configurações Gerais

1. Clique em **"Adicionar backup"**
2. Preencha as informações:
   - **Nome**: `BorgStack-Backup-Completo`
   - **Descrição**: `Backup automatizado de todos os dados do BorgStack`
   - **Criptografia**: **AES-256, integrada**
   - **Senha de criptografia**: **Use `DUPLICATI_PASSPHRASE` do arquivo .env**

⚠️ **CRÍTICO**: Armazene a senha de criptografia em local seguro (gerenciador de senhas). Sem ela, os backups NÃO PODEM ser restaurados!

#### 2.2 Destino do Backup

**Recomendações para clientes brasileiros (LGPD):**

##### Opção 1: AWS S3 (Região São Paulo)

- **Tipo de armazenamento**: S3 Compatible
- **Servidor**: `s3.sa-east-1.amazonaws.com`
- **Bucket**: `borgstack-backups-{nome-do-cliente}`
- **AWS Access Key ID**: Da console IAM da AWS
- **AWS Secret Access Key**: Da console IAM da AWS
- **Custo**: ~R$ 0,12/GB/mês
- **Localização dos dados**: Brasil (compatível com LGPD)

**Configuração**:
```
URL do destino: s3://s3.sa-east-1.amazonaws.com/borgstack-backups-{cliente}
```

##### Opção 2: Backblaze B2 (Econômico)

- **Tipo de armazenamento**: B2 Cloud Storage
- **ID da conta**: Do console do Backblaze B2
- **Application Key**: Do console do Backblaze B2
- **Bucket**: `borgstack-backups-{nome-do-cliente}`
- **Custo**: ~R$ 0,025/GB/mês (70% mais barato que AWS S3)
- **Camada gratuita**: 10GB armazenamento + 1GB download diário

**Configuração**:
```
Selecione "B2 Cloud Storage" e insira credenciais
```

##### Opção 3: Servidor FTP/SFTP Local

- **Tipo de armazenamento**: FTP ou SFTP
- **Servidor**: `sftp.empresa.com.br`
- **Porta**: 22 (SFTP) ou 21 (FTP)
- **Caminho**: `/backups/borgstack/`
- **Usuário**: Usuário FTP/SFTP
- **Senha**: Senha de autenticação

**Vantagem**: Controle total, dados nunca saem das instalações

3. Clique em **"Testar conexão"** para verificar

#### 2.3 Dados de Origem

1. Clique na aba **"Dados de origem"**
2. Selecione **TODOS** os diretórios de origem:
   - `/source/postgresql`
   - `/source/mongodb`
   - `/source/redis`
   - `/source/seaweedfs_master`
   - `/source/seaweedfs_volume`
   - `/source/seaweedfs_filer`
   - `/source/n8n`
   - `/source/evolution`
   - `/source/chatwoot_storage`
   - `/source/lowcoder_stacks`
   - `/source/directus_uploads`
   - `/source/fileflows_data`
   - `/source/fileflows_logs`
   - `/source/fileflows_input`
   - `/source/fileflows_output`
   - `/source/caddy`

#### 2.4 Agendamento

1. **Executar backup**: Automaticamente
2. **Repetir**: Diariamente às 2:00 da manhã
3. **Fuso horário**: America/Sao_Paulo (horário de Brasília)
4. **Dias da semana**: Todos os dias

#### 2.5 Opções Avançadas

**Configurações de Retenção**:
- Manter todos os backups mais recentes que: `7D` (7 dias)
- Retenção inteligente: `7D:1D,4W:1W,12M:1M`
  - Significa: 7 diários (1 por dia), 4 semanais (1 por semana), 12 mensais (1 por mês)

**Configurações de Performance**:
- **Tamanho do volume de upload**: `50MB` (permite retomada em caso de falha)
- **Compressão**: zstd (equilíbrio otimizado)
- **Manter versões**: `1` (manter 1 versão de arquivos excluídos)

**Verificação Automática**:
- Ativar: **"Executar verificação após backup"**
- Frequência: A cada backup (ou a cada 7 dias para backups mais rápidos)

5. Clique em **"Salvar"** para criar o trabalho de backup

### Passo 3: Executar Primeiro Backup (Teste)

1. Selecione o trabalho de backup criado
2. Clique em **"Executar agora"**
3. Monitore o progresso na interface web
4. **Primeiro backup será COMPLETO** (pode levar várias horas dependendo do tamanho dos dados)
5. Verifique se o backup foi concluído com sucesso

**Tempo estimado do primeiro backup**:
- Pequeno (< 10 GB): 30 minutos - 1 hora
- Médio (10-100 GB): 1-4 horas
- Grande (> 100 GB): 4-12 horas

(Depende da velocidade de upload da internet)

### Passo 4: Testar Restauração (CRÍTICO!)

⚠️ **NÃO PULE ESTA ETAPA!** Testar a restauração garante que você pode recuperar dados quando necessário.

1. Selecione o trabalho de backup
2. Clique em **"Restaurar"**
3. Escolha uma versão de backup recente
4. Selecione um arquivo pequeno de teste (ex: de `/source/caddy`)
5. Restaurar para: `/tmp/restore-test/`
6. Clique em **"Restaurar"**
7. Verifique se o arquivo foi restaurado com sucesso
8. Exclua o teste de restauração via terminal:
   ```bash
   docker compose exec duplicati rm -rf /tmp/restore-test/
   ```

## Verificação de Backup

### Verificação Automática

Configure o Duplicati para verificar backups automaticamente:

1. Edite o trabalho de backup
2. Vá para **Opções** → **Avançado**
3. Ative **"Executar verificação após backup"**
4. Frequência: A cada backup (ou a cada 7 dias)

### Verificação Manual

Para verificar manualmente a integridade do backup:

1. Selecione o trabalho de backup
2. Clique em **"Verificar arquivos"**
3. Escolha o nível de verificação:
   - **Baixar listas de arquivos**: Rápido, verifica apenas metadados
   - **Baixar e verificar arquivos**: Lento, verifica dados reais
4. Clique em **"Verificar"**

**Frequência recomendada**: Verificação completa mensal

## Procedimentos de Restauração

### Restauração de Arquivo Individual

1. Acesse a interface web do Duplicati
2. Selecione o trabalho de backup
3. Clique em **"Restaurar"**
4. Escolha a versão do backup (data/hora)
5. Navegue e selecione o arquivo desejado
6. Escolha o destino da restauração
7. Clique em **"Restaurar"**

### Restauração de Serviço Completo

Exemplo: Restaurar todos os workflows do n8n

1. Selecione o trabalho de backup
2. Clique em **"Restaurar"**
3. Escolha a versão do backup
4. Selecione todo o diretório: `/source/n8n`
5. Restaurar para: `/tmp/n8n-restore/`
6. Clique em **"Restaurar"**
7. Pare o serviço n8n: `docker compose stop n8n`
8. Copie os dados restaurados para o volume: `docker compose cp /tmp/n8n-restore/* n8n:/home/node/.n8n/`
9. Inicie o serviço: `docker compose start n8n`
10. Verifique se o serviço iniciou corretamente

### Restauração Completa do Sistema (Disaster Recovery)

Para recuperação completa após perda total de dados:

1. **Reinstale o BorgStack** no novo servidor
2. **Não inicie os serviços** ainda (não execute `docker compose up`)
3. **Acesse o Duplicati**: `docker compose up -d duplicati`
4. **Acesse a interface web** e faça login
5. **Importe a configuração de backup**:
   - Se você exportou a configuração: Configurações → Importar
   - Se não: Recrie o trabalho de backup manualmente com as mesmas credenciais
6. **Execute restauração completa**:
   - Selecione o backup
   - Clique em "Restaurar"
   - Escolha a versão mais recente
   - Selecione TODOS os diretórios `/source/*`
   - Clique em "Restaurar"
7. **Aguarde a conclusão** (pode levar horas dependendo do tamanho)
8. **Inicie todos os serviços**: `docker compose up -d`
9. **Verifique a saúde de todos os serviços**: `docker compose ps`
10. **Teste cada aplicação** para confirmar funcionamento

## Monitoramento e Alertas

### Notificações por Email

Configure notificações por email para sucesso/falha de backup:

1. Edite o trabalho de backup
2. Vá para **Opções** → **Avançado**
3. Encontre as opções **"Enviar email"**:
   - `send-mail-to`: Seu endereço de email
   - `send-mail-from`: `noreply@{SEU_DOMINIO}`
   - `send-mail-url`: `smtp://smtp.exemplo.com:587`
   - `send-mail-username`: Usuário SMTP
   - `send-mail-password`: Senha SMTP
   - `send-mail-level`: `Success,Warning,Error` (enviar em qualquer situação)
4. Teste o email: Envie um relatório de backup de teste

### Integração com n8n (Webhooks)

Para integrar com workflows do n8n:

1. Crie um workflow no n8n com trigger Webhook
2. Copie a URL do webhook (ex: `http://n8n:5678/webhook/backup-completo`)
3. Edite o trabalho de backup → **Opções** → **Avançado**
4. Adicione **"Executar script após backup"**:
   ```bash
   curl -X POST http://n8n:5678/webhook/backup-completo \
     -H "Content-Type: application/json" \
     -d '{"status":"concluido","job":"BorgStack-Backup-Completo","timestamp":"'$(date -Iseconds)'"}'
   ```

## Manutenção

### Limpeza Manual de Backups Antigos

Se precisar liberar espaço:

1. Selecione o trabalho de backup
2. Clique em **"Excluir backups antigos"**
3. O Duplicati aplicará a política de retenção configurada
4. Confirme a exclusão

### Exportar Configuração de Backup

⚠️ **IMPORTANTE**: Exporte a configuração regularmente!

1. Vá para **Configurações** (ícone de engrenagem)
2. Clique em **"Exportar"**
3. Salve o arquivo JSON em local seguro
4. **Armazene separadamente** dos backups (ex: em gerenciador de senhas)

### Atualização do Duplicati

Para atualizar o Duplicati:

1. Faça backup da configuração (exporte)
2. Pare o serviço: `docker compose stop duplicati`
3. Atualize a versão da imagem no `docker-compose.yml`
4. Atualize o container: `docker compose up -d duplicati`
5. Verifique logs: `docker compose logs duplicati`
6. Acesse a interface web e confirme funcionamento

## Solução de Problemas

### Backup Falha: "Acesso Negado"

**Causa**: Duplicati não consegue ler volumes Docker
**Solução**: Verifique se Duplicati está rodando como root (PUID=0, PGID=0 no docker-compose.yml)

### Backup Falha: "Erro de Conexão"

**Causa**: Não consegue alcançar destino de backup
**Solução**:
1. Verifique conectividade com internet do container:
   ```bash
   docker compose exec duplicati curl -I https://s3.amazonaws.com
   ```
2. Verifique credenciais do destino
3. Teste conexão na interface web do Duplicati

### Restauração Falha: "Senha Incorreta"

**Causa**: DUPLICATI_PASSPHRASE incorreta
**Solução**: **NÃO HÁ RECUPERAÇÃO SE A SENHA FOR PERDIDA!**
- Verifique gerenciador de senhas pela senha correta
- Verifique arquivo `.env` pela senha correta
- Tente variações (espaços, caracteres especiais)

### Alto Uso de Armazenamento

**Causa**: Política de retenção mantendo muitas versões
**Solução**:
1. Revise política de retenção (`7D:1D,4W:1W,12M:1M`)
2. Execute **"Excluir backups antigos"** manualmente
3. Ajuste configurações de retenção para política menos agressiva

### Backup Lento

**Causas possíveis**:
- Velocidade de upload da internet limitada
- Muitos dados mudaram desde último backup
- Compressão/criptografia consumindo CPU

**Soluções**:
- Execute backups em horários de baixo tráfego
- Aumente `dblock-size` para 100MB (uploads maiores)
- Considere backup diferencial semanal em vez de diário

## Melhores Práticas de Segurança

### 1. Segurança da Senha de Criptografia

- ✅ Armazene em gerenciador de senhas (1Password, Bitwarden, LastPass)
- ✅ Compartilhe com equipe via canais criptografados
- ✅ Escreva e guarde em cofre físico
- ❌ NUNCA commite a senha no git
- ❌ NUNCA envie por email ou chat não criptografado

### 2. Controle de Acesso

- Troque `DUPLICATI_PASSWORD` regularmente (trimestral)
- Use senhas fortes e únicas (mínimo 32 caracteres)
- Restrinja acesso à interface web via whitelist de IP no Caddy (opcional)

### 3. Segurança do Destino de Backup

- Use credenciais dedicadas para armazenamento de backup (não contas admin)
- Ative MFA na conta do provedor de backup
- Restrinja permissões de bucket/pasta para write-only (backups append-only)

### 4. Testes

- ✅ Teste restauração **mensalmente**
- ✅ Documente procedimentos de restauração
- ✅ Treine equipe em processo de disaster recovery
- ✅ Simule recuperação completa do sistema anualmente

## Conformidade com LGPD

### Criptografia de Dados

- **Todos os dados são criptografados ANTES do upload** usando AES-256
- Provedor de backup não consegue ler seus dados (criptografia zero-knowledge)
- Dados protegidos mesmo se provedor for comprometido
- Atende requisitos de criptografia da LGPD

### Localização dos Dados

Para conformidade com LGPD, recomendamos:

1. **AWS S3 São Paulo (sa-east-1)**: Dados permanecem no Brasil
2. **Backblaze B2**: Selecione região US ou EU, mas dados criptografados antes do upload
3. **NAS/SFTP local**: Controle total, dados nunca saem das instalações

### Trilha de Auditoria

O Duplicati mantém logs de todas as operações de backup:
- Histórico de execução de trabalhos de backup
- Versões de arquivos e timestamps
- Operações de restauração

Acesse logs via interface web → Aba **Log**

## 8. Dicas e Melhores Práticas

### 8.1 Configuração Otimizada
Consulte [docs/02-configuracao.md](../02-configuracao.md) para variáveis de ambiente específicas deste serviço.

### 8.2 Performance
- Consultar documentação oficial para tuning de duplicati
- Monitorar uso de recursos
- Configurar limites apropriados

### 8.3 Segurança
- Senhas fortes
- API keys rotacionadas
- Acesso restrito via rede interna

### 8.4 Monitoramento
- Health checks ativos
- Logs de erro
- Performance metrics

### 8.5 Casos de Uso
Ver workflows de exemplo em [docs/09-workflows-exemplo.md](../09-workflows-exemplo.md)

---

## Recursos Adicionais

- **Documentação do Duplicati**: https://duplicati.readthedocs.io/
- **Guia de Estratégia de Backup**: `docs/04-integrations/backup-strategy.md`
- **Benchmarks de Tempo de Restauração**: `docs/04-integrations/restore-benchmarks.md`
- **Configurações de Exemplo**: `config/duplicati/backup-config-example.json`

## Comandos de Backup Manual (Emergência)

Se o Duplicati estiver indisponível, use comandos de backup manual:

```bash
# Backup PostgreSQL
docker compose exec postgresql pg_dumpall -U postgres > backup-postgresql-$(date +%Y%m%d).sql

# Backup MongoDB
docker compose exec mongodb mongodump --username admin --password ${MONGODB_ROOT_PASSWORD} --authenticationDatabase admin --out /tmp/mongo-backup

# Backup de volume (exemplo: n8n)
docker compose exec n8n tar czf - /home/node/.n8n > n8n-backup-$(date +%Y%m%d).tar.gz
```

**Nota**: Estes são procedimentos de emergência. Backups automatizados do Duplicati são recomendados para produção.

## Suporte

Para problemas ou dúvidas:
1. Consulte a documentação do Duplicati
2. Verifique logs: `docker compose logs duplicati`
3. Revise este guia e as FAQs
4. Contate o suporte técnico do BorgStack
