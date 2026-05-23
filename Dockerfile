# syntax=docker/dockerfile:1 [cite: 1]
# check=error=true

ARG RUBY_VERSION=4.0.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# เปลี่ยน WORKDIR เป็น /app เพื่อให้สอดคล้องกับ docker-compose.yml
WORKDIR /app

# Install base packages (มี git ติดตั้งอยู่แล้วในชุดนี้) [cite: 3]
RUN apt-get install --no-install-recommends -y build-essential git libpq-dev libvips libyaml-dev pkg-config libffi-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment variables [cite: 4]
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

FROM base AS build

# Install packages needed to build gems
RUN apt-get install --no-install-recommends -y curl libjemalloc2 libvips postgresql-client nodejs npm libffi-dev && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# ---------------------------------------------------------
# ส่วนที่แก้ไข: ใช้ Git Clone แทนการ COPY ไฟล์จากเครื่อง Local
# ---------------------------------------------------------
# กำหนด ARG สำหรับรับค่า URL ของ Repository
ARG GITHUB_REPO_URL=https://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@github.com/neo112-q/API-Capstone.git
ARG GITHUB_BRANCH=main

# Clone โค้ดจาก GitHub ลงใน WORKDIR (/app)
RUN git clone -b ${GITHUB_BRANCH} ${GITHUB_REPO_URL} .

# Install application gems (อ่าน Gemfile ที่เพิ่ง Clone มา)
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1 disable parallel compilation to avoid a QEMU bug [cite: 5]
    bundle exec bootsnap precompile -j 1 --gemfile

# Precompile bootsnap code
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Adjust binfiles to be executable on Linux
RUN chmod +x bin/* && \
    sed -i "s/\r$//g" bin/* && \
    sed -i 's/ruby\.exe$/ruby/' bin/*

# Final stage for app image
FROM base

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

# Copy built artifacts: gems, application [cite: 7]
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /app /app

# อัปเดต Entrypoint ให้ใช้ path /app แทน /rails
ENTRYPOINT ["/app/bin/docker-entrypoint"]

EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]