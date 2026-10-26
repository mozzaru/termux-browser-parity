#!/data/data/com.termux/files/usr/bin/sh
# Re-enable GPU in termux_playwright (idempotent).
set -eu
TP="${PREFIX:-/data/data/com.termux/files/usr}/lib/python3.14/site-packages/termux_playwright"
F="$TP/browser.py"
[ -f "$F" ] || { echo "termux_playwright not found at $F"; exit 1; }
[ -f "$F.bak" ] || cp -a "$F" "$F.bak"
sed -i -f "$(dirname "$0")/termux_playwright-enable-gpu.sed" "$F"
python3 -c "import ast,sys; ast.parse(open('$F').read()); print('syntax ok')"
grep -c 'disable-gpu' "$F" || echo "0 --disable-gpu left (good)"
