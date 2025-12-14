#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$INFRA_DIR")"

CURRENT_ENV=$(cat "$ROOT_DIR/.current-env" 2>/dev/null || echo "none")

if [ "$CURRENT_ENV" == "blue" ]; then
    NEW_ENV="green"
elif [ "$CURRENT_ENV" == "green" ]; then
    NEW_ENV="blue"
else
    NEW_ENV="blue"
fi

echo -e "${YELLOW}======================================${NC}"
echo -e "${YELLOW}DESPLIEGUE BLUE-GREEN${NC}"
echo -e "${YELLOW}======================================${NC}"
echo -e "   Entorno actual: ${RED}$CURRENT_ENV${NC}"
echo -e "   Nuevo entorno:  ${GREEN}$NEW_ENV${NC}"
echo ""

echo -e "${YELLOW}Verificando red Docker...${NC}"
docker network create app-network 2>/dev/null || echo "   Red ya existe"

echo -e "${YELLOW}Construyendo y levantando $NEW_ENV...${NC}"
cd "$INFRA_DIR"
$DOCKER_COMPOSE -f "docker-compose.${NEW_ENV}.yml" build
$DOCKER_COMPOSE -f "docker-compose.${NEW_ENV}.yml" up -d

echo -e "${YELLOW}Esperando que los contenedores inicien...${NC}"
sleep 8

RETRIES=15
while [ $RETRIES -gt 0 ]; do
    FRONTEND_STATUS=$(docker inspect -f '{{.State.Status}}' "frontend-${NEW_ENV}" 2>/dev/null || echo "not found")
    BACKEND_STATUS=$(docker inspect -f '{{.State.Status}}' "backend-${NEW_ENV}" 2>/dev/null || echo "not found")
    FRONTEND_RESTARTING=$(docker inspect -f '{{.State.Restarting}}' "frontend-${NEW_ENV}" 2>/dev/null || echo "true")
    BACKEND_RESTARTING=$(docker inspect -f '{{.State.Restarting}}' "backend-${NEW_ENV}" 2>/dev/null || echo "true")

    echo "   Frontend: $FRONTEND_STATUS | Backend: $BACKEND_STATUS"

    if [ "$FRONTEND_STATUS" == "running" ] && [ "$FRONTEND_RESTARTING" == "false" ] && \
       [ "$BACKEND_STATUS" == "running" ] && [ "$BACKEND_RESTARTING" == "false" ]; then
        echo -e "   ${GREEN}Contenedores listos${NC}"
        break
    fi

    if [ "$FRONTEND_STATUS" == "exited" ] || [ "$BACKEND_STATUS" == "exited" ]; then
        echo -e "${RED}❌ Contenedor falló. Logs:${NC}"
        docker logs "backend-${NEW_ENV}" --tail 15 2>/dev/null
        $DOCKER_COMPOSE -f "docker-compose.${NEW_ENV}.yml" down
        exit 1
    fi

    RETRIES=$((RETRIES-1))
    sleep 2
done

if [ $RETRIES -eq 0 ]; then
    echo -e "${RED}Timeout. Mostrando logs:${NC}"
    docker logs "backend-${NEW_ENV}" --tail 20 2>/dev/null
    docker logs "frontend-${NEW_ENV}" --tail 20 2>/dev/null
    $DOCKER_COMPOSE -f "docker-compose.${NEW_ENV}.yml" down
    exit 1
fi

echo -e "${YELLOW}Cambiando tráfico...${NC}"
"$SCRIPT_DIR/switch-traffic.sh" "$NEW_ENV"

echo "$NEW_ENV" > "$ROOT_DIR/.current-env"

echo -e "${YELLOW}Levantando load balancer...${NC}"
$DOCKER_COMPOSE -f docker-compose.lb.yml up -d

sleep 3
echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}DESPLIEGUE COMPLETADO${NC}"
echo -e "${GREEN}======================================${NC}"
echo -e "   Entorno activo: ${GREEN}$NEW_ENV${NC}"
echo -e "   Frontend: http://localhost"
echo -e "   Backend:  http://localhost:3000"
