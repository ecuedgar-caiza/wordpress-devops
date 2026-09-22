#!/usr/bin/env bash
set -euo pipefail

SITE=${1:-"all"}
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="/tmp/backups"
mkdir -p "$BACKUP_DIR"

backup_site() {
  local site_name=$1
  local web_container=$2
  local db_container=$3
  local db_name=$4

  echo "===> Iniciando respaldo de: $site_name ($TIMESTAMP)"
  local dump_file="$BACKUP_DIR/${site_name}_${TIMESTAMP}.sql"
  local tar_file="$BACKUP_DIR/backup_${site_name}_${TIMESTAMP}.tar.gz"

  # 1. Exportar base de datos vía docker exec (sin contraseñas en texto plano)
  echo "--- Exportando base de datos desde $db_container..."
  docker exec "$db_container" sh -c 'exec mysqldump --all-databases -uroot -p"$MYSQL_ROOT_PASSWORD"' > "$dump_file"

  if [ ! -s "$dump_file" ]; then
    echo "ERROR: El archivo SQL quedó vacío." >&2
    exit 1
  fi

  # 2. Copiar wp-content temporalmente
  echo "--- Extrayendo wp-content de $web_container..."
  local content_tmp="$BACKUP_DIR/${site_name}_content"
  docker cp "$web_container:/var/www/html/wp-content" "$content_tmp"

  # 3. Empaquetar todo
  echo "--- Comprimiendo archivos..."
  tar -czf "$tar_file" -C "$BACKUP_DIR" "${site_name}_${TIMESTAMP}.sql" "${site_name}_content"

  # Limpieza de temporales en el VPS
  rm -rf "$dump_file" "$content_tmp"
  echo "===> Respaldo generado con éxito: $tar_file"
}

case "$SITE" in
  wp_acjsolution|acjsolution)
    backup_site "wp_acjsolution" "wp_acjsolution_site" "wp_acjsolution_db" "wordpress"
    ;;
  wp_ai_client1|ai_client1)
    backup_site "wp_ai_client1" "wp_ai_client1_site" "wp_ai_client1_db" "wordpress"
    ;;
  all)
    backup_site "wp_acjsolution" "wp_acjsolution_site" "wp_acjsolution_db" "wordpress"
    backup_site "wp_ai_client1" "wp_ai_client1_site" "wp_ai_client1_db" "wordpress"
    ;;
  *)
    echo "Sitio desconocido: $SITE. Opciones: wp_acjsolution, wp_ai_client1, all" >&2
    exit 1
    ;;
esac
