#!/bin/bash

set -e

# Variables
BACKEND_REPO="https://github.com/jlgarzon1827/MediAlertServer.git"
FRONTEND_REPO="https://github.com/jlgarzon1827/med-vigilance.git"
DOCKER_COMPOSE_FILE="./docker-compose.yml"

# Directorios locales
BACKEND_DIR="backend"
FRONTEND_DIR="frontend"

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

# Función para construir y levantar servicios
start_services() {
  echo "Construyendo y levantando servicios..."
  docker-compose -f "$DOCKER_COMPOSE_FILE" up --build -d
  
  echo "Esperando a que los servicios estén listos..."
  sleep 5
  
  echo "Aplicando migraciones en el backend..."
  docker-compose exec backend python manage.py migrate || {
    echo "Error al aplicar las migraciones. Verifica los logs del contenedor backend."
    exit 1
  }
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
    check_dependencies
    clone_repos
    start_services
    check_services
    ;;
  stop)
    stop_services
    ;;
  *)
    echo "Uso: $0 {start|stop}"
    exit 1
    ;;
esac
