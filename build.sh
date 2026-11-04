#!/bin/bash
# Builds the release assets into dist/:
#   de22ev-wireless-aa-<version>.zip       the HMG-API mod package (signed when SIGN_KEY is set)
#   de22ev-wireless-aa-<version>.USB.zip   the NEMESIS USB kit that installs it
#   SHA256SUMS
#
# Needs: a JDK 8+ (JAVA_HOME or on PATH), Python 3, curl, and D8 (D8_JAR: a jar with
# com.android.tools.r8.D8, e.g. r8.jar from https://maven.google.com/web/index.html#com.android.tools:r8).
# SIGN_KEY: the author's private key (kept outside the repository). Without it the
# package is built unsigned, which is enough to compare against a release's manifest.
# HMGSIGN_SRC: a folder with HMG-API's Signing.java and Json.java, instead of fetching them.
set -euo pipefail
cd "$(dirname "$0")"
ROOT=$PWD
JAVA_BIN=${JAVA_HOME:+$JAVA_HOME/bin/}
PY=${PYTHON:-python}
: "${D8_JAR:?set D8_JAR to a jar containing com.android.tools.r8.D8}"
native() { if command -v cygpath > /dev/null; then cygpath -w "$1"; else echo "$1"; fi; }

VERSION=$("$PY" -c "import json;print(json.load(open('mod/mod.json'))['version'])")
ID=$("$PY" -c "import json;print(json.load(open('mod/mod.json'))['id'])")
UUID=$(tr -d '\r\n' < keys/uuid.txt)
PKG=$ID-$VERSION.zip
grep -q "^ZIP=$PKG\$" usb/WAA_AA_MOD/run.sh || { echo "usb/WAA_AA_MOD/run.sh does not name $PKG" >&2; exit 1; }
grep -q "^UUID=$UUID\$" usb/WAA_AA_MOD/run.sh || { echo "usb/WAA_AA_MOD/run.sh does not name uuid $UUID" >&2; exit 1; }
echo "building $ID $VERSION"

rm -rf build dist
mkdir -p build/classes build/dex build/mod build/usb build/hmgsign dist

# WaaAp: plain Java 8 (Android APIs by reflection), dexed for Android 4.4
"${JAVA_BIN}javac" --release 8 -Xlint:-options -encoding UTF-8 -d "$(native build/classes)" "$(native src/WaaAp.java)"
CLASSES=()
for c in build/classes/*.class; do CLASSES+=("$(native "$c")"); done
"${JAVA_BIN}java" -cp "$(native "$D8_JAR")" com.android.tools.r8.D8 --min-api 19 --no-desugaring --release \
    --output "$(native build/dex)" "${CLASSES[@]}"
mkdir -p build/jar && cp build/dex/classes.dex build/jar/
"$PY" tools/zipdir.py build/jar build/waaap.jar

# the mod folder
cp mod/mod.json mod/README.en.txt mod/README.ko.txt build/mod/
mkdir -p build/mod/svc && cp mod/svc/waad.sh build/mod/svc/
cp build/waaap.jar build/mod/

# the signer: HMG-API's Signing + Json at a pinned commit, with tools/hmgsign/Engine.java
HMG_COMMIT=4fab4376adae65b67025046539963a68fb37f76f
mkdir -p build/hmgsign-src/hmgapi/engine
for f in Signing Json; do
    if [ -n "${HMGSIGN_SRC:-}" ]; then
        cp "$HMGSIGN_SRC/$f.java" build/hmgsign-src/hmgapi/engine/
    else
        curl -fsSL "https://raw.githubusercontent.com/VysseCodes/HMG-API/$HMG_COMMIT/core/runtime/java/hmgapi/engine/$f.java" \
            -o build/hmgsign-src/hmgapi/engine/$f.java
    fi
done
cp tools/hmgsign/Engine.java build/hmgsign-src/hmgapi/engine/
"${JAVA_BIN}javac" -nowarn -encoding UTF-8 -d "$(native build/hmgsign)" \
    "$(native build/hmgsign-src/hmgapi/engine/Signing.java)" "$(native build/hmgsign-src/hmgapi/engine/Json.java)" \
    "$(native build/hmgsign-src/hmgapi/engine/Engine.java)"
SIGNER=("${JAVA_BIN}java" -cp "$(native build/hmgsign)" hmgapi.engine.Signing)

if [ -n "${SIGN_KEY:-}" ]; then
    "${SIGNER[@]}" sign "$(native build/mod)" "$(native "$SIGN_KEY")"
    "${SIGNER[@]}" verify "$(native build/mod)" "$UUID"
else
    echo "SIGN_KEY not set: the package is unsigned (HMG-API refuses it without overrides)"
fi
"$PY" tools/zipdir.py build/mod "dist/$PKG"

# the NEMESIS USB kit, with the same jar and package inside
cp -r usb/. build/usb/
cp build/waaap.jar build/usb/WAA_AA_MOD/
cp "dist/$PKG" build/usb/WAA_AA_MOD/
"$PY" tools/zipdir.py build/usb "dist/$ID-$VERSION.USB.zip"

(cd dist && sha256sum "$PKG" "$ID-$VERSION.USB.zip" > SHA256SUMS)
cat dist/SHA256SUMS
