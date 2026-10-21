#!/usr/bin/env bash
# Build the Flutter SPA on Vercel.  Vercel's base image does not include the
# Flutter SDK, so obtain the stable SDK in the ephemeral build workspace.
set -euo pipefail

FLUTTER_HOME="${VERCEL_FLUTTER_HOME:-/tmp/lumi-flutter}"
FLUTTER_REF="${FLUTTER_VERSION:-stable}"

if [[ ! -x "$FLUTTER_HOME/bin/flutter" ]]; then
  git clone --depth 1 --branch "$FLUTTER_REF" \
    https://github.com/flutter/flutter.git "$FLUTTER_HOME"
fi

export PATH="$FLUTTER_HOME/bin:$PATH"
flutter config --no-analytics
flutter pub get

# Some Windows hosts cannot subset icon fonts when the checkout path contains
# non-ASCII characters. Keeping icons intact makes the build reproducible; the
# small size trade-off is appropriate for this academic demo.
# API_BASE_URL is a public build-time value, normally the Railway API domain
# (for example https://lumi-api-production.up.railway.app). It deliberately is
# not a secret and must never contain the Gemini key or a MySQL connection URL.
if [[ -n "${API_BASE_URL:-}" ]]; then
  flutter build web --release --no-tree-shake-icons \
    --dart-define="API_BASE_URL=$API_BASE_URL"
else
  flutter build web --release --no-tree-shake-icons
fi
