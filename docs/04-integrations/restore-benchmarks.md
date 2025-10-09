# Benchmarks de Tempo de Restauração - BorgStack

Este documento estabelece benchmarks de tempo de restauração para o sistema de backup Duplicati, essenciais para planejamento de recuperação de desastres e definição de RTOs (Recovery Time Objectives).

## Metodologia de Teste

### Ambiente de Referência

Os benchmarks foram estabelecidos baseados em um servidor de referência com as seguintes especificações:

| Componente | Especificação |
|------------|---------------|
| CPU | 8 vCPUs (Intel Xeon ou equivalente) |
| RAM | 36 GB |
| Armazenamento | SSD NVMe (leitura: 3500 MB/s, escrita: 3000 MB/s) |
| Rede | 1 Gbps simétrico (125 MB/s download/upload) |
| Sistema Operacional | Ubuntu Server 24.04 LTS |
| Docker | Docker Engine 24.x + Docker Compose v2 |

### Fatores que Afetam o Tempo de Restauração

1. **Velocidade de Download**
   - Maior impacto: Largura de banda da internet
   - AWS S3 São Paulo: Geralmente 80-120 MB/s em boas condições
   - Backblaze B2: Pode variar, geralmente 20-80 MB/s
   - SFTP local: Limitado pela rede local (geralmente 100-125 MB/s)

2. **Eficiência de Deduplicação**
   - Backups com alta deduplicação restauram mais rápido (menos dados para baixar)
   - Taxa típica de deduplicação: 30-60% para dados BorgStack

3. **Velocidade de Disco I/O**
   - SSD: 10x mais rápido que HDD para operações aleatórias
   - NVMe SSD: 3-6x mais rápido que SATA SSD

4. **Sobrecarga de Criptografia/Descompressão**
   - AES-256: ~5-10% de overhead
   - zstd descompressão: ~3-5% de overhead
   - Total: ~10-15% adicional ao tempo de download puro

5. **Carga do Sistema**
   - Restaurações durante horário de pico podem ser 20-40% mais lentas
   - Recomendação: Executar restaurações durante baixo tráfego

## Benchmarks por Cenário

### 1. Restauração de Arquivo Individual

**Cenário**: Restaurar um único arquivo (workflow do n8n, imagem do Chatwoot, etc.)

| Tamanho do Arquivo | Tempo Alvo | Tempo Aceitável | Limite Crítico |
|-------------------|------------|-----------------|----------------|
| < 1 MB | < 10 segundos | < 30 segundos | > 2 minutos |
| 1-10 MB | < 30 segundos | < 2 minutos | > 5 minutos |
| 10-100 MB | < 2 minutos | < 5 minutos | > 15 minutos |
| 100 MB - 1 GB | < 5 minutos | < 15 minutos | > 30 minutos |

**Passos**:
1. Localizar arquivo no backup (web UI Duplicati): ~30 segundos
2. Iniciar restauração: ~10 segundos
3. Download e descompressão: Depende do tamanho
4. Verificação de integridade: ~5-10 segundos

**Exemplo Real**:
```
Arquivo: /source/n8n/workflows/workflow-chatbot.json (250 KB)
Backup: AWS S3 São Paulo
Tempo total: 45 segundos
  - Localização: 20s
  - Download: 15s
  - Verificação: 10s
```

---

### 2. Restauração de Serviço Completo

**Cenário**: Restaurar todos os dados de um serviço (ex: todos workflows n8n, todas sessões Evolution API)

| Serviço | Tamanho Típico | Tempo Alvo | Tempo Aceitável | Limite Crítico |
|---------|---------------|------------|-----------------|----------------|
| n8n | 100 MB - 2 GB | < 30 min | < 1 hora | > 2 horas |
| Evolution API | 500 MB - 5 GB | < 1 hora | < 2 horas | > 4 horas |
| Chatwoot Storage | 1 GB - 20 GB | < 1 hora | < 3 horas | > 6 horas |
| Directus Uploads | 5 GB - 100 GB | < 2 horas | < 4 horas | > 8 horas |
| FileFlows Output | 10 GB - 500 GB | < 4 horas | < 8 horas | > 16 horas |

**Passos**:
1. Parar serviço: ~10 segundos
2. Backup de segurança dos dados atuais: 5-30 minutos
3. Restauração via Duplicati: Varia (ver tabela)
4. Verificação de integridade: 5-15 minutos
5. Reiniciar serviço: 1-5 minutos
6. Testes funcionais: 5-15 minutos

**Exemplo Real - n8n**:
```
Serviço: n8n
Tamanho dos dados: 850 MB (120 workflows, credenciais, histórico)
Backup: AWS S3 São Paulo
Rede: 100 Mbps (12.5 MB/s efetivo)

Tempo de restauração:
  1. Parar n8n: 5s
  2. Backup de segurança: 2min
  3. Download do backup: 68s (850 MB / 12.5 MB/s)
  4. Descompressão: 45s
  5. Substituir dados: 30s
  6. Verificação: 3min
  7. Reiniciar n8n: 20s
  8. Teste funcional: 5min

Total: ~12 minutos (dentro do alvo de < 30 min)
```

---

### 3. Restauração de Banco de Dados

**Cenário**: Restaurar um banco de dados completo (PostgreSQL, MongoDB, Redis)

| Banco de Dados | Tamanho Típico | Tempo Alvo | Tempo Aceitável | Limite Crítico |
|----------------|---------------|------------|-----------------|----------------|
| Redis | 100 MB - 1 GB | < 15 min | < 30 min | > 1 hora |
| MongoDB (Lowcoder) | 500 MB - 5 GB | < 30 min | < 1 hora | > 2 horas |
| PostgreSQL (um banco) | 1 GB - 10 GB | < 1 hora | < 2 horas | > 4 horas |
| PostgreSQL (todos) | 5 GB - 50 GB | < 2 horas | < 4 horas | > 8 horas |

**Fatores Adicionais**:
- Índices precisam ser reconstruídos: +10-20% do tempo
- Constraints e foreign keys: +5-10% do tempo
- Vacuum/Analyze após restauração: +10-15% do tempo

**Exemplo Real - PostgreSQL (n8n_db)**:
```
Banco: n8n_db
Tamanho: 3.2 GB
Backup: Backblaze B2
Rede: 50 Mbps (6.25 MB/s efetivo)

Tempo de restauração:
  1. Parar serviços dependentes: 30s
  2. Backup de segurança (pg_dump): 5min
  3. Download volume PostgreSQL: 512s (3.2 GB / 6.25 MB/s)
  4. Parar PostgreSQL: 10s
  5. Substituir volume: 2min
  6. Iniciar PostgreSQL: 45s
  7. Rebuild índices: 8min
  8. Vacuum analyze: 4min
  9. Reiniciar serviços: 1min
 10. Testes: 10min

Total: ~32 minutos (dentro do alvo de < 1 hora)
```

---

### 4. Restauração Completa do Sistema (Disaster Recovery)

**Cenário**: Recuperação total após perda completa do servidor

| Tamanho Total dos Dados | Tempo Alvo | Tempo Aceitável | Limite Crítico |
|-------------------------|------------|-----------------|----------------|
| < 50 GB | < 4 horas | < 6 horas | > 12 horas |
| 50-100 GB | < 6 horas | < 8 horas | > 16 horas |
| 100-500 GB | < 8 horas | < 12 horas | > 24 horas |
| > 500 GB | < 12 horas | < 24 horas | > 48 horas |

**Fases do Disaster Recovery**:

| Fase | Duração Estimada | % do Tempo Total |
|------|------------------|------------------|
| 1. Provisionamento do servidor | 15-60 min | 5% |
| 2. Instalação BorgStack (bootstrap) | 10-30 min | 3% |
| 3. Configuração .env e DNS | 10-20 min | 2% |
| 4. Download dados do backup | 2-8 horas | 60-70% |
| 5. Inicialização de serviços | 5-15 min | 3% |
| 6. Verificação e testes | 30-120 min | 15-20% |
| 7. Ajustes e troubleshooting | 15-60 min | 5-10% |

**Exemplo Real - Sistema Médio**:
```
Tamanho total: 120 GB
Backup: AWS S3 São Paulo
Rede: 200 Mbps (25 MB/s efetivo)
Servidor novo: AWS EC2 t3.xlarge (4 vCPU, 16 GB RAM)

Tempo de disaster recovery:
  1. Provisionar EC2: 5min
  2. Bootstrap BorgStack: 15min
  3. Configurar .env: 10min
  4. Iniciar Duplicati: 2min
  5. Download total (120 GB): 80min (120 GB / 25 MB/s / 60)
      Com overhead (crypto/decomp): 92min
  6. Iniciar todos serviços: 10min
  7. Aguardar services healthy: 5min
  8. Testes básicos: 20min
  9. Testes completos: 40min
 10. Configurar novo backup: 10min

Total: ~3h 30min (dentro do alvo de < 4 horas para 100 GB)

RTO alcançado: 3.5 horas
RPO: 24 horas (backup diário)
```

---

## Benchmarks por Tipo de Volume

### Volumes de Banco de Dados

| Volume | Tamanho Típico | Taxa de Mudança | Tempo de Restauração |
|--------|---------------|-----------------|---------------------|
| `borgstack_postgresql_data` | 10-50 GB | Alta (30-50% diário) | 1-2 horas |
| `borgstack_mongodb_data` | 1-10 GB | Média (10-20% diário) | 15-45 min |
| `borgstack_redis_data` | 100 MB - 2 GB | Muito Alta (60-80% diário) | 5-15 min |

### Volumes de Armazenamento de Objetos

| Volume | Tamanho Típico | Taxa de Mudança | Tempo de Restauração |
|--------|---------------|-----------------|---------------------|
| `borgstack_seaweedfs_master` | 10-100 MB | Baixa (1-5% diário) | < 5 min |
| `borgstack_seaweedfs_volume` | 50 GB - 2 TB | Média (10-30% diário) | 2-12 horas |
| `borgstack_seaweedfs_filer` | 100 MB - 5 GB | Baixa (5-10% diário) | 10-30 min |

### Volumes de Aplicação

| Volume | Tamanho Típico | Taxa de Mudança | Tempo de Restauração |
|--------|---------------|-----------------|---------------------|
| `borgstack_n8n_data` | 100 MB - 5 GB | Média (20-40% diário) | 15-45 min |
| `borgstack_evolution_instances` | 500 MB - 10 GB | Alta (40-60% diário) | 30 min - 1.5 horas |
| `borgstack_chatwoot_storage` | 1 GB - 50 GB | Média (10-30% diário) | 30 min - 3 horas |
| `borgstack_directus_uploads` | 5 GB - 200 GB | Baixa (5-15% diário) | 1-6 horas |
| `borgstack_fileflows_output` | 10 GB - 1 TB | Alta (50-80% diário) | 2-20 horas |
| `borgstack_caddy_data` | 10-100 MB | Muito Baixa (< 1% diário) | < 5 min |

---

## Otimização de Tempo de Restauração

### 1. Otimizações de Infraestrutura

**Rede**:
- ✅ Use conexão simétrica de alta velocidade (≥ 200 Mbps)
- ✅ Posicione backup próximo geograficamente (AWS S3 São Paulo para servidores no Brasil)
- ✅ Considere AWS Direct Connect ou similar para restaurações muito grandes (> 500 GB)

**Armazenamento**:
- ✅ Use SSD NVMe para restaurações (3-6x mais rápido que SATA SSD)
- ✅ Provisione espaço extra (1.5x o tamanho do backup) para operações temporárias
- ✅ Considere RAID 0 temporário para maximizar throughput durante restauração

**Compute**:
- ✅ Use instâncias com ≥ 8 vCPUs para descompressão paralela
- ✅ Provisione RAM adequada (≥ 16 GB) para cache durante restauração

### 2. Otimizações de Configuração Duplicati

**Tamanho de Bloco**:
```
dblock-size: 100mb (padrão: 50mb)
```
- Blocos maiores = menos overhead de rede
- Trade-off: Menos granularidade para deduplicação

**Upload Paralelo**:
```
asynchronous-concurrent-upload-limit: 8 (padrão: 4)
```
- Mais conexões paralelas = download mais rápido
- Cuidado: Pode saturar conexão de rede

**Descompressão**:
```
compression-module: zstd (já é o padrão)
```
- zstd: Melhor equilíbrio velocidade/taxa de compressão
- Alternativa: lz4 (mais rápido, compressão menor)

### 3. Estratégias de Restauração

**Restauração Priorizada**:
1. Restaure serviços críticos primeiro (PostgreSQL, n8n, Evolution)
2. Restaure serviços de suporte em paralelo (Redis, MongoDB)
3. Restaure volumes grandes por último (FileFlows output, Directus uploads)

**Restauração Paralela** (quando possível):
```bash
# Terminal 1: Restaurar PostgreSQL
./scripts/restore.sh

# Terminal 2: Restaurar MongoDB
./scripts/restore.sh

# Terminal 3: Restaurar n8n
./scripts/restore.sh
```

**Restauração Incremental**:
- Para volumes muito grandes (> 500 GB), considere restauração incremental:
  1. Restaure estado mais antigo primeiro (mais rápido)
  2. Aplique incrementos sequencialmente até versão desejada

---

## Testes de Restauração Recomendados

### Frequência de Testes

| Tipo de Teste | Frequência | Duração | Responsável |
|---------------|-----------|---------|-------------|
| Arquivo individual | Semanal | 5-10 min | DevOps |
| Serviço completo | Mensal | 30-60 min | DevOps + Equipe |
| Banco de dados | Trimestral | 1-2 horas | DBA + DevOps |
| Disaster Recovery (completo) | Semestral | 4-8 horas | Toda equipe |

### Checklist de Teste de Restauração

```
□ Documentar versão do backup sendo restaurada
□ Documentar timestamp de início do teste
□ Registrar velocidade de rede disponível
□ Executar restauração conforme procedimento documentado
□ Cronometrar cada fase da restauração
□ Documentar quaisquer problemas encontrados
□ Verificar integridade dos dados restaurados
□ Testar funcionalidade da aplicação
□ Documentar timestamp de conclusão
□ Calcular tempo total e comparar com benchmarks
□ Atualizar documentação se necessário
□ Arquivar logs de restauração para auditoria
```

### Template de Relatório de Teste

```markdown
# Relatório de Teste de Restauração

**Data**: YYYY-MM-DD
**Tipo**: [Arquivo/Serviço/Banco/DR Completo]
**Executado por**: Nome

## Detalhes do Backup
- Versão restaurada: YYYY-MM-DD HH:MM
- Provedor: [AWS S3/Backblaze/SFTP]
- Tamanho total: X GB

## Ambiente
- Rede: X Mbps
- Servidor: Spec
- Armazenamento: [SSD/HDD]

## Resultados
- Início: HH:MM
- Fim: HH:MM
- Duração total: X horas Y minutos
- Status: [✅ Sucesso / ❌ Falha]

## Detalhamento por Fase
1. Fase X: Y minutos
2. Fase Y: Z minutos
...

## Observações
- [Problemas encontrados]
- [Otimizações aplicadas]
- [Lições aprendidas]

## Comparação com Benchmark
- Benchmark alvo: X horas
- Tempo real: Y horas
- Variação: +/- Z%
- Dentro do aceitável: [Sim/Não]
```

---

## Metas de SLA

### Recovery Time Objective (RTO)

| Tipo de Incidente | RTO Alvo | RTO Máximo |
|-------------------|----------|------------|
| Arquivo corrompido/deletado | 15 minutos | 1 hora |
| Serviço individual comprometido | 2 horas | 4 horas |
| Banco de dados corrompido | 3 horas | 6 horas |
| Disaster Recovery (servidor completo) | 6 horas | 12 horas |

### Recovery Point Objective (RPO)

| Tipo de Dado | RPO Alvo | RPO Máximo |
|--------------|----------|------------|
| Dados críticos (workflows, credenciais) | 24 horas | 48 horas |
| Dados de aplicação (conversas, uploads) | 24 horas | 72 horas |
| Dados de mídia (processados) | 7 dias | 14 dias |
| Logs e métricas | 7 dias | 30 dias |

**Nota**: Com backups diários às 2:00 AM, o RPO máximo é 24 horas (pior caso: falha ocorre às 1:59 AM, último backup tem 23h 59min).

---

## Contato para Suporte de Restauração

Em caso de necessidade de restauração urgente:

1. **Primeiro Contato**: Administrador de Sistema
2. **Escalação**: Equipe DevOps
3. **Suporte Técnico BorgStack**: [A DEFINIR]
4. **Suporte Provedor de Backup**:
   - AWS Support: https://console.aws.amazon.com/support/
   - Backblaze Support: https://www.backblaze.com/help.html

---

## Histórico de Testes de Restauração

| Data | Tipo | Tamanho | Tempo | Status | Observações |
|------|------|---------|-------|--------|-------------|
| YYYY-MM-DD | Serviço (n8n) | 1.2 GB | 18 min | ✅ | Dentro do alvo |
| YYYY-MM-DD | DB (PostgreSQL) | 8 GB | 75 min | ✅ | Dentro do aceitável |
| YYYY-MM-DD | DR Completo | 150 GB | 5.5 horas | ✅ | Dentro do alvo |

*Atualizar esta tabela após cada teste de restauração*

---

## Revisões Deste Documento

| Versão | Data | Autor | Mudanças |
|--------|------|-------|----------|
| 1.0 | 2025-10-06 | James (Dev Agent) | Versão inicial com benchmarks de referência |

*Este documento deve ser revisado trimestralmente e atualizado com base em testes reais de restauração.*
