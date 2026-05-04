# Hecate Daemon Dockerfile
# Multi-stage build for minimal image size

# Build stage
FROM erlang:27-alpine AS builder

WORKDIR /build

# Install build dependencies (Perl for OpenSSL, etc.)
# Rust intentionally NOT pulled from apk: Alpine 3.22 ships rustc 1.87,
# but macula 3.15.x's Rust NIF deps (time@0.3.47, time-core@0.1.8,
# time-macros@0.2.27) require rustc 1.88+. Use rustup for current stable.
RUN apk add --no-cache \
    git curl bash \
    build-base cmake \
    perl linux-headers

# Install Rust via rustup (always current stable)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --default-toolchain stable --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"

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
    curl \
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

# Health check — verify Erlang node is registered with epmd
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD /app/erts-*/bin/epmd -names 2>/dev/null | grep -q hecate || exit 1

# Run — entrypoint generates vm.args from HECATE_NODE_NAME / HECATE_ERLANG_COOKIE
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["foreground"]
