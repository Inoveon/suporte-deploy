# 🚀 Suporte Deploy - Inoveon

Sistema de deploy automatizado para o projeto de gestão de chamados usando **Traefik v3.1** como proxy reverso.

## 🎯 Visão Geral

Este repositório contém **apenas as configurações e scripts de deploy**. Os projetos reais são clonados separadamente usando o script `clone-projects.sh`.

### Arquitetura
- **API Backend**: FastAPI → `https://office.inoveon.com.br/api/suporte/`
- **Dashboard Web**: React → `https://office.inoveon.com.br/portal/suporte/`
- **Proxy Reverso**: Traefik v3.1 com SSL automático
- **Servidor**: 10.0.20.11

## 🚀 Quick Start

### 1. Clone e Setup
```bash
# Clone das configurações
git clone https://github.com/inoveon/suporte-deploy.git suporte
cd suporte

# Instalar dependências (primeira vez)
./scripts/install-dependencies.sh

# Configurar SSH (primeira vez)
./scripts/setup-ssh.sh 10.0.20.11 username password

# Clone dos projetos
./clone-projects.sh

# Configuração inicial
./setup.sh
```

### 2. Deploy
```bash
# Deploy completo
./deploy/deploy.sh

# Deploy individual
./api/deploy/deploy.sh
./web/deploy/deploy.sh
```

### 3. Monitoramento
```bash
# Logs em tempo real
./scripts/logs.sh

# Health check
./scripts/health-check.sh
```

## 📁 Estrutura

```
suporte/
├── docs/                         # Documentação
│   └── DEPLOY-ARCHITECTURE.md    # Arquitetura detalhada
├── deploy/                       # Deploy geral
│   ├── deploy.sh
│   └── docker-compose.prod.yml
├── api/deploy/                   # Deploy API
├── web/deploy/                   # Deploy Portal
├── scripts/                     # Utilitários
├── clone-projects.sh            # Clone dos projetos
└── setup.sh                    # Setup inicial
```

## 🔗 Projetos Relacionados

- **API**: [suporte_chamados_api_fastapi](https://github.com/inoveon/suporte_chamados_api_fastapi)
- **Web**: [suporte_dashboard_web_react](https://github.com/inoveon/suporte_dashboard_web_react)
- **Mobile**: [suporte_tecnico_mobile_flutter](https://github.com/inoveon/suporte_tecnico_mobile_flutter)

## 📚 Documentação

- **[Arquitetura de Deploy](docs/DEPLOY-ARCHITECTURE.md)** - Guia completo da arquitetura
- **[Guia de Setup](docs/SETUP-GUIDE.md)** - Configuração passo a passo
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Solução de problemas

## 🛠️ Comandos Úteis

### Deploy e Monitoramento
```bash
# Atualizar todos os projetos
./scripts/update-all.sh

# Backup completo
./scripts/backup.sh

# Ver logs em tempo real
./scripts/logs.sh api -f

# Health check completo
./scripts/health-check.sh

# Ver logs do Traefik
docker logs traefik -f
```

### SSH e Conectividade
```bash
# Configurar SSH pela primeira vez
./scripts/setup-ssh.sh 10.0.20.11 lee mypassword

# Verificar configuração SSH
./scripts/setup-ssh.sh --check-only

# Forçar nova chave SSH
./scripts/setup-ssh.sh 10.0.20.11 lee mypassword --force-new

# Testar conexão
ssh i9-deploy 'echo "SSH OK"'
```

## ⚙️ Configuração

### Variáveis de Ambiente
Copie os templates e configure:
```bash
cp deploy/.env.template deploy/.env
cp api/deploy/.env.template api/deploy/.env
cp web/deploy/.env.template web/deploy/.env
```

### SSH
Configure a chave SSH automaticamente:
```bash
# Configuração automática (primeira vez)
./scripts/setup-ssh.sh 10.0.20.11 username password

# Verificar configuração existente
./scripts/setup-ssh.sh --check-only

# Testar conexão
ssh i9-deploy 'echo "SSH OK"'
```

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

**Mantido pela equipe DevOps da Inoveon**  
**Versão**: 1.0  
**Última atualização**: Janeiro 2025