# Patch: let Termux chromium use the real GPU (GLES2 path)

## Why

The Termux chromium build locks GL to ANGLE only:

```
gl_factory.cc:110  Requested GL implementation (gl=egl-gles2, angle=none)
                   not found in allowed implementations:
                   [(gl=egl-angle, angle=default)]
```

ANGLE cannot initialise here, for a concrete reason:

```
vulkan_icd.cpp: Preferred device ICD not found
vk_renderer.cpp:2759: ANGLE Requires a minimum Vulkan device version of 1.1
Display::initialize error 0: Internal Vulkan error (-9)
```

Turnip (the only Vulkan driver Termux can load) exposes **1.0.354**:

```
$ vulkaninfo --summary
deviceName = Turnip Adreno (TM) 610
apiVersion = 1.0.354
```

But the **system EGL works**, and reports the real GPU:

```
$ ./glinfo   # via /system/lib64/libEGL.so
GL_VENDOR   : Qualcomm
GL_RENDERER : Adreno (TM) 610
GL_VERSION  : OpenGL ES 3.2 V@0502.0
```

So the hardware is reachable; only chromium's allow-list blocks it.

## Patch

`ui/ozone/platform/x11/x11_surface_factory.cc:176` returns ANGLE only:

```cpp
X11SurfaceFactory::GetAllowedGLImplementations() {
  return std::vector<gl::GLImplementationParts>{
      gl::GLImplementationParts(gl::kGLImplementationEGLANGLE),
  };
}
```

Add `kGLImplementationEGLGLES2`. The surface factory already handles it
(`case gl::kGLImplementationEGLGLES2: ... NativeViewGLSurfaceEGLX11GLES2`), so
no other change is needed. See `chromium-allow-gles2.patch`.

Apply to tag `156.0.8078.47` and to `main`.

## Expected effect

With the patch, `--use-gl=egl` becomes valid and WebGL should render on
`Adreno (TM) 610` instead of CPU `Mesa llvmpipe`. That makes the WebGL render
hash (`gl_hash` / `gl_sum` in DataDome's payload) match the device's own
browser instead of a software rasteriser.

## What this does NOT fix

DataDome's slider also scores 24 statistics of the pointer trajectory:

```
m_crdL/R/U/D  m_yDspA  m_yDspSD  m_spdA  m_spdSD  m_xSpdA  m_xSpdSD
m_ySpdA  m_ySpdSD  m_str8  m_maxDstB  m_maxDstA  m_arL  m_arU
m_cnt  m_untrcnt  m_clsdcnt  m_clsdrt  m_incnt  m_inhsh
```

`m_inhsh` is a hash of the first 100 (x,y) pairs — it cannot be replayed, and a
synthetic drag has the wrong statistics. Measured on this device:

| metric | my synthetic drag | human reference |
|---|---|---|
| m_cnt | 48 | 50–70 |
| m_yDspSD | **0.0** | 4–15 |
| m_str8 | **0.991** | 0.72–0.79 |

A corrected generator (`tools/human-drag.js`) produces `m_yDspSD 12.77`,
`m_str8 0.7112`, `m_cnt 57` — inside the human band. Whether that is enough
still needs an end-to-end test, which requires the challenge to be served again.

Reference: https://github.com/joekav/SlideCaptcha
