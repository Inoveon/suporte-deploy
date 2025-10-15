# 🌱 Script de Seed do Banco de Dados

Este documento descreve o script de população inicial do banco de dados com dados reais da estrutura organizacional.

## 📍 Localização

```bash
scripts/database/seed_database.py
```

## 🎯 Objetivo

Popular o banco de dados com dados iniciais necessários para o funcionamento do sistema, incluindo:
- Estrutura organizacional real (cargos e departamentos)
- Usuários da equipe com perfis completos
- Dados reais do Grupo Aldo (cliente principal)
- Configurações de SLA e permissões

## 🏢 Dados Organizacionais

### Estrutura da Empresa (Inoveon)

#### Departamentos
- **Diretoria** - Direção geral da empresa
- **Suporte** - Equipe de suporte técnico aos clientes
- **Desenvolvimento** - Equipe de desenvolvimento de software
- **Comercial** - Equipe comercial e vendas
- **Administrativo** - Equipe administrativa e financeira
- **Design** - Equipe de design e UX/UI

#### Cargos
- **Diretor** - Diretor da empresa
- **Coordenador de Suporte** - Coordenador da equipe de suporte
- **Analista de Suporte** - Analista de suporte técnico
- **Desenvolvedor Sênior** - Desenvolvedor sênior
- **Desenvolvedor** - Desenvolvedor de software
- **Vendedor** - Vendedor e atendimento comercial
- **Administrativo** - Auxiliar administrativo
- **Designer** - Designer UX/UI
- **Analista de Suporte Jr** - Analista de suporte júnior

## 👥 Usuários da Equipe

### Diretoria
- **Lee Chardes** - lee@inoveon.com.br
- **Diego Santos** - diego@inoveon.com.br
- **Rodrigo Silva** - rodrigo@inoveon.com.br

### Coordenação
- **Gláucia Coordenadora** - glaucia@inoveon.com.br

### Desenvolvimento
- **Moral Developer** - moral@inoveon.com.br

### Suporte
- **Mariana Analista** - mariana@inoveon.com.br
- **Giseline Analista** - giseline@inoveon.com.br

### Administrativo
- **Andréa Administrativa** - andrea@inoveon.com.br

### Design
- **Débora Designer** - debora@inoveon.com.br

## 🏪 Cliente Principal - Grupo Aldo

### Informações Gerais
- **Nome**: Grupo Aldo
- **Segmento**: Postos de Combustível
- **CNPJ**: 00000000000000
- **Email**: contato@grupoaldo.com.br
- **Matriz**: Cuiabá/MT

### Filiais Principais
1. **ASFRETE** (808001) - Cuiabá/MT
2. **POSTO ALDO SÃO JOSÉ DOS PINHAIS LTDA** (060601) - São José dos Pinhais/PR
3. **POSTO ALDO CUIABÁ** (191902) - Cuiabá/MT
4. **POSTO ALDO MARINGÁ LTDA** (181801) - Maringá/PR
5. **POSTO ALDO BARREIRAS LTDA** (191901) - Barreiras/BA
6. **POSTO ALDO SORRISO LTDA** (151501) - Sorriso/MT
7. **POSTOS ALDO LTDA** (300100) - Cuiabá/MT (Matriz)

### Sistemas do Grupo Aldo
1. **PDV Protheus** - Sistema PDV baseado no Protheus (TOTVS Protheus, AdvPL)
2. **I9 Smart PDV** - Sistema de PDV inteligente (Flutter, Python, PostgreSQL)
3. **Posto Frota** - Sistema de gestão de frota (Python, React)
4. **Retaguarda** - Sistema de retaguarda administrativo (TOTVS Protheus, AdvPL)
5. **I9 Smart Feed** - Sistema de alimentação de dados (Python, FastAPI)
6. **I9 Smart Count** - Sistema de contagem inteligente (Python, React)
7. **Faturamento ASFRETE** - Sistema de faturamento (TOTVS Protheus, AdvPL)

## 🔧 Como Executar

### Pré-requisitos
1. PostgreSQL rodando (via Docker)
2. Ambiente virtual Python ativo
3. Banco de dados criado

### Comandos

```bash
# Subir infraestrutura
make docker-up

# Executar migrations
make migrate

# Popular banco com dados iniciais
.venv/bin/python scripts/database/seed_database.py
```

### Ou usando o Makefile
```bash
make seed
```

## 🔑 Credenciais de Acesso

### Diretoria (Nível 3)
- lee@inoveon.com.br / admin123
- diego@inoveon.com.br / admin123
- rodrigo@inoveon.com.br / admin123

### Coordenação (Nível 2)
- glaucia@inoveon.com.br / coord123

### Desenvolvimento (Nível 1)
- moral@inoveon.com.br / dev123

### Suporte (Nível 1)
- mariana@inoveon.com.br / suporte123
- giseline@inoveon.com.br / suporte123

### Administrativo (Nível 1)
- andrea@inoveon.com.br / admin123

### Design (Nível 1)
- debora@inoveon.com.br / design123

## 📊 Estrutura Criada

### 1. Cargos e Departamentos
- 6 departamentos organizacionais
- 9 cargos específicos
- Relacionamentos entre cargos e departamentos

### 2. Usuários e Perfis
- 9 usuários da equipe
- Perfis completos com cargos e departamentos
- Níveis de acesso hierárquicos

### 3. Equipes
- Equipe de Suporte (líder: Gláucia)
- Equipe de Desenvolvimento (líder: Lee)

### 4. Configurações SLA
- Bug Crítico: 4h (escalação em 2h)
- Bug Alto: 24h (escalação em 8h)
- Feature Alta: 7 dias (escalação em 24h)
- Suporte Médio: 48h (escalação em 12h)

### 5. Permissões Básicas
- Visualização de chamados
- Criação de chamados
- Atribuição de chamados
- Gerenciamento de usuários
- Relatórios executivos

## ⚠️ Comportamento do Script

### Verificações de Segurança
O script verifica se os dados já existem antes de criar:
- Se usuários já existem → não cria novos
- Se equipes já existem → não cria novas
- Se cliente já existe → não cria novo
- Se configurações já existem → não sobrescreve

### Execução Idempotente
O script pode ser executado múltiplas vezes sem problemas:
- Detecta dados existentes
- Exibe mensagens informativas
- Não duplica registros

## 🔍 Verificação Pós-Execução

Após executar o script, você pode verificar:

```bash
# Verificar usuários criados
.venv/bin/python -c "
from app.core.database import AsyncSessionLocal
from app.models import Usuario
import asyncio

async def check():
    async with AsyncSessionLocal() as db:
        from sqlalchemy import select
        result = await db.execute(select(Usuario))
        users = result.scalars().all()
        for u in users:
            print(f'{u.nome_completo} - {u.email}')

asyncio.run(check())
"
```

## 📝 Logs de Execução

O script gera logs detalhados:
```
🌱 Iniciando população do banco de dados...
💼 Criando cargos e departamentos...
✅ 6 departamentos e 9 cargos criados
👥 Criando usuários iniciais...
✅ 9 usuários criados com cargos e departamentos
🏢 Criando equipes iniciais...
✅ Equipes criadas
⏱️ Criando configurações SLA padrão...
✅ 4 configurações SLA criadas
🏪 Criando dados do Grupo Aldo...
✅ Grupo Aldo criado com 7 filiais e 7 sistemas
🏪 Resumo atual: clientes=1, filiais=7, sistemas=7
🔐 Criando permissões básicas...
✅ 5 permissões criadas

🎉 Banco de dados populado com sucesso!
```

## 🚀 Próximos Passos

Após executar o seed:
1. Testar login com as credenciais fornecidas
2. Verificar hierarquia de permissões
3. Criar chamados de teste
4. Validar fluxos de atribuição
5. Testar relatórios e métricas

---

*Script atualizado com dados reais do Grupo Aldo - Versão 2.0*
*Documentação criada em: Janeiro 2025*