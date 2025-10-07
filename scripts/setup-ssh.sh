#!/bin/bash

# 🔐 Setup SSH Script - Configuração Automática de Chaves SSH
# Verifica, cria e configura chaves SSH para deploy automático

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Banner
echo -e "${PURPLE}"
echo "┌─────────────────────────────────────────────────┐"
echo "│                                                 │"
echo "│        🔐 SSH SETUP - SUPORTE DEPLOY           │"
echo "│                                                 │"
echo "│      Configuração Automática de SSH            │"
echo "│                                                 │"
echo "└─────────────────────────────────────────────────┘"
echo -e "${NC}"

# Configurações
SSH_KEY_NAME="id_rsa_i9_deploy"
SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY_NAME"
SSH_CONFIG_PATH="$HOME/.ssh/config"
SSH_HOST_ALIAS="i9-deploy"

# Função de ajuda
show_help() {
    echo -e "${BLUE}🔐 Setup SSH - Configuração Automática${NC}"
    echo ""
    echo -e "${YELLOW}Uso:${NC}"
    echo "  $0 [SERVER_IP] [USERNAME] [PASSWORD]"
    echo ""
    echo -e "${YELLOW}Parâmetros:${NC}"
    echo "  SERVER_IP    IP do servidor (ex: 10.0.20.11)"
    echo "  USERNAME     Usuário SSH (ex: lee)"
    echo "  PASSWORD     Senha inicial (apenas primeira vez)"
    echo ""
    echo -e "${YELLOW}Opções:${NC}"
    echo "  --check-only     Apenas verificar configuração existente"
    echo "  --force-new      Forçar criação de nova chave"
    echo "  --help           Mostra esta ajuda"
    echo ""
    echo -e "${YELLOW}Exemplos:${NC}"
    echo "  $0 10.0.20.11 lee mypassword"
    echo "  $0 --check-only"
    echo "  $0 10.0.20.11 lee mypassword --force-new"
    echo ""
    echo -e "${YELLOW}Pré-requisitos:${NC}"
    echo "  • sshpass instalado (brew install sshpass)"
    echo "  • ssh-copy-id disponível"
    echo ""
}

# Configurações padrão
SERVER_IP=""
USERNAME=""
PASSWORD=""
CHECK_ONLY=false
FORCE_NEW=false

# Processar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --check-only)
            CHECK_ONLY=true
            shift
            ;;
        --force-new)
            FORCE_NEW=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        -*)
            echo -e "${RED}❌ Opção desconhecida: $1${NC}"
            show_help
            exit 1
            ;;
        *)
            if [ -z "$SERVER_IP" ]; then
                SERVER_IP="$1"
            elif [ -z "$USERNAME" ]; then
                USERNAME="$1"
            elif [ -z "$PASSWORD" ]; then
                PASSWORD="$1"
            else
                echo -e "${RED}❌ Muitos argumentos${NC}"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Verificar se é apenas check
if [ "$CHECK_ONLY" = true ]; then
    echo -e "${BLUE}🔍 Verificando configuração SSH existente...${NC}"
    # Lógica de verificação será implementada abaixo
elif [ -z "$SERVER_IP" ] || [ -z "$USERNAME" ]; then
    echo -e "${RED}❌ Parâmetros obrigatórios em falta${NC}"
    echo ""
    show_help
    exit 1
fi

# Se não forneceu senha e não é check-only, solicitar
if [ "$CHECK_ONLY" = false ] && [ -z "$PASSWORD" ]; then
    echo -e "${YELLOW}Digite a senha para $USERNAME@$SERVER_IP:${NC}"
    read -s PASSWORD
    echo
fi

echo -e "${GREEN}📋 Configurações:${NC}"
if [ "$CHECK_ONLY" = false ]; then
    echo -e "   ${YELLOW}Servidor:${NC} $USERNAME@$SERVER_IP"
fi
echo -e "   ${YELLOW}Chave SSH:${NC} $SSH_KEY_PATH"
echo -e "   ${YELLOW}Host Alias:${NC} $SSH_HOST_ALIAS"
echo ""

# Verificar pré-requisitos
check_prerequisites() {
    echo -e "${BLUE}🔍 Verificando pré-requisitos...${NC}"
    
    # Verificar se ssh está disponível
    if ! command -v ssh &> /dev/null; then
        echo -e "${RED}❌ SSH não encontrado${NC}"
        exit 1
    fi
    
    # Verificar se ssh-keygen está disponível
    if ! command -v ssh-keygen &> /dev/null; then
        echo -e "${RED}❌ ssh-keygen não encontrado${NC}"
        exit 1
    fi
    
    # Verificar sshpass (apenas se não for check-only)
    if [ "$CHECK_ONLY" = false ] && ! command -v sshpass &> /dev/null; then
        echo -e "${YELLOW}⚠️  sshpass não encontrado. Instalando...${NC}"
        if command -v brew &> /dev/null; then
            brew install sshpass
        else
            echo -e "${RED}❌ Instale sshpass manualmente${NC}"
            echo -e "${YELLOW}   macOS: brew install sshpass${NC}"
            echo -e "${YELLOW}   Ubuntu: sudo apt-get install sshpass${NC}"
            exit 1
        fi
    fi
    
    # Verificar ssh-copy-id (apenas se não for check-only)
    if [ "$CHECK_ONLY" = false ] && ! command -v ssh-copy-id &> /dev/null; then
        echo -e "${RED}❌ ssh-copy-id não encontrado${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Pré-requisitos OK${NC}"
}

# Criar diretório .ssh se não existir
ensure_ssh_directory() {
    if [ ! -d "$HOME/.ssh" ]; then
        echo -e "${YELLOW}📁 Criando diretório .ssh...${NC}"
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
    fi
}

# Verificar se chave SSH existe
check_ssh_key() {
    echo -e "${BLUE}🔑 Verificando chave SSH...${NC}"
    
    if [ -f "$SSH_KEY_PATH" ] && [ -f "${SSH_KEY_PATH}.pub" ]; then
        echo -e "${GREEN}✅ Chave SSH encontrada${NC}"
        
        # Mostrar fingerprint
        local fingerprint=$(ssh-keygen -lf "${SSH_KEY_PATH}.pub" | cut -d' ' -f2)
        echo -e "${YELLOW}   Fingerprint: $fingerprint${NC}"
        
        # Verificar se força nova chave
        if [ "$FORCE_NEW" = true ]; then
            echo -e "${YELLOW}⚠️  Forçando criação de nova chave (--force-new)${NC}"
            return 1
        fi
        
        return 0
    else
        echo -e "${YELLOW}⚠️  Chave SSH não encontrada${NC}"
        return 1
    fi
}

# Criar nova chave SSH
create_ssh_key() {
    echo -e "${BLUE}🔑 Criando nova chave SSH...${NC}"
    
    # Backup de chave existente se houver
    if [ -f "$SSH_KEY_PATH" ]; then
        local backup_suffix=$(date +%Y%m%d_%H%M%S)
        echo -e "${YELLOW}💾 Fazendo backup da chave existente...${NC}"
        cp "$SSH_KEY_PATH" "${SSH_KEY_PATH}.backup.$backup_suffix"
        cp "${SSH_KEY_PATH}.pub" "${SSH_KEY_PATH}.pub.backup.$backup_suffix"
    fi
    
    # Gerar nova chave
    echo -e "${YELLOW}⚙️  Gerando chave RSA 4096 bits...${NC}"
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "i9-deploy@$(hostname)"
    
    # Definir permissões corretas
    chmod 600 "$SSH_KEY_PATH"
    chmod 644 "${SSH_KEY_PATH}.pub"
    
    echo -e "${GREEN}✅ Chave SSH criada com sucesso${NC}"
    
    # Mostrar fingerprint da nova chave
    local fingerprint=$(ssh-keygen -lf "${SSH_KEY_PATH}.pub" | cut -d' ' -f2)
    echo -e "${YELLOW}   Fingerprint: $fingerprint${NC}"
}

# Configurar SSH config
setup_ssh_config() {
    echo -e "${BLUE}⚙️  Configurando SSH config...${NC}"
    
    # Verificar se configuração já existe
    if grep -q "Host $SSH_HOST_ALIAS" "$SSH_CONFIG_PATH" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Configuração SSH já existe${NC}"
        
        # Verificar se está usando a chave correta
        if grep -A 5 "Host $SSH_HOST_ALIAS" "$SSH_CONFIG_PATH" | grep -q "$SSH_KEY_NAME"; then
            echo -e "${GREEN}✅ Configuração SSH está correta${NC}"
            return 0
        else
            echo -e "${YELLOW}🔄 Atualizando configuração SSH...${NC}"
            # Remover configuração antiga
            sed -i.bak "/Host $SSH_HOST_ALIAS/,/^$/d" "$SSH_CONFIG_PATH"
        fi
    fi
    
    # Adicionar nova configuração
    echo -e "${YELLOW}➕ Adicionando configuração SSH...${NC}"
    cat >> "$SSH_CONFIG_PATH" << EOF

# i9 Deploy Configuration - Auto-generated
Host $SSH_HOST_ALIAS
    HostName $SERVER_IP
    User $USERNAME
    IdentityFile $SSH_KEY_PATH
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ServerAliveInterval 60
    ServerAliveCountMax 3
    LogLevel ERROR
EOF
    
    # Definir permissões corretas
    chmod 600 "$SSH_CONFIG_PATH"
    
    echo -e "${GREEN}✅ SSH config configurado${NC}"
}

# Testar conectividade com senha
test_password_connection() {
    echo -e "${BLUE}🔐 Testando conectividade com senha...${NC}"
    
    if sshpass -p "$PASSWORD" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$USERNAME@$SERVER_IP" 'echo "Conexão OK"' &>/dev/null; then
        echo -e "${GREEN}✅ Conectividade com senha OK${NC}"
        return 0
    else
        echo -e "${RED}❌ Erro na conectividade com senha${NC}"
        echo -e "${YELLOW}   Verifique IP, usuário e senha${NC}"
        return 1
    fi
}

# Copiar chave pública para o servidor
copy_public_key() {
    echo -e "${BLUE}📤 Copiando chave pública para o servidor...${NC}"
    
    # Usar ssh-copy-id com sshpass
    if sshpass -p "$PASSWORD" ssh-copy-id -i "${SSH_KEY_PATH}.pub" -o StrictHostKeyChecking=no "$USERNAME@$SERVER_IP" &>/dev/null; then
        echo -e "${GREEN}✅ Chave pública copiada com sucesso${NC}"
        return 0
    else
        echo -e "${RED}❌ Erro ao copiar chave pública${NC}"
        
        # Tentar método alternativo
        echo -e "${YELLOW}🔄 Tentando método alternativo...${NC}"
        local pub_key=$(cat "${SSH_KEY_PATH}.pub")
        
        if sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USERNAME@$SERVER_IP" "mkdir -p ~/.ssh && echo '$pub_key' >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys" &>/dev/null; then
            echo -e "${GREEN}✅ Chave adicionada via método alternativo${NC}"
            return 0
        else
            echo -e "${RED}❌ Falha em ambos os métodos${NC}"
            return 1
        fi
    fi
}

# Testar conectividade com chave
test_key_connection() {
    echo -e "${BLUE}🔑 Testando conectividade com chave SSH...${NC}"
    
    if ssh -o ConnectTimeout=10 -o BatchMode=yes "$SSH_HOST_ALIAS" 'echo "SSH Key OK"' &>/dev/null; then
        echo -e "${GREEN}✅ Conectividade com chave SSH OK${NC}"
        return 0
    else
        echo -e "${RED}❌ Erro na conectividade com chave SSH${NC}"
        return 1
    fi
}

# Verificar configuração existente
check_existing_config() {
    echo -e "${BLUE}🔍 Verificando configuração existente...${NC}"
    
    local all_good=true
    
    # Verificar chave SSH
    if [ -f "$SSH_KEY_PATH" ] && [ -f "${SSH_KEY_PATH}.pub" ]; then
        echo -e "${GREEN}✅ Chave SSH existe${NC}"
        local fingerprint=$(ssh-keygen -lf "${SSH_KEY_PATH}.pub" | cut -d' ' -f2)
        echo -e "${YELLOW}   Fingerprint: $fingerprint${NC}"
    else
        echo -e "${RED}❌ Chave SSH não encontrada${NC}"
        all_good=false
    fi
    
    # Verificar SSH config
    if grep -q "Host $SSH_HOST_ALIAS" "$SSH_CONFIG_PATH" 2>/dev/null; then
        echo -e "${GREEN}✅ SSH config existe${NC}"
        
        # Mostrar configuração
        echo -e "${YELLOW}   Configuração:${NC}"
        grep -A 8 "Host $SSH_HOST_ALIAS" "$SSH_CONFIG_PATH" | sed 's/^/     /'
    else
        echo -e "${RED}❌ SSH config não encontrado${NC}"
        all_good=false
    fi
    
    # Testar conectividade se tudo estiver configurado
    if [ "$all_good" = true ]; then
        if ssh -o ConnectTimeout=5 -o BatchMode=yes "$SSH_HOST_ALIAS" 'echo "Test OK"' &>/dev/null; then
            echo -e "${GREEN}✅ Conectividade SSH OK${NC}"
        else
            echo -e "${RED}❌ Falha na conectividade SSH${NC}"
            all_good=false
        fi
    fi
    
    echo ""
    if [ "$all_good" = true ]; then
        echo -e "${GREEN}🎉 SSH completamente configurado e funcionando!${NC}"
        echo ""
        echo -e "${YELLOW}💡 Comando de teste:${NC}"
        echo -e "   ${BLUE}ssh $SSH_HOST_ALIAS 'echo \"SSH OK\"'${NC}"
    else
        echo -e "${YELLOW}⚠️  SSH precisa ser configurado${NC}"
        echo ""
        echo -e "${YELLOW}💡 Para configurar:${NC}"
        echo -e "   ${BLUE}$0 SERVER_IP USERNAME PASSWORD${NC}"
    fi
    
    return $all_good
}

# Mostrar sumário final
show_summary() {
    echo ""
    echo -e "${GREEN}🎉 Configuração SSH concluída com sucesso!${NC}"
    echo ""
    echo -e "${YELLOW}📋 Resumo:${NC}"
    echo -e "   ${BLUE}Chave SSH:${NC} $SSH_KEY_PATH"
    echo -e "   ${BLUE}Host Alias:${NC} $SSH_HOST_ALIAS"
    echo -e "   ${BLUE}Servidor:${NC} $USERNAME@$SERVER_IP"
    echo ""
    echo -e "${YELLOW}🔧 Comandos úteis:${NC}"
    echo -e "   ${BLUE}Testar SSH:${NC} ssh $SSH_HOST_ALIAS 'echo \"SSH OK\"'"
    echo -e "   ${BLUE}Ver config:${NC} cat ~/.ssh/config | grep -A 8 '$SSH_HOST_ALIAS'"
    echo -e "   ${BLUE}Ver chave:${NC} ssh-keygen -lf ${SSH_KEY_PATH}.pub"
    echo ""
    echo -e "${YELLOW}🚀 Próximos passos:${NC}"
    echo -e "   1. Execute: ${BLUE}./setup.sh${NC}"
    echo -e "   2. Configure: ${BLUE}deploy/.env${NC}"
    echo -e "   3. Deploy: ${BLUE}./deploy/deploy.sh${NC}"
    echo ""
}

# Função principal
main() {
    check_prerequisites
    ensure_ssh_directory
    
    # Se for apenas verificação
    if [ "$CHECK_ONLY" = true ]; then
        check_existing_config
        exit $?
    fi
    
    # Verificar/criar chave SSH
    if ! check_ssh_key; then
        create_ssh_key
    fi
    
    # Configurar SSH config
    setup_ssh_config
    
    # Testar conectividade com senha
    if ! test_password_connection; then
        exit 1
    fi
    
    # Copiar chave pública
    if ! copy_public_key; then
        exit 1
    fi
    
    # Testar conectividade com chave
    if ! test_key_connection; then
        echo -e "${RED}❌ Configuração SSH falhou${NC}"
        exit 1
    fi
    
    # Mostrar sumário
    show_summary
}

# Executar função principal
main