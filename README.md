# termux-browser-parity

Make Termux browsers present a **real** TLS fingerprint, and build the fork that
closes the last gap in CI.

## Measured baseline (raw ClientHello capture, this device, 2026-10-26)

| client | JA4 | verdict |
|---|---|---|
| camoufox 156 default | `t13d1517h2_8daaf6152771_3cbfd9057e0d` | **identical to Firefox 154/155** |
| real Firefox 154/155 | `t13d1517h2_8daaf6152771_3cbfd9057e0d` | reference |
| termux chromium 156 raw | `t13d1518h2_8daaf6152771_4980c97edce0` | off by one extension |
| termux chromium `-AddTLSServerHandshakePadding` | `t13d1517h2_8daaf6152771_cb7bf5808d99` | **identical to Chrome 152** |
| real Chrome 152 | `t13d1517h2_8daaf6152771_cb7bf5808d99` | reference |
| real Android Chrome (device) | `t13d1516h2_8daaf6152771_d8a2da3f94cd` | reference |
| real Samsung Browser (device) | `t13d1516h2_8daaf6152771_d8a2da3f94cd` | reference |
| curl_cffi `chrome136` | `t13d1516h2_8daaf6152771_d8a2da3f94cd` | matches Android Chrome |

The "tidak asli" verdict in the original table was a **version-label mismatch**,
not a broken fingerprint. Termux ships Chromium 156; Chrome 152+ sends extension
`0xca34` too, so `t13d1517h2` is the current Chrome shape. The old `t13d1516h2`
rows are Chrome ≤ 151 / Android WebView.

## Two real defects, both fixed without a fork

### 1. chromium — one stray extension

`net/base/features.cc` defines `kAddTLSServerHandshakePadding` with
`FEATURE_DISABLED_BY_DEFAULT`, but the Termux/Alpine build has it **enabled**,
so it emits extension `4832` (`server_padding`). Real Chrome never sends it.

```
chromium-browser --disable-features=AddTLSServerHandshakePadding ...
```

That single flag moves the fingerprint from `t13d1518h2_4980c97edce0` to
`t13d1517h2_cb7bf5808d99` — byte-identical to Chrome 152.

### 2. playwright — android is a hard throw

`playwright-core/lib/server/registry/index.js:300`:

```js
if (process.platform === 'linux') cacheDirectory = ...
else if (process.platform === 'darwin') ...
else if (process.platform === 'win32') ...
else throw new Error('Unsupported platform: ' + process.platform);
```

Termux node reports `process.platform === 'android'`, so every browser path
lookup throws before the bundled chromium is ever considered. Two escapes:

- `PLAYWRIGHT_BROWSERS_PATH=~/.cache/ms-playwright` (env short-circuit, no patch)
- patch `'linux'` → `'linux' || 'android'` (in `patches/`)

The bundled `playwright` python package also looks for a `driver/node` that does
not exist on aarch64; `termux-playwright` already shims that. Use it.

### 3. camoufox — already correct, do not "fix" it

Camoufox 156 emits `t13d1517h2_8daaf6152771_3cbfd9057e0d`, exactly Firefox
154/155. **Adding `security.ssl3.ecdhe_*_sha` prefs breaks it** — those prefs
re-enable CBC suites and push the fingerprint back to the Firefox-135 shape
(`t13d1717h2_5b57614c22b0_...`). Leave `user.js` empty.

## Fork work — where it actually pays

The only residual difference between Termux Chromium and *this device's* Android
Chrome is three ML-DSA signature algorithms:

```
termux  : ..._0904,0905,0906,0403,0804,0401,0503,0805,0501,0806,0601
android : ..._0403,0804,0401,0503,0805,0501,0806,0601
```

`net/socket/ssl_client_socket_impl.cc` hardcodes them in `kVerifyPrefs` with no
feature flag. Removing the three lines yields `d8a2da3f94cd` — the exact
Android-Chrome value measured on this device. That is `patches/chromium-no-mldsa-sigalgs.patch`.

For camoufox there is nothing to fork: it already matches Firefox. A fork would
only be worth it to add **Chrome** TLS emulation, which is a different project.

## Verified end-to-end (on device, 2026-10-26)

```
chromium-real  -> t13d1517h2_8daaf6152771_cb7bf5808d99   == Chrome 152
pw-real        -> t13d1517h2_8daaf6152771_cb7bf5808d99   == Chrome 152
camoufox clean -> t13d1517h2_8daaf6152771_3cbfd9057e0d   == Firefox 154/155
```

`chromium-real` and `pw-real` are installed in `$PREFIX/bin`. Camoufox needed
only an empty profile — `profClean` with no `user.js` reproduces the reference.

## The mismatch that actually gets you flagged

Camoufox's TLS is Firefox; its default UA is Firefox desktop Linux. If you spoof
the UA to Android Chrome while leaving TLS alone, the layers disagree:

| layer | camoufox default | Android Chrome |
|---|---|---|
| JA4 | `t13d1517h2_..._3cbfd9057e0d` (Firefox) | `t13d1516h2_..._d8a2da3f94cd` |
| UA | Firefox/156.0 desktop | Chrome/xxx Mobile |

Pick one identity and make every layer agree. For "Android phone" that means
chromium-real with `--user-agent` + CDP `Network.setUserAgentOverride` for the
client hints (`sec-ch-ua-platform` stays `Linux` otherwise — see `bin/pw-real`).


## WebGL works (added 2026-10-26)

The packaged `libEGL.so` is a 5.8 KB stub with no `egl*` exports, which crashes
ANGLE's GPU process. Replacing it with the system EGL and running under an X
display gives real WebGL:

| metric | value |
|---|---|
| webgl | `true` |
| renderer | `ANGLE (Mesa, llvmpipe (LLVM 21.1.8 128 bits), OpenGL 4.6)` |
| readPixels | `[0, 255, 0, 255]` |
| JA4 | `t13d1517h2_8daaf6152771_cb7bf5808d99` (== Chrome 152) |

Install: `fix-gl` then `chromium-webgl`. Details in
`patches/egl-system-symlink.md`.

This does **not** defeat DataDome on `github.com/signup`: that block is keyed to
the egress IP (`x-dd-b: 259`, highest bucket) and applies to every client,
including the device's own Samsung Browser. `/login` stays 200.


## Camoufox WebGL (added 2026-10-26)

Different failure than chromium: `libxul.so` needs `libgbm.so.1` and
`libdrm.so.2`, which Termux does not ship as versioned sonames.

```sh
fix-gl-camoufox                      # symlink the two sonames
DISPLAY=:5 LIBGL_ALWAYS_SOFTWARE=1 camoufox-webgl
```

Verified render: shader links, `drawArrays` triangle reads back
`[255,255,0,255]`, all four clear colours exact, `MAX_TEXTURE_SIZE` 8192.
JA4 unchanged at `t13d1517h2_8daaf6152771_3cbfd9057e0d` (== Firefox 154/155).
Reported renderer is spoofed per identity (`Intel HD 400` / `AMD R9 200` /
`Apple M1` across runs) — by design.

See `patches/camoufox-gbm-soname.md`.

## CI

`.github/workflows/` builds the patched chromium on `ubuntu-24.04` (fast, cached)
and cross-checks the patch applies to the 156 tag. Termux aarch64 binaries are
*not* built there — the NDK toolchain lives in the Alpine/Termux package, not
upstream chromium. Build those locally with `build-termux.sh`.
