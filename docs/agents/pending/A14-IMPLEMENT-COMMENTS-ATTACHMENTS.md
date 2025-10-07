# A14 - Implementar Comentários e Anexos

## 📋 Objetivo
Implementar sistema completo de comentários e anexos para os chamados.

## 🎯 Tarefas
1. Implementar GET `/api/v1/chamados/{chamado_id}/comentarios`
2. Implementar POST `/api/v1/chamados/{chamado_id}/comentarios`
3. Implementar GET `/api/v1/chamados/{chamado_id}/anexos`
4. Implementar POST `/api/v1/chamados/{chamado_id}/anexos`
5. Implementar GET `/api/v1/anexos/{anexo_id}/download`
6. Criar models e schemas necessários
7. Implementar upload/storage de arquivos

## 📚 Referências
- docs/agents/shared/CODE-STANDARDS.md
- docs/agents/shared/API-REFERENCE.md (seção "Comentários e Anexos")
- docs/agents/shared/TEST-TEMPLATE.md (IMPORTANTE: Testar cada endpoint)
- app/models/chamado.py

## 🔧 Implementação

### Models necessários
```python
# app/models/comentario.py
class Comentario(Base):
    __tablename__ = "comentarios"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    chamado_id = Column(UUID(as_uuid=True), ForeignKey("chamados.id"))
    usuario_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id"))
    comentario = Column(Text, nullable=False)
    visivel_cliente = Column(Boolean, default=True)
    tipo_comentario = Column(String(50), default="comentario")
    criado_em = Column(DateTime, default=datetime.utcnow)
    
    # Relacionamentos
    chamado = relationship("Chamado", back_populates="comentarios")
    usuario = relationship("Usuario")

# app/models/anexo.py
class Anexo(Base):
    __tablename__ = "anexos"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    chamado_id = Column(UUID(as_uuid=True), ForeignKey("chamados.id"))
    usuario_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id"))
    nome_arquivo = Column(String(255), nullable=False)
    caminho_arquivo = Column(String(500), nullable=False)
    tamanho_bytes = Column(Integer)
    tipo_mime = Column(String(100))
    descricao = Column(Text)
    criado_em = Column(DateTime, default=datetime.utcnow)
    
    # Relacionamentos
    chamado = relationship("Chamado", back_populates="anexos")
    usuario = relationship("Usuario")
```

### Router de comentários
```python
# app/api/v1/endpoints/comentarios.py
from fastapi import UploadFile, File

@router.get("/chamados/{chamado_id}/comentarios", response_model=List[ComentarioResponse])
async def listar_comentarios(
    chamado_id: UUID,
    visivel_cliente: Optional[bool] = None,
    skip: int = 0,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Listar comentários do chamado"""
    service = ComentarioService(db)
    
    # Filtrar visibilidade baseado no tipo de usuário
    if current_user.tipo_usuario == TipoUsuario.CLIENT:
        visivel_cliente = True
    
    return await service.listar_comentarios(
        chamado_id,
        visivel_cliente,
        skip,
        limit,
        current_user
    )

@router.post("/chamados/{chamado_id}/comentarios", response_model=ComentarioResponse)
async def adicionar_comentario(
    chamado_id: UUID,
    dados: ComentarioCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Adicionar comentário ao chamado"""
    service = ComentarioService(db)
    
    # Verificar acesso ao chamado
    chamado = await ChamadoService(db).get_by_id(chamado_id)
    if not chamado:
        raise HTTPException(404, "Chamado não encontrado")
    
    comentario = await service.criar_comentario(
        chamado_id,
        dados.comentario,
        dados.visivel_cliente,
        dados.tipo_comentario,
        current_user
    )
    
    # Notificar interessados
    if dados.visivel_cliente:
        await NotificationService(db).notificar_novo_comentario(
            chamado_id,
            comentario.id
        )
    
    return comentario
```

### Router de anexos
```python
# app/api/v1/endpoints/anexos.py
@router.get("/chamados/{chamado_id}/anexos", response_model=List[AnexoResponse])
async def listar_anexos(
    chamado_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Listar anexos do chamado"""
    service = AnexoService(db)
    return await service.listar_anexos(chamado_id, current_user)

@router.post("/chamados/{chamado_id}/anexos", response_model=AnexoResponse)
async def upload_anexo(
    chamado_id: UUID,
    file: UploadFile = File(...),
    descricao: Optional[str] = Form(None),
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Upload de anexo para o chamado"""
    # Validar tamanho (max 10MB)
    if file.size > 10 * 1024 * 1024:
        raise HTTPException(413, "Arquivo muito grande (max: 10MB)")
    
    # Validar tipo de arquivo
    allowed_types = [
        "image/jpeg", "image/png", "image/gif",
        "application/pdf", "text/plain",
        "application/zip", "application/x-zip-compressed"
    ]
    if file.content_type not in allowed_types:
        raise HTTPException(415, "Tipo de arquivo não permitido")
    
    service = AnexoService(db)
    
    # Salvar arquivo
    file_path = await service.salvar_arquivo(file, chamado_id)
    
    # Criar registro no banco
    anexo = await service.criar_anexo(
        chamado_id=chamado_id,
        nome_arquivo=file.filename,
        caminho_arquivo=file_path,
        tamanho_bytes=file.size,
        tipo_mime=file.content_type,
        descricao=descricao,
        usuario_id=current_user.id
    )
    
    return anexo

@router.get("/anexos/{anexo_id}/download")
async def download_anexo(
    anexo_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Download de anexo"""
    service = AnexoService(db)
    anexo = await service.get_by_id(anexo_id)
    
    if not anexo:
        raise HTTPException(404, "Anexo não encontrado")
    
    # Verificar permissão de acesso
    chamado = await ChamadoService(db).get_by_id(anexo.chamado_id)
    if not await service.user_has_access(chamado, current_user):
        raise HTTPException(403, "Sem permissão para acessar este anexo")
    
    # Retornar arquivo
    from fastapi.responses import FileResponse
    return FileResponse(
        path=anexo.caminho_arquivo,
        filename=anexo.nome_arquivo,
        media_type=anexo.tipo_mime
    )
```

### Services
```python
# app/services/comentario_service.py
class ComentarioService(BaseService[Comentario]):
    model = Comentario
    
    async def criar_comentario(
        self,
        chamado_id: UUID,
        texto: str,
        visivel_cliente: bool,
        tipo: str,
        usuario: Usuario
    ) -> Comentario:
        dados = {
            "chamado_id": chamado_id,
            "usuario_id": usuario.id,
            "comentario": texto,
            "visivel_cliente": visivel_cliente,
            "tipo_comentario": tipo
        }
        return await self.create(dados)

# app/services/anexo_service.py
class AnexoService(BaseService[Anexo]):
    model = Anexo
    
    async def salvar_arquivo(
        self,
        file: UploadFile,
        chamado_id: UUID
    ) -> str:
        # Criar diretório se não existir
        upload_dir = f"uploads/chamados/{chamado_id}"
        os.makedirs(upload_dir, exist_ok=True)
        
        # Gerar nome único
        file_ext = os.path.splitext(file.filename)[1]
        file_name = f"{uuid.uuid4()}{file_ext}"
        file_path = os.path.join(upload_dir, file_name)
        
        # Salvar arquivo
        async with aiofiles.open(file_path, 'wb') as f:
            content = await file.read()
            await f.write(content)
        
        return file_path
```

## 🧪 Teste Após Cada Implementação

### IMPORTANTE: Seguir TEST-TEMPLATE.md - Testar IMEDIATAMENTE cada endpoint
```bash
# 1. Teste de listar comentários
curl -X GET "http://localhost:8001/api/v1/chamados/{chamado_id}/comentarios" \
     -H "Authorization: Bearer $TOKEN"
# Esperar: 200 OK

# 2. Teste de adicionar comentário
curl -X POST "http://localhost:8001/api/v1/chamados/{chamado_id}/comentarios" \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"comentario": "Teste", "visivel_cliente": true}'
# Esperar: 201 Created

# 3. Teste de upload de anexo
curl -X POST "http://localhost:8001/api/v1/chamados/{chamado_id}/anexos" \
     -H "Authorization: Bearer $TOKEN" \
     -F "file=@teste.pdf" \
     -F "descricao=Arquivo de teste"
# Esperar: 201 Created

# 4. Teste de download
curl -X GET "http://localhost:8001/api/v1/anexos/{anexo_id}/download" \
     -H "Authorization: Bearer $TOKEN" \
     --output downloaded_file.pdf
# Esperar: 200 OK com arquivo
```

### Se algum teste falhar: PARAR e corrigir antes de continuar!

## ✅ Checklist de Validação
- [ ] Models Comentario e Anexo criados
- [ ] Schemas completos
- [ ] Upload de arquivos funcionando
- [ ] Download seguro com permissões
- [ ] Limite de tamanho de arquivo
- [ ] Validação de tipos de arquivo
- [ ] Visibilidade de comentários para cliente
- [ ] Testes de upload/download

## 📊 Resultado Esperado
- Sistema completo de comentários
- Upload/download de anexos funcionando
- Controle de visibilidade
- Storage organizado por chamado

## 📝 Log de Execução
[A ser preenchido após execução]

---
**Status**: PENDENTE
**Prioridade**: MÉDIA
**Estimativa**: 1.5 horas