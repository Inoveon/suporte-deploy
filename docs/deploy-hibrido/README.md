# 🚀 Documentação de Deploy Híbrido

Esta pasta contém toda a documentação sobre **Deploy Híbrido** - uma solução que permite acesso dual aos serviços (direto via IP:porta + via proxy reverso com domínio/path).

---

## 📖 Por Onde Começar?

### 👔 Se você é Gestor/Líder

**Comece aqui**: [RESUMO-EXECUTIVO-DEPLOY-HIBRIDO.md](RESUMO-EXECUTIVO-DEPLOY-HIBRIDO.md)

**Tempo**: 10 minutos

**O que vai encontrar**:
- O que é deploy híbrido
- Benefícios para o negócio
- Custo vs benefício
- Decisão de implementar ou não

---

### 👨‍💻 Se você é Desenvolvedor

**Comece aqui**: [INDEX-DEPLOY-HIBRIDO.md](INDEX-DEPLOY-HIBRIDO.md)

**Depois siga**: [GUIA-IMPLEMENTACAO-PASSO-A-PASSO.md](GUIA-IMPLEMENTACAO-PASSO-A-PASSO.md)

**Tempo**: 7-8 horas (implementação completa)

**O que vai encontrar**:
- Tutorial passo a passo
- Comandos exatos a executar
- Checkpoints de validação
- Troubleshooting

---

### 🔧 Se você é DevOps

**Comece aqui**: [DEPLOY-HIBRIDO-GUIA-COMPLETO.md](DEPLOY-HIBRIDO-GUIA-COMPLETO.md)

**Tempo**: 40 minutos

**O que vai encontrar**:
- Arquitetura completa
- Conceitos fundamentais
- Configurações detalhadas
- Troubleshooting avançado

---

## 📚 Todos os Documentos

| Documento | Descrição | Para Quem | Tempo |
|-----------|-----------|-----------|-------|
| [**INDEX-DEPLOY-HIBRIDO.md**](INDEX-DEPLOY-HIBRIDO.md) | 📖 **COMECE AQUI** - Índice completo | Todos | 5 min |
| [**RESUMO-EXECUTIVO-DEPLOY-HIBRIDO.md**](RESUMO-EXECUTIVO-DEPLOY-HIBRIDO.md) | Visão executiva, ROI, decisão | Gestores | 10 min |
| [**DEPLOY-HIBRIDO-GUIA-COMPLETO.md**](DEPLOY-HIBRIDO-GUIA-COMPLETO.md) | Guia técnico completo | DevOps, Devs | 40 min |
| [**GUIA-IMPLEMENTACAO-PASSO-A-PASSO.md**](GUIA-IMPLEMENTACAO-PASSO-A-PASSO.md) | Tutorial de implementação | Desenvolvedores | 7-8h |
| [**TEMPLATES-CONFIGURACAO.md**](TEMPLATES-CONFIGURACAO.md) | Templates prontos (copy & paste) | Desenvolvedores | N/A |
| [**PORTAS-ESTRATEGIA.md**](PORTAS-ESTRATEGIA.md) | ⭐ Portas deste projeto (8002, 3002) | Equipe | 10 min |

---

## 🛠️ Scripts Disponíveis

```bash
# Validar configuração antes do deploy
../../scripts/validate-hybrid-deploy.sh

# Testar endpoints após deploy
../../scripts/test-endpoints.sh
```

---

## 🎯 O que é Deploy Híbrido?

Deploy híbrido permite **duas formas de acesso simultâneas**:

### 🔧 Forma 1: Acesso Direto (Desenvolvimento)
```
http://10.0.20.11:8002/api/health
http://10.0.20.11:3002/
```

**Uso**: Debug, testes, desenvolvimento

### 🌐 Forma 2: Acesso via Proxy (Produção)
```
https://office.inoveon.com.br/api/suporte/health
https://office.inoveon.com.br/portal/suporte/
```

**Uso**: Usuários finais, produção, SSL automático

---

## ✅ Benefícios Principais

- ✅ **Flexibilidade**: Debug sem afetar produção
- ✅ **SSL Automático**: Let's Encrypt gratuito
- ✅ **Múltiplos Projetos**: Um domínio para tudo
- ✅ **Build Único**: Mesmo código em dev e prod
- ✅ **Manutenção**: Templates padronizados

---

## 🚀 Quick Start

### Para implementar AGORA:

1. **Leia** (5 min):
   ```bash
   open INDEX-DEPLOY-HIBRIDO.md
   ```

2. **Entenda** (10 min):
   ```bash
   open RESUMO-EXECUTIVO-DEPLOY-HIBRIDO.md
   ```

3. **Implemente** (7-8h):
   ```bash
   open GUIA-IMPLEMENTACAO-PASSO-A-PASSO.md
   ```

4. **Use templates**:
   ```bash
   open TEMPLATES-CONFIGURACAO.md
   ```

---

## 📞 Suporte

### Problemas Comuns

Todos documentados em [DEPLOY-HIBRIDO-GUIA-COMPLETO.md](DEPLOY-HIBRIDO-GUIA-COMPLETO.md#troubleshooting):

- Portal não carrega
- API retorna 404
- CORS Error
- SSL não funciona

### Scripts de Diagnóstico

```bash
# Validar tudo
../../scripts/validate-hybrid-deploy.sh

# Testar conectividade
../../scripts/test-endpoints.sh
```

---

## 📊 Estrutura

```
deploy-hibrido/
├── README.md                            ← Você está aqui
├── INDEX-DEPLOY-HIBRIDO.md             ← Índice completo
├── RESUMO-EXECUTIVO-DEPLOY-HIBRIDO.md ← Para gestores
├── DEPLOY-HIBRIDO-GUIA-COMPLETO.md    ← Guia técnico
├── GUIA-IMPLEMENTACAO-PASSO-A-PASSO.md ← Tutorial prático
├── TEMPLATES-CONFIGURACAO.md           ← Templates prontos
└── PORTAS-ESTRATEGIA.md                ← Portas específicas (8002, 3002)
```

---

## 🎓 Fluxos de Uso

### Gestor/Líder quer apresentar a ideia

```
1. Ler: RESUMO-EXECUTIVO (10 min)
2. Decidir: Aprovar ou não?
3. Alocar: Tempo da equipe (7-8h)
```

### Desenvolvedor vai implementar

```
1. Ler: INDEX + seções relevantes do GUIA-COMPLETO (30 min)
2. Seguir: GUIA-PASSO-A-PASSO (7-8h)
3. Usar: TEMPLATES (copy & paste)
4. Validar: validate-hybrid-deploy.sh
5. Testar: test-endpoints.sh
```

### DevOps fazendo troubleshooting

```
1. Ver: GUIA-COMPLETO - Troubleshooting
2. Executar: validate-hybrid-deploy.sh
3. Executar: test-endpoints.sh
4. Ver logs específicos
```

---

## 💡 Dica

**Não sabe por onde começar?**

```bash
# Abra o índice
open INDEX-DEPLOY-HIBRIDO.md
```

Ele te guia para o documento certo baseado no seu perfil!

---

**Versão**: 1.0
**Data**: Janeiro 2025
**Mantido por**: Equipe DevOps Inoveon
