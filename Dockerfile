ARG ALPINE_VER="3.10"
ARG BASEIMAGE_ARCH="amd64"
ARG DOCKER_ARCH="amd64"
ARG LIBTORRENT_VER="1.2.6"

FROM kurapov/alpine-jemalloc:latest-${DOCKER_ARCH} AS jemalloc

FROM wiserain/libtorrent:${LIBTORRENT_VER}-alpine${ALPINE_VER}-py3 AS libtorrent

FROM ${BASEIMAGE_ARCH}/alpine:${ALPINE_VER}

ARG QEMU_ARCH

ARG BRANCH="none"
ARG COMMIT="local-build"
ARG BUILD_DATE="1970-01-01T00:00:00Z"
ARG NAME="kurapov/flexget-libtorrent"
ARG VCS_URL="https://github.com/2sheds/flexget-libtorrent"

ARG UID=1000
ARG GUID=1000
ARG MAKEFLAGS=-j4
ARG VERSION="3.1.51"
ARG DEPS="linux-headers openssl-dev unzip git"
ARG PACKAGES="openssl boost-python3 libstdc++ nodejs python3-dev"
ARG PLUGINS="transmission-rpc cloudscraper deluge-client rarfile sleekxmpp subliminal"

LABEL \
  org.opencontainers.image.authors="Oleg Kurapov <oleg@kurapov.com>" \
  org.opencontainers.image.title="${NAME}" \
  org.opencontainers.image.created="${BUILD_DATE}" \
  org.opencontainers.image.revision="${COMMIT}" \
  org.opencontainers.image.version="${VERSION}" \
  org.opencontainers.image.source="${VCS_URL}"

#__CROSS_COPY qemu-${QEMU_ARCH}-static /usr/bin/

WORKDIR /usr/src

RUN apk add --update-cache ${PACKAGES} && \
    apk add --virtual=build-dependencies build-base libffi-dev ${DEPS} && \
    addgroup -g ${GUID} flexget && \
    adduser -D -G flexget -s /bin/sh -u ${UID} flexget && \
    wget https://bootstrap.pypa.io/get-pip.py && \
    python3 get-pip.py && \
    pip3 install --no-cache-dir --prefer-binary --upgrade --force-reinstall flexget==${VERSION} && \
    pip3 install --no-cache-dir --prefer-binary ${PLUGINS} && \
    FLEXGET_PATH=$(python3 -c 'import os, flexget; print (os.path.dirname(flexget.__file__))') && \
    wget https://github.com/Flexget/webui/releases/latest/download/dist.zip && \
    unzip dist.zip && \
    rm dist.zip && \
    cp -R dist ${FLEXGET_PATH}/ui/v2/ && \
    apk del build-dependencies && \
    rm -rf /tmp/* /var/tmp/* /usr/src/* /var/cache/apk/*

WORKDIR /config

VOLUME /config

COPY --from=jemalloc /usr/local/lib/libjemalloc.so* /usr/local/lib/

COPY --from=libtorrent /libtorrent-build/usr/lib/ /usr/lib/

ENV LD_PRELOAD=/usr/local/lib/libjemalloc.so.2
ENV PYTHONUNBUFFERED 1

EXPOSE 5050 

ENTRYPOINT ["flexget", "daemon", "start", "--autoreload-config"]

