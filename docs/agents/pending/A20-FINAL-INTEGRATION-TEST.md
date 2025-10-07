# A20 - Teste Final de Integração

## 📋 Objetivo
Executar teste completo de integração garantindo 100% de funcionamento de todos os endpoints.

## 🎯 Tarefas
1. Executar todos os testes de endpoints
2. Validar todas as integrações
3. Testar fluxos completos end-to-end
4. Verificar performance
5. Gerar relatório final de qualidade
6. Atualizar documentação

## 📚 Referências
- docs/agents/continuous/QA-REVIEW.md
- docs/agents/shared/CODE-STANDARDS.md
- docs/agents/shared/API-REFERENCE.md
- docs/agents/shared/TEST-TEMPLATE.md (IMPORTANTE: Usar princípios de teste)
- scripts/test_all_endpoints.py

## 🔧 Testes a Executar

### 1. Teste de Todos os Endpoints
```python
# scripts/test_final.py
endpoints_para_testar = [
    # Authentication (4 endpoints)
    ("POST", "/api/v1/auth/login"),
    ("GET", "/api/v1/auth/me"),
    ("POST", "/api/v1/auth/refresh"),
    ("POST", "/api/v1/auth/logout"),
    
    # Usuários (7 endpoints)
    ("GET", "/api/v1/usuarios"),
    ("POST", "/api/v1/usuarios"),
    ("GET", "/api/v1/usuarios/me"),
    ("GET", "/api/v1/usuarios/{id}"),
    ("PUT", "/api/v1/usuarios/{id}"),
    ("DELETE", "/api/v1/usuarios/{id}"),
    ("POST", "/api/v1/usuarios/{id}/reset-password"),
    
    # Equipes (4 endpoints)
    ("GET", "/api/v1/equipes"),
    ("POST", "/api/v1/equipes"),
    ("GET", "/api/v1/equipes/{id}/membros"),
    ("POST", "/api/v1/equipes/{id}/membros"),
    
    # Clientes (4+ endpoints)
    ("GET", "/api/v1/clientes"),
    ("POST", "/api/v1/clientes"),
    ("GET", "/api/v1/clientes/{id}"),
    ("PUT", "/api/v1/clientes/{id}"),
    
    # Filiais e Sistemas
    ("GET", "/api/v1/filiais"),
    ("POST", "/api/v1/clientes/{id}/filiais"),
    ("GET", "/api/v1/sistemas"),
    ("POST", "/api/v1/clientes/{id}/sistemas"),
    
    # Chamados (8+ endpoints)
    ("GET", "/api/v1/chamados"),
    ("POST", "/api/v1/chamados"),
    ("GET", "/api/v1/chamados/stats"),
    ("GET", "/api/v1/chamados/{id}"),
    ("PUT", "/api/v1/chamados/{id}"),
    ("POST", "/api/v1/chamados/{id}/atribuir"),
    ("POST", "/api/v1/chamados/{id}/escalar"),
    ("POST", "/api/v1/chamados/{id}/status"),
    
    # Comentários e Anexos (5 endpoints)
    ("GET", "/api/v1/chamados/{id}/comentarios"),
    ("POST", "/api/v1/chamados/{id}/comentarios"),
    ("GET", "/api/v1/chamados/{id}/anexos"),
    ("POST", "/api/v1/chamados/{id}/anexos"),
    ("GET", "/api/v1/anexos/{id}/download"),
    
    # Tempo (4 endpoints)
    ("GET", "/api/v1/chamados/{id}/tempo"),
    ("POST", "/api/v1/chamados/{id}/tempo"),
    ("GET", "/api/v1/tempo/meu-timesheet"),
    ("GET", "/api/v1/tempo/registros"),
    
    # Dashboards (5 endpoints)
    ("GET", "/api/v1/dashboard/executive"),
    ("GET", "/api/v1/dashboard/coordination"),
    ("GET", "/api/v1/dashboard/support"),
    ("GET", "/api/v1/dashboard/technical"),
    ("GET", "/api/v1/dashboard/geral"),
    
    # Relatórios (5 endpoints)
    ("GET", "/api/v1/relatorios/sla-compliance"),
    ("GET", "/api/v1/relatorios/produtividade"),
    ("GET", "/api/v1/relatorios/chamados-detalhado"),
    ("POST", "/api/v1/relatorios/customizado"),
    ("GET", "/api/v1/relatorios/clientes"),
    
    # Métricas (3 endpoints)
    ("GET", "/api/v1/metricas/tempo-resposta"),
    ("GET", "/api/v1/metricas/satisfacao-cliente"),
    ("GET", "/api/v1/metricas/carga-trabalho"),
    
    # Configurações (6 endpoints)
    ("GET", "/api/v1/configuracoes"),
    ("GET", "/api/v1/configuracoes/sla-rules"),
    ("POST", "/api/v1/configuracoes/sla-rules"),
    ("GET", "/api/v1/configuracoes/categorias"),
    ("GET", "/api/v1/configuracoes/prioridades"),
    ("GET", "/api/v1/configuracoes/permissoes"),
    
    # Notificações (3 endpoints)
    ("GET", "/api/v1/notificacoes"),
    ("PUT", "/api/v1/notificacoes/{id}/marcar-lida"),
    ("POST", "/api/v1/notificacoes/marcar-todas-lidas"),
    
    # SLA (4 endpoints)
    ("GET", "/api/v1/sla/status"),
    ("GET", "/api/v1/sla/vencendo"),
    ("GET", "/api/v1/sla/vencidos"),
    ("GET", "/api/v1/sla/metricas"),
    
    # Busca e Options (5 endpoints)
    ("GET", "/api/v1/search"),
    ("GET", "/api/v1/options/clientes"),
    ("GET", "/api/v1/options/usuarios"),
    ("GET", "/api/v1/options/sistemas"),
    ("GET", "/api/v1/options/equipes"),
    
    # Sistema (3 endpoints)
    ("GET", "/"),
    ("GET", "/health"),
    ("GET", "/info")
]
# Total: ~80+ endpoints
```

### 2. Testes de Fluxo Completo
```python
async def teste_fluxo_completo():
    """Teste end-to-end do fluxo de chamado"""
    
    # 1. Login
    token = await login("lee@empresa.com", "admin123")
    
    # 2. Criar cliente
    cliente = await criar_cliente({
        "nome": "Cliente Teste",
        "cnpj": "12.345.678/0001-90"
    })
    
    # 3. Criar sistema do cliente
    sistema = await criar_sistema(cliente.id, {
        "nome": "Sistema Teste",
        "versao": "1.0.0"
    })
    
    # 4. Criar chamado
    chamado = await criar_chamado({
        "titulo": "Bug teste",
        "cliente_id": cliente.id,
        "sistema_id": sistema.id,
        "prioridade": "alta"
    })
    
    # 5. Atribuir chamado
    await atribuir_chamado(chamado.id, usuario_id)
    
    # 6. Adicionar comentário
    await adicionar_comentario(chamado.id, "Analisando o problema")
    
    # 7. Registrar tempo
    await registrar_tempo(chamado.id, {
        "inicio": "2025-01-01T09:00:00",
        "fim": "2025-01-01T12:00:00",
        "descricao": "Análise e correção"
    })
    
    # 8. Alterar status
    await alterar_status(chamado.id, "resolvido")
    
    # 9. Verificar notificações
    notificacoes = await listar_notificacoes()
    assert len(notificacoes) > 0
    
    # 10. Gerar relatório
    relatorio = await gerar_relatorio_sla(cliente.id)
    assert relatorio["taxa_sla"] == 100
```

### 3. Testes de Performance
```bash
# Teste de carga
ab -n 1000 -c 10 -H "Authorization: Bearer $TOKEN" http://localhost:8001/api/v1/chamados

# Métricas esperadas:
# - P95 < 200ms
# - P99 < 500ms
# - Taxa de erro < 1%
```

### 4. Testes de Permissão
```python
async def teste_permissoes():
    """Testar matriz de permissões"""
    
    usuarios_teste = [
        ("director@empresa.com", "director", 200),      # Acesso total
        ("coord@empresa.com", "coordinator", 200),       # Acesso equipe
        ("analyst@empresa.com", "analyst", 403),         # Sem permissão
    ]
    
    for email, role, expected in usuarios_teste:
        token = await login(email, "senha123")
        response = await get("/api/v1/configuracoes", token)
        assert response.status_code == expected
```

## 🧪 Execução dos Testes

### IMPORTANTE: Seguir TEST-TEMPLATE.md - Executar TODOS os testes sistematicamente

### Script Principal de Teste
```python
# test_final_integration.py
import requests
import json
import sys
import time
from datetime import datetime
from typing import Dict, List, Tuple

BASE_URL = "http://localhost:8001/api/v1"

class IntegrationTester:
    def __init__(self):
        self.total_tests = 0
        self.passed_tests = 0
        self.failed_tests = 0
        self.errors = []
        self.tokens = {}
        
    def log_result(self, test_name: str, success: bool, error: str = None):
        self.total_tests += 1
        if success:
            self.passed_tests += 1
            print(f"✅ {test_name}")
        else:
            self.failed_tests += 1
            print(f"❌ {test_name}: {error}")
            self.errors.append(f"{test_name}: {error}")
    
    async def test_authentication(self):
        print("\n🔑 TESTANDO AUTENTICAÇÃO")
        print("-" * 40)
        
        # Login com diferentes perfis
        users = [
            {"email": "diretor@empresa.com", "password": "senha123", "role": "director"},
            {"email": "coord@empresa.com", "password": "senha123", "role": "coordinator"},
            {"email": "support@empresa.com", "password": "senha123", "role": "support"}
        ]
        
        for user in users:
            try:
                resp = requests.post(f"{BASE_URL}/auth/login", json={
                    "email": user["email"],
                    "password": user["password"]
                })
                
                if resp.status_code == 200:
                    token = resp.json()["access_token"]
                    self.tokens[user["role"]] = token
                    self.log_result(f"Login {user['role']}", True)
                else:
                    self.log_result(f"Login {user['role']}", False, f"Status {resp.status_code}")
            except Exception as e:
                self.log_result(f"Login {user['role']}", False, str(e))
    
    async def test_all_endpoints(self):
        print("\n🚀 TESTANDO TODOS OS ENDPOINTS")
        print("-" * 40)
        
        # Usar token de diretor para máximo acesso
        headers = {"Authorization": f"Bearer {self.tokens.get('director', '')}"}
        
        endpoints = [
            # Básicos
            ("GET", "/", 200),
            ("GET", "/health", 200),
            ("GET", "/info", 200),
            
            # Auth
            ("GET", "/auth/me", 200),
            
            # Usuários
            ("GET", "/usuarios", 200),
            ("GET", "/usuarios/me", 200),
            
            # Equipes
            ("GET", "/equipes", 200),
            
            # Clientes
            ("GET", "/clientes", 200),
            ("GET", "/filiais", 200),
            ("GET", "/sistemas", 200),
            
            # Chamados
            ("GET", "/chamados", 200),
            ("GET", "/chamados/stats", 200),
            
            # Dashboards
            ("GET", "/dashboard/executive", 200),
            ("GET", "/dashboard/geral", 200),
            
            # Configurações
            ("GET", "/configuracoes", 200),
            ("GET", "/configuracoes/categorias", 200),
            ("GET", "/configuracoes/prioridades", 200),
            
            # Options
            ("GET", "/options/clientes", 200),
            ("GET", "/options/usuarios", 200),
            
            # Busca
            ("GET", "/search?q=teste", 200),
        ]
        
        for method, endpoint, expected in endpoints:
            try:
                start_time = time.time()
                
                if method == "GET":
                    resp = requests.get(f"{BASE_URL}{endpoint}", headers=headers)
                elif method == "POST":
                    resp = requests.post(f"{BASE_URL}{endpoint}", headers=headers, json={})
                
                elapsed = (time.time() - start_time) * 1000  # ms
                
                if resp.status_code == expected:
                    self.log_result(f"{method} {endpoint} ({elapsed:.0f}ms)", True)
                else:
                    self.log_result(
                        f"{method} {endpoint}", 
                        False, 
                        f"Expected {expected}, got {resp.status_code}"
                    )
            except Exception as e:
                self.log_result(f"{method} {endpoint}", False, str(e))
    
    async def test_crud_operations(self):
        print("\n📝 TESTANDO OPERAÇÕES CRUD")
        print("-" * 40)
        
        headers = {"Authorization": f"Bearer {self.tokens.get('director', '')}"}
        
        # Teste CRUD de cliente
        try:
            # Create
            cliente_data = {
                "nome": "Cliente Teste Final",
                "cnpj": "12.345.678/0001-99",
                "email_contato": "teste@cliente.com"
            }
            
            resp = requests.post(f"{BASE_URL}/clientes", json=cliente_data, headers=headers)
            if resp.status_code == 201:
                cliente_id = resp.json()["id"]
                self.log_result("CRUD Cliente - Create", True)
                
                # Read
                resp = requests.get(f"{BASE_URL}/clientes/{cliente_id}", headers=headers)
                if resp.status_code == 200:
                    self.log_result("CRUD Cliente - Read", True)
                else:
                    self.log_result("CRUD Cliente - Read", False, f"Status {resp.status_code}")
                
                # Update
                update_data = {"nome": "Cliente Teste Atualizado"}
                resp = requests.put(f"{BASE_URL}/clientes/{cliente_id}", json=update_data, headers=headers)
                if resp.status_code == 200:
                    self.log_result("CRUD Cliente - Update", True)
                else:
                    self.log_result("CRUD Cliente - Update", False, f"Status {resp.status_code}")
            else:
                self.log_result("CRUD Cliente - Create", False, f"Status {resp.status_code}")
        except Exception as e:
            self.log_result("CRUD Cliente", False, str(e))
    
    async def test_permissions(self):
        print("\n🔐 TESTANDO PERMISSÕES")
        print("-" * 40)
        
        # Testar acesso de support analyst a endpoints restritos
        support_headers = {"Authorization": f"Bearer {self.tokens.get('support', '')}"}
        
        restricted_endpoints = [
            ("/configuracoes/permissoes", 403),  # Apenas diretor
            ("/dashboard/executive", 403),       # Apenas diretor
            ("/relatorios/produtividade", 403),  # Diretor/Coord
        ]
        
        for endpoint, expected in restricted_endpoints:
            try:
                resp = requests.get(f"{BASE_URL}{endpoint}", headers=support_headers)
                if resp.status_code == expected:
                    self.log_result(f"Permissão {endpoint}", True)
                else:
                    self.log_result(
                        f"Permissão {endpoint}", 
                        False, 
                        f"Expected {expected}, got {resp.status_code}"
                    )
            except Exception as e:
                self.log_result(f"Permissão {endpoint}", False, str(e))
    
    async def generate_final_report(self):
        print("\n" + "=" * 60)
        print("📊 RELATÓRIO FINAL DE INTEGRAÇÃO")
        print("=" * 60)
        
        success_rate = (self.passed_tests / self.total_tests * 100) if self.total_tests > 0 else 0
        
        print(f"Total de Testes:        {self.total_tests}")
        print(f"Testes Aprovados:       {self.passed_tests}")
        print(f"Testes Falharam:        {self.failed_tests}")
        print(f"Taxa de Sucesso:        {success_rate:.1f}%")
        print(f"Data/Hora:              {datetime.now().strftime('%d/%m/%Y %H:%M:%S')}")
        
        if success_rate >= 95:
            print("\n✅ STATUS: APROVADO PARA PRODUÇÃO")
        elif success_rate >= 80:
            print("\n⚠️  STATUS: REQUER CORREÇÕES MENORES")
        else:
            print("\n❌ STATUS: REQUER CORREÇÕES MAIORES")
        
        if self.errors:
            print("\n🚨 ERROS ENCONTRADOS:")
            for error in self.errors:
                print(f"   - {error}")
        
        return success_rate >= 95

async def main():
    tester = IntegrationTester()
    
    print("🧪 INICIANDO TESTE FINAL DE INTEGRAÇÃO")
    print("=" * 60)
    
    await tester.test_authentication()
    await tester.test_all_endpoints()
    await tester.test_crud_operations()
    await tester.test_permissions()
    
    success = await tester.generate_final_report()
    
    if not success:
        print("\n⚠️  TESTE FALHOU - CORRIGIR ANTES DE PROSSEGUIR!")
        sys.exit(1)
    else:
        print("\n✅ TODOS OS TESTES PASSARAM - SISTEMA PRONTO!")

if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
```

### Como Executar o Teste Final
```bash
# 1. Certificar que o servidor está rodando
echo "Verificando se servidor está ativo..."
curl -f http://localhost:8001/health || {
    echo "❌ Servidor não está rodando!"
    echo "Execute: make dev"
    exit 1
}

# 2. Executar teste de integração
echo "Executando teste final..."
python test_final_integration.py

# 3. Se todos os testes passarem:
echo "✅ SISTEMA VALIDADO E PRONTO PARA PRODUÇÃO!"
```

### Se algum teste falhar: PARAR tudo e corrigir!

## ✅ Checklist de Validação Final

### Funcionalidade
- [ ] Todos os 80+ endpoints respondendo corretamente
- [ ] Zero erros 500
- [ ] Zero erros 422 (conflitos de rota)
- [ ] Todos os CRUDs completos
- [ ] Notificações funcionando
- [ ] Upload/download de arquivos OK

### Performance
- [ ] Tempo de resposta P95 < 200ms
- [ ] Tempo de resposta P99 < 500ms
- [ ] Suporta 100 requisições simultâneas
- [ ] Cache Redis funcionando

### Segurança
- [ ] Autenticação JWT funcionando
- [ ] Permissões aplicadas corretamente
- [ ] Validações de entrada funcionando
- [ ] Sem exposição de dados sensíveis

### Qualidade
- [ ] Cobertura de testes > 80%
- [ ] Código seguindo padrões
- [ ] Documentação OpenAPI completa
- [ ] Logs estruturados

## 📊 Relatório Final Esperado

```
╔════════════════════════════════════════╗
║    RELATÓRIO FINAL - API v1.0         ║
╠════════════════════════════════════════╣
║ Total de Endpoints:        80+         ║
║ Endpoints Funcionando:     80 (100%)   ║
║ Taxa de Sucesso:           100%        ║
║                                        ║
║ Erros Encontrados:                    ║
║ - 500 (Internal):          0           ║
║ - 422 (Validation):        0           ║
║ - 404 (Not Found):         0           ║
║ - 403 (Forbidden):         Esperados   ║
║ - 401 (Unauthorized):      Esperados   ║
║                                        ║
║ Performance:                           ║
║ - P50:                     45ms        ║
║ - P95:                     180ms       ║
║ - P99:                     450ms       ║
║                                        ║
║ Cobertura de Testes:       85%         ║
║ Complexidade Média:        3.2         ║
║                                        ║
║ Status: ✅ PRONTO PARA PRODUÇÃO      ║
╚════════════════════════════════════════╝

Assinatura: _________________________
Data: 02/10/2025
Responsável: Sistema QA Automatizado
```

## 📝 Log de Execução
[A ser preenchido após execução]

---
**Status**: PENDENTE
**Prioridade**: CRÍTICA
**Estimativa**: 2 horas
**Pré-requisito**: Todos os agentes A11-A19 executados