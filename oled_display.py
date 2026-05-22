#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OLED Display Module for Pixie-Dust Attacker
Красивое отображение информации на маленьком экране
"""

import sys
import os
import time
from luma.core.interface.serial import i2c
from luma.core.render import canvas
from luma.oled.device import ssd1306, sh1106

# ============================================
# НАСТРОЙКИ
# ============================================
I2C_PORT = 0
I2C_ADDRESS = 0x3C
FIFO_PATH = "/tmp/oled_fifo"
MAX_WIDTH = 21
# ============================================

# Глобальное состояние
current_line1 = ""
current_line2 = ""
current_line3 = ""
current_line4 = ""
animation_frame = 0

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

def draw_progress_bar(draw, x, y, width, percent):
    """Рисует красивый прогресс-бар"""
    fill_width = int(width * percent / 100)
    draw.rectangle((x, y, x + width, y + 8), outline="white", fill="black")
    if fill_width > 0:
        draw.rectangle((x, y, x + fill_width, y + 8), fill="white")
    draw.text((x + width + 2, y), f"{percent}%", fill="white")

def draw_icon(draw, x, y, icon_type):
    """Рисует иконки статуса"""
    if icon_type == "scan":
        # Сканирование - крутящиеся точки
        dots = [".  ", ".. ", "...", " ..", "  .", " .."]
        frame = animation_frame % len(dots)
        draw.text((x, y), f"Scan{dots[frame]}", fill="white")
    elif icon_type == "attack":
        # Атака - мигающая стрелка
        arrow = "▶" if (animation_frame // 5) % 2 == 0 else "►"
        draw.text((x, y), f"{arrow} ATTACK {arrow}", fill="white")
    elif icon_type == "success":
        draw.text((x, y), "✓ SUCCESS ✓", fill="white")
    elif icon_type == "fail":
        draw.text((x, y), "✗ FAILED ✗", fill="white")
    elif icon_type == "wait":
        draw.text((x, y), "⏰ WAITING ⏰", fill="white")
    elif icon_type == "cracked":
        draw.text((x, y), "★ CRACKED! ★", fill="white")

def update_display(device):
    """Обновляет экран с красивым оформлением"""
    global animation_frame
    animation_frame = (animation_frame + 1) % 60
    
    if not device:
        return
    
    try:
        with canvas(device) as draw:
            # Рамка
            draw.rectangle(device.bounding_box, outline="white", fill="black")
            
            # Строка 1: Статус (центрировано)
            status = current_line1[:MAX_WIDTH]
            status_len = len(status)
            x_status = (device.width - status_len * 6) // 2
            draw.text((max(0, x_status), 0), status, fill="white")
            
            # Разделительная линия
            draw.line((0, 10, device.width, 10), fill="white")
            
            # Строка 2: Название сети + сигнал (слева)
            net_text = current_line2[:MAX_WIDTH - 6]
            draw.text((2, 14), net_text, fill="white")
            
            # Сигнал (справа)
            if "|" in current_line2:
                signal = current_line2.split("|")[-1].strip()
            else:
                signal = ""
            x_signal = device.width - len(signal) * 6 - 2
            if signal:
                draw.text((x_signal, 14), signal, fill="white")
            
            # Строка 3: Прогресс или PIN (с иконкой)
            if "PIN:" in current_line3 or "PASS:" in current_line3:
                draw.text((2, 28), current_line3[:MAX_WIDTH], fill="white")
            elif "Attempt" in current_line3:
                draw.text((2, 28), current_line3[:MAX_WIDTH], fill="white")
                # Рисуем прогресс-бар для попыток
                if "/" in current_line3:
                    parts = current_line3.split("/")
                    if len(parts) == 2:
                        current = parts[0].split()[-1]
                        total = parts[1]
                        try:
                            percent = int(current) * 100 // int(total)
                            draw_progress_bar(draw, 2, 38, 60, percent)
                        except:
                            pass
            else:
                draw.text((2, 28), current_line3[:MAX_WIDTH], fill="white")
            
            # Строка 4: Сообщение (центрировано)
            msg = current_line4[:MAX_WIDTH]
            if msg:
                msg_len = len(msg)
                x_msg = (device.width - msg_len * 6) // 2
                draw.text((max(0, x_msg), 42), msg, fill="white")
            
    except Exception as e:
        print(f"Display error: {e}", file=sys.stderr)

def fifo_reader(device):
    """Читает команды из FIFO"""
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
                        current_line1 = "Goodbye!"
                        current_line2 = ""
                        current_line3 = ""
                        current_line4 = ""
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
        print("OLED: No display found", file=sys.stderr)
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
    
    # Заставка
    current_line1 = "PIXIE-DUST"
    current_line2 = "WPS ATTACKER"
    current_line3 = "v3.0"
    current_line4 = "Ready!"
    update_display(device)
    time.sleep(2)
    
    current_line1 = ""
    current_line2 = ""
    current_line3 = ""
    current_line4 = ""
    update_display(device)
    
    fifo_reader(device)

if __name__ == "__main__":
    main()
