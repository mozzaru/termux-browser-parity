#!/data/data/com.termux/files/usr/bin/sh
# Make Termux chromium's WebGL work.
#
# The packaged libEGL.so is a 5.8 KB Android stub with no egl* exports; ANGLE
# therefore crashes the GPU process (exit_code=11). Point it at the system EGL
# and GLESv2, which dlopen fine from Termux (verified: Adreno 610, GLES 3.2).
set -eu
CD="${PREFIX:-/data/data/com.termux/files/usr}/lib/chromium"

[ -f "$CD/libEGL.so.orig" ]    || cp -a "$CD/libEGL.so"    "$CD/libEGL.so.orig"
[ -f "$CD/libGLESv2.so.orig" ] || cp -a "$CD/libGLESv2.so" "$CD/libGLESv2.so.orig"

rm -f "$CD/libEGL.so" "$CD/libGLESv2.so"
ln -s /system/lib64/libEGL.so    "$CD/libEGL.so"
ln -s /system/lib64/libGLESv2.so "$CD/libGLESv2.so"

ls -l "$CD/libEGL.so" "$CD/libGLESv2.so"
echo "patched. verify with: DISPLAY=:5 chromium-webgl --dump-dom about:blank"
echo "revert with: cp -a $CD/libEGL.so.orig $CD/libEGL.so"
