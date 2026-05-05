#!/bin/bash
echo "--- /root/.nus-tokens ---"
if [ -f /root/.nus-tokens ]; then
    ls -la /root/.nus-tokens
    echo
    echo "Content (sanitized — first 8 chars only):"
    sed -E 's/(=.{0,2})(.{8}).+$/\1\2.../' /root/.nus-tokens
else
    echo "(file does not exist)"
fi
