# 📋 Templates de Configuração - Deploy Híbrido

Este documento contém templates prontos para usar em qualquer projeto com deploy híbrido.

## 📑 Índice

1. [Template Traefik](#template-traefik)
2. [Template Backend FastAPI](#template-backend-fastapi)
3. [Template Frontend React/Vite](#template-frontend-reactvite)
4. [Template Nginx](#template-nginx)
5. [Template Docker Compose](#template-docker-compose)
6. [Template Variáveis de Ambiente](#template-variáveis-de-ambiente)

---

## 🚀 Template Traefik

### docker-compose.traefik.yml

```yaml
version: '3.8'

services:
  traefik:
    image: traefik:v3.1
    container_name: traefik
    restart: unless-stopped

    command:
      # ============================================
      # API e Dashboard
      # ============================================
      - "--api.dashboard=true"
      - "--api.insecure=false"  # Desabilita porta 8080 sem auth (use apenas em dev)

      # ============================================
      # Providers
      # ============================================
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=traefik_net"

      # ============================================
      # Entrypoints
      # ============================================
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"

      # Redirect HTTP → HTTPS (produção)
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      - "--entrypoints.web.http.redirections.entrypoint.permanent=true"

      # ============================================
      # SSL/TLS Automático (Let's Encrypt)
      # ============================================
      - "--certificatesresolvers.letsencrypt.acme.email=${LETSENCRYPT_EMAIL}"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"

      # ============================================
      # Logs
      # ============================================
      - "--log.level=${TRAEFIK_LOG_LEVEL:-INFO}"
      - "--accesslog=true"
      - "--accesslog.filepath=/logs/access.log"
      - "--log.filepath=/logs/traefik.log"

    ports:
      - "80:80"       # HTTP
      - "443:443"     # HTTPS
      - "8080:8080"   # Dashboard (proteger em produção!)

    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt
      - ./logs:/logs

    networks:
      - traefik_net

    labels:
      - "traefik.enable=true"

      # ============================================
      # Dashboard do Traefik
      # ============================================
      - "traefik.http.routers.dashboard.rule=Host(`traefik.${DOMAIN}`)"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
      - "traefik.http.routers.dashboard.tls.certresolver=letsencrypt"
      - "traefik.http.routers.dashboard.service=api@internal"

      # Autenticação básica (opcional - descomente e configure)
      # - "traefik.http.routers.dashboard.middlewares=dashboard-auth"
      # - "traefik.http.middlewares.dashboard-auth.basicauth.users=${DASHBOARD_AUTH}"

    healthcheck:
      test: ["CMD", "traefik", "healthcheck", "--ping"]
      interval: 30s
      timeout: 5s
      retries: 3

networks:
  traefik_net:
    name: traefik_net
    driver: bridge
```

### .env para Traefik

```bash
# Domínio principal
DOMAIN=office.inoveon.com.br

# Let's Encrypt
LETSENCRYPT_EMAIL=admin@inoveon.com.br

# Logs
TRAEFIK_LOG_LEVEL=INFO

# Dashboard Auth (opcional)
# Gerar senha: echo $(htpasswd -nb admin senha) | sed -e s/\\$/\\$\\$/g
# DASHBOARD_AUTH=admin:$$apr1$$xyz...
```

---

## 🐍 Template Backend FastAPI

### app/main.py

```python
"""
Template FastAPI com suporte a deploy híbrido

Funciona em:
- Desenvolvimento: http://IP:PORTA/api/endpoint
- Produção: https://DOMINIO/api/PROJETO/endpoint
"""

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import os
import logging

# Configuração de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


# ============================================
# Lifespan Events
# ============================================
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Eventos de inicialização e finalização"""
    # Startup
    logger.info("🚀 Iniciando aplicação...")
    logger.info(f"   Root Path: {app.root_path or '(vazio)'}")
    logger.info(f"   CORS Origins: {CORS_ORIGINS}")

    yield

    # Shutdown
    logger.info("🛑 Finalizando aplicação...")


# ============================================
# Configurações
# ============================================
PROJECT_NAME = os.getenv("PROJECT_NAME", "API Template")
VERSION = os.getenv("VERSION", "1.0.0")
ROOT_PATH = os.getenv("ROOT_PATH", "")

# CORS - Adicione todas as origens necessárias
CORS_ORIGINS = [
    "http://localhost:3000",
    "http://localhost:5173",
    "http://10.0.20.11:3002",
    f"https://{os.getenv('DOMAIN', 'office.inoveon.com.br')}",
]


# ============================================
# Aplicação FastAPI
# ============================================
app = FastAPI(
    title=PROJECT_NAME,
    version=VERSION,
    description="API com suporte a deploy híbrido (acesso direto + proxy)",
    root_path=ROOT_PATH,
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json",
    lifespan=lifespan
)


# ============================================
# Middleware CORS
# ============================================
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================
# Middleware de Logging (opcional)
# ============================================
@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log de todas as requisições"""
    logger.info(f"{request.method} {request.url.path}")

    # Headers úteis para debug
    forwarded_for = request.headers.get("X-Forwarded-For")
    forwarded_proto = request.headers.get("X-Forwarded-Proto")

    if forwarded_for:
        logger.debug(f"  X-Forwarded-For: {forwarded_for}")
    if forwarded_proto:
        logger.debug(f"  X-Forwarded-Proto: {forwarded_proto}")

    response = await call_next(request)
    return response


# ============================================
# Exception Handlers
# ============================================
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Handler global de exceções"""
    logger.error(f"Erro não tratado: {exc}", exc_info=True)

    return JSONResponse(
        status_code=500,
        content={
            "detail": "Erro interno do servidor",
            "type": "internal_server_error"
        }
    )


# ============================================
# Rotas Básicas
# ============================================
@app.get("/")
async def root():
    """Rota raiz - informações da API"""
    return {
        "message": f"Bem-vindo à {PROJECT_NAME}",
        "version": VERSION,
        "docs": f"{ROOT_PATH}/api/docs" if ROOT_PATH else "/api/docs",
        "health": f"{ROOT_PATH}/api/health" if ROOT_PATH else "/api/health",
    }


@app.get("/api/health")
async def health_check():
    """
    Health check para monitoramento

    Acesso:
    - Direto: http://IP:PORTA/api/health
    - Traefik: https://DOMINIO/api/PROJETO/health
    """
    return {
        "status": "healthy",
        "service": PROJECT_NAME,
        "version": VERSION,
        "root_path": ROOT_PATH or "(vazio)"
    }


# ============================================
# Rotas de Exemplo (Auth)
# ============================================
from fastapi import HTTPException
from pydantic import BaseModel


class LoginRequest(BaseModel):
    """Schema de login"""
    email: str
    password: str


class LoginResponse(BaseModel):
    """Schema de resposta de login"""
    access_token: str
    token_type: str = "bearer"


@app.post("/api/auth/login", response_model=LoginResponse)
async def login(credentials: LoginRequest):
    """
    Endpoint de login

    Acesso:
    - Direto: http://IP:PORTA/api/auth/login
    - Traefik: https://DOMINIO/api/PROJETO/auth/login
    """
    logger.info(f"Tentativa de login: {credentials.email}")

    # Exemplo simples (substitua por lógica real)
    if credentials.email == "admin@test.com" and credentials.password == "admin123":
        return LoginResponse(access_token="exemplo-token-jwt")

    raise HTTPException(
        status_code=401,
        detail="Credenciais inválidas"
    )


@app.get("/api/auth/me")
async def get_current_user():
    """
    Retorna usuário autenticado

    Acesso:
    - Direto: http://IP:PORTA/api/auth/me
    - Traefik: https://DOMINIO/api/PROJETO/auth/me
    """
    # Exemplo (adicione validação de token real)
    return {
        "id": 1,
        "email": "admin@test.com",
        "name": "Administrador"
    }


# ============================================
# Entry Point (para execução direta)
# ============================================
if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=int(os.getenv("PORT", "8000")),
        reload=os.getenv("ENVIRONMENT", "production") == "development",
        log_level="info"
    )
```

### Dockerfile.prod

```dockerfile
# ============================================
# Build Stage
# ============================================
FROM python:3.11-slim AS builder

WORKDIR /app

# Instalar dependências de build
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copiar requirements
COPY requirements.txt .

# Instalar dependências Python
RUN pip install --no-cache-dir --user -r requirements.txt


# ============================================
# Production Stage
# ============================================
FROM python:3.11-slim

WORKDIR /app

# Copiar dependências do builder
COPY --from=builder /root/.local /root/.local

# Copiar código da aplicação
COPY . .

# Adicionar .local/bin ao PATH
ENV PATH=/root/.local/bin:$PATH

# Variáveis de ambiente
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PORT=8000
ENV ROOT_PATH=""

# Expor porta
EXPOSE $PORT

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:${PORT}/api/health')"

# Comando de inicialização
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"]
```

### requirements.txt

```txt
# FastAPI e servidor
fastapi==0.109.0
uvicorn[standard]==0.27.0
python-multipart==0.0.6

# Validação
pydantic==2.5.3
pydantic-settings==2.1.0
email-validator==2.1.0

# Banco de dados (exemplo com PostgreSQL)
sqlalchemy==2.0.25
asyncpg==0.29.0
alembic==1.13.1

# Autenticação
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4

# Utilidades
python-dotenv==1.0.0
httpx==0.26.0

# Monitoramento (opcional)
prometheus-fastapi-instrumentator==6.1.0
```

### .env.example

```bash
# ============================================
# Configurações da Aplicação
# ============================================
PROJECT_NAME=API Template
VERSION=1.0.0
ENVIRONMENT=production

# Porta (para desenvolvimento local)
PORT=8000

# Root path (para quando estiver atrás de proxy)
# Deixe vazio para acesso direto
ROOT_PATH=

# ============================================
# Banco de Dados
# ============================================
DATABASE_URL=postgresql://user:password@localhost:5432/dbname
DATABASE_URL_ASYNC=postgresql+asyncpg://user:password@localhost:5432/dbname

# ============================================
# Segurança
# ============================================
SECRET_KEY=your-super-secret-key-change-this-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# ============================================
# CORS
# ============================================
DOMAIN=office.inoveon.com.br

# ============================================
# Redis (opcional)
# ============================================
REDIS_URL=redis://localhost:6379/0
```

---

## ⚛️ Template Frontend React/Vite

### index.html (com detecção automática)

```html
<!DOCTYPE html>
<html lang="pt-BR">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Portal - Inoveon</title>

    <script>
      /**
       * ============================================
       * DETECÇÃO AUTOMÁTICA DE AMBIENTE
       * ============================================
       *
       * Este script detecta automaticamente o ambiente baseado na URL
       * e configura as variáveis globais necessárias.
       *
       * NÃO É NECESSÁRIO buildar separadamente para dev/prod!
       */

      (function() {
        'use strict';

        // ============================================
        // CONFIGURAÇÃO DO PROJETO
        // ============================================

        // Lista de prefixos válidos para este projeto
        // Adicione aqui os paths que sua aplicação pode usar
        const VALID_PREFIXES = [
          'portal/suporte',
          'suporte',
          'portal/projeto',
          'projeto'
        ];

        // Servidor de desenvolvimento (acesso direto)
        const DEV_API_HOST = 'http://10.0.20.11:8002';

        // ============================================
        // DETECÇÃO AUTOMÁTICA
        // ============================================

        const pathname = window.location.pathname;
        const hostname = window.location.hostname;
        const protocol = window.location.protocol;

        console.log('[Config] Detectando ambiente...', {
          pathname,
          hostname,
          protocol
        });

        // Detecta basename a partir do pathname
        let basePath = '';
        for (const prefix of VALID_PREFIXES) {
          const normalizedPrefix = '/' + prefix.replace(/^\//, '').replace(/\/$/, '');

          if (pathname === normalizedPrefix || pathname.startsWith(normalizedPrefix + '/')) {
            basePath = normalizedPrefix;
            console.log('[Config] Basename detectado:', basePath);
            break;
          }
        }

        // Detecta API URL
        let apiUrl;
        if (basePath) {
          // Produção via proxy
          apiUrl = `${protocol}//${hostname}/api${basePath}`;
        } else if (hostname === 'localhost' || hostname === '127.0.0.1') {
          // Desenvolvimento local
          apiUrl = 'http://localhost:8000/api';
        } else {
          // Desenvolvimento no servidor (acesso direto)
          apiUrl = `${DEV_API_HOST}/api`;
        }

        // WebSocket URL
        const wsUrl = apiUrl.replace(/^http/, 'ws') + '/ws';

        // Detecta ambiente
        const environment = basePath ? 'production' : 'development';

        // ============================================
        // CONFIGURAÇÃO GLOBAL
        // ============================================

        window.__APP_BASE_PATH__ = basePath;
        window.__APP_CONFIG__ = {
          basePath: basePath,
          apiUrl: apiUrl,
          wsUrl: wsUrl,
          environment: environment,
          version: '1.0.0'
        };

        // ============================================
        // LOG DE DEBUG
        // ============================================

        console.log('[Config] Configuração detectada:', {
          basePath: basePath || '(raiz)',
          apiUrl: apiUrl,
          wsUrl: wsUrl,
          environment: environment
        });

        // ============================================
        // TAG BASE (para assets)
        // ============================================

        if (basePath) {
          const baseTag = document.createElement('base');
          baseTag.href = basePath + '/';
          document.head.insertBefore(baseTag, document.head.firstChild);
          console.log('[Config] Tag <base> criada:', baseTag.href);
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

### src/config/api.ts

```typescript
/**
 * ============================================
 * CONFIGURAÇÃO DA API
 * ============================================
 *
 * Cliente Axios com detecção automática de ambiente
 */

import axios, { AxiosError, InternalAxiosRequestConfig } from 'axios';

// ============================================
// TIPOS
// ============================================

declare global {
  interface Window {
    __APP_BASE_PATH__?: string;
    __APP_CONFIG__?: {
      basePath: string;
      apiUrl: string;
      wsUrl: string;
      environment: string;
      version: string;
    };
  }
}

// ============================================
// CONFIGURAÇÃO
// ============================================

// Pega configuração detectada no index.html
const appConfig = window.__APP_CONFIG__ || {
  apiUrl: 'http://localhost:8000/api',
  basePath: '',
  wsUrl: 'ws://localhost:8000/api/ws',
  environment: 'development',
  version: '1.0.0'
};

console.log('[API] Inicializando com configuração:', appConfig);

// ============================================
// CLIENTE AXIOS
// ============================================

export const api = axios.create({
  baseURL: appConfig.apiUrl,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json'
  }
});

// ============================================
// INTERCEPTORS - REQUEST
// ============================================

api.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    // Adiciona token de autenticação
    const token = localStorage.getItem('access_token');
    if (token && config.headers) {
      config.headers.Authorization = `Bearer ${token}`;
    }

    // Log de debug
    console.log('[API Request]', {
      method: config.method?.toUpperCase(),
      url: config.url,
      baseURL: config.baseURL,
      fullUrl: `${config.baseURL}${config.url}`
    });

    return config;
  },
  (error: AxiosError) => {
    console.error('[API Request Error]', error);
    return Promise.reject(error);
  }
);

// ============================================
// INTERCEPTORS - RESPONSE
// ============================================

api.interceptors.response.use(
  (response) => {
    console.log('[API Response]', {
      status: response.status,
      url: response.config.url,
      data: response.data
    });

    return response;
  },
  (error: AxiosError) => {
    console.error('[API Response Error]', {
      status: error.response?.status,
      url: error.config?.url,
      message: error.message,
      data: error.response?.data
    });

    // Redireciona para login se 401
    if (error.response?.status === 401) {
      console.warn('[API] Token inválido ou expirado, redirecionando para login...');
      localStorage.removeItem('access_token');
      window.location.href = appConfig.basePath + '/login';
    }

    return Promise.reject(error);
  }
);

// ============================================
// HELPERS DE AUTENTICAÇÃO
// ============================================

export const authApi = {
  /**
   * Login
   */
  login: async (email: string, password: string) => {
    const response = await api.post('/auth/login', { email, password });
    return response.data;
  },

  /**
   * Logout
   */
  logout: () => {
    console.log('[Auth] Fazendo logout...');
    localStorage.removeItem('access_token');
    window.location.href = appConfig.basePath + '/login';
  },

  /**
   * Obter usuário atual
   */
  getCurrentUser: async () => {
    const response = await api.get('/auth/me');
    return response.data;
  },

  /**
   * Verificar se está autenticado
   */
  isAuthenticated: (): boolean => {
    return !!localStorage.getItem('access_token');
  }
};

// ============================================
// EXPORT
// ============================================

export { appConfig };
export default api;
```

### src/App.tsx

```typescript
import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';

// Páginas
import { Home } from './pages/Home';
import { Login } from './pages/Login';
import { Dashboard } from './pages/Dashboard';

// Componentes
import { Layout } from './components/Layout';
import { ProtectedRoute } from './components/ProtectedRoute';

function App() {
  // ============================================
  // Configuração do Router
  // ============================================

  // Pega basename detectado automaticamente
  const basename = window.__APP_BASE_PATH__ || '';

  console.log('[App] Inicializando com basename:', basename || '(raiz)');
  console.log('[App] Configuração:', window.__APP_CONFIG__);

  return (
    <BrowserRouter basename={basename}>
      <Routes>
        {/* Rotas públicas */}
        <Route path="/" element={<Layout />}>
          <Route index element={<Home />} />
          <Route path="login" element={<Login />} />

          {/* Rotas protegidas */}
          <Route element={<ProtectedRoute />}>
            <Route path="dashboard" element={<Dashboard />} />
          </Route>

          {/* 404 */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default App;
```

### src/components/ProtectedRoute.tsx

```typescript
import React from 'react';
import { Navigate, Outlet } from 'react-router-dom';
import { authApi } from '../config/api';

export const ProtectedRoute: React.FC = () => {
  const isAuthenticated = authApi.isAuthenticated();

  if (!isAuthenticated) {
    console.log('[ProtectedRoute] Não autenticado, redirecionando para login');
    return <Navigate to="/login" replace />;
  }

  return <Outlet />;
};
```

### vite.config.ts

```typescript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],

  // ============================================
  // BASE PATH
  // ============================================
  // IMPORTANTE: Deixar vazio!
  // A detecção é feita em runtime no index.html
  base: '/',

  // ============================================
  // RESOLVE
  // ============================================
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },

  // ============================================
  // SERVER (Desenvolvimento)
  // ============================================
  server: {
    port: 3002,
    host: '0.0.0.0',

    // Proxy para API (opcional - facilita desenvolvimento)
    proxy: {
      '/api': {
        target: 'http://10.0.20.11:8002',
        changeOrigin: true,
        secure: false,
        rewrite: (path) => {
          console.log('[Proxy] Reescrevendo:', path);
          return path;
        }
      }
    }
  },

  // ============================================
  // BUILD (Produção)
  // ============================================
  build: {
    outDir: 'dist',
    sourcemap: false,
    minify: 'terser',

    // Otimizações
    rollupOptions: {
      output: {
        manualChunks: {
          'react-vendor': ['react', 'react-dom', 'react-router-dom'],
          'ui-vendor': ['axios']
        }
      }
    }
  }
})
```

### package.json

```json
{
  "name": "portal-template",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview",
    "lint": "eslint . --ext ts,tsx",
    "format": "prettier --write \"src/**/*.{ts,tsx,css}\""
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.21.1",
    "axios": "^1.6.5"
  },
  "devDependencies": {
    "@types/react": "^18.2.48",
    "@types/react-dom": "^18.2.18",
    "@vitejs/plugin-react": "^4.2.1",
    "typescript": "^5.3.3",
    "vite": "^5.0.11",
    "eslint": "^8.56.0",
    "prettier": "^3.2.4"
  }
}
```

---

## 🌐 Template Nginx

### nginx.conf (para SPA)

```nginx
# ============================================
# Configuração Nginx para SPA (React/Vue/Angular)
# com suporte a deploy híbrido
# ============================================

server {
    listen 3002;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    # ============================================
    # Logs
    # ============================================
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log warn;

    # ============================================
    # Gzip Compression
    # ============================================
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/rss+xml
        font/truetype
        font/opentype
        application/vnd.ms-fontobject
        image/svg+xml;

    # ============================================
    # Headers de Segurança
    # ============================================
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # ============================================
    # SPA - Try Files (IMPORTANTE!)
    # ============================================
    # Todos os paths devem retornar index.html
    # para o React Router funcionar
    location / {
        try_files $uri $uri/ /index.html;
    }

    # ============================================
    # Cache de Assets Estáticos
    # ============================================
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|map)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # ============================================
    # Não Cachear o index.html
    # ============================================
    location = /index.html {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }

    # ============================================
    # Health Check
    # ============================================
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
```

---

## 🐳 Template Docker Compose Completo

### docker-compose.prod.yml

```yaml
version: '3.8'

# ============================================
# SERVICES
# ============================================

services:

  # ============================================
  # Traefik (Proxy Reverso)
  # ============================================
  traefik:
    image: traefik:v3.1
    container_name: traefik
    restart: unless-stopped

    command:
      - "--api.dashboard=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      - "--certificatesresolvers.letsencrypt.acme.email=${LETSENCRYPT_EMAIL}"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
      - "--log.level=INFO"
      - "--accesslog=true"

    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"

    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt

    networks:
      - traefik_net

    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(`traefik.${DOMAIN}`)"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
      - "traefik.http.routers.dashboard.tls.certresolver=letsencrypt"
      - "traefik.http.routers.dashboard.service=api@internal"


  # ============================================
  # Backend API (FastAPI)
  # ============================================
  api:
    build:
      context: ../api/${PROJECT_NAME}_api_fastapi
      dockerfile: ../api/deploy/Dockerfile.prod
    container_name: ${PROJECT_NAME}-api
    restart: unless-stopped

    ports:
      - "${API_PORT}:${API_PORT}"  # Acesso direto

    environment:
      - PROJECT_NAME=${PROJECT_NAME}
      - DATABASE_URL=${DATABASE_URL}
      - SECRET_KEY=${SECRET_KEY}
      - PORT=${API_PORT}
      - ROOT_PATH=
      - DOMAIN=${DOMAIN}

    networks:
      - traefik_net
      - backend_net

    depends_on:
      - db

    labels:
      - "traefik.enable=true"

      # HTTPS Router
      - "traefik.http.routers.${PROJECT_NAME}-api.rule=Host(`${DOMAIN}`) && PathPrefix(`/api/${PROJECT_NAME}`)"
      - "traefik.http.routers.${PROJECT_NAME}-api.entrypoints=websecure"
      - "traefik.http.routers.${PROJECT_NAME}-api.tls=true"
      - "traefik.http.routers.${PROJECT_NAME}-api.tls.certresolver=letsencrypt"
      - "traefik.http.routers.${PROJECT_NAME}-api.priority=2"

      # Middlewares
      - "traefik.http.middlewares.${PROJECT_NAME}-api-strip.stripprefix.prefixes=/api/${PROJECT_NAME}"
      - "traefik.http.middlewares.${PROJECT_NAME}-api-add.addprefix.prefix=/api"
      - "traefik.http.routers.${PROJECT_NAME}-api.middlewares=${PROJECT_NAME}-api-strip,${PROJECT_NAME}-api-add"

      # Service
      - "traefik.http.services.${PROJECT_NAME}-api.loadbalancer.server.port=${API_PORT}"


  # ============================================
  # Frontend Portal (React/Vite)
  # ============================================
  portal:
    build:
      context: ../web/${PROJECT_NAME}_portal_react
      dockerfile: ../web/deploy/Dockerfile.prod
    container_name: ${PROJECT_NAME}-portal
    restart: unless-stopped

    ports:
      - "${PORTAL_PORT}:${PORTAL_PORT}"  # Acesso direto

    networks:
      - traefik_net

    labels:
      - "traefik.enable=true"

      # HTTPS Router
      - "traefik.http.routers.${PROJECT_NAME}-portal.rule=Host(`${DOMAIN}`) && PathPrefix(`/portal/${PROJECT_NAME}`)"
      - "traefik.http.routers.${PROJECT_NAME}-portal.entrypoints=websecure"
      - "traefik.http.routers.${PROJECT_NAME}-portal.tls=true"
      - "traefik.http.routers.${PROJECT_NAME}-portal.tls.certresolver=letsencrypt"
      - "traefik.http.routers.${PROJECT_NAME}-portal.priority=2"

      # Service (SEM StripPrefix!)
      - "traefik.http.services.${PROJECT_NAME}-portal.loadbalancer.server.port=${PORTAL_PORT}"


  # ============================================
  # Banco de Dados (PostgreSQL)
  # ============================================
  db:
    image: postgres:16-alpine
    container_name: ${PROJECT_NAME}-db
    restart: unless-stopped

    environment:
      - POSTGRES_USER=${DB_USER}
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - POSTGRES_DB=${DB_NAME}

    volumes:
      - db_data:/var/lib/postgresql/data

    networks:
      - backend_net

    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5


  # ============================================
  # Redis (Cache/Queue)
  # ============================================
  redis:
    image: redis:7-alpine
    container_name: ${PROJECT_NAME}-redis
    restart: unless-stopped

    command: redis-server --appendonly yes

    volumes:
      - redis_data:/data

    networks:
      - backend_net

    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5


# ============================================
# NETWORKS
# ============================================

networks:
  traefik_net:
    name: traefik_net
    driver: bridge

  backend_net:
    name: backend_net
    driver: bridge


# ============================================
# VOLUMES
# ============================================

volumes:
  db_data:
    name: ${PROJECT_NAME}_db_data

  redis_data:
    name: ${PROJECT_NAME}_redis_data
```

### .env (para Docker Compose)

```bash
# ============================================
# Configurações do Projeto
# ============================================
PROJECT_NAME=suporte
DOMAIN=office.inoveon.com.br

# ============================================
# Portas
# ============================================
API_PORT=8002
PORTAL_PORT=3002

# ============================================
# Banco de Dados
# ============================================
DB_USER=suporte_user
DB_PASSWORD=suporte_pass_change_in_production
DB_NAME=suporte_chamados
DATABASE_URL=postgresql://${DB_USER}:${DB_PASSWORD}@db:5432/${DB_NAME}

# ============================================
# Segurança
# ============================================
SECRET_KEY=super-secret-key-change-this-in-production-use-openssl-rand
LETSENCRYPT_EMAIL=admin@inoveon.com.br

# ============================================
# Redis
# ============================================
REDIS_URL=redis://redis:6379/0
```

---

## 📝 Resumo de Uso dos Templates

### 1. Novo Projeto do Zero

```bash
# Copiar templates
cp docs/TEMPLATES-CONFIGURACAO.md seu-projeto/

# Substituir variáveis
sed -i 's/PROJECT_NAME=suporte/PROJECT_NAME=seuprojeto/g' .env
sed -i 's/8002/8010/g' .env  # Mudar porta da API
sed -i 's/3002/3010/g' .env  # Mudar porta do Portal

# Deploy
docker-compose -f deploy/docker-compose.prod.yml up -d
```

### 2. Adaptar Projeto Existente

1. Adicionar script de detecção no `index.html`
2. Criar `src/config/api.ts` com detecção automática
3. Ajustar `App.tsx` com basename dinâmico
4. Adicionar labels Traefik no docker-compose
5. Testar!

---

**Versão**: 1.0
**Data**: Janeiro 2025
**Mantido por**: Equipe DevOps Inoveon
