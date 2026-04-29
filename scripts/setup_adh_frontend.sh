#!/bin/bash
set -e
cd /root/work/awesome-digital-human-live2d/web

# Create .env from template, point at backend port 8002
cat > .env << 'EOF'
NEXT_PUBLIC_SERVER_IP="127.0.0.1"
NEXT_PUBLIC_SERVER_PROTOCOL="http"
NEXT_PUBLIC_SERVER_PORT="8002"
NEXT_PUBLIC_SERVER_VERSION="v0"
NEXT_PUBLIC_SERVER_MODE="prod"
EOF

echo "--- .env contents ---"
cat .env
echo "--- pnpm install (this may take a few minutes) ---"
pnpm install 2>&1 | tail -8
echo "--- pnpm install done ---"
