#!/bin/bash
set -e
cd /root/work/awesome-digital-human-live2d/web

echo "--- pnpm run build ---"
pnpm run build 2>&1 | tail -25

echo "--- killing old frontend ---"
pkill -f "next start" 2>/dev/null || true
sleep 1

echo "--- starting new frontend (setsid + 0.0.0.0:3000) ---"
setsid nohup pnpm exec next start -H 0.0.0.0 -p 3000 \
    < /dev/null > /var/log/nus-digital-human/frontend.log 2>&1 &
FRONTEND_PID=$!
disown $FRONTEND_PID 2>/dev/null || true
echo "Frontend pid=$FRONTEND_PID"

for i in {1..30}; do
    if curl -s -o /dev/null --max-time 1 http://127.0.0.1:3000/sentio; then
        echo "Frontend ready after ${i}s"
        exit 0
    fi
    sleep 1
done
echo "ERROR: frontend not reachable after 30s"
tail -20 /var/log/nus-digital-human/frontend.log
exit 1
