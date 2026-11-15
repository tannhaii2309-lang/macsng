#!/bin/bash
# Tạo dist/SngTrans.app (chạy được cả chip Apple lẫn Intel) và dist/SngTrans.dmg
set -e
cd "$(dirname "$0")"
swift build -c release --arch arm64 --arch x86_64
BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)
APP=dist/SngTrans.app
rm -rf dist && mkdir -p $APP/Contents/MacOS $APP/Contents/Resources
cp "$BIN/SngTrans" $APP/Contents/MacOS/SngTrans
cp Info.plist $APP/Contents/Info.plist
[ -f AppIcon.icns ] && cp AppIcon.icns $APP/Contents/Resources/ && \
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" $APP/Contents/Info.plist
codesign --force --deep --sign - $APP
hdiutil create -volname SngTrans -srcfolder $APP -ov -format UDZO dist/SngTrans.dmg >/dev/null
echo "Xong: $APP và dist/SngTrans.dmg"
