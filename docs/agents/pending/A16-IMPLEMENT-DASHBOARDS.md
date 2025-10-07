# A16 - Implementar Dashboards

## 📋 Objetivo
Implementar todos os dashboards do sistema com métricas e visualizações específicas por tipo de usuário.

## 🎯 Tarefas
1. Implementar GET `/api/v1/dashboard/executive` - Dashboard executivo
2. Implementar GET `/api/v1/dashboard/coordination` - Dashboard coordenação
3. Implementar GET `/api/v1/dashboard/support` - Dashboard suporte
4. Implementar GET `/api/v1/dashboard/technical` - Dashboard técnico
5. Criar agregações e métricas necessárias
6. Implementar cache para performance

## 📚 Referências
- docs/agents/shared/CODE-STANDARDS.md
- docs/agents/shared/API-REFERENCE.md (seção "Dashboards e Relatórios")
- docs/agents/shared/TEST-TEMPLATE.md (IMPORTANTE: Testar cada dashboard)
- app/services/dashboard_service.py (já criado)

## 🔧 Implementação

### Router de Dashboards
```python
# app/api/v1/endpoints/dashboards.py
router = APIRouter(prefix="/dashboard", tags=["dashboards"])

@router.get("/executive", response_model=DashboardExecutivo)
async def dashboard_executivo(
    periodo: str = Query("30d", regex="^(7d|30d|90d|1y)$"),
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Dashboard executivo - Visão geral do negócio"""
    if current_user.tipo_usuario != TipoUsuario.DIRECTOR:
        raise HTTPException(403, "Dashboard exclusivo da diretoria")
    
    service = DashboardService(db)
    cache_key = f"dashboard:executive:{periodo}"
    
    # Verificar cache
    cached = await redis_client.get(cache_key)
    if cached:
        return json.loads(cached)
    
    # Calcular métricas
    metricas = {
        # KPIs Principais
        "kpis": {
            "total_chamados": await service.total_chamados(periodo),
            "sla_compliance": await service.taxa_sla(periodo),
            "satisfacao_cliente": await service.satisfacao_media(periodo),
            "tempo_medio_resolucao": await service.tempo_medio_resolucao(periodo),
            "receita_mensal": await service.receita_estimada(periodo),
            "produtividade_equipe": await service.produtividade_geral(periodo)
        },
        
        # Tendências
        "tendencias": {
            "chamados_por_mes": await service.evolucao_chamados_mensal(periodo),
            "sla_por_mes": await service.evolucao_sla_mensal(periodo),
            "receita_por_cliente": await service.receita_por_cliente(periodo)
        },
        
        # Distribuições
        "distribuicoes": {
            "por_status": await service.chamados_por_status(),
            "por_prioridade": await service.chamados_por_prioridade(),
            "por_categoria": await service.chamados_por_categoria(),
            "por_cliente": await service.top_clientes(10)
        },
        
        # Performance
        "performance": {
            "top_desenvolvedores": await service.top_desenvolvedores(5),
            "equipes_produtividade": await service.produtividade_equipes(),
            "tempo_resposta_medio": await service.tempo_resposta_por_prioridade()
        },
        
        # Alertas
        "alertas": {
            "sla_vencendo": await service.chamados_sla_critico(),
            "sobrecarga_equipe": await service.equipes_sobrecarregadas(),
            "clientes_insatisfeitos": await service.clientes_risco()
        }
    }
    
    # Cachear por 5 minutos
    await redis_client.setex(cache_key, 300, json.dumps(metricas))
    
    return metricas

@router.get("/coordination", response_model=DashboardCoordenacao)
async def dashboard_coordenacao(
    periodo: str = Query("7d"),
    equipe_id: Optional[UUID] = None,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Dashboard de coordenação - Gestão de equipe"""
    if current_user.tipo_usuario not in [
        TipoUsuario.DIRECTOR,
        TipoUsuario.SUPPORT_COORDINATOR
    ]:
        raise HTTPException(403, "Sem permissão para este dashboard")
    
    service = DashboardService(db)
    
    # Se coordenador, filtrar pela equipe dele
    if current_user.tipo_usuario == TipoUsuario.SUPPORT_COORDINATOR:
        equipe_id = current_user.equipe_id
    
    return {
        # Visão da Equipe
        "equipe": {
            "membros_ativos": await service.membros_equipe_ativos(equipe_id),
            "carga_trabalho": await service.carga_trabalho_equipe(equipe_id),
            "chamados_abertos": await service.chamados_equipe(equipe_id, "aberto"),
            "chamados_em_andamento": await service.chamados_equipe(equipe_id, "em_andamento")
        },
        
        # Métricas de Performance
        "performance": {
            "tempo_medio_resposta": await service.tempo_resposta_equipe(equipe_id, periodo),
            "tempo_medio_resolucao": await service.tempo_resolucao_equipe(equipe_id, periodo),
            "taxa_sla": await service.taxa_sla_equipe(equipe_id, periodo),
            "chamados_resolvidos": await service.chamados_resolvidos_equipe(equipe_id, periodo)
        },
        
        # Distribuição de Trabalho
        "distribuicao": {
            "por_membro": await service.chamados_por_membro(equipe_id),
            "por_prioridade": await service.chamados_equipe_por_prioridade(equipe_id),
            "por_cliente": await service.chamados_equipe_por_cliente(equipe_id)
        },
        
        # Produtividade
        "produtividade": {
            "horas_trabalhadas": await service.horas_equipe(equipe_id, periodo),
            "horas_faturaveis": await service.horas_faturaveis_equipe(equipe_id, periodo),
            "tickets_por_pessoa": await service.media_tickets_pessoa(equipe_id, periodo)
        },
        
        # Alertas da Equipe
        "alertas": {
            "sla_risco": await service.chamados_sla_risco_equipe(equipe_id),
            "membros_sobrecarregados": await service.membros_sobrecarregados(equipe_id),
            "escalacoes_pendentes": await service.escalacoes_pendentes(equipe_id)
        }
    }

@router.get("/support", response_model=DashboardSuporte)
async def dashboard_suporte(
    periodo: str = Query("7d"),
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Dashboard de suporte - Visão individual"""
    service = DashboardService(db)
    
    return {
        # Meus Chamados
        "meus_chamados": {
            "total": await service.total_chamados_usuario(current_user.id),
            "abertos": await service.chamados_usuario_por_status(current_user.id, "aberto"),
            "em_andamento": await service.chamados_usuario_por_status(current_user.id, "em_andamento"),
            "aguardando_cliente": await service.chamados_usuario_por_status(current_user.id, "aguardando_cliente"),
            "resolvidos_hoje": await service.chamados_resolvidos_hoje(current_user.id)
        },
        
        # Prioridades
        "prioridades": {
            "criticos": await service.chamados_criticos_usuario(current_user.id),
            "alta": await service.chamados_alta_prioridade_usuario(current_user.id),
            "vencendo_sla": await service.chamados_sla_vencendo_usuario(current_user.id)
        },
        
        # Minha Performance
        "minha_performance": {
            "tempo_medio_resposta": await service.meu_tempo_resposta(current_user.id, periodo),
            "tempo_medio_resolucao": await service.meu_tempo_resolucao(current_user.id, periodo),
            "taxa_sla": await service.minha_taxa_sla(current_user.id, periodo),
            "satisfacao_media": await service.minha_satisfacao_media(current_user.id, periodo)
        },
        
        # Timesheet
        "timesheet": {
            "horas_hoje": await service.horas_trabalhadas_hoje(current_user.id),
            "horas_semana": await service.horas_trabalhadas_semana(current_user.id),
            "horas_mes": await service.horas_trabalhadas_mes(current_user.id)
        },
        
        # Próximas Ações
        "proximas_acoes": await service.proximas_acoes_usuario(current_user.id)
    }

@router.get("/technical", response_model=DashboardTecnico)
async def dashboard_tecnico(
    periodo: str = Query("30d"),
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Dashboard técnico - Métricas de desenvolvimento"""
    if current_user.tipo_usuario not in [
        TipoUsuario.DIRECTOR,
        TipoUsuario.SENIOR_DEVELOPER,
        TipoUsuario.JUNIOR_DEVELOPER
    ]:
        raise HTTPException(403, "Dashboard exclusivo para desenvolvedores")
    
    service = DashboardService(db)
    
    return {
        # Visão Técnica
        "metricas_tecnicas": {
            "bugs_reportados": await service.bugs_reportados(periodo),
            "bugs_resolvidos": await service.bugs_resolvidos(periodo),
            "features_entregues": await service.features_entregues(periodo),
            "debito_tecnico": await service.debito_tecnico_estimado()
        },
        
        # Por Sistema
        "por_sistema": {
            "distribuicao_chamados": await service.chamados_por_sistema(),
            "sistemas_criticos": await service.sistemas_com_mais_bugs(),
            "tempo_resolucao_por_sistema": await service.tempo_resolucao_por_sistema()
        },
        
        # Qualidade de Código
        "qualidade": {
            "taxa_retrabalho": await service.taxa_retrabalho(periodo),
            "bugs_por_feature": await service.proporcao_bugs_features(periodo),
            "cobertura_testes": await service.cobertura_testes_estimada()
        },
        
        # Performance de Deploy
        "deploys": {
            "total_deploys": await service.total_deploys(periodo),
            "taxa_sucesso": await service.taxa_sucesso_deploy(periodo),
            "tempo_medio_deploy": await service.tempo_medio_deploy()
        },
        
        # Backlog Técnico
        "backlog": {
            "total_pendente": await service.backlog_tecnico_total(),
            "por_prioridade": await service.backlog_por_prioridade(),
            "estimativa_conclusao": await service.estimativa_conclusao_backlog()
        }
    }

@router.get("/geral", response_model=DashboardGeral)
async def dashboard_geral(
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Dashboard geral - Visão resumida para todos"""
    service = DashboardService(db)
    
    # Dashboard básico acessível a todos
    return await service.obter_resumo_dashboard(current_user)
```

### Service Methods (adicionar ao DashboardService)
```python
# Métodos específicos para cada métrica
async def taxa_sla(self, periodo: str) -> float:
    """Calcular taxa de cumprimento de SLA"""
    # Implementação...
    
async def satisfacao_media(self, periodo: str) -> float:
    """Calcular satisfação média dos clientes"""
    # Implementação...

async def receita_estimada(self, periodo: str) -> float:
    """Calcular receita estimada baseada em horas faturáveis"""
    # Implementação...

# ... outros métodos
```

## 🧪 Teste Após Cada Implementação

### IMPORTANTE: Seguir TEST-TEMPLATE.md - Testar IMEDIATAMENTE cada dashboard
```bash
# 1. Teste dashboard executivo
curl -X GET "http://localhost:8001/api/v1/dashboard/executive?periodo=30d" \
     -H "Authorization: Bearer $TOKEN"
# Esperar: 200 OK com métricas
# Se erro: PARAR e corrigir antes de prosseguir!

# 2. Teste dashboard coordenação
curl -X GET "http://localhost:8001/api/v1/dashboard/coordination?periodo=7d" \
     -H "Authorization: Bearer $TOKEN"
# Esperar: 200 OK
# Se 403: Verificar permissões
# Se 500: Verificar queries e agregações

# 3. Teste dashboard suporte
curl -X GET "http://localhost:8001/api/v1/dashboard/support?periodo=7d" \
     -H "Authorization: Bearer $TOKEN"
# Esperar: 200 OK com dados pessoais
# Se erro: Verificar filtros por usuário

# 4. Teste dashboard técnico
curl -X GET "http://localhost:8001/api/v1/dashboard/technical?periodo=30d" \
     -H "Authorization: Bearer $TOKEN"
# Esperar: 200 OK
# Se erro: Verificar métricas técnicas

# 5. Teste dashboard geral
curl -X GET "http://localhost:8001/api/v1/dashboard/geral" \
     -H "Authorization: Bearer $TOKEN"
# Esperar: 200 OK para qualquer usuário
```

### Script Python de Teste Completo
```python
# test_dashboards.py
import requests
import json
import sys

BASE_URL = "http://localhost:8001/api/v1"

def test_dashboards():
    print("🧪 TESTANDO DASHBOARDS")
    print("="*50)
    
    # Login com diferentes perfis
    usuarios = [
        {"email": "diretor@empresa.com", "password": "senha123", "tipo": "director"},
        {"email": "coord@empresa.com", "password": "senha123", "tipo": "coordinator"},
        {"email": "support@empresa.com", "password": "senha123", "tipo": "support"}
    ]
    
    for user in usuarios:
        print(f"\n📊 Testando com perfil: {user['tipo']}")
        
        # Login
        resp = requests.post(f"{BASE_URL}/auth/login", json={
            "email": user["email"],
            "password": user["password"]
        })
        
        if resp.status_code != 200:
            print(f"❌ ERRO no login: {resp.status_code}")
            continue
        
        token = resp.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # Testar dashboards baseado no perfil
        if user["tipo"] == "director":
            # Dashboard executivo
            print("  1. Dashboard executivo...")
            resp = requests.get(f"{BASE_URL}/dashboard/executive?periodo=30d", headers=headers)
            if resp.status_code != 200:
                print(f"  ❌ ERRO: {resp.status_code} - {resp.text}")
                print("  ⚠️  CORRIGIR ANTES DE PROSSEGUIR!")
                return False
            
            data = resp.json()
            if "kpis" not in data or "tendencias" not in data:
                print("  ❌ Estrutura de dados incorreta")
                return False
            print("  ✅ Dashboard executivo OK")
        
        if user["tipo"] in ["director", "coordinator"]:
            # Dashboard coordenação
            print("  2. Dashboard coordenação...")
            resp = requests.get(f"{BASE_URL}/dashboard/coordination?periodo=7d", headers=headers)
            if resp.status_code != 200:
                print(f"  ❌ ERRO: {resp.status_code}")
                return False
            
            data = resp.json()
            if "equipe" not in data or "performance" not in data:
                print("  ❌ Estrutura incorreta")
                return False
            print("  ✅ Dashboard coordenação OK")
        
        # Dashboard suporte (todos têm acesso)
        print("  3. Dashboard suporte...")
        resp = requests.get(f"{BASE_URL}/dashboard/support?periodo=7d", headers=headers)
        if resp.status_code != 200:
            print(f"  ❌ ERRO: {resp.status_code}")
            return False
        
        data = resp.json()
        if "meus_chamados" not in data:
            print("  ❌ Estrutura incorreta")
            return False
        print("  ✅ Dashboard suporte OK")
        
        # Dashboard geral (todos têm acesso)
        print("  4. Dashboard geral...")
        resp = requests.get(f"{BASE_URL}/dashboard/geral", headers=headers)
        if resp.status_code != 200:
            print(f"  ❌ ERRO: {resp.status_code}")
            return False
        print("  ✅ Dashboard geral OK")
    
    print("\n" + "="*50)
    print("✅ TODOS OS DASHBOARDS TESTADOS COM SUCESSO!")
    return True

# Executar teste
if not test_dashboards():
    print("\n⚠️  CORRIGIR OS ERROS ANTES DE PROSSEGUIR!")
    sys.exit(1)
```

### Verificação de Cache Redis
```bash
# Testar se cache está funcionando
# 1. Primeira chamada (sem cache)
time curl -X GET "http://localhost:8001/api/v1/dashboard/executive?periodo=30d" \
     -H "Authorization: Bearer $TOKEN"
# Anotar tempo (ex: 2.5s)

# 2. Segunda chamada (com cache)
time curl -X GET "http://localhost:8001/api/v1/dashboard/executive?periodo=30d" \
     -H "Authorization: Bearer $TOKEN"
# Tempo deve ser < 100ms se cache funcionando

# Verificar chaves no Redis
redis-cli KEYS "dashboard:*"
# Deve mostrar chaves como: dashboard:executive:30d
```

### Se algum teste falhar: PARAR e corrigir imediatamente!

## ✅ Checklist de Validação
- [ ] Todos os 4 dashboards principais implementados
- [ ] Métricas calculadas corretamente
- [ ] Cache Redis configurado
- [ ] Permissões por tipo de usuário
- [ ] Performance otimizada (queries agregadas)
- [ ] Filtros por período funcionando
- [ ] Dados em tempo real quando necessário
- [ ] Testes de carga

## 📊 Resultado Esperado
- Dashboards específicos por perfil
- Métricas em tempo real
- Performance com cache
- Visualizações adequadas para cada usuário

## 📝 Log de Execução
[A ser preenchido após execução]

---
**Status**: PENDENTE
**Prioridade**: ALTA
**Estimativa**: 2 horas