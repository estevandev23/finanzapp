#!/usr/bin/env bash
# =============================================================
# manage.sh — Gestor interactivo del stack FinanzApp
# =============================================================
# Uso:
#   chmod +x manage.sh   (solo la primera vez)
#   ./manage.sh
#
# Compatible con: Linux (VPS), macOS, Windows via Git Bash / WSL
# Requiere: Docker con el plugin Compose v2 (docker compose)
# =============================================================

set -euo pipefail

# ─── Trap de errores ─────────────────────────────────────────
# Captura errores para que el usuario pueda verlos antes de que se cierre
trap 'echo ""; echo -e "  \033[0;31mError en linea $LINENO (exit code: $?)\033[0m"; echo ""; read -rp "  Presiona Enter para continuar..." ' ERR

# ─── Configuración ───────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
LOG_LINES=100

# Nombres de servicio (tal como están definidos en docker-compose.yml)
SVC_API="finanzapp-api"
SVC_WEB="finanzapp-web"
SVC_MCP="finanzapp-mcp"
SVC_N8N="n8n"
SVC_DB="postgres"

# Nombres de contenedor (container_name en docker-compose.yml)
CTR_API="finanzapp-api"
CTR_WEB="finanzapp-web"
CTR_MCP="finanzapp-mcp"
CTR_N8N="finanzapp-n8n"
CTR_DB="finanzapp-db"

# ─── Colores ANSI ────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
RESET='\033[0m'
BOLD='\033[1m'

# ─── Utilidades ──────────────────────────────────────────────

print_header() {
    local title="${1:-}"
    clear
    echo ""
    echo -e "${CYAN}  ╔══════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}  ║         FinanzApp — Stack Manager        ║${RESET}"
    echo -e "${CYAN}  ╚══════════════════════════════════════════╝${RESET}"
    if [[ -n "$title" ]]; then
        echo ""
        echo -e "${YELLOW}  >>> ${title}${RESET}"
    fi
    echo ""
}

print_option() {
    local key="$1"
    local label="$2"
    echo -e "  ${GRAY}[${RESET}${GREEN}${key}${RESET}${GRAY}]${RESET} ${WHITE}${label}${RESET}"
}

read_choice() {
    local valid_keys=("$@")
    local choice
    while true; do
        echo ""
        read -rp "  Opcion: " choice
        choice="${choice,,}"  # lowercase
        for key in "${valid_keys[@]}"; do
            if [[ "$choice" == "$key" ]]; then
                MENU_CHOICE="$choice"
                return
            fi
        done
        echo -e "  ${RED}Opcion invalida. Intenta de nuevo.${RESET}"
    done
}

run_compose() {
    echo ""
    echo -e "  ${GRAY}Ejecutando: docker compose $*${RESET}"
    echo ""
    docker compose -f "$COMPOSE_FILE" "$@"
}

pause_screen() {
    echo ""
    echo -e "  ${GRAY}Presiona Enter para volver al menu...${RESET}"
    read -r
}

show_all_status() {
    echo -e "  ${CYAN}Estado actual de los contenedores:${RESET}"
    echo ""
    docker compose -f "$COMPOSE_FILE" ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null \
        || echo -e "  ${YELLOW}No hay contenedores en ejecucion o el compose aun no fue iniciado.${RESET}" || true
}

# ─── Menú: Levantar servicios ─────────────────────────────────

menu_start() {
    print_header "Levantar servicios"
    show_all_status
    echo ""
    print_option "1" "Stack completo (todos los servicios)"
    print_option "2" "Solo n8n        (incluye postgres + api como dependencias)"
    print_option "3" "Solo API        (incluye postgres)"
    print_option "4" "Solo Frontend   (incluye postgres + api)"
    print_option "5" "Solo MCP        (incluye postgres + api)"
    print_option "6" "Solo PostgreSQL (base de datos unicamente)"
    print_option "0" "Volver"

    read_choice "1" "2" "3" "4" "5" "6" "0"

    case "$MENU_CHOICE" in
        1) run_compose up -d --build || true ;;
        2) run_compose up -d "$SVC_N8N" || true ;;
        3) run_compose up -d "$SVC_API" || true ;;
        4) run_compose up -d "$SVC_WEB" || true ;;
        5) run_compose up -d "$SVC_MCP" || true ;;
        6) run_compose up -d "$SVC_DB" || true ;;
        0) return ;;
    esac

    [[ "$MENU_CHOICE" != "0" ]] && pause_screen
}

# ─── Menú: Ver logs ──────────────────────────────────────────

menu_logs() {
    print_header "Ver logs"
    echo -e "  ${GRAY}Se muestran las ultimas ${LOG_LINES} lineas en modo seguimiento (-f).${RESET}"
    echo -e "  ${GRAY}Presiona Ctrl+C para salir del modo seguimiento.${RESET}"
    echo ""
    print_option "1" "Todos los servicios"
    print_option "2" "API            (finanzapp-api)"
    print_option "3" "Frontend       (finanzapp-web)"
    print_option "4" "MCP            (finanzapp-mcp)"
    print_option "5" "n8n"
    print_option "6" "PostgreSQL     (finanzapp-db)"
    print_option "0" "Volver"

    read_choice "1" "2" "3" "4" "5" "6" "0"

    case "$MENU_CHOICE" in
        1) run_compose logs -f --tail="$LOG_LINES" || true ;;
        2) run_compose logs -f --tail="$LOG_LINES" "$SVC_API" || true ;;
        3) run_compose logs -f --tail="$LOG_LINES" "$SVC_WEB" || true ;;
        4) run_compose logs -f --tail="$LOG_LINES" "$SVC_MCP" || true ;;
        5) run_compose logs -f --tail="$LOG_LINES" "$SVC_N8N" || true ;;
        6) run_compose logs -f --tail="$LOG_LINES" "$SVC_DB" || true ;;
        0) return ;;
    esac
}

# ─── Menú: Detener servicios ─────────────────────────────────

menu_stop() {
    print_header "Detener servicios"
    show_all_status
    echo ""
    print_option "1" "Detener todo (mantiene volumenes)"
    print_option "2" "Detener todo y eliminar volumenes  ${RED}[CUIDADO: borra datos]${RESET}"
    print_option "3" "Detener solo n8n"
    print_option "4" "Detener solo API"
    print_option "5" "Detener solo Frontend"
    print_option "6" "Detener solo MCP"
    print_option "7" "Detener solo PostgreSQL"
    print_option "0" "Volver"

    read_choice "1" "2" "3" "4" "5" "6" "7" "0"

    case "$MENU_CHOICE" in
        1) run_compose down || true ;;
        2)
            echo ""
            echo -e "  ${RED}${BOLD}ADVERTENCIA: esto eliminara todos los datos persistidos (postgres + n8n).${RESET}"
            read -rp "  Escribe 'si' para confirmar: " confirm
            if [[ "$confirm" == "si" ]]; then
                run_compose down -v || true
            else
                echo -e "  ${YELLOW}Operacion cancelada.${RESET}"
            fi
            ;;
        3) run_compose stop "$SVC_N8N" || true ;;
        4) run_compose stop "$SVC_API" || true ;;
        5) run_compose stop "$SVC_WEB" || true ;;
        6) run_compose stop "$SVC_MCP" || true ;;
        7) run_compose stop "$SVC_DB" || true ;;
        0) return ;;
    esac

    [[ "$MENU_CHOICE" != "0" ]] && pause_screen
}

# ─── Menú: Consumo de recursos ───────────────────────────────

menu_stats() {
    print_header "Consumo de recursos"
    echo -e "  ${GRAY}Muestra CPU, memoria, red y disco de los contenedores.${RESET}"
    echo -e "  ${GRAY}Modo streaming: Ctrl+C para salir.${RESET}"
    echo ""
    print_option "1" "Todos los contenedores (streaming)"
    print_option "2" "Solo API            (finanzapp-api)"
    print_option "3" "Solo Frontend       (finanzapp-web)"
    print_option "4" "Solo MCP            (finanzapp-mcp)"
    print_option "5" "Solo n8n"
    print_option "6" "Solo PostgreSQL     (finanzapp-db)"
    print_option "7" "Snapshot puntual    (todos, sin streaming)"
    print_option "0" "Volver"

    read_choice "1" "2" "3" "4" "5" "6" "7" "0"

    case "$MENU_CHOICE" in
        1) docker stats || true ;;
        2) docker stats "$CTR_API" || true ;;
        3) docker stats "$CTR_WEB" || true ;;
        4) docker stats "$CTR_MCP" || true ;;
        5) docker stats "$CTR_N8N" || true ;;
        6) docker stats "$CTR_DB" || true ;;
        7)
            echo ""
            echo -e "  ${CYAN}Snapshot de consumo actual:${RESET}"
            echo ""
            docker stats --no-stream \
                --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" || true
            pause_screen
            ;;
        0) return ;;
    esac
}

# ─── Menú: Utilidades ────────────────────────────────────────

menu_utils() {
    print_header "Utilidades"
    print_option "1" "Reconstruir imagenes sin cache"
    print_option "2" "Ver estado detallado de contenedores"
    print_option "3" "Ver puertos expuestos"
    print_option "4" "Ver redes Docker del stack"
    print_option "5" "Acceder a shell de PostgreSQL (psql)"
    print_option "6" "Ver variables del .env (secretos ocultos)"
    print_option "0" "Volver"

    read_choice "1" "2" "3" "4" "5" "6" "0"

    case "$MENU_CHOICE" in
        1)
            run_compose build --no-cache || true
            pause_screen
            ;;
        2)
            run_compose ps -a || true
            pause_screen
            ;;
        3)
            echo ""
            docker compose -f "$COMPOSE_FILE" ps \
                --format "table {{.Service}}\t{{.Ports}}"
            pause_screen
            ;;
        4)
            echo ""
            docker network inspect finanzapp_finanzapp-network 2>/dev/null \
                || echo -e "  ${YELLOW}La red no existe aun. Levanta el stack primero.${RESET}" || true
            pause_screen
            ;;
        5)
            echo ""
            echo -e "  ${CYAN}Conectando a PostgreSQL... Escribe \\q para salir.${RESET}"
            echo ""
            docker exec -it "$CTR_DB" psql -U postgres -d finanzapp || true
            ;;
        6)
            local env_file="$SCRIPT_DIR/.env"
            if [[ -f "$env_file" ]]; then
                echo ""
                echo -e "  ${CYAN}Variables del .env (contraseñas/tokens ocultos):${RESET}"
                echo ""
                while IFS= read -r line || [[ -n "$line" ]]; do
                    # Omitir comentarios y líneas vacías
                    if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]]; then
                        echo -e "  ${GRAY}${line}${RESET}"
                        continue
                    fi
                    # Ocultar valores de claves sensibles
                    if [[ "$line" =~ ^(.*PASSWORD|.*SECRET|.*TOKEN|.*KEY|.*SID)= ]]; then
                        local var_name="${line%%=*}"
                        echo -e "  ${GRAY}${var_name}=****${RESET}"
                    else
                        echo -e "  ${WHITE}${line}${RESET}"
                    fi
                done < "$env_file"
            else
                echo -e "  ${RED}Archivo .env no encontrado.${RESET}"
                echo -e "  ${YELLOW}Ejecuta: cp .env.example .env${RESET}"
            fi
            pause_screen
            ;;
        0) return ;;
    esac
}

# ─── Menú principal ──────────────────────────────────────────

menu_main() {
    print_header ""

    # Aviso si no existe .env
    if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
        echo -e "  ${RED}AVISO: No se encontro el archivo .env${RESET}"
        echo -e "  ${YELLOW}Ejecuta: cp .env.example .env  y configura las variables.${RESET}"
        echo ""
    fi

    print_option "1" "Levantar servicios"
    print_option "2" "Ver logs"
    print_option "3" "Detener servicios"
    print_option "4" "Consumo de recursos"
    print_option "5" "Utilidades"
    print_option "0" "Salir"

    read_choice "1" "2" "3" "4" "5" "0"

    case "$MENU_CHOICE" in
        1) menu_start ;;
        2) menu_logs ;;
        3) menu_stop ;;
        4) menu_stats ;;
        5) menu_utils ;;
        0)
            echo ""
            echo -e "  ${CYAN}Hasta luego.${RESET}"
            echo ""
            exit 0
            ;;
    esac
}

# ─── Validación de prerequisitos ─────────────────────────────

assert_prerequisites() {
    if ! command -v docker &>/dev/null; then
        echo -e "${RED}Error: Docker no esta instalado o no esta en el PATH.${RESET}"
        exit 1
    fi

    if ! docker info &>/dev/null; then
        echo -e "${RED}Error: Docker no esta en ejecucion. Inicíalo primero.${RESET}"
        exit 1
    fi

    if ! docker compose version &>/dev/null; then
        echo -e "${RED}Error: El plugin 'docker compose' (v2) no esta disponible.${RESET}"
        echo -e "${YELLOW}Instala Docker Desktop o el plugin compose: https://docs.docker.com/compose/install/${RESET}"
        exit 1
    fi

    if [[ ! -f "$COMPOSE_FILE" ]]; then
        echo -e "${RED}Error: No se encontro docker-compose.yml en ${SCRIPT_DIR}${RESET}"
        exit 1
    fi
}

# ─── Entry point ─────────────────────────────────────────────

assert_prerequisites

while true; do
    menu_main
done
