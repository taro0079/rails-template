# syntax = docker/dockerfile:1

# ARG for Ruby version and Rails environment
ARG RUBY_VERSION=3.3.3
ARG RAILS_ENV=development

# Base stage with shared setup
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Set working directory for the Rails app
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips sqlite3 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set environment variables, including RAILS_ENV (development or production)
ENV RAILS_ENV=${RAILS_ENV} \
    BUNDLE_PATH="/usr/local/bundle"

# Install additional packages for the build stage
FROM base AS build

# Install build essentials and git
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copy Gemfile and Gemfile.lock, install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy application code
COPY . .

# Install Node.js, Yarn, and other packages for development only if RAILS_ENV is development
RUN if [ "$RAILS_ENV" = "development" ]; then \
    apt-get update -qq && apt-get install --no-install-recommends -y nodejs yarn vim && yarn install; \
    fi

# Precompile assets and bootsnap code for production only if RAILS_ENV is production
RUN if [ "$RAILS_ENV" = "production" ]; then \
    SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile && \
    bundle exec bootsnap precompile app/ lib/; \
    fi

# Final stage for the app image
FROM base

# Copy built artifacts (gems, application) from the build stage
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Set non-root user for security purposes
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

# Set entrypoint
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Expose the default Rails port
EXPOSE 3000

# Command to run the Rails server (bind to 0.0.0.0 for both development and production)
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
