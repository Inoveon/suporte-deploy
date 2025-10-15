# 🚀 Suporte Deploy - Inoveon

Sistema de deploy automatizado para o projeto de gestão de chamados usando **Traefik v3.1** como proxy reverso.

## 🎯 Visão Geral

Este repositório contém **apenas as configurações e scripts de deploy**. Os projetos reais são clonados separadamente usando o script `clone-projects.sh`.

### Arquitetura
- **API Backend**: FastAPI → `https://office.inoveon.com.br/api/suporte/`
- **Dashboard Web**: React → `https://office.inoveon.com.br/portal/suporte/`
- **Proxy Reverso**: Traefik v3.1 com SSL automático
- **Servidor**: 10.0.20.11

## 🚀 Quick Start (Makefile)

O projeto inclui um **Makefile completo** com todos os comandos necessários:

### **Setup Completo (Primeira Vez)**
```bash
# Clone das configurações
git clone https://github.com/inoveon/suporte-deploy.git suporte
cd suporte

# Setup automático completo
make first-time

# OU passo a passo:
make install                    # Instalar dependências
make ssh PASSWORD=senha123      # Configurar SSH
make clone                      # Clonar projetos
make setup                      # Setup inicial
# Editar arquivos .env
make deploy                     # Deploy completo
```

### **Uso Diário**
```bash
make status                     # Verificar tudo
make health                     # Health check completo
make logs-follow SERVICE=api    # Logs em tempo real
make update                     # Atualizar e redeploy
```

### **Comandos Principais**
```bash
make help                       # Lista todos os comandos
make deploy                     # Deploy completo
make deploy-api                 # Deploy apenas API
make deploy-web                 # Deploy apenas Portal
make backup                     # Backup completo
make urls                       # Mostrar URLs do sistema
```

## 📁 Estrutura

```
suporte/
├── 📋 Makefile                    # Interface simplificada (40+ comandos)
├── 📚 CLAUDE.md                   # Documentação para Claude Code
├── 📖 README.md                   # Este arquivo
├── 🏗️ deploy/                     # Deploy geral e orquestração
│   ├── deploy.sh                 # Script principal de deploy
│   └── docker-compose.prod.yml   # Configuração Docker/Traefik
├── 🔧 api/deploy/                 # Deploy específico da API
│   ├── deploy.sh                 # Deploy individual da API
│   └── Dockerfile.prod           # Build otimizado para produção
├── 🌐 web/deploy/                 # Deploy específico do Portal
│   ├── deploy.sh                 # Deploy individual do Portal
│   └── Dockerfile.prod           # Build com Nginx otimizado
├── 📱 mobile/deploy/              # Deploy específico do Mobile
├── 🛠️ scripts/                    # Scripts utilitários
│   ├── install-dependencies.sh  # Instalação de dependências
│   ├── setup-ssh.sh             # Configuração automática SSH
│   ├── health-check.sh          # Health check completo
│   ├── backup.sh                # Sistema de backup
│   ├── logs.sh                  # Visualização de logs
│   └── update-all.sh            # Atualização automática
├── 📊 docs/                       # Documentação técnica
│   └── DEPLOY-ARCHITECTURE.md    # Arquitetura detalhada
├── 🔗 clone-projects.sh           # Clone automático dos projetos
├── ⚙️ setup.sh                    # Configuração inicial
└── 📋 projects.json               # Configuração dos projetos
```

## 🔗 Projetos Relacionados

- **API**: [suporte_chamados_api_fastapi](https://github.com/inoveon/suporte_chamados_api_fastapi)
- **Web**: [suporte_dashboard_web_react](https://github.com/inoveon/suporte_dashboard_web_react)
- **Mobile**: [suporte_tecnico_mobile_flutter](https://github.com/inoveon/suporte_tecnico_mobile_flutter)

## 📚 Documentação

- **[Arquitetura de Deploy](docs/DEPLOY-ARCHITECTURE.md)** - Guia completo da arquitetura
- **[Guia de Setup](docs/SETUP-GUIDE.md)** - Configuração passo a passo
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Solução de problemas

## 🛠️ Comandos Disponíveis (Makefile)

### **📦 Instalação e Setup**
```bash
make install          # Instalar todas as dependências
make ssh PASSWORD=senha  # Configurar chaves SSH
make ssh-check        # Verificar configuração SSH
make setup            # Configuração inicial do ambiente
make clone            # Clonar todos os projetos
make first-time       # Setup completo primeira vez
```

### **🚀 Deploy**
```bash
make deploy           # Deploy completo de todos os serviços
make deploy-api       # Deploy apenas da API
make deploy-web       # Deploy apenas do Portal Web
make deploy-infra     # Deploy apenas da infraestrutura
make deploy-force     # Deploy com rebuild forçado
```

### **📊 Monitoramento e Logs**
```bash
make status           # Verificar status de todos os serviços
make health           # Health check completo do sistema
make logs SERVICE=api # Ver logs específicos
make logs-follow SERVICE=api  # Seguir logs em tempo real
make logs-api         # Ver logs da API (shortcut)
make logs-web         # Ver logs do Portal (shortcut)
make logs-db          # Ver logs do Banco (shortcut)
```

### **💾 Backup e Manutenção**
```bash
make backup           # Backup completo do sistema
make backup-db        # Backup apenas do banco de dados
make backup-list      # Listar backups existentes
make backup-clean     # Limpar backups antigos
```

### **🔄 Atualização**
```bash
make update           # Atualizar todos os projetos e redeploy
make update-api       # Atualizar apenas API
make update-web       # Atualizar apenas Portal
make update-force     # Atualização forçada
```

### **🛠️ Utilitários**
```bash
make restart          # Reiniciar todos os serviços
make stop             # Parar todos os serviços
make clean            # Limpeza completa (containers, imagens, volumes)
make test             # Executar todos os testes de validação
make config-show      # Mostrar configurações atuais
make urls             # Mostrar URLs importantes
make help             # Mostrar todos os comandos disponíveis
make help-full        # Ajuda completa com exemplos
```

### **🎯 Aliases e Shortcuts**
```bash
make up               # Alias para deploy
make down             # Alias para stop
make ps               # Alias para status
```

## ⚙️ Configuração

### **Fluxo Completo de Setup (Recomendado)**
```bash
# 1. Clone e instalação
git clone https://github.com/inoveon/suporte-deploy.git suporte
cd suporte
make install

# 2. Configurar SSH
make ssh PASSWORD=suasenha123

# 3. Clone dos projetos e setup
make clone
make setup

# 4. Configurar variáveis de ambiente
# Editar: deploy/.env, api/deploy/.env, web/deploy/.env

# 5. Deploy
make deploy
```

### **Variáveis de Ambiente**
O setup criará templates automaticamente:
- `deploy/.env` - Configurações gerais
- `api/deploy/.env` - Configurações específicas da API  
- `web/deploy/.env` - Configurações específicas do Portal

### **SSH Automático**
```bash
make ssh PASSWORD=senha         # Configurar chaves SSH
make ssh-check                  # Verificar configuração
ssh i9-deploy 'echo "SSH OK"'   # Testar conexão
```

### **Configurações do Servidor**
- **IP**: 10.0.20.11
- **Usuário**: lee (configurável via USERNAME)
- **Alias SSH**: i9-deploy
- **Chave SSH**: ~/.ssh/id_rsa_i9_deploy

## 🌐 URLs de Produção

- **API Docs**: https://office.inoveon.com.br/api/suporte/docs
- **Dashboard**: https://office.inoveon.com.br/portal/suporte/
- **Health Check**: https://office.inoveon.com.br/api/suporte/health

## 🔐 Segurança

- ✅ SSL automático via Let's Encrypt
- ✅ HTTPS redirect automático
- ✅ Headers de segurança configurados
- ✅ CORS configurado adequadamente

## 🤝 Contribuição

1. Fork este repositório
2. Crie uma branch para sua feature
3. Teste localmente
4. Abra um Pull Request

## 📞 Suporte

- **Issues**: [GitHub Issues](https://github.com/inoveon/suporte-deploy/issues)
- **Documentação**: [docs/](docs/)
- **Equipe**: DevOps Inoveon

---

## 💡 Dicas e Exemplos

### **Uso Diário Típico**
```bash
make status              # Verificar se tudo está OK
make health              # Health check completo
make logs-follow SERVICE=api  # Ver logs em tempo real
make update              # Atualizar código e redeploy
```

### **Troubleshooting**
```bash
make config-show         # Ver configurações atuais
make ssh-check           # Verificar SSH
make test                # Executar todos os testes
make logs SERVICE=api    # Ver logs para debugging
```

### **Manutenção**
```bash
make backup              # Backup antes de mudanças
make backup-clean        # Limpar backups antigos
make restart             # Reiniciar serviços
make clean               # Limpeza completa (cuidado!)
```

---

**Mantido pela equipe DevOps da Inoveon**  
**Versão**: 2.0 (com Makefile)  
**Última atualização**: Janeiro 2025