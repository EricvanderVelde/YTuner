# YTuner container image for MikroTik RouterOS (RB5009 = linux/arm64).
# YTuner is compiled from this repository's source on an x86_64 build host
# (cross-compiled for arm64), so no ARM emulation is needed. The runtime
# libraries are fetched as .deb files and unpacked, so the final stage
# contains no RUN steps either.
#
# Build from the repository root: docker buildx build -f mikrotik/Dockerfile .

# Default config files come from this official release (the repository's cfg/avr.ini
# has example filters enabled).
ARG YTUNER_RELEASE=1.2.6
# FPC 3.3.1 (main branch) at the commit used for the official YTuner 1.2.6 binaries.
ARG FPC_COMMIT=29b14fec57
ARG INDY_COMMIT=bd38a62c0089e5e40eeb00569a09b8a8410b8d7d

FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS toolchain
ARG FPC_COMMIT
ARG INDY_COMMIT
RUN dpkg --add-architecture arm64 && apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      fp-compiler-3.2.2 fp-units-rtl-3.2.2 lazarus-src-2.2 \
      binutils-aarch64-linux-gnu libc6-dev-arm64-cross libc6-dev libsqlite3-dev libsqlite3-dev:arm64 \
      curl ca-certificates git make zip
# Bootstrap FPC 3.3.1 with Debian's 3.2.2: a native x86_64 compiler, then the aarch64 cross compiler.
RUN set -e; \
    curl -fsSL "https://gitlab.com/freepascal.org/fpc/source/-/archive/$FPC_COMMIT/source-$FPC_COMMIT.tar.gz" | tar xz -C /tmp; \
    cd /tmp/source-$FPC_COMMIT; \
    make all install PP=ppcx64 INSTALL_PREFIX=/opt/fpc FPMAKEOPT="-T $(nproc)"; \
    make distclean; \
    make crossall crossinstall CPU_TARGET=aarch64 OS_TARGET=linux BINUTILSPREFIX=aarch64-linux-gnu- \
      PP=/opt/fpc/lib/fpc/3.3.1/ppcx64 INSTALL_PREFIX=/opt/fpc FPMAKEOPT="-T $(nproc)"; \
    rm -rf /tmp/source-$FPC_COMMIT
RUN git init -q /opt/indy && cd /opt/indy && \
    git fetch -q --depth 1 https://github.com/IndySockets/Indy.git "$INDY_COMMIT" && \
    git checkout -q FETCH_HEAD

FROM --platform=$BUILDPLATFORM toolchain AS build
ARG TARGETARCH
COPY src /build/src
COPY res /build/res
COPY --chmod=755 mikrotik/build-ytuner.sh /usr/local/bin/build-ytuner
RUN build-ytuner "$TARGETARCH"

FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS fetch
ARG YTUNER_RELEASE
ARG TARGETARCH
RUN apt-get update && apt-get install -y --no-install-recommends curl unzip ca-certificates
RUN set -e; \
    case "$TARGETARCH" in \
      arm64) TRIPLET=aarch64-linux-gnu ;; \
      amd64) TRIPLET=x86_64-linux-gnu ;; \
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
    curl -fsSL -o ytuner.zip "https://github.com/coffeegreg/YTuner/releases/download/$YTUNER_RELEASE/ytuner-$YTUNER_RELEASE-x86_64-linux.zip"; \
    unzip -q ytuner.zip; \
    mkdir -p /rootfs/opt/ytuner/defaults; \
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
COPY --from=build /build/bin/ytuner /opt/ytuner/ytuner
COPY --chmod=755 mikrotik/entrypoint.sh /entrypoint.sh
EXPOSE 80/tcp
VOLUME /data
ENTRYPOINT ["/entrypoint.sh"]
