FROM ruby:3.3.11-slim AS builder
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libsqlite3-dev \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install

COPY package.json ./
RUN npm install

COPY . .

RUN npm run build

RUN bundle exec rake assets:precompile

FROM ruby:3.3.11-slim
ENV RAILS_ENV=production
ENV RAILS_LOG_TO_STDOUT=true
ENV RAILS_SERVE_STATIC_FILES=true
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/* && \
    groupadd -r rails && useradd -r -g rails -u 1001 rails

COPY --from=builder /app/vendor/bundle ./vendor/bundle
COPY --from=builder /app/public ./public
COPY --from=builder /app/app ./app
COPY --from=builder /app/bin ./bin
COPY --from=builder /app/config ./config
COPY --from=builder /app/config.ru ./config.ru
COPY --from=builder /app/db ./db
COPY --from=builder /app/lib ./lib
COPY --from=builder /app/Rakefile ./Rakefile
COPY --from=builder /app/Gemfile ./Gemfile
COPY --from=builder /app/Gemfile.lock ./Gemfile.lock
COPY --from=builder /app/.bundle ./.bundle

RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    chown -R rails:rails /app

EXPOSE 3000
USER 1001

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb", "-p", "3000"]