ARG ALPINE_VER="3.10"
ARG BASEIMAGE_ARCH="amd64"
ARG DOCKER_ARCH="amd64"

FROM kurapov/alpine-jemalloc:latest-${DOCKER_ARCH} AS jemalloc

FROM ${BASEIMAGE_ARCH}/alpine:${ALPINE_VER}

ARG QEMU_ARCH

ARG BRANCH="none"
ARG COMMIT="local-build"
ARG BUILD_DATE="1970-01-01T00:00:00Z"
ARG NAME="kurapov/alpine-flexget"
ARG VCS_URL="https://github.com/2sheds/alpine-flexget"

ARG UID=1000
ARG GUID=1000
ARG MAKEFLAGS=-j4
ARG VERSION="3.1.51"
ARG LIBTORRENT_VER="1.2.6"
ARG DEPS="python3-dev py3-lxml boost-python3 freetype-dev jpeg-dev lcms2-dev libpng-dev libwebp-dev libxml2-dev libxslt-dev openjpeg-dev openssl-dev tiff-dev zlib-dev"
ARG PACKAGES="freetype git lcms2 libjpeg-turbo libwebp openjpeg openssl p7zip tar tiff unrar unzip vnstat xz zlib"
ARG PLUGINS="configparser ndg-httpsclient notify paramiko pillow psutil pyopenssl requests setuptools urllib3i transmissionrpc" 
#urllib3[socks] chardet cloudscraper rarfile sleekxmpp subliminal

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
    pip3 install --no-cache-dir --prefer-binary ${PLUGINS} flexget=="${VERSION}" && \
    wget -O - https://github.com/arvidn/libtorrent/releases/download/libtorrent-${LIBTORRENT_VER}/libtorrent-rasterbar-${LIBTORRENT_VER}.tar.gz | tar -zxf - -C /usr/src && \
    ./configure --prefix=/usr --sysconfdir=/etc --mandir=/usr/share/man --localstatedir=/var --enable-python-binding \
        --with-boost-system=boost_python$(python3 -c 'import sys; print("{}{}".format(sys.version_info.major, sys.version_info.minor))') && \
    make && make install && \
    apk del build-dependencies && \
    rm -rf /tmp/* /var/tmp/* /usr/src /var/cache/apk/*

COPY --from=jemalloc /usr/local/lib/libjemalloc.so* /usr/local/lib/

ENV LD_PRELOAD=/usr/local/lib/libjemalloc.so.2

EXPOSE 5050 

ENTRYPOINT ["flexget", "daemon", "start", "--autoreload-config"]

