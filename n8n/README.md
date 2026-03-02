# N8N — Integración WhatsApp + Agente IA para FinanzApp (Evolution API)

Este directorio contiene los flujos de trabajo de N8N que implementan el agente inteligente de finanzas personales vía WhatsApp, usando **Evolution API** como proveedor de WhatsApp, **Claude (Anthropic)** como modelo de lenguaje y el backend de FinanzApp como fuente de datos.

## Arquitectura del flujo

```
WhatsApp (usuario)
      |
      | mensaje de texto
      v
Evolution API (tu contenedor Docker existente)
      |
      | webhook HTTP POST (evento: messages.upsert)
      v
N8N — Extrae numero y texto del payload
      |
      v
Agente Financiero (Claude 3.5 Sonnet via Anthropic)
      |
      |--- Tool: consultarBalance    ---> GET  /api/v1/whatsapp/balance
      |--- Tool: consultarResumenMes ---> GET  /api/v1/whatsapp/resumen-mes
      |--- Tool: registrarIngreso    ---> POST /api/v1/whatsapp/ingreso
      |--- Tool: registrarGasto      ---> POST /api/v1/whatsapp/gasto
      |--- Tool: registrarAhorro     ---> POST /api/v1/whatsapp/ahorro
      |--- Tool: consultarMetas      ---> GET  /api/v1/whatsapp/metas
      |
      | respuesta generada por Claude
      v
Evolution API — Envia respuesta al usuario
      |
      v
WhatsApp (usuario recibe la respuesta)
```

---

## Requisitos previos

1. **Evolution API** corriendo en Docker (ya lo tienes)
2. **Clave de API de Anthropic** para usar Claude
3. **Docker y Docker Compose** instalados
4. **ngrok** (solo para desarrollo local) para exponer el webhook de N8N al internet

---

## Paso 1 — Conectar N8N con tu Evolution API

Evolution API corre en su propio Docker. Para que N8N pueda llamar a Evolution API debes saber la URL correcta.

### Caso A: Evolution API en docker-compose separado (lo mas comun)

Desde la maquina donde corre N8N, Evolution API es accesible por:

| Sistema | URL a usar en EVOLUTION_API_URL |
|---|---|
| Docker Desktop (Windows/Mac) | `http://host.docker.internal:PUERTO` |
| Linux (misma maquina) | `http://172.17.0.1:PUERTO` o IP del host |
| Servidores en red local | `http://IP_DEL_SERVIDOR:PUERTO` |

Averigua el puerto de Evolution API:
```bash
docker ps | grep evolution
```

### Caso B: Agregar Evolution API a la misma red Docker del proyecto

Si prefieres que compartan red, agrega la red externa en `docker-compose.yml`:

```yaml
# Al final del docker-compose.yml, en la seccion networks:
networks:
  finanzapp-network:
    driver: bridge
  evolution-network:           # nombre de la red de tu Evolution API
    external: true             # indica que ya existe, no la crea

# En el servicio n8n, agrega la red:
  n8n:
    networks:
      - finanzapp-network
      - evolution-network
```

Con esto, `EVOLUTION_API_URL` puede ser `http://NOMBRE_CONTENEDOR_EVOLUTION:8080`.

---

## Paso 2 — Configurar las variables de entorno

```bash
cp .env.example .env
```

Edita el `.env` con tus valores reales:

```env
# N8N
N8N_ENCRYPTION_KEY=genera-con-openssl-rand-hex-32
N8N_WEBHOOK_URL=https://TU-URL-NGROK.ngrok.io

# Evolution API
EVOLUTION_API_URL=http://host.docker.internal:8080   # ajusta segun tu caso
EVOLUTION_API_KEY=tu-api-key-de-evolution
EVOLUTION_INSTANCE_NAME=finanzapp                    # nombre de tu instancia

# Anthropic Claude
ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxxxxxx
```

La `EVOLUTION_API_KEY` y el `EVOLUTION_INSTANCE_NAME` son los que configuraste cuando instalaste Evolution API. Si no recuerdas el API key, lo encuentras en el panel de administracion de Evolution API (generalmente en `http://localhost:8080/manager`).

---

## Paso 3 — Exponer N8N con ngrok (desarrollo local)

Evolution API necesita enviar webhooks a N8N, y para eso N8N debe tener una URL publica.

```bash
ngrok http 5678
# Copia la URL https://abc123.ngrok.io
# Pegala en N8N_WEBHOOK_URL del .env
```

---

## Paso 4 — Levantar el stack

```bash
# Desde la raiz del proyecto
docker compose up -d --build

# Verificar que todo este corriendo
docker compose ps

# Ver logs de N8N
docker compose logs -f n8n
```

Accede a N8N en: **http://localhost:5678**

En el primer inicio, N8N pedira que crees un usuario administrador.

---

## Paso 5 — Importar el workflow

1. En N8N, ve a **Workflows** → boton **+** → **Import from file**
2. Selecciona el archivo `n8n/workflows/finanzapp-whatsapp-agent.json`
3. El workflow se importara con los 14 nodos preconfigurados

---

## Paso 6 — Configurar credencial de Anthropic

1. En N8N, ve a **Settings** → **Credentials** → **Add credential**
2. Busca **Anthropic** y seleccionalo
3. Ingresa tu `ANTHROPIC_API_KEY`
4. Guarda la credencial con el nombre `Anthropic API Key`
5. Abre el nodo **Claude 3.5 Sonnet** en el workflow y selecciona esa credencial

---

## Paso 7 — Configurar variables de entorno en N8N

El nodo **Enviar Respuesta Evolution API** usa `$env.EVOLUTION_API_URL`, `$env.EVOLUTION_API_KEY` y `$env.EVOLUTION_INSTANCE_NAME`. Para que N8N las reconozca:

1. Ve a **Settings** → **Environment Variables**
2. Agrega las tres variables:

| Nombre | Valor |
|---|---|
| `EVOLUTION_API_URL` | `http://host.docker.internal:8080` (o tu URL) |
| `EVOLUTION_API_KEY` | tu API key de Evolution |
| `EVOLUTION_INSTANCE_NAME` | nombre de tu instancia |

Alternativamente, puedes editar el nodo y reemplazar las expresiones `$env.VARIABLE` directamente con los valores fijos.

---

## Paso 8 — Configurar el webhook en Evolution API

### 8.1 Obtener la URL del webhook de N8N

Una vez activo el workflow, la URL del webhook es:

```
POST https://TU-NGROK.ngrok.io/webhook/whatsapp
```

### 8.2 Registrar el webhook en Evolution API

**Opcion A — Por la interfaz web** (Evolution API Manager):
1. Abre `http://localhost:PUERTO/manager`
2. Ve a tu instancia → **Webhooks**
3. Agrega la URL `https://TU-NGROK.ngrok.io/webhook/whatsapp`
4. Activa el evento **messages.upsert**
5. Guarda

**Opcion B — Por API REST**:
```bash
curl -X POST http://localhost:PUERTO/webhook/set/TU_INSTANCIA \
  -H "apikey: TU_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://TU-NGROK.ngrok.io/webhook/whatsapp",
    "webhook_by_events": false,
    "webhook_base64": false,
    "events": ["MESSAGES_UPSERT"]
  }'
```

### 8.3 Activar el workflow en N8N

1. Abre el workflow **FinanzApp - Agente Financiero WhatsApp (Evolution API)**
2. Activa el toggle en la esquina superior derecha
3. N8N comenzara a recibir y procesar los mensajes de WhatsApp

---

## Paso 9 — Registrar el numero en FinanzApp

Para que el agente pueda operar, el numero de WhatsApp conectado en Evolution API debe estar registrado en FinanzApp:

1. El usuario abre la app movil de FinanzApp
2. Durante el registro, ingresa su numero de WhatsApp
3. Completa la verificacion OTP
4. Una vez verificado, puede enviar mensajes al numero conectado en Evolution API

Si el numero no esta registrado, el agente respondera pidiendo que complete el registro en la app.

---

## Paso 10 — Probar la integracion

Desde tu WhatsApp personal, envia un mensaje al numero conectado en Evolution API:

```
"Hola, como van mis finanzas?"
"Gaste 35000 en almuerzo"
"Me pagaron el salario de 3500000"
"Quiero ahorrar 200000"
"Muestrame el resumen del mes"
"Cuanto dinero me queda disponible?"
```

---

## Formato del webhook de Evolution API

Para referencia, asi llega el payload a N8N:

```json
{
  "event": "messages.upsert",
  "instance": "finanzapp",
  "data": {
    "key": {
      "remoteJid": "573001234567@s.whatsapp.net",
      "fromMe": false,
      "id": "ABCDEF123456"
    },
    "pushName": "Nombre del Contacto",
    "message": {
      "conversation": "Texto del mensaje aqui"
    },
    "messageType": "conversation",
    "messageTimestamp": 1234567890
  }
}
```

El Code node **Extraer Datos Mensaje** filtra automaticamente:
- Eventos que no son `messages.upsert` (estados, reacciones, llamadas, etc.)
- Mensajes enviados por nosotros (`fromMe: true`)
- Mensajes de grupos (`@g.us`)
- Mensajes que no son de texto (`imageMessage`, `audioMessage`, `stickerMessage`, etc.)

---

## Estructura de archivos

```
n8n/
└── workflows/
    └── finanzapp-whatsapp-agent.json   # Workflow importable de N8N
```

---

## Solucion de problemas comunes

**N8N no recibe mensajes de Evolution API**
- Verifica que ngrok este corriendo y la URL en el webhook de Evolution API sea correcta
- Verifica que el workflow este activo (toggle encendido en N8N)
- Verifica el webhook configurado: `GET http://localhost:PUERTO/webhook/find/TU_INSTANCIA -H "apikey: TU_KEY"`

**Error de conexion al enviar respuesta (N8N no alcanza Evolution API)**
- Verifica que EVOLUTION_API_URL sea accesible desde dentro del contenedor N8N
- Prueba desde dentro del contenedor: `docker exec finanzapp-n8n wget -qO- http://host.docker.internal:PUERTO`
- En Linux puede ser necesario agregar `--add-host=host.docker.internal:host-gateway` al servicio n8n en docker-compose.yml

**El agente responde "Dispositivo no encontrado"**
- El numero de WhatsApp no esta registrado en FinanzApp
- El usuario debe completar el registro en la app movil

**Claude no responde (error de credenciales)**
- Verifica la credencial de Anthropic en el nodo **Claude 3.5 Sonnet**
- Verifica que ANTHROPIC_API_KEY sea valida en https://console.anthropic.com

**Los mensajes llegan a N8N pero el backend retorna error**
- Verifica que finanzapp-api este corriendo: `docker compose ps`
- Revisa los logs: `docker compose logs -f finanzapp-api`
