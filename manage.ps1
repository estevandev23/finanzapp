# =============================================================
# manage.ps1 — Gestor interactivo del stack FinanzApp
# =============================================================
# Uso: .\manage.ps1
# Requiere Docker Desktop en ejecucion y el archivo .env en la
# misma carpeta que docker-compose.yml.
# =============================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─── Configuración ───────────────────────────────────────────

$COMPOSE_FILE = "$PSScriptRoot\docker-compose.yml"
$LOG_LINES    = 100   # Líneas de cola por defecto para logs

# Nombres de contenedor tal como aparecen en docker-compose.yml
$SERVICES = @{
    api      = "finanzapp-api"
    web      = "finanzapp-web"
    mcp      = "finanzapp-mcp"
    n8n      = "n8n"
    postgres = "postgres"
}

# ─── Utilidades ──────────────────────────────────────────────

function Write-Header {
    param([string]$Title)
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║         FinanzApp — Stack Manager        ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Cyan
    if ($Title) {
        Write-Host ""
        Write-Host "  >>> $Title" -ForegroundColor Yellow
    }
    Write-Host ""
}

function Write-MenuOption {
    param([string]$Key, [string]$Label)
    Write-Host "  [" -NoNewline -ForegroundColor DarkGray
    Write-Host $Key  -NoNewline -ForegroundColor Green
    Write-Host "] $Label" -ForegroundColor White
}

function Read-MenuChoice {
    param([string[]]$ValidKeys)
    do {
        Write-Host ""
        $choice = Read-Host "  Opcion"
        $choice = $choice.Trim().ToLower()
    } while ($choice -notin $ValidKeys)
    return $choice
}

function Invoke-Compose {
    param([string[]]$Args)
    Write-Host ""
    Write-Host "  Ejecutando: docker compose $($Args -join ' ')" -ForegroundColor DarkGray
    Write-Host ""
    & docker compose -f $COMPOSE_FILE @Args
}

function Pause-Screen {
    Write-Host ""
    Write-Host "  Presiona cualquier tecla para volver al menu..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Get-ContainerStatus {
    param([string]$ServiceName)
    $status = docker compose -f $COMPOSE_FILE ps --format "table {{.Service}}\t{{.Status}}" 2>$null |
              Select-String -Pattern "^$ServiceName"
    if ($status) { return $status.ToString().Trim() }
    return "$ServiceName — no iniciado"
}

function Show-AllStatus {
    Write-Host "  Estado actual de los contenedores:" -ForegroundColor Cyan
    Write-Host ""
    Invoke-Compose @("ps", "--format", "table {{.Service}}\t{{.Status}}\t{{.Ports}}")
}

# ─── Menú: Levantar servicios ─────────────────────────────────

function Show-StartMenu {
    Write-Header "Levantar servicios"
    Show-AllStatus
    Write-Host ""
    Write-MenuOption "1" "Stack completo (todos los servicios)"
    Write-MenuOption "2" "Solo n8n        (incluye postgres + api como dependencias)"
    Write-MenuOption "3" "Solo API        (incluye postgres)"
    Write-MenuOption "4" "Solo Frontend   (incluye postgres + api)"
    Write-MenuOption "5" "Solo MCP        (incluye postgres + api)"
    Write-MenuOption "6" "Solo PostgreSQL (base de datos unicamente)"
    Write-MenuOption "0" "Volver"

    $choice = Read-MenuChoice -ValidKeys @("1","2","3","4","5","6","0")

    switch ($choice) {
        "1" { Invoke-Compose @("up", "-d", "--build") }
        "2" { Invoke-Compose @("up", "-d", $SERVICES.n8n) }
        "3" { Invoke-Compose @("up", "-d", $SERVICES.api) }
        "4" { Invoke-Compose @("up", "-d", $SERVICES.web) }
        "5" { Invoke-Compose @("up", "-d", $SERVICES.mcp) }
        "6" { Invoke-Compose @("up", "-d", $SERVICES.postgres) }
        "0" { return }
    }

    if ($choice -ne "0") { Pause-Screen }
}

# ─── Menú: Ver logs ──────────────────────────────────────────

function Show-LogsMenu {
    Write-Header "Ver logs"
    Write-Host "  Se muestran las ultimas $LOG_LINES lineas en modo seguimiento (-f)." -ForegroundColor DarkGray
    Write-Host "  Presiona Ctrl+C para salir del modo seguimiento." -ForegroundColor DarkGray
    Write-Host ""
    Write-MenuOption "1" "Todos los servicios"
    Write-MenuOption "2" "API            (finanzapp-api)"
    Write-MenuOption "3" "Frontend       (finanzapp-web)"
    Write-MenuOption "4" "MCP            (finanzapp-mcp)"
    Write-MenuOption "5" "n8n"
    Write-MenuOption "6" "PostgreSQL     (finanzapp-db)"
    Write-MenuOption "0" "Volver"

    $choice = Read-MenuChoice -ValidKeys @("1","2","3","4","5","6","0")

    switch ($choice) {
        "1" { Invoke-Compose @("logs", "-f", "--tail=$LOG_LINES") }
        "2" { Invoke-Compose @("logs", "-f", "--tail=$LOG_LINES", $SERVICES.api) }
        "3" { Invoke-Compose @("logs", "-f", "--tail=$LOG_LINES", $SERVICES.web) }
        "4" { Invoke-Compose @("logs", "-f", "--tail=$LOG_LINES", $SERVICES.mcp) }
        "5" { Invoke-Compose @("logs", "-f", "--tail=$LOG_LINES", $SERVICES.n8n) }
        "6" { Invoke-Compose @("logs", "-f", "--tail=$LOG_LINES", $SERVICES.postgres) }
        "0" { return }
    }
}

# ─── Menú: Detener servicios ─────────────────────────────────

function Show-StopMenu {
    Write-Header "Detener servicios"
    Show-AllStatus
    Write-Host ""
    Write-MenuOption "1" "Detener todo (mantiene volumenes)"
    Write-MenuOption "2" "Detener todo y eliminar volumenes  [CUIDADO: borra datos]"
    Write-MenuOption "3" "Detener solo n8n"
    Write-MenuOption "4" "Detener solo API"
    Write-MenuOption "5" "Detener solo Frontend"
    Write-MenuOption "6" "Detener solo MCP"
    Write-MenuOption "7" "Detener solo PostgreSQL"
    Write-MenuOption "0" "Volver"

    $choice = Read-MenuChoice -ValidKeys @("1","2","3","4","5","6","7","0")

    switch ($choice) {
        "1" { Invoke-Compose @("down") }
        "2" {
            Write-Host ""
            Write-Host "  ADVERTENCIA: esto eliminara todos los datos persistidos." -ForegroundColor Red
            $confirm = Read-Host "  Escribe 'si' para confirmar"
            if ($confirm.ToLower() -eq "si") {
                Invoke-Compose @("down", "-v")
            } else {
                Write-Host "  Operacion cancelada." -ForegroundColor Yellow
            }
        }
        "3" { Invoke-Compose @("stop", $SERVICES.n8n) }
        "4" { Invoke-Compose @("stop", $SERVICES.api) }
        "5" { Invoke-Compose @("stop", $SERVICES.web) }
        "6" { Invoke-Compose @("stop", $SERVICES.mcp) }
        "7" { Invoke-Compose @("stop", $SERVICES.postgres) }
        "0" { return }
    }

    if ($choice -ne "0") { Pause-Screen }
}

# ─── Menú: Consumo de recursos ───────────────────────────────

function Show-StatsMenu {
    Write-Header "Consumo de recursos"
    Write-Host "  Muestra CPU, memoria, red y disco en tiempo real." -ForegroundColor DarkGray
    Write-Host "  Presiona Ctrl+C para salir." -ForegroundColor DarkGray
    Write-Host ""
    Write-MenuOption "1" "Todos los contenedores"
    Write-MenuOption "2" "Solo API            (finanzapp-api)"
    Write-MenuOption "3" "Solo Frontend       (finanzapp-web)"
    Write-MenuOption "4" "Solo MCP            (finanzapp-mcp)"
    Write-MenuOption "5" "Solo n8n"
    Write-MenuOption "6" "Solo PostgreSQL     (finanzapp-db)"
    Write-MenuOption "7" "Snapshot puntual    (sin modo streaming)"
    Write-MenuOption "0" "Volver"

    $choice = Read-MenuChoice -ValidKeys @("1","2","3","4","5","6","7","0")

    # Mapeo de servicio a nombre de contenedor (container_name en compose)
    $containerNames = @{
        api      = "finanzapp-api"
        web      = "finanzapp-web"
        mcp      = "finanzapp-mcp"
        n8n      = "finanzapp-n8n"
        postgres = "finanzapp-db"
    }

    switch ($choice) {
        "1" { docker stats }
        "2" { docker stats $containerNames.api }
        "3" { docker stats $containerNames.web }
        "4" { docker stats $containerNames.mcp }
        "5" { docker stats $containerNames.n8n }
        "6" { docker stats $containerNames.postgres }
        "7" {
            Write-Host ""
            Write-Host "  Snapshot de consumo actual:" -ForegroundColor Cyan
            Write-Host ""
            docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
            Pause-Screen
        }
        "0" { return }
    }
}

# ─── Menú: Utilidades extras ─────────────────────────────────

function Show-UtilsMenu {
    Write-Header "Utilidades"
    Write-MenuOption "1" "Reconstruir imagenes sin cache"
    Write-MenuOption "2" "Ver estado detallado de contenedores"
    Write-MenuOption "3" "Ver puertos expuestos"
    Write-MenuOption "4" "Ver redes Docker del stack"
    Write-MenuOption "5" "Acceder a shell de PostgreSQL (psql)"
    Write-MenuOption "6" "Ver variables de entorno del .env"
    Write-MenuOption "0" "Volver"

    $choice = Read-MenuChoice -ValidKeys @("1","2","3","4","5","6","0")

    switch ($choice) {
        "1" { Invoke-Compose @("build", "--no-cache") ; Pause-Screen }
        "2" { Invoke-Compose @("ps", "-a") ; Pause-Screen }
        "3" {
            Write-Host ""
            docker compose -f $COMPOSE_FILE ps --format "table {{.Service}}\t{{.Ports}}"
            Pause-Screen
        }
        "4" {
            Write-Host ""
            docker network inspect finanzapp_finanzapp-network 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  La red no existe aun. Levanta el stack primero." -ForegroundColor Yellow
            }
            Pause-Screen
        }
        "5" {
            Write-Host ""
            Write-Host "  Conectando a PostgreSQL dentro del contenedor..." -ForegroundColor Cyan
            Write-Host "  Escribe \q para salir de psql." -ForegroundColor DarkGray
            Write-Host ""
            docker exec -it finanzapp-db psql -U postgres -d finanzapp
        }
        "6" {
            $envFile = "$PSScriptRoot\.env"
            if (Test-Path $envFile) {
                Write-Host ""
                Write-Host "  Contenido de .env (ocultando valores de contraseñas):" -ForegroundColor Cyan
                Write-Host ""
                Get-Content $envFile | ForEach-Object {
                    if ($_ -match "^(.*PASSWORD|.*SECRET|.*TOKEN|.*KEY)=(.+)$") {
                        Write-Host "  $($Matches[1])=****" -ForegroundColor DarkGray
                    } else {
                        Write-Host "  $_" -ForegroundColor White
                    }
                }
            } else {
                Write-Host "  Archivo .env no encontrado. Copia .env.example a .env primero." -ForegroundColor Red
            }
            Pause-Screen
        }
        "0" { return }
    }
}

# ─── Menú principal ──────────────────────────────────────────

function Show-MainMenu {
    Write-Header ""

    $envFile = "$PSScriptRoot\.env"
    if (-not (Test-Path $envFile)) {
        Write-Host "  AVISO: No se encontro el archivo .env" -ForegroundColor Red
        Write-Host "  Ejecuta: cp .env.example .env  y configura las variables." -ForegroundColor Yellow
        Write-Host ""
    }

    Write-MenuOption "1" "Levantar servicios"
    Write-MenuOption "2" "Ver logs"
    Write-MenuOption "3" "Detener servicios"
    Write-MenuOption "4" "Consumo de recursos"
    Write-MenuOption "5" "Utilidades"
    Write-MenuOption "0" "Salir"

    $choice = Read-MenuChoice -ValidKeys @("1","2","3","4","5","0")

    switch ($choice) {
        "1" { Show-StartMenu }
        "2" { Show-LogsMenu }
        "3" { Show-StopMenu }
        "4" { Show-StatsMenu }
        "5" { Show-UtilsMenu }
        "0" {
            Write-Host ""
            Write-Host "  Hasta luego." -ForegroundColor Cyan
            Write-Host ""
            exit 0
        }
    }
}

# ─── Validación de prerequisitos ─────────────────────────────

function Assert-Prerequisites {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host "Error: Docker no esta instalado o no esta en el PATH." -ForegroundColor Red
        exit 1
    }

    $dockerRunning = docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Docker Desktop no esta en ejecucion. Inicialo primero." -ForegroundColor Red
        exit 1
    }

    if (-not (Test-Path $COMPOSE_FILE)) {
        Write-Host "Error: No se encontro docker-compose.yml en $PSScriptRoot" -ForegroundColor Red
        exit 1
    }
}

# ─── Entry point ─────────────────────────────────────────────

Assert-Prerequisites

while ($true) {
    Show-MainMenu
}
