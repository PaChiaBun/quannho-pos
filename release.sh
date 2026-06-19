#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Quán Nhỏ POS — Release Build Script
# Chạy: chmod +x release.sh && ./release.sh
# ─────────────────────────────────────────────────────────────────────────────

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$PROJECT_DIR/release-builds"

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     🏪 Quán Nhỏ POS — Release Builder        ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════╝${NC}"
echo ""

# Lấy version từ pubspec.yaml
VERSION_FULL=$(grep '^version:' "$PROJECT_DIR/pubspec.yaml" | sed 's/version: //')
# Tách lấy version name (loại bỏ phần build number sau dấu + để tránh lỗi link web tải APK)
VERSION=$(echo "$VERSION_FULL" | cut -d'+' -f1)
BUILD_NUM=$(echo "$VERSION_FULL" | cut -d'+' -f2)
echo -e "${YELLOW}📦 Version Name: $VERSION (Build: $BUILD_NUM)${NC}"
echo ""

# Tạo output directory
mkdir -p "$OUTPUT_DIR"

# ── 1. Flutter clean + pub get ──
echo -e "${BLUE}🧹 Cleaning...${NC}"
cd "$PROJECT_DIR"
flutter clean > /dev/null 2>&1
flutter pub get > /dev/null 2>&1
echo -e "${GREEN}   ✅ Clean done${NC}"

# ── 2. Android APK ──
echo -e "${BLUE}🤖 Building Android APK...${NC}"
flutter build apk --release --no-tree-shake-icons 2>&1 | tail -1
APK_SRC="$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_SRC" ]; then
  cp "$APK_SRC" "$OUTPUT_DIR/QuanNhoPOS-$VERSION.apk"
  APK_SIZE=$(du -h "$OUTPUT_DIR/QuanNhoPOS-$VERSION.apk" | cut -f1)
  echo -e "${GREEN}   ✅ APK: $APK_SIZE → release-builds/QuanNhoPOS-$VERSION.apk${NC}"
  
  # Tự động copy sang thư mục public của LPM.VN để phục vụ tải app trên web
  LPM_PUBLIC="/Users/banhbao/LPM.VN/lpm-web/public"
  if [ -d "$LPM_PUBLIC" ]; then
    cp "$OUTPUT_DIR/QuanNhoPOS-$VERSION.apk" "$LPM_PUBLIC/QuanNhoPOS-$VERSION.apk"
    cp "$OUTPUT_DIR/QuanNhoPOS-$VERSION.apk" "$LPM_PUBLIC/QuanNhoPOS-latest.apk"
    echo -e "${GREEN}   🚀 Tự động copy sang web public: $LPM_PUBLIC/QuanNhoPOS-$VERSION.apk & QuanNhoPOS-latest.apk${NC}"
  fi
else
  echo -e "${RED}   ❌ APK build failed${NC}"
fi

# ── 3. Android AAB (Google Play) ──
echo -e "${BLUE}📦 Building Android AAB...${NC}"
flutter build appbundle --release --no-tree-shake-icons 2>&1 | tail -1
AAB_SRC="$PROJECT_DIR/build/app/outputs/bundle/release/app-release.aab"
if [ -f "$AAB_SRC" ]; then
  cp "$AAB_SRC" "$OUTPUT_DIR/QuanNhoPOS-$VERSION.aab"
  AAB_SIZE=$(du -h "$OUTPUT_DIR/QuanNhoPOS-$VERSION.aab" | cut -f1)
  echo -e "${GREEN}   ✅ AAB: $AAB_SIZE → release-builds/QuanNhoPOS-$VERSION.aab${NC}"
else
  echo -e "${RED}   ❌ AAB build failed${NC}"
fi

# ── 4. iOS ──
echo -e "${BLUE}🍎 Building iOS...${NC}"
flutter build ios --release --no-tree-shake-icons --no-codesign 2>&1 | tail -1
IOS_APP="$PROJECT_DIR/build/ios/iphoneos/Runner.app"
if [ -d "$IOS_APP" ]; then
  IOS_SIZE=$(du -sh "$IOS_APP" | cut -f1)
  echo -e "${GREEN}   ✅ iOS: $IOS_SIZE (cần codesign trước khi distribute)${NC}"
else
  echo -e "${RED}   ❌ iOS build failed${NC}"
fi

# ── 5. macOS ──
echo -e "${BLUE}💻 Building macOS...${NC}"
flutter build macos --release --no-tree-shake-icons 2>&1 | tail -1
MACOS_APP="$PROJECT_DIR/build/macos/Build/Products/Release/quannho_pos.app"
if [ -d "$MACOS_APP" ]; then
  # Tạo DMG-like zip
  cd "$PROJECT_DIR/build/macos/Build/Products/Release/"
  zip -r -q "$OUTPUT_DIR/QuanNhoPOS-$VERSION-macOS.zip" "quannho_pos.app"
  cd "$PROJECT_DIR"
  MAC_SIZE=$(du -h "$OUTPUT_DIR/QuanNhoPOS-$VERSION-macOS.zip" | cut -f1)
  echo -e "${GREEN}   ✅ macOS: $MAC_SIZE → release-builds/QuanNhoPOS-$VERSION-macOS.zip${NC}"
  
  # Tự động copy sang thư mục public của LPM.VN để phục vụ tải app trên web
  LPM_PUBLIC="/Users/banhbao/LPM.VN/lpm-web/public"
  if [ -d "$LPM_PUBLIC" ]; then
    cp "$OUTPUT_DIR/QuanNhoPOS-$VERSION-macOS.zip" "$LPM_PUBLIC/QuanNhoPOS-$VERSION-macOS.zip"
    cp "$OUTPUT_DIR/QuanNhoPOS-$VERSION-macOS.zip" "$LPM_PUBLIC/QuanNhoPOS-latest-macOS.zip"
    echo -e "${GREEN}   🚀 Tự động copy sang web public: $LPM_PUBLIC/QuanNhoPOS-$VERSION-macOS.zip & QuanNhoPOS-latest-macOS.zip${NC}"
  fi
else
  echo -e "${RED}   ❌ macOS build failed${NC}"
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     🎉 Build hoàn tất!                        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "📂 Output: ${YELLOW}$OUTPUT_DIR/${NC}"
echo ""
ls -lh "$OUTPUT_DIR/" 2>/dev/null | grep "QuanNho"
echo ""
echo -e "${YELLOW}📝 Next steps:${NC}"
echo "  1. Upload APK lên Google Drive / Web"
echo "  2. Upload AAB lên Google Play Console"
echo "  3. Codesign iOS → Upload TestFlight"
echo "  4. Update bảng app_versions trên Supabase"
echo ""
