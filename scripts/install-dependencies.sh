#!/bin/bash

# 📦 Install Dependencies Script - Instalação de Dependências
# Instala todas as dependências necessárias para o sistema de deploy

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📦 Instalando dependências do sistema de deploy...${NC}"

# Detectar sistema operacional
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            echo "debian"
        elif [ -f /etc/redhat-release ]; then
            echo "rhel"
        else
            echo "linux"
        fi
    else
        echo "unknown"
    fi
}

OS=$(detect_os)
echo -e "${YELLOW}Sistema operacional detectado: $OS${NC}"

# Função para instalar no macOS
install_macos() {
    echo -e "${BLUE}🍎 Instalando dependências no macOS...${NC}"
    
    # Verificar se Homebrew está instalado
    if ! command -v brew &> /dev/null; then
        echo -e "${YELLOW}⚠️  Homebrew não encontrado. Instalando...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # Lista de dependências
    local deps=(
        "sshpass"           # Para automação SSH
        "jq"                # Para parsing JSON
        "rsync"             # Para sincronização de arquivos
        "curl"              # Para health checks
        "git"               # Para clone dos projetos
        "docker"            # Para containers
    )
    
    echo -e "${YELLOW}📋 Instalando: ${deps[*]}${NC}"
    
    for dep in "${deps[@]}"; do
        if brew list "$dep" &>/dev/null; then
            echo -e "${GREEN}✅ $dep já instalado${NC}"
        else
            echo -e "${YELLOW}📦 Instalando $dep...${NC}"
            brew install "$dep"
        fi
    done
    
    # Docker Desktop específico para macOS
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}🐳 Docker não encontrado. Instale Docker Desktop:${NC}"
        echo -e "${BLUE}   https://docs.docker.com/desktop/mac/install/${NC}"
    fi
}

# Função para instalar no Ubuntu/Debian
install_debian() {
    echo -e "${BLUE}🐧 Instalando dependências no Ubuntu/Debian...${NC}"
    
    # Atualizar repositórios
    echo -e "${YELLOW}🔄 Atualizando repositórios...${NC}"
    sudo apt-get update
    
    # Lista de dependências
    local deps=(
        "sshpass"           # Para automação SSH
        "jq"                # Para parsing JSON
        "rsync"             # Para sincronização de arquivos
        "curl"              # Para health checks
        "git"               # Para clone dos projetos
        "docker.io"         # Docker
        "docker-compose"    # Docker Compose
        "bc"                # Para cálculos nos scripts
        "openssl"           # Para SSL checks
    )
    
    echo -e "${YELLOW}📋 Instalando: ${deps[*]}${NC}"
    sudo apt-get install -y "${deps[@]}"
    
    # Configurar Docker
    echo -e "${YELLOW}🐳 Configurando Docker...${NC}"
    sudo systemctl enable docker
    sudo systemctl start docker
    
    # Adicionar usuário ao grupo docker
    sudo usermod -aG docker "$USER"
    echo -e "${YELLOW}⚠️  Faça logout/login para aplicar permissões do Docker${NC}"
}

# Função para instalar no RHEL/CentOS/Fedora
install_rhel() {
    echo -e "${BLUE}🎩 Instalando dependências no RHEL/CentOS/Fedora...${NC}"
    
    # Detectar gerenciador de pacotes
    if command -v dnf &> /dev/null; then
        local pkg_manager="dnf"
    elif command -v yum &> /dev/null; then
        local pkg_manager="yum"
    else
        echo -e "${RED}❌ Gerenciador de pacotes não encontrado${NC}"
        exit 1
    fi
    
    # Lista de dependências
    local deps=(
        "sshpass"           # Para automação SSH
        "jq"                # Para parsing JSON
        "rsync"             # Para sincronização de arquivos
        "curl"              # Para health checks
        "git"               # Para clone dos projetos
        "docker"            # Docker
        "docker-compose"    # Docker Compose
        "bc"                # Para cálculos nos scripts
        "openssl"           # Para SSL checks
    )
    
    echo -e "${YELLOW}📋 Instalando: ${deps[*]}${NC}"
    sudo $pkg_manager install -y "${deps[@]}"
    
    # Configurar Docker
    echo -e "${YELLOW}🐳 Configurando Docker...${NC}"
    sudo systemctl enable docker
    sudo systemctl start docker
    
    # Adicionar usuário ao grupo docker
    sudo usermod -aG docker "$USER"
    echo -e "${YELLOW}⚠️  Faça logout/login para aplicar permissões do Docker${NC}"
}

# Verificar dependências instaladas
check_dependencies() {
    echo -e "${BLUE}🔍 Verificando dependências instaladas...${NC}"
    
    local deps=(
        "ssh:SSH Client"
        "ssh-keygen:SSH Key Generator"
        "ssh-copy-id:SSH Copy ID"
        "sshpass:SSH Pass"
        "jq:JSON Processor"
        "rsync:File Sync"
        "curl:HTTP Client"
        "git:Version Control"
        "docker:Container Platform"
    )
    
    local missing=()
    
    for dep_info in "${deps[@]}"; do
        IFS=':' read -r cmd desc <<< "$dep_info"
        
        if command -v "$cmd" &> /dev/null; then
            local version=$(
                case $cmd in
                    docker) docker --version | cut -d' ' -f3 | cut -d',' -f1 ;;
                    git) git --version | cut -d' ' -f3 ;;
                    jq) jq --version | tr -d '"' ;;
                    *) echo "✓" ;;
                esac
            )
            echo -e "${GREEN}✅ $desc: $version${NC}"
        else
            echo -e "${RED}❌ $desc: Não encontrado${NC}"
            missing+=("$cmd")
        fi
    done
    
    # Verificar Docker Compose
    if command -v docker &> /dev/null; then
        if docker compose version &> /dev/null; then
            local compose_version=$(docker compose version | cut -d' ' -f4)
            echo -e "${GREEN}✅ Docker Compose: $compose_version${NC}"
        else
            echo -e "${RED}❌ Docker Compose: Não encontrado${NC}"
            missing+=("docker-compose")
        fi
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo ""
        echo -e "${RED}❌ Dependências em falta: ${missing[*]}${NC}"
        return 1
    else
        echo ""
        echo -e "${GREEN}🎉 Todas as dependências estão instaladas!${NC}"
        return 0
    fi
}

# Mostrar ajuda pós-instalação
show_post_install_help() {
    echo ""
    echo -e "${YELLOW}🚀 Próximos passos:${NC}"
    echo ""
    echo -e "${BLUE}1. Configurar SSH:${NC}"
    echo -e "   ./scripts/setup-ssh.sh 10.0.20.11 username password"
    echo ""
    echo -e "${BLUE}2. Setup do projeto:${NC}"
    echo -e "   ./setup.sh"
    echo ""
    echo -e "${BLUE}3. Clone dos projetos:${NC}"
    echo -e "   ./clone-projects.sh"
    echo ""
    echo -e "${BLUE}4. Deploy:${NC}"
    echo -e "   ./deploy/deploy.sh"
    echo ""
    echo -e "${YELLOW}💡 Documentação completa:${NC}"
    echo -e "   docs/DEPLOY-ARCHITECTURE.md"
    echo ""
}

# Função principal
main() {
    echo -e "${YELLOW}Sistema: $OS${NC}"
    echo ""
    
    case $OS in
        macos)
            install_macos
            ;;
        debian)
            install_debian
            ;;
        rhel)
            install_rhel
            ;;
        *)
            echo -e "${RED}❌ Sistema operacional não suportado: $OS${NC}"
            echo -e "${YELLOW}Instale manualmente: sshpass, jq, rsync, curl, git, docker${NC}"
            exit 1
            ;;
    esac
    
    echo ""
    if check_dependencies; then
        show_post_install_help
    else
        echo -e "${RED}❌ Algumas dependências falharam na instalação${NC}"
        exit 1
    fi
}

# Executar função principal
main