# Directus - CMS Sem Cabeça (Headless CMS)

## O que é Directus?

Directus é uma plataforma de gerenciamento de conteúdo headless (CMS sem interface front-end tradicional) que fornece APIs REST e GraphQL para entrega de conteúdo. Permite criar modelos de dados personalizados, gerenciar conteúdo, fazer upload de arquivos e controlar permissões de usuários.

**Principais Recursos:**
- Modelagem flexível de dados (coleções e campos personalizados)
- APIs REST e GraphQL automáticas para todo o conteúdo
- Gerenciamento de arquivos e mídia
- Controle granular de permissões por função
- Interface de administração moderna e intuitiva
- Suporte a WebSocket para atualizações em tempo real

**Acesso ao Sistema:**
- **Interface Admin:** https://directus.{SEU_DOMINIO}/admin
- **API REST:** https://directus.{SEU_DOMINIO}/items/{coleção}
- **API GraphQL:** https://directus.{SEU_DOMINIO}/graphql

---

## Acessando o Directus

### Primeiro Login

1. **Aguarde o Container estar Saudável**
   ```bash
   docker compose ps directus
   ```
   Aguarde até o status mostrar `healthy` (pode levar 60-90 segundos para migrações do banco de dados).

2. **Acesse a Interface Admin**
   - Navegue para: `https://directus.{SEU_DOMINIO}/admin`
   - Faça login com as credenciais do arquivo `.env`:
     - Email: `DIRECTUS_ADMIN_EMAIL` (padrão: admin@{SEU_DOMINIO})
     - Senha: `DIRECTUS_ADMIN_PASSWORD` (gerada automaticamente pelo bootstrap)

3. **Encontre suas Credenciais**
   ```bash
   grep "DIRECTUS_ADMIN" .env
   ```

---

## Criando Coleções

Coleções no Directus são como tabelas de banco de dados que armazenam seu conteúdo.

### Passo a Passo

1. **Acesse o Modelo de Dados**
   - Vá para **Configurações → Modelo de Dados** no menu lateral

2. **Crie uma Nova Coleção**
   - Clique em **"Criar Coleção"**
   - Digite o nome da coleção (ex: `artigos_blog`, `produtos`, `membros_equipe`)

3. **Escolha o Tipo de Coleção**
   - **Coleção Padrão:** Conteúdo regular com múltiplos itens
   - **Singleton:** Coleção de item único (ex: configurações do site)

4. **Configure as Opções**
   - Modelo de exibição (como os itens são mostrados em listas)
   - Ícone e cor para navegação

5. **Salve a Coleção**
   - Clique em **"Salvar"**

### Exemplo: Coleção de Artigos de Blog

```text
Nome da Coleção: artigos_blog

Configurações:
- Tipo: Coleção Padrão
- Ícone: article
- Cor: Azul
- Modelo de Exibição: {{titulo}}
```text

---

## Adicionando Campos

Depois de criar uma coleção, você precisa adicionar campos para armazenar diferentes tipos de dados.

### Tipos de Campos Disponíveis

1. **Entrada (Input)**
   - Texto curto, texto longo, número, booleano, data/hora

2. **Seleção (Selection)**
   - Dropdown, radio buttons, checkboxes

3. **Relacional (Relational)**
   - Muitos-para-um, um-para-muitos, muitos-para-muitos

4. **Arquivo (File)**
   - Upload de imagens, documentos, vídeos

5. **Apresentação (Presentation)**
   - Divisória, aviso (apenas para organização da interface)

### Passo a Passo para Adicionar Campo

1. **Selecione sua Coleção**
   - Em **Configurações → Modelo de Dados**, clique na coleção

2. **Crie um Novo Campo**
   - Clique em **"Criar Campo"** ou no botão **"+"**

3. **Escolha o Tipo de Campo**
   - Selecione entre Input, Selection, Relational, File, etc.

4. **Configure o Campo**
   - **Nome do campo:** Chave da API (ex: `titulo`, `conteudo`)
   - **Nome de exibição:** Rótulo na interface (ex: "Título", "Conteúdo")
   - **Validação:** Obrigatório, único, padrão regex
   - **Valor padrão:** Valor inicial para novos itens

5. **Salve o Campo**
   - Clique em **"Salvar"**

### Exemplo: Campos para Artigos de Blog

```text
Campo: titulo
- Tipo: Input → Text
- Validação: Obrigatório
- Interface: Caixa de texto

Campo: slug
- Tipo: Input → Text
- Validação: Obrigatório, Único
- Interface: Caixa de texto (URL-friendly)

Campo: conteudo
- Tipo: Input → WYSIWYG (Editor rico)
- Interface: Editor de texto rico

Campo: autor
- Tipo: Input → Text
- Interface: Caixa de texto

Campo: data_publicacao
- Tipo: Input → DateTime
- Interface: Seletor de data/hora

Campo: imagem_destaque
- Tipo: File → Image
- Interface: Upload de imagem

Campo: status
- Tipo: Selection → Dropdown
- Opções: rascunho, publicado, arquivado
- Valor padrão: rascunho
```text

---

## Gerenciando Conteúdo

### Criar Conteúdo

1. Navegue até sua coleção no menu **Conteúdo**
2. Clique em **"Criar Item"**
3. Preencha os campos
4. Clique em **"Salvar"**

### Visualizar/Editar Conteúdo

1. Navegue até sua coleção
2. Use filtros, pesquisa e ordenação para encontrar itens
3. Clique em um item para visualizar/editar detalhes

### Excluir Conteúdo

1. Selecione um item na coleção
2. Clique no **ícone de lixeira** ou botão **"Excluir"**
3. Confirme a exclusão

---

## Upload de Arquivos

### Fazer Upload de Arquivos

1. **Acesse a Biblioteca de Arquivos**
   - Clique em **"Biblioteca de Arquivos"** no menu lateral

2. **Envie Arquivos**
   - Clique em **"Enviar Arquivos"** ou arraste e solte arquivos
   - Arquivos são armazenados no volume Docker `borgstack_directus_uploads`

3. **Acesse Arquivos**
   - URL de acesso: `https://directus.{SEU_DOMINIO}/assets/{id_do_arquivo}`

### Usar Arquivos em Coleções

1. Adicione um campo **File** à sua coleção
2. Ao criar/editar um item, clique no campo de arquivo
3. Escolha entre arquivos existentes ou faça upload de novos

### Armazenamento Atual

**Armazenamento Local (Story 4.1):**
- Volume: `borgstack_directus_uploads`
- Caminho no container: `/directus/uploads`

**Futura Migração para S3 (Story 5.1):**
- Armazenamento distribuído com SeaweedFS
- API compatível com S3
- Ver `config/directus/s3-storage.env.example` para detalhes

---

## APIs REST e GraphQL

O Directus gera automaticamente APIs REST e GraphQL para todo o seu conteúdo.

### API REST

**URL Base:**
```text
https://directus.{SEU_DOMINIO}
```text

**Endpoints Comuns:**

| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/items/{coleção}` | GET | Listar itens da coleção |
| `/items/{coleção}/{id}` | GET | Obter item específico |
| `/items/{coleção}` | POST | Criar novo item |
| `/items/{coleção}/{id}` | PATCH | Atualizar item |
| `/items/{coleção}/{id}` | DELETE | Excluir item |
| `/assets/{id_arquivo}` | GET | Acessar arquivo |

**Exemplo: Listar Artigos**
```bash
curl https://directus.{SEU_DOMINIO}/items/artigos_blog
```text

**Exemplo: Criar Artigo**
```bash
curl -X POST https://directus.{SEU_DOMINIO}/items/artigos_blog \
  -H "Authorization: Bearer SEU_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"titulo": "Olá Mundo", "conteudo": "Meu primeiro artigo"}'
```text

### API GraphQL

**Endpoint:**
```text
https://directus.{SEU_DOMINIO}/graphql
```text

**Exemplo de Query:**
```graphql
query {
  artigos_blog(filter: { status: { _eq: "publicado" } }) {
    id
    titulo
    conteudo
    autor
    data_publicacao
  }
}
```text

**Exemplo de Mutation:**
```graphql
mutation {
  create_artigos_blog_item(data: {
    titulo: "Artigo via GraphQL"
    conteudo: "Criado com GraphQL"
    status: "rascunho"
  }) {
    id
    titulo
  }
}
```text

### Autenticação da API

Para acessar a API, você precisa de um token de autenticação:

1. **Gerar Token**
   - Faça login no Directus
   - Vá para **Menu do Usuário → Tokens de Acesso**
   - Clique em **"Criar Novo Token"**
   - Copie o token gerado

2. **Usar Token nas Requisições**
   ```bash
   curl -H "Authorization: Bearer SEU_TOKEN" \
        https://directus.{SEU_DOMINIO}/items/artigos_blog
   ```

---

## Gerenciamento de Usuários e Permissões

### Criar Usuários

1. Vá para **Configurações → Controle de Acesso → Usuários**
2. Clique em **"Criar Usuário"**
3. Preencha os detalhes:
   - Email (usado para login)
   - Senha
   - Nome, sobrenome
4. Atribua uma função (define permissões)
5. Clique em **"Salvar"**

### Gerenciar Funções

1. Vá para **Configurações → Controle de Acesso → Funções**
2. Clique em **"Criar Função"** ou edite uma função existente
3. Configure permissões:
   - **Público:** Sem autenticação necessária
   - **Administrador:** Acesso total a tudo
   - **Funções Personalizadas:** Permissões granulares por coleção

### Níveis de Permissão

Para cada coleção, você pode definir permissões CRUD:
- **Criar:** Pode adicionar novos itens
- **Ler:** Pode visualizar itens
- **Atualizar:** Pode editar itens
- **Excluir:** Pode remover itens

Permissões podem ter condições (ex: "apenas ler itens onde autor = usuário atual").

---

## Integração com n8n

O Directus pode acionar workflows do n8n em eventos de conteúdo.

### Casos de Uso

- Publicar artigo → Enviar notificação via WhatsApp (Evolution API)
- Upload de imagem de produto → Processar com FileFlows → Atualizar registro
- Criar consulta de cliente → Criar ticket no Chatwoot

### Métodos de Integração

1. **Nó Directus do n8n:**
   - Disponível no editor de workflow do n8n
   - Suporta operações CRUD em coleções
   - Requer token de API para autenticação

2. **Webhooks:**
   - Configure em **Configurações → Webhooks**
   - Aciona workflow do n8n em eventos de conteúdo (criar, atualizar, excluir)
   - Envia HTTP POST para: `https://n8n.{SEU_DOMINIO}/webhook/evento-directus`

3. **Chamadas à API REST:**
   - Use o nó HTTP Request do n8n
   - Chame endpoints da API REST do Directus
   - Inclua token Bearer para autenticação

---

## Solução de Problemas

### Problema: Falha nas Migrações do Banco de Dados

**Sintomas:** Container inicia mas mostra erros de banco de dados nos logs

**Verificar logs do PostgreSQL:**
```bash
docker compose logs postgresql | grep -i error
```text

**Verificar permissões do directus_user:**
```bash
docker compose exec postgresql psql -U postgres -c "\du" | grep directus_user
```text

**Solução:**
- Verifique se `directus_db` existe e pertence a `directus_user`
- Confirme que `DIRECTUS_DB_PASSWORD` no `.env` corresponde ao PostgreSQL
- Verifique o script de inicialização: `config/postgresql/init-databases.sql`

### Problema: Falha no Upload de Arquivos

**Sintomas:** Upload de arquivos falha ou arquivos não aparecem

**Verificar montagem do volume:**
```bash
docker compose exec directus ls -la /directus/uploads
```text

**Verificar STORAGE_LOCATIONS:**
```bash
docker compose exec directus env | grep STORAGE_LOCATIONS
```text

**Solução:**
- Verifique se `STORAGE_LOCATIONS=local` está definido
- Confirme que o volume `borgstack_directus_uploads` está montado
- Verifique permissões de arquivo no container

### Problema: Cache do Redis Não Funciona

**Sintomas:** Respostas lentas da API, cache misses nos logs

**Verificar conexão com Redis:**
```bash
docker compose exec redis redis-cli -a ${REDIS_PASSWORD} ping
```text

**Verificar configuração do Directus:**
```bash
docker compose exec directus env | grep REDIS
```text

**Solução:**
- Verifique se `REDIS_PASSWORD` corresponde no `.env` e configuração do Redis
- Confirme que Redis está acessível em `redis:6379` pela rede `borgstack_internal`
- Verifique se `CACHE_ENABLED=true` no docker-compose.yml

### Problema: Falha no Login do Admin

**Sintomas:** Não consegue fazer login com credenciais admin

**Verificar criação do usuário admin nos logs:**
```bash
docker compose logs directus | grep -i "admin"
```text

**Verificar credenciais:**
```bash
grep "DIRECTUS_ADMIN" .env
```text

**Solução:**
- Usuário admin criado automaticamente na primeira inicialização
- Verifique se `ADMIN_EMAIL` e `ADMIN_PASSWORD` estão corretos no `.env`
- Reinicie o container se o usuário admin não foi criado: `docker compose restart directus`

---

## Recursos Adicionais

### Documentação Oficial
- Documentação do Directus: https://docs.directus.io/
- Referência da API REST: https://docs.directus.io/reference/introduction.html
- Referência GraphQL: https://docs.directus.io/reference/query.html

### Guias de Integração BorgStack
- Documentação Técnica: `config/directus/README.md`
- Exemplos de Integração n8n: `config/n8n/workflows/`
- Integração Lowcoder: Conecte Directus como fonte de dados em apps Lowcoder

### Suporte
- Issues do GitHub: https://github.com/directus/directus/issues
- Discord da Comunidade: https://directus.chat/
- Issues BorgStack: https://github.com/{SUA_ORG}/borgstack/issues

---

**Última Atualização:** 2025-10-04 (Story 4.1)
**Mantido por:** Equipe de Desenvolvimento BorgStack
