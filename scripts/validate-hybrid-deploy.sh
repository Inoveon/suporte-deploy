#!/bin/bash

# ============================================
# Script de Validação de Deploy Híbrido
# ============================================
# Valida se a configuração está correta antes do deploy
# ============================================

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Contadores
total_checks=0
passed_checks=0
failed_checks=0
warnings=0

# ============================================
# Funções Auxiliares
# ============================================

print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Validação de Deploy Híbrido - Inoveon                    ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo -e "${YELLOW}┌─ $1 $(printf '─%.0s' {1..50})${NC}" | head -c 60
    echo -e "${YELLOW}┐${NC}"
}

print_end_section() {
    echo -e "${YELLOW}└────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

check_pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    ((passed_checks++))
    ((total_checks++))
}

check_fail() {
    echo -e "  ${RED}✗${NC} $1"
    ((failed_checks++))
    ((total_checks++))
}

check_warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
    ((warnings++))
}

check_info() {
    echo -e "  ${BLUE}ℹ${NC} $1"
}

# ============================================
# Validações
# ============================================

validate_env_file() {
    print_section "Variáveis de Ambiente"

    if [ -f "deploy/.env" ]; then
        check_pass "Arquivo deploy/.env encontrado"

        # Verificar variáveis essenciais
        required_vars=("PROJECT_NAME" "DOMAIN" "API_PORT" "PORTAL_PORT" "DATABASE_URL" "SECRET_KEY")

        for var in "${required_vars[@]}"; do
            if grep -q "^${var}=" "deploy/.env"; then
                value=$(grep "^${var}=" "deploy/.env" | cut -d'=' -f2)
                if [ -n "$value" ] && [ "$value" != "change-this" ] && [ "$value" != "your-" ]; then
                    check_pass "$var configurado"
                else
                    check_fail "$var não configurado corretamente"
                fi
            else
                check_fail "$var não encontrado"
            fi
        done

        # Verificar se SECRET_KEY foi alterado
        if grep -q "SECRET_KEY=super-secret-key" "deploy/.env"; then
            check_warn "SECRET_KEY parece usar valor padrão - ALTERE em produção!"
        fi

    else
        check_fail "Arquivo deploy/.env NÃO encontrado"
        check_info "Crie o arquivo baseado em deploy/.env.template"
    fi

    print_end_section
}

validate_docker_compose() {
    print_section "Docker Compose"

    if [ -f "deploy/docker-compose.prod.yml" ]; then
        check_pass "docker-compose.prod.yml encontrado"

        # Verificar se tem Traefik
        if grep -q "traefik:" "deploy/docker-compose.prod.yml"; then
            check_pass "Serviço Traefik configurado"
        else
            check_fail "Serviço Traefik NÃO encontrado"
        fi

        # Verificar labels Traefik
        if grep -q "traefik.http.routers" "deploy/docker-compose.prod.yml"; then
            check_pass "Labels Traefik encontrados"
        else
            check_fail "Labels Traefik NÃO encontrados"
        fi

        # Verificar Let's Encrypt
        if grep -q "letsencrypt" "deploy/docker-compose.prod.yml"; then
            check_pass "Let's Encrypt configurado"
        else
            check_warn "Let's Encrypt NÃO configurado"
        fi

        # Verificar networks
        if grep -q "traefik_net" "deploy/docker-compose.prod.yml"; then
            check_pass "Network traefik_net configurada"
        else
            check_fail "Network traefik_net NÃO encontrada"
        fi

    else
        check_fail "docker-compose.prod.yml NÃO encontrado"
    fi

    print_end_section
}

validate_frontend_detection() {
    print_section "Frontend - Detecção Automática"

    # Buscar index.html em possíveis localizações
    index_files=(
        "web/suporte_dashboard_web_react/index.html"
        "web/*/index.html"
        "portal/index.html"
    )

    found=false
    for pattern in "${index_files[@]}"; do
        for file in $pattern; do
            if [ -f "$file" ]; then
                check_pass "index.html encontrado: $file"
                found=true

                # Verificar script de detecção
                if grep -q "__APP_BASE_PATH__" "$file"; then
                    check_pass "Script de detecção automática presente"
                else
                    check_fail "Script de detecção NÃO encontrado"
                    check_info "Adicione o script de detecção conforme documentação"
                fi

                # Verificar __APP_CONFIG__
                if grep -q "__APP_CONFIG__" "$file"; then
                    check_pass "Configuração global (__APP_CONFIG__) presente"
                else
                    check_warn "Configuração global não encontrada"
                fi

                break 2
            fi
        done
    done

    if [ "$found" = false ]; then
        check_fail "index.html NÃO encontrado"
    fi

    print_end_section
}

validate_frontend_api_config() {
    print_section "Frontend - Configuração da API"

    # Buscar src/config/api.ts ou api.js
    api_configs=(
        "web/*/src/config/api.ts"
        "web/*/src/config/api.js"
        "src/config/api.ts"
        "src/config/api.js"
    )

    found=false
    for pattern in "${api_configs[@]}"; do
        for file in $pattern; do
            if [ -f "$file" ]; then
                check_pass "Configuração da API encontrada: $file"
                found=true

                # Verificar detecção de URL
                if grep -q "__APP_CONFIG__" "$file" || grep -q "window.location" "$file"; then
                    check_pass "Detecção automática de API URL presente"
                else
                    check_warn "Detecção automática pode não estar configurada"
                fi

                # Verificar interceptors
                if grep -q "interceptors" "$file"; then
                    check_pass "Interceptors configurados"
                else
                    check_warn "Interceptors não encontrados"
                fi

                break 2
            fi
        done
    done

    if [ "$found" = false ]; then
        check_warn "src/config/api.ts não encontrado"
    fi

    print_end_section
}

validate_vite_config() {
    print_section "Frontend - Vite Config"

    vite_configs=(
        "web/*/vite.config.ts"
        "web/*/vite.config.js"
        "vite.config.ts"
        "vite.config.js"
    )

    found=false
    for pattern in "${vite_configs[@]}"; do
        for file in $pattern; do
            if [ -f "$file" ]; then
                check_pass "vite.config encontrado: $file"
                found=true

                # Verificar base path
                if grep -q "base:" "$file"; then
                    base_value=$(grep "base:" "$file" | head -1)
                    if echo "$base_value" | grep -q "base: '/'"; then
                        check_pass "base: '/' configurado corretamente"
                    else
                        check_warn "base não está como '/' - pode causar problemas"
                        check_info "Use base: '/' e detecção em runtime"
                    fi
                fi

                # Verificar porta
                if grep -q "port:" "$file"; then
                    check_pass "Porta configurada no vite.config"
                fi

                break 2
            fi
        done
    done

    if [ "$found" = false ]; then
        check_warn "vite.config não encontrado"
    fi

    print_end_section
}

validate_backend_config() {
    print_section "Backend - FastAPI"

    # Buscar main.py
    main_files=(
        "api/*/app/main.py"
        "app/main.py"
    )

    found=false
    for pattern in "${main_files[@]}"; do
        for file in $pattern; do
            if [ -f "$file" ]; then
                check_pass "main.py encontrado: $file"
                found=true

                # Verificar root_path
                if grep -q "root_path" "$file"; then
                    check_pass "root_path configurado"
                else
                    check_warn "root_path não encontrado"
                    check_info "Adicione root_path=ROOT_PATH no FastAPI()"
                fi

                # Verificar CORS
                if grep -q "CORSMiddleware" "$file"; then
                    check_pass "CORS Middleware configurado"
                else
                    check_fail "CORS NÃO configurado"
                fi

                # Verificar health check
                if grep -q "/health" "$file" || grep -q "/api/health" "$file"; then
                    check_pass "Health check endpoint presente"
                else
                    check_warn "Health check não encontrado"
                fi

                break 2
            fi
        done
    done

    if [ "$found" = false ]; then
        check_fail "app/main.py NÃO encontrado"
    fi

    print_end_section
}

validate_nginx_config() {
    print_section "Nginx - Configuração SPA"

    nginx_configs=(
        "web/deploy/nginx.conf"
        "deploy/nginx.conf"
    )

    found=false
    for file in "${nginx_configs[@]}"; do
        if [ -f "$file" ]; then
            check_pass "nginx.conf encontrado: $file"
            found=true

            # Verificar try_files para SPA
            if grep -q "try_files.*index.html" "$file"; then
                check_pass "try_files configurado para SPA"
            else
                check_fail "try_files para SPA NÃO configurado"
                check_info "Adicione: try_files \$uri \$uri/ /index.html;"
            fi

            # Verificar cache de assets
            if grep -q "expires" "$file"; then
                check_pass "Cache de assets configurado"
            else
                check_warn "Cache de assets não configurado"
            fi

            break
        fi
    done

    if [ "$found" = false ]; then
        check_warn "nginx.conf não encontrado"
    fi

    print_end_section
}

validate_dockerfiles() {
    print_section "Dockerfiles"

    # API Dockerfile
    if [ -f "api/deploy/Dockerfile.prod" ]; then
        check_pass "API Dockerfile.prod encontrado"

        # Verificar multi-stage build
        if grep -q "FROM.*AS builder" "api/deploy/Dockerfile.prod"; then
            check_pass "Multi-stage build configurado (API)"
        else
            check_warn "Multi-stage build não usado (API)"
        fi
    else
        check_warn "API Dockerfile.prod não encontrado"
    fi

    # Portal Dockerfile
    if [ -f "web/deploy/Dockerfile.prod" ]; then
        check_pass "Portal Dockerfile.prod encontrado"

        # Verificar multi-stage build
        if grep -q "FROM.*AS build" "web/deploy/Dockerfile.prod"; then
            check_pass "Multi-stage build configurado (Portal)"
        else
            check_warn "Multi-stage build não usado (Portal)"
        fi

        # Verificar nginx
        if grep -q "nginx" "web/deploy/Dockerfile.prod"; then
            check_pass "Nginx configurado no Dockerfile"
        else
            check_warn "Nginx não encontrado no Dockerfile"
        fi
    else
        check_warn "Portal Dockerfile.prod não encontrado"
    fi

    print_end_section
}

validate_ports() {
    print_section "Portas e Conectividade"

    # Verificar se portas estão em uso
    if command -v netstat &> /dev/null; then

        # Traefik
        if netstat -tuln 2>/dev/null | grep -q ":80 "; then
            check_info "Porta 80 (HTTP) em uso"
        else
            check_warn "Porta 80 (HTTP) livre - Traefik não rodando?"
        fi

        if netstat -tuln 2>/dev/null | grep -q ":443 "; then
            check_info "Porta 443 (HTTPS) em uso"
        else
            check_warn "Porta 443 (HTTPS) livre - Traefik não rodando?"
        fi

        # API
        if [ -f "deploy/.env" ]; then
            api_port=$(grep "^API_PORT=" "deploy/.env" | cut -d'=' -f2)
            if netstat -tuln 2>/dev/null | grep -q ":${api_port} "; then
                check_info "Porta ${api_port} (API) em uso"
            else
                check_warn "Porta ${api_port} (API) livre"
            fi
        fi

        # Portal
        if [ -f "deploy/.env" ]; then
            portal_port=$(grep "^PORTAL_PORT=" "deploy/.env" | cut -d'=' -f2)
            if netstat -tuln 2>/dev/null | grep -q ":${portal_port} "; then
                check_info "Porta ${portal_port} (Portal) em uso"
            else
                check_warn "Porta ${portal_port} (Portal) livre"
            fi
        fi

    else
        check_warn "netstat não disponível - não foi possível verificar portas"
    fi

    print_end_section
}

validate_directory_structure() {
    print_section "Estrutura de Diretórios"

    # Diretórios essenciais
    dirs=(
        "deploy:Configurações de deploy"
        "api:Backend"
        "web:Frontend"
        "docs:Documentação"
        "scripts:Scripts de automação"
    )

    for item in "${dirs[@]}"; do
        dir=$(echo "$item" | cut -d':' -f1)
        desc=$(echo "$item" | cut -d':' -f2)

        if [ -d "$dir" ]; then
            check_pass "$desc ($dir/)"
        else
            check_warn "$desc não encontrado ($dir/)"
        fi
    done

    # Verificar letsencrypt
    if [ -d "letsencrypt" ] || [ -d "deploy/letsencrypt" ]; then
        check_pass "Diretório letsencrypt presente"
    else
        check_info "Diretório letsencrypt será criado no primeiro deploy"
    fi

    print_end_section
}

# ============================================
# Resumo Final
# ============================================

print_summary() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    RESUMO DA VALIDAÇÃO                     ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Total de verificações: $total_checks"
    echo -e "  ${GREEN}Passaram: $passed_checks${NC}"
    echo -e "  ${RED}Falharam: $failed_checks${NC}"
    echo -e "  ${YELLOW}Avisos: $warnings${NC}"
    echo ""

    # Calcular porcentagem
    if [ $total_checks -gt 0 ]; then
        percentage=$((passed_checks * 100 / total_checks))
        echo "  Taxa de sucesso: ${percentage}%"
        echo ""

        if [ $failed_checks -eq 0 ]; then
            echo -e "${GREEN}  ✓ CONFIGURAÇÃO VÁLIDA! Pronto para deploy.${NC}"
            exit 0
        elif [ $failed_checks -le 3 ]; then
            echo -e "${YELLOW}  ⚠ CONFIGURAÇÃO COM PROBLEMAS MENORES${NC}"
            echo -e "  Corrija os erros antes do deploy em produção."
            exit 1
        else
            echo -e "${RED}  ✗ CONFIGURAÇÃO COM PROBLEMAS CRÍTICOS${NC}"
            echo -e "  Corrija os erros antes de continuar."
            exit 1
        fi
    fi
}

# ============================================
# Execução Principal
# ============================================

main() {
    print_header

    # Executar validações
    validate_env_file
    validate_docker_compose
    validate_directory_structure
    validate_frontend_detection
    validate_frontend_api_config
    validate_vite_config
    validate_backend_config
    validate_nginx_config
    validate_dockerfiles
    validate_ports

    # Resumo
    print_summary
}

# Executar
main
