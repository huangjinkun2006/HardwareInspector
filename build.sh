#!/bin/bash
#  Hardware Inspector 构建脚本
#  用法: ./build.sh
#  产出: build/Hardware Inspector.app  （同时保留裸二进制用于命令行模式）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Hardware Inspector.app"
CONTENTS="$APP/Contents"
BIN="$CONTENTS/MacOS/HardwareInspector"
SOURCES=(
  "$ROOT/Sources/BrandLogo.swift"
  "$ROOT/Sources/BrandDetector.swift"
  "$ROOT/Sources/SystemInfo.swift"
  "$ROOT/Sources/LiveMonitor.swift"
  "$ROOT/Sources/LiveViews.swift"
  "$ROOT/Sources/Report.swift"
  "$ROOT/Sources/UI.swift"
  "$ROOT/Sources/main.swift"
)

mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

echo "[1/6] 编译 Swift 源码 ..."
ARCH="$(uname -m)"
OTHER="arm64"
if [ "$ARCH" = "arm64" ]; then OTHER="x86_64"; fi
UNIVERSAL=0
if [ "${1:-}" = "--universal" ]; then UNIVERSAL=1; fi

xcrun swiftc -swift-version 5 -O -target "${ARCH}-apple-macosx12.0" \
  "${SOURCES[@]}" -o "$BUILD/HI.$ARCH"

BUILT_UNIVERSAL=0
if [ "$UNIVERSAL" = "1" ]; then
  if xcrun swiftc -swift-version 5 -O -target "${OTHER}-apple-macosx12.0" \
      "${SOURCES[@]}" -o "$BUILD/HI.$OTHER" 2>"$BUILD/cross-compile.log"; then
    lipo -create "$BUILD/HI.$ARCH" "$BUILD/HI.$OTHER" -output "$BIN"
    BUILT_UNIVERSAL=1
    echo "      通用二进制: $ARCH + $OTHER"
  else
    echo "      另一架构交叉编译不可用，回退到本机架构（详见 build/cross-compile.log）"
  fi
fi
if [ "$BUILT_UNIVERSAL" = "0" ]; then
  cp "$BUILD/HI.$ARCH" "$BIN"
  echo "      本机架构: ${ARCH} （追加 --universal 可尝试构建通用二进制）"
fi
# 命令行入口（与 .app 内同一个可执行文件）
cp "$BIN" "$BUILD/HardwareInspector"
rm -f "$BUILD/HI.$ARCH" "$BUILD/HI.$OTHER"

echo "[2/6] 写入 Info.plist ..."
cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>          <string>zh_CN</string>
    <key>CFBundleExecutable</key>                 <string>HardwareInspector</string>
    <key>CFBundleIdentifier</key>                 <string>local.workbuddy.HardwareInspector</string>
    <key>CFBundleName</key>                       <string>硬件检测</string>
    <key>CFBundleDisplayName</key>                <string>硬件检测</string>
    <key>CFBundlePackageType</key>                <string>APPL</string>
    <key>CFBundleShortVersionString</key>         <string>1.0</string>
    <key>CFBundleVersion</key>                    <string>1</string>
    <key>CFBundleIconFile</key>                   <string>AppIcon.icns</string>
    <key>LSMinimumSystemVersion</key>             <string>12.0</string>
    <key>LSApplicationCategoryType</key>         <string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key>           <true/>
    <key>NSSupportsAutomaticTermination</key>    <true/>
    <key>NSHumanReadableCopyright</key>          <string>本机离线采集，不联网上传</string>
</dict>
</plist>
PLIST

echo "[3/6] 生成应用图标 ..."
ICONSET="$BUILD/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
xcrun swiftc -O "$ROOT/tools/IconGen.swift" -o "$BUILD/icongen"
"$BUILD/icongen" "$BUILD/icon_1024.png"
for s in 16 32 128 256 512; do
  d=$((s * 2))
  sips -z "$s" "$s" "$BUILD/icon_1024.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z "$d" "$d" "$BUILD/icon_1024.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns"
rm -rf "$ICONSET" "$BUILD/icongen" "$BUILD/icon_1024.png"

echo "[4/6] 拷贝真实品牌 Logo 素材 ..."
LOGOS="$ROOT/Assets/BrandLogos"
if [ -d "$LOGOS" ]; then
  rm -rf "$CONTENTS/Resources/BrandLogos" "$BUILD/BrandLogos"
  mkdir -p "$CONTENTS/Resources/BrandLogos" "$BUILD/BrandLogos"
  cp "$LOGOS"/*.png "$CONTENTS/Resources/BrandLogos/" 2>/dev/null || true
  if [ -f "$LOGOS/SOURCES.json" ]; then
    cp "$LOGOS/SOURCES.json" "$CONTENTS/Resources/BrandLogos/"
  fi
  cp "$CONTENTS/Resources/BrandLogos"/*.png "$BUILD/BrandLogos/" 2>/dev/null || true
  echo "      $(find "$CONTENTS/Resources/BrandLogos" -name '*.png' | wc -l | tr -d ' ') 个真实 Logo 已打包（运行时离线）"
else
  echo "      未找到 Assets/BrandLogos，Logo 将降级为品牌文字（运行 tools/fetch-brand-logos.py 可获取）"
fi

echo "[5/6] Ad-hoc 代码签名 ..."
if codesign --force --sign - "$APP" 2>"$BUILD/codesign.log"; then
  echo "      签名完成"
else
  echo "      签名跳过（不影响本机运行，详见 build/codesign.log）"
fi

echo "[6/6] 完成"
echo ""
echo "  图形界面:  open \"$APP\""
echo "  命令行:    \"$BUILD/HardwareInspector\" --cli"
echo "  JSON 输出: \"$BUILD/HardwareInspector\" --json"
echo ""
