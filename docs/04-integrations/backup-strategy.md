# Estratégia de Backup e Recuperação de Desastres

Este documento descreve a estratégia de backup do BorgStack e procedimentos detalhados de recuperação de desastres.

## Visão Geral da Estratégia

### Objetivos de Backup

- **RPO (Recovery Point Objective)**: ≤ 24 horas (backups diários às 2:00)
- **RTO (Recovery Time Objective)**: ≤ 4 horas para restauração completa do sistema
- **Retenção**: 7 diários + 4 semanais + 12 mensais
- **Criptografia**: AES-256 antes do upload (zero-knowledge)
- **Localização**: Brasil (conformidade LGPD)

### Componentes do Sistema de Backup

```text
┌─────────────────────────────────────────────────────────────┐
│                     BorgStack Services                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │PostgreSQL│  │ MongoDB  │  │  Redis   │  │SeaweedFS │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
│       │             │              │             │          │
│       └─────────────┴──────────────┴─────────────┘          │
│                         │                                    │
│                    ┌────▼─────┐                             │
│                    │ Duplicati │ (Backup Engine)            │
│                    └────┬─────┘                             │
└─────────────────────────┼───────────────────────────────────┘
                          │
                    Criptografia AES-256
                          │
                ┌─────────▼──────────┐
                │  Backup Destination │
                │                     │
                │ • AWS S3 (São Paulo)│
                │ • Backblaze B2      │
                │ • SFTP Local        │
                └─────────────────────┘
```text

## Cenários de Recuperação

### Cenário 1: Restauração de Arquivo Individual

**Situação**: Usuário deletou acidentalmente um arquivo ou workflow

**Tempo estimado**: 5-15 minutos

**Procedimento**:

1. Acesse a interface web do Duplicati: `https://duplicati.{SEU_DOMINIO}`
2. Faça login com `DUPLICATI_PASSWORD`
3. Selecione o trabalho de backup: `BorgStack-Backup-Completo`
4. Clique em **"Restaurar"**
5. Escolha a versão do backup:
   - Para arquivo deletado hoje: Backup de ontem (mais recente antes da exclusão)
   - Para versão anterior de arquivo: Navegue pelas versões disponíveis
6. Navegue até o arquivo desejado (ex: `/source/n8n/workflows/workflow-123.json`)
7. Selecione o arquivo
8. Escolha destino de restauração: `/tmp/restore-temp/`
9. Clique em **"Restaurar"**
10. Aguarde conclusão (1-5 minutos para arquivo pequeno)
11. Copie o arquivo restaurado para o local correto:
    ```bash
    docker compose cp /tmp/restore-temp/workflow-123.json n8n:/home/node/.n8n/workflows/
    ```
12. Reinicie o serviço se necessário:
    ```bash
    docker compose restart n8n
    ```
13. Limpe arquivos temporários:
    ```bash
    docker compose exec duplicati rm -rf /tmp/restore-temp/
    ```

**Validação**:
- Verifique se o arquivo foi restaurado corretamente
- Teste funcionalidade (ex: execute workflow no n8n)

---

### Cenário 2: Restauração de Serviço Completo

**Situação**: Um serviço completo precisa ser restaurado (ex: todos workflows n8n corrompidos)

**Tempo estimado**: 30 minutos - 2 horas

#### Exemplo: Restaurar todos os workflows do n8n

**Procedimento**:

1. **Identifique a versão do backup** a ser restaurada
   - Acesse Duplicati web UI
   - Verifique qual backup contém os dados corretos
   - Anote a data/hora do backup

2. **Pare o serviço afetado**:
   ```bash
   docker compose stop n8n
   ```

3. **Inicie a restauração via Duplicati**:
   - Selecione o trabalho de backup
   - Clique em **"Restaurar"**
   - Escolha a versão do backup identificada no passo 1
   - Selecione todo o diretório: `/source/n8n`
   - Restaurar para: `/tmp/n8n-restore/`
   - Clique em **"Restaurar"**

4. **Aguarde conclusão da restauração** (10-60 minutos dependendo do tamanho)

5. **Backup dos dados atuais** (medida de segurança):
   ```bash
   docker compose exec n8n tar czf /tmp/n8n-backup-antes-restore-$(date +%Y%m%d-%H%M).tar.gz /home/node/.n8n/
   ```

6. **Substitua os dados**:
   ```bash
   # Remove dados corrompidos
   docker volume rm borgstack_borgstack_n8n_data

   # Recria volume
   docker volume create borgstack_borgstack_n8n_data

   # Copia dados restaurados
   docker compose run --rm -v /tmp/n8n-restore:/restore n8n sh -c "cp -a /restore/* /home/node/.n8n/"
   ```

7. **Inicie o serviço**:
   ```bash
   docker compose start n8n
   ```

8. **Verifique logs**:
   ```bash
   docker compose logs n8n --tail 100
   ```

9. **Teste funcionalidade**:
   - Acesse n8n web UI
   - Verifique se workflows estão presentes
   - Execute workflow de teste

10. **Limpe arquivos temporários**:
    ```bash
    docker compose exec duplicati rm -rf /tmp/n8n-restore/
    ```

**Validação**:
- ✅ Serviço inicia sem erros
- ✅ Dados estão presentes e acessíveis
- ✅ Funcionalidade testada e confirmada

---

### Cenário 3: Restauração de Banco de Dados

**Situação**: Banco de dados PostgreSQL corrompido ou dados perdidos

**Tempo estimado**: 1-3 horas

#### Exemplo: Restaurar banco de dados PostgreSQL completo

**Procedimento**:

1. **Identifique o problema**:
   - Qual banco está afetado? (n8n_db, chatwoot_db, directus_db, evolution_db)
   - Quando ocorreu a corrupção? (para escolher versão correta do backup)

2. **Crie backup de segurança dos dados atuais**:
   ```bash
   docker compose exec postgresql pg_dumpall -U postgres > backup-pre-restore-$(date +%Y%m%d-%H%M).sql
   ```

3. **Restaure volume PostgreSQL via Duplicati**:
   - Acesse Duplicati web UI
   - Selecione trabalho de backup
   - Clique em **"Restaurar"**
   - Escolha versão do backup (antes da corrupção)
   - Selecione: `/source/postgresql`
   - Restaurar para: `/tmp/postgresql-restore/`
   - Clique em **"Restaurar"**
   - Aguarde conclusão (pode levar 1-2 horas para volumes grandes)

4. **Pare todos os serviços que usam PostgreSQL**:
   ```bash
   docker compose stop n8n chatwoot directus evolution postgresql
   ```

5. **Remova volume PostgreSQL atual**:
   ```bash
   docker volume rm borgstack_borgstack_postgresql_data
   ```

6. **Recrie volume e restaure dados**:
   ```bash
   # Recria volume
   docker volume create borgstack_borgstack_postgresql_data

   # Inicia PostgreSQL temporariamente
   docker compose up -d postgresql

   # Aguarda inicialização
   sleep 30

   # Restaura dados
   docker compose exec -T postgresql psql -U postgres < /tmp/postgresql-restore/backup.sql
   ```

   **Alternativa** - Restaurar apenas um banco específico:
   ```bash
   docker compose exec -T postgresql psql -U postgres -d n8n_db < /tmp/postgresql-restore/n8n_db.sql
   ```

7. **Reinicie PostgreSQL**:
   ```bash
   docker compose restart postgresql
   ```

8. **Verifique saúde do PostgreSQL**:
   ```bash
   docker compose exec postgresql pg_isready -U postgres
   docker compose exec postgresql psql -U postgres -c "\l"
   ```

9. **Inicie serviços dependentes**:
   ```bash
   docker compose start n8n chatwoot directus evolution
   ```

10. **Verifique logs de todos os serviços**:
    ```bash
    docker compose logs n8n chatwoot directus evolution --tail 50
    ```

11. **Teste funcionalidade**:
    - Acesse cada serviço via web UI
    - Verifique se dados estão presentes
    - Execute operação de teste (ex: criar/editar registro)

**Validação**:
- ✅ PostgreSQL inicia sem erros
- ✅ Todos os bancos estão presentes: `\l` no psql
- ✅ Serviços conectam ao banco sem erros
- ✅ Dados estão íntegros e acessíveis

---

### Cenário 4: Restauração Completa do Sistema (Disaster Recovery)

**Situação**: Perda total do servidor (falha de hardware, ataque, perda de datacenter)

**Tempo estimado**: 4-8 horas (dependendo do tamanho dos dados)

**Pré-requisitos**:
- ✅ Novo servidor provisionado (Ubuntu 24.04)
- ✅ Acesso SSH ao servidor
- ✅ DNS apontando para novo servidor
- ✅ Credenciais de backup disponíveis
- ✅ `DUPLICATI_PASSPHRASE` disponível (CRÍTICO!)

#### Fase 1: Preparação do Servidor

**1.1. Instale o BorgStack no novo servidor**:

```bash
# Clone repositório
git clone https://github.com/seu-usuario/borgstack.git
cd borgstack

# Execute bootstrap
sudo ./scripts/bootstrap.sh
```text

**1.2. Configure arquivo .env**:

```bash
# Copie template
cp .env.example .env

# Edite e configure TODAS as variáveis
nano .env

# CRÍTICO: Configure credenciais de backup
# DUPLICATI_PASSWORD=<sua-senha>
# DUPLICATI_ENCRYPTION_KEY=<sua-chave>
# DUPLICATI_PASSPHRASE=<CRÍTICO-senha-de-criptografia>
```text

**1.3. NÃO inicie todos os serviços ainda**:

```bash
# Inicie APENAS Duplicati
docker compose up -d duplicati

# Verifique se iniciou
docker compose ps duplicati
```text

#### Fase 2: Configuração do Duplicati

**2.1. Acesse interface web**:
- URL: `https://duplicati.{SEU_DOMINIO}` ou `http://{IP_SERVIDOR}:8200`
- Login com `DUPLICATI_PASSWORD`

**2.2. Restaure configuração de backup**:

**Opção A**: Se você exportou a configuração anteriormente
- Vá para **Configurações** → **Importar**
- Selecione arquivo JSON exportado
- Clique em **Importar**

**Opção B**: Recrie trabalho de backup manualmente
- Clique em **"Adicionar backup"**
- Configure EXATAMENTE como estava antes:
  - Nome: `BorgStack-Backup-Completo`
  - Criptografia: AES-256
  - Passphrase: `DUPLICATI_PASSPHRASE` (CRÍTICO - deve ser a mesma!)
  - Destino: Mesmo provedor e credenciais
  - Fontes: TODOS os diretórios `/source/*`

**2.3. Teste conexão com backup**:
- Clique em **"Testar conexão"**
- Verifique se encontra os backups existentes
- Se não encontrar: VERIFIQUE A PASSPHRASE!

#### Fase 3: Restauração de Dados

**3.1. Liste versões de backup disponíveis**:
- Selecione o trabalho de backup
- Clique em **"Restaurar"**
- Visualize versões disponíveis
- Escolha o backup mais recente OU versão específica antes de incidente

**3.2. Execute restauração completa**:

⚠️ **ATENÇÃO**: Esta operação pode levar várias horas!

- Selecione o backup escolhido
- Selecione **TODOS** os diretórios de origem:
  ```
  ✅ /source/postgresql
  ✅ /source/mongodb
  ✅ /source/redis
  ✅ /source/seaweedfs_master
  ✅ /source/seaweedfs_volume
  ✅ /source/seaweedfs_filer
  ✅ /source/n8n
  ✅ /source/evolution
  ✅ /source/chatwoot_storage
  ✅ /source/lowcoder_stacks
  ✅ /source/directus_uploads
  ✅ /source/fileflows_data
  ✅ /source/fileflows_logs
  ✅ /source/fileflows_input
  ✅ /source/fileflows_output
  ✅ /source/caddy
  ```
- Destino da restauração: Mantenha caminhos originais (restaurar no lugar)
- Clique em **"Restaurar"**

**3.3. Monitore progresso**:
- Acompanhe progresso na interface do Duplicati
- Verifique logs: `docker compose logs duplicati -f`
- **Tempo estimado**:
  - 10 GB: ~1 hora
  - 50 GB: ~2-3 horas
  - 100 GB: ~4-6 horas
  - (Depende da velocidade de download do provedor de backup)

#### Fase 4: Inicialização dos Serviços

**4.1. Após restauração concluída, inicie todos os serviços**:

```bash
docker compose up -d
```text

**4.2. Monitore inicialização**:

```bash
# Veja status de todos os serviços
watch docker compose ps

# Aguarde até todos mostrarem "healthy"
# Isso pode levar 5-10 minutos
```text

**4.3. Verifique logs de cada serviço**:

```bash
# PostgreSQL
docker compose logs postgresql --tail 50

# n8n
docker compose logs n8n --tail 50

# Chatwoot
docker compose logs chatwoot --tail 50

# Todos os serviços
docker compose logs --tail 20
```text

#### Fase 5: Validação e Testes

**5.1. Teste de conectividade básica**:

```bash
# Teste saúde de todos os serviços
./tests/deployment/verify-services.sh

# Ou manualmente
docker compose ps
```text

**5.2. Teste funcional de cada serviço**:

| Serviço | URL | Teste |
|---------|-----|-------|
| n8n | `https://n8n.{DOMINIO}` | Login, visualizar workflows |
| Chatwoot | `https://chatwoot.{DOMINIO}` | Login, verificar conversas |
| Evolution API | `https://evolution.{DOMINIO}` | API health check |
| Lowcoder | `https://lowcoder.{DOMINIO}` | Login, abrir aplicativo |
| Directus | `https://directus.{DOMINIO}` | Login, visualizar coleções |
| FileFlows | `https://fileflows.{DOMINIO}` | Login, verificar flows |
| Duplicati | `https://duplicati.{DOMINIO}` | Login, verificar backups |

**5.3. Teste de integridade de dados**:

```bash
# PostgreSQL - verifique bancos
docker compose exec postgresql psql -U postgres -c "\l"

# MongoDB - verifique collections
docker compose exec mongodb mongosh --username admin --password ${MONGODB_ROOT_PASSWORD} --eval "db.getMongo().getDBNames()"

# Redis - verifique conectividade
docker compose exec redis redis-cli -a ${REDIS_PASSWORD} ping

# SeaweedFS - teste S3 API
docker compose exec seaweedfs weed shell << EOF
s3.bucket.list
exit
EOF
```text

**5.4. Teste funcionalidade crítica**:

- [ ] n8n: Execute workflow de teste
- [ ] Chatwoot: Envie mensagem de teste
- [ ] Evolution API: Verifique instâncias WhatsApp conectadas
- [ ] Lowcoder: Abra e teste aplicativo
- [ ] Directus: Crie/edite item de teste
- [ ] FileFlows: Execute flow de processamento

**5.5. Configure novo backup**:

```bash
# Execute backup imediatamente para criar baseline no novo servidor
# Via web UI: Selecione backup → "Executar agora"
# OU via script
./scripts/backup-now.sh
```text

#### Fase 6: Documentação e Revisão

**6.1. Documente a recuperação**:

Crie registro da recuperação:
```text
Data: [DATA]
Servidor original: [IP/HOSTNAME]
Servidor novo: [IP/HOSTNAME]
Versão backup restaurada: [DATA/HORA]
Tempo total de recuperação: [HORAS]
Problemas encontrados: [LISTA]
Lições aprendidas: [LISTA]
```text

**6.2. Atualize procedimentos** se necessário

**6.3. Notifique stakeholders** da conclusão da recuperação

---

## Testes de Disaster Recovery

### Frequência Recomendada

- **Teste parcial** (restaurar serviço único): **Mensal**
- **Teste completo** (disaster recovery total): **Trimestral**
- **Simulação com equipe**: **Semestral**

### Checklist de Teste de DR

```text
□ Documentação de DR está atualizada
□ Credenciais de backup estão acessíveis
□ DUPLICATI_PASSPHRASE está armazenada em local seguro
□ Backup mais recente foi verificado com sucesso
□ Servidor de teste provisionado
□ Teste de restauração de arquivo individual: PASSOU
□ Teste de restauração de serviço completo: PASSOU
□ Teste de restauração de banco de dados: PASSOU
□ Tempo de recuperação dentro do RTO (≤ 4 horas): SIM/NÃO
□ Equipe treinada em procedimentos de DR
□ Lessons learned documentadas
```text

## Procedimentos de Rollback

### Se a Restauração Falhar

1. **NÃO entre em pânico**
2. **Preserve evidências**:
   ```bash
   # Capture logs
   docker compose logs > logs-falha-restore-$(date +%Y%m%d-%H%M).txt

   # Capture estado dos containers
   docker compose ps > containers-falha-restore-$(date +%Y%m%d-%H%M).txt
   ```

3. **Identifique o problema**:
   - Senha de criptografia incorreta?
   - Falha de conectividade com backup?
   - Corrupção de dados durante restauração?
   - Espaço em disco insuficiente?

4. **Tente versão anterior do backup**:
   - Escolha backup de 1 dia anterior
   - Repita processo de restauração

5. **Se múltiplas tentativas falharem**:
   - Restaure componentes individualmente (PostgreSQL → MongoDB → Redis → etc)
   - Contate suporte técnico
   - Considere restauração manual via dumps de banco de dados

## Procedimentos de Backup Manual (Emergência)

### Quando Duplicati está Indisponível

**Backup PostgreSQL**:
```bash
# Todos os bancos
docker compose exec postgresql pg_dumpall -U postgres > backup-postgresql-$(date +%Y%m%d-%H%M).sql

# Banco específico
docker compose exec postgresql pg_dump -U postgres -d n8n_db > backup-n8n-$(date +%Y%m%d-%H%M).sql
```text

**Backup MongoDB**:
```bash
docker compose exec mongodb mongodump \
  --username admin \
  --password ${MONGODB_ROOT_PASSWORD} \
  --authenticationDatabase admin \
  --out /tmp/mongo-backup-$(date +%Y%m%d-%H%M)
```text

**Backup de Volumes**:
```bash
# Exemplo: n8n
docker compose exec n8n tar czf - /home/node/.n8n > n8n-backup-$(date +%Y%m%d-%H%M).tar.gz

# Exemplo: Evolution API
docker compose exec evolution tar czf - /evolution/instances > evolution-backup-$(date +%Y%m%d-%H%M).tar.gz
```text

## Contatos de Emergência

Em caso de disaster recovery:

1. **Administrador de Sistema**: [PREENCHER]
2. **Equipe de Suporte BorgStack**: [PREENCHER]
3. **Provedor de Backup** (AWS/Backblaze): [PREENCHER]
4. **Provedor de Hosting**: [PREENCHER]

## Recursos Adicionais

- **Guia de Uso do Duplicati**: `docs/03-services/duplicati.md`
- **Benchmarks de Restauração**: `docs/04-integrations/restore-benchmarks.md`
- **Scripts de Automação**: `scripts/backup-now.sh`, `scripts/restore.sh`
- **Testes de Deployment**: `tests/deployment/verify-duplicati.sh`
