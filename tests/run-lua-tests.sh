#!/bin/sh
# Runs the npcsystem Lua test suite against the real data/ files.
# Needs a Lua 5.1 interpreter; override with LUA=/path/to/lua.
set -e
cd "$(dirname "$0")/.."
LUA="${LUA:-lua5.1}"
if ! command -v "$LUA" >/dev/null 2>&1; then
	echo "error: '$LUA' not found. Install lua5.1 or set LUA=/path/to/lua5.1" >&2
	exit 2
fi
exec "$LUA" tests/lua/run.lua
