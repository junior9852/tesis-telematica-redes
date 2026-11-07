#!/bin/bash

echo "⚙️ Levantando la infraestructura del modelo telemático..."
docker compose up -d
sleep 3
sudo ./auto_update_ip.sh
echo "----------------------------------------"
echo "✅ LABORATORIO EN LÍNEA (DOMINIO LOCAL)"
echo "🌐 RUTAS DE ACCESO DESDE TU NAVEGADOR:"
echo "➡️ Panel AdGuard   : http://srv-colegio.lan:3001"
echo "➡️ Panel Grafana   : http://srv-colegio.lan:3000"
echo "➡️ Panel Prometheus: http://srv-colegio.lan:9090"
echo "➡️ Monitor de Red  : http://srv-colegio.lan:9100/metrics"
echo "➡️ Puerto Proxy    : 3128"
echo "----------------------------------------"
