#!/usr/bin/env bash
# Tailgate/GuestList — cleanup. Removes everything a workshop run creates OUTSIDE this
# folder: the Section 1 Kali container, and any evidence files Section 2 copied
# into casky-runner-phase1's evidence/ bind mount. Safe to re-run.
#
# What this does NOT touch (on purpose):
#   - casky-runner-phase1's own containers (casky-runner, casky-db, skill-lab, …)
#     — that's your persistent dev environment, not a workshop-run asset.
#   - The casky-tailgate IMAGE (pulled from GHCR or built locally) — pass --with-image to remove it too.
#     Pass --with-image to remove it too.
#   - Postgres investigation records from casky harness runs — history, not
#     litter; delete those yourself via casky-ui or psql if you actually want to.
#
# Usage:
#   ./cleanup.sh                                    # container + copied evidence files
#   ./cleanup.sh --casky-runner-path ../../casky-runner-phase1
#   ./cleanup.sh --with-image                        # also remove the casky-tailgate image

set -uo pipefail
cd "$(dirname "$0")"

CASKY_RUNNER_PATH="${CASKY_RUNNER_PATH:-../../casky-runner-phase1}"
WITH_IMAGE=0
while [ $# -gt 0 ]; do case "$1" in
  --casky-runner-path) CASKY_RUNNER_PATH="$2"; shift 2;;
  --with-image)        WITH_IMAGE=1; shift;;
  -h|--help)            grep '^#' "$0" | sed 's/^# \{0,1\}//' | sed -n '2,20p'; exit 0;;
  *) echo "unknown arg: $1"; exit 1;;
esac; done

echo "== Section 1: Kali container =="
if docker ps -a --format '{{.Names}}' | grep -qx kali-tailgate; then
  docker rm -f kali-tailgate >/dev/null && echo "  removed container: kali-tailgate"
else
  echo "  no kali-tailgate container found — already clean"
fi

if [ "$WITH_IMAGE" -eq 1 ]; then
  if docker image inspect casky-tailgate >/dev/null 2>&1; then
    docker rmi casky-tailgate >/dev/null && echo "  removed image: casky-tailgate"
  else
    echo "  casky-tailgate image not present"
  fi
else
  echo "  (casky-tailgate image kept — pass --with-image to remove it too)"
fi

echo
echo "== Section 2: evidence copied into casky-runner-phase1 =="
EV_DIR="$CASKY_RUNNER_PATH/evidence"
if [ -d "$EV_DIR" ]; then
  removed=0
  for f in tailgate-full.txt guestlist-full.txt; do
    if [ -f "$EV_DIR/$f" ]; then rm -f "$EV_DIR/$f" && echo "  removed: $EV_DIR/$f" && removed=1; fi
  done
  [ "$removed" -eq 0 ] && echo "  no workshop evidence files found in $EV_DIR — already clean"
else
  echo "  $EV_DIR not found — pass --casky-runner-path <path> if casky-runner-phase1 lives elsewhere"
fi

echo
echo "== This folder: scratch evidence files =="
scratch=(tailgate-full.txt guestlist-full.txt)
found=0
for f in "${scratch[@]}"; do
  if [ -f "$f" ]; then rm -f "$f" && echo "  removed: $f" && found=1; fi
done
[ "$found" -eq 0 ] && echo "  none found — already clean"

echo
echo "Done. phishing-email.eml, mail-gateway.log, endpoint-alert.log, network/, ad/, guestlist/,"
echo "and the scenario scripts are untouched (that's committed workshop content, not run output)"
echo "— use ./reset.sh if those got modified mid-exercise and you want them restored from .pristine/."
