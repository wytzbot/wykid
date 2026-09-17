#!/usr/bin/env bash
set -e

# Vercel build containers may run as root. Flutter uses Git internally,
# so explicitly mark the downloaded SDK as a trusted Git directory.
FLUTTER_VERSION="${FLUTTER_VERSION:-3.35.2}"
FLUTTER_HOME="${FLUTTER_HOME:-/vercel/flutter-sdk}"

if ! command -v flutter >/dev/null 2>&1; then
  mkdir -p "$FLUTTER_HOME"
  if [ ! -x "$FLUTTER_HOME/flutter/bin/flutter" ]; then
    curl -L --fail --retry 3 \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      -o /tmp/flutter.tar.xz
    rm -rf "$FLUTTER_HOME/flutter"
    tar -xf /tmp/flutter.tar.xz -C "$FLUTTER_HOME"
  fi
  export PATH="$FLUTTER_HOME/flutter/bin:$PATH"
fi

# Fix Git's "dubious ownership" check in Vercel's build container.
git config --global --add safe.directory "$FLUTTER_HOME/flutter" || true

flutter --version
flutter config --enable-web
flutter pub get
flutter build web --release

test -f build/web/index.html
echo "Flutter Web output verified: build/web/index.html"
