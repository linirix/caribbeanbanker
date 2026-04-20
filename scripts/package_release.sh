#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${1:-$ROOT_DIR/dist}"
APP_NAME="CentralBanker"
VERSION_FILE="$ROOT_DIR/VERSION"

if ! command -v swift >/dev/null 2>&1; then
  echo "swift is required to build a release package." >&2
  exit 1
fi

SDKROOT_VALUE=""
if command -v xcrun >/dev/null 2>&1; then
  SDKROOT_VALUE="$(xcrun --show-sdk-path)"
fi

echo "Building release artifacts..."
if [[ -n "$SDKROOT_VALUE" ]]; then
  SDKROOT="$SDKROOT_VALUE" swift build -c release --package-path "$ROOT_DIR"
  PRODUCT_DIR="$(SDKROOT="$SDKROOT_VALUE" swift build -c release --show-bin-path --package-path "$ROOT_DIR")"
else
  swift build -c release --package-path "$ROOT_DIR"
  PRODUCT_DIR="$(swift build -c release --show-bin-path --package-path "$ROOT_DIR")"
fi

VERSION="$(tr -d '[:space:]' < "$VERSION_FILE" 2>/dev/null || true)"
if [[ -z "$VERSION" ]]; then
  VERSION="$(git -C "$ROOT_DIR" describe --tags --always --dirty 2>/dev/null || date +%Y%m%d)"
fi
GIT_REVISION="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
GIT_DIRTY="clean"
if ! git -C "$ROOT_DIR" diff --quiet --ignore-submodules HEAD -- 2>/dev/null; then
  GIT_DIRTY="dirty"
fi
ARCH="$(uname -m)"
ARTIFACT_NAME="${APP_NAME}-${VERSION}-macos-${ARCH}"
STAGE_DIR="$DIST_DIR/$ARTIFACT_NAME"
ARCHIVE_PATH="$DIST_DIR/$ARTIFACT_NAME.zip"
RESOURCE_BUNDLE="$PRODUCT_DIR/${APP_NAME}_CentralBankerCore.bundle"
EXECUTABLE_PATH="$PRODUCT_DIR/$APP_NAME"

rm -rf "$STAGE_DIR" "$ARCHIVE_PATH"
mkdir -p "$STAGE_DIR"

cp "$EXECUTABLE_PATH" "$STAGE_DIR/$APP_NAME"
cp -R "$RESOURCE_BUNDLE" "$STAGE_DIR/"
cp -R "$ROOT_DIR/Config" "$STAGE_DIR/"
cp "$ROOT_DIR/README.md" "$STAGE_DIR/"
cp "$ROOT_DIR/PLAYER_GUIDE.md" "$STAGE_DIR/"
cp "$ROOT_DIR/CHANGELOG.md" "$STAGE_DIR/"
cp "$ROOT_DIR/VERSION" "$STAGE_DIR/"

cat > "$STAGE_DIR/run-centralbanker" <<'EOF'
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CENTRALBANKER_CONFIG_DIR="$SCRIPT_DIR/Config"
exec "$SCRIPT_DIR/CentralBanker" "$@"
EOF
chmod +x "$STAGE_DIR/run-centralbanker"

{
  echo "CentralBanker release package"
  echo "Version: $VERSION"
  echo "Built: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "Architecture: $ARCH"
  echo "Git revision: $GIT_REVISION"
  echo "Git status: $GIT_DIRTY"
  echo "Executable: ./run-centralbanker"
} > "$STAGE_DIR/BUILD_INFO.txt"

mkdir -p "$DIST_DIR"
ditto -c -k --sequesterRsrc --keepParent "$STAGE_DIR" "$ARCHIVE_PATH"

echo ""
echo "Release package created:"
echo "  Stage:   $STAGE_DIR"
echo "  Archive: $ARCHIVE_PATH"
