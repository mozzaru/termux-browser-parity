#!/data/data/com.termux/files/usr/bin/sh
# Give camoufox the sonames it links against. Termux ships libgbm.so and
# libdrm.so without versioned sonames, but libxul.so needs libgbm.so.1 and
# libdrm.so.2 — without them GL/EGL initialisation fails.
set -eu
L="${PREFIX:-/data/data/com.termux/files/usr}/lib"
[ -e "$L/libgbm.so" ] || { echo "libgbm.so missing (pkg install mesa)"; exit 1; }
[ -e "$L/libdrm.so" ] || { echo "libdrm.so missing (pkg install libdrm)"; exit 1; }
[ -e "$L/libgbm.so.1" ] || ln -s "$L/libgbm.so" "$L/libgbm.so.1"
[ -e "$L/libdrm.so.2" ] || ln -s "$L/libdrm.so" "$L/libdrm.so.2"
ls -l "$L/libgbm.so.1" "$L/libdrm.so.2"
echo "done. verify: DISPLAY=:5 camoufox-webgl --version"
