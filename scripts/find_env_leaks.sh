#!/bin/bash
echo "--- Look for .env files that uv or scripts might source ---"
find /root/work -maxdepth 3 -name ".env" -type f 2>/dev/null
find /root -maxdepth 2 -name ".env" -type f 2>/dev/null
echo
echo "--- Web .env (frontend, has NEXT_PUBLIC_ vars) ---"
ls /root/work/awesome-digital-human-live2d/web/.env 2>&1 | head -3
echo
echo "--- ADH backend dir top-level ---"
ls -la /root/work/awesome-digital-human-live2d/.env* 2>&1 | head -5
echo
echo "--- bashrc / profile / environment files for export of these vars ---"
grep -l 'GROQ_API_KEY\|GITHUB_TOKEN' /root/.bashrc /root/.profile /etc/environment /etc/profile 2>/dev/null
echo
echo "--- Any file in /root/work that has gsk_3HLW ---"
grep -rl 'gsk_3HLW' /root/work 2>/dev/null | head -5
echo
echo "--- Any file in /root that has gsk_3HLW ---"
grep -l 'gsk_3HLW' /root/.bashrc /root/.profile 2>/dev/null
