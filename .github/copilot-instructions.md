# Instrucciones de Contexto — Proyecto de Grado: FinanzApp

## Identidad del proyecto

Estoy desarrollando **FinanzApp**, un sistema de finanzas personales inteligente como proyecto de grado, cuyo objetivo es permitir al usuario gestionar ingresos, gastos, ahorros y metas financieras mediante lenguaje natural, con integración a WhatsApp vía N8N y un agente de IA basado en el protocolo MCP.

---

## Directorio de trabajo

```
C:\Users\esteb\dev\proyecto-grado\
```

## Documentos de referencia disponibles en el directorio

Antes de responder preguntas sobre el proyecto, busca información en estos archivos:

| Archivo | Contenido |
|---------|-----------|
| `README.md` | Documentación completa del monorepo: arquitectura, stack, endpoints, variables de entorno, instrucciones Docker |
| `Requerimientos técnicos.txt` | Requisitos funcionales del sistema: dominio, reglas de negocio, módulos (ingresos, gastos, ahorros, metas, balance) |
| `mcp.txt` | Definición del agente MCP: identidad, reglas de comportamiento, intenciones financieras soportadas, funciones disponibles |
| `docker-compose.yml` | Orquestación de los tres servicios: PostgreSQL, finanzapp-api, finanzapp-mcp |
| `.env.example` | Plantilla de todas las variables de entorno del sistema |
| `finanzapp/README.md` | Documentación detallada del backend Spring Boot: servicios, modelos, endpoints, seguridad JWT |
| `finanzapp-mcp/README.md` | Documentación del servidor MCP: herramientas disponibles, configuración, integración con Claude Desktop |
| `finanzapp/docker/README.md` | Comandos Docker para el backend de forma aislada |
| `FDC-124 Desarrollo de un agente inteligente para finanzas personales con integración de WhatsApp, protocolo MCP y n8n.pdf` | Documento formal del proyecto de grado |

---

## Arquitectura general

```
WhatsApp (usuario)
    │
    ▼
  N8N (orquestación)
    │
    ▼
Claude / LLM ──► finanzapp-mcp (Node.js, TypeScript, MCP stdio)
                        │
                        │ axios / REST + JWT
                        ▼
              finanzapp-api (Spring Boot :8080)
                        │
                        │ JPA / Hibernate
                        ▼
                 PostgreSQL :5432
```

---

## Stack tecnológico

| Componente | Tecnología |
|-----------|-----------|
| Backend API | Java 21, Spring Boot 3, Spring Security, Spring Data JPA, Hibernate |
| Base de datos | PostgreSQL 16 |
| Seguridad | JWT (Bearer token), Spring Security 6 |
| Servidor MCP | Node.js 20, TypeScript 5, `@modelcontextprotocol/sdk`, axios, zod |
| Orquestación WhatsApp | N8N |
| Contenedores | Docker, Docker Compose v3.8 |
| Tests backend | spring-boot-starter-test, Maven (`./mvnw test`) |
| Tests MCP | vitest (`npm run test`) |
| Documentación API | SpringDoc / Swagger UI (`http://localhost:8080/swagger-ui.html`) |

---

## Estructura del repositorio

```
proyecto-grado/
├── docker-compose.yml          ← Stack completo (postgres + api + mcp)
├── .env.example                ← Variables de entorno (copiar a .env)
├── README.md
├── Requerimientos técnicos.txt
├── mcp.txt
│
├── finanzapp/                  ← Backend Spring Boot (arquitectura hexagonal)
│   ├── src/main/java/com/finanzapp/
│   │   ├── application/service/   ← Casos de uso (AuthService, IngresoService, etc.)
│   │   ├── domain/model/          ← Entidades de dominio
│   │   ├── domain/port/           ← Interfaces (puertos in/out)
│   │   └── infrastructure/        ← Controladores REST, repos JPA, JWT, seguridad
│   └── docker/
│
└── finanzapp-mcp/              ← Servidor MCP (TypeScript)
    └── src/
        ├── index.ts            ← Registro de herramientas MCP
        ├── api-client.ts       ← Cliente HTTP hacia finanzapp-api
        └── config.ts           ← Variables de entorno
```

---

## Dominio de negocio

### Módulos principales

- **Ingresos**: registro con categorías (`TRABAJO_PRINCIPAL`, `TRABAJO_EXTRA`, `GANANCIAS_ADICIONALES`, `INVERSIONES`, `OTROS`), soporte de monto parcial destinado a ahorro.
- **Gastos**: registro con categorías (`COMIDA`, `PAREJA`, `COMPRAS`, `TRANSPORTE`, `SERVICIOS`, `ENTRETENIMIENTO`, `SALUD`, `EDUCACION`, `OTROS`), desglose por categoría.
- **Ahorros**: pueden asociarse a una meta financiera o ser independientes. No se consideran dinero disponible.
- **Metas financieras**: con monto objetivo, progreso calculado automáticamente desde los ahorros asociados, estados `ACTIVA`, `COMPLETADA`, `CANCELADA`.
- **Balance**: calculado como `ingresos − gastos − ahorros`, disponible general o por período.
- **Dispositivos WhatsApp**: autenticación OTP de 6 dígitos, vinculados a un usuario.

### Reglas de negocio clave

- El dinero ahorrado no cuenta como dinero disponible para gastar.
- Si no se indica fecha en un registro, se usa la fecha actual.
- Un ingreso puede tener un `montoAhorro` parcial asociado.
- El balance disponible = ingresos totales − gastos totales − ahorros totales.
- Las metas se marcan `COMPLETADA` automáticamente cuando `montoActual >= montoObjetivo`.

---

## API REST — Base URL

```
http://localhost:8080/api/v1
```

Todos los endpoints requieren `Authorization: Bearer <token>` excepto `/auth/**`.

### Endpoints principales

| Recurso | Rutas |
|---------|-------|
| Auth | `POST /auth/register`, `/auth/login`, `/auth/login/whatsapp`, `/auth/refresh` |
| Ingresos | `POST /ingresos`, `GET /ingresos`, `/ingresos/periodo`, `/ingresos/total` |
| Gastos | `POST /gastos`, `GET /gastos`, `/gastos/periodo`, `/gastos/desglose` |
| Ahorros | `POST /ahorros`, `GET /ahorros`, `/ahorros/meta/{metaId}`, `/ahorros/total` |
| Metas | `POST /metas`, `GET /metas/{id}`, `POST /metas/{id}/progreso`, `PATCH /metas/{id}/estado` |
| Balance | `GET /balance`, `GET /balance/periodo` |
| Dispositivos | `POST /dispositivos`, `POST /dispositivos/verificar` |

---

## Herramientas MCP disponibles

El servidor MCP expone las siguientes herramientas al LLM:

`crearIngreso`, `obtenerIngresos`, `obtenerIngresosPorPeriodo`, `obtenerTotalIngresos`,
`crearEgreso`, `obtenerGastos`, `obtenerGastosPorPeriodo`, `obtenerGastosPorCategoria`, `obtenerTotalGastos`, `obtenerDesgloseGastos`,
`crearAhorro`, `obtenerAhorros`, `crearMeta`, `obtenerMetas`, `registrarProgresoMeta`,
`obtenerBalance`, `obtenerBalancePorPeriodo`, `obtenerResumenFinanciero`, `obtenerAnalisisFinanciero`

---

## Comandos frecuentes

```powershell
# Levantar todo el stack
cd C:\Users\esteb\dev\proyecto-grado
docker compose up -d --build

# Solo backend en desarrollo
cd finanzapp
docker compose -f docker/docker-compose.dev.yml up -d   # solo PostgreSQL
./mvnw spring-boot:run

# Servidor MCP en desarrollo
cd finanzapp-mcp
npm install && npm run build
npm run dev

# Tests
./mvnw test                  # backend
npm run test                 # MCP
```

---

## Variables de entorno clave

Copiar `.env.example` → `.env` en la raíz y ajustar:

| Variable | Descripción |
|----------|-------------|
| `DB_PASSWORD` | Contraseña PostgreSQL |
| `JWT_SECRET` | Clave firma JWT (cambiar en producción) |
| `FINANZAPP_JWT_TOKEN` | Token JWT del usuario para el servidor MCP |
| `FINANZAPP_API_URL` | URL del backend vista desde el MCP |

---

## Comportamiento esperado del agente MCP

El agente IA actúa como **asistente financiero personal** con las siguientes reglas:
- Interpreta mensajes en lenguaje natural desde WhatsApp.
- Extrae intención, monto, categoría y fecha.
- Llama a la función MCP correspondiente.
- **No inventa datos financieros** — siempre consulta al backend.
- Solicita aclaración solo cuando falta información crítica (ej. monto).
- Responde de forma clara, concisa y en tono humano.
