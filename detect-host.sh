#!/bin/bash
set -e

# Definir posibles hosts
HOSTS=("med-vigilance" "localhost" "127.0.0.1" "192.168.1.70")

# Función para probar conectividad de los hosts
find_working_host() {
  for host in "${HOSTS[@]}"; do
    echo "🔍 Probando host: $host" >&2  # Mensaje a stderr
    if ping -c 1 -W 1 "$host" &>/dev/null; then
      echo "✅ Host válido encontrado: $host" >&2  # Mensaje a stderr
      echo "$host"  # Host válido se envía a stdout
      return 0
    fi
    echo "⚠️  Host no accesible: $host" >&2  # Mensaje a stderr
  done
  echo "❌ No se encontró ningún host válido." >&2
  exit 1
}

# Buscar un host funcional (solo captura stdout)
WORKING_HOST=$(find_working_host)

# Generar archivo docker-compose.override.yml
cat > docker-compose.override.yml <<EOL
version: '3.8'

services:
  frontend:
    environment:
      - VUE_APP_API_ROOT_URL=http://${WORKING_HOST}:8000
EOL

# Mensaje final a stderr
echo "✅ docker-compose.override.yml generado con VUE_APP_API_ROOT_URL=http://${WORKING_HOST}:8000" >&2

echo "$WORKING_HOST"
