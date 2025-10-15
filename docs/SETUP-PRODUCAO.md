# 🚀 Guia de Setup para Produção

Este documento descreve o processo completo para configurar o sistema de suporte em um ambiente de produção com banco de dados zerado.

## ✅ Validação Completa Realizada

O processo foi testado em 8 de outubro de 2025, simulando um cenário de produção completo:

1. **Banco zerado** - Todas as tabelas removidas
2. **Migrations aplicadas** - 27 tabelas criadas via Alembic
3. **Dados iniciais carregados** - Script de seed executado com sucesso
4. **Integridade validada** - Todos os relacionamentos funcionando

## 🏗️ Processo de Setup

### 1. Preparação do Ambiente

```bash
# 1. Clonar repositório
git clone [url-do-repositorio]
cd suporte_chamados_api_fastapi

# 2. Criar ambiente virtual
python -m venv .venv
source .venv/bin/activate  # Linux/Mac
# ou .venv\Scripts\activate  # Windows

# 3. Instalar dependências
pip install -r requirements.txt
```

### 2. Configuração do Banco de Dados

```bash
# 1. Criar banco PostgreSQL
createdb -h localhost -U postgres suporte_chamados

# 2. Criar usuário específico
psql -h localhost -U postgres -c "
CREATE USER suporte_user WITH PASSWORD 'suporte_pass';
GRANT ALL PRIVILEGES ON DATABASE suporte_chamados TO suporte_user;
"
```

### 3. Configuração das Variáveis de Ambiente

Criar arquivo `.env` na raiz do projeto:

```env
# Database
DATABASE_URL=postgresql://suporte_user:suporte_pass@localhost:5432/suporte_chamados
DATABASE_URL_ASYNC=postgresql+asyncpg://suporte_user:suporte_pass@localhost:5432/suporte_chamados

# Security
SECRET_KEY=sua-chave-secreta-super-forte-aqui
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# Environment
ENVIRONMENT=production
DEBUG=false

# CORS (ajustar conforme necessário)
CORS_ORIGINS=["https://seu-dominio.com"]

# Redis (opcional)
REDIS_URL=redis://localhost:6379

# Email (configurar conforme provedor)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=seu-email@dominio.com
SMTP_PASSWORD=sua-senha-app
```

### 4. Aplicar Migrations

```bash
# Verificar status
.venv/bin/alembic current

# Aplicar todas as migrations
.venv/bin/alembic upgrade head

# Verificar se todas as 27 tabelas foram criadas
psql -h localhost -U suporte_user -d suporte_chamados -c "
SELECT COUNT(*) as total_tabelas 
FROM information_schema.tables 
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
"
```

### 5. Carregar Dados Iniciais

```bash
# Executar script de seed
.venv/bin/python scripts/database/seed_database.py
```

### 6. Validação do Setup

```bash
# Verificar contagens finais
PGPASSWORD=suporte_pass psql -h localhost -U suporte_user -d suporte_chamados -c "
SELECT 'USUARIOS' as tipo, COUNT(*) as total FROM usuarios
UNION ALL SELECT 'CARGOS', COUNT(*) FROM cargos
UNION ALL SELECT 'DEPARTAMENTOS', COUNT(*) FROM departamentos  
UNION ALL SELECT 'CLIENTES', COUNT(*) FROM clientes
UNION ALL SELECT 'FILIAIS', COUNT(*) FROM filiais
UNION ALL SELECT 'SISTEMAS', COUNT(*) FROM sistemas
ORDER BY tipo;
"
```

**Resultado esperado:**
```
    tipo     | total 
-------------+-------
 CARGOS      |     9
 CLIENTES    |     1
 DEPARTAMENTOS|     6
 FILIAIS     |     7
 SISTEMAS    |     7
 USUARIOS    |     9
```

## 📊 Dados Carregados

### Estrutura Organizacional
- **6 Departamentos**: Diretoria, Desenvolvimento, Suporte, etc.
- **9 Cargos**: Diretor, Coordenador, Desenvolvedor Senior, etc.
- **9 Usuários**: Equipe completa da Inoveon

### Cliente Principal
- **Grupo Aldo**: Cliente real com dados reais
- **7 Filiais**: Postos em MT, PR e BA
- **7 Sistemas**: PDV, SAT, Faturamento, etc.

### Configurações
- **2 Equipes**: Desenvolvimento e Suporte
- **4 Configurações SLA**: Por tipo e prioridade
- **5 Permissões**: Sistema básico de ACL

## 🔑 Credenciais de Acesso

### Usuários Criados

| Usuário | Email | Senha | Cargo | Departamento |
|---------|-------|-------|-------|--------------|
| Lee Chardes | lee@inoveon.com.br | admin123 | Diretor | Diretoria |
| Diego Pagio | diego@inoveon.com.br | admin123 | Diretor | Diretoria |
| Rodrigo Lemes | rodrigo@inoveon.com.br | admin123 | Diretor | Diretoria |
| Glaucia Donin | glaucia@inoveon.com.br | coord123 | Coordenador | Coordenação |
| Robison Moral | moral@inoveon.com.br | dev123 | Desenvolvedor Senior | Desenvolvimento |
| Mariana Grandi | mariana@inoveon.com.br | suporte123 | Analista Suporte | Suporte |
| Giseline Almeida | giseline@inoveon.com.br | suporte123 | Técnico Suporte | Suporte |
| Andrea Alves | andrea@inoveon.com.br | admin123 | Auxiliar Administrativo | Administrativo |
| Debora Wenglarek | debora@inoveon.com.br | design123 | Designer | Design |

## 🔧 Comandos Úteis

### Verificar Status
```bash
# Status das migrations
.venv/bin/alembic current

# Histórico de migrations
.venv/bin/alembic history

# Verificar conexão
.venv/bin/python -c "
from app.core.database import check_db_connection
import asyncio
print('Conexão:', asyncio.run(check_db_connection()))
"
```

### Backup e Restore
```bash
# Backup completo
pg_dump -h localhost -U suporte_user suporte_chamados > backup_$(date +%Y%m%d).sql

# Restore
psql -h localhost -U suporte_user suporte_chamados < backup_20251008.sql
```

### Iniciar Aplicação
```bash
# Desenvolvimento
.venv/bin/uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Produção
.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
```

## ⚠️ Pontos de Atenção

### 1. Constraint de Tipo de Contrato
O campo `tipo_contrato` na tabela `clientes` aceita apenas:
- `"desenvolvimento"`
- `"suporte"` 
- `"ambos"`

**ERRO CORRIGIDO**: O script de seed estava usando `"desenvolvimento_suporte"` que violava a constraint.

### 2. Versão do Alembic
Após aplicar migrations, verificar se a versão atual é `6f1018822215`. Se necessário:

```sql
UPDATE alembic_version SET version_num = '6f1018822215';
```

### 3. Extensões PostgreSQL
As migrations criam automaticamente as extensões necessárias:
- `uuid-ossp` - Para geração de UUIDs
- `pg_trgm` - Para busca textual avançada

### 4. Triggers de Timestamp
Triggers automáticos para `atualizado_em` são criados para todas as tabelas principais.

## 🧪 Testes de Integridade

Executar após o setup para validar:

```sql
-- Verificar integridade referencial
SELECT 'INTEGRIDADE REFERENCIAL' as teste, 'PASSOU' as resultado 
WHERE NOT EXISTS (
    SELECT 1 FROM perfis_usuario p 
    LEFT JOIN usuarios u ON p.usuario_id = u.id 
    LEFT JOIN cargos c ON p.cargo_id = c.id 
    LEFT JOIN departamentos d ON p.departamento_id = d.id 
    WHERE u.id IS NULL OR c.id IS NULL OR d.id IS NULL
);

-- Verificar foreign keys
SELECT 'FOREIGN KEYS VALIDAS' as teste, 'PASSOU' as resultado 
WHERE NOT EXISTS (
    SELECT 1 FROM filiais f 
    LEFT JOIN clientes c ON f.cliente_id = c.id 
    WHERE c.id IS NULL
);

-- Verificar sistemas linkados
SELECT 'SISTEMAS LINKADOS' as teste, 'PASSOU' as resultado 
WHERE NOT EXISTS (
    SELECT 1 FROM sistemas s 
    LEFT JOIN clientes c ON s.cliente_id = c.id 
    WHERE c.id IS NULL
);
```

**Resultado esperado**: Todos os testes devem retornar "PASSOU".

## 📈 Próximos Passos

1. **Configurar SSL/TLS** para produção
2. **Setup de monitoramento** (logs, métricas)
3. **Backup automatizado** diário
4. **Configurar CI/CD** para deploys
5. **Teste de carga** da API
6. **Documentação de APIs** no Swagger

## 📞 Suporte

Em caso de problemas durante o setup:

1. Verificar logs da aplicação
2. Consultar documentação específica em `/docs`
3. Validar variáveis de ambiente
4. Verificar conectividade com banco de dados

---

**Validado em**: 8 de outubro de 2025  
**Versão**: v1.0  
**Status**: ✅ Funcionando perfeitamente em ambiente de produção simulado