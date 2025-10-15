# Prompt Completo para Implementação de Roteamento com Traefik

## 📋 Contexto do Projeto

Tenho múltiplos serviços rodando em portas diferentes no mesmo servidor (10.0.20.11):
- **Portais React/Vite**: portas 3001, 3002, 3003...
- **APIs FastAPI**: portas 8001, 8002, 8003...
- **APIs Java (Spring Boot)**: portas 8004, 8005, 8006...

**Objetivo**: Configurar o Traefik como reverse proxy para acessar todos os serviços através do domínio `office.inoveon.com.br` usando paths, mantendo o acesso direto por IP:porta funcionando.

---

## 🎯 Requisitos Funcionais

### Acesso Dual (2 formas de acesso funcionando simultaneamente):

**Forma 1 - Acesso Direto (Desenvolvimento/Interno):**
```
http://10.0.20.11:3001/          → Portal de Suporte
http://10.0.20.11:8003/api/auth  → API de Suporte (FastAPI)
http://10.0.20.11:8004/api/users → API de Backup (Java)
```

**Forma 2 - Acesso via Domínio (Produção/Externo):**
```
https://office.inoveon.com.br/suporte/          → Portal de Suporte
https://office.inoveon.com.br/api/suporte/auth  → API de Suporte (FastAPI)
https://office.inoveon.com.br/api/backup/users  → API de Backup (Java)
```

---

## 🔧 Arquitetura da Solução

### Como Funciona:

1. **Traefik** recebe todas as requisições HTTPS na porta 443
2. **Analisa o Host e o Path** da requisição
3. **Roteia para o serviço correto** baseado em regras
4. **Mantém ou remove prefixos** conforme necessário
5. **Gera certificados SSL automaticamente** via Let's Encrypt

### Fluxo de Requisição:

```
Cliente → https://office.inoveon.com.br/suporte/login
   ↓
Traefik (analisa: Host=office.inoveon.com.br, Path=/suporte/login)
   ↓
Identifica: Router "suporte-portal"
   ↓
Encaminha para: http://10.0.20.11:3001/suporte/login
   ↓
React detecta basename=/suporte e renderiza corretamente
```

```
Cliente → https://office.inoveon.com.br/api/suporte/auth
   ↓
Traefik (analisa: Host=office.inoveon.com.br, Path=/api/suporte/auth)
   ↓
Identifica: Router "suporte-api"
   ↓
Remove "/api/suporte" via middleware stripprefix
   ↓
Encaminha para: http://10.0.20.11:8003/api/auth
   ↓
FastAPI recebe /api/auth normalmente
```

---

## 📦 Parte 1: Configuração do Traefik

### docker-compose.yml

```yaml
version: '3.8'

services:
  traefik:
    image: traefik:latest
    container_name: traefik
    restart: unless-stopped
    command:
      # Habilita API e Dashboard
      - "--api.dashboard=true"
      - "--api.insecure=false"

      # Configuração de providers
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"

      # Entrypoints
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"

      # Certificados SSL automáticos (Let's Encrypt)
      - "--certificatesresolvers.letsencrypt.acme.email=seu@email.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"

      # Logs
      - "--log.level=INFO"
      - "--accesslog=true"

    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"  # Dashboard (proteger em produção)

    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt
      - ./traefik-config:/etc/traefik

    networks:
      - traefik-network

    labels:
      # Dashboard do Traefik
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(`traefik.office.inoveon.com.br`)"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
      - "traefik.http.routers.dashboard.tls.certresolver=letsencrypt"
      - "traefik.http.routers.dashboard.service=api@internal"

  # ============================================
  # PORTAL DE SUPORTE (React/Vite - Porta 3001)
  # ============================================
  suporte-portal:
    image: nginx:alpine
    container_name: suporte-portal-proxy
    restart: unless-stopped
    networks:
      - traefik-network
    labels:
      - "traefik.enable=true"

      # Roteamento
      - "traefik.http.routers.suporte-portal.rule=Host(`office.inoveon.com.br`) && PathPrefix(`/suporte`)"
      - "traefik.http.routers.suporte-portal.entrypoints=websecure"
      - "traefik.http.routers.suporte-portal.tls.certresolver=letsencrypt"

      # Serviço (aponta para o servidor real)
      - "traefik.http.services.suporte-portal.loadbalancer.server.url=http://10.0.20.11:3001"

      # NÃO remove o /suporte porque o React precisa dele

  # ============================================
  # API DE SUPORTE (FastAPI - Porta 8003)
  # ============================================
  suporte-api:
    image: nginx:alpine
    container_name: suporte-api-proxy
    restart: unless-stopped
    networks:
      - traefik-network
    labels:
      - "traefik.enable=true"

      # Roteamento
      - "traefik.http.routers.suporte-api.rule=Host(`office.inoveon.com.br`) && PathPrefix(`/api/suporte`)"
      - "traefik.http.routers.suporte-api.entrypoints=websecure"
      - "traefik.http.routers.suporte-api.tls.certresolver=letsencrypt"

      # Serviço
      - "traefik.http.services.suporte-api.loadbalancer.server.url=http://10.0.20.11:8003"

      # Middleware: Remove /api/suporte antes de enviar para o backend
      - "traefik.http.middlewares.suporte-api-strip.stripprefix.prefixes=/api/suporte"

      # Middleware: Adiciona /api de volta
      - "traefik.http.middlewares.suporte-api-add.addprefix.prefix=/api"

      # Aplica os middlewares em ordem
      - "traefik.http.routers.suporte-api.middlewares=suporte-api-strip,suporte-api-add"

      # CORS (se necessário)
      - "traefik.http.middlewares.suporte-api-cors.headers.accesscontrolallowmethods=GET,POST,PUT,DELETE,OPTIONS,PATCH"
      - "traefik.http.middlewares.suporte-api-cors.headers.accesscontrolalloworigin=*"
      - "traefik.http.middlewares.suporte-api-cors.headers.accesscontrolallowheaders=*"

  # ============================================
  # API DE BACKUP (Java Spring Boot - Porta 8004)
  # ============================================
  backup-api:
    image: nginx:alpine
    container_name: backup-api-proxy
    restart: unless-stopped
    networks:
      - traefik-network
    labels:
      - "traefik.enable=true"

      # Roteamento
      - "traefik.http.routers.backup-api.rule=Host(`office.inoveon.com.br`) && PathPrefix(`/api/backup`)"
      - "traefik.http.routers.backup-api.entrypoints=websecure"
      - "traefik.http.routers.backup-api.tls.certresolver=letsencrypt"

      # Serviço
      - "traefik.http.services.backup-api.loadbalancer.server.url=http://10.0.20.11:8004"

      # Middleware: Remove /api/backup e adiciona /api
      - "traefik.http.middlewares.backup-api-strip.stripprefix.prefixes=/api/backup"
      - "traefik.http.middlewares.backup-api-add.addprefix.prefix=/api"
      - "traefik.http.routers.backup-api.middlewares=backup-api-strip,backup-api-add"

networks:
  traefik-network:
    driver: bridge
```

### Por que essa configuração?

- **stripprefix.prefixes=/api/suporte**: Remove o prefixo `/api/suporte` da URL
- **addprefix.prefix=/api**: Adiciona `/api` de volta (porque suas APIs já respondem em `/api/...`)
- **Ordem dos middlewares**: Primeiro remove `/api/suporte`, depois adiciona `/api`
- **Resultado**: `https://office.inoveon.com.br/api/suporte/auth` → `http://10.0.20.11:8003/api/auth`

---

## 🐍 Parte 2: FastAPI - Configuração

### Por que FastAPI precisa de ajustes?

O FastAPI por padrão não tem suporte nativo para `root_path` dinâmico detectado automaticamente. Precisamos configurá-lo para funcionar em ambos os cenários.

### Estrutura do Projeto FastAPI:

```
suporte-api/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── config.py
│   └── routers/
│       ├── __init__.py
│       └── auth.py
├── requirements.txt
└── .env
```

### config.py - Configuração Centralizada

```python
from pydantic_settings import BaseSettings
from functools import lru_cache

class Settings(BaseSettings):
    # Configurações gerais
    app_name: str = "Suporte API"
    version: str = "1.0.0"

    # Root path para quando estiver atrás do Traefik
    # Deixe vazio para acesso direto por IP
    root_path: str = ""

    # CORS
    cors_origins: list = [
        "http://10.0.20.11:3001",
        "https://office.inoveon.com.br"
    ]

    # Banco de dados, JWT, etc...
    database_url: str = "postgresql://..."
    secret_key: str = "sua-chave-secreta"

    class Config:
        env_file = ".env"

@lru_cache()
def get_settings():
    return Settings()
```

### main.py - Aplicação Principal

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import get_settings
from app.routers import auth
import os

settings = get_settings()

# Detecta automaticamente se está atrás de proxy
# Se a variável X-Forwarded-Prefix existir, usa ela
root_path = os.getenv("ROOT_PATH", settings.root_path)

app = FastAPI(
    title=settings.app_name,
    version=settings.version,
    root_path=root_path,  # Importante para documentação OpenAPI
    docs_url="/api/docs",  # Swagger UI
    redoc_url="/api/redoc",  # ReDoc
    openapi_url="/api/openapi.json"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routers
app.include_router(auth.router, prefix="/api", tags=["auth"])

# Health check (útil para monitoramento)
@app.get("/api/health")
async def health_check():
    return {"status": "healthy", "service": settings.app_name}

# Root endpoint
@app.get("/")
async def root():
    return {
        "message": f"Bem-vindo à {settings.app_name}",
        "docs": f"{root_path}/api/docs" if root_path else "/api/docs"
    }
```

### routers/auth.py - Exemplo de Router

```python
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

router = APIRouter()

class LoginRequest(BaseModel):
    username: str
    password: str

class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

@router.post("/auth/login", response_model=LoginResponse)
async def login(credentials: LoginRequest):
    """
    Endpoint de login

    Funcionará em:
    - http://10.0.20.11:8003/api/auth/login (direto)
    - https://office.inoveon.com.br/api/suporte/auth/login (via Traefik)
    """
    # Sua lógica de autenticação aqui
    if credentials.username == "admin" and credentials.password == "admin":
        return LoginResponse(access_token="token-exemplo")

    raise HTTPException(status_code=401, detail="Credenciais inválidas")

@router.get("/auth/me")
async def get_current_user():
    """
    Retorna informações do usuário autenticado
    """
    return {"username": "admin", "email": "admin@inoveon.com.br"}
```

### requirements.txt

```txt
fastapi==0.104.1
uvicorn[standard]==0.24.0
pydantic==2.5.0
pydantic-settings==2.1.0
python-multipart==0.0.6
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-dotenv==1.0.0
```

### .env

```env
ROOT_PATH=
CORS_ORIGINS=["http://10.0.20.11:3001","https://office.inoveon.com.br"]
DATABASE_URL=postgresql://user:pass@localhost/db
SECRET_KEY=sua-chave-super-secreta-aqui
```

### Como executar:

```bash
# Desenvolvimento (acesso direto)
uvicorn app.main:app --host 0.0.0.0 --port 8003 --reload

# Produção
uvicorn app.main:app --host 0.0.0.0 --port 8003 --workers 4
```

### Testando os endpoints:

```bash
# Acesso direto
curl -X POST http://10.0.20.11:8003/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}'

# Via Traefik (após configurado)
curl -X POST https://office.inoveon.com.br/api/suporte/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}'
```

---

## ☕ Parte 3: Java Spring Boot - Configuração

### Por que Java precisa de ajustes?

O Spring Boot precisa saber que está rodando atrás de um proxy reverso e qual o contexto path correto para gerar URLs e lidar com redirecionamentos corretamente.

### Estrutura do Projeto Spring Boot:

```
backup-api/
├── src/
│   └── main/
│       ├── java/
│       │   └── com/
│       │       └── inoveon/
│       │           └── backup/
│       │               ├── BackupApplication.java
│       │               ├── config/
│       │               │   ├── WebConfig.java
│       │               │   └── CorsConfig.java
│       │               └── controller/
│       │                   └── UserController.java
│       └── resources/
│           └── application.yml
├── pom.xml
└── Dockerfile
```

### application.yml - Configuração Principal

```yaml
server:
  port: 8004

  # Configuração para proxy reverso
  forward-headers-strategy: framework

  # Servlet context path (para acesso direto)
  # Mantenha vazio para acesso direto funcionar
  servlet:
    context-path: /

spring:
  application:
    name: backup-api

  # CORS permitidos
  web:
    cors:
      allowed-origins:
        - http://10.0.20.11:3002
        - https://office.inoveon.com.br
      allowed-methods:
        - GET
        - POST
        - PUT
        - DELETE
        - OPTIONS
        - PATCH
      allowed-headers: "*"
      allow-credentials: true
      max-age: 3600

# Configuração do Tomcat para aceitar headers de proxy
tomcat:
  remoteip:
    remote-ip-header: X-Forwarded-For
    protocol-header: X-Forwarded-Proto
    internal-proxies: 10\\.0\\.20\\..*

# Logging
logging:
  level:
    root: INFO
    com.inoveon: DEBUG
  pattern:
    console: "%d{yyyy-MM-dd HH:mm:ss} - %msg%n"

# Actuator (health check)
management:
  endpoints:
    web:
      exposure:
        include: health,info
      base-path: /api/actuator
  endpoint:
    health:
      show-details: always
```

### WebConfig.java - Configuração Web

```java
package com.inoveon.backup.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.PathMatchConfigurer;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    /**
     * Configuração para permitir que a aplicação funcione
     * tanto com acesso direto quanto atrás de proxy reverso
     */
    @Override
    public void configurePathMatch(PathMatchConfigurer configurer) {
        // Permite trailing slashes
        configurer.setUseTrailingSlashMatch(true);
    }
}
```

### CorsConfig.java - Configuração CORS Adicional

```java
package com.inoveon.backup.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.CorsFilter;

import java.util.Arrays;
import java.util.List;

@Configuration
public class CorsConfig {

    @Bean
    public CorsFilter corsFilter() {
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        CorsConfiguration config = new CorsConfiguration();

        // Permitir credenciais
        config.setAllowCredentials(true);

        // Origens permitidas
        config.setAllowedOrigins(Arrays.asList(
            "http://10.0.20.11:3002",
            "https://office.inoveon.com.br"
        ));

        // Métodos permitidos
        config.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"));

        // Headers permitidos
        config.setAllowedHeaders(List.of("*"));

        // Expor headers
        config.setExposedHeaders(Arrays.asList(
            "Authorization",
            "Content-Type",
            "X-Total-Count"
        ));

        // Max age
        config.setMaxAge(3600L);

        source.registerCorsConfiguration("/**", config);

        return new CorsFilter(source);
    }
}
```

### UserController.java - Exemplo de Controller

```java
package com.inoveon.backup.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletRequest;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/users")
public class UserController {

    /**
     * Lista todos os usuários
     *
     * Funcionará em:
     * - http://10.0.20.11:8004/api/users (direto)
     * - https://office.inoveon.com.br/api/backup/users (via Traefik)
     */
    @GetMapping
    public ResponseEntity<List<Map<String, Object>>> listUsers(HttpServletRequest request) {
        // Log para debug
        System.out.println("Request URI: " + request.getRequestURI());
        System.out.println("Context Path: " + request.getContextPath());
        System.out.println("Servlet Path: " + request.getServletPath());

        // Headers do proxy (se existirem)
        String forwardedFor = request.getHeader("X-Forwarded-For");
        String forwardedProto = request.getHeader("X-Forwarded-Proto");
        String forwardedPrefix = request.getHeader("X-Forwarded-Prefix");

        System.out.println("X-Forwarded-For: " + forwardedFor);
        System.out.println("X-Forwarded-Proto: " + forwardedProto);
        System.out.println("X-Forwarded-Prefix: " + forwardedPrefix);

        // Dados de exemplo
        List<Map<String, Object>> users = List.of(
            Map.of("id", 1, "name", "João Silva", "email", "joao@inoveon.com.br"),
            Map.of("id", 2, "name", "Maria Santos", "email", "maria@inoveon.com.br")
        );

        return ResponseEntity.ok(users);
    }

    /**
     * Busca usuário por ID
     */
    @GetMapping("/{id}")
    public ResponseEntity<Map<String, Object>> getUser(@PathVariable Long id) {
        Map<String, Object> user = Map.of(
            "id", id,
            "name", "João Silva",
            "email", "joao@inoveon.com.br",
            "role", "admin"
        );

        return ResponseEntity.ok(user);
    }

    /**
     * Cria novo usuário
     */
    @PostMapping
    public ResponseEntity<Map<String, Object>> createUser(@RequestBody Map<String, Object> userData) {
        Map<String, Object> response = new HashMap<>(userData);
        response.put("id", 3);
        response.put("created_at", System.currentTimeMillis());

        return ResponseEntity.status(201).body(response);
    }

    /**
     * Health check
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of(
            "status", "healthy",
            "service", "backup-api",
            "timestamp", String.valueOf(System.currentTimeMillis())
        ));
    }
}
```

### BackupApplication.java - Classe Principal

```java
package com.inoveon.backup;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.web.filter.ForwardedHeaderFilter;

@SpringBootApplication
public class BackupApplication {

    public static void main(String[] args) {
        SpringApplication.run(BackupApplication.class, args);
    }

    /**
     * Bean para processar headers X-Forwarded-* do proxy
     * IMPORTANTE: Isso permite que o Spring saiba quando está atrás de um proxy
     */
    @Bean
    public ForwardedHeaderFilter forwardedHeaderFilter() {
        return new ForwardedHeaderFilter();
    }
}
```

### pom.xml - Dependências Maven

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.0</version>
        <relativePath/>
    </parent>

    <groupId>com.inoveon</groupId>
    <artifactId>backup-api</artifactId>
    <version>1.0.0</version>
    <name>Backup API</name>
    <description>API de Backup com suporte a proxy reverso</description>

    <properties>
        <java.version>17</java.version>
    </properties>

    <dependencies>
        <!-- Spring Boot Web -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>

        <!-- Spring Boot Actuator (health checks) -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>

        <!-- Lombok (opcional, para reduzir boilerplate) -->
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>

        <!-- Spring Boot DevTools (desenvolvimento) -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-devtools</artifactId>
            <scope>runtime</scope>
            <optional>true</optional>
        </dependency>

        <!-- Testes -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
```

### Como executar:

```bash
# Desenvolvimento
mvn spring-boot:run

# Produção (gerar JAR)
mvn clean package
java -jar target/backup-api-1.0.0.jar

# Com profile específico
java -jar target/backup-api-1.0.0.jar --spring.profiles.active=production
```

### Testando os endpoints:

```bash
# Acesso direto
curl http://10.0.20.11:8004/api/users

# Via Traefik (após configurado)
curl https://office.inoveon.com.br/api/backup/users

# Health check
curl http://10.0.20.11:8004/api/actuator/health
```

---

## ⚛️ Parte 4: React/Vite - Configuração Frontend

### Por que o React precisa de ajustes?

O React Router precisa saber o `basename` correto para gerar URLs e navegar adequadamente. Vamos fazer isso dinamicamente para suportar ambos os cenários.

### Estrutura do Projeto React:

```
suporte-portal/
├── public/
│   └── index.html (será gerado pelo Vite)
├── src/
│   ├── main.jsx
│   ├── App.jsx
│   ├── config/
│   │   └── api.js
│   ├── pages/
│   │   ├── Home.jsx
│   │   ├── Login.jsx
│   │   └── Dashboard.jsx
│   └── components/
│       └── Navbar.jsx
├── index.html
├── vite.config.js
└── package.json
```

### index.html - HTML Base

```html
<!DOCTYPE html>
<html lang="pt-BR">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Portal de Suporte - Inoveon</title>

    <script>
      /**
       * Detecção automática do basename
       *
       * Este script roda ANTES do React carregar e detecta automaticamente
       * se a aplicação está rodando em:
       * - Raiz (http://10.0.20.11:3001/) → basename = ''
       * - Subpath (https://office.inoveon.com.br/suporte/) → basename = '/suporte'
       *
       * Isso permite que o mesmo build funcione em ambos os ambientes!
       */

      // Lista de possíveis prefixos (adicione outros serviços aqui)
      const validPrefixes = ['suporte', 'backup', 'monitoramento'];

      // Pega o primeiro segmento do path
      const pathSegments = window.location.pathname.split('/').filter(Boolean);
      const firstSegment = pathSegments[0];

      // Verifica se é um prefixo válido
      const basePath = validPrefixes.includes(firstSegment) ? `/${firstSegment}` : '';

      // Cria a tag <base> dinamicamente
      const baseTag = document.createElement('base');
      baseTag.href = basePath + '/';
      document.head.appendChild(baseTag);

      // Salva para uso no React
      window.__APP_BASE_PATH__ = basePath;
      window.__APP_CONFIG__ = {
        basePath: basePath,
        apiUrl: basePath ? `https://office.inoveon.com.br/api${basePath}` : 'http://10.0.20.11:8003/api'
      };

      // Log para debug (remover em produção)
      console.log('Base Path detectado:', basePath);
      console.log('API URL:', window.__APP_CONFIG__.apiUrl);
    </script>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
```

### vite.config.js - Configuração do Vite

```javascript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],

  // Base path - deixa vazio porque será detectado dinamicamente no browser
  base: '/',

  server: {
    port: 3001,
    host: '0.0.0.0',

    // Proxy para desenvolvimento (opcional)
    proxy: {
      '/api': {
        target: 'http://10.0.20.11:8003',
        changeOrigin: true,
        secure: false
      }
    }
  },

  build: {
    outDir: 'dist',
    sourcemap: false,

    // Otimizações
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom', 'react-router-dom'],
        }
      }
    }
  }
})
```

### src/config/api.js - Configuração da API

```javascript
import axios from 'axios';

/**
 * Detecta automaticamente a URL base da API
 *
 * - Desenvolvimento/Direto: http://10.0.20.11:8003/api
 * - Produção/Traefik: https://office.inoveon.com.br/api/suporte
 */
const getApiBaseUrl = () => {
  const basePath = window.__APP_BASE_PATH__ || '';

  if (basePath) {
    // Está atrás do Traefik
    const protocol = window.location.protocol;
    const host = window.location.host;
    return `${protocol}//${host}/api${basePath}`;
  } else {
    // Acesso direto
    return 'http://10.0.20.11:8003/api';
  }
};

// Instância do axios configurada
export const api = axios.create({
  baseURL: getApiBaseUrl(),
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json'
  }
});

// Interceptor para adicionar token de autenticação
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('access_token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Interceptor para tratar erros de resposta
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // Token expirado ou inválido
      localStorage.removeItem('access_token');
      window.location.href = window.__APP_BASE_PATH__ + '/login';
    }
    return Promise.reject(error);
  }
);

// Funções helper
export const authApi = {
  login: (username, password) =>
    api.post('/auth/login', { username, password }),

  logout: () => {
    localStorage.removeItem('access_token');
    window.location.href = window.__APP_BASE_PATH__ + '/login';
  },

  getCurrentUser: () =>
    api.get('/auth/me'),
};

export default api;
```

### src/main.jsx - Entry Point

```jsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
```

### src/App.jsx - Aplicação Principal

```jsx
import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Home from './pages/Home';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Navbar from './components/Navbar';

function App() {
  /**
   * Pega o basename detectado automaticamente
   * Este valor foi definido no index.html antes do React carregar
   */
  const basename = window.__APP_BASE_PATH__ || '';

  console.log('App carregada com basename:', basename);

  return (
    <BrowserRouter basename={basename}>
      <div className="app">
        <Navbar />
        <main className="main-content">
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/login" element={<Login />} />
            <Route path="/dashboard" element={<Dashboard />} />

            {/* Rota 404 */}
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </main>
      </div>
    </BrowserRouter>
  );
}

export default App;
```

### src/pages/Login.jsx - Página de Login

```jsx
import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { authApi } from '../config/api';

function Login() {
  const navigate = useNavigate();
  const [formData, setFormData] = useState({
    username: '',
    password: ''
  });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const response = await authApi.login(formData.username, formData.password);

      // Salva o token
      localStorage.setItem('access_token', response.data.access_token);

      // Redireciona para o dashboard
      navigate('/dashboard');
    } catch (err) {
      console.error('Erro no login:', err);
      setError(err.response?.data?.detail || 'Erro ao fazer login');
    } finally {
      setLoading(false);
    }
  };

  const handleChange = (e) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value
    });
  };

  return (
    <div className="login-page">
      <div className="login-card">
        <h1>Login - Portal de Suporte</h1>

        {error && (
          <div className="error-message">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label htmlFor="username">Usuário:</label>
            <input
              type="text"
              id="username"
              name="username"
              value={formData.username}
              onChange={handleChange}
              required
              disabled={loading}
            />
          </div>

          <div className="form-group">
            <label htmlFor="password">Senha:</label>
            <input
              type="password"
              id="password"
              name="password"
              value={formData.password}
              onChange={handleChange}
              required
              disabled={loading}
            />
          </div>

          <button type="submit" disabled={loading}>
            {loading ? 'Entrando...' : 'Entrar'}
          </button>
        </form>

        <div className="debug-info">
          <small>
            Base Path: {window.__APP_BASE_PATH__ || '(raiz)'}
            <br />
            API URL: {window.__APP_CONFIG__?.apiUrl}
          </small>
        </div>
      </div>
    </div>
  );
}

export default Login;
```

### src/pages/Dashboard.jsx - Dashboard

```jsx
import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { authApi } from '../config/api';

function Dashboard() {
  const navigate = useNavigate();
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadUserData();
  }, []);

  const loadUserData = async () => {
    try {
      const response = await authApi.getCurrentUser();
      setUser(response.data);
    } catch (error) {
      console.error('Erro ao carregar usuário:', error);
      navigate('/login');
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = () => {
    authApi.logout();
  };

  if (loading) {
    return <div className="loading">Carregando...</div>;
  }

  return (
    <div className="dashboard">
      <h1>Dashboard - Portal de Suporte</h1>

      {user && (
        <div className="user-info">
          <p>Bem-vindo, <strong>{user.username}</strong>!</p>
          <p>Email: {user.email}</p>
        </div>
      )}

      <div className="dashboard-content">
        <h2>Estatísticas</h2>
        <div className="stats-grid">
          <div className="stat-card">
            <h3>Tickets Abertos</h3>
            <p className="stat-number">42</p>
          </div>
          <div className="stat-card">
            <h3>Tickets Resolvidos</h3>
            <p className="stat-number">128</p>
          </div>
          <div className="stat-card">
            <h3>Em Andamento</h3>
            <p className="stat-number">15</p>
          </div>
        </div>
      </div>

      <button onClick={handleLogout} className="logout-btn">
        Sair
      </button>

      <div className="debug-info">
        <small>
          Base Path: {window.__APP_BASE_PATH__ || '(raiz)'}
          <br />
          API URL: {window.__APP_CONFIG__?.apiUrl}
        </small>
      </div>
    </div>
  );
}

export default Dashboard;
```

### src/components/Navbar.jsx - Navegação

```jsx
import React from 'react';
import { Link, useLocation } from 'react-router-dom';

function Navbar() {
  const location = useLocation();
  const isLoggedIn = !!localStorage.getItem('access_token');

  return (
    <nav className="navbar">
      <div className="nav-brand">
        <Link to="/">Portal Inoveon</Link>
      </div>

      <ul className="nav-links">
        <li>
          <Link
            to="/"
            className={location.pathname === '/' ? 'active' : ''}
          >
            Home
          </Link>
        </li>

        {isLoggedIn ? (
          <li>
            <Link
              to="/dashboard"
              className={location.pathname === '/dashboard' ? 'active' : ''}
            >
              Dashboard
            </Link>
          </li>
        ) : (
          <li>
            <Link
              to="/login"
              className={location.pathname === '/login' ? 'active' : ''}
            >
              Login
            </Link>
          </li>
        )}
      </ul>
    </nav>
  );
}

export default Navbar;
```

### package.json

```json
{
  "name": "suporte-portal",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "lint": "eslint . --ext js,jsx"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.20.0",
    "axios": "^1.6.2"
  },
  "devDependencies": {
    "@types/react": "^18.2.43",
    "@types/react-dom": "^18.2.17",
    "@vitejs/plugin-react": "^4.2.1",
    "vite": "^5.0.8"
  }
}
```

### Como executar:

```bash
# Instalar dependências
npm install

# Desenvolvimento
npm run dev

# Build para produção
npm run build

# Preview do build
npm run preview
```

---

## 🧪 Parte 5: Testes e Validação

### Script de teste completo:

```bash
#!/bin/bash

echo "=== Testes de Conectividade ==="

# Cores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Função para testar endpoint
test_endpoint() {
    local url=$1
    local description=$2

    echo -n "Testando $description... "

    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|201\|301\|302"; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${RED}✗ FALHOU${NC}"
        return 1
    fi
}

echo ""
echo "--- Testes de Acesso Direto (IP:Porta) ---"
test_endpoint "http://10.0.20.11:3001" "Portal Suporte (direto)"
test_endpoint "http://10.0.20.11:8003/api/health" "API Suporte (direto)"
test_endpoint "http://10.0.20.11:8004/api/actuator/health" "API Backup Java (direto)"

echo ""
echo "--- Testes via Traefik (Domínio) ---"
test_endpoint "https://office.inoveon.com.br/suporte/" "Portal Suporte (Traefik)"
test_endpoint "https://office.inoveon.com.br/api/suporte/health" "API Suporte (Traefik)"
test_endpoint "https://office.inoveon.com.br/api/backup/actuator/health" "API Backup (Traefik)"

echo ""
echo "--- Teste de Login ---"
curl -X POST https://office.inoveon.com.br/api/suporte/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}' \
  -v

echo ""
echo "=== Fim dos Testes ==="
```

Salve como `test-endpoints.sh` e execute:
```bash
chmod +x test-endpoints.sh
./test-endpoints.sh
```

---

## 📝 Checklist de Implementação

### ✅ Pré-requisitos:
- [ ] Docker e Docker Compose instalados
- [ ] Domínio `office.inoveon.com.br` configurado no DNS
- [ ] Portas 80 e 443 abertas no firewall
- [ ] Servidor com IP 10.0.20.11 acessível

### ✅ Traefik:
- [ ] Criar `docker-compose.yml` com configuração do Traefik
- [ ] Criar diretório `./letsencrypt` para certificados
- [ ] Configurar email no Let's Encrypt
- [ ] Adicionar labels para cada serviço
- [ ] Subir o Traefik: `docker-compose up -d`
- [ ] Verificar dashboard: `http://seu-servidor:8080`

### ✅ FastAPI:
- [ ] Criar estrutura de pastas
- [ ] Configurar `config.py` com settings
- [ ] Ajustar `main.py` com CORS e root_path
- [ ] Criar routers com endpoints
- [ ] Testar localmente na porta 8003
- [ ] Verificar `/api/docs` funcionando

### ✅ Java Spring Boot:
- [ ] Configurar `application.yml`
- [ ] Criar `WebConfig.java` e `CorsConfig.java`
- [ ] Implementar controllers com `/api` prefix
- [ ] Adicionar `ForwardedHeaderFilter` bean
- [ ] Testar localmente na porta 8004
- [ ] Verificar `/api/actuator/health`

### ✅ React/Vite:
- [ ] Modificar `index.html` com script de detecção
- [ ] Configurar `vite.config.js`
- [ ] Criar `src/config/api.js` com detecção de URL
- [ ] Ajustar `App.jsx` com basename dinâmico
- [ ] Implementar páginas (Login, Dashboard)
- [ ] Build e testar: `npm run build && npm run preview`
- [ ] Verificar acesso direto: `http://10.0.20.11:3001`

### ✅ Validação Final:
- [ ] Testar acesso direto por IP em TODOS os serviços
- [ ] Testar acesso via domínio em TODOS os serviços
- [ ] Verificar certificado SSL válido
- [ ] Testar login e fluxo completo
- [ ] Verificar CORS funcionando
- [ ] Monitorar logs do Traefik: `docker-compose logs -f traefik`

---

## 🚨 Troubleshooting

### Problema: Portal não carrega via Traefik
```bash
# Verificar logs do Traefik
docker-compose logs traefik | grep suporte

# Verificar se o service está acessível
curl -I http://10.0.20.11:3001

# Verificar labels do container
docker inspect <container-id> | grep -A 20 Labels
```

### Problema: API retorna 404
```bash
# Verificar se middleware stripprefix está correto
# FastAPI: Deve remover /api/suporte e adicionar /api
# Java: Deve remover /api/backup e adicionar /api

# Testar manualmente
curl -v https://office.inoveon.com.br/api/suporte/health
```

### Problema: CORS error
```bash
# Verificar headers da resposta
curl -H "Origin: https://office.inoveon.com.br" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type" \
  -X OPTIONS \
  https://office.inoveon.com.br/api/suporte/auth/login \
  -v
```

### Problema: Certificado SSL não gera
```bash
# Verificar se portas 80/443 estão abertas
netstat -tuln | grep -E '80|443'

# Verificar logs do Let's Encrypt
docker-compose logs traefik | grep acme

# Forçar renovação
docker-compose exec traefik rm /letsencrypt/acme.json
docker-compose restart traefik
```

---

## 🎓 Resumo: Como Funciona

### Fluxo de Requisição Completo:

1. **Usuário acessa**: `https://office.inoveon.com.br/suporte/login`

2. **DNS resolve** para o IP do servidor com Traefik

3. **Traefik recebe** na porta 443 e:
   - Identifica: Host=`office.inoveon.com.br`, Path=`/suporte/login`
   - Aplica certificado SSL
   - Encontra router: `suporte-portal`
   - Encaminha para: `http://10.0.20.11:3001/suporte/login`

4. **React detecta** no `index.html`:
   - Path começa com `/suporte`
   - Define: `window.__APP_BASE_PATH__ = '/suporte'`
   - Cria: `<base href="/suporte/">`

5. **React Router** usa `basename='/suporte'`:
   - Rota `/login` vira `/suporte/login`
   - Links funcionam corretamente

6. **Frontend faz chamada API**:
   ```javascript
   api.post('/auth/login', {...})
   ```

7. **Axios envia para**: `https://office.inoveon.com.br/api/suporte/auth/login`

8. **Traefik recebe** e:
   - Identifica: router `suporte-api`
   - Aplica middleware: Remove `/api/suporte`
   - Aplica middleware: Adiciona `/api`
   - Encaminha para: `http://10.0.20.11:8003/api/auth/login`

9. **FastAPI recebe**: `/api/auth/login` (path esperado!)

10. **Resposta volta** pelo mesmo caminho com CORS correto

---

## 📚 Conceitos Importantes

### Por que stripprefix + addprefix?

Suas APIs já respondem em `/api/...`, então:
- URL externa: `/api/suporte/auth`
- Traefik remove: `/api/suporte` → sobra `/auth`
- Traefik adiciona: `/api` → fica `/api/auth` ✅
- API recebe: `/api/auth` (como esperado!)

### Por que basename dinâmico no React?

O mesmo build precisa funcionar em:
- Desenvolvimento: `http://ip:porta/` (basename='')
- Produção: `https://dominio/suporte/` (basename='/suporte')

A detecção automática resolve isso!

### Por que ForwardedHeaderFilter no Spring?

O Spring precisa saber:
- Qual o protocolo original (HTTP/HTTPS)
- Qual o host original
- Qual o IP do cliente real

Isso é essencial para gerar URLs corretas e logs apropriados.

---

## 🎯 Próximos Passos

Após implementação básica:

1. **Segurança**:
   - Proteger dashboard do Traefik com autenticação
   - Implementar rate limiting
   - Adicionar WAF (Web Application Firewall)

2. **Monitoramento**:
   - Configurar Prometheus + Grafana
   - Alertas de disponibilidade
   - Logs centralizados

3. **Alta Disponibilidade**:
   - Load balancing entre múltiplas instâncias
   - Health checks automáticos
   - Failover automático
