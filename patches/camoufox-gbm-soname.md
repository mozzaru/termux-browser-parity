# Patch: give Camoufox working WebGL on Termux

`libxul.so` links against `libgbm.so.1` and `libdrm.so.2`. Termux ships
`libgbm.so` and `libdrm.so` **without versioned sonames**, so GL/EGL
initialisation fails and WebGL stays off even with an X display.

## Fix

```sh
ln -s $PREFIX/lib/libgbm.so $PREFIX/lib/libgbm.so.1
ln -s $PREFIX/lib/libdrm.so $PREFIX/lib/libdrm.so.2
```

Installed as `fix-gl-camoufox`.

Then run camoufox **headful under an X display** with software GL:

```sh
export DISPLAY=:5 LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe
camoufox-webgl
```

Prefs that matter (`firefox_user_prefs`):

```js
"webgl.force-enabled": true,
"webgl.forbid-software": false,      // camoufox.cfg already sets this
"gfx.webrender.software": true,
"layers.acceleration.disabled": true,
```

## Verified

```
red      : [255, 0, 0, 255]
green    : [0, 255, 0, 255]
blue     : [0, 0, 255, 255]
mid      : [128, 128, 128, 255]
shaderOK : true
triangle : [255, 255, 0, 255]     <- real drawArrays + readPixels
maxTex   : 8192
JA4      : t13d1517h2_8daaf6152771_3cbfd9057e0d   (== Firefox 154/155)
```

The reported renderer is **spoofed per identity by design** — three runs gave
`Intel HD 400`, `AMD Radeon R9 200`, `Apple M1`. The underlying GL is Mesa
llvmpipe. That is camoufox working as intended, not a fake success.

Headless (no `DISPLAY`) still yields `webgl: false`; the X display is required.
