FROM lansible/upx:latest as upx

#######################################################################################################################
# Build static mold
#######################################################################################################################
FROM alpine:3.18 as builder

# https://github.com/rui314/mold/releases
ENV VERSION=v1.11.0

# Add unprivileged user
RUN echo "mold:x:1000:1000:mold:/:" > /etc_passwd

# hadolint ignore=DL3018
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

WORKDIR /mold/build

RUN cmake -DCMAKE_BUILD_TYPE=Release -DMOLD_MOSTLY_STATIC=true .. && \
  cmake --build . -j "$(nproc)" && \
  cmake --install .

# 'Install' upx from image since upx isn't available for aarch64 from Alpine
COPY --from=upx /usr/bin/upx /usr/bin/upx
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
