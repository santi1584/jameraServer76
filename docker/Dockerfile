# syntax=docker/dockerfile:1.4

# ============================================================================
# Stage 1 — builder
# ----------------------------------------------------------------------------
# Compile the otserv binary from the bundled C++ source. We do *not* use the
# pre-compiled `otserv` ELF shipped in the repo (it was built for glibc 2.6.32
# in 2017; we don't trust opaque 9-year-old binaries running on modern hosts).
# Ubuntu 18.04 is old enough that 2017-era OTServ C++ compiles cleanly and
# new enough that boost 1.65, lua 5.1, libxml2, libmysqlclient, libpq, and
# unixodbc are all one apt-get away.
#
# Build context is the *repo root* (set by docker-compose.yml `context: ..`)
# so this Dockerfile can COPY directly from `source 7.6/`, `data/`, etc.
# ============================================================================
FROM ubuntu:18.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Build toolchain + every library configure.ac demands (libpq, unixodbc, and
# sqlite3 are all hard-required by the configure script even if we only end up
# using MySQL at runtime — the configure errors out otherwise).
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config \
    libboost-all-dev \
    libgmp-dev \
    liblua5.1-0-dev \
    libxml2-dev \
    libmysqlclient-dev \
    libpq-dev \
    libsqlite3-dev \
    unixodbc-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Copy the whole repo in. We rename the "source 7.6" directory (which has an
# annoying space) to /src/source for safer scripting.
COPY . /src/jamera/
RUN mv "/src/jamera/source 7.6" /src/source

WORKDIR /src/source

# Regenerate the autotools build files (the bundled Makefile/configure are
# from 2017 and reference paths that don't exist in the container).
RUN ./autogen.sh

# Configure + build.
#   -std=c++14 — the source predates C++17 removals (auto_ptr, random_shuffle).
#                C++14 keeps them around and is otherwise modern enough that
#                std::unordered_set works without the tr1 qualifier.
#   -fpermissive — tolerate the modest pile of implicit-conversion warnings.
#   -Wno-deprecated-declarations — boost 1.65 sprinkles these across asio.
#   -pthread — modern ld is strict about transitively-needed shared libs;
#              boost doesn't drag in libpthread on its own.
#   --enable-mysql — configure.ac defaults to SQLite, which mismatches the
#                    `MySQLResult*` allocations the source actually makes.
RUN ./configure \
    CXXFLAGS="-O2 -std=c++14 -fpermissive -Wno-deprecated-declarations" \
    LDFLAGS="-pthread" \
    --prefix=/opt/otserv \
    --enable-mysql \
  && make -j"$(nproc)"

# ============================================================================
# Stage 2 — runtime
# ----------------------------------------------------------------------------
# Tiny image with only the shared libraries the binary actually needs to load
# at startup. No compilers, no headers, no source. Runs as a non-root user
# with a read-only root filesystem and all Linux capabilities dropped (see
# docker-compose.yml). Network egress is also blocked at the compose level so
# even if a Lua script tried to phone home (the upstream config.lua bakes in
# remote DB creds for jamera.com.br — entrypoint.sh sed-patches them out),
# the syscall just fails.
# ============================================================================
FROM ubuntu:18.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    libboost-system1.65.1 \
    libboost-thread1.65.1 \
    libboost-regex1.65.1 \
    libboost-date-time1.65.1 \
    libboost-filesystem1.65.1 \
    libgmp10 \
    liblua5.1-0 \
    libxml2 \
    libmysqlclient20 \
    libpq5 \
    libsqlite3-0 \
    libodbc1 \
    netcat-openbsd \
  && rm -rf /var/lib/apt/lists/*

# Non-root user. UID/GID 1000 matches the typical host user on Linux/Mac so
# bind-mounted volumes (if any) don't end up owned by root.
RUN useradd --create-home --uid 1000 --shell /bin/bash otserv

WORKDIR /app

# Bring the compiled binary in, plus the game data tree and the upstream
# config.lua (which entrypoint.sh sed-patches before the server starts).
COPY --from=builder /src/source/otserv /app/otserv
COPY --from=builder /src/jamera/data /app/data
COPY --from=builder /src/jamera/config.lua /app/config.lua

# Entrypoint script lives outside the COPY of upstream files so we can iterate
# on it without invalidating the source build cache.
COPY docker/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh /app/otserv \
  && chown -R otserv:otserv /app

USER otserv

# Game port. Login server in classic otserv runs on the same port (the
# protocol switches based on the first byte). docker-compose maps this to
# 127.0.0.1:7171 — bound to localhost only, never exposed to the LAN.
EXPOSE 7171

ENTRYPOINT ["/app/entrypoint.sh"]
