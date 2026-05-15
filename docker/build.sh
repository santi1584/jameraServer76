#!/usr/bin/env bash
# Run `docker compose build` with all output tee'd to ./build.log.
# Useful when chasing compile errors so the full output is captured
# (the modernization patches make the build mostly silent now, but the
# logging path is handy for the next round of upstream-source surprises).

set -o pipefail
cd "$(dirname "$0")"

LOG=build.log
echo "[build] writing logs to $(pwd)/$LOG"
echo "" > "$LOG"

docker compose build otserv 2>&1 | tee "$LOG"
EXIT=${PIPESTATUS[0]}

if [[ $EXIT -eq 0 ]]; then
  echo
  echo "[build] OK. Start the stack with: docker compose up"
else
  echo
  echo "[build] FAILED (exit $EXIT). Log: $(pwd)/$LOG"
fi

exit "$EXIT"
