#!/bin/bash

# 🏥 Health Check Script - Verificação de Saúde
# Verifica a saúde de todos os serviços do sistema

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
    echo -e "${RED}❌ Arquivo .env não encontrado em deploy/${NC}"
    exit 1
}

echo -e "${BLUE}🏥 Health Check - Sistema Suporte${NC}"
echo -e "${YELLOW}Servidor: $SSH_HOST${NC}"
echo -e "${YELLOW}Domínio: $DOMAIN${NC}"
echo ""

# Função para executar no servidor
run_remote() {
    ssh "$SSH_HOST" "$@"
}

# Função para testar URL
test_url() {
    local url="$1"
    local desc="$2"
    local timeout="${3:-10}"
    
    echo -n "  ${YELLOW}$desc:${NC} "
    
    if curl -f -s --max-time "$timeout" "$url" &>/dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        return 1
    fi
}

# Função para testar container
test_container() {
    local container="$1"
    local desc="$2"
    
    echo -n "  ${YELLOW}$desc:${NC} "
    
    if run_remote "docker ps --filter name=$container --filter status=running --quiet" | grep -q .; then
        echo -e "${GREEN}✅ RUNNING${NC}"
        return 0
    else
        echo -e "${RED}❌ NOT RUNNING${NC}"
        return 1
    fi
}

# Função para testar comando em container
test_container_command() {
    local container="$1"
    local command="$2"
    local desc="$3"
    
    echo -n "  ${YELLOW}$desc:${NC} "
    
    if run_remote "docker exec $container $command" &>/dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        return 1
    fi
}

# Contadores
TOTAL_CHECKS=0
PASSED_CHECKS=0

check_result() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [ $? -eq 0 ]; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    fi
}

# 1. Verificar conectividade SSH
echo -e "${BLUE}🔐 Conectividade SSH${NC}"
echo -n "  ${YELLOW}SSH Connection:${NC} "
if run_remote 'echo "OK"' &>/dev/null; then
    echo -e "${GREEN}✅ OK${NC}"
    check_result
else
    echo -e "${RED}❌ FAIL${NC}"
    echo -e "${RED}Não foi possível conectar ao servidor${NC}"
    exit 1
fi

# 2. Verificar Docker
echo -e "${BLUE}🐳 Docker Engine${NC}"
echo -n "  ${YELLOW}Docker Version:${NC} "
if run_remote 'docker --version' &>/dev/null; then
    VERSION=$(run_remote 'docker --version | cut -d" " -f3 | cut -d"," -f1')
    echo -e "${GREEN}✅ $VERSION${NC}"
    check_result
else
    echo -e "${RED}❌ FAIL${NC}"
    check_result
fi

echo -n "  ${YELLOW}Docker Compose:${NC} "
if run_remote 'docker compose version' &>/dev/null; then
    VERSION=$(run_remote 'docker compose version | cut -d" " -f4')
    echo -e "${GREEN}✅ $VERSION${NC}"
    check_result
else
    echo -e "${RED}❌ FAIL${NC}"
    check_result
fi

# 3. Verificar Containers
echo -e "${BLUE}📦 Containers Status${NC}"
test_container "suporte-api" "API Container"
check_result

test_container "suporte-portal" "Portal Container"
check_result

test_container "suporte-db" "Database Container"
check_result

test_container "suporte-redis" "Redis Container"
check_result

# 4. Verificar Health Checks internos
echo -e "${BLUE}🏥 Internal Health Checks${NC}"

# API Health
test_container_command "suporte-api" "curl -f http://localhost:8000/health" "API Health Endpoint"
check_result

# Database Health
test_container_command "suporte-db" "pg_isready -U suporte_user" "PostgreSQL Ready"
check_result

# Redis Health
test_container_command "suporte-redis" "redis-cli ping" "Redis Ping"
check_result

# 5. Verificar URLs externas
echo -e "${BLUE}🌐 External URLs${NC}"

# URLs para testar
declare -a urls=(
    "https://$DOMAIN/api/suporte/health|API Health (External)"
    "https://$DOMAIN/api/suporte/docs|API Documentation"
    "https://$DOMAIN/portal/suporte/|Portal Homepage"
)

for url_desc in "${urls[@]}"; do
    IFS='|' read -r url desc <<< "$url_desc"
    test_url "$url" "$desc" 15
    check_result
done

# 6. Verificar SSL
echo -e "${BLUE}🔐 SSL Certificate${NC}"
echo -n "  ${YELLOW}SSL Cert Valid:${NC} "
if echo | openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" 2>/dev/null | openssl x509 -noout -dates &>/dev/null; then
    EXPIRY=$(echo | openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
    echo -e "${GREEN}✅ Valid (Expires: $EXPIRY)${NC}"
    check_result
else
    echo -e "${RED}❌ INVALID${NC}"
    check_result
fi

# 7. Verificar recursos do sistema
echo -e "${BLUE}💾 System Resources${NC}"

# CPU Usage
CPU_USAGE=$(run_remote "top -bn1 | grep 'Cpu(s)' | awk '{print \$2}' | cut -d'%' -f1" 2>/dev/null || echo "0")
echo -n "  ${YELLOW}CPU Usage:${NC} "
if (( $(echo "$CPU_USAGE < 80" | bc -l) )); then
    echo -e "${GREEN}✅ ${CPU_USAGE}%${NC}"
    check_result
else
    echo -e "${RED}❌ ${CPU_USAGE}% (High)${NC}"
    check_result
fi

# Memory Usage
MEM_USAGE=$(run_remote "free | grep Mem | awk '{printf \"%.1f\", \$3/\$2 * 100.0}'" 2>/dev/null || echo "0")
echo -n "  ${YELLOW}Memory Usage:${NC} "
if (( $(echo "$MEM_USAGE < 85" | bc -l) )); then
    echo -e "${GREEN}✅ ${MEM_USAGE}%${NC}"
    check_result
else
    echo -e "${RED}❌ ${MEM_USAGE}% (High)${NC}"
    check_result
fi

# Disk Usage
DISK_USAGE=$(run_remote "df -h $DEPLOY_PATH | awk 'NR==2 {print \$5}' | cut -d'%' -f1" 2>/dev/null || echo "0")
echo -n "  ${YELLOW}Disk Usage:${NC} "
if [ "$DISK_USAGE" -lt 85 ]; then
    echo -e "${GREEN}✅ ${DISK_USAGE}%${NC}"
    check_result
else
    echo -e "${RED}❌ ${DISK_USAGE}% (High)${NC}"
    check_result
fi

# 8. Verificar logs recentes por erros
echo -e "${BLUE}📋 Recent Errors${NC}"
echo -n "  ${YELLOW}API Errors (last 1h):${NC} "
API_ERRORS=$(run_remote "docker logs suporte-api --since 1h 2>&1 | grep -i error | wc -l" 2>/dev/null || echo "0")
if [ "$API_ERRORS" -eq 0 ]; then
    echo -e "${GREEN}✅ None${NC}"
    check_result
else
    echo -e "${YELLOW}⚠️  $API_ERRORS errors${NC}"
    check_result
fi

echo -n "  ${YELLOW}Portal Errors (last 1h):${NC} "
PORTAL_ERRORS=$(run_remote "docker logs suporte-portal --since 1h 2>&1 | grep -i error | wc -l" 2>/dev/null || echo "0")
if [ "$PORTAL_ERRORS" -eq 0 ]; then
    echo -e "${GREEN}✅ None${NC}"
    check_result
else
    echo -e "${YELLOW}⚠️  $PORTAL_ERRORS errors${NC}"
    check_result
fi

# Resumo final
echo ""
echo -e "${BLUE}📊 Health Check Summary${NC}"
echo "================================"

HEALTH_PERCENTAGE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

if [ "$HEALTH_PERCENTAGE" -eq 100 ]; then
    echo -e "${GREEN}🎉 ALL SYSTEMS HEALTHY${NC}"
    STATUS_COLOR=$GREEN
elif [ "$HEALTH_PERCENTAGE" -ge 80 ]; then
    echo -e "${YELLOW}⚠️  MOSTLY HEALTHY${NC}"
    STATUS_COLOR=$YELLOW
else
    echo -e "${RED}🚨 SYSTEM ISSUES DETECTED${NC}"
    STATUS_COLOR=$RED
fi

echo -e "${STATUS_COLOR}Passed: $PASSED_CHECKS/$TOTAL_CHECKS ($HEALTH_PERCENTAGE%)${NC}"

# Mostrar URLs úteis
echo ""
echo -e "${BLUE}🔗 Quick Links${NC}"
echo -e "   ${YELLOW}API Docs:${NC} https://$DOMAIN/api/suporte/docs"
echo -e "   ${YELLOW}Portal:${NC} https://$DOMAIN/portal/suporte/"
echo -e "   ${YELLOW}API Health:${NC} https://$DOMAIN/api/suporte/health"

# Exit code baseado na saúde
if [ "$HEALTH_PERCENTAGE" -ge 80 ]; then
    exit 0
else
    exit 1
fi