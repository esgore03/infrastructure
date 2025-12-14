#!/bin/bash

CURRENT_ENV=$(cat .current-env)
PREVIOUS_ENV=$([[ "$CURRENT_ENV" == "blue" ]] && echo "green" || echo "blue")

echo "Haciendo rollback de $CURRENT_ENV a $PREVIOUS_ENV..."

./switch-traffic.sh $PREVIOUS_ENV

echo "$PREVIOUS_ENV" > .current-env

echo "Rollback completado. Entorno activo: $PREVIOUS_ENV"
