# Hecate Daemon Dockerfile
# Multi-stage build for minimal image size

# Build stage
FROM erlang:27-alpine AS builder

WORKDIR /build

# Install build dependencies (Rust for NIFs, Perl for OpenSSL, etc.)
RUN apk add --no-cache \
    git curl bash \
    build-base cmake \
    rust cargo \
    perl linux-headers

# Install rebar3
RUN curl -fsSL https://s3.amazonaws.com/rebar3/rebar3 -o /usr/local/bin/rebar3 && \
    chmod +x /usr/local/bin/rebar3

# Copy dependency config first (cacheable layer)
COPY rebar.config ./

# Fetch dependencies (cached until rebar.config changes)
RUN rebar3 get-deps

# Copy source (busts cache when code changes)
COPY config/ config/
COPY src/ src/
COPY apps/ apps/
COPY docker/ docker/

# Compile
RUN rebar3 compile

# Build release
RUN rebar3 as prod release

# Runtime stage - must match Alpine version from erlang:27-alpine (3.22)
FROM alpine:3.22

# Install runtime dependencies
RUN apk add --no-cache \
    ncurses-libs \
    libstdc++ \
    libgcc \
    openssl \
    ca-certificates \
    dbus

WORKDIR /app

# Copy release from builder
COPY --from=builder /build/_build/prod/rel/hecate ./

# Copy entrypoint (generates vm.args from env vars)
COPY docker/entrypoint.sh /app/entrypoint.sh

# Create data directory
RUN mkdir -p /data

# Environment
ENV HOME=/app
ENV HECATE_DATA_DIR=/data
ENV HECATE_API_HOST=0.0.0.0
ENV HECATE_API_PORT=4444

# Expose ports
EXPOSE 4444

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -q --spider http://localhost:4444/health || exit 1

# Run — entrypoint generates vm.args from HECATE_NODE_NAME / HECATE_ERLANG_COOKIE
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["foreground"]
