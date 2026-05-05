#!/bin/bash
# Reads stdin lines and writes to /root/.nus-tokens, then verifies sanitized.
cat > /root/.nus-tokens
chmod 600 /root/.nus-tokens
echo "Written. New file size: $(wc -c < /root/.nus-tokens) bytes"
echo "Sanitized check:"
sed -E 's/(=.{0,2})(.{8}).+/\1\2.../' /root/.nus-tokens
