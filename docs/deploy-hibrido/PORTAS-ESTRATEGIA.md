# 🚢 Estratégia de Portas - Projeto Suporte

## 📋 Objetivo

Definir estratégia de portas para permitir acesso dual:
- **Acesso Interno**: IP direto para debug/testes (`http://10.0.20.11:porta`)
- **Acesso Externo**: Domínio via proxy para usuários (`https://office.inoveon.com.br/path`)

## 🎯 Configuração Proposta

### **Projeto Suporte**
```bash
# API Suporte
:8002 → API (interna + externa)

# Portal Suporte  
:3002 → Portal (interna + externa)

# Traefik Dashboard
:8080 → Dashboard (já funcionando)
```

## 📊 Mapeamento Atual vs Novo

### ❌ **Situação Atual**
```bash
# Conflitos identificados
:3001 → i9-campaigns-frontend (ocupada)
:8001 → i9-campaigns-api (ocupada)
:8501 → inoveon-admin (MATAR - substituir pelo nosso)

# Suporte hoje
:8000 → suporte-api (só interno, sem exposição)
```

### ✅ **Nova Configuração**
```bash
# Suporte (estratégia dual)
:8002 → suporte-api (interna + externa)
:3002 → suporte-portal (interna + externa)
:8080 → traefik-dashboard (já OK)

# Acesso externo via proxy
office.inoveon.com.br/api/suporte → :8002
office.inoveon.com.br/portal/suporte → :3002
```

## 🔧 Implementação

### **Passo 1: Verificar Porta 8002**
```bash
# Verificar se porta 8002 está livre
netstat -tlnp | grep :8002

# Opcional: Parar inoveon-admin (libera recursos)
docker stop inoveon-admin
docker rm inoveon-admin
```

### **Passo 2: Reconfigurar API Suporte**
```bash
# Configurar aplicação para rodar na porta 8002 internamente também
# No docker-compose ou docker run:
ports:
  - "8002:8002"  # Externa:Interna (mesma porta)

# Alterar uvicorn para usar porta 8002
# No entrypoint.sh ou comando:
uvicorn app.main:app --host 0.0.0.0 --port 8002
```

### **Passo 3: Configurar Portal**
```bash
# Deploy do portal na porta 3002
ports:
  - "3002:3002"    # Externa:Interna (mesma porta)

# Configurar nginx para rodar na porta 3002
# No nginx.conf:
server {
    listen 3002;
    # ...
}
```

### **Passo 4: Configurar Comunicação Portal → API**

#### **Configuração de Environment Variables**
```bash
# Portal precisa saber onde encontrar a API
# Arquivos .env por ambiente:

# .env.development (local):
VITE_API_URL=http://localhost:8002
VITE_WS_URL=ws://localhost:8002/ws

# .env.production (servidor - acesso direto):
VITE_API_URL=http://10.0.20.11:8002  
VITE_WS_URL=ws://10.0.20.11:8002/ws

# .env.production (servidor - via proxy):
VITE_API_URL=https://office.inoveon.com.br/api/suporte
VITE_WS_URL=wss://office.inoveon.com.br/api/suporte/ws
```

#### **Build Time vs Runtime**
```bash
# Vite (Build Time) - valores fixos no build
VITE_API_URL=http://10.0.20.11:8002

# Runtime (dinâmico) - detectar ambiente no browser
if (window.location.hostname === '10.0.20.11') {
  apiUrl = 'http://10.0.20.11:8002'
} else if (window.location.hostname === 'office.inoveon.com.br') {
  apiUrl = 'https://office.inoveon.com.br/api/suporte'
}
```

#### **Configuração CORS na API**
```python
# Na API (FastAPI), permitir origens do portal:
CORS_ORIGINS = [
    "http://localhost:3002",      # Dev local
    "http://10.0.20.11:3002",     # Produção direta
    "https://office.inoveon.com.br"  # Produção via proxy
]
```

### **Passo 5: Atualizar Traefik**
```bash
# Manter proxy reverso funcionando
# API: office.inoveon.com.br/api/suporte → localhost:8002
# Portal: office.inoveon.com.br/portal/suporte → localhost:3002
```

## 🎯 Benefícios da Estratégia

### **Acesso Interno (Debug/Testes)**
```bash
# Direto, sem interferência do Traefik
curl http://10.0.20.11:8002/health
curl http://10.0.20.11:3002/

# Dashboard Traefik
http://10.0.20.11:8080
```

### **Acesso Externo (Usuários)**
```bash
# Via proxy, com SSL e paths limpos
https://office.inoveon.com.br/api/suporte/docs
https://office.inoveon.com.br/portal/suporte/
```

### **Flexibilidade Operacional**
- ✅ Debug independente de cada serviço
- ✅ Testes isolados sem proxy
- ✅ Monitoramento granular
- ✅ URLs limpos para usuários
- ✅ SSL automático via Traefik

## 📋 Checklist de Migração

### **Preparação**
- [ ] Documentar configuração atual
- [ ] Backup de configurações existentes
- [ ] Parar inoveon-admin
- [ ] Verificar portas livres

### **Configuração API**
- [ ] Atualizar docker-compose da API
- [ ] Expor porta 8501
- [ ] Testar acesso direto
- [ ] Verificar health endpoint

### **Configuração Portal**
- [ ] Deploy portal na porta 3002
- [ ] Configurar nginx interno
- [ ] Testar acesso direto
- [ ] Verificar assets/routing

### **Configuração Traefik**
- [ ] Atualizar regras de proxy
- [ ] Configurar middlewares
- [ ] Testar roteamento
- [ ] Verificar SSL

### **Validação Final**
- [ ] Testar acesso interno (IP:porta)
- [ ] Testar acesso externo (domínio/path)
- [ ] Verificar logs de todos os serviços
- [ ] Documentar URLs finais

## 🔗 URLs Finais

### **Desenvolvimento/Debug (IP interno)**
```bash
# API direta
http://10.0.20.11:8002/docs
http://10.0.20.11:8002/health

# Portal direto  
http://10.0.20.11:3002/

# Dashboard Traefik
http://10.0.20.11:8080/dashboard/
```

### **Produção (domínio público)**
```bash
# API via proxy
https://office.inoveon.com.br/api/suporte/docs
https://office.inoveon.com.br/api/suporte/health

# Portal via proxy
https://office.inoveon.com.br/portal/suporte/
```

## ⚠️ Notas Importantes

### **Segurança**
- Acesso por IP deve ser restrito à rede interna
- Firewall deve bloquear portas 8002, 3002 externamente
- Apenas porta 80/443 acessível publicamente

### **Monitoramento**
- Logs de acesso direto vs proxy
- Métricas separadas por tipo de acesso
- Alertas para falhas em qualquer camada

### **Documentação**
- Atualizar README com novos endpoints
- Documentar quando usar cada tipo de acesso
- Manter guia de troubleshooting

## 🚀 Implementação

### **Resumo da Estratégia Final:**
- ✅ **Padrão de Portas**: Externa:Interna iguais (8002:8002, 3002:3002)
- ✅ **Acesso Dual**: Direto via IP + Proxy via domínio  
- ✅ **Configuração Híbrida**: Portal detecta ambiente automaticamente
- ✅ **CORS Configurado**: API permite ambas as origens

### **Comandos de Deploy:**
```bash
# 1. Atualizar API para porta 8002
make deploy-api

# 2. Atualizar Portal para porta 3002  
make deploy-web

# 3. Verificar configurações
make status

# 4. Testar acessos
curl http://10.0.20.11:8002/health
curl http://10.0.20.11:3002/
```

### **URLs Finais de Validação:**
```bash
# Direto (debug/testes)
http://10.0.20.11:8002/docs
http://10.0.20.11:3002/

# Via proxy (usuários)
https://office.inoveon.com.br/api/suporte/docs
https://office.inoveon.com.br/portal/suporte/
```

---

**Data:** 08/10/2025  
**Status:** ✅ Pronto para implementação  
**Responsável:** Lee Chardes