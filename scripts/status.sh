#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

CURRENT_ENV=$(cat "$ROOT_DIR/.current-env" 2>/dev/null || echo "ninguno")

echo ""
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}         ESTADO DEL DESPLIEGUE             ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Entorno activo: ${GREEN}$CURRENT_ENV${NC}"
echo ""
echo -e "${YELLOW}Contenedores:${NC}"
echo "─────────────────────────────────────────────"
printf "%-20s %-15s %-10s\n" "NOMBRE" "ESTADO" "PUERTOS"
echo "─────────────────────────────────────────────"

show_container() {
    local name=$1
    local status=$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || echo "no existe")
    local ports=$(docker port "$name" 2>/dev/null | head -1 || echo "-")

    if [ "$status" == "running" ]; then
        printf "%-20s ${GREEN}%-15s${NC} %-10s\n" "$name" "$status" "$ports"
    elif [ "$status" == "no existe" ]; then
        printf "%-20s ${RED}%-15s${NC} %-10s\n" "$name" "$status" "-"
    else
        printf "%-20s ${YELLOW}%-15s${NC} %-10s\n" "$name" "$status" "-"
    fi
}

show_container "loadbalancer"
show_container "frontend-blue"
show_container "backend-blue"
show_container "frontend-green"
show_container "backend-green"

echo ""
echo -e "${YELLOW}URLs de acceso:${NC}"
echo "   Frontend: http://localhost:80"
echo "   Backend:  http://localhost:3000"
echo ""
echo -e "${YELLOW}Health Checks:${NC}"

if curl -sf "http://localhost:80/health" > /dev/null 2>&1; then
    echo -e "   Frontend: ${GREEN}Healthy${NC}"
else
    echo -e "   Frontend: ${RED}No responde${NC}"
fi

if curl -sf "http://localhost:3000/health" > /dev/null 2>&1; then
    echo -e "   Backend:  ${GREEN}Healthy${NC}"
else
    echo -e "   Backend:  ${RED}No responde${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
