ARG           FROM_REGISTRY=ghcr.io/dubo-dubon-duponey

ARG           FROM_IMAGE_BUILDER=base:builder-bullseye-2021-07-01@sha256:f1c46316c38cc1ca54fd53b54b73797b35ba65ee727beea1a5ed08d0ad7e8ccf
ARG           FROM_IMAGE_RUNTIME=base:runtime-bullseye-2021-07-01@sha256:9f5b20d392e1a1082799b3befddca68cee2636c72c502aa7652d160896f85b36
ARG           FROM_IMAGE_TOOLS=tools:linux-bullseye-2021-07-01@sha256:f1e25694fe933c7970773cb323975bb5c995fa91d0c1a148f4f1c131cbc5872c

FROM          $FROM_REGISTRY/$FROM_IMAGE_TOOLS                                                                          AS builder-tools

#######################
# Builder assembly
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_BUILDER                                              AS builder

RUN           mkdir -p /dist/boot/bin

COPY          --from=builder-tools  /boot/bin/goello-server  /dist/boot/bin
COPY          --from=builder-tools  /boot/bin/http-health    /dist/boot/bin

RUN           chmod 555 /dist/boot/bin/*; \
              epoch="$(date --date "$BUILD_CREATED" +%s)"; \
              find /dist/boot -newermt "@$epoch" -exec touch --no-dereference --date="@$epoch" '{}' +;

#######################
# Running image
#######################
FROM          $FROM_REGISTRY/$FROM_IMAGE_RUNTIME

ARG           PG_MAJOR=13
ARG           PG_VERSION=13+226.pgdg110+1
ARG           PG_COMMON=226.pgdg110+1

USER          root

RUN           --mount=type=secret,uid=100,id=CA \
              --mount=type=secret,uid=100,id=CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY \
              --mount=type=secret,uid=100,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              --mount=type=secret,id=.curlrc \
              apt-get update -qq            && \
              apt-get install -qq --no-install-recommends \
                curl=7.74.0-1.2 \
                gnupg=2.2.27-2      && \
              curl -sSfL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
              echo "deb http://apt.postgresql.org/pub/repos/apt bullseye-pgdg main" | tee /etc/apt/sources.list.d/postgres.list && \
              apt-get update -qq            && \
              apt-get install -qq --no-install-recommends \
                postgresql-common="$PG_COMMON" \
                postgresql-"$PG_MAJOR=$PG_VERSION" && \
              apt-get purge -qq curl gnupg  && \
              apt-get -qq autoremove        && \
              apt-get -qq clean             && \
              rm -rf /var/lib/apt/lists/*   && \
              rm -rf /tmp/*                 && \
              rm -rf /var/tmp/*

USER          dubo-dubon-duponey

COPY          --from=builder --chown=$BUILD_UID:root /dist /

ENV           PATH=/usr/lib/postgresql/$PG_MAJOR/bin/:$PATH
ENV           PGDATA=/data

STOPSIGNAL    SIGINT

EXPOSE        5432
VOLUME        /data
VOLUME        /tmp

# mDNS
ENV           MDNS_NAME="Postgres mDNS display name"
ENV           MDNS_HOST="postgres"
ENV           MDNS_TYPE=_postgres._tcp

# Realm in case access is authenticated
ENV           REALM="My Precious Realm"
# Provide username and password here (call the container with the "hash" command to generate a properly encrypted password, otherwise, a random one will be generated)
ENV           USERNAME=""
ENV           PASSWORD=""

# Log level and port
ENV           PORT=5432

ENV           HEALTHCHECK_URL=http://127.0.0.1:5432/
# XXX replace with nc -zv localhost 5432 or a homegrown version of it
#HEALTHCHECK   --interval=30s --timeout=30s --start-period=10s --retries=1 CMD http-health || exit 1
