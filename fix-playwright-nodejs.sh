#!/data/data/com.termux/files/usr/bin/sh
# Fix Node.js playwright-core on Termux.
# It throws "Unsupported platform: android" from its cache-dir resolver.
# Treat android like linux wherever it checks for linux. Idempotent.
set -eu
for P in "$HOME"/camofox-browser/node_modules/playwright-core/lib/coreBundle.js \
         "$HOME"/camofox-browser/node_modules/playwright-core/lib/server/registry/index.js \
         "$HOME"/camofox-browser/node_modules/playwright-core/lib/serverRegistry.js ; do
  [ -f "$P" ] || continue
  [ -f "$P.orig" ] || cp -a "$P" "$P.orig"
  if grep -q 'process.platform === "linux" || process.platform === "android"' "$P"; then
    echo "already patched: $P"
  else
    sed -i 's/if (process\.platform === "linux")/if (process.platform === "linux" || process.platform === "android")/g' "$P"
    node --check "$P" && echo "patched: $P"
  fi
done
