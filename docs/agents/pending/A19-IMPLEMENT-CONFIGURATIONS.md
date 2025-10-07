# A19 - Implementar Sistema de Configurações

## 📋 Objetivo
Implementar endpoints de configuração do sistema, incluindo SLA rules, permissões e parâmetros gerais.

## 🎯 Tarefas
1. Implementar GET `/api/v1/configuracoes`
2. Implementar GET/POST `/api/v1/configuracoes/sla`
3. Implementar GET/PUT `/api/v1/configuracoes/permissoes`
4. Implementar GET `/api/v1/configuracoes/categorias`
5. Implementar GET `/api/v1/configuracoes/prioridades`
6. Criar sistema de configurações dinâmicas

## 📚 Referências
- docs/agents/shared/CODE-STANDARDS.md
- docs/agents/shared/API-REFERENCE.md (seção "Configurações do Sistema")
- docs/agents/shared/TEST-TEMPLATE.md (IMPORTANTE: Testar cada configuração)

## 🔧 Implementação

### Models de Configuração
```python
# app/models/configuracao.py (adicionar)
class ConfiguracaoSLA(Base):
    __tablename__ = "configuracoes_sla"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    cliente_id = Column(UUID(as_uuid=True), ForeignKey("clientes.id"))
    tipo_chamado = Column(String(50))
    prioridade = Column(String(50))
    sla_horas = Column(Integer, nullable=False)
    sla_resposta_horas = Column(Integer)
    aplicar_escalonamento = Column(Boolean, default=False)
    tempo_escalonamento_horas = Column(Integer)
    nivel_escalonamento = Column(Integer, default=1)
    ativo = Column(Boolean, default=True)
    criado_em = Column(DateTime, default=datetime.utcnow)
    
    # Relacionamentos
    cliente = relationship("Cliente")

class ConfiguracaoGeral(Base):
    __tablename__ = "configuracoes_gerais"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    chave = Column(String(100), unique=True, nullable=False)
    valor = Column(JSON)
    tipo = Column(String(50))  # string, number, boolean, json
    descricao = Column(Text)
    categoria = Column(String(50))
    editavel = Column(Boolean, default=True)
    criado_em = Column(DateTime, default=datetime.utcnow)
    atualizado_em = Column(DateTime, onupdate=datetime.utcnow)
```

### Router de Configurações
```python
# app/api/v1/endpoints/configuracoes.py
router = APIRouter(prefix="/configuracoes", tags=["configuracoes"])

@router.get("/", response_model=List[ConfiguracaoResponse])
async def listar_configuracoes(
    categoria: Optional[str] = None,
    editavel: Optional[bool] = None,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Listar configurações gerais do sistema"""
    if current_user.tipo_usuario not in [
        TipoUsuario.DIRECTOR,
        TipoUsuario.SUPPORT_COORDINATOR
    ]:
        raise HTTPException(403, "Sem permissão para ver configurações")
    
    service = ConfiguracaoService(db)
    return await service.listar_configuracoes(categoria, editavel)

@router.get("/sla-rules", response_model=List[SLAConfigResponse])
async def listar_regras_sla(
    cliente_id: Optional[UUID] = None,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Listar regras de SLA configuradas"""
    service = ConfiguracaoService(db)
    return await service.listar_regras_sla(cliente_id)

@router.post("/sla-rules", response_model=SLAConfigResponse)
async def criar_regra_sla(
    dados: SLAConfigCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Criar nova regra de SLA"""
    if current_user.tipo_usuario not in [
        TipoUsuario.DIRECTOR,
        TipoUsuario.SUPPORT_COORDINATOR
    ]:
        raise HTTPException(403, "Sem permissão para criar regras de SLA")
    
    service = ConfiguracaoService(db)
    
    # Verificar se já existe regra para esta combinação
    existe = await service.verificar_regra_existente(
        dados.cliente_id,
        dados.tipo_chamado,
        dados.prioridade
    )
    
    if existe:
        raise HTTPException(
            400,
            "Já existe uma regra de SLA para esta combinação"
        )
    
    return await service.criar_regra_sla(dados)

@router.put("/sla-rules/{regra_id}", response_model=SLAConfigResponse)
async def atualizar_regra_sla(
    regra_id: UUID,
    dados: SLAConfigUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Atualizar regra de SLA"""
    if current_user.tipo_usuario not in [
        TipoUsuario.DIRECTOR,
        TipoUsuario.SUPPORT_COORDINATOR
    ]:
        raise HTTPException(403, "Sem permissão para alterar regras de SLA")
    
    service = ConfiguracaoService(db)
    return await service.atualizar_regra_sla(regra_id, dados)

@router.get("/categorias", response_model=List[CategoriaConfig])
async def listar_categorias(
    tipo: Optional[str] = Query(None, description="Tipo de categoria"),
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Listar categorias disponíveis no sistema"""
    categorias = {
        "chamado": [
            {"valor": "bug", "label": "Bug/Erro", "cor": "#FF0000"},
            {"valor": "feature", "label": "Nova Funcionalidade", "cor": "#00FF00"},
            {"valor": "melhoria", "label": "Melhoria", "cor": "#0000FF"},
            {"valor": "duvida", "label": "Dúvida", "cor": "#FFFF00"},
            {"valor": "integracao", "label": "Integração", "cor": "#FF00FF"}
        ],
        "atividade": [
            {"valor": "desenvolvimento", "label": "Desenvolvimento"},
            {"valor": "teste", "label": "Teste"},
            {"valor": "documentacao", "label": "Documentação"},
            {"valor": "reuniao", "label": "Reunião"},
            {"valor": "suporte", "label": "Suporte"}
        ],
        "sistema": [
            {"valor": "producao", "label": "Produção"},
            {"valor": "homologacao", "label": "Homologação"},
            {"valor": "desenvolvimento", "label": "Desenvolvimento"},
            {"valor": "desativado", "label": "Desativado"}
        ]
    }
    
    if tipo:
        return categorias.get(tipo, [])
    
    return categorias

@router.get("/prioridades", response_model=List[PrioridadeConfig])
async def listar_prioridades(
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Listar níveis de prioridade configurados"""
    return [
        {
            "valor": "critica",
            "label": "Crítica",
            "cor": "#FF0000",
            "sla_padrao_horas": 4,
            "escalonar": True,
            "ordem": 1
        },
        {
            "valor": "alta",
            "label": "Alta",
            "cor": "#FF8800",
            "sla_padrao_horas": 8,
            "escalonar": True,
            "ordem": 2
        },
        {
            "valor": "media",
            "label": "Média",
            "cor": "#FFFF00",
            "sla_padrao_horas": 24,
            "escalonar": False,
            "ordem": 3
        },
        {
            "valor": "baixa",
            "label": "Baixa",
            "cor": "#00FF00",
            "sla_padrao_horas": 48,
            "escalonar": False,
            "ordem": 4
        }
    ]

@router.get("/permissoes", response_model=Dict[str, PermissaoConfig])
async def listar_permissoes(
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Listar matriz de permissões do sistema"""
    if current_user.tipo_usuario != TipoUsuario.DIRECTOR:
        raise HTTPException(403, "Apenas diretoria pode ver permissões")
    
    return MATRIZ_PERMISSOES

@router.put("/permissoes/{tipo_usuario}")
async def atualizar_permissoes(
    tipo_usuario: str,
    permissoes: Dict[str, bool],
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Atualizar permissões de um tipo de usuário"""
    if current_user.tipo_usuario != TipoUsuario.DIRECTOR:
        raise HTTPException(403, "Apenas diretoria pode alterar permissões")
    
    service = ConfiguracaoService(db)
    await service.atualizar_permissoes(tipo_usuario, permissoes)
    
    return {"message": "Permissões atualizadas com sucesso"}

@router.post("/parametros")
async def atualizar_parametro(
    chave: str,
    valor: Any,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Atualizar parâmetro de configuração"""
    if current_user.tipo_usuario != TipoUsuario.DIRECTOR:
        raise HTTPException(403, "Apenas diretoria pode alterar parâmetros")
    
    service = ConfiguracaoService(db)
    
    # Validar se parâmetro é editável
    config = await service.obter_configuracao(chave)
    if not config or not config.editavel:
        raise HTTPException(400, "Parâmetro não pode ser alterado")
    
    await service.atualizar_parametro(chave, valor)
    
    return {"message": f"Parâmetro {chave} atualizado"}
```

### Service de Configuração
```python
# app/services/configuracao_service.py
class ConfiguracaoService(BaseService):
    
    async def listar_configuracoes(
        self,
        categoria: Optional[str] = None,
        editavel: Optional[bool] = None
    ) -> List[ConfiguracaoGeral]:
        """Listar configurações gerais"""
        query = select(ConfiguracaoGeral)
        
        if categoria:
            query = query.where(ConfiguracaoGeral.categoria == categoria)
        
        if editavel is not None:
            query = query.where(ConfiguracaoGeral.editavel == editavel)
        
        query = query.order_by(ConfiguracaoGeral.categoria, ConfiguracaoGeral.chave)
        
        result = await self.db.execute(query)
        return result.scalars().all()
    
    async def criar_regra_sla(self, dados: SLAConfigCreate) -> ConfiguracaoSLA:
        """Criar nova regra de SLA"""
        regra = ConfiguracaoSLA(**dados.dict())
        self.db.add(regra)
        await self.db.commit()
        await self.db.refresh(regra)
        return regra
    
    async def calcular_sla_chamado(
        self,
        cliente_id: UUID,
        tipo_chamado: str,
        prioridade: str
    ) -> Dict[str, Any]:
        """Calcular SLA baseado nas regras configuradas"""
        # Buscar regra específica do cliente
        query = select(ConfiguracaoSLA).where(
            and_(
                ConfiguracaoSLA.cliente_id == cliente_id,
                ConfiguracaoSLA.tipo_chamado == tipo_chamado,
                ConfiguracaoSLA.prioridade == prioridade,
                ConfiguracaoSLA.ativo == True
            )
        )
        
        result = await self.db.execute(query)
        regra = result.scalar_one_or_none()
        
        if regra:
            return {
                "sla_horas": regra.sla_horas,
                "sla_resposta_horas": regra.sla_resposta_horas,
                "aplicar_escalonamento": regra.aplicar_escalonamento,
                "tempo_escalonamento_horas": regra.tempo_escalonamento_horas
            }
        
        # Usar valores padrão se não houver regra específica
        return self._sla_padrao(tipo_chamado, prioridade)
    
    def _sla_padrao(self, tipo_chamado: str, prioridade: str) -> Dict[str, Any]:
        """Valores padrão de SLA"""
        matriz_sla = {
            ("bug", "critica"): {"sla_horas": 4, "sla_resposta_horas": 1},
            ("bug", "alta"): {"sla_horas": 8, "sla_resposta_horas": 2},
            ("bug", "media"): {"sla_horas": 24, "sla_resposta_horas": 4},
            ("bug", "baixa"): {"sla_horas": 48, "sla_resposta_horas": 8},
            ("feature", "alta"): {"sla_horas": 168, "sla_resposta_horas": 24},
            ("feature", "media"): {"sla_horas": 336, "sla_resposta_horas": 48},
            ("feature", "baixa"): {"sla_horas": 504, "sla_resposta_horas": 72}
        }
        
        return matriz_sla.get(
            (tipo_chamado, prioridade),
            {"sla_horas": 48, "sla_resposta_horas": 8}  # Padrão geral
        )
```

### Matriz de Permissões
```python
# app/core/permissions.py
MATRIZ_PERMISSOES = {
    "director": {
        "usuarios.view_all": True,
        "usuarios.create": True,
        "usuarios.edit": True,
        "usuarios.delete": True,
        "chamados.view_all": True,
        "chamados.assign": True,
        "chamados.escalate": True,
        "relatorios.executive": True,
        "configuracoes.edit": True
    },
    "support_coordinator": {
        "usuarios.view_team": True,
        "usuarios.create": False,
        "usuarios.edit": False,
        "usuarios.delete": False,
        "chamados.view_team": True,
        "chamados.assign": True,
        "chamados.escalate": True,
        "relatorios.team": True,
        "configuracoes.view": True
    },
    "support_analyst": {
        "usuarios.view_self": True,
        "chamados.view_assigned": True,
        "chamados.comment": True,
        "chamados.update_status": True,
        "relatorios.personal": True
    }
    # ... outras roles
}
```

## 🧪 Teste Após Cada Implementação

### IMPORTANTE: Seguir TEST-TEMPLATE.md - Testar IMEDIATAMENTE cada endpoint
```bash
# 1. Teste listar configurações gerais
curl -X GET "http://localhost:8001/api/v1/configuracoes" \
     -H "Authorization: Bearer $TOKEN"
# Esperar: 200 OK ou 403 se não autorizado
# Se erro: PARAR e corrigir imediatamente!

# 2. Teste listar regras de SLA
curl -X GET "http://localhost:8001/api/v1/configuracoes/sla-rules" \
     -H "Authorization: Bearer $TOKEN"
# Esperar: 200 OK com lista de regras
# Se erro: Verificar model e queries

# 3. Teste criar regra de SLA
curl -X POST "http://localhost:8001/api/v1/configuracoes/sla-rules" \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "cliente_id": "uuid-cliente",
       "tipo_chamado": "bug",
       "prioridade": "critica",
       "sla_horas": 4,
       "sla_resposta_horas": 1
     }'
# Esperar: 201 Created
# Se 400: Regra já existe
# Se 403: Sem permissão

# 4. Teste listar categorias
curl -X GET "http://localhost:8001/api/v1/configuracoes/categorias?tipo=chamado" \
     -H "Authorization: Bearer $TOKEN"
# Esperar: 200 OK com lista de categorias
# Se erro: Verificar estrutura de dados

# 5. Teste listar prioridades
curl -X GET "http://localhost:8001/api/v1/configuracoes/prioridades" \
     -H "Authorization: Bearer $TOKEN"
# Esperar: 200 OK com níveis de prioridade

# 6. Teste matriz de permissões
curl -X GET "http://localhost:8001/api/v1/configuracoes/permissoes" \
     -H "Authorization: Bearer $TOKEN"
# Esperar: 200 OK (diretor) ou 403 (outros)
```

### Script Python de Teste Completo
```python
# test_configuracoes.py
import requests
import json
import sys

BASE_URL = "http://localhost:8001/api/v1"

def test_configuracoes():
    print("🧪 TESTANDO SISTEMA DE CONFIGURAÇÕES")
    print("="*50)
    
    # Login como diretor
    resp = requests.post(f"{BASE_URL}/auth/login", json={
        "email": "diretor@empresa.com",
        "password": "senha123"
    })
    
    if resp.status_code != 200:
        print("❌ ERRO no login")
        return False
    
    token = resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    
    # 1. Testar listar configurações
    print("\n1. Testando listar configurações...")
    resp = requests.get(f"{BASE_URL}/configuracoes", headers=headers)
    
    if resp.status_code != 200:
        print(f"❌ ERRO: {resp.status_code} - {resp.text}")
        print("⚠️  CORRIGIR ANTES DE PROSSEGUIR!")
        return False
    print("✅ Listagem de configurações OK")
    
    # 2. Testar regras de SLA
    print("\n2. Testando regras de SLA...")
    resp = requests.get(f"{BASE_URL}/configuracoes/sla-rules", headers=headers)
    
    if resp.status_code != 200:
        print(f"❌ ERRO: {resp.status_code}")
        return False
    
    regras = resp.json()
    print(f"✅ Regras de SLA OK - {len(regras)} regras configuradas")
    
    # 3. Testar criar regra de SLA
    print("\n3. Testando criar regra de SLA...")
    nova_regra = {
        "cliente_id": "00000000-0000-0000-0000-000000000001",  # UUID exemplo
        "tipo_chamado": "bug",
        "prioridade": "critica",
        "sla_horas": 4,
        "sla_resposta_horas": 1,
        "aplicar_escalonamento": True,
        "tempo_escalonamento_horas": 2
    }
    
    resp = requests.post(
        f"{BASE_URL}/configuracoes/sla-rules",
        json=nova_regra,
        headers=headers
    )
    
    if resp.status_code not in [200, 201, 400]:  # 400 se já existe
        print(f"❌ ERRO: {resp.status_code}")
        return False
    
    if resp.status_code == 400:
        print("✅ Regra já existe (esperado)")
    else:
        print("✅ Regra de SLA criada")
    
    # 4. Testar categorias
    print("\n4. Testando listar categorias...")
    resp = requests.get(f"{BASE_URL}/configuracoes/categorias?tipo=chamado", headers=headers)
    
    if resp.status_code != 200:
        print(f"❌ ERRO: {resp.status_code}")
        return False
    
    categorias = resp.json()
    if not isinstance(categorias, list):
        print("❌ Formato incorreto")
        return False
    
    if categorias and "valor" not in categorias[0]:
        print("❌ Estrutura de categoria incorreta")
        return False
    print(f"✅ Categorias OK - {len(categorias)} categorias")
    
    # 5. Testar prioridades
    print("\n5. Testando listar prioridades...")
    resp = requests.get(f"{BASE_URL}/configuracoes/prioridades", headers=headers)
    
    if resp.status_code != 200:
        print(f"❌ ERRO: {resp.status_code}")
        return False
    
    prioridades = resp.json()
    if not isinstance(prioridades, list) or len(prioridades) != 4:
        print("❌ Deve retornar 4 níveis de prioridade")
        return False
    print("✅ Prioridades OK")
    
    # 6. Testar permissões (apenas diretor)
    print("\n6. Testando matriz de permissões...")
    resp = requests.get(f"{BASE_URL}/configuracoes/permissoes", headers=headers)
    
    if resp.status_code != 200:
        print(f"❌ ERRO: {resp.status_code}")
        return False
    
    permissoes = resp.json()
    if "director" not in permissoes:
        print("❌ Matriz de permissões incompleta")
        return False
    print("✅ Matriz de permissões OK")
    
    # 7. Testar atualização de parâmetro
    print("\n7. Testando atualizar parâmetro...")
    resp = requests.post(
        f"{BASE_URL}/configuracoes/parametros",
        json={"chave": "max_anexo_mb", "valor": 10},
        headers=headers
    )
    
    if resp.status_code not in [200, 400]:  # 400 se parâmetro não existe
        print(f"❌ ERRO: {resp.status_code}")
        return False
    print("✅ Atualização de parâmetro OK")
    
    print("\n" + "="*50)
    print("✅ TODOS OS TESTES DE CONFIGURAÇÕES PASSARAM!")
    return True

def test_permissoes_diferentes_usuarios():
    print("\n🔐 Testando permissões por tipo de usuário...")
    
    usuarios = [
        {"email": "support@empresa.com", "password": "senha123", "tipo": "support"},
        {"email": "coord@empresa.com", "password": "senha123", "tipo": "coordinator"}
    ]
    
    for user in usuarios:
        # Login
        resp = requests.post(f"{BASE_URL}/auth/login", json={
            "email": user["email"],
            "password": user["password"]
        })
        
        if resp.status_code != 200:
            continue
        
        token = resp.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # Testar acesso a permissões
        resp = requests.get(f"{BASE_URL}/configuracoes/permissoes", headers=headers)
        
        if user["tipo"] == "support":
            if resp.status_code == 403:
                print(f"✅ {user['tipo']}: Acesso negado corretamente")
            else:
                print(f"❌ {user['tipo']}: Deveria negar acesso")
                return False
        elif user["tipo"] == "coordinator":
            if resp.status_code == 403:
                print(f"✅ {user['tipo']}: Acesso negado corretamente")
            else:
                print(f"❌ {user['tipo']}: Deveria negar acesso")
                return False
    
    return True

# Executar testes
if not test_configuracoes():
    print("\n⚠️  CORRIGIR OS ERROS ANTES DE PROSSEGUIR!")
    sys.exit(1)

test_permissoes_diferentes_usuarios()
```

### Se algum teste falhar: PARAR e corrigir antes de continuar!

## ✅ Checklist de Validação
- [ ] Todos os endpoints de configuração implementados
- [ ] Regras de SLA funcionando
- [ ] Sistema de permissões configurável
- [ ] Categorias e prioridades disponíveis
- [ ] Parâmetros gerais editáveis
- [ ] Validações aplicadas
- [ ] Cache para configurações frequentes

## 📊 Resultado Esperado
- Sistema de configuração completo
- SLA dinâmico por cliente
- Permissões configuráveis
- Parâmetros do sistema ajustáveis

## 📝 Log de Execução
[A ser preenchido após execução]

---
**Status**: PENDENTE
**Prioridade**: MÉDIA
**Estimativa**: 1.5 horas