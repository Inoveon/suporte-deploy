#!/bin/bash

# 💾 Backup Script - Sistema Suporte
# Backup completo de dados e configurações

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

# Configurações de backup
BACKUP_BASE_DIR="${BACKUP_PATH:-/backup/suporte}"
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
BACKUP_DIR="$BACKUP_BASE_DIR/$TIMESTAMP"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"

echo -e "${BLUE}💾 Backup Sistema Suporte${NC}"
echo -e "${YELLOW}Timestamp: $TIMESTAMP${NC}"
echo -e "${YELLOW}Backup Dir: $BACKUP_DIR${NC}"
echo ""

# Função para executar no servidor
run_remote() {
    ssh "$SSH_HOST" "$@"
}

# Função para mostrar ajuda
show_help() {
    echo -e "${BLUE}💾 Backup Script - Sistema Suporte${NC}"
    echo ""
    echo -e "${YELLOW}Uso:${NC}"
    echo "  $0 [TIPO] [OPÇÕES]"
    echo ""
    echo -e "${YELLOW}Tipos:${NC}"
    echo "  full             Backup completo (padrão)"
    echo "  database         Apenas banco de dados"
    echo "  files            Apenas arquivos/uploads"
    echo "  config           Apenas configurações"
    echo "  list             Listar backups existentes"
    echo "  restore BACKUP   Restaurar backup específico"
    echo "  clean            Limpar backups antigos"
    echo ""
    echo -e "${YELLOW}Opções:${NC}"
    echo "  --compress       Comprimir backup (recomendado)"
    echo "  --encrypt        Criptografar backup"
    echo "  --remote-only    Manter backup apenas no servidor"
    echo "  --help           Mostra esta ajuda"
    echo ""
    echo -e "${YELLOW}Exemplos:${NC}"
    echo "  $0 full --compress"
    echo "  $0 database"
    echo "  $0 restore backup_20250107_143022"
    echo ""
}

# Configurações padrão
BACKUP_TYPE="full"
COMPRESS=false
ENCRYPT=false
REMOTE_ONLY=false

# Processar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        full|database|files|config|list|clean)
            BACKUP_TYPE="$1"
            shift
            ;;
        restore)
            BACKUP_TYPE="restore"
            RESTORE_NAME="$2"
            shift 2
            ;;
        --compress)
            COMPRESS=true
            shift
            ;;
        --encrypt)
            ENCRYPT=true
            shift
            ;;
        --remote-only)
            REMOTE_ONLY=true
            shift
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

# Verificar pré-requisitos
check_prerequisites() {
    echo -e "${BLUE}🔍 Verificando pré-requisitos...${NC}"
    
    # Verificar SSH
    if ! run_remote 'echo "SSH OK"' &>/dev/null; then
        echo -e "${RED}❌ Erro na conexão SSH${NC}"
        exit 1
    fi
    
    # Criar diretório de backup no servidor
    run_remote "mkdir -p $BACKUP_BASE_DIR"
    
    echo -e "${GREEN}✅ Pré-requisitos OK${NC}"
}

# Backup do banco de dados
backup_database() {
    echo -e "${BLUE}🗄️  Backup do banco de dados...${NC}"
    
    local db_backup="$BACKUP_DIR/database"
    run_remote "mkdir -p $db_backup"
    
    # PostgreSQL dump
    echo -e "${YELLOW}  Fazendo dump do PostgreSQL...${NC}"
    run_remote "docker exec suporte-db pg_dump -U suporte_user -d suporte_chamados > $db_backup/postgres_dump.sql"
    
    # Informações do banco
    run_remote "docker exec suporte-db psql -U suporte_user -d suporte_chamados -c '\l' > $db_backup/database_info.txt"
    run_remote "docker exec suporte-db psql -U suporte_user -d suporte_chamados -c 'SELECT schemaname,tablename,tableowner FROM pg_tables WHERE schemaname='\''public'\'';' > $db_backup/tables_info.txt"
    
    # Redis dump (se existir)
    if run_remote "docker ps --filter name=suporte-redis --quiet" | grep -q .; then
        echo -e "${YELLOW}  Fazendo backup do Redis...${NC}"
        run_remote "docker exec suporte-redis redis-cli SAVE"
        run_remote "docker cp suporte-redis:/data/dump.rdb $db_backup/redis_dump.rdb"
    fi
    
    echo -e "${GREEN}✅ Backup do banco concluído${NC}"
}

# Backup de arquivos
backup_files() {
    echo -e "${BLUE}📁 Backup de arquivos...${NC}"
    
    local files_backup="$BACKUP_DIR/files"
    run_remote "mkdir -p $files_backup"
    
    # Uploads da API
    if run_remote "[ -d '$DEPLOY_PATH/api/uploads' ]"; then
        echo -e "${YELLOW}  Backup de uploads da API...${NC}"
        run_remote "cp -r $DEPLOY_PATH/api/uploads $files_backup/api_uploads"
    fi
    
    # Logs
    echo -e "${YELLOW}  Backup de logs...${NC}"
    run_remote "mkdir -p $files_backup/logs"
    
    # Logs dos containers
    for container in suporte-api suporte-portal suporte-db suporte-redis; do
        if run_remote "docker ps --filter name=$container --quiet" | grep -q .; then
            run_remote "docker logs $container --since 7d > $files_backup/logs/${container}.log 2>&1" || true
        fi
    done
    
    # Logs do sistema
    if run_remote "[ -d '$DEPLOY_PATH/logs' ]"; then
        run_remote "cp -r $DEPLOY_PATH/logs/* $files_backup/logs/" || true
    fi
    
    echo -e "${GREEN}✅ Backup de arquivos concluído${NC}"
}

# Backup de configurações
backup_config() {
    echo -e "${BLUE}⚙️  Backup de configurações...${NC}"
    
    local config_backup="$BACKUP_DIR/config"
    run_remote "mkdir -p $config_backup"
    
    # Docker Compose
    if run_remote "[ -f '$DEPLOY_PATH/docker-compose.prod.yml' ]"; then
        run_remote "cp $DEPLOY_PATH/docker-compose.prod.yml $config_backup/"
    fi
    
    # Environment files (sem senhas)
    for env_file in "$DEPLOY_PATH/.env" "$DEPLOY_PATH/api/.env" "$DEPLOY_PATH/web/.env"; do
        if run_remote "[ -f '$env_file' ]"; then
            local filename=$(basename "$env_file")
            local dirname=$(basename "$(dirname "$env_file")")
            run_remote "mkdir -p $config_backup/$dirname"
            # Filtrar senhas sensíveis
            run_remote "grep -v -E '(PASSWORD|SECRET|KEY)=' '$env_file' > '$config_backup/$dirname/$filename' || cp '$env_file' '$config_backup/$dirname/$filename'"
        fi
    done
    
    # Dockerfiles
    for dockerfile in "$DEPLOY_PATH/api/Dockerfile.prod" "$DEPLOY_PATH/web/Dockerfile.prod"; do
        if run_remote "[ -f '$dockerfile' ]"; then
            local dirname=$(basename "$(dirname "$dockerfile")")
            run_remote "mkdir -p $config_backup/$dirname"
            run_remote "cp '$dockerfile' '$config_backup/$dirname/'"
        fi
    done
    
    # Nginx configs
    if run_remote "docker exec suporte-portal ls /etc/nginx/conf.d/" &>/dev/null; then
        run_remote "mkdir -p $config_backup/nginx"
        run_remote "docker cp suporte-portal:/etc/nginx/conf.d/ $config_backup/nginx/" || true
    fi
    
    # Informações do sistema
    echo -e "${YELLOW}  Coletando informações do sistema...${NC}"
    run_remote "docker ps > $config_backup/docker_containers.txt"
    run_remote "docker images > $config_backup/docker_images.txt"
    run_remote "docker network ls > $config_backup/docker_networks.txt"
    run_remote "docker volume ls > $config_backup/docker_volumes.txt"
    run_remote "df -h > $config_backup/disk_usage.txt"
    run_remote "free -h > $config_backup/memory_usage.txt"
    run_remote "uname -a > $config_backup/system_info.txt"
    
    echo -e "${GREEN}✅ Backup de configurações concluído${NC}"
}

# Comprimir backup
compress_backup() {
    if [ "$COMPRESS" = true ]; then
        echo -e "${BLUE}🗜️  Comprimindo backup...${NC}"
        run_remote "cd $BACKUP_BASE_DIR && tar -czf ${TIMESTAMP}.tar.gz $TIMESTAMP && rm -rf $TIMESTAMP"
        echo -e "${GREEN}✅ Backup comprimido: ${TIMESTAMP}.tar.gz${NC}"
    fi
}

# Criptografar backup
encrypt_backup() {
    if [ "$ENCRYPT" = true ]; then
        echo -e "${BLUE}🔐 Criptografando backup...${NC}"
        
        if [ "$COMPRESS" = true ]; then
            local file="${TIMESTAMP}.tar.gz"
        else
            local file="$TIMESTAMP"
            # Comprimir antes de criptografar se não foi comprimido
            run_remote "cd $BACKUP_BASE_DIR && tar -czf ${TIMESTAMP}.tar.gz $TIMESTAMP && rm -rf $TIMESTAMP"
            file="${TIMESTAMP}.tar.gz"
        fi
        
        # Usar OpenSSL para criptografia (requer senha)
        echo -e "${YELLOW}Digite a senha para criptografia:${NC}"
        run_remote "cd $BACKUP_BASE_DIR && openssl enc -aes-256-cbc -salt -in $file -out ${file}.enc && rm $file"
        echo -e "${GREEN}✅ Backup criptografado: ${file}.enc${NC}"
    fi
}

# Listar backups
list_backups() {
    echo -e "${BLUE}📋 Backups existentes:${NC}"
    echo ""
    
    run_remote "ls -la $BACKUP_BASE_DIR/" | grep -E '^d|\.tar\.gz|\.enc' | while read -r line; do
        echo "  $line"
    done
    
    echo ""
    echo -e "${YELLOW}Uso do disco:${NC}"
    run_remote "du -sh $BACKUP_BASE_DIR/*" 2>/dev/null || echo "  Nenhum backup encontrado"
}

# Limpar backups antigos
clean_old_backups() {
    echo -e "${BLUE}🧹 Limpando backups antigos (> $RETENTION_DAYS dias)...${NC}"
    
    local count=$(run_remote "find $BACKUP_BASE_DIR -maxdepth 1 -type d -mtime +$RETENTION_DAYS | wc -l")
    local count_files=$(run_remote "find $BACKUP_BASE_DIR -maxdepth 1 -name '*.tar.gz' -mtime +$RETENTION_DAYS | wc -l")
    local count_enc=$(run_remote "find $BACKUP_BASE_DIR -maxdepth 1 -name '*.enc' -mtime +$RETENTION_DAYS | wc -l")
    
    local total=$((count + count_files + count_enc))
    
    if [ "$total" -gt 0 ]; then
        echo -e "${YELLOW}Encontrados $total backups antigos${NC}"
        run_remote "find $BACKUP_BASE_DIR -maxdepth 1 -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \;"
        run_remote "find $BACKUP_BASE_DIR -maxdepth 1 -name '*.tar.gz' -mtime +$RETENTION_DAYS -delete"
        run_remote "find $BACKUP_BASE_DIR -maxdepth 1 -name '*.enc' -mtime +$RETENTION_DAYS -delete"
        echo -e "${GREEN}✅ $total backups antigos removidos${NC}"
    else
        echo -e "${GREEN}✅ Nenhum backup antigo encontrado${NC}"
    fi
}

# Restaurar backup
restore_backup() {
    local backup_name="$1"
    
    if [ -z "$backup_name" ]; then
        echo -e "${RED}❌ Nome do backup não especificado${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🔄 Restaurando backup: $backup_name${NC}"
    echo -e "${RED}⚠️  ATENÇÃO: Esta operação irá substituir os dados atuais!${NC}"
    
    read -p "Tem certeza que deseja continuar? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Operação cancelada${NC}"
        exit 0
    fi
    
    # Verificar se backup existe
    if ! run_remote "[ -d '$BACKUP_BASE_DIR/$backup_name' ] || [ -f '$BACKUP_BASE_DIR/${backup_name}.tar.gz' ] || [ -f '$BACKUP_BASE_DIR/${backup_name}.tar.gz.enc' ]"; then
        echo -e "${RED}❌ Backup não encontrado: $backup_name${NC}"
        exit 1
    fi
    
    # Parar serviços
    echo -e "${YELLOW}Parando serviços...${NC}"
    run_remote "cd $DEPLOY_PATH && docker compose -f docker-compose.prod.yml down"
    
    # Descomprimir se necessário
    if run_remote "[ -f '$BACKUP_BASE_DIR/${backup_name}.tar.gz' ]"; then
        echo -e "${YELLOW}Descomprimindo backup...${NC}"
        run_remote "cd $BACKUP_BASE_DIR && tar -xzf ${backup_name}.tar.gz"
    fi
    
    # Restaurar banco de dados
    if run_remote "[ -f '$BACKUP_BASE_DIR/$backup_name/database/postgres_dump.sql' ]"; then
        echo -e "${YELLOW}Restaurando banco de dados...${NC}"
        # Reiniciar apenas o banco
        run_remote "cd $DEPLOY_PATH && docker compose -f docker-compose.prod.yml up -d suporte-db"
        sleep 10
        run_remote "docker exec -i suporte-db psql -U suporte_user -d suporte_chamados < $BACKUP_BASE_DIR/$backup_name/database/postgres_dump.sql"
    fi
    
    # Restaurar arquivos
    if run_remote "[ -d '$BACKUP_BASE_DIR/$backup_name/files' ]"; then
        echo -e "${YELLOW}Restaurando arquivos...${NC}"
        run_remote "cp -r $BACKUP_BASE_DIR/$backup_name/files/* $DEPLOY_PATH/" || true
    fi
    
    # Reiniciar todos os serviços
    echo -e "${YELLOW}Reiniciando serviços...${NC}"
    run_remote "cd $DEPLOY_PATH && docker compose -f docker-compose.prod.yml up -d"
    
    echo -e "${GREEN}✅ Restauração concluída${NC}"
}

# Executar baseado no tipo
case $BACKUP_TYPE in
    full)
        check_prerequisites
        echo -e "${BLUE}🔄 Iniciando backup completo...${NC}"
        run_remote "mkdir -p $BACKUP_DIR"
        backup_database
        backup_files
        backup_config
        
        # Criar arquivo de metadados
        run_remote "cat > $BACKUP_DIR/backup_info.txt << EOF
Backup Type: Full
Timestamp: $TIMESTAMP
Server: $SSH_HOST
Domain: $DOMAIN
Environment: $ENVIRONMENT
Created: $(date)
EOF"
        
        compress_backup
        encrypt_backup
        clean_old_backups
        echo -e "${GREEN}🎉 Backup completo concluído${NC}"
        ;;
    database)
        check_prerequisites
        run_remote "mkdir -p $BACKUP_DIR"
        backup_database
        compress_backup
        echo -e "${GREEN}✅ Backup do banco concluído${NC}"
        ;;
    files)
        check_prerequisites
        run_remote "mkdir -p $BACKUP_DIR"
        backup_files
        compress_backup
        echo -e "${GREEN}✅ Backup de arquivos concluído${NC}"
        ;;
    config)
        check_prerequisites
        run_remote "mkdir -p $BACKUP_DIR"
        backup_config
        compress_backup
        echo -e "${GREEN}✅ Backup de configurações concluído${NC}"
        ;;
    list)
        list_backups
        ;;
    restore)
        restore_backup "$RESTORE_NAME"
        ;;
    clean)
        clean_old_backups
        ;;
    *)
        echo -e "${RED}❌ Tipo de backup desconhecido: $BACKUP_TYPE${NC}"
        show_help
        exit 1
        ;;
esac