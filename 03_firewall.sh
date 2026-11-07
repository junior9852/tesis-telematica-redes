#!/bin/bash

echo "🔍 Detectando la IP y la tarjeta de red del servidor por DHCP..."
SERVER_IP=$(hostname -I | awk '{print $1}')
INTERFACE=$(ip route get 8.8.8.8 | awk '{print $5; exit}')

echo "IP detectada: ${SERVER_IP} | Interfaz física: ${INTERFACE}"

echo "🧹 Limpiando reglas atascadas..."
sudo iptables -t nat -F PREROUTING

echo "🛡️ Activando políticas de intercepción perimetral (DNAT)..."
sudo sysctl -w net.ipv4.ip_forward=1

# 2. Intercepción DNS (Puerto 53) -> Excluyendo a Docker
sudo iptables -t nat -A PREROUTING -p udp --dport 53 ! -s 172.16.0.0/12 -j DNAT --to-destination ${SERVER_IP}:53
sudo iptables -t nat -A PREROUTING -p tcp --dport 53 ! -s 172.16.0.0/12 -j DNAT --to-destination ${SERVER_IP}:53

# 3. Intercepción Web (Puerto 80) -> Excluyendo a Docker
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 ! -s 172.16.0.0/12 -j DNAT --to-destination ${SERVER_IP}:3129

# 4. Enmascaramiento dinámico (NAT) usando la interfaz detectada
sudo iptables -t nat -A POSTROUTING -o ${INTERFACE} -j MASQUERADE

echo "✅ Tráfico interceptado correctamente sin IPs fijas."
