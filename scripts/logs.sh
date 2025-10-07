#!/bin/bash

# 📋 Logs Script - Visualização de Logs
# Facilita a visualização de logs dos serviços

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Carregar configurações
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/deploy/.env" 2>/dev/null || {
    echo -e "${RED}❌ Arquivo .env não encontrado em deploy/❌${NC}"
    exit 1
}

# Função para mostrar ajuda
show_help() {
    echo -e "${BLUE}📋 Logs Viewer - Sistema Suporte${NC}"
    echo ""
    echo -e "${YELLOW}Uso:${NC}"
    echo "  $0 [SERVIÇO] [OPÇÕES]"
    echo ""
    echo -e "${YELLOW}Serviços:${NC}"
    echo "  api              Logs da API FastAPI"
    echo "  web              Logs do Portal React"
    echo "  db               Logs do PostgreSQL"
    echo "  redis            Logs do Redis"
    echo "  traefik          Logs do Traefik"
    echo "  all              Logs de todos os serviços"
    echo ""
    echo -e "${YELLOW}Opções:${NC}"
    echo "  -f, --follow     Seguir logs em tempo real"
    echo "  -n, --lines N    Mostrar últimas N linhas (padrão: 50)"
    echo "  --since TIME     Logs desde um tempo específico"
    echo "  --help           Mostra esta ajuda"
    echo ""
    echo -e "${YELLOW}Exemplos:${NC}"
    echo "  $0 api -f"
    echo "  $0 all -n 100"
    echo "  $0 db --since 1h"
    echo ""
}

# Valores padrão
SERVICE=""
FOLLOW=false
LINES=50
SINCE=""

# Processar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        api|web|db|redis|traefik|all)
            SERVICE="$1"
            shift
            ;;
        -f|--follow)
            FOLLOW=true
            shift
            ;;
        -n|--lines)
            LINES="$2"
            shift 2
            ;;
        --since)
            SINCE="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Argumento desconhecido: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Se nenhum serviço especificado, mostrar menu
if [ -z "$SERVICE" ]; then
    echo -e "${BLUE}📋 Selecione o serviço:${NC}"
    echo "1) API (suporte-api)"
    echo "2) Portal (suporte-portal)"
    echo "3) Database (suporte-db)"
    echo "4) Redis (suporte-redis)"
    echo "5) Traefik"
    echo "6) Todos os serviços"
    echo ""
    read -p "Opção [1-6]: " choice
    
    case $choice in
        1) SERVICE="api" ;;
        2) SERVICE="web" ;;
        3) SERVICE="db" ;;
        4) SERVICE="redis" ;;
        5) SERVICE="traefik" ;;
        6) SERVICE="all" ;;
        *)
            echo -e "${RED}❌ Opção inválida${NC}"
            exit 1
            ;;
    esac
fi

# Mapear serviços para nomes de containers
get_container_name() {
    case $1 in
        api) echo "suporte-api" ;;
        web) echo "suporte-portal" ;;
        db) echo "suporte-db" ;;
        redis) echo "suporte-redis" ;;
        traefik) echo "traefik" ;;
        *) echo "$1" ;;
    esac
}

# Construir comando docker logs
build_logs_command() {
    local container="$1"
    local cmd="docker logs $container"
    
    if [ "$FOLLOW" = true ]; then
        cmd="$cmd -f"
    fi
    
    cmd="$cmd --tail $LINES"
    
    if [ -n "$SINCE" ]; then
        cmd="$cmd --since $SINCE"
    fi
    
    echo "$cmd"
}

# Executar comando no servidor
run_remote() {
    ssh "$SSH_HOST" "$@"
}

# Verificar se container existe
check_container() {
    local container="$1"
    if ! run_remote "docker ps -a --format '{{.Names}}' | grep -q '^${container}$'"; then
        echo -e "${RED}❌ Container $container não encontrado${NC}"
        return 1
    fi
    return 0
}

# Mostrar logs de um serviço
show_service_logs() {
    local service="$1"
    local container=$(get_container_name "$service")
    
    echo -e "${BLUE}📋 Logs do $service ($container)${NC}"
    
    if ! check_container "$container"; then
        return 1
    fi
    
    local cmd=$(build_logs_command "$container")
    
    if [ "$FOLLOW" = true ]; then
        echo -e "${YELLOW}Seguindo logs... (Ctrl+C para sair)${NC}"
    fi
    
    run_remote "$cmd"
}

# Mostrar logs de todos os serviços
show_all_logs() {
    local services=("api" "web" "db" "redis")
    
    echo -e "${BLUE}📋 Logs de Todos os Serviços${NC}"
    echo ""
    
    for service in "${services[@]}"; do
        local container=$(get_container_name "$service")
        
        if check_container "$container"; then
            echo -e "${YELLOW}=== $service ($container) ===${NC}"
            local cmd=$(build_logs_command "$container")
            run_remote "$cmd" | head -10
            echo ""
        fi
    done
    
    if [ "$FOLLOW" = true ]; then
        echo -e "${YELLOW}Modo follow não suportado para 'all'. Use um serviço específico.${NC}"
    fi
}

# Executar baseado no serviço
case $SERVICE in
    all)
        show_all_logs
        ;;
    *)
        show_service_logs "$SERVICE"
        ;;
esac