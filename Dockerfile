# syntax = docker/dockerfile:1.10

FROM docker.io/node:22-slim@sha256:4b44c32c9f3118d60977d0dde5f758f63c4f9eac8ddee4275277239ec600950f AS assets

ENV NODE_ENV=production
ENV YARN_CACHE_FOLDER=/cache/yarn

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN mkdir --parents /opt/openmensa
WORKDIR /opt/openmensa

COPY .yarnrc.yml package.json yarn.lock rspack.config.mjs app/javascripts /opt/openmensa/
RUN --mount=type=cache,target=/cache/yarn <<EOF
  corepack enable
  yarn install --immutable
EOF

COPY rspack.config.mjs /opt/openmensa/
COPY app/javascripts/ /opt/openmensa/app/javascripts/
RUN <<EOF
  yarn build --mode production
EOF


FROM docker.io/ruby:3.3.6-slim-bullseye@sha256:8f8440417c25eefc9f34b09a1a04841c7ec27a4ad825cd6d44da0bb48076842b AS build

ENV RAILS_ENV=production
ENV RAILS_GROUPS=assets
ENV SKIP_JS_BUILD=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN mkdir --parents /opt/openmensa
WORKDIR /opt/openmensa

# Install build dependencies for gems with native extensions
RUN <<EOF
  apt-get --yes --quiet update
  apt-get --yes --quiet install \
    build-essential \
    libpq-dev
EOF

COPY Gemfile Gemfile.lock /opt/openmensa/
RUN <<EOF
  gem install bundler -v "$(grep -A 1 "BUNDLED WITH" Gemfile.lock | tail -n 1)"
  bundle config set --local deployment 'true'
  bundle config set --local without 'development test'
  bundle install --jobs 4 --retry 3
EOF

# Note: see also .dockerignore
COPY . /opt/openmensa/
RUN <<EOF
  bundle exec rake assets:precompile
  rm -rf /opt/openmensa/log /opt/openmensa/tmp
EOF


FROM docker.io/ruby:3.3.6-slim-bullseye@sha256:8f8440417c25eefc9f34b09a1a04841c7ec27a4ad825cd6d44da0bb48076842b

ENV RAILS_ENV=production

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=assets /opt/openmensa /opt/openmensa
COPY --from=build /opt/openmensa /opt/openmensa
WORKDIR /opt/openmensa

# Install native runtime dependencies
RUN <<EOF
  apt-get --yes --quiet update
  apt-get --yes --quiet install --no-install-recommends libpq5
  rm -rf /var/lib/apt/lists/*
EOF

RUN <<EOF
  gem install bundler -v "$(grep -A 1 "BUNDLED WITH" Gemfile.lock | tail -n 1)"
  bundle config set --local deployment 'true'
  bundle config set --local without 'development test'
  mkdir --parents /etc/openmensa /var/log/openmensa /mnt/www
  ln --symbolic /tmp /opt/openmensa/tmp
  ln --symbolic /var/log/openmensa /opt/openmensa/log
  ln --symbolic /opt/openmensa/config/{database.yml,omniauth.yml,settings.yml} /etc/openmensa
  useradd --create-home --home-dir /var/lib/openmensa --shell /bin/bash openmensa
  chown openmensa:openmensa /var/log/openmensa /mnt/www
EOF

USER openmensa

EXPOSE 3000

VOLUME /mnt/www

ENTRYPOINT [ "/opt/openmensa/entrypoint.sh" ]
CMD [ "server" ]
