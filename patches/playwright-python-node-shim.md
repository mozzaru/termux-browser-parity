# Patch: Python Playwright on Termux

`playwright` ships `driver/node` as a **glibc aarch64** binary:

```
INTERP  /lib/ld-linux-aarch64.so.1
```

Termux is Bionic (`/system/bin/linker64`), so executing it fails with
`FileNotFoundError` even though the file exists and is +x. Every
`sync_playwright()` call dies before it reaches the browser.

## Fix

Replace the binary with a shim that delegates to Termux's own node (>= 18):

```sh
D=$PREFIX/lib/python3.14/site-packages/playwright/driver
mv $D/node $D/node.orig
printf '#!/data/data/com.termux/files/usr/bin/sh\nexec %s "$@"\n' "$(command -v node)" > $D/node
chmod 755 $D/node
```

Installed as `fix-playwright-node`.

## Also needed

- `fix-gl` — chromium's `libEGL.so` stub crashes ANGLE
- an X display (`Xvfb :5`)
- **no** `--disable-gpu`; `termux_playwright` injects it, so launch plain
  `playwright.sync_api` instead of the shim for GPU work

## Verified

```python
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b = p.chromium.launch(executable_path="/data/data/com.termux/files/usr/lib/chromium/chrome",
                          headless=False, args=["--no-sandbox","--use-gl=angle",
                                                "--use-angle=gl","--ignore-gpu-blocklist"])
```

```
webgl    : true
renderer : ANGLE (Mesa, llvmpipe (LLVM 21.1.8 128 bits), OpenGL 4.6)
pixel    : [0, 0, 255, 255]
maxTex   : 16384
JA4      : t13d1517h2_8daaf6152771_cb7bf5808d99   (== Chrome 152)
```

Wrapper installed as `pw-webgl`.

## Node.js playwright-core

Separate bug: it throws `Unsupported platform: android` from its cache-dir
resolver. Treat android like linux:

```sh
sed -i 's/if (process.platform === "linux")/if (process.platform === "linux" || process.platform === "android")/g' \
  ~/camofox-browser/node_modules/playwright-core/lib/coreBundle.js
```

Installed as `fix-playwright-nodejs`. Verified: WebGL true, same renderer.
