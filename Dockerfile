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
ARG PACKAGES="openssl boost-python3 libstdc++ nodejs"
ARG PLUGINS="transmissionrpc cloudscraper deluge-client rarfile sleekxmpp subliminal"

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
    pip3 install --upgrade pip && \
    pip3 install --no-cache-dir --prefer-binary ${PLUGINS} && \
    # Build master branch from source (workaround until v3.1.52 removes pillow dependency)
    pip3 install --upgrade setuptools wheel && \
    git clone -b master --depth 1 https://github.com/Flexget/Flexget.git flexget && \
    pip3 wheel -e ./flexget && \
    pip3 install --no-cache-dir --no-index --force-reinstall -f . flexget && \
    FLEXGET_PATH=$(python3 -c 'import os, flexget; print (os.path.dirname(flexget.__file__))') && \
    wget https://github.com/Flexget/webui/releases/latest/download/dist.zip && \
    unzip dist.zip && \
    rm dist.zip && \
    cp -R dist ${FLEXGET_PATH}/ui/v2/ && \
    apk del build-dependencies && \
    rm -rf /tmp/* /var/tmp/* /usr/src/* /root/.cache/pip /var/cache/apk/*

WORKDIR /config

VOLUME /config

COPY --from=jemalloc /usr/local/lib/libjemalloc.so* /usr/local/lib/

COPY --from=libtorrent /libtorrent-build/usr/lib/ /usr/lib/

ENV LD_PRELOAD=/usr/local/lib/libjemalloc.so.2

EXPOSE 5050 

ENTRYPOINT ["flexget", "daemon", "start", "--autoreload-config"]

