#!/usr/bin/env bash
# Dashcam — cleanup. Removes everything a run of this exercise creates: the kali-dashcam
# container (Option A), and the local venv + cloned upstream skills repo (Option B), none of
# which is committed workshop content. Safe to re-run.
#
# What this does NOT touch (on purpose):
#   - data/, skills/, and the scenario scripts — that's committed workshop content.
#   - ~/.claude/skills symlinks (Option B) — re-run ./setup-skills.sh to refresh them instead.
#
# Usage:
#   ./cleanup.sh                # container + venv + cloned upstream skills repo
#   ./cleanup.sh --keep-venv    # keep the venv, only remove the container + cloned skills repo
#   ./cleanup.sh --with-image   # also remove the casky-dashcam image

set -uo pipefail
cd "$(dirname "$0")"

KEEP_VENV=0
WITH_IMAGE=0
while [ $# -gt 0 ]; do case "$1" in
  --keep-venv)  KEEP_VENV=1; shift;;
  --with-image) WITH_IMAGE=1; shift;;
  -h|--help)    grep '^#' "$0" | sed 's/^# \{0,1\}//' | sed -n '2,20p'; exit 0;;
  *) echo "unknown arg: $1"; exit 1;;
esac; done

echo "== Option A: kali-dashcam container =="
if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx kali-dashcam; then
  docker rm -f kali-dashcam >/dev/null && echo "  removed container: kali-dashcam"
else
  echo "  no kali-dashcam container found — already clean"
fi
if [ "$WITH_IMAGE" -eq 1 ]; then
  if docker image inspect casky-dashcam >/dev/null 2>&1; then
    docker rmi casky-dashcam >/dev/null && echo "  removed image: casky-dashcam"
  else
    echo "  casky-dashcam image not present"
  fi
else
  echo "  (casky-dashcam image kept — pass --with-image to remove it too)"
fi

echo
echo "== Option B: local venv + cloned upstream skills repo =="
if [ "$KEEP_VENV" -eq 0 ] && [ -d .venv ]; then
  rm -rf .venv && echo "  removed: .venv"
else
  [ -d .venv ] && echo "  kept: .venv (--keep-venv)" || echo "  no .venv found — already clean"
fi

if [ -d Anthropic-Cybersecurity-Skills ]; then
  rm -rf Anthropic-Cybersecurity-Skills && echo "  removed: Anthropic-Cybersecurity-Skills/ (cloned upstream)"
else
  echo "  no cloned Anthropic-Cybersecurity-Skills/ found — already clean"
fi

echo
echo "Done. data/, skills/, and the scenario scripts are untouched — use ./reset.sh if data/"
echo "got modified mid-exercise and you want it restored from .pristine/."
