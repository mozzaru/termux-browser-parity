# termux_playwright hardcodes --disable-gpu + --disable-software-rasterizer in
# CORE_ANDROID_CHROMIUM_ARGS, which makes the GPU process refuse to boot:
#   "GPU process was unable to boot: GPU access is disabled through commandline
#    switch --disable-gpu and --disable-software-rasterizer"
# Removing the two lines lets ANGLE run (needs fix-gl + an X display).
/^    "--disable-gpu",$/d
/^    "--disable-software-rasterizer",$/d
