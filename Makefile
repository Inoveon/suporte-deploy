.PHONY: help install setup ssh clone deploy status logs health backup update clean test

# Variáveis padrão
SERVER_IP ?= 10.0.20.11
USERNAME ?= lee
PASSWORD ?=

help: ## 📋 Mostrar todos os comandos disponíveis
	@echo ""
	@echo "┌─────────────────────────────────────────────────┐"
	@echo "│                                                 │"
	@echo "│        🚀 SUPORTE DEPLOY - MAKEFILE            │"
	@echo "│                                                 │"
	@echo "│      Comandos Simplificados de Deploy          │"
	@echo "│                                                 │"
	@echo "└─────────────────────────────────────────────────┘"
	@echo ""
	@echo "🎯 Comandos Principais:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'
	@echo ""
	@echo "📝 Exemplos de Uso:"
	@echo "  make install                    # Instalar dependências"
	@echo "  make ssh PASSWORD=senha123      # Configurar SSH"
	@echo "  make deploy                     # Deploy completo"
	@echo "  make status                     # Verificar status"
	@echo "  make logs SERVICE=api           # Ver logs da API"
	@echo ""
	@echo "🔧 Variáveis:"
	@echo "  SERVER_IP  = $(SERVER_IP)"
	@echo "  USERNAME   = $(USERNAME)"
	@echo "  SERVICE    = api|web|db|redis|all"
	@echo ""

# ============================================================================
# 📦 INSTALAÇÃO E SETUP
# ============================================================================

install: ## 📦 Instalar todas as dependências do sistema
	@echo "📦 Instalando dependências..."
	@./scripts/install-dependencies.sh

ssh: ## 🔐 Configurar chaves SSH (make ssh PASSWORD=senha)
	@if [ -z "$(PASSWORD)" ]; then \
		echo "❌ PASSWORD é obrigatório. Use: make ssh PASSWORD=sua_senha"; \
		echo "   Exemplo: make ssh PASSWORD=minhasenha"; \
		exit 1; \
	fi
	@echo "🔐 Configurando SSH para $(USERNAME)@$(SERVER_IP)..."
	@./scripts/setup-ssh.sh $(SERVER_IP) $(USERNAME) $(PASSWORD)

ssh-check: ## 🔍 Verificar configuração SSH existente
	@echo "🔍 Verificando configuração SSH..."
	@./scripts/setup-ssh.sh --check-only

setup: ## ⚙️ Configuração inicial do ambiente
	@echo "⚙️ Configurando ambiente..."
	@./setup.sh

clone: ## 📥 Clonar todos os projetos
	@echo "📥 Clonando projetos..."
	@./clone-projects.sh

first-time: install clone setup ## 🚀 Setup completo primeira vez (use: make first-time)
	@echo "🎉 Setup inicial concluído! Configure os .env e execute 'make ssh' e 'make deploy'."

# ============================================================================
# 🚀 DEPLOY
# ============================================================================

deploy: ## 🚀 Deploy completo de todos os serviços
	@echo "🚀 Iniciando deploy completo..."
	@./deploy/deploy.sh all

deploy-api: ## 🔧 Deploy apenas da API
	@echo "🔧 Deploy da API..."
	@./api/deploy/deploy.sh

deploy-web: ## 🌐 Deploy apenas do Portal Web
	@echo "🌐 Deploy do Portal..."
	@./web/deploy/deploy.sh

deploy-infra: ## 🏗️ Deploy apenas da infraestrutura
	@echo "🏗️ Deploy da infraestrutura..."
	@./deploy/deploy.sh infra

deploy-force: ## ⚡ Deploy com rebuild forçado
	@echo "⚡ Deploy com rebuild forçado..."
	@./deploy/deploy.sh all --force

# ============================================================================
# 📊 MONITORAMENTO E LOGS
# ============================================================================

status: ## 📊 Verificar status de todos os serviços
	@echo "📊 Verificando status dos serviços..."
	@./deploy/deploy.sh status

health: ## 🏥 Health check completo do sistema
	@echo "🏥 Executando health check..."
	@./scripts/health-check.sh

logs: ## 📋 Ver logs (make logs SERVICE=api)
	@if [ -z "$(SERVICE)" ]; then \
		echo "📋 Especifique o serviço: make logs SERVICE=api|web|db|redis|all"; \
		./scripts/logs.sh; \
	else \
		echo "📋 Mostrando logs do $(SERVICE)..."; \
		./scripts/logs.sh $(SERVICE); \
	fi

logs-follow: ## 📋 Seguir logs em tempo real (make logs-follow SERVICE=api)
	@if [ -z "$(SERVICE)" ]; then \
		echo "❌ SERVICE é obrigatório. Use: make logs-follow SERVICE=api"; \
		exit 1; \
	fi
	@echo "📋 Seguindo logs do $(SERVICE) em tempo real..."
	@./scripts/logs.sh $(SERVICE) -f

# ============================================================================
# 💾 BACKUP E MANUTENÇÃO
# ============================================================================

backup: ## 💾 Backup completo do sistema
	@echo "💾 Iniciando backup completo..."
	@./scripts/backup.sh full --compress

backup-db: ## 🗄️ Backup apenas do banco de dados
	@echo "🗄️ Backup do banco de dados..."
	@./scripts/backup.sh database --compress

backup-list: ## 📋 Listar backups existentes
	@echo "📋 Listando backups..."
	@./scripts/backup.sh list

backup-clean: ## 🧹 Limpar backups antigos
	@echo "🧹 Limpando backups antigos..."
	@./scripts/backup.sh clean

# ============================================================================
# 🔄 ATUALIZAÇÃO
# ============================================================================

update: ## 🔄 Atualizar todos os projetos e redeploy
	@echo "🔄 Atualizando todos os projetos..."
	@./scripts/update-all.sh

update-api: ## 🔧 Atualizar apenas API
	@echo "🔧 Atualizando apenas API..."
	@./scripts/update-all.sh --api-only

update-web: ## 🌐 Atualizar apenas Portal
	@echo "🌐 Atualizando apenas Portal..."
	@./scripts/update-all.sh --web-only

update-force: ## ⚡ Atualização forçada
	@echo "⚡ Atualização forçada..."
	@./scripts/update-all.sh --force

# ============================================================================
# 🛠️ UTILITÁRIOS
# ============================================================================

restart: ## 🔄 Reiniciar todos os serviços
	@echo "🔄 Reiniciando serviços..."
	@./deploy/deploy.sh restart

stop: ## 🛑 Parar todos os serviços
	@echo "🛑 Parando serviços..."
	@./deploy/deploy.sh stop

clean: ## 🧹 Limpeza completa (containers, imagens, volumes)
	@echo "⚠️ Esta operação irá remover todos os containers e volumes!"
	@read -p "Tem certeza? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	@echo "🧹 Executando limpeza completa..."
	@./deploy/deploy.sh clean

test: ## 🧪 Executar todos os testes de validação
	@echo "🧪 Executando testes de validação..."
	@echo "📋 1. Verificando SSH..."
	@make ssh-check
	@echo "📋 2. Verificando health..."
	@make health
	@echo "📋 3. Verificando status..."
	@make status

# ============================================================================
# 📊 DESENVOLVIMENTO E DEBUG
# ============================================================================

config-show: ## 📋 Mostrar configurações atuais
	@echo "📋 Configurações atuais:"
	@echo ""
	@echo "Servidor SSH:"
	@if [ -f ~/.ssh/config ]; then \
		grep -A 8 "Host i9-deploy" ~/.ssh/config || echo "  Configuração não encontrada"; \
	else \
		echo "  Arquivo ~/.ssh/config não existe"; \
	fi
	@echo ""
	@echo "Projetos clonados:"
	@[ -d api/suporte_chamados_api_fastapi ] && echo "  ✅ API" || echo "  ❌ API"
	@[ -d web/suporte_dashboard_web_react ] && echo "  ✅ Portal" || echo "  ❌ Portal"
	@[ -d mobile/suporte_tecnico_mobile_flutter ] && echo "  ✅ Mobile" || echo "  ❌ Mobile"

urls: ## 🔗 Mostrar URLs importantes
	@echo "🔗 URLs do Sistema:"
	@echo ""
	@echo "Produção:"
	@echo "  API Docs:   https://office.inoveon.com.br/api/suporte/docs"
	@echo "  Portal:     https://office.inoveon.com.br/portal/suporte/"
	@echo "  Health:     https://office.inoveon.com.br/api/suporte/health"
	@echo ""
	@echo "Desenvolvimento:"
	@echo "  API Local:  http://localhost:8001/docs"
	@echo "  Portal Local: http://localhost:3001"

# ============================================================================
# 🎯 ALIASES E SHORTCUTS
# ============================================================================

# Aliases curtos para comandos mais usados
up: deploy ## Alias para deploy
down: stop ## Alias para stop
ps: status ## Alias para status

logs-api: ## Ver logs da API
	@make logs SERVICE=api

logs-web: ## Ver logs do Portal
	@make logs SERVICE=web

logs-db: ## Ver logs do Banco
	@make logs SERVICE=db

# ============================================================================
# 📚 HELP EXTENDIDO
# ============================================================================

help-full: ## 📚 Ajuda completa com exemplos
	@echo ""
	@echo "┌─────────────────────────────────────────────────┐"
	@echo "│                                                 │"
	@echo "│        🚀 SUPORTE DEPLOY - GUIA COMPLETO       │"
	@echo "│                                                 │"
	@echo "└─────────────────────────────────────────────────┘"
	@echo ""
	@echo "🎯 Fluxo Completo de Setup:"
	@echo ""
	@echo "1. Primeira vez (servidor novo):"
	@echo "   make install"
	@echo "   make ssh PASSWORD=senha123"
	@echo "   make clone"
	@echo "   make setup"
	@echo "   # Editar arquivos .env em deploy/, api/deploy/, web/deploy/"
	@echo "   make deploy"
	@echo ""
	@echo "2. Desenvolvimento diário:"
	@echo "   make status          # Verificar se tudo está OK"
	@echo "   make update          # Atualizar código e redeploy"
	@echo "   make health          # Health check completo"
	@echo "   make logs-follow SERVICE=api  # Ver logs em tempo real"
	@echo ""
	@echo "3. Manutenção:"
	@echo "   make backup          # Backup completo"
	@echo "   make backup-clean    # Limpar backups antigos"
	@echo "   make restart         # Reiniciar serviços"
	@echo ""
	@echo "4. Debugging:"
	@echo "   make config-show     # Mostrar configurações"
	@echo "   make ssh-check       # Verificar SSH"
	@echo "   make test            # Executar todos os testes"
	@echo ""
	@echo "🔧 Comandos por Componente:"
	@echo ""
	@echo "API: make deploy-api, make logs-api, make update-api"
	@echo "Portal: make deploy-web, make logs-web, make update-web"
	@echo "Banco: make logs-db, make backup-db"
	@echo ""
	@echo "💡 Dicas:"
	@echo "• Use 'make help' para lista rápida de comandos"
	@echo "• Todos os scripts estão em ./scripts/ para uso direto"
	@echo "• Configurações em deploy/.env, api/deploy/.env, web/deploy/.env"
	@echo "• Documentação completa em docs/DEPLOY-ARCHITECTURE.md"
	@echo ""