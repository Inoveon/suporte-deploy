# A18 - Implementar Sistema de Busca

## 📋 Objetivo
Implementar busca global e endpoints de opções para selects/autocomplete.

## 🎯 Tarefas
1. Implementar GET `/api/v1/search` - Busca global
2. Implementar GET `/api/v1/options/clientes`
3. Implementar GET `/api/v1/options/usuarios`
4. Implementar GET `/api/v1/options/sistemas`
5. Implementar GET `/api/v1/options/equipes`
6. Criar índices para otimizar buscas

## 📚 Referências
- docs/agents/shared/CODE-STANDARDS.md
- docs/agents/shared/API-REFERENCE.md (seção "Busca e Filtros")
- docs/agents/shared/TEST-TEMPLATE.md (IMPORTANTE: Testar cada endpoint)

## 🔧 Implementação

### Router de Busca
```python
# app/api/v1/endpoints/busca.py
router = APIRouter(prefix="", tags=["busca"])

@router.get("/search", response_model=SearchResponse)
async def busca_global(
    q: str = Query(..., min_length=2, description="Termo de busca"),
    entity: Optional[str] = Query(None, regex="^(chamados|clientes|usuarios|sistemas)$"),
    limit: int = Query(10, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Busca global no sistema
    
    Busca em múltiplas entidades baseado nas permissões do usuário
    """
    service = BuscaService(db)
    
    # Definir entidades baseado no tipo de usuário
    entidades_permitidas = definir_entidades_permitidas(current_user)
    
    if entity:
        if entity not in entidades_permitidas:
            raise HTTPException(403, f"Sem permissão para buscar em {entity}")
        entidades = [entity]
    else:
        entidades = entidades_permitidas
    
    resultados = {}
    
    # Buscar em cada entidade
    for entidade in entidades:
        if entidade == "chamados":
            resultados["chamados"] = await service.buscar_chamados(
                q, limit, current_user
            )
        elif entidade == "clientes":
            resultados["clientes"] = await service.buscar_clientes(
                q, limit, current_user
            )
        elif entidade == "usuarios":
            resultados["usuarios"] = await service.buscar_usuarios(
                q, limit, current_user
            )
        elif entidade == "sistemas":
            resultados["sistemas"] = await service.buscar_sistemas(
                q, limit, current_user
            )
    
    # Formatar resposta
    return {
        "query": q,
        "total_results": sum(len(r) for r in resultados.values()),
        "results": resultados,
        "timestamp": datetime.now()
    }

@router.get("/options/clientes", response_model=List[OptionResponse])
async def opcoes_clientes(
    search: Optional[str] = None,
    ativo: bool = True,
    limit: int = Query(20, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Opções de clientes para selects"""
    query = select(Cliente.id, Cliente.nome, Cliente.cnpj)
    
    # Filtrar por ativos
    if ativo:
        query = query.where(Cliente.ativo == True)
    
    # Busca por nome ou CNPJ
    if search:
        query = query.where(
            or_(
                Cliente.nome.ilike(f"%{search}%"),
                Cliente.cnpj.like(f"%{search}%")
            )
        )
    
    # Aplicar restrições baseado no usuário
    if current_user.tipo_usuario == TipoUsuario.SUPPORT_ANALYST:
        # Apenas clientes com chamados atribuídos
        query = query.join(Chamado).where(
            Chamado.atribuido_para == current_user.id
        ).distinct()
    
    query = query.order_by(Cliente.nome).limit(limit)
    
    result = await db.execute(query)
    clientes = result.all()
    
    return [
        {
            "value": str(cliente.id),
            "label": cliente.nome,
            "extra": cliente.cnpj
        }
        for cliente in clientes
    ]

@router.get("/options/usuarios", response_model=List[OptionResponse])
async def opcoes_usuarios(
    search: Optional[str] = None,
    tipo: Optional[str] = Query(None, description="Filtrar por tipo"),
    equipe_id: Optional[UUID] = None,
    disponivel: bool = False,
    limit: int = Query(20, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Opções de usuários para atribuição"""
    query = select(
        Usuario.id,
        Usuario.nome_completo,
        Usuario.email,
        Usuario.tipo_usuario
    ).where(Usuario.ativo == True)
    
    # Busca por nome ou email
    if search:
        query = query.where(
            or_(
                Usuario.nome_completo.ilike(f"%{search}%"),
                Usuario.email.ilike(f"%{search}%")
            )
        )
    
    # Filtrar por tipo
    if tipo:
        query = query.where(Usuario.tipo_usuario == tipo)
    
    # Filtrar por equipe
    if equipe_id:
        query = query.join(EquipeMembro).where(
            EquipeMembro.equipe_id == equipe_id
        )
    
    # Apenas disponíveis (sem sobrecarga)
    if disponivel:
        # Subquery para contar chamados ativos
        subq = select(
            Chamado.atribuido_para,
            func.count(Chamado.id).label('total')
        ).where(
            Chamado.status.in_(["aberto", "em_andamento"])
        ).group_by(Chamado.atribuido_para).subquery()
        
        query = query.outerjoin(subq, Usuario.id == subq.c.atribuido_para)
        query = query.where(
            or_(
                subq.c.total == None,
                subq.c.total < 10  # Max 10 chamados ativos
            )
        )
    
    query = query.order_by(Usuario.nome_completo).limit(limit)
    
    result = await db.execute(query)
    usuarios = result.all()
    
    return [
        {
            "value": str(usuario.id),
            "label": usuario.nome_completo,
            "extra": {
                "email": usuario.email,
                "tipo": usuario.tipo_usuario
            }
        }
        for usuario in usuarios
    ]

@router.get("/options/sistemas", response_model=List[OptionResponse])
async def opcoes_sistemas(
    cliente_id: Optional[UUID] = Query(None, description="Filtrar por cliente"),
    search: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = Query(20, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Opções de sistemas para selects"""
    query = select(
        Sistema.id,
        Sistema.nome,
        Sistema.versao_atual,
        Sistema.cliente_id,
        Cliente.nome.label('cliente_nome')
    ).join(Cliente)
    
    # Filtrar por cliente
    if cliente_id:
        query = query.where(Sistema.cliente_id == cliente_id)
    
    # Busca por nome
    if search:
        query = query.where(Sistema.nome.ilike(f"%{search}%"))
    
    # Filtrar por status
    if status:
        query = query.where(Sistema.status == status)
    
    query = query.where(Sistema.ativo == True)
    query = query.order_by(Sistema.nome).limit(limit)
    
    result = await db.execute(query)
    sistemas = result.all()
    
    return [
        {
            "value": str(sistema.id),
            "label": f"{sistema.nome} (v{sistema.versao_atual})",
            "extra": {
                "cliente": sistema.cliente_nome,
                "cliente_id": str(sistema.cliente_id)
            }
        }
        for sistema in sistemas
    ]

@router.get("/options/equipes", response_model=List[OptionResponse])
async def opcoes_equipes(
    search: Optional[str] = None,
    departamento: Optional[str] = None,
    limit: int = Query(20, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Opções de equipes para selects"""
    query = select(
        Equipe.id,
        Equipe.nome,
        Equipe.departamento,
        func.count(EquipeMembro.usuario_id).label('total_membros')
    ).outerjoin(EquipeMembro).group_by(Equipe.id)
    
    # Busca por nome
    if search:
        query = query.where(Equipe.nome.ilike(f"%{search}%"))
    
    # Filtrar por departamento
    if departamento:
        query = query.where(Equipe.departamento == departamento)
    
    query = query.where(Equipe.ativo == True)
    query = query.order_by(Equipe.nome).limit(limit)
    
    result = await db.execute(query)
    equipes = result.all()
    
    return [
        {
            "value": str(equipe.id),
            "label": equipe.nome,
            "extra": {
                "departamento": equipe.departamento,
                "membros": equipe.total_membros
            }
        }
        for equipe in equipes
    ]
```

### Service de Busca
```python
# app/services/busca_service.py
class BuscaService(BaseService):
    
    async def buscar_chamados(
        self,
        termo: str,
        limit: int,
        current_user: Usuario
    ) -> List[Dict]:
        """Buscar chamados por termo"""
        query = select(
            Chamado.id,
            Chamado.numero,
            Chamado.titulo,
            Chamado.status,
            Cliente.nome.label('cliente_nome')
        ).join(Cliente)
        
        # Busca em título, descrição ou número
        query = query.where(
            or_(
                Chamado.titulo.ilike(f"%{termo}%"),
                Chamado.descricao.ilike(f"%{termo}%"),
                Chamado.numero.like(f"%{termo}%")
            )
        )
        
        # Aplicar filtros de permissão
        query = self._aplicar_filtros_usuario(query, current_user)
        
        query = query.order_by(Chamado.criado_em.desc()).limit(limit)
        
        result = await self.db.execute(query)
        chamados = result.all()
        
        return [
            {
                "id": str(chamado.id),
                "tipo": "chamado",
                "titulo": f"#{chamado.numero} - {chamado.titulo}",
                "subtitulo": f"Cliente: {chamado.cliente_nome}",
                "status": chamado.status,
                "url": f"/chamados/{chamado.id}"
            }
            for chamado in chamados
        ]
    
    async def buscar_clientes(
        self,
        termo: str,
        limit: int,
        current_user: Usuario
    ) -> List[Dict]:
        """Buscar clientes por termo"""
        query = select(
            Cliente.id,
            Cliente.nome,
            Cliente.cnpj,
            Cliente.email_contato,
            func.count(Chamado.id).label('total_chamados')
        ).outerjoin(Chamado).group_by(Cliente.id)
        
        query = query.where(
            or_(
                Cliente.nome.ilike(f"%{termo}%"),
                Cliente.cnpj.like(f"%{termo}%"),
                Cliente.email_contato.ilike(f"%{termo}%")
            )
        )
        
        query = query.where(Cliente.ativo == True)
        query = query.order_by(Cliente.nome).limit(limit)
        
        result = await self.db.execute(query)
        clientes = result.all()
        
        return [
            {
                "id": str(cliente.id),
                "tipo": "cliente",
                "titulo": cliente.nome,
                "subtitulo": f"CNPJ: {cliente.cnpj}",
                "extra": {
                    "email": cliente.email_contato,
                    "chamados": cliente.total_chamados
                },
                "url": f"/clientes/{cliente.id}"
            }
            for cliente in clientes
        ]
```

### Schemas
```python
class OptionResponse(BaseModel):
    value: str
    label: str
    extra: Optional[Dict[str, Any]] = None

class SearchResultItem(BaseModel):
    id: str
    tipo: str
    titulo: str
    subtitulo: Optional[str] = None
    status: Optional[str] = None
    extra: Optional[Dict[str, Any]] = None
    url: Optional[str] = None

class SearchResponse(BaseModel):
    query: str
    total_results: int
    results: Dict[str, List[SearchResultItem]]
    timestamp: datetime
```

## 🧪 Teste Após Cada Implementação

### IMPORTANTE: Seguir TEST-TEMPLATE.md - Testar IMEDIATAMENTE cada endpoint
```bash
# 1. Teste busca global
curl -X GET "http://localhost:8001/api/v1/search?q=teste" \
     -H "Authorization: Bearer $TOKEN"
# Esperar: 200 OK com resultados
# Se erro: PARAR e corrigir imediatamente!

# 2. Teste busca específica por entidade
curl -X GET "http://localhost:8001/api/v1/search?q=bug&entity=chamados" \
     -H "Authorization: Bearer $TOKEN"
# Esperar: 200 OK apenas com chamados
# Se erro: Verificar filtros e permissões

# 3. Teste options de clientes
curl -X GET "http://localhost:8001/api/v1/options/clientes?search=empresa" \
     -H "Authorization: Bearer $TOKEN"
# Esperar: 200 OK com lista de clientes
# Se erro: Verificar query e joins

# 4. Teste options de usuários
curl -X GET "http://localhost:8001/api/v1/options/usuarios?disponivel=true" \
     -H "Authorization: Bearer $TOKEN"
# Esperar: 200 OK com usuários disponíveis
# Se erro: Verificar subquery de disponibilidade

# 5. Teste options de sistemas
curl -X GET "http://localhost:8001/api/v1/options/sistemas?cliente_id=uuid-cliente" \
     -H "Authorization: Bearer $TOKEN"
# Esperar: 200 OK com sistemas do cliente
# Se erro: Verificar filtro por cliente

# 6. Teste options de equipes
curl -X GET "http://localhost:8001/api/v1/options/equipes" \
     -H "Authorization: Bearer $TOKEN"
# Esperar: 200 OK com lista de equipes
```

### Script Python de Teste Completo
```python
# test_busca.py
import requests
import json
import sys
import time

BASE_URL = "http://localhost:8001/api/v1"

def test_busca_e_options():
    print("🧪 TESTANDO SISTEMA DE BUSCA E OPTIONS")
    print("="*50)
    
    # Login
    resp = requests.post(f"{BASE_URL}/auth/login", json={
        "email": "admin@empresa.com",
        "password": "admin123"
    })
    
    if resp.status_code != 200:
        print("❌ ERRO no login")
        return False
    
    token = resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    
    # 1. Testar busca global
    print("\n1. Testando busca global...")
    resp = requests.get(f"{BASE_URL}/search?q=teste", headers=headers)
    
    if resp.status_code != 200:
        print(f"❌ ERRO: {resp.status_code} - {resp.text}")
        print("⚠️  CORRIGIR ANTES DE PROSSEGUIR!")
        return False
    
    dados = resp.json()
    if "query" not in dados or "results" not in dados:
        print("❌ Estrutura de resposta incorreta")
        return False
    print(f"✅ Busca global OK - {dados['total_results']} resultados")
    
    # 2. Testar busca por entidade específica
    print("\n2. Testando busca por entidade (chamados)...")
    resp = requests.get(f"{BASE_URL}/search?q=bug&entity=chamados", headers=headers)
    
    if resp.status_code != 200:
        print(f"❌ ERRO: {resp.status_code}")
        return False
    
    dados = resp.json()
    if "chamados" not in dados["results"]:
        print("❌ Deveria retornar apenas chamados")
        return False
    print("✅ Busca por entidade OK")
    
    # 3. Testar options de clientes
    print("\n3. Testando options de clientes...")
    resp = requests.get(f"{BASE_URL}/options/clientes", headers=headers)
    
    if resp.status_code != 200:
        print(f"❌ ERRO: {resp.status_code}")
        return False
    
    clientes = resp.json()
    if not isinstance(clientes, list):
        print("❌ Resposta deve ser uma lista")
        return False
    
    if clientes and ("value" not in clientes[0] or "label" not in clientes[0]):
        print("❌ Formato de option incorreto")
        return False
    print(f"✅ Options de clientes OK - {len(clientes)} opções")
    
    # 4. Testar options de usuários com filtro
    print("\n4. Testando options de usuários (disponíveis)...")
    resp = requests.get(f"{BASE_URL}/options/usuarios?disponivel=true", headers=headers)
    
    if resp.status_code != 200:
        print(f"❌ ERRO: {resp.status_code}")
        return False
    
    usuarios = resp.json()
    print(f"✅ Options de usuários OK - {len(usuarios)} disponíveis")
    
    # 5. Testar options de sistemas com busca
    print("\n5. Testando options de sistemas com busca...")
    resp = requests.get(f"{BASE_URL}/options/sistemas?search=ERP", headers=headers)
    
    if resp.status_code != 200:
        print(f"❌ ERRO: {resp.status_code}")
        return False
    
    sistemas = resp.json()
    print(f"✅ Options de sistemas OK - {len(sistemas)} encontrados")
    
    # 6. Testar options de equipes
    print("\n6. Testando options de equipes...")
    resp = requests.get(f"{BASE_URL}/options/equipes", headers=headers)
    
    if resp.status_code != 200:
        print(f"❌ ERRO: {resp.status_code}")
        return False
    
    equipes = resp.json()
    if equipes and "extra" in equipes[0]:
        if "membros" not in equipes[0]["extra"]:
            print("❌ Faltando contagem de membros")
            return False
    print(f"✅ Options de equipes OK - {len(equipes)} equipes")
    
    print("\n" + "="*50)
    print("✅ TODOS OS TESTES DE BUSCA PASSARAM!")
    return True

def test_performance_busca():
    print("\n⏱️  Testando performance da busca...")
    
    # Login
    resp = requests.post(f"{BASE_URL}/auth/login", json={
        "email": "admin@empresa.com",
        "password": "admin123"
    })
    token = resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    
    # Testar busca global
    start = time.time()
    resp = requests.get(f"{BASE_URL}/search?q=a", headers=headers)  # Busca genérica
    elapsed = time.time() - start
    
    if elapsed > 0.5:
        print(f"⚠️  AVISO: Busca demorou {elapsed:.3f}s (máximo recomendado: 500ms)")
        print("   Verificar índices no banco de dados:")
        print("   - CREATE INDEX idx_chamados_titulo ON chamados(titulo);")
        print("   - CREATE INDEX idx_clientes_nome ON clientes(nome);")
        print("   - CREATE INDEX idx_usuarios_nome ON usuarios(nome_completo);")
    else:
        print(f"✅ Performance OK: {elapsed:.3f}s")
    
    return resp.status_code == 200

# Executar testes
if not test_busca_e_options():
    print("\n⚠️  CORRIGIR OS ERROS ANTES DE PROSSEGUIR!")
    sys.exit(1)

test_performance_busca()
```

### Verificação de Índices no Banco
```sql
-- Criar índices para otimizar busca
CREATE INDEX IF NOT EXISTS idx_chamados_titulo ON chamados USING gin(to_tsvector('portuguese', titulo));
CREATE INDEX IF NOT EXISTS idx_chamados_descricao ON chamados USING gin(to_tsvector('portuguese', descricao));
CREATE INDEX IF NOT EXISTS idx_chamados_numero ON chamados(numero);

CREATE INDEX IF NOT EXISTS idx_clientes_nome ON clientes USING gin(to_tsvector('portuguese', nome));
CREATE INDEX IF NOT EXISTS idx_clientes_cnpj ON clientes(cnpj);

CREATE INDEX IF NOT EXISTS idx_usuarios_nome ON usuarios USING gin(to_tsvector('portuguese', nome_completo));
CREATE INDEX IF NOT EXISTS idx_usuarios_email ON usuarios(email);

CREATE INDEX IF NOT EXISTS idx_sistemas_nome ON sistemas USING gin(to_tsvector('portuguese', nome));
```

### Se algum teste falhar: PARAR e corrigir imediatamente!

## ✅ Checklist de Validação
- [ ] Busca global funcionando
- [ ] Todos os endpoints de options implementados
- [ ] Filtros e permissões aplicados
- [ ] Performance otimizada com índices
- [ ] Autocomplete responsivo
- [ ] Limitação de resultados
- [ ] Testes de busca com diferentes termos

## 📊 Resultado Esperado
- Busca global rápida e eficiente
- Options para todos os selects
- Autocomplete funcionando
- Resposta rápida (< 200ms)

## 📝 Log de Execução
[A ser preenchido após execução]

---
**Status**: PENDENTE
**Prioridade**: MÉDIA
**Estimativa**: 1 hora