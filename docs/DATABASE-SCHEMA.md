# 🗄️ Esquema de Banco de Dados - Sistema de Gestão de Chamados

Estrutura de banco de dados PostgreSQL para o sistema de gestão de chamados de desenvolvimento de software.

## 📊 Visão Geral da Arquitetura

Sistema projetado para atender **múltiplos clientes** com suas respectivas **filiais** e **sistemas**, focado em **suporte de desenvolvimento de software**.

### 🎯 Características Principais
- **Multi-tenant**: Isolamento por cliente
- **Auditoria completa**: Histórico de todas as mudanças
- **SLA flexível**: Configuração por cliente/tipo
- **Tracking de tempo**: Controle de horas trabalhadas
- **Escalabilidade**: Estrutura otimizada para crescimento

---

## 🗂️ Entidades Principais

### 👤 **usuarios** (Autenticação Central)
```sql
CREATE TABLE usuarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    senha_hash VARCHAR(255) NOT NULL,
    nome_completo VARCHAR(255) NOT NULL,
    ativo BOOLEAN DEFAULT true,
    tipo_usuario VARCHAR(30) NOT NULL CHECK (tipo_usuario IN ('director', 'support_coordinator', 'senior_developer', 'support_analyst', 'administrative', 'commercial', 'designer')),
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ultimo_login TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Tipos de Usuário (Hierarquia Organizacional):**
- `director`: Diretoria (Lee, Diego, Rodrigo)
- `support_coordinator`: Coordenador de Suporte (Gláucia)
- `senior_developer`: Desenvolvedor Senior (Lee, Diego, Moral)
- `support_analyst`: Analista de Suporte (Mariana, Giseline, Andréa)
- `administrative`: Administrativo (Andréa, Débora)
- `commercial`: Comercial (Rodrigo)
- `designer`: Designer (Débora)

### 🏢 **clientes** (Empresas Contratantes)
```sql
CREATE TABLE clientes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome_empresa VARCHAR(255) NOT NULL,
    cnpj VARCHAR(18) UNIQUE,
    email_contato VARCHAR(255) NOT NULL,
    telefone VARCHAR(20),
    endereco JSONB,
    sla_padrao_horas INTEGER DEFAULT 24,
    ativo BOOLEAN DEFAULT true,
    observacoes TEXT,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Campos JSONB endereco:**
```json
{
  "logradouro": "Rua Example, 123",
  "bairro": "Centro",
  "cidade": "São Paulo",
  "estado": "SP",
  "cep": "01234-567",
  "complemento": "Sala 101"
}
```

### 🏪 **filiais** (Unidades dos Clientes)
```sql
CREATE TABLE filiais (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
    nome VARCHAR(255) NOT NULL,
    codigo VARCHAR(20) NOT NULL, -- ex: "SP001", "RJ002"
    endereco JSONB,
    responsavel_nome VARCHAR(255),
    responsavel_email VARCHAR(255),
    responsavel_telefone VARCHAR(20),
    ativo BOOLEAN DEFAULT true,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(cliente_id, codigo)
);
```

### 💻 **sistemas** (Softwares Desenvolvidos/Mantidos)
```sql
CREATE TABLE sistemas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
    nome VARCHAR(255) NOT NULL,
    descricao TEXT,
    versao_atual VARCHAR(50),
    repositorio_url VARCHAR(500),
    tecnologias JSONB, -- ["React", "Python", "PostgreSQL"]
    status VARCHAR(20) DEFAULT 'desenvolvimento' CHECK (status IN ('desenvolvimento', 'producao', 'manutencao', 'descontinuado')),
    url_producao VARCHAR(500),
    url_homologacao VARCHAR(500),
    observacoes TEXT,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## 🎫 Gestão de Chamados

### 📋 **chamados** (Tabela Principal)
```sql
CREATE TABLE chamados (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    numero SERIAL UNIQUE, -- #001, #002, etc
    titulo VARCHAR(255) NOT NULL,
    descricao TEXT NOT NULL,
    
    -- Relacionamentos
    cliente_id UUID NOT NULL REFERENCES clientes(id),
    filial_id UUID REFERENCES filiais(id),
    sistema_id UUID REFERENCES sistemas(id),
    
    -- Classificação
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('bug', 'feature', 'melhoria', 'suporte', 'integracao')),
    prioridade VARCHAR(20) NOT NULL CHECK (prioridade IN ('baixa', 'media', 'alta', 'critica', 'urgente')),
    status VARCHAR(20) DEFAULT 'aberto' CHECK (status IN ('aberto', 'atribuido', 'em_andamento', 'aguardando_cliente', 'resolvido', 'fechado', 'cancelado')),
    
    -- Atribuição
    criado_por UUID NOT NULL REFERENCES usuarios(id),
    atribuido_para UUID REFERENCES usuarios(id),
    
    -- Controle Hierárquico
    equipe_responsavel_id UUID REFERENCES equipes(id),
    nivel_escalonamento INTEGER DEFAULT 1, -- 1=Suporte, 2=Coordenação, 3=Diretoria
    escalonado_para UUID REFERENCES usuarios(id),
    escalonado_em TIMESTAMP,
    motivo_escalonamento TEXT,
    
    -- Controle de Tempo
    prazo_sla TIMESTAMP,
    tempo_estimado_horas INTEGER,
    tempo_trabalhado_horas DECIMAL(10,2) DEFAULT 0,
    
    -- Resolução
    solucao TEXT,
    teste_solucao TEXT,
    
    -- Timestamps
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolvido_em TIMESTAMP,
    fechado_em TIMESTAMP
);
```

**Status do Chamado:**
- `aberto`: Recém criado, aguardando triagem
- `atribuido`: Designado para um desenvolvedor
- `em_andamento`: Desenvolvedor trabalhando ativamente
- `aguardando_cliente`: Aguardando resposta/validação do cliente
- `resolvido`: Solução implementada, aguardando aprovação
- `fechado`: Aprovado e finalizado pelo cliente
- `cancelado`: Cancelado por qualquer motivo

### 📝 **chamados_historico** (Auditoria Completa)
```sql
CREATE TABLE chamados_historico (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chamado_id UUID NOT NULL REFERENCES chamados(id) ON DELETE CASCADE,
    usuario_id UUID NOT NULL REFERENCES usuarios(id),
    acao VARCHAR(50) NOT NULL CHECK (acao IN ('criado', 'atribuido', 'status_alterado', 'comentario', 'anexo', 'tempo_lancado')),
    campo_alterado VARCHAR(100),
    valor_anterior TEXT,
    valor_novo TEXT,
    comentario TEXT,
    dados_extras JSONB, -- Para informações adicionais específicas da ação
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## 👥 Gestão de Equipe e Hierarquia

### 👤 **perfis_usuario** (Detalhamento dos Perfis)
```sql
CREATE TABLE perfis_usuario (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE UNIQUE,
    cargo VARCHAR(100) NOT NULL, -- "Diretor Técnico", "Coordenadora de Suporte"
    departamento VARCHAR(50), -- "Diretoria", "Suporte", "Desenvolvimento"
    nivel_acesso INTEGER DEFAULT 1, -- 1=Operacional, 2=Coordenação, 3=Diretoria
    clientes_atribuidos JSONB, -- IDs dos clientes que pode acessar (null = todos)
    especialidades JSONB, -- ["Suporte Técnico", "Gestão de Equipe"]
    telefone VARCHAR(20),
    observacoes TEXT,
    ativo BOOLEAN DEFAULT true,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 🏢 **equipes** (Organização por Equipes)
```sql
CREATE TABLE equipes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome VARCHAR(100) NOT NULL, -- "Suporte Nível 1", "Desenvolvimento Backend"
    descricao TEXT,
    lider_id UUID REFERENCES usuarios(id), -- Gláucia lidera "Suporte"
    departamento VARCHAR(50), -- "Suporte", "Desenvolvimento", "Comercial"
    ativo BOOLEAN DEFAULT true,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 👥 **equipes_membros** (Relacionamento Usuário-Equipe)
```sql
CREATE TABLE equipes_membros (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    equipe_id UUID NOT NULL REFERENCES equipes(id) ON DELETE CASCADE,
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    papel VARCHAR(50) DEFAULT 'membro', -- 'lider', 'membro', 'substituto'
    data_entrada DATE DEFAULT CURRENT_DATE,
    data_saida DATE,
    ativo BOOLEAN DEFAULT true,
    UNIQUE(equipe_id, usuario_id)
);
```

### 🔐 **permissoes_sistema** (Controle Granular)
```sql
CREATE TABLE permissoes_sistema (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo VARCHAR(100) NOT NULL UNIQUE, -- "chamados.view_all", "relatorios.executive"
    nome VARCHAR(255) NOT NULL,
    descricao TEXT,
    modulo VARCHAR(50), -- "chamados", "relatorios", "usuarios"
    nivel_minimo INTEGER DEFAULT 1, -- Nível mínimo necessário
    ativo BOOLEAN DEFAULT true
);
```

### 🎯 **perfis_permissoes** (Permissões por Perfil)
```sql
CREATE TABLE perfis_permissoes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo_usuario VARCHAR(30) NOT NULL,
    permissao_codigo VARCHAR(100) NOT NULL REFERENCES permissoes_sistema(codigo),
    concedida BOOLEAN DEFAULT true,
    UNIQUE(tipo_usuario, permissao_codigo)
);
```

### 📋 **delegacoes** (Delegação de Autoridade)
```sql
CREATE TABLE delegacoes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delegante_id UUID NOT NULL REFERENCES usuarios(id), -- Quem delega (ex: Gláucia)
    delegatario_id UUID NOT NULL REFERENCES usuarios(id), -- Para quem delega
    permissoes JSONB NOT NULL, -- Lista de permissões delegadas
    data_inicio DATE NOT NULL,
    data_fim DATE,
    motivo TEXT,
    ativo BOOLEAN DEFAULT true,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 📊 **audit_acessos** (Log de Acessos)
```sql
CREATE TABLE audit_acessos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id),
    acao VARCHAR(100) NOT NULL, -- "login", "view_executive_dashboard", "export_report"
    recurso VARCHAR(255), -- Recurso acessado
    ip_address INET,
    user_agent TEXT,
    sucesso BOOLEAN DEFAULT true,
    detalhes JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 🧑‍💻 **desenvolvedores** (Perfis Técnicos)
```sql
CREATE TABLE desenvolvedores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE UNIQUE,
    especialidades JSONB, -- ["Python", "React", "DevOps", "Mobile"]
    nivel_senioridade VARCHAR(20) CHECK (nivel_senioridade IN ('junior', 'pleno', 'senior', 'tech_lead', 'arquiteto')),
    capacidade_horas_dia INTEGER DEFAULT 8,
    custo_hora DECIMAL(10,2),
    bio TEXT,
    linkedin_url VARCHAR(500),
    github_url VARCHAR(500),
    ativo BOOLEAN DEFAULT true,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### ⏱️ **chamados_tempo** (Tracking de Horas)
```sql
CREATE TABLE chamados_tempo (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chamado_id UUID NOT NULL REFERENCES chamados(id) ON DELETE CASCADE,
    desenvolvedor_id UUID NOT NULL REFERENCES desenvolvedores(id),
    inicio TIMESTAMP NOT NULL,
    fim TIMESTAMP,
    horas_trabalhadas DECIMAL(10,2) NOT NULL,
    descricao_atividade TEXT NOT NULL,
    tipo_atividade VARCHAR(50) CHECK (tipo_atividade IN ('analise', 'desenvolvimento', 'teste', 'deploy', 'documentacao', 'reuniao')),
    data_lancamento DATE DEFAULT CURRENT_DATE,
    aprovado BOOLEAN DEFAULT false,
    aprovado_por UUID REFERENCES usuarios(id),
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## 📎 Anexos e Comunicação

### 📄 **chamados_anexos**
```sql
CREATE TABLE chamados_anexos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chamado_id UUID NOT NULL REFERENCES chamados(id) ON DELETE CASCADE,
    usuario_id UUID NOT NULL REFERENCES usuarios(id),
    nome_arquivo VARCHAR(255) NOT NULL,
    nome_original VARCHAR(255) NOT NULL,
    caminho_arquivo VARCHAR(500) NOT NULL,
    tamanho_bytes BIGINT NOT NULL,
    tipo_mime VARCHAR(100) NOT NULL,
    hash_arquivo VARCHAR(64), -- Para verificação de integridade
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 💬 **chamados_comentarios**
```sql
CREATE TABLE chamados_comentarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chamado_id UUID NOT NULL REFERENCES chamados(id) ON DELETE CASCADE,
    usuario_id UUID NOT NULL REFERENCES usuarios(id),
    comentario TEXT NOT NULL,
    visivel_cliente BOOLEAN DEFAULT true,
    tipo_comentario VARCHAR(20) DEFAULT 'comentario' CHECK (tipo_comentario IN ('comentario', 'nota_interna', 'solucao')),
    editado BOOLEAN DEFAULT false,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    editado_em TIMESTAMP
);
```

---

## ⚙️ Configurações do Sistema

### 📅 **configuracoes_sla**
```sql
CREATE TABLE configuracoes_sla (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID REFERENCES clientes(id), -- NULL = configuração global
    equipe_id UUID REFERENCES equipes(id), -- SLA específico por equipe
    tipo_chamado VARCHAR(20),
    prioridade VARCHAR(20),
    sla_horas INTEGER NOT NULL,
    aplicar_escalonamento BOOLEAN DEFAULT true,
    tempo_escalonamento_horas INTEGER DEFAULT 2,
    ativo BOOLEAN DEFAULT true,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(cliente_id, equipe_id, tipo_chamado, prioridade)
);
```

### 🔔 **notificacoes**
```sql
CREATE TABLE notificacoes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    chamado_id UUID REFERENCES chamados(id) ON DELETE CASCADE,
    tipo VARCHAR(50) NOT NULL CHECK (tipo IN ('novo_chamado', 'atribuido', 'comentario', 'sla_vencendo', 'status_alterado')),
    titulo VARCHAR(255) NOT NULL,
    mensagem TEXT NOT NULL,
    lida BOOLEAN DEFAULT false,
    url_acao VARCHAR(500), -- Link para ação específica
    dados_extras JSONB,
    criada_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## 🔗 Relacionamentos e Constraints

### **Chaves Estrangeiras Principais**
```sql
-- Relacionamentos Cliente
ALTER TABLE filiais ADD CONSTRAINT fk_filiais_cliente 
    FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE CASCADE;

ALTER TABLE sistemas ADD CONSTRAINT fk_sistemas_cliente 
    FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE CASCADE;

-- Relacionamentos Chamado
ALTER TABLE chamados ADD CONSTRAINT fk_chamados_cliente 
    FOREIGN KEY (cliente_id) REFERENCES clientes(id);

ALTER TABLE chamados ADD CONSTRAINT fk_chamados_filial 
    FOREIGN KEY (filial_id) REFERENCES filiais(id);

ALTER TABLE chamados ADD CONSTRAINT fk_chamados_sistema 
    FOREIGN KEY (sistema_id) REFERENCES sistemas(id);

-- Relacionamento Usuário-Desenvolvedor
ALTER TABLE desenvolvedores ADD CONSTRAINT fk_desenvolvedores_usuario 
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE;
```

### **Triggers para Atualização Automática**
```sql
-- Trigger para atualizar timestamp
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.atualizado_em = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Aplicar trigger nas tabelas principais
CREATE TRIGGER update_usuarios_timestamp 
    BEFORE UPDATE ON usuarios FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_clientes_timestamp 
    BEFORE UPDATE ON clientes FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_chamados_timestamp 
    BEFORE UPDATE ON chamados FOR EACH ROW EXECUTE FUNCTION update_timestamp();
```

---

## 📈 Índices para Performance

### **Índices Essenciais**
```sql
-- Índices para consultas frequentes de chamados
CREATE INDEX idx_chamados_status ON chamados(status);
CREATE INDEX idx_chamados_cliente ON chamados(cliente_id);
CREATE INDEX idx_chamados_atribuido ON chamados(atribuido_para);
CREATE INDEX idx_chamados_criado_em ON chamados(criado_em);
CREATE INDEX idx_chamados_prazo_sla ON chamados(prazo_sla);
CREATE INDEX idx_chamados_numero ON chamados(numero);

-- Índices para histórico e auditoria
CREATE INDEX idx_historico_chamado ON chamados_historico(chamado_id);
CREATE INDEX idx_historico_usuario ON chamados_historico(usuario_id);
CREATE INDEX idx_historico_data ON chamados_historico(criado_em);

-- Índices para busca de texto
CREATE INDEX idx_chamados_titulo_gin ON chamados USING GIN(to_tsvector('portuguese', titulo));
CREATE INDEX idx_chamados_descricao_gin ON chamados USING GIN(to_tsvector('portuguese', descricao));

-- Índices compostos para consultas complexas
CREATE INDEX idx_chamados_cliente_status ON chamados(cliente_id, status);
CREATE INDEX idx_chamados_atribuido_status ON chamados(atribuido_para, status);
```

---

## 🎯 Vantagens da Estrutura

### ✅ **Escalabilidade**
- Suporte para múltiplos clientes sem conflitos
- Estrutura preparada para crescimento
- Índices otimizados para performance

### ✅ **Flexibilidade**
- Campos JSONB para dados variáveis
- Configuração de SLA por cliente
- Tipos de chamados extensíveis

### ✅ **Auditoria Completa**
- Histórico de todas as mudanças
- Rastreabilidade total
- Compliance e governança

### ✅ **Relatórios Avançados**
- Estrutura otimizada para dashboards
- Métricas de produtividade
- Análise de SLA e performance

### ✅ **Segurança**
- Isolamento por cliente
- Controle de acesso granular
- Integridade referencial

---

## 📊 Consultas Exemplo

### **Chamados por Status**
```sql
SELECT 
    c.nome_empresa,
    ch.status,
    COUNT(*) as total_chamados
FROM chamados ch
JOIN clientes c ON ch.cliente_id = c.id
GROUP BY c.nome_empresa, ch.status
ORDER BY c.nome_empresa, ch.status;
```

### **SLA Vencendo**
```sql
SELECT 
    ch.numero,
    ch.titulo,
    c.nome_empresa,
    ch.prazo_sla,
    EXTRACT(HOUR FROM (ch.prazo_sla - CURRENT_TIMESTAMP)) as horas_restantes
FROM chamados ch
JOIN clientes c ON ch.cliente_id = c.id
WHERE ch.prazo_sla < CURRENT_TIMESTAMP + INTERVAL '2 hours'
AND ch.status NOT IN ('resolvido', 'fechado', 'cancelado')
ORDER BY ch.prazo_sla;
```

### **Produtividade por Desenvolvedor**
```sql
SELECT 
    u.nome_completo,
    COUNT(ch.id) as chamados_resolvidos,
    SUM(ct.horas_trabalhadas) as total_horas,
    AVG(ct.horas_trabalhadas) as media_horas_por_chamado
FROM usuarios u
JOIN desenvolvedores d ON u.id = d.usuario_id
JOIN chamados ch ON u.id = ch.atribuido_para
JOIN chamados_tempo ct ON ch.id = ct.chamado_id AND d.id = ct.desenvolvedor_id
WHERE ch.status = 'resolvido'
AND ch.resolvido_em >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY u.id, u.nome_completo
ORDER BY chamados_resolvidos DESC;
```

---

## 🚀 Próximos Passos

1. **Validar estrutura** com stakeholders
2. **Criar scripts de migração** para desenvolvimento
3. **Implementar seeds** para dados de teste
4. **Configurar backup** e recovery
5. **Definir políticas de retenção** de dados
6. **Implementar views** para relatórios complexos

---

*Estrutura de banco de dados - Sistema de Gestão de Chamados v1.0*