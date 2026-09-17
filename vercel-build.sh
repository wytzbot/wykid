#!/usr/bin/env bash
set -e

# Install a stable Flutter SDK when Vercel does not provide one.
if ! command -v flutter >/dev/null 2>&1; then
  FLUTTER_VERSION="${FLUTTER_VERSION:-3.35.2}"
  mkdir -p "$HOME/flutter-sdk"
  if [ ! -x "$HOME/flutter-sdk/flutter/bin/flutter" ]; then
    curl -L --fail --retry 3 "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" -o /tmp/flutter.tar.xz
    rm -rf "$HOME/flutter-sdk/flutter"
    tar -xf /tmp/flutter.tar.xz -C "$HOME/flutter-sdk"
  fi
  export PATH="$HOME/flutter-sdk/flutter/bin:$PATH"
fi

flutter --version
flutter config --enable-web
flutter pub get
flutter build web --release

test -f build/web/index.html
echo "Flutter Web output verified: build/web/index.html"
