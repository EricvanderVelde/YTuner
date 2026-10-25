#!/bin/sh
# Compile YTuner from /build/src with the FPC 3.3.1 toolchain of the Dockerfile.
# Usage: build-ytuner.sh arm64|amd64   (Docker TARGETARCH names)
set -e
case "$1" in
  arm64) CPU=aarch64; PPC=ppcrossa64
         LINK="-XPaarch64-linux-gnu- -Fl/usr/aarch64-linux-gnu/lib -Fl/usr/lib/aarch64-linux-gnu -FL/lib/ld-linux-aarch64.so.1" ;;
  amd64) CPU=x86_64; PPC=ppcx64
         LINK="-Fl/usr/lib/x86_64-linux-gnu -FL/lib64/ld-linux-x86-64.so.2" ;;
  *) echo "unsupported arch $1"; exit 1 ;;
esac
FPC=/opt/fpc/lib/fpc/3.3.1
UNITS=$FPC/units/$CPU-linux
INDY=/opt/indy/Lib
export PATH=/opt/fpc/bin:$PATH

# The SQL scripts are embedded as zipped resources (see res/sql.rc and script/zip-sql.bat).
cd /build/res
for f in ../src/sql/*.sql; do
  b=${f##*/}
  zip -qjX "${b%.sql}.zip" "$f"
done

# Same options as the "Release linux64 aarch64" build mode in ytuner.lpi.
cd /build
mkdir -p lib bin
$FPC/$PPC -n -Tlinux -MObjFPC -Scghi -O3 -CX -XX -Xs -vew -l- -FF \
  -Fu$UNITS/rtl -Fu"$UNITS/*" -Fu/usr/lib/lazarus/2.2.6/components/lazutils \
  -Fu$INDY/System -Fu$INDY/Core -Fu$INDY/Protocols \
  -Fi$INDY/System -Fi$INDY/Core -Fi$INDY/Protocols \
  $LINK -FUlib -FEbin src/ytuner.pas
