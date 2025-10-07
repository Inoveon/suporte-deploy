#!/bin/bash

# 🛠️ Setup Script - Suporte Deploy
# Configuração inicial do ambiente de deploy

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Diretório base
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_FILE="$BASE_DIR/projects.json"

echo -e "${BLUE}🛠️  Setup do ambiente de deploy...${NC}"

# Verificar se projects.json existe
if [ ! -f "$PROJECTS_FILE" ]; then
    echo -e "${RED}❌ Arquivo projects.json não encontrado!${NC}"
    exit 1
fi

# Verificar dependências
echo -e "${BLUE}🔍 Verificando dependências...${NC}"

# jq
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  Instalando jq...${NC}"
    if command -v brew &> /dev/null; then
        brew install jq
    else
        echo -e "${RED}❌ Instale jq manualmente: https://jqlang.github.io/jq/download/${NC}"
        exit 1
    fi
fi

# Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker não encontrado. Instale: https://docker.com${NC}"
    exit 1
fi

# Docker Compose
if ! command -v docker compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose não encontrado.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Dependências OK${NC}"

# Ler configurações
PROJECT_NAME=$(jq -r '.project_name' "$PROJECTS_FILE")
SERVER=$(jq -r '.server' "$PROJECTS_FILE")
SSH_HOST=$(jq -r '.ssh_host' "$PROJECTS_FILE")

echo -e "${GREEN}📋 Projeto: $PROJECT_NAME${NC}"
echo -e "${GREEN}🖥️  Servidor: $SERVER${NC}"

# Verificar conexão SSH
echo -e "${BLUE}🔐 Verificando conexão SSH...${NC}"
if ssh -o ConnectTimeout=5 "$SSH_HOST" 'echo "SSH OK"' &>/dev/null; then
    echo -e "${GREEN}✅ SSH conectado${NC}"
else
    echo -e "${RED}❌ Erro na conexão SSH com $SSH_HOST${NC}"
    echo -e "${YELLOW}   Verifique a configuração em ~/.ssh/config${NC}"
    exit 1
fi

# Verificar Docker no servidor
echo -e "${BLUE}🐳 Verificando Docker no servidor...${NC}"
if ssh "$SSH_HOST" 'docker --version && docker compose version' &>/dev/null; then
    echo -e "${GREEN}✅ Docker OK no servidor${NC}"
else
    echo -e "${RED}❌ Docker não encontrado no servidor${NC}"
    exit 1
fi

# Criar templates .env se não existirem
echo -e "${BLUE}📝 Configurando templates .env...${NC}"

# Template geral
if [ ! -f "$BASE_DIR/deploy/.env" ]; then
    if [ -f "$BASE_DIR/deploy/.env.template" ]; then
        cp "$BASE_DIR/deploy/.env.template" "$BASE_DIR/deploy/.env"
        echo -e "${YELLOW}📄 Criado deploy/.env a partir do template${NC}"
    fi
fi

# Templates dos componentes
COMPONENTS=$(jq -c '.components[]' "$PROJECTS_FILE")
while IFS= read -r component; do
    NAME=$(echo "$component" | jq -r '.name')
    ENABLED=$(echo "$component" | jq -r '.enabled // true')
    
    if [ "$ENABLED" = "true" ]; then
        ENV_TEMPLATE="$BASE_DIR/$NAME/deploy/.env.template"
        ENV_FILE="$BASE_DIR/$NAME/deploy/.env"
        
        if [ -f "$ENV_TEMPLATE" ] && [ ! -f "$ENV_FILE" ]; then
            cp "$ENV_TEMPLATE" "$ENV_FILE"
            echo -e "${YELLOW}📄 Criado $NAME/deploy/.env a partir do template${NC}"
        fi
    fi
done <<< "$COMPONENTS"

# Verificar se os projetos foram clonados
echo -e "${BLUE}📦 Verificando projetos clonados...${NC}"
ALL_CLONED=true

while IFS= read -r component; do
    PATH=$(echo "$component" | jq -r '.path')
    ENABLED=$(echo "$component" | jq -r '.enabled // true')
    
    if [ "$ENABLED" = "true" ]; then
        if [ -d "$BASE_DIR/$PATH" ]; then
            echo -e "${GREEN}✅ $PATH${NC}"
        else
            echo -e "${RED}❌ $PATH não encontrado${NC}"
            ALL_CLONED=false
        fi
    fi
done <<< "$COMPONENTS"

if [ "$ALL_CLONED" = false ]; then
    echo -e "${YELLOW}⚠️  Execute primeiro: ./clone-projects.sh${NC}"
fi

# Verificar estrutura de deploy
echo -e "${BLUE}🏗️  Verificando estrutura de deploy...${NC}"

REQUIRED_DIRS=(
    "deploy"
    "api/deploy"
    "web/deploy"
    "scripts"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$BASE_DIR/$dir" ]; then
        echo -e "${GREEN}✅ $dir/${NC}"
    else
        echo -e "${RED}❌ $dir/ não encontrado${NC}"
    fi
done

echo ""
echo -e "${GREEN}🎉 Setup concluído!${NC}"
echo ""
echo -e "${YELLOW}🔧 Próximos passos:${NC}"
echo -e "   1. Configure as variáveis em ${BLUE}deploy/.env${NC}"
echo -e "   2. Configure as variáveis em ${BLUE}api/deploy/.env${NC}"
echo -e "   3. Configure as variáveis em ${BLUE}web/deploy/.env${NC}"
echo -e "   4. Execute: ${BLUE}./deploy/deploy.sh${NC}"
echo ""
echo -e "${BLUE}📚 Documentação:${NC}"
echo -e "   • ${YELLOW}docs/DEPLOY-ARCHITECTURE.md${NC} - Arquitetura completa"
echo -e "   • ${YELLOW}README.md${NC} - Instruções de uso"
echo ""