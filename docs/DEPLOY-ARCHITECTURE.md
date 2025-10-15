# 📋 Arquitetura de Deploy - Padrão Inoveon

Este documento define a **arquitetura padrão de deploy** usando **Traefik v3.1** como proxy reverso para projetos multi-stack. Serve como **template base** para todos os projetos da empresa.

## 🎯 Visão Geral

### Arquitetura Centralizada
- **Um domínio**: `office.inoveon.com.br`
- **Múltiplos projetos**: Cada projeto tem seu path único
- **Proxy reverso**: Traefik roteia automaticamente
- **SSL automático**: Let's Encrypt sem configuração manual
- **Deploy independente**: Cada projeto pode ser deployado separadamente

### Padrão de URLs
```
https://office.inoveon.com.br/
├── api/projeto1/          → FastAPI Backend
├── portal/projeto1/       → React/Vue Frontend  
├── api/projeto2/          → Outro Backend
├── portal/projeto2/       → Outro Frontend
└── admin/                 → Painel administrativo
```

## 🏗️ Arquitetura de Rede

```
┌─────────────────────────────────────────────────────────────┐
│                    office.inoveon.com.br                   │
│                         (Cloudflare)                       │
└─────────────────────────┬───────────────────────────────────┘
                          │
                 ┌────────▼────────┐
                 │   Traefik v3.1  │
                 │   (Porta 80/443)│
                 └────────┬────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
   /api/projeto      /portal/projeto   /api/outro
        │                 │                 │
    ┌───▼───┐         ┌───▼───┐        ┌────▼────┐
    │  API  │         │Portal │        │  Outro  │
    │FastAPI│         │ React │        │ Sistema │
    │:8000  │         │ :80   │        │  :8001  │
    └───────┘         └───────┘        └─────────┘
```

## 🔧 Componentes da Arquitetura

### 1. Traefik (Proxy Reverso)
- **Roteamento automático** baseado em labels Docker
- **SSL automático** via Let's Encrypt
- **Load balancing** entre múltiplas instâncias
- **Middleware** para transformação de paths

### 2. Backend (APIs)
- **StripPrefix**: Remove prefixo antes de enviar para API
- **root_path**: Configuração para OpenAPI/Swagger
- **Health checks**: Monitoramento automático

### 3. Frontend (Portais)
- **SEM StripPrefix**: Mantém path completo
- **Base path**: Configuração no build tool
- **Static files**: Servidos pelo Nginx

## 📁 Estrutura Padrão de Projeto

### Organização de Diretórios
```
projeto/
├── README.md                     # Documentação do projeto
├── .gitignore                    # Ignora pastas dos sub-projetos
├── clone-projects.sh             # Script para clonar sub-projetos
├── projects.json                 # Lista dos repositórios
├── setup.sh                      # Configuração inicial
│
├── docs/                         # Documentação
│   ├── DEPLOY-ARCHITECTURE.md    # Este documento
│   ├── SETUP-GUIDE.md            # Guia de configuração
│   └── TROUBLESHOOTING.md        # Solução de problemas
│
├── deploy/                       # Deploy geral
│   ├── deploy.sh                 # Orquestrador principal
│   ├── docker-compose.prod.yml   # Compose com Traefik
│   └── .env.template             # Template de variáveis
│
├── scripts/                      # Utilitários
│   ├── backup.sh                 # Backup automático
│   ├── logs.sh                   # Visualização de logs
│   ├── health-check.sh           # Health check geral
│   └── update-all.sh             # Atualização completa
│
├── api/                          # Backend
│   ├── deploy/                   # Deploy específico da API
│   │   ├── deploy.sh
│   │   ├── docker-compose.prod.yml
│   │   ├── Dockerfile.prod
│   │   └── .env.template
│   └── projeto_api_fastapi/      # Código (clonado separadamente)
│
├── web/                          # Frontend
│   ├── deploy/                   # Deploy específico do Portal
│   │   ├── deploy.sh
│   │   ├── docker-compose.prod.yml
│   │   ├── Dockerfile.prod
│   │   ├── nginx.conf
│   │   └── .env.template
│   └── projeto_portal_react/     # Código (clonado separadamente)
│
└── mobile/                       # Mobile (futuro)
    ├── deploy/
    └── projeto_mobile_flutter/   # Código (clonado separadamente)
```

## 🐳 Configuração Docker

### Backend (FastAPI) - Labels Traefik
```yaml
services:
  api:
    build: ./api
    restart: unless-stopped
    labels:
      - traefik.enable=true
      
      # HTTP Router
      - traefik.http.routers.projeto-api-http.rule=PathPrefix(`/api/projeto`)
      - traefik.http.routers.projeto-api-http.entrypoints=web
      - traefik.http.routers.projeto-api-http.middlewares=projeto-api-strip@docker
      - traefik.http.routers.projeto-api-http.priority=1
      
      # HTTPS Router
      - traefik.http.routers.projeto-api.rule=Host(`office.inoveon.com.br`) && PathPrefix(`/api/projeto`)
      - traefik.http.routers.projeto-api.entrypoints=websecure
      - traefik.http.routers.projeto-api.tls=true
      - traefik.http.routers.projeto-api.tls.certresolver=letsencrypt
      - traefik.http.routers.projeto-api.middlewares=projeto-api-strip@docker
      - traefik.http.routers.projeto-api.priority=2
      
      # Middleware StripPrefix
      - traefik.http.middlewares.projeto-api-strip.stripprefix.prefixes=/api/projeto
      
      # Service
      - traefik.http.services.projeto-api.loadbalancer.server.port=8000
    networks:
      - traefik_net
```

### Frontend (React) - Labels Traefik
```yaml
services:
  portal:
    build: ./portal
    restart: unless-stopped
    labels:
      - traefik.enable=true
      
      # HTTP Router
      - traefik.http.routers.projeto-portal-http.rule=PathPrefix(`/portal/projeto`)
      - traefik.http.routers.projeto-portal-http.entrypoints=web
      - traefik.http.routers.projeto-portal-http.priority=1
      
      # HTTPS Router
      - traefik.http.routers.projeto-portal.rule=Host(`office.inoveon.com.br`) && PathPrefix(`/portal/projeto`)
      - traefik.http.routers.projeto-portal.entrypoints=websecure
      - traefik.http.routers.projeto-portal.tls=true
      - traefik.http.routers.projeto-portal.tls.certresolver=letsencrypt
      - traefik.http.routers.projeto-portal.priority=2
      
      # Service (SEM StripPrefix)
      - traefik.http.services.projeto-portal.loadbalancer.server.port=80
    networks:
      - traefik_net
```

## ⚙️ Configurações Específicas

### Backend (FastAPI)
```python
# main.py
from fastapi import FastAPI

app = FastAPI(
    title="Projeto API",
    description="API do projeto XYZ",
    version="1.0.0",
    root_path="/api/projeto"  # ← ESSENCIAL para Swagger UI
)

@app.get("/health")
def health():
    return {"status": "ok"}
```

**Por que `root_path`?**
- Swagger UI precisa saber o prefixo completo
- OpenAPI JSON é gerado com `"servers":[{"url":"/api/projeto"}]`
- Sem isso, `/docs` não carrega corretamente

### Frontend (Vite/React)
```javascript
// vite.config.js
export default defineConfig({
  base: '/portal/projeto/',  // ← ESSENCIAL para assets
  build: {
    outDir: 'dist',
    emptyOutDir: true,
  },
})
```

**Por que `base`?**
- Assets são gerados com prefixo: `/portal/projeto/assets/`
- Router do React usa a base correta
- Links internos respeitam o prefixo

### Nginx (Frontend)
```nginx
server {
  listen 80;
  server_name _;
  root /usr/share/nginx/html;
  index index.html;
  
  location /portal/projeto {
    try_files $uri $uri/ /portal/projeto/index.html;
  }
}
```

### Dockerfile Frontend
```dockerfile
# Build stage
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install --no-audit --no-fund
COPY . .
RUN npm run build

# Production stage
FROM nginx:1.27-alpine
# IMPORTANTE: Copiar para o path correto
COPY --from=build /app/dist /usr/share/nginx/html/portal/projeto
COPY nginx.conf /etc/nginx/conf.d/default.conf
```

## 🔐 Configuração SSL

### Automática via Let's Encrypt
O Traefik gera certificados automaticamente quando:
1. **DNS** `office.inoveon.com.br` aponta para o servidor
2. **Portas** 80/443 estão acessíveis externamente  
3. **Router HTTPS** tem `tls.certresolver=letsencrypt`

### Sem intervenção manual
- ✅ Geração automática de certificados
- ✅ Renovação automática (90 dias)
- ✅ Redirecionamento HTTP → HTTPS
- ❌ Não precisa configurar certificados nos containers

## 📊 Diferenças Críticas: API vs Portal

| Aspecto | API (FastAPI) | Portal (React/Vite) |
|---------|---------------|---------------------|
| **StripPrefix** | ✅ SIM | ❌ NÃO |
| **Configuração** | `root_path="/api/projeto"` | `base: '/portal/projeto/'` |
| **Nginx** | N/A (direto FastAPI) | `location /portal/projeto` |
| **Assets** | N/A | `/portal/projeto/assets/` |
| **Docker Copy** | N/A | `COPY dist /html/portal/projeto` |
| **Health Check** | `/health` endpoint | Status HTTP 200 |

## 🚀 Interface Simplificada (Makefile)

O projeto inclui um **Makefile completo** que simplifica todos os comandos de deploy:

### **Quick Start com Makefile**
```bash
# Clone e setup completo
git clone https://github.com/empresa/projeto.git
cd projeto
make first-time

# OU passo a passo:
make install                    # Dependências
make ssh PASSWORD=senha123      # Configurar SSH
make clone                      # Clonar projetos  
make setup                      # Setup inicial
make deploy                     # Deploy completo
```

### **Comandos Principais**
```bash
# Deploy
make deploy           # Deploy completo
make deploy-api       # Deploy apenas API
make deploy-web       # Deploy apenas Portal
make deploy-force     # Deploy com rebuild forçado

# Monitoramento
make status           # Status de todos os serviços
make health           # Health check completo
make logs SERVICE=api # Ver logs específicos
make logs-follow SERVICE=api  # Logs em tempo real

# Manutenção
make update           # Atualizar código e redeploy
make backup           # Backup completo
make restart          # Reiniciar serviços
make clean            # Limpeza completa

# Utilitários
make help             # Lista todos os comandos
make config-show      # Ver configurações
make urls             # URLs do sistema
make ssh-check        # Verificar SSH
```

## 🚀 Fluxo de Deploy

### 1. Setup Inicial (Uma vez)
```bash
# Método simplificado (recomendado)
make first-time

# Método manual (para casos específicos)
./clone-projects.sh
./setup.sh
```

### 2. Deploy Completo
```bash
# Método simplificado (recomendado)
make deploy

# Método manual (para casos específicos)
./deploy/deploy.sh all

# Deploy individual
make deploy-api       # ou ./api/deploy/deploy.sh
make deploy-web       # ou ./web/deploy/deploy.sh
```

### 3. Monitoramento
```bash
# Método simplificado (recomendado)
make status
make health
make logs-follow SERVICE=api

# Método manual (para casos específicos)
./scripts/logs.sh
./scripts/health-check.sh
./scripts/backup.sh
```

## 🧪 Validação e Testes

### URLs de Teste
```bash
# API
curl https://office.inoveon.com.br/api/projeto/health
curl https://office.inoveon.com.br/api/projeto/docs

# Portal
curl https://office.inoveon.com.br/portal/projeto/
```

### Health Checks
- **API**: Endpoint `/health` retorna JSON
- **Portal**: Status HTTP 200 na rota raiz
- **Traefik**: Dashboard em `:8080` (desenvolvimento)

## ⚠️ Problemas Comuns

### API: Swagger UI não carrega
**Causa**: Falta `root_path` no FastAPI
```python
# ❌ Errado
app = FastAPI()

# ✅ Correto  
app = FastAPI(root_path="/api/projeto")
```

### Portal: Assets retornam 404
**Causa**: StripPrefix removendo prefixo dos assets
```yaml
# ❌ Errado - com StripPrefix
- traefik.http.middlewares.projeto-portal-strip.stripprefix.prefixes=/portal/projeto

# ✅ Correto - SEM StripPrefix no portal
# (remover completamente a linha acima)
```

### Portal: Página em branco
**Causa 1**: Base path incorreto no Vite
```javascript
// ❌ Errado
export default defineConfig({
  base: '/',
})

// ✅ Correto
export default defineConfig({
  base: '/portal/projeto/',
})
```

**Causa 2**: Arquivos no local errado no container
```dockerfile
# ❌ Errado
COPY --from=build /app/dist /usr/share/nginx/html/

# ✅ Correto  
COPY --from=build /app/dist /usr/share/nginx/html/portal/projeto
```

### SSL não funciona
**Causas**:
- DNS não aponta para o servidor
- Portas 80/443 bloqueadas no firewall
- Servidor não acessível externamente

**Solução**: Testar primeiro com HTTP, depois configurar DNS

## 📝 Templates de Configuração

### projects.json
```json
{
  "project_name": "projeto",
  "domain": "office.inoveon.com.br",
  "server": "10.0.20.11",
  "components": [
    {
      "name": "api",
      "type": "fastapi",
      "repo": "https://github.com/empresa/projeto_api_fastapi.git",
      "path": "api/projeto_api_fastapi",
      "port": 8000,
      "health_endpoint": "/health"
    },
    {
      "name": "web", 
      "type": "react",
      "repo": "https://github.com/empresa/projeto_portal_react.git",
      "path": "web/projeto_portal_react",
      "port": 80,
      "build_tool": "vite"
    }
  ]
}
```

### .env.template
```bash
# Projeto
PROJECT_NAME=projeto
ENVIRONMENT=production
DOMAIN=office.inoveon.com.br

# API
API_SECRET_KEY=your-secret-key-here
DATABASE_URL=postgresql://user:pass@db:5432/dbname
REDIS_URL=redis://redis:6379/0

# CORS
CORS_ORIGINS=["https://office.inoveon.com.br"]

# Logs
LOG_LEVEL=INFO
```

## 🔧 Comandos Úteis

### **Via Makefile (Recomendado)**
```bash
# Status e monitoramento
make status                     # Status de todos os containers
make health                     # Health check completo
make logs SERVICE=api           # Logs específicos
make logs-follow SERVICE=api    # Logs em tempo real
make config-show               # Ver configurações atuais

# Deploy e atualizações
make deploy                    # Deploy completo
make deploy-api                # Deploy apenas API
make update                    # Atualizar código e redeploy
make restart                   # Reiniciar serviços

# Backup e manutenção
make backup                    # Backup completo
make backup-list               # Listar backups
make backup-clean              # Limpar backups antigos

# SSH e conectividade
make ssh-check                 # Verificar SSH
make test                      # Testes de validação
make urls                      # URLs do sistema
```

### **Comandos Docker Diretos**
```bash
# Ver containers ativos
docker ps | grep projeto

# Logs específicos  
docker logs projeto-api-1 -f
docker logs projeto-portal-1 -f

# Logs do Traefik
docker logs traefik | grep projeto
```

### **Traefik**
```bash
# Ver rotas registradas
curl http://localhost:8080/api/http/routers

# Dashboard (desenvolvimento)
http://localhost:8080
```

### **Diagnóstico Manual**
```bash
# Testar conectividade
curl -I https://office.inoveon.com.br/api/projeto/health

# Verificar certificado SSL
openssl s_client -connect office.inoveon.com.br:443 -servername office.inoveon.com.br

# DNS lookup
nslookup office.inoveon.com.br
```

## 📚 Referências

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Docker Compose](https://docs.docker.com/compose/)
- [Let's Encrypt](https://letsencrypt.org/)
- [FastAPI Deployment](https://fastapi.tiangolo.com/deployment/)
- [Vite Build](https://vitejs.dev/guide/build.html)

## 🤝 Contribuição

### Para adicionar novo projeto
1. Copie esta estrutura como base
2. Substitua `projeto` pelo nome real
3. Configure `projects.json` com os repositórios
4. Teste localmente antes do deploy
5. Documente particularidades no README

### Para melhorar a arquitetura
1. Teste mudanças em ambiente de desenvolvimento
2. Atualize esta documentação
3. Valide com outros projetos existentes
4. Mantenha compatibilidade reversa

---

*Arquitetura padronizada para deploy eficiente e escalável usando Traefik como proxy reverso.*

**Versão**: 2.0 (com Makefile)  
**Última atualização**: Janeiro 2025  
**Mantido por**: Equipe DevOps Inoveon