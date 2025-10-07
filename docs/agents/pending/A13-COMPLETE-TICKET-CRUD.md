# A13 - Completar CRUD de Chamados

## 📋 Objetivo
Implementar todas as operações CRUD e funcionalidades relacionadas aos chamados.

## 🎯 Tarefas
1. Implementar POST `/api/v1/chamados` - Criar chamado
2. Implementar GET `/api/v1/chamados/{chamado_id}` - Detalhes do chamado
3. Implementar PUT `/api/v1/chamados/{chamado_id}` - Atualizar chamado
4. Implementar POST `/api/v1/chamados/{chamado_id}/atribuir` - Atribuir chamado
5. Implementar POST `/api/v1/chamados/{chamado_id}/escalar` - Escalar chamado
6. Implementar POST `/api/v1/chamados/{chamado_id}/status` - Alterar status
7. Implementar DELETE `/api/v1/chamados/{chamado_id}` - Cancelar chamado

## 📚 Referências
- docs/agents/shared/CODE-STANDARDS.md
- docs/agents/shared/API-REFERENCE.md (seção "Gestão de Chamados")
- app/services/chamado_service.py
- app/models/chamado.py

## 🔧 Implementação

### Endpoints em chamados.py
```python
@router.post("/", response_model=ChamadoResponse, status_code=201)
async def criar_chamado(
    dados: ChamadoCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Criar novo chamado"""
    service = ChamadoService(db)
    chamado = await service.criar_chamado(dados, current_user)
    
    # Notificar equipe de suporte
    await NotificationService(db).notificar_novo_chamado(chamado.id)
    
    return chamado

@router.get("/{chamado_id}", response_model=ChamadoDetailResponse)
async def obter_chamado(
    chamado_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Obter detalhes completos do chamado"""
    service = ChamadoService(db)
    chamado = await service.obter_chamado_completo(chamado_id, current_user)
    
    if not chamado:
        raise HTTPException(404, "Chamado não encontrado")
    
    return chamado

@router.put("/{chamado_id}", response_model=ChamadoResponse)
async def atualizar_chamado(
    chamado_id: UUID,
    dados: ChamadoUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Atualizar dados do chamado"""
    service = ChamadoService(db)
    return await service.atualizar_chamado(chamado_id, dados, current_user)

@router.post("/{chamado_id}/atribuir")
async def atribuir_chamado(
    chamado_id: UUID,
    dados: AtribuirChamado,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Atribuir chamado para usuário/equipe"""
    # Verificar permissão de coordenação
    if current_user.tipo_usuario not in [
        TipoUsuario.DIRECTOR,
        TipoUsuario.SUPPORT_COORDINATOR
    ]:
        raise HTTPException(403, "Sem permissão para atribuir chamados")
    
    service = ChamadoService(db)
    await service.atribuir_chamado(
        chamado_id,
        dados.atribuido_para,
        dados.equipe_responsavel_id,
        dados.observacoes
    )
    
    # Notificar usuário atribuído
    await NotificationService(db).notificar_chamado_atribuido(
        chamado_id,
        dados.atribuido_para
    )
    
    return {"message": "Chamado atribuído com sucesso"}

@router.post("/{chamado_id}/escalar")
async def escalar_chamado(
    chamado_id: UUID,
    dados: EscalarChamado,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Escalar chamado para nível superior"""
    service = ChamadoService(db)
    await service.escalar_chamado(
        chamado_id,
        dados.escalonado_para,
        dados.motivo_escalonamento,
        dados.nivel_escalonamento,
        current_user
    )
    
    return {"message": "Chamado escalonado com sucesso"}

@router.post("/{chamado_id}/status")
async def alterar_status(
    chamado_id: UUID,
    dados: AlterarStatus,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Alterar status do chamado"""
    service = ChamadoService(db)
    await service.alterar_status(
        chamado_id,
        dados.status,
        dados.comentario,
        current_user
    )
    
    # Notificar mudança de status
    await NotificationService(db).notificar_status_alterado(
        chamado_id,
        dados.status
    )
    
    return {"message": f"Status alterado para {dados.status}"}

@router.delete("/{chamado_id}")
async def cancelar_chamado(
    chamado_id: UUID,
    motivo: str = Query(..., description="Motivo do cancelamento"),
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Cancelar chamado"""
    service = ChamadoService(db)
    await service.cancelar_chamado(chamado_id, motivo, current_user)
    
    return {"message": "Chamado cancelado"}
```

### Schemas necessários
```python
class ChamadoCreate(BaseModel):
    titulo: str = Field(..., min_length=5, max_length=200)
    descricao: str = Field(..., min_length=10)
    cliente_id: UUID
    filial_id: Optional[UUID] = None
    sistema_id: Optional[UUID] = None
    tipo: TipoChamado
    prioridade: PrioridadeChamado
    categoria: CategoriaChamado

class ChamadoUpdate(BaseModel):
    titulo: Optional[str] = None
    descricao: Optional[str] = None
    prioridade: Optional[PrioridadeChamado] = None
    categoria: Optional[CategoriaChamado] = None

class AtribuirChamado(BaseModel):
    atribuido_para: UUID
    equipe_responsavel_id: Optional[UUID] = None
    observacoes: Optional[str] = None

class EscalarChamado(BaseModel):
    escalonado_para: UUID
    motivo_escalonamento: str
    nivel_escalonamento: int = Field(ge=1, le=3)

class AlterarStatus(BaseModel):
    status: StatusChamado
    comentario: Optional[str] = None

class ChamadoDetailResponse(ChamadoResponse):
    comentarios: List[ComentarioResponse] = []
    anexos: List[AnexoResponse] = []
    tempo_trabalhado: List[TempoResponse] = []
    historico_status: List[HistoricoResponse] = []
```

## 🧪 Teste Após Cada Implementação

### IMPORTANTE: Testar IMEDIATAMENTE cada endpoint após implementar
```bash
# 1. Após implementar POST /chamados - Criar chamado
curl -X POST "http://localhost:8001/api/v1/chamados" \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "titulo": "Bug no sistema de vendas",
       "descricao": "Sistema não calcula desconto corretamente",
       "cliente_id": "uuid-cliente",
       "tipo": "bug",
       "prioridade": "alta",
       "categoria": "backend"
     }'

# Esperar: 201 Created
# Se erro: PARAR e corrigir imediatamente

# 2. Após implementar GET /chamados/{id}
CHAMADO_ID="uuid-do-chamado"
curl -X GET "http://localhost:8001/api/v1/chamados/$CHAMADO_ID" \
     -H "Authorization: Bearer $TOKEN"

# Esperar: 200 OK com detalhes completos
# Se erro: Verificar permissões e joins

# 3. Após implementar PUT /chamados/{id}
curl -X PUT "http://localhost:8001/api/v1/chamados/$CHAMADO_ID" \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"titulo": "Título Atualizado", "prioridade": "critica"}'

# Esperar: 200 OK
# Se erro: Verificar schema e validações

# 4. Após implementar POST /chamados/{id}/atribuir
curl -X POST "http://localhost:8001/api/v1/chamados/$CHAMADO_ID/atribuir" \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "atribuido_para": "uuid-usuario",
       "observacoes": "Urgente"
     }'

# Esperar: 200 OK
# Se erro: Verificar permissões de coordenação

# 5. Após implementar POST /chamados/{id}/status
curl -X POST "http://localhost:8001/api/v1/chamados/$CHAMADO_ID/status" \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "status": "em_andamento",
       "comentario": "Iniciando análise"
     }'

# Esperar: 200 OK
# Se erro: Verificar enum de status
```

### Script de teste completo do CRUD
```python
# test_chamado_crud.py
import requests
import json
import time

BASE_URL = "http://localhost:8001/api/v1"

# Login primeiro
login_resp = requests.post(f"{BASE_URL}/auth/login", json={
    "email": "lee@empresa.com",
    "password": "admin123"
})
token = login_resp.json()["access_token"]
headers = {"Authorization": f"Bearer {token}"}

def teste_crud_chamados():
    print("🧪 TESTANDO CRUD DE CHAMADOS")
    print("="*50)
    
    # 1. Criar chamado
    print("\n1. Criando chamado...")
    chamado_data = {
        "titulo": f"Teste CRUD {int(time.time())}",
        "descricao": "Teste de criação de chamado via script",
        "cliente_id": "uuid-cliente-existente",  # Usar ID real
        "tipo": "bug",
        "prioridade": "alta",
        "categoria": "backend"
    }
    
    resp = requests.post(f"{BASE_URL}/chamados", json=chamado_data, headers=headers)
    if resp.status_code != 201:
        print(f"❌ ERRO ao criar: {resp.status_code}")
        print(f"   Resposta: {resp.text}")
        print("   CORRIGIR ANTES DE PROSSEGUIR!")
        return False
    
    chamado = resp.json()
    chamado_id = chamado["id"]
    print(f"✅ Chamado criado: {chamado_id}")
    
    # 2. Buscar chamado
    print("\n2. Buscando chamado...")
    resp = requests.get(f"{BASE_URL}/chamados/{chamado_id}", headers=headers)
    if resp.status_code != 200:
        print(f"❌ ERRO ao buscar: {resp.status_code}")
        print(f"   Resposta: {resp.text}")
        print("   CORRIGIR!")
        return False
    print("✅ Busca OK")
    
    # 3. Atualizar chamado
    print("\n3. Atualizando chamado...")
    update_data = {
        "titulo": "Título Atualizado",
        "prioridade": "critica"
    }
    resp = requests.put(f"{BASE_URL}/chamados/{chamado_id}", json=update_data, headers=headers)
    if resp.status_code != 200:
        print(f"❌ ERRO ao atualizar: {resp.status_code}")
        print(f"   Resposta: {resp.text}")
        print("   CORRIGIR!")
        return False
    print("✅ Atualização OK")
    
    # 4. Atribuir chamado
    print("\n4. Atribuindo chamado...")
    atribuir_data = {
        "atribuido_para": "uuid-usuario",  # Usar ID real
        "observacoes": "Teste de atribuição"
    }
    resp = requests.post(f"{BASE_URL}/chamados/{chamado_id}/atribuir", json=atribuir_data, headers=headers)
    if resp.status_code != 200:
        print(f"❌ ERRO ao atribuir: {resp.status_code}")
        print(f"   Resposta: {resp.text}")
        print("   CORRIGIR!")
        return False
    print("✅ Atribuição OK")
    
    # 5. Alterar status
    print("\n5. Alterando status...")
    status_data = {
        "status": "em_andamento",
        "comentario": "Iniciando trabalho"
    }
    resp = requests.post(f"{BASE_URL}/chamados/{chamado_id}/status", json=status_data, headers=headers)
    if resp.status_code != 200:
        print(f"❌ ERRO ao alterar status: {resp.status_code}")
        print(f"   Resposta: {resp.text}")
        print("   CORRIGIR!")
        return False
    print("✅ Status alterado")
    
    # 6. Escalar chamado
    print("\n6. Escalando chamado...")
    escalar_data = {
        "escalonado_para": "uuid-coordenador",  # Usar ID real
        "motivo_escalonamento": "Complexidade alta",
        "nivel_escalonamento": 2
    }
    resp = requests.post(f"{BASE_URL}/chamados/{chamado_id}/escalar", json=escalar_data, headers=headers)
    if resp.status_code != 200:
        print(f"❌ ERRO ao escalar: {resp.status_code}")
        print(f"   Resposta: {resp.text}")
        print("   CORRIGIR!")
        return False
    print("✅ Escalação OK")
    
    # 7. Cancelar chamado
    print("\n7. Cancelando chamado...")
    resp = requests.delete(f"{BASE_URL}/chamados/{chamado_id}?motivo=Teste%20concluido", headers=headers)
    if resp.status_code not in [200, 204]:
        print(f"❌ ERRO ao cancelar: {resp.status_code}")
        print(f"   Resposta: {resp.text}")
        print("   CORRIGIR!")
        return False
    print("✅ Chamado cancelado")
    
    print("\n" + "="*50)
    print("✅ TODOS OS TESTES PASSARAM!")
    return True

# Executar teste
if not teste_crud_chamados():
    print("\n⚠️  CORRIGIR OS ERROS ANTES DE PROSSEGUIR!")
    exit(1)
```

### Se algum teste falhar:
1. **NÃO PROSSEGUIR** para o próximo endpoint
2. Verificar log de erro detalhado
3. Corrigir o problema no código
4. Testar novamente até passar
5. Só então implementar o próximo endpoint

## ✅ Checklist de Validação
- [ ] Todos os endpoints CRUD implementados
- [ ] Sistema de atribuição funcionando
- [ ] Sistema de escalação funcionando
- [ ] Alteração de status com histórico
- [ ] Notificações disparadas corretamente
- [ ] Validações de negócio aplicadas
- [ ] Permissões verificadas
- [ ] Testes completos

## 📊 Resultado Esperado
- CRUD completo de chamados
- Sistema de workflow (atribuição, escalação, status)
- Integração com notificações
- Histórico de alterações preservado

## 📝 Log de Execução
[A ser preenchido após execução]

---
**Status**: PENDENTE
**Prioridade**: ALTA
**Estimativa**: 1.5 horas