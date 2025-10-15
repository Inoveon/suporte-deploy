#!/bin/bash

# 🔧 Deploy Individual - API Suporte
# Deploy apenas da API FastAPI

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Diretórios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="$(dirname "$SCRIPT_DIR")"
BASE_DIR="$(dirname "$API_DIR")"
PROJECT_DIR="$API_DIR/suporte_chamados_api_fastapi"

echo -e "${BLUE}🔧 Deploy Individual - API Suporte${NC}"

# Verificar se o projeto foi clonado
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${RED}❌ Projeto API não encontrado em: $PROJECT_DIR${NC}"
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
echo -e "   ${YELLOW}Projeto:${NC} API Suporte"
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
run_remote "mkdir -p $REMOTE_DIR/api"

# Sincronizar arquivos
echo -e "${BLUE}📤 Sincronizando arquivos...${NC}"
rsync -avz --delete \
    --exclude='node_modules' \
    --exclude='__pycache__' \
    --exclude='.git' \
    --exclude='.env' \
    --exclude='logs/' \
    --exclude='uploads/' \
    "$PROJECT_DIR/" "$SSH_HOST:$REMOTE_DIR/api/src/"

# Copiar arquivos de deploy
echo -e "${BLUE}📤 Copiando configurações de deploy...${NC}"
scp "$SCRIPT_DIR/Dockerfile.prod" "$SSH_HOST:$REMOTE_DIR/api/"
scp "$SCRIPT_DIR/.env" "$SSH_HOST:$REMOTE_DIR/api/"

# Copiar docker-compose se existir
if [ -f "$SCRIPT_DIR/docker-compose.prod.yml" ]; then
    scp "$SCRIPT_DIR/docker-compose.prod.yml" "$SSH_HOST:$REMOTE_DIR/api/"
fi

# Build da imagem
echo -e "${BLUE}🔨 Fazendo build da imagem...${NC}"
run_remote "cd $REMOTE_DIR/api && docker build -f Dockerfile.prod -t suporte-api:latest ./src"

# Parar serviços existentes
echo -e "${BLUE}🛑 Parando serviços existentes...${NC}"
run_remote "cd $REMOTE_DIR && docker compose -p suporte stop suporte-api || true"

# Verificar se existe docker-compose geral
if run_remote "[ -f '$REMOTE_DIR/docker-compose.prod.yml' ]"; then
    echo -e "${BLUE}🚀 Usando docker-compose geral...${NC}"
    run_remote "cd $REMOTE_DIR && docker compose -f docker-compose.prod.yml up -d suporte-api"
else
    echo -e "${BLUE}🚀 Usando docker-compose local...${NC}"
    if [ -f "$SCRIPT_DIR/docker-compose.prod.yml" ]; then
        run_remote "cd $REMOTE_DIR/api && docker compose -f docker-compose.prod.yml up -d"
    else
        echo -e "${YELLOW}⚠️  Executando container diretamente...${NC}"
        run_remote "cd $REMOTE_DIR/api && docker run -d --name suporte-api --env-file .env --network database_net --network traefik_net \
            -p 8002:8002 \
            -l 'traefik.enable=true' \
            -l 'traefik.http.routers.suporte-api.rule=Host(\`office.inoveon.com.br\`) && PathPrefix(\`/api/suporte\`)' \
            -l 'traefik.http.routers.suporte-api.tls=true' \
            -l 'traefik.http.routers.suporte-api.tls.certresolver=letsencrypt' \
            -l 'traefik.http.services.suporte-api.loadbalancer.server.port=8002' \
            -l 'traefik.http.middlewares.suporte-api-stripprefix.stripprefix.prefixes=/api/suporte' \
            -l 'traefik.http.routers.suporte-api.middlewares=suporte-api-stripprefix' \
            -l 'traefik.http.routers.suporte-api-ip.rule=Host(\`10.0.20.11\`) && PathPrefix(\`/api/suporte\`)' \
            -l 'traefik.http.routers.suporte-api-ip.entrypoints=web' \
            -l 'traefik.http.routers.suporte-api-ip.service=suporte-api@docker' \
            -l 'traefik.http.routers.suporte-api-ip.middlewares=suporte-api-stripprefix' \
            suporte-api:latest"
    fi
fi

# Aguardar inicialização
echo -e "${BLUE}⏳ Aguardando inicialização...${NC}"
sleep 10

# Health check
echo -e "${BLUE}🏥 Verificando saúde da aplicação...${NC}"
for i in {1..30}; do
    if run_remote "docker exec suporte-api curl -f http://localhost:8002/health" &>/dev/null; then
        echo -e "${GREEN}✅ API está respondendo${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ API não está respondendo após 30 tentativas${NC}"
        echo -e "${YELLOW}📋 Logs do container:${NC}"
        run_remote "docker logs suporte-api --tail 50"
        exit 1
    fi
    sleep 2
done

# Verificar logs
echo -e "${BLUE}📋 Últimos logs:${NC}"
run_remote "docker logs suporte-api --tail 10"

# Limpeza de imagens antigas
echo -e "${BLUE}🧹 Limpando imagens antigas...${NC}"
run_remote "docker image prune -f"

echo ""
echo -e "${GREEN}🎉 Deploy da API concluído com sucesso!${NC}"
echo ""
echo -e "${YELLOW}🔗 URLs:${NC}"
echo -e "   ${BLUE}Health Check:${NC} https://office.inoveon.com.br/api/suporte/health"
echo -e "   ${BLUE}API Docs:${NC} https://office.inoveon.com.br/api/suporte/docs"
echo ""
echo -e "${YELLOW}🛠️  Comandos úteis:${NC}"
echo -e "   ${BLUE}Logs:${NC} ssh $SSH_HOST 'docker logs suporte-api -f'"
echo -e "   ${BLUE}Status:${NC} ssh $SSH_HOST 'docker ps | grep suporte-api'"
echo -e "   ${BLUE}Restart:${NC} ssh $SSH_HOST 'docker restart suporte-api'"
echo ""