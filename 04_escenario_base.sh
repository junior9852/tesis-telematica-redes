#!/bin/bash
# --- ESCENARIO BASE: SIN PROXY NI FILTRADO DNS ---
WAN_IF="ens33"
CSV_FILE="corridas_base.csv"

echo "corrida,mb_consumidos" > $CSV_FILE
echo "🚀 Iniciando simulación de tráfico (ESCENARIO BASE - 30 corridas)..."

URLS_WEB=("http://neverssl.com" "http://ipv4.download.thinkbroadband.com/5MB.zip")
URLS_DNS=("facebook.com" "tiktok.com" "doubleclick.net" "google-analytics.com" "mined.gob.ni")

for ronda in {1..30}; do
    echo "-----------------------------------"
    echo "Ejecutando Corrida Base #$ronda / 30..."
    
    # Leer bytes en la WAN ANTES de la prueba
    RX_ANTES=$(cat /sys/class/net/$WAN_IF/statistics/rx_bytes)
    TX_ANTES=$(cat /sys/class/net/$WAN_IF/statistics/tx_bytes)

    # Generar tráfico directo a internet
    for url in "${URLS_WEB[@]}"; do
        curl -s -L -o /dev/null "$url"
    done
    for dns in "${URLS_DNS[@]}"; do
        nslookup $dns > /dev/null
    done
    
    # Leer bytes en la WAN DESPUÉS de la prueba
    RX_DESPUES=$(cat /sys/class/net/$WAN_IF/statistics/rx_bytes)
    TX_DESPUES=$(cat /sys/class/net/$WAN_IF/statistics/tx_bytes)
    
    # Calcular consumo en MB
    DIF_RX=$((RX_DESPUES - RX_ANTES))
    DIF_TX=$((TX_DESPUES - TX_ANTES))
    MB_TOTAL=$(awk "BEGIN {printf \"%.2f\", ($DIF_RX + $DIF_TX)/1048576}")
    
    echo "✔️ Tráfico medido: $MB_TOTAL MB"
    echo "$ronda,$MB_TOTAL" >> $CSV_FILE
    sleep 2
done

echo "✅ 30 corridas del Escenario Base completadas. Datos guardados en $CSV_FILE."
