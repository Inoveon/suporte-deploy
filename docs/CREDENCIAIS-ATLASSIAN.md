# 🔐 Credenciais de Acesso - Atlassian (Jira/Confluence)

Este documento contém as informações de acesso aos serviços Atlassian da i9on para integração e desenvolvimento.

## 🏢 Informações da Instância

### **Confluence**
- **URL**: https://i9on.atlassian.net/wiki/home
- **Site ID**: 2912d6fc-ff66-4a5f-a898-35a93d136ee6

### **Jira**
- **URL**: https://i9on.atlassian.net
- **Instância**: i9on.atlassian.net

## 👤 Credenciais de Acesso

### **Usuário**
- **Email**: [SERÁ PREENCHIDO QUANDO FORNECIDO]
- **Tipo**: Conta Atlassian

### **API Token**
- **Token**: [SERÁ PREENCHIDO QUANDO FORNECIDO]
- **Gerado em**: [DATA]
- **Escopo**: Jira + Confluence
- **Permissões**: [A DEFINIR]

## 🔧 Configuração de API

### **Autenticação**
```bash
# Método: Basic Auth
# Username: {email}
# Password: {api_token}
```

### **Headers Necessários**
```
Authorization: Basic {base64(email:token)}
Content-Type: application/json
Accept: application/json
```

## 🌐 Endpoints Principais

### **Confluence API**
```
Base URL: https://i9on.atlassian.net/wiki/rest/api/
Versão: latest

Principais:
- GET /space - Listar espaços
- GET /content - Listar páginas
- GET /content/{id} - Detalhes da página
- POST /content - Criar página
```

### **Jira API**
```
Base URL: https://i9on.atlassian.net/rest/api/3/
Versão: 3

Principais:
- GET /project - Listar projetos
- GET /issue - Listar issues
- POST /issue - Criar issue
- GET /field - Campos customizados
```

## 🎯 Propósito de Uso

### **Confluence**
- Verificação da documentação existente
- Análise da estrutura de conhecimento
- Identificação de gaps de documentação
- Planejamento de integração com sistema de suporte

### **Jira**
- Análise de projetos existentes
- Verificação de workflows
- Integração com sistema de chamados
- Sincronização de dados

## 🔒 Segurança

### **Importante**
- ⚠️ Token de API é sensível - manter privado
- ⚠️ Não versionar este arquivo com credenciais preenchidas
- ⚠️ Usar variáveis de ambiente em produção
- ⚠️ Renovar token periodicamente

### **Permissões Esperadas**
- **Confluence**: Read/Write em espaços específicos
- **Jira**: Read em projetos, Write em issues específicas
- **Admin**: Configuração de campos e workflows (se necessário)

## 📝 Notas de Desenvolvimento

### **Testes de Conexão**
```python
import requests
import base64

def test_confluence_connection(email, token):
    auth = base64.b64encode(f"{email}:{token}".encode()).decode()
    headers = {
        'Authorization': f'Basic {auth}',
        'Accept': 'application/json'
    }
    
    response = requests.get(
        'https://i9on.atlassian.net/wiki/rest/api/space',
        headers=headers
    )
    
    return response.status_code == 200
```

### **Estrutura de Requisições**
```python
# Listar espaços do Confluence
GET /wiki/rest/api/space?limit=50

# Buscar páginas por título
GET /wiki/rest/api/content?title={title}&spaceKey={space}

# Obter conteúdo da página
GET /wiki/rest/api/content/{id}?expand=body.storage,space,version
```

## 📋 Checklist de Verificação

### **Confluence**
- [ ] Acesso aos espaços
- [ ] Listagem de páginas
- [ ] Leitura de conteúdo
- [ ] Identificação de templates
- [ ] Mapeamento da estrutura

### **Jira**
- [ ] Acesso aos projetos
- [ ] Listagem de issues
- [ ] Campos customizados
- [ ] Workflows configurados
- [ ] Tipos de issue

## 🎯 Objetivos da Análise

1. **Documentação Existente**
   - Catalogar conhecimento atual
   - Identificar padrões de organização
   - Mapear responsáveis por área

2. **Integração**
   - Avaliar possibilidade de sincronização
   - Definir estratégia de migração
   - Planejar complementação

3. **Melhorias**
   - Gaps de documentação
   - Oportunidades de automação
   - Padronização de processos

---

**⚠️ ATENÇÃO**: 
- Este arquivo deve ser atualizado com as credenciais reais quando fornecidas
- Manter backup seguro das credenciais
- Documentar qualquer alteração ou renovação de tokens

**Última atualização**: 01/10/2025