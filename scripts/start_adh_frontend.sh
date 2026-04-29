#!/bin/bash
cd /root/work/awesome-digital-human-live2d/web
# Bind to all interfaces so Windows host can reach it via localhost forwarding
exec pnpm exec next start -H 0.0.0.0 -p 3000
