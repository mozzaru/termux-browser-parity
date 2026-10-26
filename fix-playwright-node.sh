#!/data/data/com.termux/files/usr/bin/sh
# Make Python Playwright work on Termux.
#
# playwright ships driver/node as a glibc aarch64 binary
# (interpreter /lib/ld-linux-aarch64.so.1). Termux is Bionic
# (/system/bin/linker64), so exec fails with FileNotFoundError.
# Replace it with a shim that delegates to the Termux node (>= 18).
set -eu
PYVER="${PYVER:-$(python3 -c 'import sys;print("%d.%d"%sys.version_info[:2])')}"
D="${PREFIX:-/data/data/com.termux/files/usr}/lib/python${PYVER}/site-packages/playwright/driver"
[ -d "$D" ] || { echo "playwright driver not found at $D"; exit 1; }
NODE="$(command -v node)" || { echo "node not found"; exit 1; }
[ -f "$D/node.orig" ] || cp -a "$D/node" "$D/node.orig"
cat > "$D/node" <<EOF
#!/data/data/com.termux/files/usr/bin/sh
# glibc node replaced by a Termux (Bionic) node shim
exec $NODE "\$@"
EOF
chmod 755 "$D/node"
"$D/node" --version
echo "patched: $D/node -> $NODE"
echo "revert : cp -a $D/node.orig $D/node"
