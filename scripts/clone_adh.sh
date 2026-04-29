#!/bin/bash
set -e
mkdir -p /root/work
cd /root/work
if [ -d awesome-digital-human-live2d ]; then
    echo "ADH repo already exists, pulling latest..."
    cd awesome-digital-human-live2d
    git pull --ff-only 2>&1 | tail -3
else
    echo "Cloning ADH (李锟 fork)..."
    git clone https://github.com/freecoinx/awesome-digital-human-live2d.git 2>&1 | tail -3
fi
cd /root/work/awesome-digital-human-live2d
echo "---"
echo "ADH location: $(pwd)"
ls -la | head -15
echo "---"
git log --oneline -5
