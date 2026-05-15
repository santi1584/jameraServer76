# jameraServer76 — dockerized

Runs the bundled Tibia 7.6 server in a hardened Docker container, so we can
develop client software against a real wire-level 7.6 protocol target
without trusting 9-year-old binaries to run on the host.

**Development use only.** Credentials below are intentionally trivial; do
not expose port 7171 to anything beyond `localhost`.

## What's running

Two containers on a private bridge network:

- **`jamera-mariadb`** — MariaDB 10.6 holding accounts/characters/items.
  Schema bootstraps from `../ot_teste3.sql` on first boot.
- **`jamera-otserv`** — the compiled `otserv` binary. Non-root, read-only
  root filesystem, no Linux capabilities, no-new-privileges. Listens on
  port 7171.

Only the otserv container's `7171` is exposed to the host, and only on
`127.0.0.1`. The mariadb port stays internal.

## Setup

You'll need [Docker Desktop](https://www.docker.com/products/docker-desktop/)
or a compatible engine. Tested on Intel macOS, should also work on Linux
and Apple-silicon macOS (via the amd64 emulation Docker Desktop provides).

```bash
git clone https://github.com/santi1584/jameraServer76.git
cd jameraServer76/docker
docker compose up --build      # ~5–10 min first build
```

The first boot does a lot:
1. Builds the otserv image (compiles 72k LOC of C++; subsequent builds are
   cached and take <30 seconds unless source changes).
2. Pulls the mariadb image.
3. mariadb runs the SQL dump to create the schema.
4. otserv waits for mariadb to be healthy, then starts.

You'll see otserv output ending with `Tibia World RPG OldSchool Server
Running...` once it's accepting connections.

## Verifying

```bash
# Simple TCP probe — server should accept the connection
nc -zv localhost 7171

# Watch the otserv logs
docker compose logs -f otserv
```

## Common operations

```bash
# Stop everything
docker compose down

# Stop and wipe the database (fresh accounts/characters next boot)
docker compose down -v

# Rebuild just the otserv image (if you edited the C++ source)
docker compose build otserv

# Logged build (for debug runs that need to capture output)
./build.sh   # tees stdout/stderr to build.log

# Shell into the running otserv container
docker compose exec otserv bash

# Shell into the mariadb container to inspect schema
docker compose exec mariadb mariadb -uotserv -pdev-otserv-pass-not-for-prod ot_teste3
```

## Creating an in-game account

The upstream SQL dump may not seed default accounts. Easiest path is to
create one directly in the DB:

```bash
docker compose exec mariadb mariadb -uotserv -pdev-otserv-pass-not-for-prod ot_teste3 -e \
  "INSERT INTO accounts (id, password, email, premend, blocked, deleted, warned, warnings) \
   VALUES (1, '1', 'dev@local', 0, 0, 0, 0, 0);"
```

That gives you account `1` / password `1`. (The server stores passwords as
plain text — fine for local dev only.) Then connect with a Tibia 7.6
client and create a character.

If the dump's existing players are attached to accounts that no longer
exist, you can reassign one to your account number:

```sql
UPDATE players SET account_id = 1 WHERE name = 'GOD Bruno';
```

## Security notes

- Network is a private docker bridge. otserv ↔ mariadb only. Neither can
  talk to the public internet from inside the container.
- otserv runs as UID 1000, `read_only: true`, `cap_drop: ALL`,
  `no-new-privileges:true`. Blast radius of a hypothetical compromise is
  limited to writing to `/tmp` (tmpfs) and TCP to mariadb.
- The container does NOT use the pre-compiled `otserv` ELF in this repo
  (built for glibc 2.6.32 in 2017). We rebuild from source.
- The upstream `config.lua` bakes in remote DB credentials pointing at
  `jamera.com.br:3306`. `entrypoint.sh` sed-patches the config to point
  at the local mariadb before the binary ever reads it.

## Modernization patches

The source in `../source 7.6/` is patched in this fork to compile with
modern gcc/g++:

- `std::tr1::unordered_map/set` → `std::unordered_map/set` (and the
  matching header includes). libstdc++ stopped shipping `<tr1/*>` headers
  around gcc 9.
- `Game::findItemOfType` had a `return false;` for a `NULL` cylinder in
  a function that returns `Item*`. Modern gcc rejects the implicit
  bool→pointer conversion even with `-fpermissive`. Changed to
  `return NULL;`.

The Dockerfile passes `-std=c++14 -fpermissive
-Wno-deprecated-declarations` and `-pthread` so the rest of the 2017
source compiles cleanly against Ubuntu 18.04's toolchain.

## Troubleshooting

**`otserv` exits immediately with a SQL error.** mariadb wasn't ready
when otserv started. The compose file uses a healthcheck-gated
`depends_on`, so this shouldn't happen — if it does, inspect
`docker compose logs mariadb` first.

**Port 7171 already in use.** Another process is bound to it.
`lsof -i :7171` to find it. Either kill it or change the host port
mapping in `docker-compose.yml` (the `ports:` line; container side stays
7171).

**Build fails during compile.** The source is from 2017; modern gcc may
flag warnings as errors in stricter modes. The Dockerfile already passes
`-fpermissive -Wno-deprecated-declarations` to soften that. If you hit a
new failure, run `./build.sh` so the full output is captured to
`build.log`.
