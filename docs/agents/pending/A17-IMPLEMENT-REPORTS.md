# A17 - Implementar Sistema de Relatórios

## 📋 Objetivo
Implementar sistema completo de relatórios com exportação em múltiplos formatos.

## 🎯 Tarefas
1. Implementar GET `/api/v1/relatorios/sla-compliance`
2. Implementar GET `/api/v1/relatorios/produtividade`
3. Implementar GET `/api/v1/relatorios/chamados-detalhado`
4. Implementar POST `/api/v1/relatorios/customizado`
5. Implementar exportação PDF/CSV/Excel
6. Criar templates de relatórios

## 📚 Referências
- docs/agents/shared/CODE-STANDARDS.md
- docs/agents/shared/API-REFERENCE.md (seção "Relatórios Específicos")
- docs/agents/shared/TEST-TEMPLATE.md (IMPORTANTE: Testar cada relatório)

## 🔧 Implementação

### Router de Relatórios
```python
# app/api/v1/endpoints/relatorios.py
from fastapi.responses import FileResponse, StreamingResponse
import pandas as pd
from reportlab.pdfgen import canvas

router = APIRouter(prefix="/relatorios", tags=["relatorios"])

@router.get("/sla-compliance")
async def relatorio_sla(
    cliente_id: Optional[UUID] = None,
    equipe_id: Optional[UUID] = None,
    period: str = Query("monthly", regex="^(daily|weekly|monthly|yearly)$"),
    format: str = Query("json", regex="^(json|csv|pdf|excel)$"),
    data_inicio: datetime = Query(...),
    data_fim: datetime = Query(...),
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Relatório de cumprimento de SLA"""
    service = RelatorioService(db)
    
    # Gerar dados do relatório
    dados = await service.relatorio_sla(
        cliente_id=cliente_id,
        equipe_id=equipe_id,
        data_inicio=data_inicio,
        data_fim=data_fim,
        periodo=period
    )
    
    # Formatar resposta baseado no formato solicitado
    if format == "json":
        return dados
    elif format == "csv":
        return await exportar_csv(dados, "relatorio_sla")
    elif format == "pdf":
        return await exportar_pdf(dados, "Relatório de SLA", current_user)
    elif format == "excel":
        return await exportar_excel(dados, "relatorio_sla")

@router.get("/produtividade")
async def relatorio_produtividade(
    usuario_id: Optional[UUID] = None,
    equipe_id: Optional[UUID] = None,
    data_inicio: datetime = Query(...),
    data_fim: datetime = Query(...),
    format: str = Query("json"),
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Relatório de produtividade"""
    # Verificar permissões
    if current_user.tipo_usuario not in [
        TipoUsuario.DIRECTOR,
        TipoUsuario.SUPPORT_COORDINATOR
    ]:
        raise HTTPException(403, "Sem permissão para relatórios de produtividade")
    
    service = RelatorioService(db)
    
    dados = await service.relatorio_produtividade(
        usuario_id=usuario_id,
        equipe_id=equipe_id,
        data_inicio=data_inicio,
        data_fim=data_fim
    )
    
    # Estrutura do relatório
    relatorio = {
        "periodo": {
            "inicio": data_inicio.isoformat(),
            "fim": data_fim.isoformat()
        },
        "resumo": {
            "total_chamados": dados["total_chamados"],
            "chamados_resolvidos": dados["resolvidos"],
            "tempo_medio_resolucao": dados["tempo_medio"],
            "taxa_sla": dados["taxa_sla"],
            "horas_trabalhadas": dados["horas_total"],
            "horas_faturaveis": dados["horas_faturaveis"]
        },
        "por_usuario": dados["detalhes_usuarios"],
        "por_equipe": dados["detalhes_equipes"],
        "evolucao_diaria": dados["evolucao"],
        "top_performers": dados["top_performers"]
    }
    
    return formatar_resposta(relatorio, format)

@router.get("/chamados-detalhado")
async def relatorio_chamados_detalhado(
    cliente_id: Optional[UUID] = None,
    status: Optional[str] = None,
    prioridade: Optional[str] = None,
    categoria: Optional[str] = None,
    data_inicio: Optional[datetime] = None,
    data_fim: Optional[datetime] = None,
    format: str = Query("json"),
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Relatório detalhado de chamados com múltiplos filtros"""
    service = RelatorioService(db)
    
    filtros = {
        "cliente_id": cliente_id,
        "status": status,
        "prioridade": prioridade,
        "categoria": categoria,
        "data_inicio": data_inicio,
        "data_fim": data_fim
    }
    
    dados = await service.relatorio_chamados_detalhado(filtros, current_user)
    
    return formatar_resposta(dados, format)

@router.post("/customizado")
async def gerar_relatorio_customizado(
    config: RelatorioCustomizado,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Gerar relatório customizado com campos e filtros definidos"""
    service = RelatorioService(db)
    
    # Validar permissões para campos solicitados
    await service.validar_campos_permitidos(config.campos, current_user)
    
    # Gerar relatório
    dados = await service.gerar_customizado(
        entidade=config.entidade,
        campos=config.campos,
        filtros=config.filtros,
        agrupamentos=config.agrupamentos,
        ordenacao=config.ordenacao,
        current_user=current_user
    )
    
    return formatar_resposta(dados, config.formato)

@router.get("/clientes")
async def relatorio_clientes(
    incluir_inativos: bool = False,
    format: str = Query("json"),
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Relatório de clientes com métricas"""
    service = RelatorioService(db)
    
    dados = await service.relatorio_clientes(incluir_inativos)
    
    relatorio = {
        "total_clientes": len(dados["clientes"]),
        "clientes_ativos": dados["ativos"],
        "clientes": [
            {
                "id": cliente["id"],
                "nome": cliente["nome"],
                "total_chamados": cliente["total_chamados"],
                "chamados_abertos": cliente["chamados_abertos"],
                "taxa_sla": cliente["taxa_sla"],
                "satisfacao": cliente["satisfacao"],
                "receita_estimada": cliente["receita_estimada"]
            }
            for cliente in dados["clientes"]
        ],
        "top_10_volume": dados["top_volume"],
        "top_10_receita": dados["top_receita"]
    }
    
    return formatar_resposta(relatorio, format)
```

### Service de Relatórios
```python
# app/services/relatorio_service.py
class RelatorioService(BaseService):
    
    async def relatorio_sla(self, **filtros) -> Dict:
        """Gerar dados para relatório de SLA"""
        query = select(
            Chamado.cliente_id,
            Cliente.nome.label('cliente_nome'),
            func.count(Chamado.id).label('total_chamados'),
            func.sum(
                case(
                    (Chamado.prazo_sla > Chamado.resolvido_em, 1),
                    else_=0
                )
            ).label('dentro_sla'),
            func.avg(
                extract('epoch', Chamado.resolvido_em - Chamado.criado_em) / 3600
            ).label('tempo_medio_horas')
        ).join(Cliente)
        
        # Aplicar filtros
        if filtros.get('cliente_id'):
            query = query.where(Chamado.cliente_id == filtros['cliente_id'])
        
        if filtros.get('data_inicio'):
            query = query.where(Chamado.criado_em >= filtros['data_inicio'])
        
        query = query.group_by(Chamado.cliente_id, Cliente.nome)
        
        result = await self.db.execute(query)
        dados = result.all()
        
        return {
            "periodo": filtros,
            "dados": [
                {
                    "cliente": row.cliente_nome,
                    "total_chamados": row.total_chamados,
                    "dentro_sla": row.dentro_sla,
                    "taxa_sla": (row.dentro_sla / row.total_chamados * 100) if row.total_chamados else 0,
                    "tempo_medio_horas": float(row.tempo_medio_horas or 0)
                }
                for row in dados
            ],
            "resumo": self._calcular_resumo_sla(dados)
        }
```

### Funções de Exportação
```python
async def exportar_csv(dados: Dict, nome_arquivo: str):
    """Exportar dados para CSV"""
    df = pd.DataFrame(dados['dados'])
    
    output = io.StringIO()
    df.to_csv(output, index=False)
    output.seek(0)
    
    return StreamingResponse(
        io.BytesIO(output.getvalue().encode()),
        media_type="text/csv",
        headers={
            "Content-Disposition": f"attachment; filename={nome_arquivo}.csv"
        }
    )

async def exportar_pdf(dados: Dict, titulo: str, usuario: Usuario):
    """Exportar dados para PDF"""
    from reportlab.lib import colors
    from reportlab.lib.pagesizes import letter, A4
    from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph
    from reportlab.lib.styles import getSampleStyleSheet
    
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A4)
    elements = []
    
    # Título
    styles = getSampleStyleSheet()
    elements.append(Paragraph(titulo, styles['Title']))
    elements.append(Paragraph(f"Gerado por: {usuario.nome_completo}", styles['Normal']))
    elements.append(Paragraph(f"Data: {datetime.now().strftime('%d/%m/%Y %H:%M')}", styles['Normal']))
    
    # Tabela de dados
    if 'dados' in dados:
        df = pd.DataFrame(dados['dados'])
        table_data = [df.columns.tolist()] + df.values.tolist()
        
        table = Table(table_data)
        table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 14),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
            ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
            ('GRID', (0, 0), (-1, -1), 1, colors.black)
        ]))
        
        elements.append(table)
    
    doc.build(elements)
    buffer.seek(0)
    
    return StreamingResponse(
        buffer,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f"attachment; filename={titulo.replace(' ', '_')}.pdf"
        }
    )

async def exportar_excel(dados: Dict, nome_arquivo: str):
    """Exportar dados para Excel"""
    with pd.ExcelWriter(io.BytesIO(), engine='xlsxwriter') as writer:
        # Aba principal
        df = pd.DataFrame(dados['dados'])
        df.to_excel(writer, sheet_name='Dados', index=False)
        
        # Aba de resumo se existir
        if 'resumo' in dados:
            df_resumo = pd.DataFrame([dados['resumo']])
            df_resumo.to_excel(writer, sheet_name='Resumo', index=False)
        
        # Formatar colunas
        workbook = writer.book
        worksheet = writer.sheets['Dados']
        
        # Auto-ajustar largura das colunas
        for i, col in enumerate(df.columns):
            column_len = max(df[col].astype(str).str.len().max(), len(col))
            worksheet.set_column(i, i, column_len + 2)
        
        writer.save()
        output = writer.buffer
        output.seek(0)
    
    return StreamingResponse(
        output,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={
            "Content-Disposition": f"attachment; filename={nome_arquivo}.xlsx"
        }
    )
```

## 🧪 Teste Após Cada Implementação

### IMPORTANTE: Seguir TEST-TEMPLATE.md - Testar cada relatório e formato
```bash
# 1. Teste relatório SLA em JSON
curl -X GET "http://localhost:8001/api/v1/relatorios/sla-compliance?data_inicio=2025-01-01&data_fim=2025-01-31&format=json" \
     -H "Authorization: Bearer $TOKEN"
# Esperar: 200 OK com dados JSON
# Se erro: PARAR e corrigir imediatamente!

# 2. Teste relatório SLA em CSV
curl -X GET "http://localhost:8001/api/v1/relatorios/sla-compliance?data_inicio=2025-01-01&data_fim=2025-01-31&format=csv" \
     -H "Authorization: Bearer $TOKEN" \
     --output relatorio_sla.csv
# Esperar: Download de arquivo CSV
# Se erro: Verificar pandas e exportação

# 3. Teste relatório SLA em PDF
curl -X GET "http://localhost:8001/api/v1/relatorios/sla-compliance?data_inicio=2025-01-01&data_fim=2025-01-31&format=pdf" \
     -H "Authorization: Bearer $TOKEN" \
     --output relatorio_sla.pdf
# Esperar: Download de arquivo PDF
# Se erro: Verificar reportlab

# 4. Teste relatório produtividade
curl -X GET "http://localhost:8001/api/v1/relatorios/produtividade?data_inicio=2025-01-01&data_fim=2025-01-31" \
     -H "Authorization: Bearer $TOKEN"
# Esperar: 200 OK ou 403 se não autorizado
# Se erro: Verificar permissões e queries

# 5. Teste relatório customizado
curl -X POST "http://localhost:8001/api/v1/relatorios/customizado" \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "entidade": "chamados",
       "campos": ["id", "titulo", "status", "prioridade"],
       "filtros": {"status": "aberto"},
       "formato": "json"
     }'
# Esperar: 200 OK com dados customizados
```

### Script Python de Teste Completo
```python
# test_relatorios.py
import requests
import os
import sys
from datetime import datetime, timedelta

BASE_URL = "http://localhost:8001/api/v1"

def test_relatorios():
    print("🧪 TESTANDO SISTEMA DE RELATÓRIOS")
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
    
    # Datas para teste
    data_fim = datetime.now()
    data_inicio = data_fim - timedelta(days=30)
    
    # 1. Testar relatório SLA - JSON
    print("\n1. Testando relatório SLA (JSON)...")
    params = {
        "data_inicio": data_inicio.isoformat(),
        "data_fim": data_fim.isoformat(),
        "format": "json"
    }
    resp = requests.get(f"{BASE_URL}/relatorios/sla-compliance", params=params, headers=headers)
    
    if resp.status_code != 200:
        print(f"❌ ERRO: {resp.status_code} - {resp.text}")
        print("⚠️  CORRIGIR ANTES DE PROSSEGUIR!")
        return False
    
    dados = resp.json()
    if "periodo" not in dados or "dados" not in dados:
        print("❌ Estrutura de dados incorreta")
        return False
    print("✅ Relatório SLA JSON OK")
    
    # 2. Testar exportação CSV
    print("\n2. Testando exportação CSV...")
    params["format"] = "csv"
    resp = requests.get(f"{BASE_URL}/relatorios/sla-compliance", params=params, headers=headers)
    
    if resp.status_code != 200:
        print(f"❌ ERRO no CSV: {resp.status_code}")
        return False
    
    if "text/csv" not in resp.headers.get("content-type", ""):
        print("❌ Tipo de conteúdo incorreto")
        return False
    
    # Salvar arquivo
    with open("test_relatorio.csv", "wb") as f:
        f.write(resp.content)
    
    if os.path.exists("test_relatorio.csv"):
        print("✅ CSV exportado com sucesso")
        os.remove("test_relatorio.csv")
    
    # 3. Testar exportação PDF
    print("\n3. Testando exportação PDF...")
    params["format"] = "pdf"
    resp = requests.get(f"{BASE_URL}/relatorios/sla-compliance", params=params, headers=headers)
    
    if resp.status_code != 200:
        print(f"❌ ERRO no PDF: {resp.status_code}")
        return False
    
    if "application/pdf" not in resp.headers.get("content-type", ""):
        print("❌ Tipo de conteúdo incorreto")
        return False
    
    # Verificar se é PDF válido
    if not resp.content.startswith(b"%PDF"):
        print("❌ Arquivo PDF inválido")
        return False
    print("✅ PDF exportado com sucesso")
    
    # 4. Testar exportação Excel
    print("\n4. Testando exportação Excel...")
    params["format"] = "excel"
    resp = requests.get(f"{BASE_URL}/relatorios/sla-compliance", params=params, headers=headers)
    
    if resp.status_code != 200:
        print(f"❌ ERRO no Excel: {resp.status_code}")
        return False
    
    if "spreadsheetml" not in resp.headers.get("content-type", ""):
        print("❌ Tipo de conteúdo incorreto")
        return False
    print("✅ Excel exportado com sucesso")
    
    # 5. Testar relatório de produtividade
    print("\n5. Testando relatório de produtividade...")
    params = {
        "data_inicio": data_inicio.isoformat(),
        "data_fim": data_fim.isoformat(),
        "format": "json"
    }
    resp = requests.get(f"{BASE_URL}/relatorios/produtividade", params=params, headers=headers)
    
    if resp.status_code not in [200, 403]:  # 403 é esperado se não for coordenador/diretor
        print(f"❌ ERRO: {resp.status_code}")
        return False
    
    if resp.status_code == 200:
        dados = resp.json()
        if "periodo" not in dados or "resumo" not in dados:
            print("❌ Estrutura incorreta")
            return False
        print("✅ Relatório produtividade OK")
    else:
        print("✅ Permissão negada corretamente (usuário sem acesso)")
    
    # 6. Testar relatório customizado
    print("\n6. Testando relatório customizado...")
    custom_data = {
        "entidade": "chamados",
        "campos": ["id", "titulo", "status", "prioridade", "criado_em"],
        "filtros": {"status": "aberto"},
        "ordenacao": {"campo": "criado_em", "direcao": "desc"},
        "formato": "json"
    }
    resp = requests.post(f"{BASE_URL}/relatorios/customizado", json=custom_data, headers=headers)
    
    if resp.status_code != 200:
        print(f"❌ ERRO: {resp.status_code}")
        return False
    print("✅ Relatório customizado OK")
    
    # 7. Testar relatório de chamados detalhado
    print("\n7. Testando relatório de chamados detalhado...")
    params = {
        "status": "aberto",
        "prioridade": "alta",
        "format": "json"
    }
    resp = requests.get(f"{BASE_URL}/relatorios/chamados-detalhado", params=params, headers=headers)
    
    if resp.status_code != 200:
        print(f"❌ ERRO: {resp.status_code}")
        return False
    print("✅ Relatório de chamados OK")
    
    # 8. Testar relatório de clientes
    print("\n8. Testando relatório de clientes...")
    resp = requests.get(f"{BASE_URL}/relatorios/clientes?format=json", headers=headers)
    
    if resp.status_code != 200:
        print(f"❌ ERRO: {resp.status_code}")
        return False
    
    dados = resp.json()
    if "total_clientes" not in dados or "clientes" not in dados:
        print("❌ Estrutura incorreta")
        return False
    print("✅ Relatório de clientes OK")
    
    print("\n" + "="*50)
    print("✅ TODOS OS TESTES DE RELATÓRIOS PASSARAM!")
    return True

# Executar teste
if not test_relatorios():
    print("\n⚠️  CORRIGIR OS ERROS ANTES DE PROSSEGUIR!")
    sys.exit(1)
```

### Teste de Performance
```python
# test_relatorio_performance.py
import time

def test_performance_relatorio():
    print("⏱️  Testando performance de relatórios grandes...")
    
    # Simular período grande (1 ano)
    data_fim = datetime.now()
    data_inicio = data_fim - timedelta(days=365)
    
    params = {
        "data_inicio": data_inicio.isoformat(),
        "data_fim": data_fim.isoformat(),
        "format": "json"
    }
    
    start = time.time()
    resp = requests.get(f"{BASE_URL}/relatorios/sla-compliance", params=params, headers=headers)
    elapsed = time.time() - start
    
    if elapsed > 5:
        print(f"⚠️  AVISO: Relatório demorou {elapsed:.2f}s (máximo recomendado: 5s)")
        print("   Considere adicionar cache ou paginação")
    else:
        print(f"✅ Performance OK: {elapsed:.2f}s")
    
    return resp.status_code == 200

test_performance_relatorio()
```

### Se algum teste falhar: PARAR e corrigir antes de continuar!

## ✅ Checklist de Validação
- [ ] Todos os endpoints de relatório implementados
- [ ] Exportação CSV funcionando
- [ ] Exportação PDF funcionando
- [ ] Exportação Excel funcionando
- [ ] Filtros e agregações corretos
- [ ] Permissões aplicadas
- [ ] Performance otimizada para grandes volumes
- [ ] Templates de relatórios criados

## 📊 Resultado Esperado
- Sistema completo de relatórios
- Múltiplos formatos de exportação
- Relatórios customizáveis
- Performance adequada

## 📝 Log de Execução
[A ser preenchido após execução]

---
**Status**: PENDENTE
**Prioridade**: MÉDIA
**Estimativa**: 2 horas