#!/bin/bash

# ============================================
# ДЕМОН ДЛЯ PIXIE DUST ATTACKER
# Запускает атаку в цикле
# ============================================

INTERVAL=600  # 10 минут между циклами
LOG_FILE="/var/log/pixie-attacker.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Pixie-Dust Attacker Daemon Started ==="

while true; do
    log "--- Starting new attack cycle ---"
    
    # Запускаем основной скрипт в неинтерактивном режиме
    /root/pixie_attacker.sh -t 30 -o /var/log/pixie_results < /dev/null
    
    exit_code=$?
    log "Attack cycle finished with exit code: $exit_code"
    
    log "Waiting ${INTERVAL} seconds before next cycle..."
    sleep $INTERVAL
done
