#!/bin/bash

# 1. Obtener la IP actual asignada por la interfaz de red principal
CURRENT_IP=$(hostname -I | awk '{print $1}')

if [ -z "$CURRENT_IP" ]; then
    echo "No se pudo obtener una dirección IP válida."
    exit 1
fi

echo "IP actual del servidor: $CURRENT_IP"

# 2. Configuración de AdGuard Home (API)
ADGUARD_USER="jr-admin"         # Tu usuario de AdGuard (si configuraste uno)
ADGUARD_PASS="linux1234"         # Tu contraseña de AdGuard
ADGUARD_URL="http://127.0.0.1:3001"
DOMAIN="srv-colegio.lan"

# 3. Eliminar reescrituras viejas y agregar la nueva mediante la API de AdGuard
# (AdGuard almacena las reescrituras en su archivo de configuración adguard_conf/AdGuardHome.yaml)
# Si prefieres actualizar el YAML directamente mediante sed:

CONFIG_FILE="./adguard_conf/AdGuardHome.yaml"

if [ -f "$CONFIG_FILE" ]; then
    # Actualizar la IP del dominio srv-colegio.lan en la configuración de AdGuard
    sudo sed -i -E "/domain: '$DOMAIN'|domain: $DOMAIN/,/answer:/ s/answer: .*/answer: $CURRENT_IP/" "$CONFIG_FILE"
    echo "Configuración de AdGuard actualizada con la IP: $CURRENT_IP"
    
    # Reiniciar el contenedor de AdGuard para aplicar cambios sin tocar los demás
    docker restart adguard_dns
else
    echo "No se encontró el archivo de configuración de AdGuard."
fi
