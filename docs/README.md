# 📚 Documentação Global - Sistema de Suporte

Documentação centralizada do sistema de gestão de chamados para desenvolvimento de software e suporte técnico.

## 🚀 NOVO: Deploy Híbrido

**📖 [Comece aqui: Índice Completo de Deploy Híbrido](deploy-hibrido/INDEX-DEPLOY-HIBRIDO.md)**

Implementamos uma **solução híbrida de deploy** que permite:
- ✅ Acesso direto por IP:PORTA (desenvolvimento/debug)
- ✅ Acesso via domínio/path (produção/usuários)
- ✅ SSL automático via Let's Encrypt
- ✅ Múltiplos projetos no mesmo servidor
- ✅ Configuração padronizada e templates prontos

### 📑 Documentação de Deploy Híbrido

| Documento | Quando Usar | Tempo |
|-----------|-------------|-------|
| [**📊 Resumo Executivo**](deploy-hibrido/RESUMO-EXECUTIVO-DEPLOY-HIBRIDO.md) | Entender conceito, apresentar para gestores | 10 min |
| [**📖 Guia Completo**](deploy-hibrido/DEPLOY-HIBRIDO-GUIA-COMPLETO.md) | Entendimento profundo da arquitetura | 40 min |
| [**📋 Guia Passo a Passo**](deploy-hibrido/GUIA-IMPLEMENTACAO-PASSO-A-PASSO.md) | Implementar agora (projeto novo ou existente) | 7-8h |
| [**📝 Templates**](deploy-hibrido/TEMPLATES-CONFIGURACAO.md) | Copy & paste para implementação | N/A |

### 🛠️ Scripts Disponíveis

```bash
# Validar configuração antes do deploy
./scripts/validate-hybrid-deploy.sh

# Testar endpoints após deploy
./scripts/test-endpoints.sh
```

---

## 🎯 Visão Geral do Sistema

Sistema completo para gestão de chamados de desenvolvimento e suporte técnico, atendendo múltiplos clientes com suas respectivas filiais em diversos segmentos de mercado.

## 🏗️ Arquitetura do Sistema

```
Sistema de Suporte
├── API Backend (FastAPI)     # Lógica de negócio e dados
├── Dashboard Web (React)     # Interface de gestão
└── Mobile App (Flutter)      # App para técnicos (futuro)
```

## 📁 Estrutura de Projetos

### 1. API Backend
- **Pasta**: `suporte/api/suporte_chamados_api_fastapi/`
- **Tecnologia**: FastAPI + PostgreSQL + Redis
- **Responsabilidade**: Gerenciamento de dados, lógica de negócio, autenticação

### 2. Dashboard Web
- **Pasta**: `suporte/web/suporte_dashboard_web_react/`
- **Tecnologia**: React + Vite + ShadCN + TypeScript
- **Responsabilidade**: Interface de usuário, visualizações, relatórios

### 3. Mobile App
- **Pasta**: `suporte/mobile/suporte_tecnico_mobile_flutter/`
- **Tecnologia**: Flutter
- **Status**: Planejado para futuro desenvolvimento

## 🎯 Objetivos do Sistema

- Centralizar gestão de chamados de múltiplos clientes
- Otimizar atribuição e acompanhamento de tarefas
- Fornecer métricas e relatórios de produtividade
- Automatizar processos de suporte e desenvolvimento
- Garantir SLA e qualidade de atendimento

## 👥 Usuários do Sistema

- **Desenvolvedores**: Recebem e resolvem chamados
- **Gestores**: Acompanham métricas e performance
- **Clientes**: Solicitam suporte e acompanham status
- **Administradores**: Configuram sistema e usuários

## 📊 Módulos Principais

- **Gestão de Chamados**: CRUD, atribuição, status tracking
- **Gestão de Clientes**: Múltiplos clientes e filiais (Grupo Aldo como cliente principal)
- **Gestão de Desenvolvedores**: Especialidades e carga de trabalho
- **Relatórios**: Dashboards e métricas
- **Configurações**: SLA, notificações, integrações

## 🔗 Integrações Planejadas

- Sistemas de versionamento (Git/GitHub)
- Ferramentas de comunicação (Slack/Teams)
- Sistemas de monitoramento
- APIs de terceiros

## 📚 Documentações Disponíveis

### Deploy e Infraestrutura
- **[📖 Deploy Híbrido - COMECE AQUI](deploy-hibrido/INDEX-DEPLOY-HIBRIDO.md)** - Índice completo de deploy híbrido
- **[Resumo Executivo](deploy-hibrido/RESUMO-EXECUTIVO-DEPLOY-HIBRIDO.md)** - Visão executiva
- **[Guia Completo](deploy-hibrido/DEPLOY-HIBRIDO-GUIA-COMPLETO.md)** - Guia técnico completo
- **[Guia Passo a Passo](deploy-hibrido/GUIA-IMPLEMENTACAO-PASSO-A-PASSO.md)** - Tutorial prático
- **[Templates](deploy-hibrido/TEMPLATES-CONFIGURACAO.md)** - Templates prontos
- **[DEPLOY-ARCHITECTURE.md](DEPLOY-ARCHITECTURE.md)** - Arquitetura Traefik v3.1
- **[PORTAS-ESTRATEGIA.md](PORTAS-ESTRATEGIA.md)** - Estratégia de portas

### Setup e Configuração
- **[SETUP-PRODUCAO.md](SETUP-PRODUCAO.md)** - Guia de setup para produção
- **[SEED-DATABASE.md](SEED-DATABASE.md)** - População inicial do banco com dados reais

### Referências
- **[API-REFERENCE.md](../api/suporte_chamados_api_fastapi/docs/API-REFERENCE.md)** - Documentação completa da API
- **[DEPLOYMENT.md](../api/suporte_chamados_api_fastapi/docs/DEPLOYMENT.md)** - Guia de deploy e infraestrutura

## 🏢 Cliente Principal

### Grupo Aldo
O sistema foi desenvolvido especificamente para atender o **Grupo Aldo**, uma rede de postos de combustível com:
- **36+ filiais** espalhadas pelo Brasil
- **12 sistemas** diferentes (PDV, Retaguarda, I9 Smart, etc.)
- **Múltiplas tecnologias** (Protheus, Flutter, Python, React)
- **Operação 24/7** com necessidade de suporte contínuo

---

## 🚀 Quick Start

### Para Desenvolvedores

```bash
# 1. Ler documentação de deploy
open docs/deploy-hibrido/INDEX-DEPLOY-HIBRIDO.md

# 2. Validar ambiente
./scripts/validate-hybrid-deploy.sh

# 3. Testar endpoints
./scripts/test-endpoints.sh
```

### Para Gestores

1. Leia: [RESUMO-EXECUTIVO-DEPLOY-HIBRIDO.md](deploy-hibrido/RESUMO-EXECUTIVO-DEPLOY-HIBRIDO.md)
2. Entenda os benefícios e custos
3. Aprove a implementação

---

*Documentação global do sistema de suporte - versão 2.1*
*Atualizada com Deploy Híbrido - Janeiro 2025*