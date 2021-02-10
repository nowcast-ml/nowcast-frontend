ARG ALPINE_VERSION=3.13.1
ARG CADDY_VERSION=2.3.0
ARG TINI_VERSION=0.19.0
ARG NODE_VERSION=15.8.0-alpine3.12


FROM alpine:${ALPINE_VERSION} AS base
RUN apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community \
    ca-certificates \
    tzdata


FROM base AS binaries
ARG CADDY_VERSION
ARG TINI_VERSION
WORKDIR /opt/bin
ENV PATH /opt/bin:${PATH}
RUN apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community \
    curl \
    tar
RUN curl -s -L -o ./tini "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-static-amd64" \
 && chmod +x ./tini \
 && chown root:root ./tini \
 && chmod +rw ./tini \
 && ./tini --version
RUN curl -s -L "https://github.com/caddyserver/caddy/releases/download/v${CADDY_VERSION}/caddy_${CADDY_VERSION}_linux_amd64.tar.gz" \
    | tar xz caddy \
 && chown root:root ./caddy \
 && chmod +rw ./caddy \
 && ./caddy version


FROM node:${NODE_VERSION} AS build
WORKDIR /app
ENV PATH /app/node_modules/.bin:${PATH}
COPY package.json ./
COPY yarn.lock ./
RUN yarn
COPY . ./
RUN yarn build


FROM base
ARG ALPINE_VERSION
ARG CADDY_VERSION
ARG TINI_VERSION

LABEL maintainer="Sebastian Klatt <sebastian@markow.io>"
LABEL st.nowca.image.alpine.version="${ALPINE_VERSION}"
LABEL st.nowca.image.caddy.version="${CADDY_VERSION}"
LABEL st.nowca.image.tini.version="${tini_VERSION}"

WORKDIR /app
ENV UID=10000
ENV GID=10001

RUN addgroup \
    -g "${GID}" \
    app \
 && adduser \
    -D \
    -g "" \
    -h "$(pwd)" \
    -G app \
    -u "${UID}" \
    app
COPY --from=binaries /opt/bin/tini /bin/tini
COPY --from=binaries /opt/bin/caddy /bin/caddy
COPY --from=build /app/build ./www
COPY Caddyfile .

USER app
EXPOSE 8080

ENTRYPOINT ["/bin/tini", "--"]
CMD ["/bin/caddy", "run"]

