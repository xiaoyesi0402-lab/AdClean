#!/usr/bin/env bash
# AdClean 构建脚本（无需 Android Studio / Gradle）
#
# 依赖：
#   JAVA_HOME   JDK 11+
#   AAPT        aapt 可执行文件（Android SDK build-tools）
#   SMALI_JAR   smali.jar（https://github.com/JesusFreke/smali）
#   APKSIGNER   apksigner 可执行文件（Android SDK build-tools）
#   FRAMEWORK   framework-res.apk（用于 aapt 解析 android: 属性）
#   KEYSTORE    签名用 keystore（不存在会自动生成一个 debug 的）

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/source"
OUT="$ROOT/build"
DIST="$ROOT/dist"

AAPT="${AAPT:-aapt}"
SMALI_JAR="${SMALI_JAR:-smali.jar}"
APKSIGNER="${APKSIGNER:-apksigner}"
FRAMEWORK="${FRAMEWORK:-$ROOT/framework-res.apk}"
KEYSTORE="${KEYSTORE:-$ROOT/debug.keystore}"

command -v java >/dev/null || { echo "!! 找不到 java，请设置 JAVA_HOME"; exit 1; }
[ -f "$FRAMEWORK" ] || { echo "!! 找不到 $FRAMEWORK（framework-res.apk）"; exit 1; }

rm -rf "$OUT"; mkdir -p "$OUT" "$DIST"

echo "==> 1/4 汇编 smali -> classes.dex"
if [ -n "${SMALI_CP:-}" ]; then
  # 用拆分好的 jar（如 Debian 的 libsmali-java）：SMALI_CP 指向 jar 目录通配
  java -cp "$SMALI_CP" org.jf.smali.Main assemble "$SRC/smali" -o "$OUT/classes.dex"
else
  java -jar "$SMALI_JAR" assemble "$SRC/smali" -o "$OUT/classes.dex"
fi

echo "==> 2/4 打包 Manifest 与资源"
"$AAPT" package -f \
  -M "$SRC/AndroidManifest.xml" \
  -A "$SRC/assets" \
  -F "$OUT/base.apk" \
  -I "$FRAMEWORK" \
  --min-sdk-version 24 \
  --target-sdk-version 33

echo "==> 3/4 加入 classes.dex"
python3 - "$OUT" <<'PY'
import sys, zipfile, shutil, os
out = sys.argv[1]
shutil.copy(os.path.join(out, "base.apk"), os.path.join(out, "stage.apk"))
with zipfile.ZipFile(os.path.join(out, "stage.apk"), "a", zipfile.ZIP_DEFLATED) as z:
    z.write(os.path.join(out, "classes.dex"), "classes.dex")
PY

echo "==> 4/4 签名"
if [ ! -f "$KEYSTORE" ]; then
  echo "    生成调试 keystore ..."
  keytool -genkeypair -keystore "$KEYSTORE" -alias andro \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass android -keypass android \
    -dname "CN=Android Debug,O=Android,C=US"
fi

"$APKSIGNER" sign --ks "$KEYSTORE" --ks-pass pass:android --key-pass pass:android \
  --out "$DIST/AdClean.apk" "$OUT/stage.apk"

echo "==> 完成: $DIST/AdClean.apk"
sha256sum "$DIST/AdClean.apk" 2>/dev/null || true
