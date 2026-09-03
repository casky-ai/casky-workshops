#!/usr/bin/env bash
# TollBooth — cleanup. Removes everything a workshop run creates OUTSIDE this
# folder: the Section 1 Kali container, and any evidence files Section 2 copied
# into Casky Box's evidence/ bind mount (casky-box/evidence/, shared by every
# workshop). Safe to re-run.
#
# What this does NOT touch (on purpose):
#   - Casky Box's own containers (casky-runner, casky-db, casky-ui, …) — it's shared
#     across workshops/attendees, so this never stops or removes it.
#   - The casky-tollbooth IMAGE (pulled from GHCR or built locally) — pass --with-image to remove it too.
#     Pass --with-image to remove it too.
#   - Postgres investigation records from casky harness runs — history, not
#     litter; delete those yourself via casky-ui or psql if you actually want to.
#
# Usage:
#   ./cleanup.sh                                    # container + copied evidence files
#   ./cleanup.sh --casky-box-path ../casky-box       # if casky-box/ was moved elsewhere
#   ./cleanup.sh --with-image                        # also remove the casky-tollbooth image

set -uo pipefail
cd "$(dirname "$0")"

CASKY_BOX_PATH="${CASKY_BOX_PATH:-../casky-box}"
WITH_IMAGE=0
while [ $# -gt 0 ]; do case "$1" in
  --casky-box-path)    CASKY_BOX_PATH="$2"; shift 2;;
  --with-image)        WITH_IMAGE=1; shift;;
  -h|--help)            grep '^#' "$0" | sed 's/^# \{0,1\}//' | sed -n '2,20p'; exit 0;;
  *) echo "unknown arg: $1"; exit 1;;
esac; done

echo "== Section 1: Kali container =="
if docker ps -a --format '{{.Names}}' | grep -qx kali-tollbooth; then
  docker rm -f kali-tollbooth >/dev/null && echo "  removed container: kali-tollbooth"
else
  echo "  no kali-tollbooth container found — already clean"
fi

if [ "$WITH_IMAGE" -eq 1 ]; then
  if docker image inspect casky-tollbooth >/dev/null 2>&1; then
    docker rmi casky-tollbooth >/dev/null && echo "  removed image: casky-tollbooth"
  else
    echo "  casky-tollbooth image not present"
  fi
else
  echo "  (casky-tollbooth image kept — pass --with-image to remove it too)"
fi

echo
echo "== Section 2: evidence copied into Casky Box =="
EV_DIR="$CASKY_BOX_PATH/evidence"
if [ -d "$EV_DIR" ]; then
  removed=0
  for f in tollbooth-full.txt opendoor-full.txt tollbooth-pcap.txt tollbooth-cloudtrail.jsonl tollbooth-cloudtrail.json; do
    if [ -f "$EV_DIR/$f" ]; then rm -f "$EV_DIR/$f" && echo "  removed: $EV_DIR/$f" && removed=1; fi
  done
  [ "$removed" -eq 0 ] && echo "  no workshop evidence files found in $EV_DIR — already clean"
else
  echo "  $EV_DIR not found — pass --casky-box-path <path> if casky-box/ lives elsewhere"
fi

echo
echo "== This folder: scratch evidence files =="
shopt -s nullglob 2>/dev/null || true
scratch=(tollbooth-pcap.txt tollbooth-full.txt opendoor-full.txt tollbooth-cloudtrail.jsonl)
found=0
for f in "${scratch[@]}"; do
  if [ -f "$f" ]; then rm -f "$f" && echo "  removed: $f" && found=1; fi
done
[ "$found" -eq 0 ] && echo "  none found — already clean"

echo
echo "Done. lab-tollbooth.pcap, cloudtrail/, opendoor/, and the scenario scripts are untouched"
echo "(that's committed workshop content, not run output) — use ./reset.sh if those got modified"
echo "mid-exercise and you want them restored from .pristine/."
