# Version-agnostic recipe: accept "android" wherever playwright accepts "linux"
# in the cache-directory resolver. Works on 1.48 (registry/index.js) and
# 1.6x (serverRegistry.js).
s/process\.platform === 'linux') cacheDirectory =/process.platform === 'linux' || process.platform === 'android') cacheDirectory =/
s/if (process\.platform === "linux")$/if (process.platform === "linux" || process.platform === "android")/
