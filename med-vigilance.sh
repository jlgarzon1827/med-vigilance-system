#!/bin/bash

set -e

# Variables
BACKEND_REPO="https://github.com/jlgarzon1827/MediAlertServer.git"
FRONTEND_REPO="https://github.com/jlgarzon1827/med-vigilance.git"
DOCKER_COMPOSE_FILE="./docker-compose.yml"

# Directorios locales
BACKEND_DIR="backend"
FRONTEND_DIR="frontend"
FRONTEND_ENV_FILE="./frontend/.env"

# Función para verificar dependencias
check_dependencies() {
  if ! command -v docker &> /dev/null; then
    echo "Error: Docker no está instalado."
    exit 1
  fi

  if ! command -v docker-compose &> /dev/null; then
    echo "Error: Docker Compose no está instalado."
    exit 1
  fi
}

# Función para detectar el host válido
detect_host() {
  echo "🔧 Detectando host válido para el frontend..." >&2
  WORKING_HOST=$(./detect-host.sh)  # Solo captura el host desde stdout
  echo "✅ Host válido detectado: $WORKING_HOST" >&2
}

# Función para clonar o actualizar repositorios
clone_repos() {
  echo "Clonando o actualizando repositorios..."

  if [ ! -d "$BACKEND_DIR" ]; then
    echo "Clonando repositorio del backend..."
    git clone "$BACKEND_REPO" "$BACKEND_DIR"
  else
    echo "Actualizando repositorio del backend..."
    (cd "$BACKEND_DIR" && git pull)
  fi

  if [ ! -d "$FRONTEND_DIR" ]; then
    echo "Clonando repositorio del frontend..."
    git clone "$FRONTEND_REPO" "$FRONTEND_DIR"
  else
    echo "Actualizando repositorio del frontend..."
    (cd "$FRONTEND_DIR" && git pull)
  fi
}

# Función para actualizar o crear el archivo .env en el frontend con el host detectado
update_frontend_env() {
  echo "🔧 Verificando archivo .env en $FRONTEND_ENV_FILE..."

  # Si no existe, crearlo con un valor basado en el host detectado
  if [ ! -f "$FRONTEND_ENV_FILE" ]; then
    echo "🛠️  Creando archivo .env con valores predeterminados..."
    cat > "$FRONTEND_ENV_FILE" <<EOL
VUE_APP_API_ROOT_URL=http://${WORKING_HOST}:8000
EOL
    echo "✅ Archivo .env creado en $FRONTEND_ENV_FILE."
  else
    # Si existe, actualizar solo la línea de VUE_APP_API_ROOT_URL de forma segura
    echo "🛠️  Actualizando la variable VUE_APP_API_ROOT_URL en $FRONTEND_ENV_FILE..."
    sed -i "s|^VUE_APP_API_ROOT_URL=.*|VUE_APP_API_ROOT_URL=http://${WORKING_HOST}:8000|" "$FRONTEND_ENV_FILE"
    cp "$FRONTEND_ENV_FILE" "$FRONTEND_ENV_FILE".production
    echo "✅ Variable VUE_APP_API_ROOT_URL actualizada en $FRONTEND_ENV_FILE."
  fi

  # Mostrar el contenido final del archivo .env para verificación
  echo "📄 Contenido del archivo .env:"
  cat "$FRONTEND_ENV_FILE"
}

# Crear el archivo SQLite si no existe
initialize_sqlite() {
  if [ ! -f "./backend/db.sqlite3" ]; then
    echo "🛠️  Creando archivo db.sqlite3 en ./backend..."
    touch ./backend/db.sqlite3 && chmod 666 ./backend/db.sqlite3
    echo "✅ Archivo db.sqlite3 creado con permisos adecuados."
  else
    echo "ℹ️  El archivo db.sqlite3 ya existe, no es necesario crearlo."
  fi
}

# Función para construir y levantar servicios
start_services() {
  echo "Construyendo y levantando servicios..."
  docker-compose -f "$DOCKER_COMPOSE_FILE" up --build -d

  echo "Esperando a que los servicios estén listos..."
  sleep 5
}

# Función para verificar servicios activos
check_services() {
  echo "\nServicios activos:"
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "django_backend|vue_frontend"

  echo "\nAccesos:"
  echo "- Backend (Django): http://med-vigilance:8000/admin"
  echo "- Frontend (Vue):   http://med-vigilance:8080"
}

# Función para detener y limpiar servicios
stop_services() {
  echo "Deteniendo servicios (los datos de SQLite se mantienen)..."
  docker-compose down || {
    echo "Error al detener los servicios. Verifica los logs de Docker."
    exit 1
  }
}

# Menú principal del script
case $1 in
  start)
    check_dependencies         # Verificar que las dependencias estén instaladas.
    detect_host                # Detectar el host válido y asignarlo a WORKING_HOST.
    clone_repos                # Clonar o actualizar los repositorios.
    update_frontend_env        # Actualizar o crear el archivo .env del frontend con WORKING_HOST.
    initialize_sqlite          # Crear la base de datos SQLite si no existe.
    start_services             # Construir y levantar los servicios.
    check_services             # Verificar los servicios activos.
    ;;
  stop)
    stop_services              # Detener y limpiar los servicios.
    ;;
  *)
    echo "Uso: $0 {start|stop}"
    exit 1
    ;;
esac
