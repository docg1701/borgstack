# FileFlows - Processamento Automático de Mídia

## O que é FileFlows?

FileFlows é uma plataforma de processamento automático de arquivos de mídia que monitora diretórios, aplica fluxos de transformação e gera arquivos processados. Utiliza FFmpeg para transcodificação de vídeo, áudio e imagens através de uma interface visual de fluxos de trabalho.

**Principais Recursos:**
- Transcodificação de vídeo/áudio/imagem usando FFmpeg
- Designer visual de fluxos de processamento (drag-and-drop)
- Monitoramento automático de diretórios para processamento
- Nós de processamento configuráveis (local ou distribuído)
- Integração com Directus e n8n para automação de mídia
- Suporte a WebSocket para atualizações de status em tempo real

**Acesso ao Sistema:**
- **Interface Web:** https://fileflows.{SEU_DOMINIO}
- **Designer de Fluxos:** https://fileflows.{SEU_DOMINIO}/flows
- **Monitoramento:** https://fileflows.{SEU_DOMINIO}/processing

---

## Acessando o FileFlows

### Primeiro Login

1. **Aguarde o Container estar Saudável**
   ```bash
   docker compose ps fileflows
   ```
   Aguarde até o status mostrar `healthy` (pode levar 60 segundos para inicialização do Node.js e verificação do FFmpeg).

2. **Acesse a Interface Web**
   - Navegue para: `https://fileflows.{SEU_DOMINIO}`
   - Você será apresentado ao assistente de configuração inicial

3. **Complete o Assistente de Configuração Inicial**
   - Siga os passos para criar conta de administrador
   - Configure o nó de processamento local (servidor)

---

## Configurando Nós de Processamento

Nós de processamento executam os trabalhos de conversão de mídia. Pelo menos um nó é necessário.

### Criar Nó de Servidor Local

1. **Acesse Configurações de Nós**
   - Vá para **Configurações → Nós de Processamento** no menu lateral

2. **Crie um Novo Nó**
   - Clique em **"Adicionar Nó"**
   - Digite o nome: `Servidor Local BorgStack`

3. **Configure o Nó**
   - **Nome do Nó:** `Servidor Local BorgStack` (ou nome personalizado)
   - **Diretório Temp:** `/temp` (já configurado no docker-compose.yml)
   - **Processamento Concorrente:** `2` (para servidor com 8 vCPUs)
   - **Habilitado:** ✅ Sim

4. **Diretrizes de Capacidade**
   - **Carga leve:** 1-2 trabalhos simultâneos por 4 núcleos de CPU
   - **Carga pesada:** 1 trabalho simultâneo por 4 núcleos (transcodificação intensiva)
   - **Servidor com 8 vCPUs:** Comece com 2 trabalhos simultâneos, monitore uso da CPU

5. **Salve o Nó**
   - Clique em **"Salvar"**

### Verificar FFmpeg

O FFmpeg é incluído na imagem Docker por padrão.

1. Vá para **Configurações → Sistema**
2. Role até a seção **FFmpeg**
3. Verifique **Caminho do FFmpeg:** `/usr/bin/ffmpeg`
4. Clique em **Testar FFmpeg** para verificar que os codecs estão disponíveis

Resultado esperado: ✅ FFmpeg funcionando corretamente

---

## Criando Bibliotecas

Bibliotecas são diretórios que o FileFlows monitora para novos arquivos a serem processados.

### Criar Biblioteca de Entrada

1. **Acesse Bibliotecas**
   - Vá para **Bibliotecas** → **Adicionar Biblioteca**

2. **Configure a Biblioteca**
   - **Nome:** `Entrada de Mídia`
   - **Caminho:** `/input`
   - **Intervalo de Varredura:** `60 segundos` (verifica novos arquivos a cada minuto)
   - **Habilitado:** ✅ Sim
   - **Padrão de Arquivo:** `*.*` (todos os arquivos) ou extensões específicas (ex: `*.mp4,*.mkv,*.avi`)

3. **Salve a Biblioteca**
   - Clique em **"Salvar"**

### Biblioteca de Saída

O FileFlows coloca automaticamente os arquivos processados no diretório de saída definido no fluxo. Não é necessário configuração separada para saída.

### Modo de Monitoramento

O FileFlows monitora o diretório da biblioteca de entrada (`/input`) para novos arquivos. Quando um novo arquivo é detectado:

1. FileFlows verifica se o arquivo corresponde a um filtro de **Fluxo** (extensão, tamanho, etc.)
2. Se corresponder, o Fluxo é disparado automaticamente
3. O processamento começa no próximo slot disponível do Nó de Processamento

---

## Criando Fluxos de Processamento

Fluxos são pipelines visuais de processamento: **Entrada** → **Etapas de Processamento** → **Saída**

### Criar um Fluxo

1. **Acesse Fluxos**
   - Vá para **Fluxos** → **Adicionar Fluxo**

2. **Digite o Nome do Fluxo**
   - Exemplo: "Transcodificação de Vídeo H.264"

3. **Abra o Designer de Fluxos**
   - Clique em **"Criar"** para abrir o designer visual

### Interface do Designer de Fluxos

- **Canvas:** Arraste e solte nós de processamento
- **Caixa de Ferramentas (Esquerda):** Nós de processamento disponíveis
- **Propriedades (Direita):** Configure o nó selecionado

### Estrutura Básica de Fluxo

```
[Arquivo de Entrada] → [Filtro de Arquivo] → [Processar FFmpeg] → [Mover Arquivo] → [Saída]
```

---

## Exemplos de Fluxos Comuns

### Fluxo 1: Transcodificação de Vídeo para H.264

**Objetivo:** Converter todos os vídeos para H.264 com qualidade balanceada

**Etapas do Fluxo:**

1. **Entrada:** Arquivo da biblioteca `/input` (automático)

2. **Filtro de Arquivo:** Verificar se a extensão é vídeo
   - Extensões: `.mp4`, `.mkv`, `.avi`, `.mov`, `.webm`

3. **FFmpeg:** Transcodificar para H.264
   - Comando: `-c:v libx264 -crf 23 -preset medium -c:a aac -b:a 128k`
   - **Explicação:**
     - `-c:v libx264`: Codec de vídeo H.264 (software)
     - `-crf 23`: Fator de Qualidade Constante (18=alta, 28=baixa, 23=balanceado)
     - `-preset medium`: Velocidade de codificação (ultrafast a veryslow, medium=balanceado)
     - `-c:a aac`: Codec de áudio AAC
     - `-b:a 128k`: Taxa de bits de áudio 128 kbps

4. **Mover Arquivo:** Mover para `/output/{nome_do_arquivo}_h264.mp4`

5. **Deletar Original:** (Opcional) Remover arquivo original do `/input`

**Habilitar Fluxo:** Ative o switch **Habilitado** nas configurações do fluxo

**Testar Fluxo:**
```bash
docker compose cp teste-video.mp4 fileflows:/input/
```

Monitore o processamento em **Processamento** → **Trabalhos Ativos**

### Fluxo 2: Normalização de Áudio

**Objetivo:** Normalizar níveis de áudio usando filtro loudnorm do FFmpeg

**Etapas do Fluxo:**

1. **Entrada:** Arquivo da biblioteca `/input`

2. **Filtro de Arquivo:** Verificar se é arquivo de áudio
   - Extensões: `.mp3`, `.wav`, `.flac`, `.m4a`, `.aac`, `.ogg`

3. **FFmpeg:** Normalizar áudio
   - Comando: `-af loudnorm=I=-16:TP=-1.5:LRA=11 -c:a aac -b:a 192k`
   - **Explicação:**
     - `loudnorm`: Normalização de loudness EBU R128
     - `I=-16 LUFS`: Loudness integrado alvo (padrão de transmissão)
     - `TP=-1.5 dBTP`: Limite de pico verdadeiro (previne clipping)
     - `LRA=11 LU`: Intervalo de loudness alvo (faixa dinâmica)

4. **Mover Arquivo:** Mover para `/output/{nome_do_arquivo}_normalizado.m4a`

**Caso de Uso:** Normalizar episódios de podcast, faixas de música ou audiolivros para volume de reprodução consistente

### Fluxo 3: Conversão de Imagem para WebP

**Objetivo:** Converter imagens para formato WebP para entrega web otimizada

**Etapas do Fluxo:**

1. **Entrada:** Arquivo da biblioteca `/input`

2. **Filtro de Arquivo:** Verificar se é imagem
   - Extensões: `.jpg`, `.jpeg`, `.png`, `.bmp`, `.tiff`

3. **FFmpeg:** Converter para WebP
   - Comando: `-c:v libwebp -quality 80 -compression_level 6`
   - **Explicação:**
     - `libwebp`: Codec de imagem WebP
     - `quality 80`: Qualidade WebP (0=pior, 100=lossless, 80=balanceado)
     - `compression_level 6`: Esforço de compressão (0=rápido, 6=balanceado, 9=lento/melhor)

4. **Mover Arquivo:** Mover para `/output/{nome_do_arquivo}.webp`

**Caso de Uso:** Otimizar imagens para web - WebP fornece 25-35% de redução no tamanho com qualidade equivalente a JPEG/PNG

---

## Integração com Directus e n8n

FileFlows integra-se com outros serviços BorgStack através de fluxos de trabalho n8n.

### Fluxo de Trabalho 1: Upload no Directus → Processamento no FileFlows

**Gatilho:** Usuário faz upload de vídeo no Directus CMS

**Fluxo de Trabalho:**

1. Usuário faz upload de vídeo no Directus (armazenado em `/uploads`)
2. Directus dispara webhook n8n com metadados do arquivo
3. n8n copia arquivo do Directus para entrada do FileFlows:
   ```
   /directus/uploads/{arquivo} → /input/{arquivo}
   ```
4. FileFlows detecta novo arquivo e inicia processamento
5. FileFlows processa arquivo (transcodifica H.264) e gera saída para `/output`
6. FileFlows envia webhook para n8n com status de conclusão
7. n8n atualiza Directus com URL do arquivo processado

**Fluxo n8n:**
- Gatilho Webhook (Directus → n8n)
- Copiar Arquivo (uploads do Directus → entrada do FileFlows)
- Aguardar Webhook (FileFlows → n8n)
- Atualizar Directus (definir URL do arquivo processado)

### Fluxo de Trabalho 2: Processamento Manual via n8n

**Gatilho:** Requisição HTTP n8n de aplicativo Lowcoder ou sistema externo

**Fluxo de Trabalho:**

1. Sistema externo chama n8n: `POST /webhook/processar-midia` com URL do arquivo
2. n8n baixa arquivo para entrada do FileFlows: `wget {url} -O /input/{nome_arquivo}`
3. FileFlows processa arquivo automaticamente
4. n8n recebe webhook de conclusão do FileFlows
5. n8n retorna URL do arquivo processado ao chamador

**Exemplo de Webhook n8n para FileFlows:**
```javascript
// Nó de Requisição HTTP n8n para disparar processamento do FileFlows
{
  "method": "POST",
  "url": "http://fileflows:5000/api/flow/trigger",
  "body": {
    "filename": "{{ $json.filename }}",
    "source_path": "/input/{{ $json.filename }}",
    "flow_id": "video-h264-transcode"
  }
}
```

---

## Monitoramento de Processamento

### Acompanhar Trabalhos Ativos

1. **Acesse Processamento**
   - Vá para **Processamento** → **Trabalhos Ativos**

2. **Visualize o Progresso**
   - Veja os arquivos sendo processados em tempo real
   - Verifique a porcentagem de conclusão
   - Monitore o nó executando o trabalho

3. **Verifique o Histórico**
   - Vá para **Processamento** → **Histórico**
   - Veja trabalhos concluídos, com falha ou cancelados
   - Clique em um trabalho para ver logs detalhados do FFmpeg

### Monitorar Recursos do Servidor

Durante o processamento, monitore o uso de CPU/RAM do container:

```bash
docker stats fileflows
```

Observe as colunas **CPU %** e **USO DE MEM**.

**Para arquivos grandes:**
- Certifique-se de que o volume `/temp` tenha espaço adequado (arquivos temporários podem ser 2-3x o tamanho do arquivo de entrada durante o processamento)
- Considere usar preset de codificação mais rápido (`-preset fast` em vez de `-preset medium`)

---

## Solução de Problemas

### Container do FileFlows Não Inicia

**Verificar logs:**
```bash
docker compose logs fileflows --tail=100
```

**Problemas comuns:**
- **Erros de permissão:** Verifique se PUID/PGID correspondem ao usuário do host (`id -u && id -g`)
- **Erros de montagem de volume:** Certifique-se de que os diretórios `/input`, `/output`, `/temp` estejam acessíveis

### Processamento Falha

**Verificar logs do FFmpeg:**
1. Vá para **Processamento** → **Histórico**
2. Clique no trabalho com falha
3. Visualize **Saída de Log** para erros do FFmpeg

**Erros comuns do FFmpeg:**
- **Codec não suportado:** Verifique se o FFmpeg tem o codec necessário:
  ```bash
  docker compose exec fileflows ffmpeg -codecs | grep {codec}
  ```
- **Sem espaço em disco:** Verifique se o volume `/temp` tem espaço adequado
- **Arquivo de entrada corrompido:** Verifique a integridade do arquivo:
  ```bash
  ffprobe {arquivo}
  ```

### Arquivo Não Detectado

**Verificar configuração da biblioteca:**
1. Vá para **Bibliotecas**
2. Certifique-se de que a biblioteca está **Habilitada:** ✅ Sim
3. Certifique-se de que **Caminho:** `/input` está correto
4. Certifique-se de que **Padrão de Arquivo:** corresponde aos seus arquivos (ex: `*.mp4`)

**Forçar varredura da biblioteca:**
1. Vá para **Bibliotecas** → **Entrada de Mídia**
2. Clique em **Varrer Agora** para forçar nova varredura

**Verificar permissões de arquivo:**
```bash
docker compose exec fileflows ls -la /input
```

Os arquivos devem ser legíveis pelo usuário do container (PUID/PGID).

### Interface Web Não Acessível

**Verificar roteamento do Caddy:**
```bash
docker compose logs caddy | grep fileflows
```

**Verificar saúde do container FileFlows:**
```bash
docker compose ps fileflows
```

Status esperado: `Up (healthy)`

**Testar acesso direto ao container:**
```bash
docker compose exec caddy curl http://fileflows:5000/
```

Resposta esperada: Página HTML (interface do FileFlows)

### Problemas de Performance

**Reduzir processamento concorrente:**
1. Vá para **Configurações** → **Nós de Processamento**
2. Reduza **Trabalhos Paralelos Máximos** para `1`
3. Monitore uso de CPU/RAM do servidor: `docker stats fileflows`

**Para arquivos grandes:**
- Certifique-se de que o volume `/temp` tenha espaço adequado
- Considere usar preset de codificação mais rápido (`-preset fast`)

---

## Referência de Comandos FFmpeg

### Codecs de Vídeo Comuns

```bash
# H.264 (melhor compatibilidade)
-c:v libx264 -crf 23 -preset medium

# H.265 (melhor compressão, processamento mais lento)
-c:v libx265 -crf 28 -preset medium

# VP9 (formato aberto, bom para web)
-c:v libvpx-vp9 -crf 31 -b:v 0

# AV1 (melhor compressão futura, muito lento)
-c:v libaom-av1 -crf 30 -b:v 0
```

### Codecs de Áudio Comuns

```bash
# AAC (melhor compatibilidade)
-c:a aac -b:a 128k

# MP3 (amplamente suportado)
-c:a libmp3lame -b:a 192k

# Opus (melhor qualidade por bit)
-c:a libopus -b:a 128k

# FLAC (sem perdas)
-c:a flac
```

### Filtros Comuns

```bash
# Redimensionar vídeo para 1920x1080
-vf scale=1920:1080

# Cortar vídeo para 1920x1080 do canto superior esquerdo
-vf crop=1920:1080:0:0

# Normalização de áudio
-af loudnorm=I=-16:TP=-1.5:LRA=11

# Desentrelaçar vídeo
-vf yadif=0:-1:0

# Redução de ruído de vídeo
-vf hqdn3d
```

---

## 8. Dicas e Melhores Práticas

### 8.1 Configuração Otimizada
Consulte [docs/02-configuracao.md](../02-configuracao.md) para variáveis de ambiente específicas deste serviço.

### 8.2 Performance
- Consultar documentação oficial para tuning de fileflows
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

- **Documentação Técnica:** `/config/fileflows/README.md` (guia técnico completo)
- **Fluxos de Exemplo:** `/config/fileflows/example-flows.json` (templates de fluxo)
- **Template de Migração S3:** `/config/fileflows/s3-storage.env.example` (migração futura para SeaweedFS)
- **Comunidade FileFlows:** https://discord.gg/fileflows
- **Documentação FFmpeg:** https://ffmpeg.org/documentation.html

---

**Dúvidas ou problemas?**
- Verifique os logs: `docker compose logs fileflows --tail=100`
- Verifique a saúde: `docker compose ps fileflows`
- Consulte a documentação técnica em `config/fileflows/README.md`
