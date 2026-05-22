#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OLED Display Module for Pixie-Dust Attacker
Компактная версия - максимум информации на маленьком экране
"""

import sys
import os
import time
from luma.core.interface.serial import i2c
from luma.core.render import canvas
from luma.oled.device import ssd1306, sh1106

# ============================================
# НАСТРОЙКИ (ИЗМЕНИТЕ ПОД СВОЙ ДИСПЛЕЙ)
# ============================================
I2C_PORT = 0        # Порт I2C (проверьте через i2cdetect -y 0)
I2C_ADDRESS = 0x3C  # Адрес дисплея (обычно 0x3C или 0x3D)
FIFO_PATH = "/tmp/oled_fifo"
MAX_WIDTH = 21      # Максимум символов в строке
# ============================================

# Глобальное состояние
current_line1 = ""   # Строка 1: счетчик и статус
current_line2 = ""   # Строка 2: название сети + сигнал
current_line3 = ""   # Строка 3: прогресс или PIN
current_line4 = ""   # Строка 4: пароль или сообщение

def init_display():
    """Инициализация дисплея"""
    serial = i2c(port=I2C_PORT, address=I2C_ADDRESS)
    
    try:
        device = ssd1306(serial)
        print("OLED: SSD1306 detected", file=sys.stderr)
        return device
    except:
        pass
    
    try:
        device = sh1106(serial)
        print("OLED: SH1106 detected", file=sys.stderr)
        return device
    except Exception as e:
        print(f"OLED ERROR: {e}", file=sys.stderr)
        return None

def update_display(device):
    """Обновляет экран"""
    if not device:
        return
    
    try:
        with canvas(device) as draw:
            # Очищаем экран (черный фон)
            draw.rectangle(device.bounding_box, outline="black", fill="black")
            
            # Строка 1: статус и счетчик (y=0)
            draw.text((0, 0), current_line1[:MAX_WIDTH], fill="white")
            draw.line((0, 10, device.width, 10), fill="white")
            
            # Строка 2: название сети и сигнал (y=14)
            draw.text((0, 14), current_line2[:MAX_WIDTH], fill="white")
            
            # Строка 3: прогресс или PIN (y=28)
            draw.text((0, 28), current_line3[:MAX_WIDTH], fill="white")
            
            # Строка 4: пароль или сообщение (y=42)
            draw.text((0, 42), current_line4[:MAX_WIDTH], fill="white")
            
    except Exception as e:
        print(f"Display error: {e}", file=sys.stderr)

def fifo_reader(device):
    """Читает команды из FIFO"""
    global current_line1, current_line2, current_line3, current_line4
    
    while True:
        try:
            # Открываем FIFO для чтения
            fifo_fd = os.open(FIFO_PATH, os.O_RDONLY | os.O_NONBLOCK)
            with os.fdopen(fifo_fd, 'r') as fifo:
                while True:
                    line = fifo.readline()
                    if not line:
                        break
                    
                    msg = line.strip()
                    if not msg:
                        continue
                    
                    # Парсим команды
                    if msg.startswith("L1:"):
                        current_line1 = msg[3:].strip()
                    elif msg.startswith("L2:"):
                        current_line2 = msg[3:].strip()
                    elif msg.startswith("L3:"):
                        current_line3 = msg[3:].strip()
                    elif msg.startswith("L4:"):
                        current_line4 = msg[3:].strip()
                    elif msg.startswith("CLEAR"):
                        current_line1 = ""
                        current_line2 = ""
                        current_line3 = ""
                        current_line4 = ""
                    elif msg.startswith("EXIT"):
                        current_line1 = "Script ended"
                        current_line2 = "Goodbye!"
                        current_line3 = ""
                        current_line4 = ""
                        update_display(device)
                        return
                    
                    # Обновляем дисплей
                    update_display(device)
                    
        except BlockingIOError:
            pass
        except Exception as e:
            print(f"FIFO error: {e}", file=sys.stderr)
        
        time.sleep(0.1)

def main():
    device = init_display()
    if not device:
        print("OLED: No display found", file=sys.stderr)
        # Даже без дисплея читаем FIFO чтобы не блокировать скрипт
        while True:
            try:
                with open(FIFO_PATH, 'r') as f:
                    pass
            except:
                pass
            time.sleep(1)
        return
    
    # Создаем FIFO
    if not os.path.exists(FIFO_PATH):
        os.mkfifo(FIFO_PATH)
    
    # Заставка
    current_line1 = "Pixie-Dust v3.0"
    current_line2 = "WPS Attacker"
    current_line3 = "Ready!"
    current_line4 = ""
    update_display(device)
    time.sleep(2)
    
    # Очищаем перед началом работы
    current_line1 = ""
    current_line2 = ""
    current_line3 = ""
    current_line4 = ""
    update_display(device)
    
    # Запускаем чтение
    fifo_reader(device)

if __name__ == "__main__":
    main()
