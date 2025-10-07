#!/bin/bash

# 🌐 Deploy Individual - Portal Suporte
# Deploy apenas do Portal React

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Diretórios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_DIR="$(dirname "$SCRIPT_DIR")"
BASE_DIR="$(dirname "$WEB_DIR")"
PROJECT_DIR="$WEB_DIR/suporte_dashboard_web_react"

echo -e "${BLUE}🌐 Deploy Individual - Portal Suporte${NC}"

# Verificar se o projeto foi clonado
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${RED}❌ Projeto Portal não encontrado em: $PROJECT_DIR${NC}"
    echo -e "${YELLOW}   Execute primeiro: cd $BASE_DIR && ./clone-projects.sh${NC}"
    exit 1
fi

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
source "$BASE_DIR/deploy/.env" 2>/dev/null || true

# Verificar variáveis obrigatórias
if [ -z "$SSH_HOST" ]; then
    echo -e "${RED}❌ SSH_HOST não configurado${NC}"
    exit 1
fi

echo -e "${GREEN}📋 Configurações:${NC}"
echo -e "   ${YELLOW}Servidor:${NC} $SSH_HOST"
echo -e "   ${YELLOW}Projeto:${NC} Portal Suporte"
echo -e "   ${YELLOW}Ambiente:${NC} $ENVIRONMENT"

# Função para executar comandos no servidor
run_remote() {
    ssh "$SSH_HOST" "$@"
}

# Verificar conexão SSH
echo -e "${BLUE}🔐 Verificando conexão SSH...${NC}"
if ! run_remote 'echo "SSH OK"' &>/dev/null; then
    echo -e "${RED}❌ Erro na conexão SSH${NC}"
    exit 1
fi

# Verificar Docker no servidor
echo -e "${BLUE}🐳 Verificando Docker no servidor...${NC}"
if ! run_remote 'docker --version' &>/dev/null; then
    echo -e "${RED}❌ Docker não encontrado no servidor${NC}"
    exit 1
fi

# Criar diretório de deploy no servidor
REMOTE_DIR="${DEPLOY_PATH:-/docker/inoveon/suporte}"
echo -e "${BLUE}📁 Criando diretório de deploy: $REMOTE_DIR${NC}"
run_remote "mkdir -p $REMOTE_DIR/web"

# Verificar se vite.config.ts está configurado corretamente
echo -e "${BLUE}🔍 Verificando configuração do Vite...${NC}"
if [ -f "$PROJECT_DIR/vite.config.ts" ]; then
    if grep -q "base.*portal.*suporte" "$PROJECT_DIR/vite.config.ts"; then
        echo -e "${GREEN}✅ Vite configurado para produção${NC}"
    else
        echo -e "${YELLOW}⚠️  Configurando base path no Vite...${NC}"
        # Backup do arquivo original
        cp "$PROJECT_DIR/vite.config.ts" "$PROJECT_DIR/vite.config.ts.backup"
        
        # Adicionar base path se não existir
        if ! grep -q "base:" "$PROJECT_DIR/vite.config.ts"; then
            sed -i.bak '/export default defineConfig/a\
  base: "/portal/suporte/",' "$PROJECT_DIR/vite.config.ts"
        fi
    fi
fi

# Sincronizar arquivos do projeto
echo -e "${BLUE}📤 Sincronizando arquivos do projeto...${NC}"
rsync -avz --delete \
    --exclude='node_modules' \
    --exclude='dist' \
    --exclude='build' \
    --exclude='.git' \
    --exclude='.env.local' \
    --exclude='.vite' \
    "$PROJECT_DIR/" "$SSH_HOST:$REMOTE_DIR/web/src/"

# Copiar arquivos de deploy
echo -e "${BLUE}📤 Copiando configurações de deploy...${NC}"
scp "$SCRIPT_DIR/Dockerfile.prod" "$SSH_HOST:$REMOTE_DIR/web/"
scp "$SCRIPT_DIR/.env" "$SSH_HOST:$REMOTE_DIR/web/"

# Copiar docker-compose se existir
if [ -f "$SCRIPT_DIR/docker-compose.prod.yml" ]; then
    scp "$SCRIPT_DIR/docker-compose.prod.yml" "$SSH_HOST:$REMOTE_DIR/web/"
fi

# Build da imagem
echo -e "${BLUE}🔨 Fazendo build da imagem...${NC}"
run_remote "cd $REMOTE_DIR/web && docker build -f Dockerfile.prod -t suporte-portal:latest ./src"

# Parar serviços existentes
echo -e "${BLUE}🛑 Parando serviços existentes...${NC}"
run_remote "cd $REMOTE_DIR && docker compose -p suporte stop suporte-portal || true"

# Verificar se existe docker-compose geral
if run_remote "[ -f '$REMOTE_DIR/docker-compose.prod.yml' ]"; then
    echo -e "${BLUE}🚀 Usando docker-compose geral...${NC}"
    run_remote "cd $REMOTE_DIR && docker compose -f docker-compose.prod.yml up -d suporte-portal"
else
    echo -e "${BLUE}🚀 Usando docker-compose local...${NC}"
    if [ -f "$SCRIPT_DIR/docker-compose.prod.yml" ]; then
        run_remote "cd $REMOTE_DIR/web && docker compose -f docker-compose.prod.yml up -d"
    else
        echo -e "${YELLOW}⚠️  Executando container diretamente...${NC}"
        run_remote "cd $REMOTE_DIR/web && docker run -d --name suporte-portal --env-file .env -p 80:80 suporte-portal:latest"
    fi
fi

# Aguardar inicialização
echo -e "${BLUE}⏳ Aguardando inicialização...${NC}"
sleep 5

# Health check
echo -e "${BLUE}🏥 Verificando saúde da aplicação...${NC}"
for i in {1..15}; do
    if run_remote "curl -f http://localhost:80/health" &>/dev/null; then
        echo -e "${GREEN}✅ Portal está respondendo${NC}"
        break
    fi
    if [ $i -eq 15 ]; then
        echo -e "${RED}❌ Portal não está respondendo após 15 tentativas${NC}"
        echo -e "${YELLOW}📋 Logs do container:${NC}"
        run_remote "docker logs suporte-portal --tail 50"
        exit 1
    fi
    sleep 2
done

# Verificar se assets estão sendo servidos corretamente
echo -e "${BLUE}🎨 Verificando assets...${NC}"
if run_remote "curl -f http://localhost:80/portal/suporte/" &>/dev/null; then
    echo -e "${GREEN}✅ Portal acessível${NC}"
else
    echo -e "${YELLOW}⚠️  Portal pode ter problemas de roteamento${NC}"
fi

# Verificar logs
echo -e "${BLUE}📋 Últimos logs:${NC}"
run_remote "docker logs suporte-portal --tail 10"

# Limpeza de imagens antigas
echo -e "${BLUE}🧹 Limpando imagens antigas...${NC}"
run_remote "docker image prune -f"

echo ""
echo -e "${GREEN}🎉 Deploy do Portal concluído com sucesso!${NC}"
echo ""
echo -e "${YELLOW}🔗 URLs:${NC}"
echo -e "   ${BLUE}Portal:${NC} https://office.inoveon.com.br/portal/suporte/"
echo -e "   ${BLUE}Health:${NC} https://office.inoveon.com.br/portal/suporte/ (deve retornar página)"
echo ""
echo -e "${YELLOW}🛠️  Comandos úteis:${NC}"
echo -e "   ${BLUE}Logs:${NC} ssh $SSH_HOST 'docker logs suporte-portal -f'"
echo -e "   ${BLUE}Status:${NC} ssh $SSH_HOST 'docker ps | grep suporte-portal'"
echo -e "   ${BLUE}Restart:${NC} ssh $SSH_HOST 'docker restart suporte-portal'"
echo ""

# Restaurar backup do vite.config.ts se foi modificado
if [ -f "$PROJECT_DIR/vite.config.ts.backup" ]; then
    echo -e "${BLUE}🔄 Restaurando vite.config.ts original...${NC}"
    mv "$PROJECT_DIR/vite.config.ts.backup" "$PROJECT_DIR/vite.config.ts"
fi