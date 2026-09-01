#!/bin/bash
# Builds the Xposed module APK without Gradle.
set -e
cd "$(dirname "$0")"

export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
SDK="$HOME/android-sdk"
BT="$SDK/build-tools/35.0.0"
ANDROID_JAR="$SDK/platforms/android-35/android.jar"

rm -rf build
mkdir -p build/classes build/dex

# 1. Compile module + compile-only API stubs.
"$JAVA_HOME/bin/javac" --release 8 -nowarn -d build/classes \
  $(find stub src -name '*.java')

# 2. Dex ONLY our own classes. The de.robv.* stubs must stay out of the APK,
#    otherwise they would shadow the real framework classes at runtime.
"$BT/d8" --min-api 26 --lib "$ANDROID_JAR" --classpath build/classes \
  --output build/dex build/classes/dev/gmsver/*.class

# 3. Resources + manifest -> base APK (assets carry xposed_init).
"$BT/aapt2" compile --dir res -o build/res.zip
"$BT/aapt2" link -I "$ANDROID_JAR" \
  --manifest AndroidManifest.xml \
  -A assets \
  --min-sdk-version 26 --target-sdk-version 35 \
  -o build/unsigned.apk build/res.zip

# 4. Add the dex at the APK root.
python3 -c "
import zipfile
z = zipfile.ZipFile('build/unsigned.apk', 'a', zipfile.ZIP_DEFLATED)
z.write('build/dex/classes.dex', 'classes.dex')
z.close()
"

# 5. Align, then sign (v2+; Android 15 rejects v1-only signatures).
"$BT/zipalign" -f 4 build/unsigned.apk build/aligned.apk
if [ ! -f build/../key.jks ]; then
  "$JAVA_HOME/bin/keytool" -genkeypair -keystore key.jks -alias gmsver \
    -storepass android -keypass android -keyalg RSA -keysize 2048 \
    -validity 10000 -dname "CN=gmsver" >/dev/null 2>&1 || true
fi
"$BT/apksigner" sign --ks key.jks --ks-pass pass:android --key-pass pass:android \
  --out build/gmsver.apk build/aligned.apk

echo "BUILD OK -> $(pwd)/build/gmsver.apk"
