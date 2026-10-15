#!/bin/bash

clear

echo "=================================================="
echo "              ███████╗██╗   ██╗███╗   ███╗"
echo "              ██╔════╝██║   ██║████╗ ████║"
echo "              ███████╗██║   ██║██╔████╔██║"
echo "              ╚════██║██║   ██║██║╚██╔╝██║"
echo "              ███████║╚██████╔╝██║ ╚═╝ ██║"
echo "              ╚══════╝ ╚═════╝ ╚═╝     ╚═╝"
echo ""
echo "                    SVM v9.3"
echo "=================================================="
echo ""

echo "[+] Updating packages..."
apt update -y

echo "[+] Installing required packages..."
apt install -y unzip curl wget git sudo

echo "[+] Checking Svm-v9.3.zip..."

if [ ! -f "Svm-v9.3.zip" ]; then
    echo "[!] Svm-v9.3.zip not found!"
    echo "[!] Put Svm-v9.3.zip in this directory and run again."
    exit 1
fi

echo "[+] Extracting Svm-v9.3.zip..."
rm -rf Svm-v9.3
unzip -o Svm-v9.3.zip

if [ -d "Svm-v9.3" ]; then
    cd Svm-v9.3
else
    echo "[!] Svm-v9.3 directory not found after extraction."
    exit 1
fi

if [ ! -f "install.sh" ]; then
    echo "[!] install.sh not found!"
    exit 1
fi

echo "[+] Making install.sh executable..."
chmod +x install.sh

echo ""
echo "=================================================="
echo "              Starting SVM v9.3 Installer"
echo "=================================================="
echo ""

bash install.sh

echo ""
echo "=================================================="
echo "              SVM v9.3 Installation Done"
echo "=================================================="
