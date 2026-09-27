# YTuner container image for MikroTik RouterOS (RB5009 = linux/arm64).
# Builds without emulation: the arm64 libraries are fetched as .deb files and
# unpacked on the build host, so the final stage contains no RUN steps.
ARG YTUNER_VERSION=1.2.6

FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS fetch
ARG YTUNER_VERSION
ARG TARGETARCH
RUN apt-get update && apt-get install -y --no-install-recommends curl unzip ca-certificates
RUN set -e; \
    case "$TARGETARCH" in \
      arm64) ZIP=aarch64-arm64-armv7-armv8-armv9-linux; TRIPLET=aarch64-linux-gnu ;; \
      amd64) ZIP=x86_64-linux; TRIPLET=x86_64-linux-gnu ;; \
      *) echo "unsupported arch $TARGETARCH"; exit 1 ;; \
    esac; \
    dpkg --add-architecture "$TARGETARCH"; apt-get update; \
    mkdir -p /rootfs /tmp/deb; cd /tmp/deb; \
    apt-get download "libsqlite3-0:$TARGETARCH" "libssl3:$TARGETARCH"; \
    for f in *.deb; do dpkg-deb -x "$f" /rootfs; done; \
    # FPC's OpenSSL loader looks for the unversioned names first.
    ln -s libssl.so.3 "/rootfs/usr/lib/$TRIPLET/libssl.so"; \
    ln -s libcrypto.so.3 "/rootfs/usr/lib/$TRIPLET/libcrypto.so"; \
    mkdir -p /rootfs/etc/ssl/certs; cp /etc/ssl/certs/ca-certificates.crt /rootfs/etc/ssl/certs/; \
    cd /tmp; \
    curl -fsSL -o ytuner.zip "https://github.com/coffeegreg/YTuner/releases/download/$YTUNER_VERSION/ytuner-$YTUNER_VERSION-$ZIP.zip"; \
    unzip -q ytuner.zip; \
    mkdir -p /rootfs/opt/ytuner/defaults; \
    cp ytuner-*/ytuner /rootfs/opt/ytuner/; chmod 755 /rootfs/opt/ytuner/ytuner; \
    cp -r ytuner-*/config /rootfs/opt/ytuner/defaults/; \
    # Keep all persistent state under /data (the RouterOS mount). DNS interception
    # is done by RouterOS static DNS entries, so YTuner's own DNS proxy is off.
    sed -e 's|^CacheFolderLocation=.*|CacheFolderLocation=/data|' \
        -e 's|^ConfigFolderLocation=.*|ConfigFolderLocation=/data|' \
        -e 's|^DBFolderLocation=.*|DBFolderLocation=/data|' \
        -e 's|^MessageInfoLevel=.*|MessageInfoLevel=1|' \
        -e 's|^RBCacheType=.*|RBCacheType=catPermMemDB|' \
        -e '/^\[DNSServer\]/,/^\[/ s|^Enable=1|Enable=0|' \
        ytuner-*/ytuner.ini > /rootfs/opt/ytuner/defaults/ytuner.ini

FROM debian:bookworm-slim
COPY --from=fetch /rootfs/ /
COPY --chmod=755 entrypoint.sh /entrypoint.sh
EXPOSE 80/tcp
VOLUME /data
ENTRYPOINT ["/entrypoint.sh"]
