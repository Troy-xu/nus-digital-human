#!/bin/bash
set -e
# Install Node.js LTS via NodeSource (official repo)
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - 2>&1 | tail -5
DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs 2>&1 | tail -5
# Install pnpm globally
npm install -g pnpm 2>&1 | tail -3
echo "---verify---"
node --version
npm --version
pnpm --version
