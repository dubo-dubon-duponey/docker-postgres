ARG           BUILDER_BASE=dubodubonduponey/base:builder
ARG           RUNTIME_BASE=dubodubonduponey/base:runtime

#######################
# Extra builder for healthchecker
#######################
# hadolint ignore=DL3006,DL3029
FROM          --platform=$BUILDPLATFORM $BUILDER_BASE                                                                   AS builder-healthcheck

ARG           GIT_REPO=github.com/dubo-dubon-duponey/healthcheckers
ARG           GIT_VERSION=51ebf8ca3d255e0c846307bf72740f731e6210c3

WORKDIR       $GOPATH/src/$GIT_REPO
RUN           git clone git://$GIT_REPO .
RUN           git checkout $GIT_VERSION
# hadolint ignore=DL4006
RUN           env GOOS=linux GOARCH="$(printf "%s" "$TARGETPLATFORM" | sed -E 's/^[^/]+\/([^/]+).*/\1/')" go build -v -ldflags "-s -w" \
                -o /dist/boot/bin/http-health ./cmd/http

#######################
# Goello
#######################
# hadolint ignore=DL3006,DL3029
FROM          --platform=$BUILDPLATFORM $BUILDER_BASE                                                                   AS builder-goello

ARG           GIT_REPO=github.com/dubo-dubon-duponey/goello
ARG           GIT_VERSION=6f6c96ef8161467ab25be45fe3633a093411fcf2

WORKDIR       $GOPATH/src/$GIT_REPO
RUN           git clone git://$GIT_REPO .
RUN           git checkout $GIT_VERSION
# hadolint ignore=DL4006
RUN           env GOOS=linux GOARCH="$(printf "%s" "$TARGETPLATFORM" | sed -E 's/^[^/]+\/([^/]+).*/\1/')" go build -v -ldflags "-s -w" \
                -o /dist/boot/bin/goello-server ./cmd/server/main.go

#######################
# Builder assembly
#######################
# hadolint ignore=DL3006
FROM          $BUILDER_BASE                                                                                             AS builder

COPY          --from=builder-healthcheck /dist/boot/bin /dist/boot/bin
COPY          --from=builder-goello /dist/boot/bin /dist/boot/bin

RUN           chmod 555 /dist/boot/bin/*; \
              epoch="$(date --date "$BUILD_CREATED" +%s)"; \
              find /dist/boot/bin -newermt "@$epoch" -exec touch --no-dereference --date="@$epoch" '{}' +;

#######################
# Running image
#######################
# hadolint ignore=DL3006
FROM          $RUNTIME_BASE

ARG           PG_MAJOR=13
ARG           PG_VERSION=13.0-1.pgdg100+1

USER          root

# hadolint ignore=DL4006
RUN           apt-get update -qq            && \
              apt-get install -qq --no-install-recommends \
                curl=7.64.0-4+deb10u1 \
                gnupg=2.2.12-1+deb10u1      && \
              curl --proto '=https' --tlsv1.2 -sSfL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
              echo "deb http://apt.postgresql.org/pub/repos/apt buster-pgdg main" | tee /etc/apt/sources.list.d/postgres.list && \
              apt-get update -qq            && \
              apt-get install -qq --no-install-recommends \
                postgresql-common=220.pgdg100+1 \
                postgresql-"$PG_MAJOR=$PG_VERSION" && \
              apt-get purge -qq curl gnupg  && \
              apt-get -qq autoremove        && \
              apt-get -qq clean             && \
              rm -rf /var/lib/apt/lists/*   && \
              rm -rf /tmp/*                 && \
              rm -rf /var/tmp/*

USER          dubo-dubon-duponey

COPY          --from=builder --chown=$BUILD_UID:root /dist .

ENV           PATH=/usr/lib/postgresql/$PG_MAJOR/bin/:$PATH
ENV           PGDATA=/data

STOPSIGNAL    SIGINT

EXPOSE        5432
VOLUME        /data
VOLUME        /tmp

# mDNS
ENV           MDNS_NAME="Fancy Postgres Service Name"
ENV           MDNS_HOST="postgres"
ENV           MDNS_TYPE=_postgres._tcp

# Authentication
ENV           USERNAME="dubo-dubon-duponey"
ENV           PASSWORD="nhehehehehe"
ENV           REALM="My precious postgres"

# Log level and port
ENV           PORT=5432

ENV           HEALTHCHECK_URL=http://127.0.0.1:5432/
# XXX replace with nc -zv localhost 5432 or a homegrown version of it
#HEALTHCHECK   --interval=30s --timeout=30s --start-period=10s --retries=1 CMD http-health || exit 1
