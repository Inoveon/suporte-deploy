#!/bin/bash

# 🔄 Update All Script - Atualização Completa
# Atualiza todos os projetos e redeploy

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Carregar configurações
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/deploy/.env" 2>/dev/null || {
    echo -e "${RED}❌ Arquivo .env não encontrado em deploy/${NC}"
    exit 1
}

# Banner
echo -e "${PURPLE}"
echo "┌─────────────────────────────────────────────────┐"
echo "│                                                 │"
echo "│        🔄 UPDATE ALL - SUPORTE SYSTEM          │"
echo "│                                                 │"
echo "│      Atualização Completa dos Projetos         │"
echo "│                                                 │"
echo "└─────────────────────────────────────────────────┘"
echo -e "${NC}"

# Função de ajuda
show_help() {
    echo -e "${BLUE}🔄 Update All - Sistema Suporte${NC}"
    echo ""
    echo -e "${YELLOW}Uso:${NC}"
    echo "  $0 [OPÇÕES]"
    echo ""
    echo -e "${YELLOW}Opções:${NC}"
    echo "  --no-backup      Pular backup antes da atualização"
    echo "  --force          Força atualização mesmo com conflitos"
    echo "  --deploy-only    Apenas redeploy, sem git pull"
    echo "  --api-only       Atualizar apenas API"
    echo "  --web-only       Atualizar apenas Portal"
    echo "  --dry-run        Simular atualização sem executar"
    echo "  --help           Mostra esta ajuda"
    echo ""
    echo -e "${YELLOW}Exemplo:${NC}"
    echo "  $0 --force"
    echo "  $0 --api-only --no-backup"
    echo ""
}

# Configurações padrão
DO_BACKUP=true
FORCE_UPDATE=false
DEPLOY_ONLY=false
API_ONLY=false
WEB_ONLY=false
DRY_RUN=false

# Processar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-backup)
            DO_BACKUP=false
            shift
            ;;
        --force)
            FORCE_UPDATE=true
            shift
            ;;
        --deploy-only)
            DEPLOY_ONLY=true
            shift
            ;;
        --api-only)
            API_ONLY=true
            shift
            ;;
        --web-only)
            WEB_ONLY=true
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
            echo -e "${RED}❌ Opção desconhecida: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Se especificou api-only ou web-only, não fazer backup completo
if [ "$API_ONLY" = true ] || [ "$WEB_ONLY" = true ]; then
    DO_BACKUP=false
fi

echo -e "${GREEN}📋 Configurações:${NC}"
echo -e "   ${YELLOW}Backup:${NC} $DO_BACKUP"
echo -e "   ${YELLOW}Force:${NC} $FORCE_UPDATE"
echo -e "   ${YELLOW}Deploy Only:${NC} $DEPLOY_ONLY"
echo -e "   ${YELLOW}API Only:${NC} $API_ONLY"
echo -e "   ${YELLOW}Web Only:${NC} $WEB_ONLY"
echo -e "   ${YELLOW}Dry Run:${NC} $DRY_RUN"

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}🔍 Modo DRY RUN - Simulação${NC}"
fi

echo ""

# Função para executar comandos
run_command() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] $*${NC}"
    else
        "$@"
    fi
}

# Verificar se é repositório git
check_git_repo() {
    local dir="$1"
    if [ -d "$dir/.git" ]; then
        return 0
    else
        return 1
    fi
}

# Atualizar um projeto
update_project() {
    local project_name="$1"
    local project_path="$2"
    
    echo -e "${BLUE}🔄 Atualizando $project_name...${NC}"
    
    if [ ! -d "$project_path" ]; then
        echo -e "${RED}❌ Projeto não encontrado: $project_path${NC}"
        return 1
    fi
    
    if ! check_git_repo "$project_path"; then
        echo -e "${YELLOW}⚠️  $project_name não é um repositório git${NC}"
        return 0
    fi
    
    cd "$project_path"
    
    # Verificar status do repositório
    if [ "$DEPLOY_ONLY" = false ]; then
        echo -e "${YELLOW}  Verificando status...${NC}"
        
        # Verificar se há mudanças locais
        if ! git diff --quiet || ! git diff --cached --quiet; then
            if [ "$FORCE_UPDATE" = false ]; then
                echo -e "${RED}❌ Há mudanças locais não commitadas em $project_name${NC}"
                echo -e "${YELLOW}   Use --force para ignorar ou commite as mudanças${NC}"
                return 1
            else
                echo -e "${YELLOW}⚠️  Ignorando mudanças locais (--force)${NC}"
                run_command git stash
            fi
        fi
        
        # Verificar branch atual
        local current_branch=$(git branch --show-current)
        echo -e "${YELLOW}  Branch atual: $current_branch${NC}"
        
        # Fetch latest changes
        echo -e "${YELLOW}  Fazendo fetch...${NC}"
        run_command git fetch origin
        
        # Verificar se há atualizações
        local local_commit=$(git rev-parse HEAD)
        local remote_commit=$(git rev-parse "origin/$current_branch")
        
        if [ "$local_commit" = "$remote_commit" ]; then
            echo -e "${GREEN}✅ $project_name já está atualizado${NC}"
            return 0
        fi
        
        # Pull changes
        echo -e "${YELLOW}  Fazendo pull...${NC}"
        if run_command git pull origin "$current_branch"; then
            echo -e "${GREEN}✅ $project_name atualizado${NC}"
        else
            echo -e "${RED}❌ Erro ao atualizar $project_name${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}  Pulando git pull (deploy-only)${NC}"
    fi
    
    return 0
}

# Fazer backup antes da atualização
do_backup() {
    if [ "$DO_BACKUP" = true ]; then
        echo -e "${BLUE}💾 Fazendo backup antes da atualização...${NC}"
        if [ -f "$BASE_DIR/scripts/backup.sh" ]; then
            run_command "$BASE_DIR/scripts/backup.sh" database --compress
        else
            echo -e "${YELLOW}⚠️  Script de backup não encontrado${NC}"
        fi
    fi
}

# Health check antes da atualização
pre_update_check() {
    echo -e "${BLUE}🏥 Verificando saúde do sistema antes da atualização...${NC}"
    
    if [ -f "$BASE_DIR/scripts/health-check.sh" ]; then
        if run_command "$BASE_DIR/scripts/health-check.sh" &>/dev/null; then
            echo -e "${GREEN}✅ Sistema saudável${NC}"
        else
            echo -e "${YELLOW}⚠️  Sistema com problemas detectados${NC}"
            if [ "$FORCE_UPDATE" = false ]; then
                echo -e "${RED}❌ Abortando atualização. Use --force para continuar${NC}"
                exit 1
            fi
        fi
    else
        echo -e "${YELLOW}⚠️  Script de health check não encontrado${NC}"
    fi
}

# Health check após a atualização
post_update_check() {
    echo -e "${BLUE}🏥 Verificando saúde do sistema após atualização...${NC}"
    
    # Aguardar um pouco para os serviços subirem
    if [ "$DRY_RUN" = false ]; then
        sleep 30
    fi
    
    if [ -f "$BASE_DIR/scripts/health-check.sh" ]; then
        if run_command "$BASE_DIR/scripts/health-check.sh"; then
            echo -e "${GREEN}✅ Sistema funcionando corretamente${NC}"
        else
            echo -e "${RED}❌ Sistema com problemas após atualização${NC}"
            echo -e "${YELLOW}Verifique os logs: $BASE_DIR/scripts/logs.sh${NC}"
            return 1
        fi
    fi
}

# Deploy após atualização
do_deploy() {
    echo -e "${BLUE}🚀 Fazendo deploy das atualizações...${NC}"
    
    if [ "$API_ONLY" = true ]; then
        echo -e "${YELLOW}  Deploy apenas da API...${NC}"
        run_command "$BASE_DIR/api/deploy/deploy.sh"
    elif [ "$WEB_ONLY" = true ]; then
        echo -e "${YELLOW}  Deploy apenas do Portal...${NC}"
        run_command "$BASE_DIR/web/deploy/deploy.sh"
    else
        echo -e "${YELLOW}  Deploy completo...${NC}"
        run_command "$BASE_DIR/deploy/deploy.sh" all
    fi
}

# Mostrar sumário das mudanças
show_changes_summary() {
    echo -e "${BLUE}📋 Sumário das Mudanças${NC}"
    echo "=========================="
    
    # Lista de projetos para verificar
    local projects=(
        "API|$BASE_DIR/api/suporte_chamados_api_fastapi"
        "Portal|$BASE_DIR/web/suporte_dashboard_web_react"
    )
    
    for project_info in "${projects[@]}"; do
        IFS='|' read -r name path <<< "$project_info"
        
        # Pular se for only mode e não for o projeto
        if [ "$API_ONLY" = true ] && [ "$name" != "API" ]; then
            continue
        fi
        if [ "$WEB_ONLY" = true ] && [ "$name" != "Portal" ]; then
            continue
        fi
        
        if [ -d "$path" ] && check_git_repo "$path"; then
            echo -e "${YELLOW}$name:${NC}"
            cd "$path"
            
            # Últimos commits
            local commit_count=$(git rev-list --count HEAD...HEAD@{1} 2>/dev/null || echo "0")
            if [ "$commit_count" -gt 0 ]; then
                echo -e "  ${GREEN}+$commit_count novos commits${NC}"
                git log --oneline HEAD...HEAD@{1} | head -5 | sed 's/^/    /'
            else
                echo -e "  ${YELLOW}Nenhuma mudança${NC}"
            fi
            echo ""
        fi
    done
}

# Execução principal
main() {
    # Pre-update checks
    pre_update_check
    
    # Backup
    do_backup
    
    # Atualizar projetos
    local update_failed=false
    
    if [ "$API_ONLY" = true ]; then
        echo -e "${BLUE}🔄 Atualizando apenas API...${NC}"
        if ! update_project "API" "$BASE_DIR/api/suporte_chamados_api_fastapi"; then
            update_failed=true
        fi
    elif [ "$WEB_ONLY" = true ]; then
        echo -e "${BLUE}🔄 Atualizando apenas Portal...${NC}"
        if ! update_project "Portal" "$BASE_DIR/web/suporte_dashboard_web_react"; then
            update_failed=true
        fi
    else
        echo -e "${BLUE}🔄 Atualizando todos os projetos...${NC}"
        
        # API
        if ! update_project "API" "$BASE_DIR/api/suporte_chamados_api_fastapi"; then
            update_failed=true
        fi
        
        # Portal
        if ! update_project "Portal" "$BASE_DIR/web/suporte_dashboard_web_react"; then
            update_failed=true
        fi
    fi
    
    if [ "$update_failed" = true ]; then
        echo -e "${RED}❌ Falha na atualização de alguns projetos${NC}"
        if [ "$FORCE_UPDATE" = false ]; then
            exit 1
        fi
    fi
    
    # Deploy
    do_deploy
    
    # Post-update checks
    post_update_check
    
    # Sumário
    show_changes_summary
    
    echo ""
    echo -e "${GREEN}🎉 Atualização concluída com sucesso!${NC}"
    echo ""
    echo -e "${YELLOW}🔗 URLs atualizadas:${NC}"
    echo -e "   ${BLUE}API:${NC} https://$DOMAIN/api/suporte/docs"
    echo -e "   ${BLUE}Portal:${NC} https://$DOMAIN/portal/suporte/"
    echo ""
}

# Executar função principal
main