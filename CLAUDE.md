# CLAUDE.md

Este arquivo fornece orientações para o Claude Code (claude.ai/code) ao trabalhar com código neste repositório.

## 🎯 Arquitetura do Sistema

### Projeto Multi-Stack
- **API Backend**: FastAPI (Python) em `api/suporte_chamados_api_fastapi/`
- **Dashboard Web**: React + TypeScript + Vite em `web/suporte_dashboard_web_react/`
- **App Mobile**: Flutter em `mobile/suporte_tecnico_mobile_flutter/`

### Infraestrutura (Traefik v3.1)
- **Proxy reverso centralizado** roteando por path
- **API**: `/api/suporte/` → FastAPI na porta 8000
- **Portal**: `/portal/suporte/` → React/Nginx na porta 80
- **SSL automático** via Let's Encrypt para `office.inoveon.com.br`

## 🛠️ Comandos de Desenvolvimento

### API Backend (FastAPI)
```bash
cd api/suporte_chamados_api_fastapi/

# Setup ambiente
make install                    # Cria .venv e instala dependências
make docker-up                  # Sobe PostgreSQL + Redis + Adminer

# Desenvolvimento
make dev                        # Servidor desenvolvimento (porta 8001)
make migrate                    # Aplicar migrations do Alembic
make seed                       # Popular BD com dados iniciais

# Qualidade
make test                       # Pytest com coverage
make lint                       # Flake8 + MyPy
make format                     # Black + isort
make quality                    # format-check + lint + test

# Dados
make seed-chamados QTD=50       # Gerar chamados fake
make clean-chamados             # Limpar todos os chamados
make seed-org                   # Departamentos e cargos padrão
```

### Dashboard Web (React)
```bash
cd web/suporte_dashboard_web_react/

# Desenvolvimento
npm run dev                     # Servidor desenvolvimento (Vite)
npm run build                   # Build para produção
npm run preview                 # Preview do build

# Qualidade
npm run lint                    # ESLint
npm run lint:fix                # ESLint com correções
npm run type-check              # TypeScript check
npm run format                  # Prettier
npm run test                    # Vitest
npm run test:e2e                # Playwright E2E
```

### Mobile App (Flutter)
```bash
cd mobile/suporte_tecnico_mobile_flutter/

flutter pub get                 # Instalar dependências
flutter run                     # Executar app
flutter build apk               # Build Android
flutter test                    # Executar testes
```

## 🏗️ Estrutura de Arquivos Importantes

### API Backend
- `app/main.py` - Entry point FastAPI com `root_path="/api/suporte"`
- `app/models/` - Modelos SQLAlchemy (Chamado, Cliente, Usuario, etc.)
- `app/api/v1/` - Endpoints organizados por domínio
- `app/services/` - Lógica de negócio
- `app/core/config.py` - Configurações por ambiente
- `migrations/` - Migrations Alembic
- `scripts/` - Scripts utilitários e manutenção

### Dashboard Web
- `src/pages/` - Componentes de página
- `src/components/` - Componentes reutilizáveis (ShadCN/UI)
- `src/services/` - Clientes API com React Query
- `src/hooks/` - Custom hooks
- `src/types/` - Definições TypeScript
- `vite.config.ts` - Configurado com `base: '/portal/suporte/'`

### Configurações Docker
- **API**: `docker-compose.yml` (desenvolvimento local)
- **Produção**: Labels Traefik para routing automático
- **StripPrefix**: API remove `/api/suporte`, Portal mantém `/portal/suporte`

## 🔐 Configuração de Ambiente

### Variáveis API (.env)
```env
DATABASE_URL=postgresql://suporte_user:suporte_pass@localhost:5432/suporte_chamados
REDIS_URL=redis://localhost:6379
SECRET_KEY=your-secret-key
ENVIRONMENT=development
CORS_ORIGINS=["http://localhost:3000","http://localhost:5173"]
```

### URLs de Acesso
- **API Docs**: `http://localhost:8001/docs` (dev) ou `https://office.inoveon.com.br/api/suporte/docs`
- **Dashboard**: `http://localhost:5173` (dev) ou `https://office.inoveon.com.br/portal/suporte/`
- **Adminer**: `http://localhost:8080` (gestão PostgreSQL)

## 📋 Modelos de Dados Principais

### Entidades Core
- **Cliente**: Empresas com múltiplas filiais
- **Filial**: Localização específica do cliente
- **Sistema**: Aplicações desenvolvidas para cada cliente
- **Chamado**: Ticket de suporte/desenvolvimento
- **Usuario**: Desenvolvedores e usuários do sistema

### Relacionamentos
- Cliente → N Filiais
- Cliente → N Sistemas  
- Chamado → 1 Cliente, 1 Filial, 1 Sistema
- Chamado → 1 Desenvolvedor (Usuario)

### Tipos de Chamado
- **Bug Fix**: Correção de erros
- **Feature Request**: Nova funcionalidade  
- **Integration**: Integrações entre sistemas
- **Maintenance**: Manutenção de código

## 🧪 Estratégia de Testes

### API (Pytest)
- `app/tests/unit/` - Testes unitários de modelos/services
- `app/tests/integration/` - Testes de API endpoints
- `app/tests/e2e/` - Testes de fluxo completo
- Coverage mínimo: 80%

### Frontend (Vitest + Playwright)
- Componentes: React Testing Library
- E2E: Playwright para fluxos críticos
- Hooks: Testes isolados de lógica

## 🚀 Deploy e Produção

### Estrutura Docker Compose (Produção)
```yaml
# Exemplo para novos projetos seguindo o padrão
services:
  api:
    labels:
      - traefik.http.routers.PROJETO-api.rule=PathPrefix(`/api/PROJETO`)
      - traefik.http.middlewares.PROJETO-api-strip.stripprefix.prefixes=/api/PROJETO
  
  portal:
    labels:
      - traefik.http.routers.PROJETO-portal.rule=PathPrefix(`/portal/PROJETO`)
      # SEM StripPrefix no portal
```

### Checklist Deploy
1. **API**: Configurar `root_path` no FastAPI
2. **Portal**: Configurar `base` no Vite
3. **Docker**: Labels Traefik corretos
4. **SSL**: DNS apontando para servidor
5. **Migrations**: `make migrate` em produção

## 🔧 Troubleshooting Comum

### API: Swagger não carrega
- Verificar `root_path="/api/suporte"` no FastAPI
- Confirmar StripPrefix nos labels Traefik

### Portal: Assets 404
- Verificar `base: '/portal/suporte/'` no vite.config.ts
- Confirmar NGINX configurado para servir no caminho correto

### Banco: Connection refused
- Verificar se `docker-compose up -d` foi executado
- Confirmar credenciais no .env

### CORS errors
- Adicionar origem no `CORS_ORIGINS` da API
- Verificar se frontend está na porta correta

## 📝 Convenções de Código

### Python (API)
- **Models**: PascalCase (`Chamado`, `Cliente`)
- **Functions**: snake_case (`criar_chamado`)
- **Files**: snake_case (`chamado_service.py`)
- **Black**: line-length 88
- **Imports**: isort com profile "black"

### TypeScript (Frontend)
- **Components**: PascalCase (`ChamadoForm`)
- **Files**: kebab-case (`chamado-form.tsx`)
- **Functions**: camelCase (`createChamado`)
- **Prettier**: 2 spaces, trailing commas

### Git Commits
```
feat(api): adiciona endpoint de relatórios
fix(web): corrige filtros de data no dashboard
docs(readme): atualiza instruções de setup
test(e2e): adiciona teste de criação de chamado
```

## 🎯 Funcionalidades Principais

### Dashboard Analytics
- Métricas de SLA por cliente/sistema
- Gráficos de chamados por período
- Distribuição por tipo/prioridade
- Performance de desenvolvedores

### Gestão de Chamados
- CRUD completo com validações
- Atribuição automática de desenvolvedores
- Tracking de tempo real vs estimado
- Sistema de comentários e anexos

### Integrações
- Sistema de notificações (email/slack)
- APIs REST para sistemas externos
- Webhooks para eventos importantes
- Export de relatórios (PDF/Excel)

---

*Sistema otimizado para gestão eficiente de desenvolvimento e suporte de software com arquitetura microserviços usando Traefik como proxy reverso.*