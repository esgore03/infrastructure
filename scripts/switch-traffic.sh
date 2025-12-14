set -e

NEW_ENV=$1

if [ -z "$NEW_ENV" ]; then
    echo "Uso: ./switch-traffic.sh [blue|green]"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGINX_DIR="$(dirname "$SCRIPT_DIR")/nginx"

echo "Cambiando tráfico a: $NEW_ENV"

echo "server frontend-${NEW_ENV}:80;" > "$NGINX_DIR/active-frontend.conf"
echo "server backend-${NEW_ENV}:3000;" > "$NGINX_DIR/active-backend.conf"

docker exec loadbalancer nginx -s reload 2>/dev/null || echo "   Load balancer se actualizará al reiniciar"

echo "Tráfico redirigido a $NEW_ENV"
