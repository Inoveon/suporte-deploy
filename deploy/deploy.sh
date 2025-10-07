#!/bin/bash

# 🚀 Deploy Geral - Suporte Complete
# Orquestrador principal para deploy de todos os componentes

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Diretórios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Banner
echo -e "${PURPLE}"
echo "┌─────────────────────────────────────────────────┐"
echo "│                                                 │"
echo "│        🚀 SUPORTE DEPLOY - INOVEON             │"
echo "│                                                 │"
echo "│     Sistema de Deploy Automatizado             │"
echo "│     Arquitetura Traefik + Multi-Stack          │"
echo "│                                                 │"
echo "└─────────────────────────────────────────────────┘"
echo -e "${NC}"

# Função de ajuda
show_help() {
    echo -e "${BLUE}🚀 Deploy Geral - Sistema Suporte${NC}"
    echo ""
    echo -e "${YELLOW}Uso:${NC}"
    echo "  $0 [COMANDO] [OPÇÕES]"
    echo ""
    echo -e "${YELLOW}Comandos:${NC}"
    echo "  all              Deploy completo (padrão)"
    echo "  api              Deploy apenas da API"
    echo "  web              Deploy apenas do Portal"
    echo "  infra            Deploy apenas da infraestrutura"
    echo "  status           Verificar status dos serviços"
    echo "  logs             Visualizar logs"
    echo "  health           Health check completo"
    echo "  stop             Parar todos os serviços"
    echo "  restart          Reiniciar todos os serviços"
    echo "  clean            Limpeza completa"
    echo ""
    echo -e "${YELLOW}Opções:${NC}"
    echo "  --force          Força rebuild de imagens"
    echo "  --no-cache       Build sem cache"
    echo "  --dry-run        Simula o deploy sem executar"
    echo "  --help           Mostra esta ajuda"
    echo ""
    echo -e "${YELLOW}Exemplos:${NC}"
    echo "  $0 all --force"
    echo "  $0 api --no-cache"
    echo "  $0 status"
    echo ""
}

# Verificar argumentos
COMMAND="${1:-all}"
FORCE_REBUILD=false
NO_CACHE=false
DRY_RUN=false

# Processar opções
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_REBUILD=true
            shift
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            if [[ $1 == -* ]]; then
                echo -e "${RED}❌ Opção desconhecida: $1${NC}"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Verificar se .env existe
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo -e "${YELLOW}⚠️  Arquivo .env não encontrado${NC}"
    if [ -f "$SCRIPT_DIR/.env.template" ]; then
        cp "$SCRIPT_DIR/.env.template" "$SCRIPT_DIR/.env"
        echo -e "${YELLOW}📝 Criado .env a partir do template${NC}"
        echo -e "${RED}🔧 Configure as variáveis em: $SCRIPT_DIR/.env${NC}"
        exit 1
    else
        echo -e "${RED}❌ Template .env não encontrado${NC}"
        exit 1
    fi
fi

# Carregar configurações
source "$SCRIPT_DIR/.env"

# Verificar variáveis obrigatórias
if [ -z "$SSH_HOST" ]; then
    echo -e "${RED}❌ SSH_HOST não configurado no .env${NC}"
    exit 1
fi

echo -e "${GREEN}📋 Configurações:${NC}"
echo -e "   ${YELLOW}Servidor:${NC} $SSH_HOST ($SERVER_IP)"
echo -e "   ${YELLOW}Projeto:${NC} $PROJECT_NAME"
echo -e "   ${YELLOW}Ambiente:${NC} $ENVIRONMENT"
echo -e "   ${YELLOW}Domínio:${NC} $DOMAIN"
echo -e "   ${YELLOW}Deploy Path:${NC} $DEPLOY_PATH"

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}🔍 Modo DRY RUN - Simulação${NC}"
fi

echo ""

# Função para executar comandos no servidor
run_remote() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] ssh $SSH_HOST '$*'${NC}"
    else
        ssh "$SSH_HOST" "$@"
    fi
}

# Função para executar comandos locais
run_local() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] $*${NC}"
    else
        "$@"
    fi
}

# Verificar pré-requisitos
check_prerequisites() {
    echo -e "${BLUE}🔍 Verificando pré-requisitos...${NC}"
    
    # Verificar conexão SSH
    if ! run_remote 'echo "SSH OK"' &>/dev/null; then
        echo -e "${RED}❌ Erro na conexão SSH com $SSH_HOST${NC}"
        exit 1
    fi
    
    # Verificar Docker no servidor
    if ! run_remote 'docker --version && docker compose version' &>/dev/null; then
        echo -e "${RED}❌ Docker/Compose não encontrado no servidor${NC}"
        exit 1
    fi
    
    # Verificar se os projetos foram clonados
    local missing_projects=()
    
    if [ ! -d "$BASE_DIR/api/suporte_chamados_api_fastapi" ]; then
        missing_projects+=("API")
    fi
    
    if [ ! -d "$BASE_DIR/web/suporte_dashboard_web_react" ]; then
        missing_projects+=("Web")
    fi
    
    if [ ${#missing_projects[@]} -gt 0 ]; then
        echo -e "${RED}❌ Projetos não clonados: ${missing_projects[*]}${NC}"
        echo -e "${YELLOW}   Execute primeiro: ./clone-projects.sh${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Pré-requisitos OK${NC}"
}

# Deploy da infraestrutura
deploy_infra() {
    echo -e "${BLUE}🏗️  Deploy da Infraestrutura...${NC}"
    
    REMOTE_DIR="$DEPLOY_PATH"
    
    # Criar diretórios no servidor
    run_remote "mkdir -p $REMOTE_DIR/{api,web,data,logs,backup}"
    
    # Copiar docker-compose principal
    if [ "$DRY_RUN" = false ]; then
        scp "$SCRIPT_DIR/docker-compose.prod.yml" "$SSH_HOST:$REMOTE_DIR/"
        scp "$SCRIPT_DIR/.env" "$SSH_HOST:$REMOTE_DIR/"
    fi
    
    # Verificar rede Traefik
    if run_remote "docker network ls | grep -q traefik_net"; then
        echo -e "${GREEN}✅ Rede Traefik existe${NC}"
    else
        echo -e "${YELLOW}⚠️  Criando rede Traefik...${NC}"
        run_remote "docker network create traefik_net"
    fi
    
    echo -e "${GREEN}✅ Infraestrutura pronta${NC}"
}

# Deploy da API
deploy_api() {
    echo -e "${BLUE}🔧 Deploy da API...${NC}"
    
    if [ -f "$BASE_DIR/api/deploy/deploy.sh" ]; then
        run_local "$BASE_DIR/api/deploy/deploy.sh"
    else
        echo -e "${RED}❌ Script de deploy da API não encontrado${NC}"
        exit 1
    fi
}

# Deploy do Portal
deploy_web() {
    echo -e "${BLUE}🌐 Deploy do Portal...${NC}"
    
    if [ -f "$BASE_DIR/web/deploy/deploy.sh" ]; then
        run_local "$BASE_DIR/web/deploy/deploy.sh"
    else
        echo -e "${RED}❌ Script de deploy do Portal não encontrado${NC}"
        exit 1
    fi
}

# Status dos serviços
check_status() {
    echo -e "${BLUE}📊 Status dos Serviços...${NC}"
    
    echo -e "${YELLOW}🐳 Containers Docker:${NC}"
    run_remote "docker ps --filter name=suporte- --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
    
    echo ""
    echo -e "${YELLOW}🏥 Health Checks:${NC}"
    
    # API Health
    if run_remote "curl -f -s http://localhost:8000/health" &>/dev/null; then
        echo -e "${GREEN}✅ API: Healthy${NC}"
    else
        echo -e "${RED}❌ API: Unhealthy${NC}"
    fi
    
    # Portal Health
    if run_remote "curl -f -s http://localhost:80/health" &>/dev/null; then
        echo -e "${GREEN}✅ Portal: Healthy${NC}"
    else
        echo -e "${RED}❌ Portal: Unhealthy${NC}"
    fi
    
    # Database Health
    if run_remote "docker exec suporte-db pg_isready -U suporte_user" &>/dev/null; then
        echo -e "${GREEN}✅ Database: Healthy${NC}"
    else
        echo -e "${RED}❌ Database: Unhealthy${NC}"
    fi
    
    # Redis Health
    if run_remote "docker exec suporte-redis redis-cli ping" &>/dev/null; then
        echo -e "${GREEN}✅ Redis: Healthy${NC}"
    else
        echo -e "${RED}❌ Redis: Unhealthy${NC}"
    fi
}

# Visualizar logs
show_logs() {
    echo -e "${BLUE}📋 Logs dos Serviços...${NC}"
    echo ""
    echo -e "${YELLOW}Selecione o serviço:${NC}"
    echo "1) API"
    echo "2) Portal"
    echo "3) Database"
    echo "4) Redis"
    echo "5) Todos"
    
    read -p "Opção [1-5]: " choice
    
    case $choice in
        1)
            run_remote "docker logs suporte-api -f --tail 50"
            ;;
        2)
            run_remote "docker logs suporte-portal -f --tail 50"
            ;;
        3)
            run_remote "docker logs suporte-db -f --tail 50"
            ;;
        4)
            run_remote "docker logs suporte-redis -f --tail 50"
            ;;
        5)
            run_remote "docker logs suporte-api --tail 20 && echo '---' && docker logs suporte-portal --tail 20"
            ;;
        *)
            echo -e "${RED}❌ Opção inválida${NC}"
            ;;
    esac
}

# Health check completo
health_check() {
    echo -e "${BLUE}🏥 Health Check Completo...${NC}"
    
    # URLs para testar
    local urls=(
        "https://office.inoveon.com.br/api/suporte/health|API Health"
        "https://office.inoveon.com.br/api/suporte/docs|API Docs"
        "https://office.inoveon.com.br/portal/suporte/|Portal"
    )
    
    for url_desc in "${urls[@]}"; do
        IFS='|' read -r url desc <<< "$url_desc"
        echo -n "  ${YELLOW}$desc:${NC} "
        
        if curl -f -s "$url" &>/dev/null; then
            echo -e "${GREEN}✅ OK${NC}"
        else
            echo -e "${RED}❌ FAIL${NC}"
        fi
    done
    
    echo ""
    check_status
}

# Parar serviços
stop_services() {
    echo -e "${BLUE}🛑 Parando serviços...${NC}"
    run_remote "cd $DEPLOY_PATH && docker compose -f docker-compose.prod.yml down"
    echo -e "${GREEN}✅ Serviços parados${NC}"
}

# Reiniciar serviços
restart_services() {
    echo -e "${BLUE}🔄 Reiniciando serviços...${NC}"
    run_remote "cd $DEPLOY_PATH && docker compose -f docker-compose.prod.yml restart"
    echo -e "${GREEN}✅ Serviços reiniciados${NC}"
}

# Limpeza completa
clean_all() {
    echo -e "${YELLOW}⚠️  Esta operação irá remover containers, imagens e volumes${NC}"
    read -p "Tem certeza? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}🧹 Limpeza completa...${NC}"
        run_remote "cd $DEPLOY_PATH && docker compose -f docker-compose.prod.yml down -v --remove-orphans"
        run_remote "docker system prune -f"
        run_remote "docker volume prune -f"
        echo -e "${GREEN}✅ Limpeza concluída${NC}"
    else
        echo -e "${YELLOW}Operação cancelada${NC}"
    fi
}

# Executar comando baseado no argumento
case $COMMAND in
    all)
        check_prerequisites
        deploy_infra
        deploy_api
        deploy_web
        echo ""
        echo -e "${GREEN}🎉 Deploy completo concluído!${NC}"
        echo ""
        health_check
        ;;
    api)
        check_prerequisites
        deploy_api
        ;;
    web)
        check_prerequisites
        deploy_web
        ;;
    infra)
        check_prerequisites
        deploy_infra
        ;;
    status)
        check_status
        ;;
    logs)
        show_logs
        ;;
    health)
        health_check
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    clean)
        clean_all
        ;;
    *)
        echo -e "${RED}❌ Comando desconhecido: $COMMAND${NC}"
        show_help
        exit 1
        ;;
esac