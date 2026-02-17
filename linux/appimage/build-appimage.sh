#!/usr/bin/env bash
set -euo pipefail

#========================================
# Sono AppImage Builder
# Builds a portable AppImage from the
# Flutter Linux release build.
#========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/linux/x64/release/bundle"
APPDIR="$PROJECT_ROOT/build/Sono.AppDir"
APPIMAGE_TOOL="$PROJECT_ROOT/build/appimagetool"
ICON_SRC="$PROJECT_ROOT/assets/icon/ic_launcher_nightly.png"
OUTPUT="$PROJECT_ROOT/Sono-nightly-x86_64.AppImage"

echo "==> Sono AppImage Builder"
echo "    Project: $PROJECT_ROOT"

#--- Step 1: Build Flutter Linux release ---
echo ""
echo "==> Building Flutter Linux release..."
cd "$PROJECT_ROOT"
flutter build linux --release

if [ ! -f "$BUILD_DIR/sono" ]; then
    echo "ERROR: Flutter build output not found at $BUILD_DIR/sono"
    exit 1
fi
echo "    Build complete."

#--- Step 2: Download appimagetool if needed ---
if [ ! -x "$APPIMAGE_TOOL" ]; then
    echo ""
    echo "==> Downloading appimagetool..."
    curl -fSL -o "$APPIMAGE_TOOL" \
        "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
    chmod +x "$APPIMAGE_TOOL"
    echo "    Downloaded."
fi

#--- Step 3: Create AppDir structure ---
echo ""
echo "==> Creating AppDir..."
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/share/applications"
mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"

# Copy the entire Flutter bundle into usr/bin
cp -r "$BUILD_DIR"/* "$APPDIR/usr/bin/"

# Copy icon
cp "$ICON_SRC" "$APPDIR/sono.png"
cp "$ICON_SRC" "$APPDIR/usr/share/icons/hicolor/256x256/apps/sono.png"

#--- Step 4: Create .desktop file ---
cat > "$APPDIR/sono.desktop" <<'DESKTOP'
[Desktop Entry]
Name=Sono
Exec=sono
Icon=sono
Type=Application
Categories=AudioVideo;Audio;Music;Player;
Comment=Local music player
DESKTOP

cp "$APPDIR/sono.desktop" "$APPDIR/usr/share/applications/sono.desktop"

#--- Step 5: Create AppRun ---
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash
set -euo pipefail

SELF_DIR="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$SELF_DIR/usr/bin/lib:${LD_LIBRARY_PATH:-}"

exec "$SELF_DIR/usr/bin/sono" "$@"
APPRUN

chmod +x "$APPDIR/AppRun"

#--- Step 6: Package AppImage ---
echo ""
echo "==> Packaging AppImage..."
ARCH=x86_64 "$APPIMAGE_TOOL" "$APPDIR" "$OUTPUT"

echo ""
echo "==> Done! AppImage created at:"
echo "    $OUTPUT"
echo ""
echo "    Run with: ./Sono-nightly-x86_64.AppImage"
