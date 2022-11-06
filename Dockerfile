#######################################################################################################################
# Build static mold
#######################################################################################################################
FROM alpine:3.16 as builder

# https://github.com/rui314/mold/releases
ENV VERSION=v1.6.0

# Add unprivileged user
RUN echo "mold:x:1000:1000:mold:/:" > /etc_passwd

RUN apk --no-cache add \
        git \
        build-base \
        linux-headers \
        cmake \
        clang \
        clang-static \
        lld \
        libstdc++ \
        zlib-dev \
        zlib-static \
        libressl-dev

RUN git clone --depth 1 --single-branch --branch "${VERSION}" https://github.com/rui314/mold.git /mold

WORKDIR /mold

# LDFLAGS source (removed from main): https://github.com/rui314/mold/blob/v1.0.3/build-static.sh
RUN CORES=$(grep -c '^processor' /proc/cpuinfo); \
    export MAKEFLAGS="-j$((CORES+1)) -l${CORES}"; \
    make \
      CC=clang \
      CXX=clang++ \
      LDFLAGS='-fuse-ld=lld -static -Wl,-u,pthread_rwlock_rdlock -Wl,-u,pthread_rwlock_unlock -Wl,-u,pthread_rwlock_wrlock' \
      LTO=1 && \
    make install

# 'Install' upx from image since upx isn't available for aarch64 from Alpine
COPY --from=lansible/upx /usr/bin/upx /usr/bin/upx
# Minify binaries
# No upx: 16.3M
# upx: 4.8M
# --best: 4.7M
# --brute: breaks the executable
RUN upx --best /usr/local/bin/mold && \
    upx -t /usr/local/bin/mold


#######################################################################################################################
# Final scratch image
#######################################################################################################################
FROM scratch

# Add description
LABEL org.label-schema.description="Static compiled Mold in a scratch container"

# Copy the unprivileged user
COPY --from=builder /etc_passwd /etc/passwd

# Copy static binary
COPY --from=builder /usr/local/bin/mold /usr/local/bin/mold

# Add symlink for use with GCC -B
COPY --from=builder /usr/local/libexec/mold /usr/local/libexec/mold

USER mold
ENTRYPOINT ["/usr/local/bin/mold"]
