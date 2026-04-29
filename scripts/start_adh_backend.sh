#!/bin/bash
export PATH=/root/.local/bin:$PATH
cd /root/work/awesome-digital-human-live2d
exec uv run python main.py
