# MongoDB - Banco de Dados NoSQL

## Visão Geral

### O que é MongoDB?

MongoDB é um banco de dados NoSQL orientado a documentos, de código aberto, que armazena dados em formato JSON flexível (BSON). É conhecido por sua alta performance, escalabilidade horizontal e modelo de dados dinâmico que não requer schemas fixos.

No contexto do BorgStack, o MongoDB serve como banco de dados **dedicado** para o Lowcoder:
- **Lowcoder**: Metadados de aplicações, configurações, templates, usuários

**Importante**: Diferentemente do PostgreSQL (compartilhado por 4 serviços), o MongoDB é usado **exclusivamente** pelo Lowcoder.

### Versão no BorgStack

- **Versão**: MongoDB 7.0
- **Storage Engine**: WiredTiger (padrão, com compressão)

### Características Principais

1. **Modelo de Documentos**: Dados armazenados em documentos BSON (JSON binário)
2. **Schema Flexível**: Estrutura de dados pode variar entre documentos
3. **Queries Poderosas**: Suporte a queries complexas, agregações e índices
4. **Alta Performance**: Otimizado para leitura/escrita rápida
5. **Replicação**: Suporte nativo a replica sets (não usado no BorgStack por simplicidade)

---

## Configuração Inicial

### Localização dos Arquivos

```bash
# Dados do MongoDB (volume Docker)
docker volume inspect borgstack_mongodb_data

# Logs
docker compose logs -f mongodb

# Verificar status
docker compose ps mongodb
```

### Banco de Dados do Lowcoder

```bash
# Database name
lowcoder

# Collections principais:
# - application: Aplicações criadas
# - datasource: Fontes de dados configuradas
# - user: Usuários do Lowcoder
# - organization: Organizações
# - folder: Pastas de organização
```

### Credenciais e Conexão

Credenciais no arquivo `.env`:

```bash
# Superusuário (root)
MONGODB_ROOT_USER=root
MONGODB_ROOT_PASSWORD=senha_super_segura_mongodb

# Database do Lowcoder
LOWCODER_MONGODB_DATABASE=lowcoder
LOWCODER_MONGODB_USER=lowcoder_user
LOWCODER_MONGODB_PASSWORD=senha_lowcoder
```

### Conectar ao MongoDB

#### Via mongosh (Container)

```bash
# Conectar como root
docker compose exec mongodb mongosh -u root -p senha_super_segura_mongodb --authenticationDatabase admin

# Conectar ao database do Lowcoder
docker compose exec mongodb mongosh -u lowcoder_user -p senha_lowcoder --authenticationDatabase lowcoder lowcoder

# Conectar com URI
docker compose exec mongodb mongosh "mongodb://lowcoder_user:senha_lowcoder@localhost:27017/lowcoder?authSource=lowcoder"

# Listar databases
docker compose exec mongodb mongosh -u root -p --authenticationDatabase admin --eval "show dbs"

# Listar coleções
docker compose exec mongodb mongosh -u lowcoder_user -p lowcoder --eval "show collections"
```

#### Connection String

Formato para conexão de aplicações:

```bash
# Lowcoder
mongodb://lowcoder_user:senha_lowcoder@mongodb:27017/lowcoder?authSource=lowcoder

# Root (admin)
mongodb://root:senha_root@mongodb:27017/admin?authSource=admin
```

---

## Conceitos Fundamentais

### 1. Database

Um **database** é um container lógico para coleções:

```javascript
// Conectar via mongosh
use lowcoder

// Listar databases
show dbs

// Ver database atual
db

// Criar database (criado automaticamente ao inserir dados)
use meu_database

// Deletar database (CUIDADO!)
use meu_database
db.dropDatabase()
```

### 2. Collection

Uma **collection** é equivalente a uma tabela em bancos relacionais:

```javascript
// Listar coleções
show collections

// Criar coleção explicitamente (opcional)
db.createCollection("minhaColecao")

// Criar coleção com validação de schema
db.createCollection("usuarios", {
   validator: {
      $jsonSchema: {
         bsonType: "object",
         required: ["nome", "email"],
         properties: {
            nome: {
               bsonType: "string",
               description: "deve ser string e é obrigatório"
            },
            email: {
               bsonType: "string",
               pattern: "^.+@.+$",
               description: "deve ser email válido e é obrigatório"
            },
            idade: {
               bsonType: "int",
               minimum: 0,
               description: "deve ser inteiro >= 0 se informado"
            }
         }
      }
   }
})

// Deletar coleção
db.minhaColecao.drop()
```

### 3. Document

Um **document** é um registro BSON (similar a JSON):

```javascript
// Inserir documento
db.usuarios.insertOne({
    nome: "João Silva",
    email: "joao@example.com",
    idade: 30,
    tags: ["dev", "backend"],
    endereco: {
        rua: "Av. Paulista",
        numero: 1000,
        cidade: "São Paulo"
    },
    criadoEm: new Date()
})

// Inserir múltiplos documentos
db.usuarios.insertMany([
    {nome: "Maria", email: "maria@example.com", idade: 25},
    {nome: "Pedro", email: "pedro@example.com", idade: 35}
])

// Ver estrutura de um documento
db.usuarios.findOne()
```

### 4. Queries

```javascript
// Buscar todos os documentos
db.usuarios.find()

// Buscar com filtro
db.usuarios.find({idade: {$gte: 30}})

// Buscar um documento
db.usuarios.findOne({email: "joao@example.com"})

// Buscar com projeção (campos específicos)
db.usuarios.find({}, {nome: 1, email: 1, _id: 0})

// Ordenar
db.usuarios.find().sort({idade: -1})

// Limitar resultados
db.usuarios.find().limit(10)

// Pular resultados (paginação)
db.usuarios.find().skip(10).limit(10)

// Contar documentos
db.usuarios.countDocuments({idade: {$gte: 30}})
```

### 5. Updates

```javascript
// Atualizar um documento
db.usuarios.updateOne(
    {email: "joao@example.com"},
    {$set: {idade: 31}}
)

// Atualizar múltiplos documentos
db.usuarios.updateMany(
    {idade: {$lt: 18}},
    {$set: {menor: true}}
)

// Upsert (insert se não existe, update se existe)
db.usuarios.updateOne(
    {email: "novo@example.com"},
    {$set: {nome: "Novo Usuário", idade: 20}},
    {upsert: true}
)

// Incrementar valor
db.usuarios.updateOne(
    {email: "joao@example.com"},
    {$inc: {idade: 1}}
)

// Adicionar a array
db.usuarios.updateOne(
    {email: "joao@example.com"},
    {$push: {tags: "fullstack"}}
)

// Remover de array
db.usuarios.updateOne(
    {email: "joao@example.com"},
    {$pull: {tags: "backend"}}
)
```

### 6. Deletes

```javascript
// Deletar um documento
db.usuarios.deleteOne({email: "joao@example.com"})

// Deletar múltiplos documentos
db.usuarios.deleteMany({idade: {$lt: 18}})

// Deletar todos os documentos (CUIDADO!)
db.usuarios.deleteMany({})
```

### 7. Indexes

**Indexes** aceleram queries:

```javascript
// Criar index
db.usuarios.createIndex({email: 1})

// Criar index único
db.usuarios.createIndex({email: 1}, {unique: true})

// Criar index composto
db.usuarios.createIndex({nome: 1, idade: -1})

// Criar index de texto (full-text search)
db.usuarios.createIndex({nome: "text", bio: "text"})

// Listar indexes
db.usuarios.getIndexes()

// Deletar index
db.usuarios.dropIndex("email_1")

// Analisar performance de query
db.usuarios.find({email: "joao@example.com"}).explain("executionStats")
```

---

## Tutorial Passo a Passo: Gerenciamento Básico

### Passo 1: Verificar Status do MongoDB

```bash
# Container está rodando?
docker compose ps mongodb

# Health check
docker inspect mongodb | grep -A 10 "Health"

# Logs recentes
docker compose logs --tail=50 mongodb

# Conectividade (via mongosh)
docker compose exec mongodb mongosh --eval "db.adminCommand('ping')"
```

### Passo 2: Explorar Database do Lowcoder

```bash
# Conectar ao database lowcoder
docker compose exec mongodb mongosh -u lowcoder_user -p lowcoder

# Dentro do mongosh:
```

```javascript
// Ver coleções
show collections

// Ver aplicações criadas
db.application.find().pretty()

// Ver quantidade de aplicações
db.application.countDocuments()

// Ver usuários
db.user.find({}, {username: 1, email: 1})

// Ver datasources configuradas
db.datasource.find()

// Ver organizações
db.organization.find()
```

### Passo 3: Consultar Dados

```javascript
// Conectar
use lowcoder

// Ver aplicações criadas nos últimos 7 dias
db.application.find({
    createdAt: {
        $gte: new Date(Date.now() - 7*24*60*60*1000)
    }
}).sort({createdAt: -1})

// Ver usuários ativos
db.user.find({
    state: {$ne: "DELETED"}
}).count()

// Ver datasources por tipo
db.datasource.aggregate([
    {$group: {
        _id: "$type",
        count: {$sum: 1}
    }},
    {$sort: {count: -1}}
])
```

### Passo 4: Monitorar Performance

```javascript
// Ver estatísticas do database
db.stats()

// Ver estatísticas de uma coleção
db.application.stats()

// Ver operações em execução
db.currentOp()

// Matar operação lenta (CUIDADO!)
db.killOp(opId)

// Ver profiler (queries lentas)
db.system.profile.find().limit(10).sort({ts: -1})
```

---

## Backup e Restore

### Backup com mongodump

#### Backup do Database Lowcoder

```bash
# Backup básico (formato BSON)
docker compose exec mongodb mongodump \
    -u lowcoder_user \
    -p senha_lowcoder \
    --authenticationDatabase lowcoder \
    --db lowcoder \
    --out /tmp/backup

# Copiar do container
docker cp mongodb:/tmp/backup ./backups/lowcoder_$(date +%Y%m%d)

# Backup com compressão gzip
docker compose exec mongodb mongodump \
    -u lowcoder_user \
    -p senha_lowcoder \
    --authenticationDatabase lowcoder \
    --db lowcoder \
    --archive=/tmp/lowcoder.archive \
    --gzip

# Copiar backup comprimido
docker cp mongodb:/tmp/lowcoder.archive ./backups/lowcoder_$(date +%Y%m%d).archive.gz
```

#### Backup de Todas as Databases

```bash
# Backup completo (root necessário)
docker compose exec mongodb mongodump \
    -u root \
    -p senha_root \
    --authenticationDatabase admin \
    --out /tmp/full_backup

# Copiar do container
docker cp mongodb:/tmp/full_backup ./backups/full_$(date +%Y%m%d)
```

#### Backup Direto para Arquivo Local

```bash
# Usando pipe (sem arquivo temporário no container)
docker compose exec -T mongodb mongodump \
    -u lowcoder_user \
    -p senha_lowcoder \
    --authenticationDatabase lowcoder \
    --db lowcoder \
    --archive \
    --gzip > ./backups/lowcoder_$(date +%Y%m%d).archive.gz
```

### Restore com mongorestore

#### Restore do Database Lowcoder

```bash
# Copiar backup para container
docker cp ./backups/lowcoder_20250108 mongodb:/tmp/restore_data

# Restore básico
docker compose exec mongodb mongorestore \
    -u lowcoder_user \
    -p senha_lowcoder \
    --authenticationDatabase lowcoder \
    --db lowcoder \
    /tmp/restore_data/lowcoder

# Restore de arquivo archive comprimido
docker cp ./backups/lowcoder_20250108.archive.gz mongodb:/tmp/lowcoder.archive.gz

docker compose exec mongodb mongorestore \
    -u lowcoder_user \
    -p senha_lowcoder \
    --authenticationDatabase lowcoder \
    --archive=/tmp/lowcoder.archive.gz \
    --gzip
```

#### Restore Direto de Arquivo Local

```bash
# Usando pipe (sem copiar para container)
docker compose exec -T mongodb mongorestore \
    -u lowcoder_user \
    -p senha_lowcoder \
    --authenticationDatabase lowcoder \
    --archive \
    --gzip < ./backups/lowcoder_20250108.archive.gz
```

#### Restore com Drop (Substituir Dados Existentes)

```bash
# CUIDADO: Isso remove dados existentes antes do restore!
docker compose exec mongodb mongorestore \
    -u lowcoder_user \
    -p senha_lowcoder \
    --authenticationDatabase lowcoder \
    --db lowcoder \
    --drop \
    /tmp/restore_data/lowcoder
```

### Script de Backup Automatizado

```bash
#!/bin/bash
# backups/backup-mongodb.sh

set -e

BACKUP_DIR="/path/to/backups/mongodb"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

mkdir -p "$BACKUP_DIR"

echo "Starting MongoDB backup..."

# Backup do Lowcoder database
docker compose exec -T mongodb mongodump \
    -u lowcoder_user \
    -p "$LOWCODER_MONGODB_PASSWORD" \
    --authenticationDatabase lowcoder \
    --db lowcoder \
    --archive \
    --gzip > "$BACKUP_DIR/lowcoder_${TIMESTAMP}.archive.gz"

# Verificar integridade
if [ -f "$BACKUP_DIR/lowcoder_${TIMESTAMP}.archive.gz" ]; then
    SIZE=$(du -h "$BACKUP_DIR/lowcoder_${TIMESTAMP}.archive.gz" | cut -f1)
    echo "✅ Backup completed: $SIZE"
else
    echo "❌ Backup failed!"
    exit 1
fi

# Remover backups antigos
echo "Cleaning old backups (older than $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -name "*.archive.gz" -mtime +$RETENTION_DAYS -delete

echo "✅ Backup process completed successfully!"
```

---

## Agregações (Aggregation Pipeline)

Agregações permitem queries complexas e transformações de dados:

```javascript
// Pipeline básico
db.application.aggregate([
    // Stage 1: Filtrar
    {$match: {deleted: false}},

    // Stage 2: Agrupar e contar
    {$group: {
        _id: "$organizationId",
        totalApps: {$sum: 1},
        ultimaAtualizacao: {$max: "$modifiedAt"}
    }},

    // Stage 3: Ordenar
    {$sort: {totalApps: -1}},

    // Stage 4: Limitar
    {$limit: 10}
])

// Exemplo: Contar aplicações por organização
db.application.aggregate([
    {$match: {deleted: {$ne: true}}},
    {$group: {
        _id: "$organizationId",
        count: {$sum: 1}
    }},
    {$sort: {count: -1}}
])

// Exemplo: Estatísticas de usuários
db.user.aggregate([
    {$group: {
        _id: "$state",
        count: {$sum: 1}
    }}
])

// Exemplo: Join entre coleções (lookup)
db.application.aggregate([
    {$lookup: {
        from: "organization",
        localField: "organizationId",
        foreignField: "_id",
        as: "org"
    }},
    {$unwind: "$org"},
    {$project: {
        nome: "$name",
        organizacao: "$org.name",
        criadoEm: "$createdAt"
    }},
    {$limit: 10}
])
```

---

## Otimização de Performance

### Criar Indexes Estratégicos

```javascript
// Index para queries frequentes
db.application.createIndex({organizationId: 1, deleted: 1})

// Index para ordenação
db.application.createIndex({createdAt: -1})

// Index de texto para busca
db.application.createIndex({name: "text", description: "text"})

// Usar index de texto
db.application.find({$text: {$search: "dashboard analytics"}})

// Index TTL (auto-delete após X segundos)
db.sessions.createIndex({createdAt: 1}, {expireAfterSeconds: 86400})

// Ver indexes criados
db.application.getIndexes()

// Estatísticas de uso de indexes
db.application.aggregate([{$indexStats: {}}])
```

### Analisar Queries

```javascript
// Ver explain de uma query
db.application.find({organizationId: "123"}).explain("executionStats")

// Verificar se index está sendo usado
db.application.find({organizationId: "123"}).explain().queryPlanner.winningPlan

// Ver tempo de execução
db.application.find({organizationId: "123"}).explain("executionStats").executionStats.executionTimeMillis
```

### Profiler de Performance

```javascript
// Habilitar profiler (nível 2 = todas as operações)
db.setProfilingLevel(2)

// Habilitar apenas para operações lentas (> 100ms)
db.setProfilingLevel(1, {slowms: 100})

// Ver queries lentas
db.system.profile.find({millis: {$gt: 100}}).sort({ts: -1}).limit(10)

// Desabilitar profiler
db.setProfilingLevel(0)
```

---

## Integração com Lowcoder

### Connection String no Lowcoder

O Lowcoder já está pré-configurado via variáveis de ambiente:

```bash
# docker-compose.yml - lowcoder-api-service
LOWCODER_MONGODB_URL=mongodb://lowcoder_user:senha_lowcoder@mongodb:27017/lowcoder?authSource=lowcoder
```

### Queries Comuns do Lowcoder

```javascript
// Ver todas as aplicações
db.application.find({deleted: {$ne: true}})

// Ver aplicações de uma organização
db.application.find({
    organizationId: ObjectId("..."),
    deleted: {$ne: true}
})

// Ver datasources configuradas
db.datasource.find({
    organizationId: ObjectId("...")
})

// Ver usuários de uma organização
db.user.find({
    "orgAndRoles.orgId": ObjectId("...")
})

// Limpar sessões expiradas (se não houver TTL index)
db.sessions.deleteMany({
    expiresAt: {$lt: new Date()}
})
```

### Backup Antes de Atualizar Lowcoder

```bash
# Sempre fazer backup antes de atualizar a versão do Lowcoder!

# 1. Parar Lowcoder
docker compose stop lowcoder-api-service lowcoder-node-service lowcoder-frontend

# 2. Backup do MongoDB
docker compose exec -T mongodb mongodump \
    -u lowcoder_user \
    -p senha_lowcoder \
    --authenticationDatabase lowcoder \
    --db lowcoder \
    --archive \
    --gzip > backups/lowcoder_pre_upgrade_$(date +%Y%m%d).archive.gz

# 3. Atualizar Lowcoder
docker compose pull lowcoder-api-service lowcoder-node-service lowcoder-frontend

# 4. Iniciar Lowcoder
docker compose up -d lowcoder-api-service lowcoder-node-service lowcoder-frontend

# 5. Verificar logs
docker compose logs -f lowcoder-api-service
```

---

## Comandos Úteis

### Administração

```javascript
// Ver versão do MongoDB
db.version()

// Ver informações do servidor
db.serverStatus()

// Ver estatísticas do database
db.stats()

// Ver uso de espaço por coleção
db.runCommand({dbStats: 1, scale: 1024*1024}) // MB

// Ver operações em execução
db.currentOp({active: true})

// Ver configuração do servidor
db.adminCommand({getCmdLineOpts: 1})

// Ver log do MongoDB
db.adminCommand({getLog: "global"})
```

### Manutenção

```javascript
// Compact collection (recuperar espaço)
db.runCommand({compact: "application"})

// Rebuild indexes
db.application.reIndex()

// Validate collection
db.application.validate()

// Repair database (apenas se necessário)
db.repairDatabase()
```

### Monitoramento

```bash
# Estatísticas do container
docker stats mongodb

# Logs em tempo real
docker compose logs -f mongodb

# Filtrar por erro
docker compose logs mongodb | grep -i error

# Ver processos MongoDB
docker compose exec mongodb ps aux | grep mongo

# Uso de disco do volume
docker system df -v | grep mongodb
```

---

## Solução de Problemas

### 1. Não Consigo Conectar ao MongoDB

**Sintomas**: Erro "Authentication failed" ou "Connection refused"

**Soluções**:

```bash
# Verificar container está rodando
docker compose ps mongodb

# Verificar logs
docker compose logs -f mongodb

# Verificar credenciais no .env
grep MONGODB .env

# Testar conexão básica
docker compose exec mongodb mongosh --eval "db.adminCommand('ping')"

# Conectar como root
docker compose exec mongodb mongosh -u root -p --authenticationDatabase admin

# Verificar usuário existe
docker compose exec mongodb mongosh -u root -p --authenticationDatabase admin --eval "
use lowcoder
db.getUsers()
"

# Recriar usuário se necessário
docker compose exec mongodb mongosh -u root -p --authenticationDatabase admin --eval "
use lowcoder
db.createUser({
    user: 'lowcoder_user',
    pwd: 'senha_lowcoder',
    roles: [{role: 'readWrite', db: 'lowcoder'}]
})
"
```

### 2. Database Está Lento

**Sintomas**: Queries demoradas, Lowcoder lento

**Soluções**:

```javascript
// Conectar
use lowcoder

// Ver operações lentas
db.currentOp({
    active: true,
    secs_running: {$gt: 5}
})

// Verificar indexes
db.application.getIndexes()

// Criar indexes faltantes (exemplo)
db.application.createIndex({organizationId: 1})
db.application.createIndex({createdAt: -1})

// Ver estatísticas de coleções
db.application.stats()
db.datasource.stats()
db.user.stats()

// Compact collections grandes
db.runCommand({compact: "application"})
```

```bash
# Verificar uso de recursos
docker stats mongodb

# Se memória alta: aumentar cache
# Editar docker-compose.yml:
# command: --wiredTigerCacheSizeGB 2
```

### 3. Disco Cheio

**Sintomas**: Erro "No space left on device"

**Soluções**:

```bash
# Verificar uso de disco do volume
docker system df -v | grep mongodb

# Ver tamanho do database
docker compose exec mongodb mongosh -u lowcoder_user -p lowcoder --eval "
db.stats(1024*1024) // MB
"

# Ver tamanho por coleção
docker compose exec mongodb mongosh -u lowcoder_user -p lowcoder --eval "
db.getCollectionNames().forEach(function(col) {
    var stats = db[col].stats(1024*1024);
    print(col + ': ' + stats.size + ' MB');
})
"

# Compact para recuperar espaço
docker compose exec mongodb mongosh -u lowcoder_user -p lowcoder --eval "
db.runCommand({compact: 'application'})
db.runCommand({compact: 'datasource'})
"

# Limpar logs antigos (se habilitado)
docker compose exec mongodb sh -c "find /var/log/mongodb -name '*.log' -mtime +7 -delete"
```

### 4. Backup Falha

**Sintomas**: mongodump retorna erro

**Soluções**:

```bash
# Verificar espaço em disco
df -h

# Verificar credenciais
docker compose exec mongodb mongosh -u lowcoder_user -p senha_lowcoder --authenticationDatabase lowcoder --eval "db.adminCommand('ping')"

# Backup com verbose
docker compose exec mongodb mongodump \
    -u lowcoder_user \
    -p senha_lowcoder \
    --authenticationDatabase lowcoder \
    --db lowcoder \
    --out /tmp/backup \
    --verbose

# Se falhar por falta de permissão, usar root
docker compose exec mongodb mongodump \
    -u root \
    -p senha_root \
    --authenticationDatabase admin \
    --db lowcoder \
    --out /tmp/backup
```

### 5. Restore Falha

**Sintomas**: mongorestore retorna erro

**Soluções**:

```bash
# Verificar backup existe
docker compose exec mongodb ls -lh /tmp/backup/lowcoder/

# Restore com verbose
docker compose exec mongodb mongorestore \
    -u lowcoder_user \
    -p senha_lowcoder \
    --authenticationDatabase lowcoder \
    --db lowcoder \
    /tmp/backup/lowcoder \
    --verbose

# Se erro de permissão, usar root
docker compose exec mongodb mongorestore \
    -u root \
    -p senha_root \
    --authenticationDatabase admin \
    --db lowcoder \
    /tmp/backup/lowcoder

# Restore com drop (substitui dados)
docker compose exec mongodb mongorestore \
    -u lowcoder_user \
    -p senha_lowcoder \
    --authenticationDatabase lowcoder \
    --db lowcoder \
    --drop \
    /tmp/backup/lowcoder
```

### 6. Lowcoder Não Conecta ao MongoDB

**Sintomas**: Erro "MongoNetworkError" nos logs do Lowcoder

**Soluções**:

```bash
# Verificar connection string
grep LOWCODER_MONGODB_URL docker-compose.yml

# Verificar MongoDB está na rede correta
docker inspect mongodb | grep -A 10 "Networks"
docker inspect lowcoder-api-service | grep -A 10 "Networks"
# Ambos devem estar em borgstack_internal

# Testar conectividade do Lowcoder ao MongoDB
docker compose exec lowcoder-api-service ping -c 3 mongodb

# Ver logs do Lowcoder
docker compose logs -f lowcoder-api-service | grep -i mongo

# Reiniciar Lowcoder
docker compose restart lowcoder-api-service lowcoder-node-service
```

### 7. Container Reinicia Constantemente

**Sintomas**: `docker compose ps` mostra container em loop de restart

**Soluções**:

```bash
# Ver logs detalhados
docker compose logs --tail=100 mongodb

# Verificar permissões do volume
docker volume inspect borgstack_mongodb_data

# Verificar recursos do sistema
docker stats mongodb

# Limpar dados corrompidos (CUIDADO: perde dados!)
# docker compose down mongodb
# docker volume rm borgstack_mongodb_data
# docker compose up -d mongodb
```

---

## 8. Dicas e Melhores Práticas

### 8.1 Configuração Otimizada
Consulte [docs/02-configuracao.md](../02-configuracao.md) para variáveis de ambiente específicas deste serviço.

### 8.2 Performance
- Índices em queries frequentes
- Aggregation pipeline otimizado
- Connection pool: 100 conexões

### 8.3 Segurança
- Autenticação habilitada
- Roles com least privilege
- Backup diário

### 8.4 Monitoramento
- Uso de CPU/RAM
- Slow queries (> 100ms)
- Tamanho de coleções

### 8.5 Casos de Uso
Ver workflows de exemplo em [docs/09-workflows-exemplo.md](../09-workflows-exemplo.md)

---

## Recursos Adicionais

### Documentação Oficial
- [MongoDB Manual](https://www.mongodb.com/docs/manual/)
- [MongoDB Shell (mongosh)](https://www.mongodb.com/docs/mongodb-shell/)
- [MongoDB Database Tools](https://www.mongodb.com/docs/database-tools/)

### Ferramentas
- [MongoDB Compass](https://www.mongodb.com/products/compass) - GUI oficial
- [Robo 3T](https://robomongo.org/) - Cliente leve
- [Studio 3T](https://studio3t.com/) - IDE avançado

---

## Próximos Passos

Depois de configurar o MongoDB, você pode:

1. **Configurar Lowcoder**: Ver [docs/03-services/lowcoder.md](./lowcoder.md)
2. **Configurar Backups Automatizados**: Ver [docs/06-manutencao.md](../06-manutencao.md)
3. **Otimizar Performance**: Ver [docs/08-desempenho.md](../08-desempenho.md)
4. **Monitorar Sistema**: Configurar alertas e dashboards

---

## Referências Técnicas

### Variáveis de Ambiente

```bash
# Superusuário
MONGODB_ROOT_USER=root
MONGODB_ROOT_PASSWORD=senha_super_segura_mongodb

# Database do Lowcoder
LOWCODER_MONGODB_DATABASE=lowcoder
LOWCODER_MONGODB_USER=lowcoder_user
LOWCODER_MONGODB_PASSWORD=senha_lowcoder

# Connection String (Lowcoder)
LOWCODER_MONGODB_URL=mongodb://lowcoder_user:senha_lowcoder@mongodb:27017/lowcoder?authSource=lowcoder
```

### Portas

| Serviço | Porta Interna | Porta Externa | Descrição |
|---------|---------------|---------------|-----------|
| MongoDB | 27017 | - | Não exposta (rede interna apenas) |

### Volumes

```yaml
volumes:
  borgstack_mongodb_data:  # Dados do MongoDB (/data/db)
```

### Limites e Configurações

| Recurso | Configuração | Valor Padrão |
|---------|--------------|--------------|
| WiredTiger Cache | wiredTigerCacheSizeGB | 50% RAM - 1GB |
| Max Connections | maxConns | 65536 |
| Storage Engine | storage.engine | wiredTiger |
| Journal | storage.journal.enabled | true |

---

**Última atualização**: 2025-10-08
**Versão do BorgStack**: 1.0
**Versão do MongoDB**: 7.0
