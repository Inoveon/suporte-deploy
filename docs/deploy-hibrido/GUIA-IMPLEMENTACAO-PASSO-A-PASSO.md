# 📖 Guia de Implementação Passo a Passo - Deploy Híbrido

Este guia detalha **exatamente** o que fazer para implementar deploy híbrido em um projeto existente ou novo.

## 📋 Índice

1. [Pré-requisitos](#pré-requisitos)
2. [Fase 1: Preparação (30min)](#fase-1-preparação-30min)
3. [Fase 2: Configurar Traefik (1h)](#fase-2-configurar-traefik-1h)
4. [Fase 3: Adaptar Backend (2h)](#fase-3-adaptar-backend-2h)
5. [Fase 4: Adaptar Frontend (3h)](#fase-4-adaptar-frontend-3h)
6. [Fase 5: Deploy e Testes (1h)](#fase-5-deploy-e-testes-1h)
7. [Troubleshooting](#troubleshooting)

**Tempo total estimado**: 7-8 horas

---

## ✅ Pré-requisitos

Antes de começar, certifique-se de ter:

- [ ] Docker e Docker Compose instalados
- [ ] Acesso ao servidor (SSH)
- [ ] Domínio configurado (ex: `office.inoveon.com.br`)
- [ ] DNS apontando para o servidor
- [ ] Portas 80 e 443 abertas no firewall
- [ ] Conhecimento básico de Docker, React e FastAPI

---

## 🚀 Fase 1: Preparação (30min)

### 1.1. Backup do Projeto Atual

```bash
# Criar backup completo
cd /Users/leechardes/Projetos/suporte
tar -czf ../suporte-backup-$(date +%Y%m%d).tar.gz .

# Verificar backup criado
ls -lh ../suporte-backup-*.tar.gz
```

### 1.2. Documentar Configuração Atual

```bash
# Anotar portas em uso
netstat -tuln | grep LISTEN > current-ports.txt

# Anotar containers rodando
docker ps > current-containers.txt

# Anotar configuração de rede
docker network ls > current-networks.txt
```

### 1.3. Definir Nomenclatura

Escolha os paths que serão usados:

```bash
# Exemplo para projeto "suporte"
API_PATH="/api/suporte"
PORTAL_PATH="/portal/suporte"

# Exemplo para projeto "backup"
API_PATH="/api/backup"
PORTAL_PATH="/portal/backup"
```

**📝 Anote suas escolhas:**
- Nome do projeto: _______________
- Path da API: _______________
- Path do Portal: _______________
- Porta da API (acesso direto): _______________
- Porta do Portal (acesso direto): _______________

### 1.4. Criar Estrutura de Diretórios

```bash
cd /Users/leechardes/Projetos/suporte

# Criar diretórios se não existirem
mkdir -p deploy/letsencrypt
mkdir -p api/deploy
mkdir -p web/deploy
mkdir -p scripts
mkdir -p docs

# Dar permissões corretas
chmod 600 deploy/letsencrypt  # Let's Encrypt precisa dessas permissões
```

✅ **Checkpoint 1**: Estrutura de diretórios criada

---

## 🔧 Fase 2: Configurar Traefik (1h)

### 2.1. Criar docker-compose do Traefik

Copie o template completo:

```bash
# Usar template da documentação
cp docs/TEMPLATES-CONFIGURACAO.md deploy/docker-compose.traefik.yml

# Ou criar manualmente
nano deploy/docker-compose.prod.yml
```

**Cole o conteúdo do template Traefik** (veja [TEMPLATES-CONFIGURACAO.md](TEMPLATES-CONFIGURACAO.md#template-traefik))

### 2.2. Criar arquivo .env

```bash
nano deploy/.env
```

**Conteúdo mínimo**:

```bash
# Projeto
PROJECT_NAME=suporte
DOMAIN=office.inoveon.com.br

# Let's Encrypt
LETSENCRYPT_EMAIL=admin@inoveon.com.br

# Portas
API_PORT=8002
PORTAL_PORT=3002

# Banco de dados
DB_USER=suporte_user
DB_PASSWORD=TROCAR_SENHA_AQUI
DB_NAME=suporte_chamados
DATABASE_URL=postgresql://${DB_USER}:${DB_PASSWORD}@db:5432/${DB_NAME}

# Segurança
SECRET_KEY=$(openssl rand -hex 32)

# Redis
REDIS_URL=redis://redis:6379/0
```

**⚠️ IMPORTANTE**: Gere uma SECRET_KEY real:

```bash
openssl rand -hex 32
```

### 2.3. Testar Traefik Isoladamente

```bash
cd deploy

# Subir apenas o Traefik
docker-compose up traefik

# Em outro terminal, verificar se está rodando
curl http://localhost:8080/api/http/routers

# Verificar logs
docker logs traefik -f
```

**Deve mostrar**: Traefik iniciado, dashboard acessível em `http://IP:8080`

### 2.4. Verificar DNS

```bash
# Verificar se domínio aponta para o servidor
nslookup office.inoveon.com.br

# Deve retornar o IP do servidor (ex: 10.0.20.11)
```

✅ **Checkpoint 2**: Traefik rodando, dashboard acessível

---

## 🐍 Fase 3: Adaptar Backend (2h)

### 3.1. Criar/Atualizar app/main.py

```bash
cd api/suporte_chamados_api_fastapi
nano app/main.py
```

**Adicione/Modifique**:

```python
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Detecta root_path
ROOT_PATH = os.getenv("ROOT_PATH", "")

app = FastAPI(
    title="Suporte API",
    version="1.0.0",
    root_path=ROOT_PATH,  # ← ADICIONAR
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json"
)

# CORS - ADICIONAR TODAS AS ORIGENS
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3002",
        "http://localhost:5173",
        "http://10.0.20.11:3002",
        "https://office.inoveon.com.br",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health check - ADICIONAR
@app.get("/api/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "suporte-api",
        "root_path": ROOT_PATH or "(vazio)"
    }
```

### 3.2. Criar/Atualizar Dockerfile.prod

```bash
nano api/deploy/Dockerfile.prod
```

**Cole o template** (veja [TEMPLATES-CONFIGURACAO.md](TEMPLATES-CONFIGURACAO.md#dockerfileprod))

### 3.3. Adicionar Labels Traefik

```bash
nano deploy/docker-compose.prod.yml
```

**Adicione o serviço da API**:

```yaml
services:
  # ... (traefik já está aqui)

  suporte-api:
    build:
      context: ../api/suporte_chamados_api_fastapi
      dockerfile: deploy/Dockerfile.prod
    container_name: suporte-api
    restart: unless-stopped

    ports:
      - "8002:8002"  # ← Acesso direto

    environment:
      - DATABASE_URL=${DATABASE_URL}
      - SECRET_KEY=${SECRET_KEY}
      - PORT=8002
      - ROOT_PATH=  # ← Vazio!

    networks:
      - traefik_net
      - backend_net

    labels:
      - "traefik.enable=true"

      # HTTPS Router
      - "traefik.http.routers.suporte-api.rule=Host(`office.inoveon.com.br`) && PathPrefix(`/api/suporte`)"
      - "traefik.http.routers.suporte-api.entrypoints=websecure"
      - "traefik.http.routers.suporte-api.tls=true"
      - "traefik.http.routers.suporte-api.tls.certresolver=letsencrypt"

      # Middlewares
      - "traefik.http.middlewares.suporte-api-strip.stripprefix.prefixes=/api/suporte"
      - "traefik.http.middlewares.suporte-api-add.addprefix.prefix=/api"
      - "traefik.http.routers.suporte-api.middlewares=suporte-api-strip,suporte-api-add"

      # Service
      - "traefik.http.services.suporte-api.loadbalancer.server.port=8002"
```

### 3.4. Testar API

```bash
# Build e subir
docker-compose up --build suporte-api

# Em outro terminal, testar acesso direto
curl http://10.0.20.11:8002/api/health

# Deve retornar: {"status":"healthy"...}
```

✅ **Checkpoint 3**: API acessível diretamente na porta 8002

---

## ⚛️ Fase 4: Adaptar Frontend (3h)

### 4.1. Atualizar index.html

```bash
cd web/suporte_dashboard_web_react
nano index.html
```

**ANTES do `<div id="root"></div>`, adicione o script de detecção**:

```html
<script>
  (function() {
    'use strict';

    const VALID_PREFIXES = ['portal/suporte', 'suporte'];
    const DEV_API_HOST = 'http://10.0.20.11:8002';

    const pathname = window.location.pathname;
    const hostname = window.location.hostname;
    const protocol = window.location.protocol;

    let basePath = '';
    for (const prefix of VALID_PREFIXES) {
      const normalizedPrefix = '/' + prefix.replace(/^\//, '');
      if (pathname.startsWith(normalizedPrefix + '/') || pathname === normalizedPrefix) {
        basePath = normalizedPrefix;
        break;
      }
    }

    let apiUrl;
    if (basePath) {
      apiUrl = `${protocol}//${hostname}/api/suporte`;
    } else if (hostname === 'localhost' || hostname === '127.0.0.1') {
      apiUrl = 'http://localhost:8000/api';
    } else {
      apiUrl = `${DEV_API_HOST}/api`;
    }

    window.__APP_BASE_PATH__ = basePath;
    window.__APP_CONFIG__ = {
      basePath: basePath,
      apiUrl: apiUrl,
      environment: basePath ? 'production' : 'development'
    };

    console.log('[Config]', window.__APP_CONFIG__);

    if (basePath) {
      const baseTag = document.createElement('base');
      baseTag.href = basePath + '/';
      document.head.insertBefore(baseTag, document.head.firstChild);
    }
  })();
</script>
```

### 4.2. Criar/Atualizar src/config/api.ts

```bash
# TypeScript
nano src/config/api.ts

# Ou JavaScript
nano src/config/api.js
```

**Cole o template completo** (veja [TEMPLATES-CONFIGURACAO.md](TEMPLATES-CONFIGURACAO.md#srcconfigapits))

### 4.3. Atualizar App.tsx

```bash
nano src/App.tsx  # ou App.jsx
```

**Modifique o BrowserRouter**:

```typescript
import { BrowserRouter } from 'react-router-dom';

function App() {
  // Pega basename detectado automaticamente
  const basename = window.__APP_BASE_PATH__ || '';

  console.log('[App] Basename:', basename || '(raiz)');

  return (
    <BrowserRouter basename={basename}>
      {/* Suas rotas aqui */}
    </BrowserRouter>
  );
}
```

### 4.4. Atualizar vite.config.ts

```bash
nano vite.config.ts  # ou vite.config.js
```

**IMPORTANTE**: `base` deve ser `'/'`

```typescript
export default defineConfig({
  plugins: [react()],

  // DEIXAR VAZIO - detecção em runtime!
  base: '/',

  server: {
    port: 3002,
    host: '0.0.0.0',
  },

  build: {
    outDir: 'dist',
  }
})
```

### 4.5. Criar nginx.conf

```bash
nano web/deploy/nginx.conf
```

**Cole o template** (veja [TEMPLATES-CONFIGURACAO.md](TEMPLATES-CONFIGURACAO.md#nginxconf-para-spa))

### 4.6. Criar Dockerfile.prod

```bash
nano web/deploy/Dockerfile.prod
```

**Cole o template** (veja [TEMPLATES-CONFIGURACAO.md](TEMPLATES-CONFIGURACAO.md#template-frontend-reactvite))

### 4.7. Testar Build Local

```bash
cd web/suporte_dashboard_web_react

# Instalar dependências (se necessário)
npm install

# Build
npm run build

# Testar build
npm run preview

# Acessar: http://localhost:4173 (ou porta configurada)
```

### 4.8. Adicionar ao docker-compose.prod.yml

```bash
nano deploy/docker-compose.prod.yml
```

**Adicione o serviço do portal**:

```yaml
services:
  # ... (traefik e api já estão aqui)

  suporte-portal:
    build:
      context: ../web/suporte_dashboard_web_react
      dockerfile: deploy/Dockerfile.prod
    container_name: suporte-portal
    restart: unless-stopped

    ports:
      - "3002:3002"  # ← Acesso direto

    networks:
      - traefik_net

    labels:
      - "traefik.enable=true"

      # HTTPS Router
      - "traefik.http.routers.suporte-portal.rule=Host(`office.inoveon.com.br`) && PathPrefix(`/portal/suporte`)"
      - "traefik.http.routers.suporte-portal.entrypoints=websecure"
      - "traefik.http.routers.suporte-portal.tls=true"
      - "traefik.http.routers.suporte-portal.tls.certresolver=letsencrypt"

      # Service (SEM stripprefix!)
      - "traefik.http.services.suporte-portal.loadbalancer.server.port=3002"
```

✅ **Checkpoint 4**: Frontend compilando e configurado

---

## 🚀 Fase 5: Deploy e Testes (1h)

### 5.1. Validar Configuração

```bash
cd /Users/leechardes/Projetos/suporte

# Executar script de validação
chmod +x scripts/validate-hybrid-deploy.sh
./scripts/validate-hybrid-deploy.sh
```

**Deve retornar**: "✓ CONFIGURAÇÃO VÁLIDA"

### 5.2. Deploy Completo

```bash
cd deploy

# Build e subir todos os serviços
docker-compose -f docker-compose.prod.yml up --build -d

# Verificar status
docker-compose ps

# Ver logs
docker-compose logs -f
```

### 5.3. Aguardar Certificado SSL

```bash
# Monitorar logs do Traefik
docker logs traefik -f | grep acme

# Deve mostrar: "The ACME certificate has been successfully generated"
```

**⏱️ Pode levar 1-3 minutos** para o Let's Encrypt gerar o certificado.

### 5.4. Testes Completos

#### Teste 1: Acesso Direto à API

```bash
# Health check
curl http://10.0.20.11:8002/api/health

# Deve retornar JSON com status healthy
```

#### Teste 2: Acesso via Traefik à API

```bash
# Health check via domínio
curl https://office.inoveon.com.br/api/suporte/health

# Swagger UI
curl -I https://office.inoveon.com.br/api/suporte/docs
```

#### Teste 3: Acesso Direto ao Portal

```bash
# Home page
curl -I http://10.0.20.11:3002/

# Deve retornar HTTP 200
```

#### Teste 4: Acesso via Traefik ao Portal

```bash
# Home page via domínio
curl -I https://office.inoveon.com.br/portal/suporte/

# Deve retornar HTTP 200
```

#### Teste 5: Teste de Login (API)

```bash
curl -X POST https://office.inoveon.com.br/api/suporte/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"test123"}'

# Deve retornar JSON (200 ou 401, ambos OK)
```

#### Teste 6: Console do Browser

1. Abra: `https://office.inoveon.com.br/portal/suporte/`
2. Abra o DevTools (F12)
3. Vá na aba Console
4. Procure por logs `[Config]`, `[App]`, `[API]`

**Deve mostrar**:
```
[Config] {basePath: "/portal/suporte", apiUrl: "https://office.inoveon.com.br/api/suporte", ...}
[App] Basename: /portal/suporte
```

#### Teste 7: Navegação Completa

1. Acesse: `https://office.inoveon.com.br/portal/suporte/`
2. Clique em "Login"
3. URL deve ser: `https://office.inoveon.com.br/portal/suporte/login`
4. Tente fazer login
5. Verifique no Network tab se está chamando `https://office.inoveon.com.br/api/suporte/auth/login`

### 5.5. Executar Script de Testes Automatizados

```bash
chmod +x scripts/test-endpoints.sh
./scripts/test-endpoints.sh
```

✅ **Checkpoint 5**: Todos os testes passaram!

---

## 🐛 Troubleshooting

### Problema: Portal mostra página em branco

**Diagnóstico**:
```bash
# Ver logs do container
docker logs suporte-portal

# Ver logs do Nginx
docker exec suporte-portal cat /var/log/nginx/error.log

# Verificar console do browser (F12)
```

**Soluções**:
1. Verificar se `base: '/'` no vite.config
2. Confirmar script de detecção no index.html
3. Verificar se build foi feito corretamente
4. Verificar nginx.conf para SPA

### Problema: API retorna 404

**Diagnóstico**:
```bash
# Ver o que Traefik está recebendo
docker logs traefik | grep suporte

# Testar direto (deve funcionar)
curl http://10.0.20.11:8002/api/health

# Testar via Traefik
curl -v https://office.inoveon.com.br/api/suporte/health
```

**Soluções**:
1. Verificar ordem dos middlewares: `stripprefix,addprefix`
2. Confirmar paths corretos: `/api/suporte` → `/api`
3. Verificar se API responde em `/api/*`
4. Validar labels Traefik

### Problema: CORS Error

**Diagnóstico**:
```bash
# Testar CORS
curl -H "Origin: https://office.inoveon.com.br" \
  -H "Access-Control-Request-Method: POST" \
  -X OPTIONS \
  https://office.inoveon.com.br/api/suporte/auth/login \
  -v
```

**Soluções**:
1. Adicionar origem no CORS da API
2. Verificar `allow_credentials=True`
3. Confirmar `allow_methods=["*"]`

### Problema: Certificado SSL não gerado

**Diagnóstico**:
```bash
# Ver logs do Let's Encrypt
docker logs traefik | grep acme

# Testar porta 80 (HTTP challenge precisa)
curl http://office.inoveon.com.br/
```

**Soluções**:
1. Verificar DNS aponta para servidor
2. Confirmar portas 80/443 abertas
3. Validar email no Let's Encrypt
4. Limpar acme.json: `rm deploy/letsencrypt/acme.json && docker-compose restart traefik`

---

## 📝 Checklist Final

Marque cada item quando concluído:

### Configuração
- [ ] Arquivo `.env` criado e configurado
- [ ] `docker-compose.prod.yml` completo
- [ ] SECRET_KEY gerado aleatoriamente
- [ ] DNS apontando para o servidor
- [ ] Portas 80/443 abertas no firewall

### Backend
- [ ] `root_path` configurado no FastAPI
- [ ] CORS com todas as origens
- [ ] Health check em `/api/health`
- [ ] Dockerfile.prod criado
- [ ] Labels Traefik corretos
- [ ] Middlewares: stripprefix + addprefix

### Frontend
- [ ] Script de detecção no `index.html`
- [ ] `src/config/api.ts` com detecção automática
- [ ] `basename` dinâmico no Router
- [ ] `base: '/'` no vite.config
- [ ] nginx.conf para SPA
- [ ] Dockerfile.prod criado
- [ ] Labels Traefik (SEM stripprefix)

### Testes
- [ ] Script de validação executado
- [ ] Acesso direto API funciona
- [ ] Acesso via Traefik API funciona
- [ ] Acesso direto Portal funciona
- [ ] Acesso via Traefik Portal funciona
- [ ] Login completo funciona
- [ ] Console sem erros
- [ ] Certificado SSL válido

---

## 🎉 Próximos Passos

Após tudo funcionando:

1. **Monitoramento**
   - Configurar logs centralizados
   - Adicionar métricas (Prometheus + Grafana)
   - Configurar alertas

2. **Segurança**
   - Proteger dashboard do Traefik
   - Adicionar rate limiting
   - Configurar backups automáticos

3. **Performance**
   - Otimizar build do frontend
   - Configurar cache adequado
   - Adicionar CDN (se necessário)

4. **Documentação**
   - Atualizar README com novas URLs
   - Documentar variáveis de ambiente
   - Criar runbook para troubleshooting

---

**Versão**: 1.0
**Data**: Janeiro 2025
**Mantido por**: Equipe DevOps Inoveon

**Tempo de implementação**: ✅ Concluído em _____ horas
