#!/bin/bash

# 🚀 Clone Projects Script - Suporte Deploy
# Clona todos os projetos listados no projects.json

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Diretório base
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_FILE="$BASE_DIR/projects.json"

echo -e "${BLUE}🚀 Iniciando clone dos projetos...${NC}"

# Verificar se projects.json existe
if [ ! -f "$PROJECTS_FILE" ]; then
    echo -e "${RED}❌ Arquivo projects.json não encontrado!${NC}"
    exit 1
fi

# Verificar se jq está instalado
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  jq não está instalado. Instalando...${NC}"
    if command -v brew &> /dev/null; then
        brew install jq
    else
        echo -e "${RED}❌ Instale jq manualmente: https://jqlang.github.io/jq/download/${NC}"
        exit 1
    fi
fi

# Ler configurações do projects.json
PROJECT_NAME=$(jq -r '.project_name' "$PROJECTS_FILE")
COMPONENTS=$(jq -c '.components[]' "$PROJECTS_FILE")

echo -e "${GREEN}📋 Projeto: $PROJECT_NAME${NC}"
echo ""

# Clonar cada componente
while IFS= read -r component; do
    NAME=$(echo "$component" | jq -r '.name')
    REPO=$(echo "$component" | jq -r '.repo')
    PATH=$(echo "$component" | jq -r '.path')
    ENABLED=$(echo "$component" | jq -r '.enabled // true')
    
    # Pular se desabilitado
    if [ "$ENABLED" = "false" ]; then
        echo -e "${YELLOW}⏭️  Pulando $NAME (desabilitado)${NC}"
        continue
    fi
    
    FULL_PATH="$BASE_DIR/$PATH"
    
    echo -e "${BLUE}📦 Clonando $NAME...${NC}"
    echo -e "   ${YELLOW}Repo:${NC} $REPO"
    echo -e "   ${YELLOW}Path:${NC} $PATH"
    
    # Verificar se o diretório já existe
    if [ -d "$FULL_PATH" ]; then
        echo -e "${YELLOW}⚠️  Diretório $PATH já existe${NC}"
        read -p "   Deseja atualizar? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}🔄 Atualizando $NAME...${NC}"
            cd "$FULL_PATH"
            git pull
            echo -e "${GREEN}✅ $NAME atualizado${NC}"
        else
            echo -e "${YELLOW}⏭️  Pulando $NAME${NC}"
        fi
    else
        # Criar diretório pai se não existir
        mkdir -p "$(dirname "$FULL_PATH")"
        
        # Clonar repositório
        if git clone "$REPO" "$FULL_PATH"; then
            echo -e "${GREEN}✅ $NAME clonado com sucesso${NC}"
        else
            echo -e "${RED}❌ Erro ao clonar $NAME${NC}"
            exit 1
        fi
    fi
    
    echo ""
done <<< "$COMPONENTS"

echo -e "${GREEN}🎉 Todos os projetos foram clonados com sucesso!${NC}"
echo ""
echo -e "${BLUE}📁 Estrutura criada:${NC}"

# Mostrar estrutura criada
while IFS= read -r component; do
    NAME=$(echo "$component" | jq -r '.name')
    PATH=$(echo "$component" | jq -r '.path')
    ENABLED=$(echo "$component" | jq -r '.enabled // true')
    
    if [ "$ENABLED" = "true" ] && [ -d "$BASE_DIR/$PATH" ]; then
        echo -e "   ${GREEN}✅${NC} $PATH"
    fi
done <<< "$COMPONENTS"

echo ""
echo -e "${YELLOW}🔧 Próximos passos:${NC}"
echo -e "   1. Execute: ${BLUE}./setup.sh${NC}"
echo -e "   2. Configure as variáveis de ambiente"
echo -e "   3. Execute: ${BLUE}./deploy/deploy.sh${NC}"
echo ""