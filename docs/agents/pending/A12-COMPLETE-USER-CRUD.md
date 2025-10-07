# A12 - Completar CRUD de Usuários

## 📋 Objetivo
Implementar todas as operações CRUD faltantes para o gerenciamento completo de usuários.

## 🎯 Tarefas
1. Implementar POST `/api/v1/usuarios` - Criar usuário
2. Implementar GET `/api/v1/usuarios/{user_id}` - Obter usuário específico
3. Implementar PUT `/api/v1/usuarios/{user_id}` - Atualizar usuário
4. Implementar DELETE `/api/v1/usuarios/{user_id}` - Desativar usuário
5. Implementar POST `/api/v1/usuarios/{user_id}/reset-password` - Reset de senha
6. Adicionar validações e permissões adequadas

## 📚 Referências
- docs/agents/shared/CODE-STANDARDS.md
- docs/agents/shared/API-REFERENCE.md (seção "Gestão de Usuários")
- app/services/usuario_service.py
- app/schemas/usuario.py

## 🔧 Implementação

### Endpoints a criar em usuarios.py
```python
@router.post("/", response_model=UsuarioResponse)
async def criar_usuario(
    dados: UsuarioCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Criar novo usuário - Permissão: Diretoria"""
    if current_user.tipo_usuario != TipoUsuario.DIRECTOR:
        raise HTTPException(403, "Sem permissão")
    
    service = UsuarioService(db)
    return await service.criar_usuario(dados)

@router.get("/{user_id}", response_model=UsuarioResponse)
async def obter_usuario(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Obter detalhes do usuário"""
    service = UsuarioService(db)
    return await service.obter_usuario(user_id, current_user)

@router.put("/{user_id}", response_model=UsuarioResponse)
async def atualizar_usuario(
    user_id: UUID,
    dados: UsuarioUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Atualizar dados do usuário"""
    service = UsuarioService(db)
    return await service.atualizar_usuario(user_id, dados, current_user)

@router.delete("/{user_id}")
async def desativar_usuario(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Desativar usuário - Soft delete"""
    if current_user.tipo_usuario != TipoUsuario.DIRECTOR:
        raise HTTPException(403, "Sem permissão")
    
    service = UsuarioService(db)
    await service.desativar_usuario(user_id)
    return {"message": "Usuário desativado com sucesso"}

@router.post("/{user_id}/reset-password")
async def reset_senha(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Reset senha do usuário"""
    if current_user.tipo_usuario not in [TipoUsuario.DIRECTOR, TipoUsuario.SUPPORT_COORDINATOR]:
        raise HTTPException(403, "Sem permissão")
    
    service = UsuarioService(db)
    temp_password = await service.reset_senha(user_id)
    return {"message": "Senha resetada", "temporary_password": temp_password}
```

### Métodos no UsuarioService
```python
async def criar_usuario(self, dados: UsuarioCreate) -> Usuario:
    # Verificar email duplicado
    # Hash da senha
    # Criar usuário
    # Enviar email de boas-vindas
    pass

async def obter_usuario(self, user_id: UUID, current_user: Usuario) -> Usuario:
    # Verificar permissão de acesso
    # Retornar dados do usuário
    pass

async def atualizar_usuario(self, user_id: UUID, dados: UsuarioUpdate, current_user: Usuario) -> Usuario:
    # Verificar permissão
    # Validar dados
    # Atualizar usuário
    pass

async def desativar_usuario(self, user_id: UUID) -> None:
    # Soft delete (ativo = False)
    # Deslogar sessões ativas
    pass

async def reset_senha(self, user_id: UUID) -> str:
    # Gerar senha temporária
    # Atualizar hash
    # Enviar email
    # Retornar senha temporária
    pass
```

## 🧪 Teste Após Cada Implementação

### IMPORTANTE: Testar cada endpoint imediatamente após implementar
```bash
# 1. Após implementar POST /usuarios - Criar usuário
curl -X POST "http://localhost:8001/api/v1/usuarios" \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "email": "teste@empresa.com",
       "nome_completo": "Usuário Teste",
       "tipo_usuario": "support_analyst",
       "senha": "senha123"
     }'

# Esperar: 201 Created
# Se erro: Corrigir imediatamente

# 2. Após implementar GET /usuarios/{id}
USER_ID="uuid-do-usuario"
curl -X GET "http://localhost:8001/api/v1/usuarios/$USER_ID" \
     -H "Authorization: Bearer $TOKEN"

# Esperar: 200 OK
# Se erro: Verificar permissões e service

# 3. Após implementar PUT /usuarios/{id}
curl -X PUT "http://localhost:8001/api/v1/usuarios/$USER_ID" \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"nome_completo": "Nome Atualizado"}'

# Esperar: 200 OK
# Se erro: Verificar schema e validações

# 4. Após implementar DELETE /usuarios/{id}
curl -X DELETE "http://localhost:8001/api/v1/usuarios/$USER_ID" \
     -H "Authorization: Bearer $TOKEN"

# Esperar: 204 No Content
# Se erro: Verificar soft delete

# 5. Após implementar POST /usuarios/{id}/reset-password
curl -X POST "http://localhost:8001/api/v1/usuarios/$USER_ID/reset-password" \
     -H "Authorization: Bearer $TOKEN"

# Esperar: 200 OK com senha temporária
# Se erro: Verificar geração de senha
```

### Script de teste completo
```python
# test_user_crud.py
import requests
import json

BASE_URL = "http://localhost:8001/api/v1"
token = "seu_token_aqui"
headers = {"Authorization": f"Bearer {token}"}

# 1. Criar usuário
print("1. Testando criação de usuário...")
user_data = {
    "email": f"test_{int(time.time())}@empresa.com",
    "nome_completo": "Teste CRUD",
    "tipo_usuario": "support_analyst",
    "senha": "senha123"
}
resp = requests.post(f"{BASE_URL}/usuarios", json=user_data, headers=headers)
if resp.status_code != 201:
    print(f"❌ ERRO ao criar: {resp.status_code} - {resp.text}")
    # PARAR E CORRIGIR
else:
    print("✅ Usuário criado")
    user = resp.json()
    user_id = user["id"]
    
    # 2. Buscar usuário
    print("2. Testando busca...")
    resp = requests.get(f"{BASE_URL}/usuarios/{user_id}", headers=headers)
    if resp.status_code != 200:
        print(f"❌ ERRO ao buscar: {resp.status_code}")
        # CORRIGIR
    else:
        print("✅ Busca OK")
    
    # 3. Atualizar
    print("3. Testando atualização...")
    update_data = {"nome_completo": "Nome Atualizado"}
    resp = requests.put(f"{BASE_URL}/usuarios/{user_id}", json=update_data, headers=headers)
    if resp.status_code != 200:
        print(f"❌ ERRO ao atualizar: {resp.status_code}")
        # CORRIGIR
    else:
        print("✅ Atualização OK")
    
    # 4. Reset senha
    print("4. Testando reset senha...")
    resp = requests.post(f"{BASE_URL}/usuarios/{user_id}/reset-password", headers=headers)
    if resp.status_code != 200:
        print(f"❌ ERRO no reset: {resp.status_code}")
        # CORRIGIR
    else:
        print("✅ Reset OK")
    
    # 5. Deletar
    print("5. Testando delete...")
    resp = requests.delete(f"{BASE_URL}/usuarios/{user_id}", headers=headers)
    if resp.status_code not in [200, 204]:
        print(f"❌ ERRO ao deletar: {resp.status_code}")
        # CORRIGIR
    else:
        print("✅ Delete OK")

print("\n✅ CRUD de usuários completo!")
```

### Se algum teste falhar:
1. Verificar o erro específico no log
2. Corrigir o código imediatamente
3. Testar novamente até funcionar
4. Só prosseguir quando TODOS os endpoints estiverem OK

## ✅ Checklist de Validação
- [ ] Todos os endpoints CRUD implementados
- [ ] Schemas UsuarioCreate e UsuarioUpdate completos
- [ ] Validações de email único
- [ ] Hash de senha implementado
- [ ] Soft delete funcionando
- [ ] Permissões por tipo de usuário
- [ ] Testes para cada endpoint
- [ ] Documentação OpenAPI atualizada

## 📊 Resultado Esperado
- CRUD completo de usuários funcionando
- Sistema de permissões aplicado
- Gestão segura de senhas
- Soft delete preservando histórico

## 📝 Log de Execução
[A ser preenchido após execução]

---
**Status**: PENDENTE
**Prioridade**: ALTA
**Estimativa**: 1 hora