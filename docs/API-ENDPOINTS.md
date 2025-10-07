# 🌐 Estrutura de Endpoints - API Sistema de Gestão de Chamados

Definição completa dos endpoints REST necessários para atender toda a hierarquia organizacional e funcionalidades do sistema.

## 📋 Visão Geral da API

### 🎯 Características Principais
- **RESTful**: Seguindo padrões REST
- **Autenticação JWT**: Tokens com permissões específicas
- **Paginação**: Todas as listas com paginação
- **Filtros Avançados**: Query parameters para filtragem
- **RBAC**: Role-Based Access Control por endpoint
- **Versionamento**: `/api/v1/` como base

### 🔧 Tecnologia Base
- **FastAPI**: Framework principal
- **SQLAlchemy**: ORM para banco de dados
- **Pydantic**: Validação e serialização
- **JWT**: Autenticação e autorização

---

## 🔐 Autenticação e Autorização

### **POST** `/api/v1/auth/login`
**Descrição**: Login do usuário no sistema
```json
{
  "email": "lee@empresa.com",
  "password": "senha123"
}
```
**Resposta**:
```json
{
  "access_token": "jwt_token_here",
  "token_type": "bearer",
  "expires_in": 3600,
  "user": {
    "id": "uuid",
    "nome_completo": "Lee Chardes",
    "email": "lee@empresa.com",
    "tipo_usuario": "director",
    "perfil": {
      "cargo": "Diretor Técnico",
      "departamento": "Diretoria",
      "nivel_acesso": 3
    }
  }
}
```

### **POST** `/api/v1/auth/refresh`
**Descrição**: Renovar token JWT
**Headers**: `Authorization: Bearer {token}`

### **GET** `/api/v1/auth/me`
**Descrição**: Dados do usuário logado
**Permissões**: Qualquer usuário autenticado

### **POST** `/api/v1/auth/logout`
**Descrição**: Logout (invalidar token)

---

## 👥 Gestão de Usuários

### **GET** `/api/v1/usuarios`
**Descrição**: Listar usuários com filtros
**Permissões**: `usuarios.view_all` (Diretoria, Coordenação)
**Query Parameters**:
- `page=1&per_page=20` - Paginação
- `tipo_usuario=support_analyst` - Filtrar por tipo
- `departamento=Suporte` - Filtrar por departamento
- `ativo=true` - Apenas ativos
- `search=João` - Busca por nome/email

### **POST** `/api/v1/usuarios`
**Descrição**: Criar novo usuário
**Permissões**: `usuarios.create` (Diretoria)
```json
{
  "email": "novo@empresa.com",
  "nome_completo": "Novo Usuario",
  "tipo_usuario": "support_analyst",
  "senha": "senha_temporaria",
  "perfil": {
    "cargo": "Analista de Suporte",
    "departamento": "Suporte",
    "telefone": "(11) 99999-9999"
  }
}
```

### **GET** `/api/v1/usuarios/{user_id}`
**Descrição**: Detalhes de um usuário específico
**Permissões**: `usuarios.view` ou próprio usuário

### **PUT** `/api/v1/usuarios/{user_id}`
**Descrição**: Atualizar dados do usuário
**Permissões**: `usuarios.edit` ou próprio usuário

### **DELETE** `/api/v1/usuarios/{user_id}`
**Descrição**: Desativar usuário
**Permissões**: `usuarios.delete` (Diretoria)

### **POST** `/api/v1/usuarios/{user_id}/reset-password`
**Descrição**: Resetar senha do usuário
**Permissões**: `usuarios.reset_password` (Coordenação+)

---

## 🏢 Gestão de Equipes

### **GET** `/api/v1/equipes`
**Descrição**: Listar todas as equipes
**Permissões**: `equipes.view_all` (Coordenação+)

### **POST** `/api/v1/equipes`
**Descrição**: Criar nova equipe
**Permissões**: `equipes.create` (Diretoria)
```json
{
  "nome": "Suporte Mobile",
  "descricao": "Equipe especializada em suporte mobile",
  "departamento": "Suporte",
  "lider_id": "uuid_glaucia"
}
```

### **GET** `/api/v1/equipes/{equipe_id}/membros`
**Descrição**: Membros de uma equipe
**Permissões**: `equipes.view_members`

### **POST** `/api/v1/equipes/{equipe_id}/membros`
**Descrição**: Adicionar membro à equipe
**Permissões**: `equipes.manage_members` (Coordenação+)
```json
{
  "usuario_id": "uuid_usuario",
  "papel": "membro"
}
```

---

## 🏪 Gestão de Clientes

### **GET** `/api/v1/clientes`
**Descrição**: Listar clientes conforme permissão
**Permissões**: Filtrado por `clientes_atribuidos` do usuário
**Query Parameters**:
- `page=1&per_page=20`
- `ativo=true`
- `search=Nome Cliente`

### **POST** `/api/v1/clientes`
**Descrição**: Criar novo cliente
**Permissões**: `clientes.create` (Comercial+)
```json
{
  "nome_empresa": "Tech Solutions LTDA",
  "cnpj": "12.345.678/0001-90",
  "email_contato": "contato@techsolutions.com",
  "telefone": "(11) 3333-4444",
  "endereco": {
    "logradouro": "Av. Paulista, 1000",
    "cidade": "São Paulo",
    "estado": "SP",
    "cep": "01310-100"
  },
  "sla_padrao_horas": 24
}
```

### **GET** `/api/v1/clientes/{cliente_id}`
**Descrição**: Detalhes do cliente
**Permissões**: Acesso ao cliente específico

### **GET** `/api/v1/clientes/{cliente_id}/filiais`
**Descrição**: Filiais do cliente

### **POST** `/api/v1/clientes/{cliente_id}/filiais`
**Descrição**: Criar filial
```json
{
  "nome": "Filial São Paulo",
  "codigo": "SP001",
  "responsavel_nome": "João Silva",
  "responsavel_email": "joao@cliente.com"
}
```

### **GET** `/api/v1/clientes/{cliente_id}/sistemas`
**Descrição**: Sistemas do cliente

### **POST** `/api/v1/clientes/{cliente_id}/sistemas`
**Descrição**: Cadastrar sistema do cliente
```json
{
  "nome": "Sistema ERP",
  "descricao": "Sistema de gestão empresarial",
  "versao_atual": "2.1.0",
  "tecnologias": ["PHP", "MySQL", "Vue.js"],
  "status": "producao"
}
```

---

## 🎫 Gestão de Chamados

### **GET** `/api/v1/chamados`
**Descrição**: Listar chamados conforme permissão do usuário
**Filtros Automáticos por Tipo de Usuário**:
- **Director**: Todos os chamados
- **Support Coordinator**: Equipe + escalados
- **Support Analyst**: Apenas atribuídos
- **Senior Developer**: Atribuídos + equipe técnica

**Query Parameters**:
```
?page=1&per_page=20
&status=aberto,atribuido
&prioridade=alta,critica
&cliente_id=uuid
&sistema_id=uuid
&atribuido_para=uuid
&equipe_id=uuid
&date_from=2024-01-01
&date_to=2024-12-31
&search=bug sistema
```

### **POST** `/api/v1/chamados`
**Descrição**: Criar novo chamado
**Permissões**: `chamados.create` (Suporte+)
```json
{
  "titulo": "Bug no sistema de vendas",
  "descricao": "O sistema não está calculando desconto corretamente...",
  "cliente_id": "uuid",
  "filial_id": "uuid",
  "sistema_id": "uuid",
  "tipo": "bug",
  "prioridade": "alta"
}
```

### **GET** `/api/v1/chamados/{chamado_id}`
**Descrição**: Detalhes completos do chamado
**Inclui**: comentários, anexos, histórico, tempo trabalhado

### **PUT** `/api/v1/chamados/{chamado_id}`
**Descrição**: Atualizar chamado
**Permissões**: Baseada no nível do usuário e atribuição

### **POST** `/api/v1/chamados/{chamado_id}/atribuir`
**Descrição**: Atribuir chamado para usuário/equipe
**Permissões**: `chamados.assign` (Coordenação+)
```json
{
  "atribuido_para": "uuid_usuario",
  "equipe_responsavel_id": "uuid_equipe",
  "observacoes": "Urgente - cliente VIP"
}
```

### **POST** `/api/v1/chamados/{chamado_id}/escalar`
**Descrição**: Escalar chamado para nível superior
**Permissões**: `chamados.escalate`
```json
{
  "escalonado_para": "uuid_coordenador",
  "motivo_escalonamento": "Complexidade técnica alta",
  "nivel_escalonamento": 2
}
```

### **POST** `/api/v1/chamados/{chamado_id}/status`
**Descrição**: Alterar status do chamado
```json
{
  "status": "em_andamento",
  "comentario": "Iniciando análise do problema"
}
```

---

## 💬 Comentários e Anexos

### **GET** `/api/v1/chamados/{chamado_id}/comentarios`
**Descrição**: Comentários do chamado
**Filtro**: `visivel_cliente` baseado no tipo de usuário

### **POST** `/api/v1/chamados/{chamado_id}/comentarios`
**Descrição**: Adicionar comentário
```json
{
  "comentario": "Identifiquei a causa do problema...",
  "visivel_cliente": true,
  "tipo_comentario": "comentario"
}
```

### **GET** `/api/v1/chamados/{chamado_id}/anexos`
**Descrição**: Anexos do chamado

### **POST** `/api/v1/chamados/{chamado_id}/anexos`
**Descrição**: Upload de anexo
**Content-Type**: `multipart/form-data`
**Campos**: `file`, `descricao`

### **GET** `/api/v1/anexos/{anexo_id}/download`
**Descrição**: Download de anexo
**Permissões**: Acesso ao chamado relacionado

---

## ⏱️ Controle de Tempo

### **GET** `/api/v1/chamados/{chamado_id}/tempo`
**Descrição**: Registro de horas do chamado

### **POST** `/api/v1/chamados/{chamado_id}/tempo`
**Descrição**: Lançar horas trabalhadas
**Permissões**: Usuário atribuído ao chamado
```json
{
  "inicio": "2024-01-15T09:00:00Z",
  "fim": "2024-01-15T12:00:00Z",
  "descricao_atividade": "Análise e correção do bug",
  "tipo_atividade": "desenvolvimento"
}
```

### **GET** `/api/v1/tempo/meu-timesheet`
**Descrição**: Timesheet do usuário logado
**Query**: `?date_from=2024-01-01&date_to=2024-01-31`

---

## 📊 Dashboards e Relatórios

### **GET** `/api/v1/dashboard/executive`
**Descrição**: Dados para dashboard executivo
**Permissões**: `dashboard.executive` (Diretoria)
```json
{
  "total_chamados": 150,
  "sla_compliance": 95.2,
  "receita_mensal": 85000,
  "satisfaction_score": 4.8,
  "chamados_por_status": {...},
  "produtividade_equipe": {...}
}
```

### **GET** `/api/v1/dashboard/coordination`
**Descrição**: Dashboard de coordenação
**Permissões**: `dashboard.coordination` (Coordenação+)

### **GET** `/api/v1/dashboard/support`
**Descrição**: Dashboard de suporte
**Permissões**: `dashboard.support` (Suporte)

### **GET** `/api/v1/dashboard/technical`
**Descrição**: Dashboard técnico
**Permissões**: `dashboard.technical` (Desenvolvedores)

---

## 📈 Relatórios Específicos

### **GET** `/api/v1/relatorios/sla-compliance`
**Descrição**: Relatório de cumprimento de SLA
**Query Parameters**:
- `cliente_id` - Por cliente
- `equipe_id` - Por equipe
- `period=monthly` - Período
- `format=json|csv|pdf` - Formato de saída

### **GET** `/api/v1/relatorios/produtividade`
**Descrição**: Relatório de produtividade
**Permissões**: `relatorios.produtividade` (Coordenação+)

### **GET** `/api/v1/relatorios/chamados-detalhado`
**Descrição**: Relatório detalhado de chamados
**Query**: Múltiplos filtros de período, cliente, status

### **POST** `/api/v1/relatorios/customizado`
**Descrição**: Gerar relatório customizado
**Body**: Definição dos campos, filtros e agrupamentos

---

## ⚙️ Configurações do Sistema

### **GET** `/api/v1/configuracoes/sla`
**Descrição**: Configurações de SLA
**Permissões**: `configuracoes.view` (Coordenação+)

### **POST** `/api/v1/configuracoes/sla`
**Descrição**: Criar configuração de SLA
```json
{
  "cliente_id": "uuid",
  "tipo_chamado": "bug",
  "prioridade": "alta",
  "sla_horas": 4,
  "aplicar_escalonamento": true,
  "tempo_escalonamento_horas": 2
}
```

### **GET** `/api/v1/configuracoes/permissoes`
**Descrição**: Listar permissões do sistema
**Permissões**: `configuracoes.permissoes` (Diretoria)

### **PUT** `/api/v1/configuracoes/permissoes/{tipo_usuario}`
**Descrição**: Atualizar permissões de um tipo de usuário

---

## 🔔 Notificações

### **GET** `/api/v1/notificacoes`
**Descrição**: Notificações do usuário logado
**Query**: `?lida=false&page=1&per_page=20`

### **PUT** `/api/v1/notificacoes/{notificacao_id}/marcar-lida`
**Descrição**: Marcar notificação como lida

### **POST** `/api/v1/notificacoes/marcar-todas-lidas`
**Descrição**: Marcar todas como lidas

---

## 🔍 Busca e Filtros

### **GET** `/api/v1/search`
**Descrição**: Busca global no sistema
**Query**: `?q=termo&entity=chamados,clientes,usuarios`
**Permissões**: Baseada no acesso do usuário

### **GET** `/api/v1/options/clientes`
**Descrição**: Opções de clientes para selects
**Resposta**: `[{"id": "uuid", "nome": "Cliente A"}]`

### **GET** `/api/v1/options/usuarios`
**Descrição**: Opções de usuários para atribuição
**Query**: `?tipo=developer&equipe_id=uuid`

### **GET** `/api/v1/options/sistemas`
**Descrição**: Sistemas disponíveis
**Query**: `?cliente_id=uuid`

---

## 📊 Métricas e Analytics

### **GET** `/api/v1/metricas/tempo-resposta`
**Descrição**: Métricas de tempo de resposta
**Query**: `?period=30d&group_by=equipe,cliente`

### **GET** `/api/v1/metricas/satisfacao-cliente`
**Descrição**: Índices de satisfação

### **GET** `/api/v1/metricas/carga-trabalho`
**Descrição**: Carga de trabalho por usuário/equipe

---

## 🔐 Estrutura de Permissões por Endpoint

### **Diretoria** (`director`)
- ✅ Acesso total a todos os endpoints
- ✅ Relatórios executivos
- ✅ Configurações do sistema
- ✅ Gestão de usuários e equipes

### **Coordenador Suporte** (`support_coordinator`)
- ✅ Gestão de chamados da equipe
- ✅ Atribuição e escalação
- ✅ Relatórios de equipe
- ✅ Configurações de SLA
- ❌ Relatórios executivos/financeiros

### **Desenvolvedor Senior** (`senior_developer`)
- ✅ Chamados atribuídos + equipe técnica
- ✅ Dashboard técnico
- ✅ Controle de tempo
- ❌ Gestão de usuários
- ❌ Configurações de SLA

### **Analista Suporte** (`support_analyst`)
- ✅ Chamados atribuídos
- ✅ Dashboard de suporte pessoal
- ✅ Comentários e anexos
- ❌ Atribuição de chamados
- ❌ Relatórios gerenciais

### **Administrativo** (`administrative`)
- ✅ Relatórios administrativos
- ✅ Gestão básica de usuários
- ✅ Export de dados
- ❌ Chamados técnicos
- ❌ Configurações críticas

### **Comercial** (`commercial`)
- ✅ Gestão de clientes
- ✅ Dashboard comercial
- ✅ Relatórios de vendas
- ❌ Operações técnicas
- ❌ Gestão interna

---

## 🚀 Considerações Técnicas

### **Paginação Padrão**
```json
{
  "items": [...],
  "total": 150,
  "page": 1,
  "per_page": 20,
  "pages": 8,
  "has_next": true,
  "has_prev": false
}
```

### **Tratamento de Erros**
```json
{
  "error": "PERMISSION_DENIED",
  "message": "Usuário não tem permissão para esta ação",
  "code": 403,
  "details": {
    "required_permission": "chamados.assign",
    "user_level": 1,
    "required_level": 2
  }
}
```

### **Rate Limiting**
- **Autenticação**: 5 tentativas/minuto
- **APIs normais**: 100 requests/minuto
- **Relatórios**: 10 requests/minuto
- **Upload**: 5 arquivos/minuto

### **WebSocket (Futuro)**
- `/ws/notifications` - Notificações em tempo real
- `/ws/chamados/{id}` - Updates de chamado específico
- `/ws/dashboard` - Updates de dashboard

---

Esta estrutura de endpoints atende completamente a hierarquia organizacional definida, com controle granular de permissões e funcionalidades específicas para cada tipo de usuário.

**Última atualização**: 01/10/2025