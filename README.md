
---

## 📋 Краткая инструкция по установке

```bash
# 1. Установите зависимости
sudo apt update
sudo apt install reaver aircrack-ng wireless-tools python3-pip -y
pip3 install luma.oled

# 2. Установите модифицированный Reaver (обязательно!)
git clone https://github.com/t6x/reaver-wps-fork-t6x
cd reaver-wps-fork-t6x/src
./configure && make && sudo make install

# 3. Создайте скрипты (скопируйте содержимое выше)
nano /root/oled_display.py
nano /root/pixie_attacker.sh

# 4. Сделайте исполняемыми
chmod +x /root/oled_display.py /root/pixie_attacker.sh

# 5. Запустите
sudo /root/pixie_attacker.sh
