# 💰 FinanzApp — Monorepo

Plataforma de gestión financiera personal compuesta por dos aplicaciones:

| Proyecto | Ruta | Descripción |
|----------|------|-------------|
| **finanzapp** | `./finanzapp/` | API REST (Java 21 · Spring Boot 3) |
| **finanzapp-mcp** | `./finanzapp-mcp/` | Servidor MCP (Node 20 · TypeScript) |

El `docker-compose.yml` de esta carpeta levanta ambas aplicaciones junto con la base de datos PostgreSQL con un único comando.

---

## 📋 Tabla de contenido

- [Visión general](#visión-general)
- [Stack tecnológico](#stack-tecnológico)
- [Requisitos previos](#requisitos-previos)
- [Estructura del repositorio](#estructura-del-repositorio)
- [Levantamiento con Docker Compose](#levantamiento-con-docker-compose)
- [finanzapp — Backend](#finanzapp--backend)
- [finanzapp-mcp — Servidor MCP](#finanzapp-mcp--servidor-mcp)
- [Base de datos](#base-de-datos)
- [Seguridad y JWT](#seguridad-y-jwt)
- [Ejecutar en desarrollo (sin Docker)](#ejecutar-en-desarrollo-sin-docker)
- [Tests](#tests)
- [Variables de entorno](#variables-de-entorno)
- [Contribuir](#contribuir)

---

## Visión general

FinanzApp permite a los usuarios registrar y consultar ingresos, gastos, ahorros y metas financieras a través de una API REST segura. Además expone un **servidor MCP** para que asistentes conversacionales como **Claude** puedan gestionar las finanzas del usuario mediante lenguaje natural, sin que el usuario tenga que escribir peticiones HTTP manualmente.

```
 ┌───────────────────┐   JWT / REST    ┌─────────────────────────┐
 │   Cliente HTTP    │ ──────────────► │    finanzapp-api        │
 │  (curl, Postman,  │                 │   Spring Boot :8080     │◄──┐
 │   frontend, etc.) │                 └────────────┬────────────┘   │
 └───────────────────┘                              │ JPA            │
                                                    ▼                │
 ┌───────────────────┐   JSON-RPC      ┌────────────────────────┐   │
 │  Claude / LLM     │ ──────────────► │   finanzapp-mcp        │───┘
 │  (MCP Client)     │  (stdio/MCP)    │   Node.js :stdio       │ axios/REST
 └───────────────────┘                 └────────────────────────┘
                                                    │
                                       ┌────────────▼────────────┐
                                       │      PostgreSQL :5432    │
                                       └─────────────────────────┘
```

---

## Stack tecnológico

| Capa | Tecnología |
|------|-----------|
| Backend | Java 21, Spring Boot 3, Spring Security, Spring Data JPA |
| ORM | Hibernate (PostgreSQL dialect) |
| Seguridad | JWT (Bearer token) |
| Base de datos | PostgreSQL 16 |
| MCP Server | Node.js 20, TypeScript 5, `@modelcontextprotocol/sdk`, axios, zod |
| Tests backend | spring-boot-starter-test |
| Tests MCP | vitest |
| Contenedores | Docker, Docker Compose v3.8 |
| Build Java | Maven Wrapper (`mvnw`) |

---

## Requisitos previos

Para **Docker** (recomendado):
- Docker ≥ 24 y Docker Compose plugin

Para **desarrollo local** (sin Docker):
- JDK 21
- Maven 3.9+ (o usar `./mvnw`)
- Node.js 20 + npm 10
- PostgreSQL 16 accesible en `localhost:5432`

---

## Estructura del repositorio

```
proyecto-grado/
├── docker-compose.yml          ← Compose unificado (postgres + api + mcp)
├── .env.example                ← Plantilla de variables de entorno
├── README.md                   ← Este archivo
│
├── finanzapp/                  ← Backend Spring Boot
│   ├── Dockerfile
│   ├── pom.xml
│   ├── mvnw / mvnw.cmd
│   ├── docker/
│   │   ├── docker-compose.yml       (compose solo del backend)
│   │   ├── docker-compose.dev.yml   (compose solo con postgres para dev)
│   │   └── init-db/01-init.sql
│   └── src/
│       ├── main/java/com/finanzapp/
│       │   ├── FinanzappApplication.java
│       │   ├── application/service/   ← Servicios / casos de uso
│       │   ├── domain/
│       │   │   ├── model/             ← Entidades de dominio
│       │   │   ├── port/              ← Interfaces (puertos in/out)
│       │   │   └── exception/
│       │   └── infrastructure/
│       │       ├── adapter/           ← Controladores REST + repos JPA
│       │       ├── config/
│       │       └── security/          ← JwtService, filtros
│       └── main/resources/application.yml
│
└── finanzapp-mcp/              ← Servidor MCP (TypeScript)
    ├── Dockerfile
    ├── package.json
    ├── tsconfig.json
    ├── .env.example
    └── src/
        ├── index.ts            ← Servidor MCP + definición de herramientas
        ├── api-client.ts       ← Cliente HTTP hacia finanzapp-api
        └── config.ts           ← Carga de variables de entorno
```

---

## Levantamiento con Docker Compose

### 1. Preparar variables de entorno

```powershell
# Desde C:\Users\esteb\dev\proyecto-grado\
Copy-Item .env.example .env
# Editar .env y ajustar DB_PASSWORD, JWT_SECRET y FINANZAPP_JWT_TOKEN
notepad .env
```

### 2. Construir y levantar todo el stack

```powershell
docker compose up -d --build
```

Esto construye las imágenes del backend y del MCP, y levanta los tres servicios:

| Contenedor | Imagen | Puerto host |
|------------|--------|-------------|
| `finanzapp-db` | postgres:16-alpine | 5432 |
| `finanzapp-api` | build desde `./finanzapp` | 8080 |
| `finanzapp-mcp` | build desde `./finanzapp-mcp` | — (stdio) |

### 3. Verificar que todo está saludable

```powershell
docker compose ps
docker compose logs -f finanzapp-api   # ver logs del backend
```

### 4. Comandos útiles

```powershell
# Detener sin borrar datos
docker compose stop

# Detener y borrar contenedores (datos persisten en el volumen)
docker compose down

# Borrar también los volúmenes (¡se pierden los datos!)
docker compose down -v

# Reconstruir sólo un servicio
docker compose up -d --build finanzapp-api
```

---

## finanzapp — Backend

### Descripción

API REST que sigue la **arquitectura hexagonal** (puertos y adaptadores). La lógica de negocio vive en `application/service`, los modelos en `domain/model` y los detalles de infraestructura (JPA, JWT, controllers) en `infrastructure/`.

### Servicios (casos de uso)

| Clase | Responsabilidad |
|-------|----------------|
| `AuthService` | Login email/password, login por WhatsApp (OTP), registro, refreshToken |
| `UsuarioService` | CRUD de usuarios, cambio de contraseña, baja lógica (`activo=false`) |
| `IngresoService` | Registro y consulta de ingresos; soporta monto reservado para ahorro |
| `GastoService` | Registro y consulta de gastos con desglose y totales por categoría |
| `AhorroService` | Registro de ahorros opcionalmente asociados a una meta financiera |
| `MetaFinancieraService` | Creación y seguimiento de metas (monto actual calculado desde ahorros) |
| `BalanceService` | Cálculo de balance general o por período: ingresos − gastos − ahorros |
| `DispositivoService` | Registro, verificación y gestión de dispositivos WhatsApp (OTP 6 dígitos) |

### Modelos de dominio

| Modelo | Campos clave |
|--------|-------------|
| `Usuario` | id, nombre, email, password, telefono, activo |
| `Ingreso` | id, usuarioId, monto, categoriaIngreso, descripcion, fecha, montoAhorro |
| `Gasto` | id, usuarioId, monto, categoriaGasto, descripcion, fecha |
| `Ahorro` | id, usuarioId, ingresoId, metaId, monto, descripcion, fecha |
| `MetaFinanciera` | id, usuarioId, nombre, montoObjetivo, montoActual, fechaLimite, estado |
| `Balance` | totalIngresos, totalGastos, totalAhorros, dineroDisponible |
| `Dispositivo` | id, usuarioId, numeroWhatsapp, verificado, codigoVerificacion, tokenDispositivo |

**Enums:**
- `CategoriaIngreso`: `TRABAJO_PRINCIPAL`, `TRABAJO_EXTRA`, `GANANCIAS_ADICIONALES`, `INVERSIONES`, `OTROS`
- `CategoriaGasto`: `COMIDA`, `PAREJA`, `COMPRAS`, `TRANSPORTE`, `SERVICIOS`, `ENTRETENIMIENTO`, `SALUD`, `EDUCACION`, `OTROS`
- `EstadoMeta`: `ACTIVA`, `COMPLETADA`, `CANCELADA`

### Endpoints principales

> Base URL: `http://localhost:8080/api/v1`
> Todas las rutas excepto `/auth/**` requieren `Authorization: Bearer <token>`.

#### Autenticación

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/auth/register` | Registrar nuevo usuario |
| POST | `/auth/login` | Login con email y password → JWT |
| POST | `/auth/login/whatsapp` | Login con número WhatsApp + código OTP |
| POST | `/auth/refresh` | Renovar token JWT |

#### Ingresos

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/ingresos` | Registrar ingreso |
| GET | `/ingresos` | Listar todos los ingresos del usuario |
| GET | `/ingresos/periodo?fechaInicio=&fechaFin=` | Ingresos por período |
| GET | `/ingresos/categoria/{categoria}` | Ingresos por categoría |
| GET | `/ingresos/total` | Total de ingresos |
| GET | `/ingresos/total/periodo?fechaInicio=&fechaFin=` | Total por período |

#### Gastos

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/gastos` | Registrar gasto |
| GET | `/gastos` | Listar todos los gastos |
| GET | `/gastos/periodo?fechaInicio=&fechaFin=` | Gastos por período |
| GET | `/gastos/categoria/{categoria}` | Gastos por categoría |
| GET | `/gastos/total` | Total de gastos |
| GET | `/gastos/desglose` | Desglose por categoría |
| GET | `/gastos/desglose/periodo?fechaInicio=&fechaFin=` | Desglose por período |

#### Ahorros

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/ahorros` | Registrar ahorro |
| GET | `/ahorros` | Listar ahorros |
| GET | `/ahorros/periodo?fechaInicio=&fechaFin=` | Ahorros por período |
| GET | `/ahorros/meta/{metaId}` | Ahorros de una meta |
| GET | `/ahorros/total` | Total de ahorros |

#### Metas financieras

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/metas` | Crear meta |
| GET | `/metas` | Listar metas del usuario |
| GET | `/metas/{id}` | Detalle de una meta (con % avance) |
| PUT | `/metas/{id}` | Actualizar meta |
| POST | `/metas/{id}/progreso` | Registrar abono hacia la meta |
| PATCH | `/metas/{id}/estado` | Cambiar estado de la meta |
| DELETE | `/metas/{id}` | Eliminar meta |

#### Balance

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/balance` | Balance general |
| GET | `/balance/periodo?fechaInicio=&fechaFin=` | Balance por período |

#### Dispositivos (WhatsApp OTP)

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/dispositivos` | Registrar dispositivo y generar OTP |
| POST | `/dispositivos/verificar` | Verificar OTP y activar dispositivo |
| GET | `/dispositivos` | Listar dispositivos del usuario |
| DELETE | `/dispositivos/{id}` | Eliminar dispositivo |

### Ejemplo rápido

```bash
# 1. Registrar usuario
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"nombre":"Juan","email":"juan@ejemplo.com","password":"secreta123"}'

# 2. Login → obtener JWT
TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"juan@ejemplo.com","password":"secreta123"}' | \
  python -c "import sys,json; print(json.load(sys.stdin)['data']['token'])")

# 3. Consultar balance
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/v1/balance
```

---

## finanzapp-mcp — Servidor MCP

### Descripción

Implementa el **Model Context Protocol (MCP)** sobre transporte `stdio`. Permite que Claude (o cualquier cliente MCP) registre ingresos, consulte gastos, gestione metas y obtenga análisis financieros mediante lenguaje natural.

Flujo de comunicación:
1. El LLM invoca el proceso `node dist/index.js` (o el contenedor).
2. El servidor escucha peticiones JSON-RPC en `stdin` y responde en `stdout`.
3. Internamente llama al backend REST con axios usando el JWT configurado.

### Herramientas disponibles

| Herramienta | Parámetros requeridos | Descripción |
|-------------|----------------------|-------------|
| `crearIngreso` | `monto` | Registrar ingreso (+ categoría, descripción, fecha opcionales) |
| `obtenerIngresos` | — | Listar todos los ingresos |
| `obtenerIngresosPorPeriodo` | `fechaInicio`, `fechaFin` | Ingresos en un rango de fechas |
| `obtenerTotalIngresos` | — | Suma total de ingresos |
| `crearEgreso` | `monto` | Registrar gasto (+ categoría, descripción, fecha opcionales) |
| `obtenerGastos` | — | Listar todos los gastos |
| `obtenerGastosPorPeriodo` | `fechaInicio`, `fechaFin` | Gastos en un rango de fechas |
| `obtenerGastosPorCategoria` | `categoria` | Gastos de una categoría concreta |
| `obtenerTotalGastos` | — | Suma total de gastos |
| `obtenerDesgloseGastos` | — | Total por cada categoría de gasto |
| `crearAhorro` | `monto` | Registrar ahorro (+ metaId opcional) |
| `obtenerAhorros` | — | Listar todos los ahorros |
| `crearMeta` | `nombre`, `montoObjetivo` | Crear meta financiera |
| `obtenerMetas` | — | Listar metas activas |
| `registrarProgresoMeta` | `metaId`, `monto` | Abonar a una meta |
| `obtenerBalance` | — | Balance general (ingresos − gastos − ahorros) |
| `obtenerBalancePorPeriodo` | `fechaInicio`, `fechaFin` | Balance en un período |
| `obtenerResumenFinanciero` | — | Resumen completo del estado financiero |
| `obtenerAnalisisFinanciero` | — | Análisis con tendencias y recomendaciones |

### Arquitectura interna

```
src/
├── index.ts        ← Instancia Server MCP, registra ListTools y CallTool,
│                     define herramientas con inputSchema (JSON Schema)
│                     y valida parámetros con zod antes de llamar a apiClient.
├── api-client.ts   ← Clase FinanzAppApiClient (axios) con métodos por recurso.
│                     Inyecta el JWT en cada petición mediante un interceptor.
└── config.ts       ← Lee FINANZAPP_API_URL, FINANZAPP_JWT_TOKEN, etc. desde env.
```

### Configurar el MCP en Claude Desktop

Añade en `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "finanzapp": {
      "command": "docker",
      "args": ["exec", "-i", "finanzapp-mcp", "node", "dist/index.js"],
      "env": {
        "FINANZAPP_API_URL": "http://finanzapp-api:8080/api/v1",
        "FINANZAPP_JWT_TOKEN": "<tu-token-jwt>"
      }
    }
  }
}
```

O en desarrollo local (sin Docker):

```json
{
  "mcpServers": {
    "finanzapp": {
      "command": "node",
      "args": ["C:/Users/esteb/dev/proyecto-grado/finanzapp-mcp/dist/index.js"],
      "env": {
        "FINANZAPP_API_URL": "http://localhost:8080/api/v1",
        "FINANZAPP_JWT_TOKEN": "<tu-token-jwt>"
      }
    }
  }
}
```

---

## Base de datos

- Motor: **PostgreSQL 16**
- Nombre de la BD: `finanzapp`
- Esquema: `public`
- Script de init (`docker/init-db/01-init.sql`): habilita la extensión `uuid-ossp` para generación de UUIDs en la base de datos.
- Las tablas las crea Hibernate automáticamente al arrancar el backend (`ddl-auto: update`).

---

## Seguridad y JWT

- El backend emite un JWT firmado con la clave `JWT_SECRET` al hacer login.
- Expiración por defecto: **24 horas** (configurable con `JWT_EXPIRATION` en ms).
- Todos los endpoints REST (excepto `/auth/**`) requieren el header:
  ```
  Authorization: Bearer <token>
  ```
- El servidor MCP extrae el token del env `FINANZAPP_JWT_TOKEN` y lo adjunta automáticamente en cada llamada al backend.

---

## Ejecutar en desarrollo (sin Docker)

### Backend

```powershell
cd finanzapp

# Levantar sólo la base de datos con Docker
docker compose -f docker/docker-compose.dev.yml up -d

# Ejecutar el backend localmente
./mvnw spring-boot:run
# La API queda en http://localhost:8080
# Swagger UI: http://localhost:8080/swagger-ui.html
```

### MCP Server

```powershell
cd finanzapp-mcp

# Instalar dependencias
npm install

# Copiar y editar variables de entorno
Copy-Item .env.example .env
notepad .env   # ajustar FINANZAPP_API_URL y FINANZAPP_JWT_TOKEN

# Compilar TypeScript
npm run build

# Modo desarrollo (sin compilar, usa tsx)
npm run dev
```

---

## Tests

### Backend

```powershell
cd finanzapp
./mvnw test
```

### MCP Server

```powershell
cd finanzapp-mcp
npm run test        # ejecución única con vitest
npm run test:watch  # modo watch
```

---

## Variables de entorno

Copia `.env.example` → `.env` en la raíz (`proyecto-grado/`) y ajusta los valores:

| Variable | Defecto | Descripción |
|----------|---------|-------------|
| `DB_USERNAME` | `postgres` | Usuario de PostgreSQL |
| `DB_PASSWORD` | `postgres` | Contraseña de PostgreSQL |
| `DB_PORT` | `5432` | Puerto expuesto de la BD |
| `API_PORT` | `8080` | Puerto expuesto del backend |
| `JWT_SECRET` | *(predeterminado largo)* | Clave firma JWT — **cambiar en producción** |
| `JWT_EXPIRATION` | `86400000` | Expiración token en ms (24 h) |
| `JWT_REFRESH_EXPIRATION` | `604800000` | Expiración refresh en ms (7 d) |
| `JPA_DDL_AUTO` | `update` | Estrategia DDL de Hibernate |
| `LOG_LEVEL` | `INFO` | Nivel de log del backend |
| `JAVA_OPTS` | `-Xms256m -Xmx512m` | Opciones JVM |
| `FINANZAPP_API_URL` | `http://finanzapp-api:8080/api/v1` | URL base del backend (vista desde el MCP) |
| `FINANZAPP_JWT_TOKEN` | *(vacío)* | Token JWT del usuario para el MCP |
| `FINANZAPP_WHATSAPP_NUMBER` | *(vacío)* | Número WhatsApp (opcional) |
| `FINANZAPP_TIMEOUT` | `30000` | Timeout peticiones MCP → backend (ms) |

---

## Contribuir

1. Crea una rama desde `main`: `git checkout -b feature/mi-mejora`
2. Realiza tus cambios y añade tests.
3. Ejecuta `./mvnw test` y `cd finanzapp-mcp && npm run test` — deben pasar en verde.
4. Abre un Pull Request describiendo el cambio.

---

## Licencia

MIT — ver `finanzapp-mcp/package.json`.

