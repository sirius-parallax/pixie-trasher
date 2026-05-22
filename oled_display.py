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

current_line1 = ""
current_line2 = ""
current_line3 = ""
current_line4 = ""

def init_display():
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
    if not device:
        return
    try:
        with canvas(device) as draw:
            draw.rectangle(device.bounding_box, outline="black", fill="black")
            draw.text((0, 0), current_line1[:MAX_WIDTH], fill="white")
            draw.line((0, 10, device.width, 10), fill="white")
            draw.text((0, 14), current_line2[:MAX_WIDTH], fill="white")
            draw.text((0, 28), current_line3[:MAX_WIDTH], fill="white")
            draw.text((0, 42), current_line4[:MAX_WIDTH], fill="white")
    except Exception as e:
        print(f"Display error: {e}", file=sys.stderr)

def fifo_reader(device):
    global current_line1, current_line2, current_line3, current_line4
    while True:
        try:
            fifo_fd = os.open(FIFO_PATH, os.O_RDONLY | os.O_NONBLOCK)
            with os.fdopen(fifo_fd, 'r') as fifo:
                while True:
                    line = fifo.readline()
                    if not line:
                        break
                    msg = line.strip()
                    if not msg:
                        continue
                    if msg.startswith("L1:"):
                        current_line1 = msg[3:].strip()
                    elif msg.startswith("L2:"):
                        current_line2 = msg[3:].strip()
                    elif msg.startswith("L3:"):
                        current_line3 = msg[3:].strip()
                    elif msg.startswith("L4:"):
                        current_line4 = msg[3:].strip()
                    elif msg.startswith("CLEAR"):
                        current_line1 = ""; current_line2 = ""; current_line3 = ""; current_line4 = ""
                    elif msg.startswith("EXIT"):
                        current_line1 = "Script ended"; current_line2 = "Goodbye!"
                        current_line3 = ""; current_line4 = ""
                        update_display(device)
                        return
                    update_display(device)
        except BlockingIOError:
            pass
        except Exception as e:
            print(f"FIFO error: {e}", file=sys.stderr)
        time.sleep(0.1)

def main():
    device = init_display()
    if not device:
        while True:
            try:
                with open(FIFO_PATH, 'r') as f:
                    pass
            except:
                pass
            time.sleep(1)
        return
    if not os.path.exists(FIFO_PATH):
        os.mkfifo(FIFO_PATH)
    current_line1 = "Pixie-Dust v3.0"
    current_line2 = "WPS Attacker"
    current_line3 = "Ready!"
    update_display(device)
    time.sleep(2)
    current_line1 = ""; current_line2 = ""; current_line3 = ""; current_line4 = ""
    update_display(device)
    fifo_reader(device)

if __name__ == "__main__":
    main()
