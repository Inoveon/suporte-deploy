# 📚 Padrões de Código - Sistema de Gestão de Chamados

## 🎯 Objetivo
Estabelecer padrões consistentes de desenvolvimento para garantir qualidade, manutenibilidade e escalabilidade do sistema.

## 🏗️ Estrutura do Projeto

```
app/
├── api/
│   ├── deps.py              # Dependências comuns (auth, db)
│   └── v1/
│       ├── endpoints/        # Routers organizados por domínio
│       │   ├── usuarios.py
│       │   ├── chamados.py
│       │   └── ...
│       └── __init__.py
├── core/
│   ├── config.py            # Configurações
│   ├── database.py          # Conexão DB
│   ├── security.py          # Autenticação
│   └── middleware.py        # Middlewares
├── models/                  # SQLAlchemy models
│   ├── base.py             # Base model
│   ├── usuario.py
│   ├── chamado.py
│   └── ...
├── schemas/                 # Pydantic schemas
│   ├── usuario.py
│   ├── chamado.py
│   └── ...
├── services/               # Lógica de negócio
│   ├── base.py            # BaseService
│   ├── usuario_service.py
│   ├── chamado_service.py
│   └── ...
└── main.py                # FastAPI app
```

## 📝 Padrões de Nomenclatura

### Models (SQLAlchemy)
```python
# Arquivo: app/models/chamado.py
class Chamado(Base):
    __tablename__ = "chamados"
    
    # Campos com snake_case
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    titulo = Column(String(200), nullable=False)
    criado_em = Column(DateTime, default=datetime.utcnow)
    atualizado_em = Column(DateTime, onupdate=datetime.utcnow)
    
    # Relacionamentos
    cliente = relationship("Cliente", back_populates="chamados")
    comentarios = relationship("Comentario", back_populates="chamado")
```

### Schemas (Pydantic)
```python
# Arquivo: app/schemas/chamado.py
class ChamadoBase(BaseModel):
    titulo: str = Field(..., min_length=1, max_length=200)
    descricao: Optional[str] = None

class ChamadoCreate(ChamadoBase):
    cliente_id: UUID
    prioridade: PrioridadeChamado

class ChamadoUpdate(BaseModel):
    titulo: Optional[str] = None
    status: Optional[StatusChamado] = None

class ChamadoResponse(ChamadoBase):
    id: UUID
    criado_em: datetime
    status: str
    
    class Config:
        from_attributes = True

class ChamadoListResponse(BaseModel):
    items: List[ChamadoResponse]
    total: int
    page: int
    per_page: int
    pages: int
    has_next: bool
    has_prev: bool
```

### Services
```python
# Arquivo: app/services/chamado_service.py
class ChamadoService(BaseService[Chamado]):
    model = Chamado
    
    async def criar_chamado(
        self,
        dados: ChamadoCreate,
        current_user: Usuario
    ) -> Chamado:
        """
        Criar novo chamado com validações de negócio
        """
        # Validações
        await self._validar_cliente(dados.cliente_id)
        
        # Criar chamado
        chamado = await self.create(dados.dict())
        
        # Notificar
        await self._notificar_novo_chamado(chamado)
        
        return chamado
    
    async def listar_chamados(
        self,
        filtros: Dict[str, Any],
        current_user: Usuario
    ) -> ChamadoListResponse:
        """
        Listar chamados com filtros e paginação
        """
        query = self._build_query(filtros, current_user)
        return await self.paginate(query, filtros)
```

### Routers/Endpoints
```python
# Arquivo: app/api/v1/endpoints/chamados.py
router = APIRouter(prefix="/chamados", tags=["chamados"])

@router.get("/", response_model=ChamadoListResponse)
async def listar_chamados(
    status: Optional[str] = Query(None),
    prioridade: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Listar chamados com filtros e paginação
    
    Permissões:
    - Director: Todos os chamados
    - Coordinator: Chamados da equipe
    - Analyst: Apenas atribuídos
    """
    service = ChamadoService(db)
    filtros = {
        "status": status,
        "prioridade": prioridade,
        "page": page,
        "per_page": per_page
    }
    return await service.listar_chamados(filtros, current_user)

# IMPORTANTE: Rotas específicas ANTES das parametrizadas
@router.get("/stats", response_model=ChamadoStats)
async def obter_estatisticas(...):
    """Estatísticas de chamados"""
    pass

@router.get("/{chamado_id}", response_model=ChamadoResponse)
async def obter_chamado(...):
    """Detalhes de um chamado"""
    pass
```

## 🔧 Padrões de Implementação

### 1. Ordem de Rotas
```python
# ✅ CORRETO - Rotas específicas primeiro
@router.get("/me")
@router.get("/stats")
@router.get("/{id}")

# ❌ INCORRETO - Causará conflito 422
@router.get("/{id}")
@router.get("/me")  # Nunca será alcançada
```

### 2. Tratamento de Erros
```python
from app.core.exceptions import NotFoundError, BusinessLogicError

async def obter_chamado(chamado_id: UUID):
    chamado = await service.get_by_id(chamado_id)
    if not chamado:
        raise NotFoundError(f"Chamado {chamado_id} não encontrado")
    
    if not user_has_access(chamado, current_user):
        raise HTTPException(
            status_code=403,
            detail="Usuário não tem acesso a este chamado"
        )
    
    return chamado
```

### 3. Paginação Padrão
```python
class PaginationParams(BaseModel):
    page: int = Query(1, ge=1)
    per_page: int = Query(20, ge=1, le=100)
    
async def paginate(query, params: PaginationParams):
    total = await db.execute(select(func.count()).select_from(query))
    items = await db.execute(
        query.offset((params.page - 1) * params.per_page)
             .limit(params.per_page)
    )
    
    return {
        "items": items.scalars().all(),
        "total": total.scalar(),
        "page": params.page,
        "per_page": params.per_page,
        "pages": math.ceil(total.scalar() / params.per_page),
        "has_next": params.page * params.per_page < total.scalar(),
        "has_prev": params.page > 1
    }
```

### 4. Validações e Permissões
```python
# Em services
async def _validar_permissao_chamado(
    self,
    chamado: Chamado,
    user: Usuario,
    acao: str
) -> bool:
    """Validar se usuário pode executar ação no chamado"""
    
    # Director tem acesso total
    if user.tipo_usuario == TipoUsuario.DIRECTOR:
        return True
    
    # Coordinator pode gerenciar da equipe
    if user.tipo_usuario == TipoUsuario.SUPPORT_COORDINATOR:
        return chamado.equipe_id == user.equipe_id
    
    # Analyst apenas atribuídos
    if user.tipo_usuario == TipoUsuario.SUPPORT_ANALYST:
        return chamado.atribuido_para == user.id
    
    return False
```

### 5. Async/Await Consistente
```python
# ✅ CORRETO - Sempre async/await com DB
async def get_usuario(db: AsyncSession, user_id: UUID):
    result = await db.execute(
        select(Usuario).where(Usuario.id == user_id)
    )
    return result.scalar_one_or_none()

# ❌ INCORRETO - Misturar sync/async
def get_usuario(db: AsyncSession, user_id: UUID):
    return db.query(Usuario).filter(Usuario.id == user_id).first()
```

## 📊 Padrões de Resposta

### Sucesso
```python
# 200 OK - GET
{
    "id": "uuid",
    "titulo": "Chamado exemplo",
    "status": "aberto"
}

# 201 Created - POST
{
    "id": "uuid",
    "message": "Chamado criado com sucesso",
    "data": {...}
}

# 204 No Content - DELETE
# Sem corpo de resposta
```

### Erros
```python
# 400 Bad Request
{
    "error": "VALIDATION_ERROR",
    "message": "Dados inválidos",
    "details": [
        {"field": "email", "error": "Email inválido"}
    ]
}

# 401 Unauthorized
{
    "error": "UNAUTHORIZED",
    "message": "Token inválido ou expirado"
}

# 403 Forbidden
{
    "error": "FORBIDDEN",
    "message": "Sem permissão para esta ação",
    "required_permission": "chamados.delete"
}

# 404 Not Found
{
    "error": "NOT_FOUND",
    "message": "Recurso não encontrado",
    "resource": "chamado",
    "id": "uuid"
}

# 422 Unprocessable Entity
{
    "error": "UNPROCESSABLE_ENTITY",
    "message": "Entidade não processável",
    "details": {...}
}

# 500 Internal Server Error
{
    "error": "INTERNAL_ERROR",
    "message": "Erro interno do servidor",
    "request_id": "uuid"
}
```

## 🧪 Padrões de Teste

### Estrutura
```python
# tests/test_chamados.py
import pytest
from httpx import AsyncClient

@pytest.mark.asyncio
async def test_criar_chamado(
    client: AsyncClient,
    db_session,
    user_token
):
    # Arrange
    data = {
        "titulo": "Teste",
        "cliente_id": "uuid"
    }
    
    # Act
    response = await client.post(
        "/api/v1/chamados",
        json=data,
        headers={"Authorization": f"Bearer {user_token}"}
    )
    
    # Assert
    assert response.status_code == 201
    assert response.json()["titulo"] == "Teste"
```

## 🔒 Segurança

### 1. Nunca expor dados sensíveis
```python
# ❌ INCORRETO
return {"user": user, "password": password}

# ✅ CORRETO
return {"user": user.dict(exclude={"password", "senha_hash"})}
```

### 2. Sempre validar permissões
```python
@router.delete("/{id}")
async def deletar(id: UUID, current_user: Usuario = Depends(get_current_user)):
    if not current_user.has_permission("delete"):
        raise HTTPException(403, "Sem permissão")
```

### 3. Sanitizar inputs
```python
from html import escape

titulo = escape(dados.titulo)  # Prevenir XSS
```

## 📚 Imports Padrão

```python
# Ordem de imports
# 1. Standard library
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
from uuid import UUID
import logging

# 2. Third party
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel, Field

# 3. Local application
from app.core.database import get_db
from app.api.deps import get_current_user
from app.models.chamado import Chamado
from app.schemas.chamado import ChamadoCreate, ChamadoResponse
from app.services.chamado_service import ChamadoService
```

## ✅ Checklist de Implementação

Para cada novo endpoint:
- [ ] Schema Pydantic criado
- [ ] Model SQLAlchemy verificado
- [ ] Service com lógica de negócio
- [ ] Router com validações
- [ ] Ordem de rotas correta (específicas primeiro)
- [ ] Permissões implementadas
- [ ] Tratamento de erros
- [ ] Paginação (se listagem)
- [ ] Testes escritos
- [ ] Documentação OpenAPI

## 🚀 Comandos Úteis

```bash
# Verificar tipos
mypy app/

# Formatar código
black app/

# Lint
flake8 app/

# Testes
pytest tests/

# Coverage
pytest --cov=app tests/
```

---
*Última atualização: 02/10/2025*