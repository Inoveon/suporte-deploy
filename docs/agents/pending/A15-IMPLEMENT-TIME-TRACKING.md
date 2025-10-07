# A15 - Implementar Controle de Tempo

## 📋 Objetivo
Implementar sistema completo de controle de tempo (timesheet) para tracking de horas trabalhadas nos chamados.

## 🎯 Tarefas
1. Criar model RegistroTempo
2. Implementar GET `/api/v1/chamados/{chamado_id}/tempo`
3. Implementar POST `/api/v1/chamados/{chamado_id}/tempo`
4. Implementar GET `/api/v1/tempo/meu-timesheet`
5. Implementar GET `/api/v1/tempo/registros`
6. Criar relatórios de tempo por usuário/equipe/projeto

## 📚 Referências
- docs/agents/shared/CODE-STANDARDS.md
- docs/agents/shared/API-REFERENCE.md (seção "Controle de Tempo")
- docs/agents/shared/TEST-TEMPLATE.md (IMPORTANTE: Testar cada endpoint)

## 🔧 Implementação

### Model
```python
# app/models/tempo.py
class RegistroTempo(Base):
    __tablename__ = "registros_tempo"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    chamado_id = Column(UUID(as_uuid=True), ForeignKey("chamados.id"))
    usuario_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id"))
    inicio = Column(DateTime, nullable=False)
    fim = Column(DateTime, nullable=False)
    duracao_minutos = Column(Integer, nullable=False)
    descricao_atividade = Column(Text, nullable=False)
    tipo_atividade = Column(String(50))  # desenvolvimento, teste, reuniao, documentacao
    faturavel = Column(Boolean, default=True)
    aprovado = Column(Boolean, default=False)
    aprovado_por = Column(UUID(as_uuid=True), ForeignKey("usuarios.id"))
    criado_em = Column(DateTime, default=datetime.utcnow)
    
    # Relacionamentos
    chamado = relationship("Chamado", back_populates="registros_tempo")
    usuario = relationship("Usuario", foreign_keys=[usuario_id])
    aprovador = relationship("Usuario", foreign_keys=[aprovado_por])
    
    @property
    def duracao_horas(self) -> float:
        return self.duracao_minutos / 60
```

### Router
```python
# app/api/v1/endpoints/tempo.py
router = APIRouter(prefix="/tempo", tags=["tempo"])

@router.get("/chamados/{chamado_id}/tempo", response_model=List[RegistroTempoResponse])
async def listar_tempo_chamado(
    chamado_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Listar registros de tempo do chamado"""
    service = TempoService(db)
    return await service.listar_por_chamado(chamado_id, current_user)

@router.post("/chamados/{chamado_id}/tempo", response_model=RegistroTempoResponse)
async def registrar_tempo(
    chamado_id: UUID,
    dados: RegistroTempoCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Registrar tempo trabalhado no chamado"""
    service = TempoService(db)
    
    # Verificar se usuário está atribuído ao chamado
    chamado = await ChamadoService(db).get_by_id(chamado_id)
    if not chamado:
        raise HTTPException(404, "Chamado não encontrado")
    
    if chamado.atribuido_para != current_user.id:
        if current_user.tipo_usuario not in [TipoUsuario.DIRECTOR, TipoUsuario.SUPPORT_COORDINATOR]:
            raise HTTPException(403, "Apenas o usuário atribuído pode registrar tempo")
    
    # Calcular duração
    duracao = (dados.fim - dados.inicio).total_seconds() / 60
    
    if duracao <= 0:
        raise HTTPException(400, "Tempo final deve ser maior que tempo inicial")
    
    if duracao > 480:  # 8 horas
        raise HTTPException(400, "Registro não pode exceder 8 horas")
    
    registro = await service.criar_registro(
        chamado_id=chamado_id,
        usuario_id=current_user.id,
        inicio=dados.inicio,
        fim=dados.fim,
        duracao_minutos=int(duracao),
        descricao_atividade=dados.descricao_atividade,
        tipo_atividade=dados.tipo_atividade,
        faturavel=dados.faturavel
    )
    
    # Atualizar tempo total do chamado
    await ChamadoService(db).atualizar_tempo_total(chamado_id)
    
    return registro

@router.get("/meu-timesheet", response_model=TimesheetResponse)
async def meu_timesheet(
    date_from: datetime = Query(..., description="Data inicial"),
    date_to: datetime = Query(..., description="Data final"),
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Obter timesheet do usuário logado"""
    service = TempoService(db)
    
    registros = await service.obter_timesheet(
        usuario_id=current_user.id,
        data_inicio=date_from,
        data_fim=date_to
    )
    
    # Agrupar por dia
    timesheet_por_dia = {}
    total_horas = 0
    total_faturavel = 0
    
    for registro in registros:
        dia = registro.inicio.date().isoformat()
        if dia not in timesheet_por_dia:
            timesheet_por_dia[dia] = {
                "data": dia,
                "registros": [],
                "total_horas": 0,
                "horas_faturaveis": 0
            }
        
        timesheet_por_dia[dia]["registros"].append(registro)
        timesheet_por_dia[dia]["total_horas"] += registro.duracao_horas
        
        if registro.faturavel:
            timesheet_por_dia[dia]["horas_faturaveis"] += registro.duracao_horas
            total_faturavel += registro.duracao_horas
        
        total_horas += registro.duracao_horas
    
    return {
        "periodo": {
            "inicio": date_from,
            "fim": date_to
        },
        "dias": list(timesheet_por_dia.values()),
        "resumo": {
            "total_horas": round(total_horas, 2),
            "horas_faturaveis": round(total_faturavel, 2),
            "horas_nao_faturaveis": round(total_horas - total_faturavel, 2),
            "dias_trabalhados": len(timesheet_por_dia)
        }
    }

@router.get("/registros", response_model=RegistroTempoListResponse)
async def listar_registros(
    usuario_id: Optional[UUID] = None,
    equipe_id: Optional[UUID] = None,
    cliente_id: Optional[UUID] = None,
    date_from: Optional[datetime] = None,
    date_to: Optional[datetime] = None,
    apenas_faturavel: bool = False,
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Listar registros de tempo com filtros"""
    service = TempoService(db)
    
    # Aplicar restrições baseado no tipo de usuário
    if current_user.tipo_usuario == TipoUsuario.SUPPORT_ANALYST:
        usuario_id = current_user.id
    elif current_user.tipo_usuario == TipoUsuario.SUPPORT_COORDINATOR:
        if not usuario_id:
            equipe_id = current_user.equipe_id
    
    filtros = {
        "usuario_id": usuario_id,
        "equipe_id": equipe_id,
        "cliente_id": cliente_id,
        "data_inicio": date_from,
        "data_fim": date_to,
        "apenas_faturavel": apenas_faturavel,
        "page": page,
        "per_page": per_page
    }
    
    return await service.listar_registros(filtros, current_user)

@router.put("/registros/{registro_id}/aprovar")
async def aprovar_registro(
    registro_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Aprovar registro de tempo"""
    if current_user.tipo_usuario not in [
        TipoUsuario.DIRECTOR,
        TipoUsuario.SUPPORT_COORDINATOR
    ]:
        raise HTTPException(403, "Sem permissão para aprovar registros")
    
    service = TempoService(db)
    await service.aprovar_registro(registro_id, current_user.id)
    
    return {"message": "Registro aprovado com sucesso"}
```

### Schemas
```python
class RegistroTempoCreate(BaseModel):
    inicio: datetime
    fim: datetime
    descricao_atividade: str = Field(..., min_length=10)
    tipo_atividade: TipoAtividade
    faturavel: bool = True

class RegistroTempoResponse(BaseModel):
    id: UUID
    chamado_id: UUID
    usuario_id: UUID
    inicio: datetime
    fim: datetime
    duracao_horas: float
    descricao_atividade: str
    tipo_atividade: str
    faturavel: bool
    aprovado: bool
    
    class Config:
        from_attributes = True

class TimesheetDia(BaseModel):
    data: str
    registros: List[RegistroTempoResponse]
    total_horas: float
    horas_faturaveis: float

class TimesheetResponse(BaseModel):
    periodo: Dict[str, datetime]
    dias: List[TimesheetDia]
    resumo: Dict[str, Any]
```

## 🧪 Teste Após Cada Implementação

### IMPORTANTE: Seguir TEST-TEMPLATE.md
```python
# test_time_tracking.py
import requests
from datetime import datetime, timedelta

BASE_URL = "http://localhost:8001/api/v1"

def test_time_tracking():
    # 1. Registrar tempo
    print("1. Registrando tempo...")
    tempo_data = {
        "inicio": datetime.now().isoformat(),
        "fim": (datetime.now() + timedelta(hours=2)).isoformat(),
        "descricao_atividade": "Desenvolvimento de funcionalidade",
        "tipo_atividade": "desenvolvimento",
        "faturavel": True
    }
    resp = requests.post(f"{BASE_URL}/chamados/{{chamado_id}}/tempo", json=tempo_data, headers=headers)
    if resp.status_code != 201:
        print(f"❌ ERRO: {resp.status_code} - {resp.text}")
        print("⚠️  CORRIGIR ANTES DE PROSSEGUIR!")
        return False
    print("✅ Tempo registrado")
    
    # 2. Listar registros
    print("2. Listando registros...")
    resp = requests.get(f"{BASE_URL}/tempo/registros", headers=headers)
    if resp.status_code != 200:
        print(f"❌ ERRO: {resp.status_code}")
        return False
    print("✅ Listagem OK")
    
    # 3. Meu timesheet
    print("3. Obtendo timesheet...")
    params = {
        "date_from": (datetime.now() - timedelta(days=7)).isoformat(),
        "date_to": datetime.now().isoformat()
    }
    resp = requests.get(f"{BASE_URL}/tempo/meu-timesheet", params=params, headers=headers)
    if resp.status_code != 200:
        print(f"❌ ERRO: {resp.status_code}")
        return False
    print("✅ Timesheet OK")
    
    return True

if not test_time_tracking():
    print("⚠️  CORRIGIR ERROS!")
    exit(1)
```

## ✅ Checklist de Validação
- [ ] Model RegistroTempo criado
- [ ] Schemas completos
- [ ] Registro de tempo funcionando
- [ ] Validações de tempo (não negativo, max 8h)
- [ ] Timesheet pessoal funcionando
- [ ] Filtros por equipe/cliente
- [ ] Sistema de aprovação
- [ ] Cálculo de horas faturáveis
- [ ] Testes completos

## 📊 Resultado Esperado
- Controle completo de tempo
- Timesheet por usuário
- Relatórios de tempo
- Sistema de aprovação de horas

## 📝 Log de Execução
[A ser preenchido após execução]

---
**Status**: PENDENTE
**Prioridade**: MÉDIA
**Estimativa**: 1 hora