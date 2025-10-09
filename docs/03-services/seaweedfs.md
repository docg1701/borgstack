# SeaweedFS - Armazenamento de Objetos S3

## O que é SeaweedFS?

SeaweedFS é um sistema de armazenamento distribuído de objetos compatível com S3, desenvolvido para armazenar e servir bilhões de arquivos de forma rápida e eficiente. No BorgStack, o SeaweedFS fornece armazenamento centralizado para todos os serviços que trabalham com arquivos (Directus, FileFlows, Chatwoot, n8n).

**Principais características:**

- **Compatibilidade S3**: API totalmente compatível com Amazon S3 (AWS SDK, s3cmd, boto3)
- **Distribuído**: Escala horizontalmente adicionando mais servidores
- **Eficiente**: Armazena milhões de arquivos com baixa latência
- **Simples**: Modo servidor unificado para implantações de servidor único
- **Open Source**: Software livre sob licença Apache 2.0

**Quando usar SeaweedFS:**

- ✅ Armazenar uploads de usuários (imagens, vídeos, documentos)
- ✅ Processar mídia (FileFlows converte vídeos armazenados no SeaweedFS)
- ✅ Anexos de conversas (Chatwoot salva arquivos de chat)
- ✅ Arquivos de workflow (n8n processa arquivos via HTTP Request)
- ✅ Assets de CMS (Directus usa para armazenar assets do headless CMS)

## Arquitetura do SeaweedFS

O SeaweedFS opera em **modo servidor unificado** no BorgStack, onde todos os componentes rodam em um único container:

```
┌─────────────────────────────────────────────────────────────┐
│                   Container SeaweedFS                       │
│                                                             │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────┐ │
│  │ Master Server  │  │ Volume Server  │  │    Filer     │ │
│  │   (porta 9333) │  │   (porta 8080) │  │ (porta 8888) │ │
│  │                │  │                │  │              │ │
│  │ • Topologia    │  │ • Armazena     │  │ • Sistema de │ │
│  │ • Alocação de  │  │   arquivos     │  │   arquivos   │ │
│  │   volumes      │  │ • Lê/escreve   │  │ • Metadados  │ │
│  └────────────────┘  └────────────────┘  └──────────────┘ │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │              S3 API (porta 8333)                      │ │
│  │  • Interface HTTP compatível com Amazon S3            │ │
│  │  • Autenticação AWS Signature v4                      │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

**Componentes:**

1. **Master Server (porta 9333)**
   - Gerencia topologia do cluster
   - Aloca volumes para armazenamento
   - Rastreia status dos servidores

2. **Volume Server (porta 8080)**
   - Armazena arquivos em volumes (arquivos .dat e .idx)
   - Realiza leitura e escrita de dados
   - Gerencia replicação (quando configurado)

3. **Filer (porta 8888)**
   - Abstração de sistema de arquivos
   - Mapeia caminhos S3 → chunks de volumes
   - Armazena metadados de arquivos

4. **S3 API (porta 8333)**
   - Interface HTTP compatível com S3
   - Aceita requisições AWS SDK
   - Autenticação via access key + secret key

## Acessando o S3 API

### Endpoint Interno (Serviços BorgStack)

Todos os serviços BorgStack acessam o SeaweedFS via rede interna Docker:

```bash
Endpoint S3: http://seaweedfs:8333
Região: us-east-1
```

**Serviços que usam S3:**

- **Directus**: Assets do CMS
- **FileFlows**: Mídia processada (via workflows n8n)
- **Chatwoot**: Anexos de conversas
- **n8n**: Anexos de workflows (via HTTP Request nodes)

### Credenciais de Acesso

As credenciais S3 são configuradas no arquivo `.env`:

```bash
SEAWEEDFS_ACCESS_KEY=sua-chave-de-acesso-32-chars
SEAWEEDFS_SECRET_KEY=sua-chave-secreta-64-chars
```

**Gerar credenciais fortes:**

```bash
# Access Key (32 caracteres)
openssl rand -base64 24

# Secret Key (64 caracteres)
openssl rand -base64 48
```

⚠️ **Importante**: Guarde estas credenciais em local seguro. Elas são necessárias para todos os clientes S3.

### Acesso Externo (Opcional)

Por padrão, a API S3 está disponível apenas na rede interna (`borgstack_internal`) por segurança.

Para habilitar acesso externo via HTTPS:

1. Adicione ao `.env`:
   ```bash
   SEAWEEDFS_HOST=s3.seudominio.com
   ```

2. Configure reverse proxy Caddy (veja `config/caddy/Caddyfile`)

3. Adicione SeaweedFS à rede `borgstack_external` no `docker-compose.yml`

⚠️ **Atenção**: Apenas exponha externamente se realmente necessário. Acesso interno é mais seguro.

## Estrutura de Buckets

O SeaweedFS usa um bucket principal com subdiretórios para cada serviço:

```
/buckets/
  borgstack/                      # Bucket principal
    n8n/                          # Anexos de workflows n8n
    chatwoot/                     # Arquivos do Chatwoot
      avatars/                    # Avatares de usuários
      messages/                   # Anexos de mensagens
      uploads/                    # Uploads gerais
    directus/                     # Assets do Directus CMS
      originals/                  # Arquivos originais
      thumbnails/                 # Miniaturas geradas
      documents/                  # Documentos
    fileflows/                    # Mídia do FileFlows
      input/                      # Arquivos para processar
      output/                     # Arquivos processados
      temp/                       # Arquivos temporários
    lowcoder/                     # Assets de aplicativos Lowcoder
    duplicati/                    # Área de staging de backups
```

**Por que um único bucket?**

- Gerenciamento de permissões mais simples
- Backup mais fácil (snapshot de um único bucket)
- Endpoint S3 consistente entre serviços
- Alinha-se com melhores práticas S3 (use prefixos, não buckets excessivos)

## Fazendo Upload de Arquivos

### AWS CLI

```bash
# Configurar AWS CLI
aws configure set aws_access_key_id $SEAWEEDFS_ACCESS_KEY
aws configure set aws_secret_access_key $SEAWEEDFS_SECRET_KEY
aws configure set default.region us-east-1
aws configure set default.s3.signature_version s3v4

# Listar buckets
aws --endpoint-url http://localhost:8333 s3 ls

# Listar arquivos no bucket borgstack
aws --endpoint-url http://localhost:8333 s3 ls s3://borgstack/

# Upload de arquivo
aws --endpoint-url http://localhost:8333 s3 cp arquivo.jpg s3://borgstack/n8n/

# Upload de diretório inteiro
aws --endpoint-url http://localhost:8333 s3 sync ./meus-arquivos/ s3://borgstack/directus/
```

### s3cmd

Crie `~/.s3cfg`:

```ini
[default]
access_key = SUA_SEAWEEDFS_ACCESS_KEY
secret_key = SUA_SEAWEEDFS_SECRET_KEY
host_base = localhost:8333
host_bucket = localhost:8333/%(bucket)
use_https = False
signature_v2 = False
```

Uso:

```bash
# Listar buckets
s3cmd ls

# Upload de arquivo
s3cmd put foto.png s3://borgstack/chatwoot/avatars/

# Upload com metadados
s3cmd put video.mp4 s3://borgstack/fileflows/input/ --mime-type=video/mp4
```

### Python boto3

```python
import boto3
from botocore.client import Config

# Criar cliente S3
s3 = boto3.client(
    's3',
    endpoint_url='http://seaweedfs:8333',
    aws_access_key_id='SUA_ACCESS_KEY',
    aws_secret_access_key='SUA_SECRET_KEY',
    config=Config(signature_version='s3v4'),
    region_name='us-east-1'
)

# Upload de arquivo
with open('documento.pdf', 'rb') as f:
    s3.put_object(
        Bucket='borgstack',
        Key='directus/documents/documento.pdf',
        Body=f,
        ContentType='application/pdf'
    )

# Upload com metadados customizados
s3.put_object(
    Bucket='borgstack',
    Key='chatwoot/messages/anexo.txt',
    Body='Conteúdo do arquivo',
    Metadata={'author': 'João', 'department': 'Vendas'}
)
```

## Fazendo Download de Arquivos

### AWS CLI

```bash
# Download de arquivo
aws --endpoint-url http://localhost:8333 s3 cp s3://borgstack/n8n/arquivo.jpg ./

# Download de diretório inteiro
aws --endpoint-url http://localhost:8333 s3 sync s3://borgstack/directus/originals/ ./downloads/

# Listar arquivos de um prefixo
aws --endpoint-url http://localhost:8333 s3 ls s3://borgstack/fileflows/output/
```

### s3cmd

```bash
# Download de arquivo
s3cmd get s3://borgstack/chatwoot/avatars/foto.png ./

# Download recursivo
s3cmd get --recursive s3://borgstack/directus/ ./backup-directus/
```

### Python boto3

```python
# Download de arquivo
s3.download_file('borgstack', 'directus/documents/relatorio.pdf', 'relatorio-local.pdf')

# Download para memória
response = s3.get_object(Bucket='borgstack', Key='n8n/dados.json')
conteudo = response['Body'].read().decode('utf-8')

# Gerar URL temporária de download (válida por 1 hora)
url = s3.generate_presigned_url(
    'get_object',
    Params={'Bucket': 'borgstack', 'Key': 'fileflows/output/video.mp4'},
    ExpiresIn=3600
)
print(f"Link temporário: {url}")
```

## Gerenciamento de Volumes

### Verificar Status do Cluster

```bash
# Status geral do cluster
curl http://localhost:9333/cluster/status

# Topologia de volumes
curl http://localhost:9333/dir/status

# Status de volumes individuais
curl http://localhost:9333/vol/status
```

### Crescer Volumes Manualmente

O SeaweedFS cria novos volumes automaticamente quando os existentes enchem. Para pré-alocar volumes:

```bash
# Crescer 4 volumes com replicação 000 (servidor único)
curl "http://localhost:9333/vol/grow?count=4&replication=000"

# Verificar volumes criados
curl http://localhost:9333/dir/status
```

### Monitorar Uso de Armazenamento

```bash
# Uso de disco do volume server
docker compose exec seaweedfs df -h /data/volume

# Tamanho do banco de dados filer
docker compose exec seaweedfs du -sh /data/filer

# Tamanho dos metadados master
docker compose exec seaweedfs du -sh /data/master
```

### Configuração de Volumes

**Limite de tamanho por volume** (`.env`):

```bash
SEAWEEDFS_VOLUME_SIZE_LIMIT_MB=10240  # 10GB (padrão)
```

**Máximo de volumes** (`.env`):

```bash
SEAWEEDFS_MAX_VOLUMES=100  # 100 volumes (padrão)
# Capacidade total = 10GB × 100 = 1TB
```

**Pré-alocação de volumes** (`.env`):

```bash
SEAWEEDFS_VOLUME_PREALLOCATE=false  # Padrão: desabilitado
# true = pré-aloca espaço em disco (melhor performance, mais espaço usado)
```

## Estratégia de Replicação

### Configuração Atual (Servidor Único)

```bash
SEAWEEDFS_REPLICATION=000
```

**Formato**: `XYZ` onde:
- **X** = Cópias em datacenters diferentes
- **Y** = Cópias em racks diferentes
- **Z** = Cópias em servidores diferentes

**`000`** = Sem replicação (modo servidor único)

⚠️ **Atenção**: Sem replicação, a perda do servidor = perda de dados. Use backups com Duplicati.

### Expansão Multi-Servidor

Ao adicionar servidores para redundância:

1. Atualize `.env`:
   ```bash
   SEAWEEDFS_REPLICATION=001  # 1 cópia em servidor diferente
   ```

2. Implante servidores de volume adicionais

3. Reinicie SeaweedFS master:
   ```bash
   docker compose restart seaweedfs
   ```

4. Verifique topologia:
   ```bash
   curl http://localhost:9333/cluster/status
   ```

**Opções de replicação:**

- `001` = 1 cópia em servidor diferente (2 cópias totais em 2 servidores)
- `011` = 1 cópia em rack + 1 em servidor (requer 2+ racks)
- `100` = 1 cópia em datacenter diferente (requer 2+ datacenters)

## Integração com Serviços

### Directus CMS

Configuração `.env` para Directus usar SeaweedFS:

```bash
STORAGE_LOCATIONS=s3
STORAGE_S3_DRIVER=s3
STORAGE_S3_KEY=${SEAWEEDFS_ACCESS_KEY}
STORAGE_S3_SECRET=${SEAWEEDFS_SECRET_KEY}
STORAGE_S3_BUCKET=borgstack
STORAGE_S3_REGION=us-east-1
STORAGE_S3_ENDPOINT=http://seaweedfs:8333
STORAGE_S3_ROOT=/directus/
```

### FileFlows

FileFlows não suporta S3 nativamente. Integração via workflows n8n:

1. n8n baixa mídia do SeaweedFS → copia para `/input` do FileFlows
2. FileFlows processa → salva em `/output`
3. n8n faz upload de `/output` → SeaweedFS

### Chatwoot

Configuração `.env` para Chatwoot usar SeaweedFS:

```bash
ACTIVE_STORAGE_SERVICE=s3
AWS_ACCESS_KEY_ID=${SEAWEEDFS_ACCESS_KEY}
AWS_SECRET_ACCESS_KEY=${SEAWEEDFS_SECRET_KEY}
AWS_REGION=us-east-1
AWS_BUCKET_NAME=borgstack
AWS_S3_ENDPOINT=http://seaweedfs:8333
AWS_S3_PATH_PREFIX=chatwoot/
```

### n8n Workflows

n8n usa HTTP Request nodes com AWS SDK para operações S3. Veja workflows de exemplo em `config/n8n/workflows/`.

## Solução de Problemas

### Container Não Inicia

```bash
# Verificar logs do SeaweedFS
docker compose logs seaweedfs --tail=100

# Problemas comuns:
# - Credenciais S3 faltando no .env
# - Erros de permissão de volumes
# - Conflitos de porta

# Verificar health check
docker compose ps seaweedfs
```

### S3 API Retorna 403 Forbidden

```bash
# Verificar credenciais corretas
docker compose exec seaweedfs printenv | grep AWS

# Testar Master API (sem autenticação)
curl http://localhost:9333/cluster/status

# Testar S3 API com credenciais
curl -u ${SEAWEEDFS_ACCESS_KEY}:${SEAWEEDFS_SECRET_KEY} http://localhost:8333/
```

### Volumes Não Crescem Automaticamente

```bash
# Verificar status de volumes
curl http://localhost:9333/dir/status

# Crescer volumes manualmente
curl "http://localhost:9333/vol/grow?count=4&replication=000"

# Verificar limite de volumes não atingido
docker compose exec seaweedfs printenv | grep MAX_VOLUMES
```

### Performance Lenta

```bash
# Testar I/O de disco (deve ser >100 MB/s para SSD)
docker compose exec seaweedfs sh -c \
  "dd if=/dev/zero of=/data/volume/test.dat bs=1M count=1000 oflag=direct"

# Monitorar distribuição de volumes (evitar hotspots)
curl http://localhost:9333/dir/status

# Habilitar pré-alocação de volumes (.env)
SEAWEEDFS_VOLUME_PREALLOCATE=true

# Reiniciar SeaweedFS
docker compose restart seaweedfs
```

### Corrupção de Metadados Filer

```bash
# Parar SeaweedFS
docker compose stop seaweedfs

# Backup de dados filer
docker compose exec -T seaweedfs tar czf - /data/filer > filer-backup.tar.gz

# Reiniciar com rebuild do filer (último recurso)
docker compose up -d seaweedfs

# Verificar logs filer
docker compose logs seaweedfs --tail=50 | grep filer
```

## Backup e Recuperação

Os volumes SeaweedFS são backupeados pelo Duplicati. Backup manual:

```bash
# Backup dos 3 volumes
docker compose exec -T seaweedfs tar czf - /data/master > seaweedfs-master-$(date +%Y%m%d).tar.gz
docker compose exec -T seaweedfs tar czf - /data/volume > seaweedfs-volume-$(date +%Y%m%d).tar.gz
docker compose exec -T seaweedfs tar czf - /data/filer > seaweedfs-filer-$(date +%Y%m%d).tar.gz
```

⚠️ **Importante**: Os 3 volumes são necessários para recuperação:

- `master`: Topologia e metadados de alocação de volumes
- `volume`: Conteúdo real dos arquivos em chunks
- `filer`: Mapeamento de caminhos S3 → chunks de volumes

## Melhores Práticas de Segurança

1. **Nunca commite credenciais S3 no controle de versão**
   - Armazene em `.env` com permissões 600
   - Rotacione credenciais periodicamente

2. **Use rede interna apenas (padrão)**
   - Sem acesso S3 externo a menos que necessário
   - Exponha via Caddy HTTPS apenas se imprescindível

3. **Habilite quotas de diretório**
   - Previna ataques de exaustão de armazenamento
   - Limite consumo de storage por serviço

4. **Monitore logs de acesso**
   - Revise padrões de acesso à API S3
   - Detecte tentativas de acesso não autorizado

5. **Backups regulares**
   - Automatizados via Duplicati
   - Teste procedimentos de restauração trimestralmente

6. **Atualize credenciais após mudanças de equipe**
   - Rotacione chaves S3 quando funcionários saírem
   - Use credenciais separadas para diferentes ambientes

## 8. Dicas e Melhores Práticas

### 8.1 Configuração Otimizada
Consulte [docs/02-configuracao.md](../02-configuracao.md) para variáveis de ambiente específicas deste serviço.

### 8.2 Performance
- Consultar documentação oficial para tuning de seaweedfs
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

- [SeaweedFS GitHub](https://github.com/seaweedfs/seaweedfs)
- [SeaweedFS Wiki](https://github.com/seaweedfs/seaweedfs/wiki)
- [Compatibilidade S3 API](https://github.com/seaweedfs/seaweedfs/wiki/Amazon-S3-API)
- [Configuração Filer](https://github.com/seaweedfs/seaweedfs/wiki/Filer-Stores)
- [Estratégia de Replicação](https://github.com/seaweedfs/seaweedfs/wiki/Replication)

## Próximos Passos

Após implantação do SeaweedFS:

1. Implantar Duplicati para backups automáticos do SeaweedFS
2. Migrar Directus e FileFlows de volumes locais para SeaweedFS S3
3. Configurar Chatwoot para usar SeaweedFS para anexos
4. Criar templates de workflow n8n para operações S3

---

Para validação da implantação, execute:

```bash
./tests/deployment/verify-seaweedfs.sh
```

Para configuração detalhada, veja:

```bash
config/seaweedfs/README.md
```
