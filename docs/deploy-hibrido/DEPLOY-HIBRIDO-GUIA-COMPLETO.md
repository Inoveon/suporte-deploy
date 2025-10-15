# 🚀 Guia Completo de Deploy Híbrido com Traefik

## 📋 Índice

1. [Visão Geral](#visão-geral)
2. [Arquitetura Híbrida](#arquitetura-híbrida)
3. [Conceitos Fundamentais](#conceitos-fundamentais)
4. [Implementação por Stack](#implementação-por-stack)
5. [Automação e Scripts](#automação-e-scripts)
6. [Testes e Validação](#testes-e-validação)
7. [Troubleshooting](#troubleshooting)
8. [Checklist de Implementação](#checklist-de-implementação)

---

## 🎯 Visão Geral

### O que é Deploy Híbrido?

Deploy híbrido é uma estratégia que permite **acesso dual** aos serviços:

- **Acesso Direto (Desenvolvimento/Debug)**: `http://IP:PORTA/endpoint`
- **Acesso via Proxy (Produção/Usuários)**: `https://DOMINIO/path/endpoint`

### Benefícios

✅ **Flexibilidade Total**: Debug sem interferir em produção
✅ **Manutenção Simplificada**: Isolar problemas rapidamente
✅ **Builds Únicos**: Mesmos artefatos funcionam em dev/prod
✅ **URLs Amigáveis**: Paths limpos para usuários finais
✅ **SSL Automático**: Let's Encrypt via Traefik

### Quando Usar?

- ✅ Múltiplos serviços no mesmo servidor
- ✅ Equipes de desenvolvimento precisam de debug direto
- ✅ Ambientes com domínio único e múltiplos projetos
- ✅ Necessidade de SSL centralizado

---

## 🏗️ Arquitetura Híbrida

### Visão Macro

```
┌─────────────────────────────────────────────────────────────┐
│                 ACESSO DUAL SIMULTÂNEO                      │
└─────────────────────────────────────────────────────────────┘

╔═══════════════════════════════════════════════════════════╗
║  FORMA 1: ACESSO DIRETO (Dev/Debug)                       ║
╚═══════════════════════════════════════════════════════════╝

    Cliente → http://10.0.20.11:8002/api/health
                     ↓
                   [API]
                   :8002

╔═══════════════════════════════════════════════════════════╗
║  FORMA 2: ACESSO VIA PROXY (Produção)                     ║
╚═══════════════════════════════════════════════════════════╝

    Cliente → https://office.inoveon.com.br/api/suporte/health
                     ↓
                 [Traefik]
                 :80/443
                     ↓
              [Roteamento]
                     ↓
                   [API]
                   :8002
```

### Fluxo Detalhado de Requisição

```
1. Usuário acessa: https://office.inoveon.com.br/portal/suporte/login

2. DNS → IP do servidor (10.0.20.11)

3. Traefik (porta 443):
   - Identifica: Host=office.inoveon.com.br
   - Identifica: Path=/portal/suporte/login
   - Aplica: Certificado SSL
   - Encontra: Router "suporte-portal"
   - Encaminha: http://10.0.20.11:3002/portal/suporte/login

4. Frontend React:
   - Detecta: window.location.pathname contém "/portal/suporte"
   - Define: window.__APP_BASE_PATH__ = "/portal/suporte"
   - Router: basename="/portal/suporte"
   - Renderiza: componente Login

5. Frontend faz chamada API:
   - Código: api.post('/auth/login', {...})
   - URL Real: https://office.inoveon.com.br/api/suporte/auth/login

6. Traefik recebe chamada API:
   - Identifica: Router "suporte-api"
   - Aplica: Middleware StripPrefix (/api/suporte)
   - Remove: /api/suporte → sobra /auth/login
   - Aplica: Middleware AddPrefix (/api)
   - Adiciona: /api → fica /api/auth/login
   - Encaminha: http://10.0.20.11:8002/api/auth/login

7. Backend FastAPI:
   - Recebe: /api/auth/login (path esperado!)
   - Processa: Autenticação
   - Retorna: JSON com token

8. Resposta volta:
   - FastAPI → Traefik → Cliente
   - Headers CORS corretos aplicados
```

---

## 💡 Conceitos Fundamentais

### 1. Root Path vs Basename

**Root Path (Backend)**
- Usado por: FastAPI, Spring Boot
- Propósito: OpenAPI/Swagger saber o prefixo
- Exemplo: `root_path="/api/suporte"`
- Quando usar: Aplicação atrás de proxy

**Basename (Frontend)**
- Usado por: React Router, Vue Router
- Propósito: Navegação e links corretos
- Exemplo: `basename="/portal/suporte"`
- Quando usar: App servido em subpath

### 2. StripPrefix vs AddPrefix

**StripPrefix (Traefik)**
```yaml
# Remove prefixo ANTES de enviar para backend
stripprefix.prefixes=/api/suporte

# Requisição: /api/suporte/auth
# Envia para backend: /auth
```

**AddPrefix (Traefik)**
```yaml
# Adiciona prefixo APÓS remover
addprefix.prefix=/api

# Recebeu: /auth (após stripprefix)
# Envia para backend: /api/auth
```

**Por que os dois juntos?**
```
URL Externa:    /api/suporte/auth/login
StripPrefix:    /auth/login
AddPrefix:      /api/auth/login  ← Formato que a API espera!
```

### 3. Detecção Automática de Ambiente

**Problema**: Como usar o mesmo build em dev e prod?

**Solução**: Detecção runtime no browser

```javascript
// Detecta automaticamente baseado na URL
const pathname = window.location.pathname;

if (pathname.includes('/portal/suporte')) {
  // Está em produção via Traefik
  basename = '/portal/suporte'
  apiUrl = 'https://office.inoveon.com.br/api/suporte'
} else {
  // Está em desenvolvimento direto
  basename = ''
  apiUrl = 'http://10.0.20.11:8002/api'
}
```

### 4. Headers X-Forwarded-*

Quando atrás de proxy, o backend precisa saber:

```
X-Forwarded-For: IP original do cliente
X-Forwarded-Proto: http ou https
X-Forwarded-Host: dominio.com
X-Forwarded-Prefix: /api/suporte
```

**Uso**:
- Logs com IP real do cliente
- Redirecionamentos com protocolo correto
- URLs geradas com host correto

---

## 🔧 Implementação por Stack

### Traefik (Proxy Reverso)

**Arquivo**: `deploy/docker-compose.prod.yml`

```yaml
version: '3.8'

services:
  traefik:
    image: traefik:v3.1
    container_name: traefik
    restart: unless-stopped

    command:
      # API e Dashboard
      - "--api.dashboard=true"
      - "--api.insecure=false"

      # Providers
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"

      # Entrypoints
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"

      # Redirect HTTP → HTTPS
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"

      # SSL/TLS automático
      - "--certificatesresolvers.letsencrypt.acme.email=seu@email.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"

      # Logs
      - "--log.level=INFO"
      - "--accesslog=true"

    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"  # Dashboard (proteger em produção!)

    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt

    networks:
      - traefik_net

    labels:
      - "traefik.enable=true"

      # Dashboard (opcional - proteger com auth)
      - "traefik.http.routers.dashboard.rule=Host(`traefik.office.inoveon.com.br`)"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
      - "traefik.http.routers.dashboard.tls.certresolver=letsencrypt"
      - "traefik.http.routers.dashboard.service=api@internal"

networks:
  traefik_net:
    name: traefik_net
    driver: bridge
```

**Checklist Traefik**:
- [ ] Email configurado no Let's Encrypt
- [ ] Volume `./letsencrypt` criado e com permissões corretas
- [ ] Portas 80/443 abertas no firewall
- [ ] DNS apontando para o servidor
- [ ] Dashboard protegido (não expor na internet)

---

### Backend FastAPI

**Arquivo**: `api/suporte_chamados_api_fastapi/app/main.py`

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
import os

# Detecta root_path automaticamente
# Prioridade: ENV > Settings > Vazio
root_path = os.getenv("ROOT_PATH", settings.root_path or "")

app = FastAPI(
    title="Suporte API",
    version="1.0.0",
    root_path=root_path,  # ESSENCIAL para Swagger UI
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json"
)

# CORS - Permitir ambas as origens
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://10.0.20.11:3002",           # Dev direto
        "http://localhost:3002",             # Dev local
        "https://office.inoveon.com.br",    # Produção via Traefik
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health check (essencial para monitoramento)
@app.get("/api/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "suporte-api",
        "root_path": root_path
    }

@app.get("/")
async def root():
    return {
        "message": "Suporte API",
        "docs": f"{root_path}/api/docs" if root_path else "/api/docs",
        "health": f"{root_path}/api/health" if root_path else "/api/health"
    }
```

**Arquivo**: `api/deploy/Dockerfile.prod`

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Instalar dependências
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código
COPY . .

# Variáveis de ambiente
ENV PYTHONUNBUFFERED=1
ENV ROOT_PATH=""

# Expor porta
EXPOSE 8002

# Comando de inicialização
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8002"]
```

**Labels Traefik para API**:

```yaml
# deploy/docker-compose.prod.yml
services:
  suporte-api:
    build: ../api/suporte_chamados_api_fastapi
    container_name: suporte-api
    restart: unless-stopped

    ports:
      - "8002:8002"  # Acesso direto

    environment:
      - DATABASE_URL=${DATABASE_URL}
      - ROOT_PATH=""  # Vazio para acesso direto funcionar

    networks:
      - traefik_net

    labels:
      - "traefik.enable=true"

      # HTTPS Router
      - "traefik.http.routers.suporte-api.rule=Host(`office.inoveon.com.br`) && PathPrefix(`/api/suporte`)"
      - "traefik.http.routers.suporte-api.entrypoints=websecure"
      - "traefik.http.routers.suporte-api.tls=true"
      - "traefik.http.routers.suporte-api.tls.certresolver=letsencrypt"
      - "traefik.http.routers.suporte-api.priority=2"

      # Middlewares: Remove /api/suporte, adiciona /api
      - "traefik.http.middlewares.suporte-api-strip.stripprefix.prefixes=/api/suporte"
      - "traefik.http.middlewares.suporte-api-add.addprefix.prefix=/api"
      - "traefik.http.routers.suporte-api.middlewares=suporte-api-strip,suporte-api-add"

      # Service
      - "traefik.http.services.suporte-api.loadbalancer.server.port=8002"
```

**Checklist FastAPI**:
- [ ] `root_path` configurável via ENV
- [ ] CORS com todas as origens necessárias
- [ ] Health check em `/api/health`
- [ ] Docs em `/api/docs`
- [ ] Porta exposta para acesso direto

---

### Frontend React/Vite

**Arquivo**: `web/suporte_dashboard_web_react/index.html`

```html
<!DOCTYPE html>
<html lang="pt-BR">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Portal de Suporte - Inoveon</title>

    <script>
      /**
       * DETECÇÃO AUTOMÁTICA DE AMBIENTE
       *
       * Este script detecta automaticamente se a aplicação está rodando:
       * - Em desenvolvimento (http://10.0.20.11:3002/)
       * - Em produção via Traefik (https://office.inoveon.com.br/portal/suporte/)
       *
       * Não precisa de builds diferentes!
       */

      (function() {
        // Lista de prefixos válidos para este projeto
        const validPrefixes = [
          'portal/suporte',
          'suporte'
        ];

        // Pega o pathname atual
        const pathname = window.location.pathname;

        // Detecta o basename
        let basePath = '';
        for (const prefix of validPrefixes) {
          if (pathname.includes(prefix)) {
            // Normaliza para começar com /
            basePath = '/' + prefix.replace(/^\//, '');
            break;
          }
        }

        // Detecta API URL automaticamente
        const apiUrl = basePath
          ? `${window.location.protocol}//${window.location.host}/api/suporte`
          : 'http://10.0.20.11:8002/api';

        // Salva configuração global
        window.__APP_BASE_PATH__ = basePath;
        window.__APP_CONFIG__ = {
          basePath: basePath,
          apiUrl: apiUrl,
          wsUrl: apiUrl.replace('http', 'ws') + '/ws',
          environment: basePath ? 'production' : 'development'
        };

        // Log para debug (remover em produção se necessário)
        console.log('[App Config]', {
          basePath: basePath || '(raiz)',
          apiUrl: apiUrl,
          environment: window.__APP_CONFIG__.environment
        });

        // Cria tag <base> se necessário (para assets)
        if (basePath) {
          const baseTag = document.createElement('base');
          baseTag.href = basePath + '/';
          document.head.appendChild(baseTag);
        }
      })();
    </script>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

**Arquivo**: `web/suporte_dashboard_web_react/src/config/api.ts`

```typescript
import axios from 'axios';

/**
 * Configuração do cliente API com detecção automática
 */

// Pega configuração detectada no index.html
const config = window.__APP_CONFIG__ || {
  apiUrl: 'http://localhost:8002/api',
  basePath: ''
};

// Cliente Axios configurado
export const api = axios.create({
  baseURL: config.apiUrl,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json'
  }
});

// Interceptor: Adiciona token de autenticação
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('access_token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }

    // Log para debug
    console.log('[API Request]', {
      method: config.method?.toUpperCase(),
      url: config.url,
      baseURL: config.baseURL
    });

    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Interceptor: Trata erros de resposta
api.interceptors.response.use(
  (response) => {
    console.log('[API Response]', {
      status: response.status,
      url: response.config.url
    });
    return response;
  },
  (error) => {
    console.error('[API Error]', {
      status: error.response?.status,
      url: error.config?.url,
      message: error.message
    });

    // Redireciona para login se 401
    if (error.response?.status === 401) {
      localStorage.removeItem('access_token');
      window.location.href = config.basePath + '/login';
    }

    return Promise.reject(error);
  }
);

// Helpers de autenticação
export const authApi = {
  login: (email: string, password: string) =>
    api.post('/auth/login', { email, password }),

  logout: () => {
    localStorage.removeItem('access_token');
    window.location.href = config.basePath + '/login';
  },

  getCurrentUser: () =>
    api.get('/auth/me'),
};

// Export da configuração
export const appConfig = config;

export default api;
```

**Arquivo**: `web/suporte_dashboard_web_react/src/App.tsx`

```typescript
import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Home } from './pages/Home';
import { Login } from './pages/Login';
import { Dashboard } from './pages/Dashboard';

function App() {
  // Pega basename detectado automaticamente
  const basename = window.__APP_BASE_PATH__ || '';

  console.log('[App] Inicializada com basename:', basename || '(raiz)');

  return (
    <BrowserRouter basename={basename}>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/login" element={<Login />} />
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
```

**Arquivo**: `web/suporte_dashboard_web_react/vite.config.ts`

```typescript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],

  // Base vazio - detecção automática no runtime!
  base: '/',

  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },

  server: {
    port: 3002,
    host: '0.0.0.0',

    // Proxy para desenvolvimento (opcional)
    proxy: {
      '/api': {
        target: 'http://10.0.20.11:8002',
        changeOrigin: true,
        secure: false,
      }
    }
  },

  build: {
    outDir: 'dist',
    sourcemap: false,

    // Otimizações
    rollupOptions: {
      output: {
        manualChunks: {
          'react-vendor': ['react', 'react-dom', 'react-router-dom'],
        }
      }
    }
  }
})
```

**Arquivo**: `web/deploy/Dockerfile.prod`

```dockerfile
# Build stage
FROM node:20-alpine AS build

WORKDIR /app

# Instalar dependências
COPY package*.json ./
RUN npm ci --no-audit --no-fund

# Copiar código
COPY . .

# Build (com base vazio - detecção runtime!)
ENV VITE_BASE_PATH=/
RUN npm run build

# Production stage
FROM nginx:1.27-alpine

# Copiar build para servir em QUALQUER path
# O Nginx vai servir, e o JS detecta o path automaticamente
COPY --from=build /app/dist /usr/share/nginx/html

# Configuração Nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 3002

CMD ["nginx", "-g", "daemon off;"]
```

**Arquivo**: `web/deploy/nginx.conf`

```nginx
server {
    listen 3002;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    # Configuração para SPA (Single Page Application)
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache para assets estáticos
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Não cachear o index.html
    location = /index.html {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        expires 0;
    }

    # Gzip
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    gzip_vary on;
}
```

**Labels Traefik para Portal**:

```yaml
# deploy/docker-compose.prod.yml
services:
  suporte-portal:
    build: ../web/suporte_dashboard_web_react
    container_name: suporte-portal
    restart: unless-stopped

    ports:
      - "3002:3002"  # Acesso direto

    networks:
      - traefik_net

    labels:
      - "traefik.enable=true"

      # HTTPS Router
      - "traefik.http.routers.suporte-portal.rule=Host(`office.inoveon.com.br`) && PathPrefix(`/portal/suporte`)"
      - "traefik.http.routers.suporte-portal.entrypoints=websecure"
      - "traefik.http.routers.suporte-portal.tls=true"
      - "traefik.http.routers.suporte-portal.tls.certresolver=letsencrypt"
      - "traefik.http.routers.suporte-portal.priority=2"

      # Service (SEM StripPrefix - portal precisa do path completo!)
      - "traefik.http.services.suporte-portal.loadbalancer.server.port=3002"
```

**Checklist React**:
- [ ] Script de detecção no `index.html`
- [ ] Configuração da API com detecção automática
- [ ] `basename` dinâmico no Router
- [ ] `base: '/'` no vite.config.ts
- [ ] Nginx configurado para SPA
- [ ] Build único funciona em dev e prod

---

## 🤖 Automação e Scripts

### Script de Testes Completo

**Arquivo**: `scripts/test-endpoints.sh`

```bash
#!/bin/bash

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configurações
SERVER_IP="10.0.20.11"
DOMAIN="office.inoveon.com.br"
API_PORT="8002"
PORTAL_PORT="3002"

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Teste de Conectividade - Deploy Híbrido  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Função para testar endpoint
test_endpoint() {
    local url=$1
    local description=$2
    local expected_status=${3:-200}

    echo -n "  Testando $description... "

    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" --connect-timeout 5 --max-time 10)

    if [ "$http_code" -eq "$expected_status" ] || [ "$http_code" -eq 301 ] || [ "$http_code" -eq 302 ]; then
        echo -e "${GREEN}✓ OK${NC} (HTTP $http_code)"
        return 0
    else
        echo -e "${RED}✗ FALHOU${NC} (HTTP $http_code)"
        return 1
    fi
}

# Contador de testes
total_tests=0
passed_tests=0

# ============================================
# TESTES DE ACESSO DIRETO (IP:PORTA)
# ============================================
echo -e "${YELLOW}┌─ Acesso Direto (Desenvolvimento) ─────────┐${NC}"

((total_tests++))
test_endpoint "http://${SERVER_IP}:${API_PORT}/api/health" "API Health (direto)" && ((passed_tests++))

((total_tests++))
test_endpoint "http://${SERVER_IP}:${API_PORT}/api/docs" "API Docs (direto)" && ((passed_tests++))

((total_tests++))
test_endpoint "http://${SERVER_IP}:${PORTAL_PORT}/" "Portal Home (direto)" && ((passed_tests++))

echo -e "${YELLOW}└────────────────────────────────────────────┘${NC}"
echo ""

# ============================================
# TESTES VIA TRAEFIK (DOMÍNIO)
# ============================================
echo -e "${YELLOW}┌─ Acesso via Traefik (Produção) ───────────┐${NC}"

((total_tests++))
test_endpoint "https://${DOMAIN}/api/suporte/health" "API Health (Traefik)" && ((passed_tests++))

((total_tests++))
test_endpoint "https://${DOMAIN}/api/suporte/docs" "API Docs (Traefik)" && ((passed_tests++))

((total_tests++))
test_endpoint "https://${DOMAIN}/portal/suporte/" "Portal Home (Traefik)" && ((passed_tests++))

echo -e "${YELLOW}└────────────────────────────────────────────┘${NC}"
echo ""

# ============================================
# TESTE DE LOGIN (API)
# ============================================
echo -e "${YELLOW}┌─ Teste de Endpoints da API ───────────────┐${NC}"

echo "  Testando login via Traefik..."
response=$(curl -s -X POST "https://${DOMAIN}/api/suporte/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@test.com","password":"admin123"}' \
  -w "\n%{http_code}")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 401 ]; then
    echo -e "  ${GREEN}✓ Endpoint respondendo${NC} (HTTP $http_code)"
    ((total_tests++))
    ((passed_tests++))
else
    echo -e "  ${RED}✗ Erro no endpoint${NC} (HTTP $http_code)"
    ((total_tests++))
fi

echo -e "${YELLOW}└────────────────────────────────────────────┘${NC}"
echo ""

# ============================================
# TESTE DE SSL
# ============================================
echo -e "${YELLOW}┌─ Validação SSL ───────────────────────────┐${NC}"

echo "  Verificando certificado SSL..."
ssl_output=$(echo | openssl s_client -connect ${DOMAIN}:443 -servername ${DOMAIN} 2>/dev/null | grep "Verify return code")

if echo "$ssl_output" | grep -q "0 (ok)"; then
    echo -e "  ${GREEN}✓ Certificado SSL válido${NC}"
    ((total_tests++))
    ((passed_tests++))
else
    echo -e "  ${YELLOW}⚠ Certificado SSL não verificado${NC}"
    echo "    (pode estar usando certificado autoassinado em dev)"
    ((total_tests++))
fi

echo -e "${YELLOW}└────────────────────────────────────────────┘${NC}"
echo ""

# ============================================
# RESUMO
# ============================================
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              RESUMO DOS TESTES             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""
echo "  Total de testes: $total_tests"
echo "  Testes passados: $passed_tests"
echo "  Testes falhados: $((total_tests - passed_tests))"
echo ""

if [ $passed_tests -eq $total_tests ]; then
    echo -e "${GREEN}  ✓ TODOS OS TESTES PASSARAM!${NC}"
    exit 0
else
    echo -e "${RED}  ✗ ALGUNS TESTES FALHARAM${NC}"
    exit 1
fi
```

**Uso**:
```bash
chmod +x scripts/test-endpoints.sh
./scripts/test-endpoints.sh
```

### Script de Validação de Configuração

**Arquivo**: `scripts/validate-config.sh`

```bash
#!/bin/bash

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Validando configuração do projeto..."
echo ""

errors=0
warnings=0

# Verificar arquivos essenciais
echo "📁 Verificando arquivos de configuração..."

files=(
    "deploy/docker-compose.prod.yml:Compose de produção"
    "deploy/.env:Variáveis de ambiente"
    "api/deploy/Dockerfile.prod:Dockerfile da API"
    "web/deploy/Dockerfile.prod:Dockerfile do Portal"
    "web/deploy/nginx.conf:Configuração Nginx"
)

for item in "${files[@]}"; do
    IFS=':' read -r file desc <<< "$item"

    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
    else
        echo -e "  ${RED}✗${NC} $desc (não encontrado: $file)"
        ((errors++))
    fi
done

echo ""

# Verificar detecção automática no frontend
echo "🎯 Verificando detecção automática no frontend..."

if [ -f "web/suporte_dashboard_web_react/index.html" ]; then
    if grep -q "__APP_BASE_PATH__" "web/suporte_dashboard_web_react/index.html"; then
        echo -e "  ${GREEN}✓${NC} Script de detecção encontrado"
    else
        echo -e "  ${RED}✗${NC} Script de detecção não encontrado"
        ((errors++))
    fi
else
    echo -e "  ${RED}✗${NC} index.html não encontrado"
    ((errors++))
fi

echo ""

# Verificar configuração Traefik
echo "🚀 Verificando configuração Traefik..."

if [ -f "deploy/docker-compose.prod.yml" ]; then
    if grep -q "traefik.http.routers" "deploy/docker-compose.prod.yml"; then
        echo -e "  ${GREEN}✓${NC} Labels Traefik encontrados"
    else
        echo -e "  ${YELLOW}⚠${NC} Labels Traefik não encontrados"
        ((warnings++))
    fi

    if grep -q "letsencrypt" "deploy/docker-compose.prod.yml"; then
        echo -e "  ${GREEN}✓${NC} Let's Encrypt configurado"
    else
        echo -e "  ${YELLOW}⚠${NC} Let's Encrypt não configurado"
        ((warnings++))
    fi
fi

echo ""

# Verificar portas
echo "🔌 Verificando configuração de portas..."

if netstat -tuln 2>/dev/null | grep -q ":8002"; then
    echo -e "  ${GREEN}✓${NC} Porta 8002 (API) em uso"
else
    echo -e "  ${YELLOW}⚠${NC} Porta 8002 (API) livre"
fi

if netstat -tuln 2>/dev/null | grep -q ":3002"; then
    echo -e "  ${GREEN}✓${NC} Porta 3002 (Portal) em uso"
else
    echo -e "  ${YELLOW}⚠${NC} Porta 3002 (Portal) livre"
fi

echo ""

# Resumo
echo "📊 RESUMO DA VALIDAÇÃO"
echo "  Erros críticos: $errors"
echo "  Avisos: $warnings"
echo ""

if [ $errors -eq 0 ]; then
    echo -e "${GREEN}✓ Configuração válida!${NC}"
    exit 0
else
    echo -e "${RED}✗ Corrija os erros antes de continuar${NC}"
    exit 1
fi
```

---

## ✅ Checklist de Implementação

### Fase 1: Preparação (30min)

- [ ] Backup da configuração atual
- [ ] Ler documentação completa
- [ ] Identificar serviços a serem migrados
- [ ] Definir nomenclatura de paths (ex: `/api/suporte`, `/portal/suporte`)
- [ ] Mapear portas disponíveis

### Fase 2: Traefik (1h)

- [ ] Criar `deploy/docker-compose.prod.yml`
- [ ] Configurar entrypoints (80, 443)
- [ ] Configurar Let's Encrypt
- [ ] Criar diretório `./letsencrypt`
- [ ] Testar Traefik isoladamente: `docker-compose up traefik`
- [ ] Acessar dashboard: `http://IP:8080`

### Fase 3: Backend API (2h)

- [ ] Adicionar labels Traefik no docker-compose
- [ ] Configurar middlewares (stripprefix, addprefix)
- [ ] Ajustar CORS para múltiplas origens
- [ ] Configurar `root_path` no FastAPI
- [ ] Expor porta para acesso direto
- [ ] Testar acesso direto: `http://IP:8002/api/health`
- [ ] Deploy e testar via Traefik: `https://dominio/api/projeto/health`

### Fase 4: Frontend React (3h)

- [ ] Adicionar script de detecção no `index.html`
- [ ] Criar `src/config/api.ts` com detecção automática
- [ ] Ajustar `App.tsx` com basename dinâmico
- [ ] Configurar `vite.config.ts` com `base: '/'`
- [ ] Criar `nginx.conf` para SPA
- [ ] Atualizar `Dockerfile.prod`
- [ ] Adicionar labels Traefik (SEM stripprefix)
- [ ] Build e testar localmente
- [ ] Deploy e testar via Traefik

### Fase 5: Testes (1h)

- [ ] Executar `scripts/test-endpoints.sh`
- [ ] Validar acesso direto (IP:porta)
- [ ] Validar acesso via Traefik (domínio/path)
- [ ] Testar login completo
- [ ] Verificar CORS
- [ ] Validar SSL
- [ ] Testar navegação entre páginas
- [ ] Verificar console do browser (sem erros)

### Fase 6: Documentação (30min)

- [ ] Atualizar README com novas URLs
- [ ] Documentar variáveis de ambiente
- [ ] Criar guia de troubleshooting
- [ ] Adicionar exemplos de uso

---

## 🐛 Troubleshooting

### Problema: Portal não carrega via Traefik

**Sintomas**: Página em branco, 404, ou assets não carregam

**Diagnóstico**:
```bash
# 1. Verificar se Traefik está roteando
curl -I https://office.inoveon.com.br/portal/suporte/

# 2. Verificar logs do Traefik
docker logs traefik | grep suporte

# 3. Verificar se portal está acessível diretamente
curl -I http://10.0.20.11:3002/
```

**Soluções**:
- ✅ Verificar se NÃO tem stripprefix no portal
- ✅ Confirmar `base: '/'` no vite.config.ts
- ✅ Verificar script de detecção no index.html
- ✅ Confirmar nginx configurado para SPA

### Problema: API retorna 404

**Sintomas**: Endpoints retornam 404 via Traefik mas funcionam direto

**Diagnóstico**:
```bash
# Testar direto
curl http://10.0.20.11:8002/api/health

# Testar via Traefik
curl -v https://office.inoveon.com.br/api/suporte/health

# Ver o que Traefik está enviando
docker logs traefik -f
```

**Soluções**:
- ✅ Verificar ordem dos middlewares: `stripprefix,addprefix`
- ✅ Confirmar paths corretos: `/api/suporte` → `/api`
- ✅ Validar que API responde em `/api/*`
- ✅ Verificar `root_path` no FastAPI

### Problema: CORS Error

**Sintomas**: Console do browser mostra erro CORS

**Diagnóstico**:
```bash
# Testar CORS com curl
curl -H "Origin: https://office.inoveon.com.br" \
  -H "Access-Control-Request-Method: POST" \
  -X OPTIONS \
  https://office.inoveon.com.br/api/suporte/auth/login \
  -v
```

**Soluções**:
- ✅ Adicionar origem no CORS da API
- ✅ Verificar `allow_credentials=True`
- ✅ Confirmar headers corretos

### Problema: Certificado SSL não gera

**Sintomas**: HTTPS não funciona, navegador reclama de certificado

**Diagnóstico**:
```bash
# Verificar logs do Let's Encrypt
docker logs traefik | grep acme

# Testar conectividade HTTP (porta 80)
curl http://office.inoveon.com.br/
```

**Soluções**:
- ✅ Verificar se DNS está correto
- ✅ Confirmar portas 80/443 abertas no firewall
- ✅ Validar email no Let's Encrypt
- ✅ Limpar `acme.json` e reiniciar: `rm letsencrypt/acme.json && docker-compose restart traefik`

---

## 📚 Referências

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [FastAPI Behind a Proxy](https://fastapi.tiangolo.com/advanced/behind-a-proxy/)
- [React Router Basename](https://reactrouter.com/en/main/routers/create-browser-router#basename)
- [Vite Base Public Path](https://vitejs.dev/guide/build.html#public-base-path)
- [Let's Encrypt](https://letsencrypt.org/)

---

**Versão**: 1.0
**Data**: Janeiro 2025
**Mantido por**: Equipe DevOps Inoveon
