# A11 - Corrigir Conflitos de Rotas

## 📋 Objetivo
Resolver conflitos de rotas que causam erros 422, garantindo que rotas específicas sejam registradas antes das parametrizadas.

## 🎯 Tarefas
1. Identificar todas as rotas com conflito
2. Reordenar rotas nos routers (específicas primeiro)
3. Ajustar `/api/v1/usuarios/me` 
4. Ajustar `/api/v1/chamados/stats`
5. Verificar outros possíveis conflitos
6. Testar todas as rotas corrigidas

## 📚 Referências
- docs/agents/shared/CODE-STANDARDS.md (seção "Ordem de Rotas")
- docs/agents/shared/API-REFERENCE.md
- docs/agents/continuous/QA-REVIEW.md

## 🔧 Implementação

### Correção em usuarios.py
```python
# Rotas específicas PRIMEIRO
@router.get("/me", response_model=UsuarioResponse)
async def obter_usuario_logado(...):
    pass

# Depois as parametrizadas
@router.get("/{user_id}", response_model=UsuarioResponse)
async def obter_usuario(...):
    pass
```

### Correção em chamados.py
```python
# Específicas primeiro
@router.get("/stats", response_model=ChamadoStats)
async def obter_estatisticas(...):
    pass

@router.get("/{chamado_id}", response_model=ChamadoResponse)
async def obter_chamado(...):
    pass
```

## 🧪 Teste Após Implementação

### IMPORTANTE: Testar cada correção imediatamente
```python
# Após corrigir usuarios.py, testar:
curl -X GET "http://localhost:8001/api/v1/usuarios/me" \
     -H "Authorization: Bearer $TOKEN"

# Esperar: 200 OK
# Se erro: Corrigir imediatamente antes de prosseguir

# Após corrigir chamados.py, testar:
curl -X GET "http://localhost:8001/api/v1/chamados/stats" \
     -H "Authorization: Bearer $TOKEN"

# Esperar: 200 OK
# Se erro: Corrigir imediatamente antes de prosseguir

# Teste completo de conflitos:
python -c "
import requests
token = 'seu_token_aqui'
headers = {'Authorization': f'Bearer {token}'}

endpoints = [
    ('/api/v1/usuarios/me', 200),
    ('/api/v1/chamados/stats', 200),
]

for endpoint, expected in endpoints:
    resp = requests.get(f'http://localhost:8001{endpoint}', headers=headers)
    if resp.status_code != expected:
        print(f'❌ ERRO em {endpoint}: {resp.status_code}')
        print(f'   Resposta: {resp.text}')
        # CORRIGIR IMEDIATAMENTE
    else:
        print(f'✅ OK: {endpoint}')
"
```

### Se houver erro, verificar:
1. Ordem das rotas no arquivo
2. Imports corretos
3. Schemas definidos
4. Service methods implementados

## ✅ Checklist de Validação
- [ ] Erro 422 em `/usuarios/me` resolvido
- [ ] Erro 422 em `/chamados/stats` resolvido
- [ ] Todos os routers verificados
- [ ] Testes passando sem erros 422
- [ ] Documentação de rotas atualizada

## 📊 Resultado Esperado
- Zero erros 422 em todos os endpoints
- Todas as rotas específicas acessíveis
- Rotas parametrizadas funcionando corretamente

## 📝 Log de Execução
[A ser preenchido após execução]

---
**Status**: PENDENTE
**Prioridade**: ALTA (Correção crítica)
**Estimativa**: 30 minutos