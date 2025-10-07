# 📋 Guia de Deploy - Sistema de Suporte Inoveon

## 🏗️ Arquitetura Geral

O sistema utiliza **Traefik v3.1** como proxy reverso central, roteando tráfego para múltiplos serviços através de um único domínio com paths diferentes.

```
┌─────────────────────────────────────────────────────────────┐
│                      office.inoveon.com.br                  │
└─────────────────────────────────────────────────────────────┘
                            │
                    ┌───────┴───────┐
                    │   Traefik     │
                    │  (Porta 80)   │
                    └───────┬───────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
  /api/suporte        /portal/suporte     /api/routeros
        │                   │                   │
    ┌───▼───┐           ┌───▼───┐         ┌────▼────┐
    │  API  │           │Portal │         │  Outro  │
    │FastAPI│           │ React │         │ Sistema │
    └───────┘           └───────┘         └─────────┘
```

## 🎯 Padrão de Roteamento

### Estrutura de URLs
- **API**: `http://10.0.20.11/api/[projeto]/` ou `https://office.inoveon.com.br/api/[projeto]/`
- **Portal**: `http://10.0.20.11/portal/[projeto]/` ou `https://office.inoveon.com.br/portal/[projeto]/`

Exemplo:
- API Suporte: `/api/suporte/` → FastAPI docs em `/api/suporte/docs`
- Portal Suporte: `/portal/suporte/` → Interface React

---

## 🔧 Como Funciona: API Backend (FastAPI)

### Configuração do Traefik (Labels Docker)

```yaml
services:
  api:
    build: ./api
    restart: unless-stopped
    labels:
      - traefik.enable=true

      # Router HTTP (aceita acesso por IP ou domínio)
      - traefik.http.routers.suporte-api-http.rule=PathPrefix(`/api/suporte`)
      - traefik.http.routers.suporte-api-http.entrypoints=web
      - traefik.http.routers.suporte-api-http.middlewares=suporte-api-strip@docker
      - traefik.http.routers.suporte-api-http.priority=1

      # Router HTTPS (apenas com domínio)
      - traefik.http.routers.suporte-api.rule=Host(`office.inoveon.com.br`) && PathPrefix(`/api/suporte`)
      - traefik.http.routers.suporte-api.entrypoints=websecure
      - traefik.http.routers.suporte-api.tls=true
      - traefik.http.routers.suporte-api.tls.certresolver=letsencrypt
      - traefik.http.routers.suporte-api.middlewares=suporte-api-strip@docker
      - traefik.http.routers.suporte-api.priority=2

      # Middleware: Remove /api/suporte antes de chegar na API
      - traefik.http.middlewares.suporte-api-strip.stripprefix.prefixes=/api/suporte

      # Porta interna do container
      - traefik.http.services.suporte-api.loadbalancer.server.port=8000
    networks:
      - traefik_net
```

### ⚠️ IMPORTANTE: StripPrefix na API

O **StripPrefix** remove o prefixo `/api/suporte` antes de encaminhar para a API.

**Fluxo:**
```
Cliente: GET http://office.inoveon.com.br/api/suporte/health
         ↓
Traefik: Remove /api/suporte (StripPrefix)
         ↓
API recebe: GET /health
```

### Configuração FastAPI

```python
from fastapi import FastAPI

# IMPORTANTE: root_path é necessário para Swagger UI funcionar
app = FastAPI(
    title="Suporte API",
    description="API do sistema de suporte Inoveon",
    version="1.0.0",
    root_path="/api/suporte"  # ← Necessário para OpenAPI gerar URLs corretas
)

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/")
def root():
    return {"app": "suporte-api", "message": "Hello from API!"}
```

**Por que `root_path`?**
- Mesmo com StripPrefix, o Swagger UI precisa saber o prefixo completo
- O OpenAPI JSON é gerado com `"servers":[{"url":"/api/suporte"}]`
- Sem isso, `/docs` não carrega o `openapi.json` corretamente

---

## 🌐 Como Funciona: Portal Frontend (React/Vite)

### Configuração do Traefik (Labels Docker)

```yaml
services:
  portal:
    build: ./portal
    restart: unless-stopped
    labels:
      - traefik.enable=true

      # Router HTTP (aceita acesso por IP ou domínio)
      - traefik.http.routers.suporte-portal-http.rule=PathPrefix(`/portal/suporte`)
      - traefik.http.routers.suporte-portal-http.entrypoints=web
      - traefik.http.routers.suporte-portal-http.priority=1

      # Router HTTPS (apenas com domínio)
      - traefik.http.routers.suporte-portal.rule=Host(`office.inoveon.com.br`) && PathPrefix(`/portal/suporte`)
      - traefik.http.routers.suporte-portal.entrypoints=websecure
      - traefik.http.routers.suporte-portal.tls=true
      - traefik.http.routers.suporte-portal.tls.certresolver=letsencrypt
      - traefik.http.routers.suporte-portal.priority=2

      # SEM StripPrefix - portal mantém o caminho completo
      # Porta interna do container
      - traefik.http.services.suporte-portal.loadbalancer.server.port=80
    networks:
      - traefik_net
```

### ⚠️ IMPORTANTE: SEM StripPrefix no Portal

O portal **NÃO** usa StripPrefix. O caminho completo é mantido.

**Fluxo:**
```
Cliente: GET http://office.inoveon.com.br/portal/suporte/
         ↓
Traefik: Mantém /portal/suporte (SEM StripPrefix)
         ↓
Nginx recebe: GET /portal/suporte/
```

### Configuração Vite

**vite.config.js:**
```javascript
import { defineConfig } from 'vite'

export default defineConfig({
  // IMPORTANTE: base deve ser o caminho completo
  base: '/portal/suporte/',
  build: {
    outDir: 'dist',
    emptyOutDir: true,
  },
})
```

**O que isso faz:**
- Assets (JS, CSS) são gerados com prefixo: `/portal/suporte/assets/index-xxx.js`
- Router do React usa a base correta
- Links internos respeitam o prefixo

### Dockerfile do Portal

```dockerfile
# Build (Vite/React)
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install --no-audit --no-fund
COPY . .
RUN npm run build

# Serve com Nginx
FROM nginx:1.27-alpine
# IMPORTANTE: Copiar para /usr/share/nginx/html/portal/suporte
COPY --from=build /app/dist /usr/share/nginx/html/portal/suporte

# Configuração Nginx
RUN printf 'server { \
  listen 80; \
  server_name _; \
  root /usr/share/nginx/html; \
  index index.html; \
  location /portal/suporte { \
    try_files $uri $uri/ /portal/suporte/index.html; \
  } \
}' > /etc/nginx/conf.d/default.conf
```

**Por que copiar para `/usr/share/nginx/html/portal/suporte`?**
- Nginx recebe requisições com `/portal/suporte/` no caminho
- Arquivos estão em `/usr/share/nginx/html/portal/suporte/`
- Match perfeito: `/portal/suporte/assets/index.js` → arquivo existe

---

## 📝 Checklist para Novos Projetos

### 1. API Backend (FastAPI/Python)

- [ ] Criar pasta `api/` com `Dockerfile` e `main.py`
- [ ] Configurar `root_path` no FastAPI: `FastAPI(root_path="/api/[projeto]")`
- [ ] Adicionar labels no `compose.yml`:
  - `PathPrefix(/api/[projeto])`
  - `stripprefix.prefixes=/api/[projeto]`
  - Middleware `strip` em ambos routers HTTP e HTTPS
- [ ] Testar `/docs` funcionando

### 2. Portal Frontend (React/Vite)

- [ ] Criar pasta `portal/` com `package.json` e `vite.config.js`
- [ ] Configurar `base: '/portal/[projeto]/'` no Vite
- [ ] Dockerfile:
  - Copiar build para `/usr/share/nginx/html/portal/[projeto]`
  - Configurar location Nginx: `location /portal/[projeto]`
- [ ] Adicionar labels no `compose.yml`:
  - `PathPrefix(/portal/[projeto])`
  - **SEM** StripPrefix
- [ ] Testar assets carregando corretamente

### 3. Docker Compose

```yaml
version: "3.9"

services:
  api:
    build: ./api
    restart: unless-stopped
    labels:
      - traefik.enable=true
      - traefik.http.routers.PROJETO-api-http.rule=PathPrefix(`/api/PROJETO`)
      - traefik.http.routers.PROJETO-api-http.entrypoints=web
      - traefik.http.routers.PROJETO-api-http.middlewares=PROJETO-api-strip@docker
      - traefik.http.routers.PROJETO-api-http.priority=1
      - traefik.http.routers.PROJETO-api.rule=Host(`office.inoveon.com.br`) && PathPrefix(`/api/PROJETO`)
      - traefik.http.routers.PROJETO-api.entrypoints=websecure
      - traefik.http.routers.PROJETO-api.tls=true
      - traefik.http.routers.PROJETO-api.tls.certresolver=letsencrypt
      - traefik.http.routers.PROJETO-api.middlewares=PROJETO-api-strip@docker
      - traefik.http.routers.PROJETO-api.priority=2
      - traefik.http.middlewares.PROJETO-api-strip.stripprefix.prefixes=/api/PROJETO
      - traefik.http.services.PROJETO-api.loadbalancer.server.port=8000
    networks:
      - traefik_net

  portal:
    build: ./portal
    restart: unless-stopped
    labels:
      - traefik.enable=true
      - traefik.http.routers.PROJETO-portal-http.rule=PathPrefix(`/portal/PROJETO`)
      - traefik.http.routers.PROJETO-portal-http.entrypoints=web
      - traefik.http.routers.PROJETO-portal-http.priority=1
      - traefik.http.routers.PROJETO-portal.rule=Host(`office.inoveon.com.br`) && PathPrefix(`/portal/PROJETO`)
      - traefik.http.routers.PROJETO-portal.entrypoints=websecure
      - traefik.http.routers.PROJETO-portal.tls=true
      - traefik.http.routers.PROJETO-portal.tls.certresolver=letsencrypt
      - traefik.http.routers.PROJETO-portal.priority=2
      - traefik.http.services.PROJETO-portal.loadbalancer.server.port=80
    networks:
      - traefik_net

networks:
  traefik_net:
    external: true
```

**Substitua `PROJETO` pelo nome do seu projeto!**

---

## 🧪 Testes

### Testar API
```bash
# Por IP
curl http://10.0.20.11/api/suporte/
curl http://10.0.20.11/api/suporte/health
curl http://10.0.20.11/api/suporte/docs

# Por domínio (quando DNS estiver configurado)
curl https://office.inoveon.com.br/api/suporte/
```

### Testar Portal
```bash
# Por IP
curl http://10.0.20.11/portal/suporte/

# No navegador
http://10.0.20.11/portal/suporte/
https://office.inoveon.com.br/portal/suporte/
```

---

## 🚀 Deploy

### 1. Subir Traefik (apenas uma vez)
```bash
cd /docker/traefik
docker compose up -d
```

### 2. Subir Projeto
```bash
cd /docker/inoveon/PROJETO
docker compose up -d --build
```

### 3. Verificar Status
```bash
docker ps | grep PROJETO
docker logs PROJETO-api-1
docker logs PROJETO-portal-1
```

### 4. Verificar Rotas no Traefik
```bash
docker logs traefik | grep PROJETO
```

---

## 🔐 SSL / HTTPS

O Traefik gera certificados **automaticamente** via Let's Encrypt quando:
1. DNS `office.inoveon.com.br` aponta para o servidor
2. Portas 80/443 estão acessíveis externamente
3. Router HTTPS tem `tls.certresolver=letsencrypt`

**Não é necessário:**
- Gerar certificados manualmente
- Renovar certificados (auto-renovação)
- Configurar certificados nos containers

---

## 📊 Diferenças: API vs Portal

| Aspecto | API (FastAPI) | Portal (React/Vite) |
|---------|---------------|---------------------|
| **StripPrefix** | ✅ SIM | ❌ NÃO |
| **root_path/base** | `root_path="/api/projeto"` | `base: '/portal/projeto/'` |
| **Nginx location** | N/A (sem Nginx) | `location /portal/projeto` |
| **Assets path** | N/A | `/portal/projeto/assets/` |
| **Copy no Dockerfile** | N/A | `COPY dist /html/portal/projeto` |

---

## ⚠️ Problemas Comuns

### API: Swagger não carrega
- **Causa**: Falta `root_path` no FastAPI
- **Solução**: `FastAPI(root_path="/api/projeto")`

### Portal: Assets retornam 404
- **Causa**: StripPrefix removendo o prefixo
- **Solução**: Remover StripPrefix do portal

### Portal: Página em branco
- **Causa 1**: `base` incorreto no Vite
- **Solução**: Configurar `base: '/portal/projeto/'`
- **Causa 2**: Arquivos no lugar errado no Nginx
- **Solução**: Copiar para `/usr/share/nginx/html/portal/projeto`

### Certificado SSL não gera
- **Causa**: DNS não configurado ou portas bloqueadas
- **Solução**: Testar com HTTP primeiro, depois configurar DNS

---

## 📞 Suporte

- Logs Traefik: `docker logs traefik`
- Logs Projeto: `docker logs PROJETO-api-1` ou `docker logs PROJETO-portal-1`
- Testar config Nginx: `docker exec PROJETO-portal-1 nginx -t`
- IP do servidor: `10.0.20.11`
- Domínio: `office.inoveon.com.br`
