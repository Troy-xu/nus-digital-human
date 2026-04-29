#!/bin/bash
# Stop the NUS Digital Human demo (kills ADH backend + frontend processes).

echo "Stopping NUS Digital Human demo..."

pkill -f "uv run python main.py"  2>/dev/null && echo "  Backend killed"  || echo "  Backend not running"
pkill -f "next start"             2>/dev/null && echo "  Frontend killed" || echo "  Frontend not running"
pkill -f "main.py"                2>/dev/null

sleep 1

# Verify ports are free
ss -tlnp 2>/dev/null | grep -E ":8002|:3000" && echo "WARN: some port still in use" || echo "Ports 8002, 3000 free"

echo "Done."
