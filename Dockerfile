FROM golang:1.21-buster as builder

ARG DEPENDENCIES="\
    dpkg-dev \
    git \
    make \
    pkg-config\
    libseccomp-dev \
    btrfs-progs \
    gcc"

RUN set -ex; \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime; \
    apt-get update; \
    apt-get install -y ${DEPENDENCIES}; \
    rm -rf /var/lib/apt/lists/*

ARG CONTAINERD_VERSION=v1.7.9

ENV CONTAINERD_VERSION=${CONTAINERD_VERSION}
ENV GOPROXY=https://goproxy.io

ARG WORKDIR=/opt/containerd

RUN set -ex; \
    git clone -b ${CONTAINERD_VERSION} --depth=1 https://github.com/containerd/containerd ${WORKDIR}

WORKDIR ${WORKDIR}

RUN set -ex; \
    sed -i 's@|| riscv64@|| riscv64 || loong64@g' vendor/github.com/cilium/ebpf/internal/endian_le.go; \
    sed -i 's@ppc64le riscv64@ppc64le riscv64 loong64@g' vendor/github.com/cilium/ebpf/internal/endian_le.go; \
    sed -i "s@--dirty='.m' @@g" Makefile; \
    sed -i 's@$(shell if ! git diff --no-ext-diff --quiet --exit-code; then echo .m; fi)@@g' Makefile; \
    go mod tidy

RUN set -ex; \
    make release; \
    mkdir dist; \
    cp -f releases/containerd-* dist/

FROM debian:buster-slim

WORKDIR /opt/containerd

COPY --from=builder /opt/containerd/dist /opt/containerd/dist

VOLUME /dist

CMD cp -rf dist/* /dist/