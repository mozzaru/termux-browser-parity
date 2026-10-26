#!/data/data/com.termux/files/usr/bin/sh
# Build Termux aarch64 chromium from source with patches/chromium-no-mldsa-sigalgs.patch.
# Run this ON the device. GitHub-hosted runners cannot produce this artifact:
# the NDK/Bionic toolchain for chromium-on-Termux lives in the Termux package
# (chromium is built with the Alpine/Termux aarch64 toolchain, not upstream's
# build system). CI only proves the patch applies and that JA4 fixtures hold.
set -eu

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
WORK="${WORK:-$HOME/chromium-build}"
TAG="${TAG:-156.0.8078.47}"
PATCHES="$(cd "$(dirname "$0")" && pwd)/patches"

echo "== prerequisites =="
command -v git >/dev/null || { echo "need git"; exit 1; }
command -v python3 >/dev/null || { echo "need python3"; exit 1; }
df -h "$HOME" | tail -1

echo "== fetch depot_tools =="
if [ ! -d "$WORK/depot_tools" ]; then
  git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git "$WORK/depot_tools"
fi
export PATH="$WORK/depot_tools:$PATH"
export DEPOT_TOOLS_UPDATE=0

echo "== sync src @ $TAG =="
mkdir -p "$WORK/src"
cd "$WORK/src"
if [ ! -d .git ]; then
  git init -q .
  git remote add origin https://chromium.googlesource.com/chromium/src.git
fi
git fetch --depth 1 origin "refs/tags/$TAG"
git checkout -q FETCH_HEAD

echo "== apply fingerprint patch =="
patch -p1 --dry-run < "$PATCHES/chromium-no-mldsa-sigalgs.patch"
patch -p1 < "$PATCHES/chromium-no-mldsa-sigalgs.patch"

echo "== deps =="
gclient sync --no-history --shallow -D

echo "== gn gen =="
# Termux aarch64 target. Android target_os keeps Bionic, which is what the
# Termux chromium package uses; use_ozone+headless avoids X11.
gn gen out/termux --args='
  is_debug=false
  is_official_build=true
  target_os="android"
  target_cpu="arm64"
  is_component_build=false
  use_ozone=true
  ozone_platform_headless=true
  use_glib=false
  use_sysroot=false
  use_custom_libcxx=false
  is_clang=true
  clang_use_chrome_plugins=false
  enable_nacl=false
  symbol_level=0
  blink_symbol_level=0
  v8_symbol_level=0
  is_cfi=false
  use_thin_lto=false
  enable_swiftshader=false
  treat_warnings_as_errors=false
'

echo "== build (this is hours on-device; expect thermal throttling) =="
ninja -C out/termux chrome chromedriver

echo "== verify the patch took =="
strings out/termux/chrome | grep -c "ML-DSA" || true
echo "artifact: $WORK/src/out/termux/chrome"
