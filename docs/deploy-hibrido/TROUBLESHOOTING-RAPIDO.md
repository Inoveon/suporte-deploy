# 🚨 Troubleshooting Rápido - Deploy Híbrido API

> **Guia de referência rápida para resolver problemas comuns**

## 🔍 Diagnóstico Rápido

### Container não inicia?

```bash
# Ver logs
docker logs suporte-api --tail 50

# Problema comum: Database connection
# Solução: Verificar DATABASE_URL no .env
docker exec suporte-api env | grep DATABASE_URL
```

### Login retorna 500?

```bash
# Verificar senha do banco
# DATABASE_URL e DATABASE_URL_ASYNC devem ter mesma senha!
cat /docker/inoveon/suporte/api/deploy/.env | grep DATABASE_URL

# Corrigir e recriar (não apenas restart!)
docker-compose -f docker-compose.prod.yml up -d suporte-api
```

### Traefik retorna "no available server"?

```bash
# 1. Verificar se servidor está UP
curl -s http://10.0.20.11:8080/api/http/services | jq '.[] | select(.name=="suporte-api@docker") | .serverStatus'

# Se DOWN, verificar qual IP o Traefik está usando
docker inspect suporte-api -f "{{json .NetworkSettings.Networks}}" | jq '.traefik_net.IPAddress'

# 2. Forçar rede correta no docker-compose.prod.yml
labels:
  - traefik.docker.network=traefik_net  # ← Adicionar esta linha

# 3. Recriar container
docker-compose -f docker-compose.prod.yml up -d suporte-api

# 4. Reiniciar Traefik
docker restart traefik
```

### Path duplicado (404 após 30x)?

```bash
# Verificar logs
docker logs suporte-api | grep "POST /api/suporte/api/v1"

# Se aparecer path duplicado, remover root_path do FastAPI
# app/main.py - REMOVER esta linha:
# root_path="/api/suporte"  # ← DELETAR!

# Manter apenas:
servers=[
    {"url": "/api/suporte", "description": "Produção"},
    {"url": "http://10.0.20.11:8002/api", "description": "Dev"},
]
```

### Health check failing?

```bash
# Testar direto do container
docker exec suporte-api curl -s http://127.0.0.1:8002/health

# Se retornar 400, desabilitar TrustedHostMiddleware
# app/main.py - comentar:
# if not settings.DEBUG:
#     app.add_middleware(TrustedHostMiddleware, ...)
```

### Banco vazio após deploy?

```bash
# Popular com dados iniciais
docker exec suporte-api python scripts/database/seed_database.py
```

---

## ⚡ Comandos Essenciais

### Forçar Recriação Completa

```bash
cd /docker/inoveon/suporte
docker-compose -f docker-compose.prod.yml stop suporte-api
docker-compose -f docker-compose.prod.yml rm -f suporte-api
docker-compose -f docker-compose.prod.yml build --no-cache suporte-api
docker-compose -f docker-compose.prod.yml up -d suporte-api
```

### Verificar Status Traefik

```bash
# Routers
curl -s http://10.0.20.11:8080/api/http/routers | jq '.[] | select(.name | contains("suporte")) | {name, rule, status}'

# Services
curl -s http://10.0.20.11:8080/api/http/services | jq '.[] | select(.name | contains("suporte")) | {name, serverStatus}'

# Middlewares
curl -s http://10.0.20.11:8080/api/http/middlewares | jq '.[] | select(.name | contains("suporte")) | {name, type}'
```

### Testar Login

```bash
# Direto (dev)
curl -X POST http://10.0.20.11:8002/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"lee@inoveon.com.br","password":"admin123"}'

# Via proxy (prod)
curl -X POST https://office.inoveon.com.br/api/suporte/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"lee@inoveon.com.br","password":"admin123"}' -k
```

---

## 📋 Checklist 5 Minutos

Antes de qualquer deploy, verificar:

- [ ] Mesma senha em `DATABASE_URL` e `DATABASE_URL_ASYNC`
- [ ] IP do banco (não nome do container): `@10.0.20.11:5432`
- [ ] Label `traefik.docker.network=traefik_net` no docker-compose
- [ ] FastAPI SEM `root_path`
- [ ] TrustedHostMiddleware desabilitado
- [ ] Portas expostas: `8002:8002`

---

**Para detalhes completos, ver:** [LICOES-APRENDIDAS-IMPLEMENTACAO.md](./LICOES-APRENDIDAS-IMPLEMENTACAO.md)
