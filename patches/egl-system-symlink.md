# Patch: make Termux chromium's WebGL work

Not a source patch. The packaged `libEGL.so` / `libGLESv2.so` are 5.8 KB Android
stubs with **zero** `egl*` exports, so ANGLE crashes the GPU process
(`exit_code=11`) and `chrome://gpu` reports `WebGL: Disabled`.

## Root cause chain (measured)

1. `$PREFIX/lib/chromium/libEGL.so` → 5808 bytes, no EGL symbols at all.
2. GPU process: `exit_code=11`, `ContextResult::kTransientFailure`.
3. `/dev/dri/renderD128` is **SELinux**-blocked for `untrusted_app_27`
   (`graphics_device`), not permission-blocked. `/dev/kgsl-3d0` is openable.
4. `/vendor/lib64/egl/libEGL_adreno.so` is **linker-namespace**-blocked.
   `/system/lib64/libEGL.so` dlopen's fine.
5. Through system EGL: `eglInitialize` OK, config OK, context OK,
   `glGetString` → `Adreno (TM) 610`, GLES 3.2.

## Fix

```sh
CD=$PREFIX/lib/chromium
cp -a $CD/libEGL.so $CD/libEGL.so.orig
cp -a $CD/libGLESv2.so $CD/libGLESv2.so.orig
ln -sf /system/lib64/libEGL.so    $CD/libEGL.so
ln -sf /system/lib64/libGLESv2.so $CD/libGLESv2.so
```

Plus an X display and **no** `--disable-gpu`:

```sh
Xvfb :5 -screen 0 1280x900x24 &
DISPLAY=:5 chromium-webgl --dump-dom about:blank
```

## Verified result

```
webgl    : true
renderer : ANGLE (Mesa, llvmpipe (LLVM 21.1.8 128 bits), OpenGL 4.6)
pixel    : [0, 255, 0, 255]     <- real readPixels, not a spoof
JA4      : t13d1517h2_8daaf6152771_cb7bf5808d99  (== Chrome 152)
```

Two traps that look like the cause but are not:
- `termux_playwright.CORE_ANDROID_CHROMIUM_ARGS` injects `--disable-gpu` and
  `--disable-software-rasterizer`; with those present the GPU process refuses to
  boot no matter what else you set. Launch playwright directly, or patch it.
- `Xvfb` must actually be running; a stale `DISPLAY=:5` with a dead server gives
  `Missing X server or $DISPLAY` and exits.
