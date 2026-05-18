# syntax=docker/dockerfile:1
# Production image cho Hệ thống quản lý điện nội bộ Sư đoàn.
# Multi-stage build: stage 1 = builder (gems + assets), stage 2 = runtime tối thiểu.

ARG RUBY_VERSION=3.4.3
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# Runtime packages (cần ở final image):
# - postgresql-client: cho pg_dump/pg_restore (backup feature)
# - libjemalloc2: memory allocator hiệu năng
# - libvips: image processing (Active Storage variants)
# - tini: init system tốt cho container (forward signal)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl libjemalloc2 libvips postgresql-client tini && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LANG="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8" \
    TZ="Asia/Ho_Chi_Minh"

# ====== Build stage ======
FROM base AS build

# Build-time packages (chỉ cần để compile gems + assets):
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential git libpq-dev pkg-config && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Cài gems trước để cache layer
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy phần còn lại của app
COPY . .

# Precompile bootsnap (load nhanh hơn ở runtime)
RUN bundle exec bootsnap precompile app/ lib/

# Precompile assets cần SECRET_KEY_BASE giả (build-time, không phải runtime).
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

# ====== Final stage ======
FROM base

# Copy gems + app từ builder
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Non-root user (Rails 8 omakase pattern)
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER rails:rails

# Entrypoint chạy db:prepare (idempotent migrate) + exec command
ENTRYPOINT ["/usr/bin/tini", "--", "/rails/bin/docker-entrypoint"]

EXPOSE 3000
# Thrust: HTTP/2 + caching + compression (Rails 8 default for production)
CMD ["./bin/thrust", "./bin/rails", "server"]
