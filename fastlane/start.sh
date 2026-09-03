#!/usr/bin/env bash
# FastLane/SpeedBump — participant start. Idempotent. Safe to re-run.
set -e
cd "$(dirname "$0")"
echo "=============================================="
echo "  FastLane / SpeedBump  ·  Vibe Coding Security Lab"
echo "  The Vibe Coding Security Top 10 Gotchas"
echo "=============================================="
# 1. sanity: data present
ls app/*.json >/dev/null 2>&1       || { echo "[!] missing app/ evidence — run ./reset.sh"; exit 1; }
ls speedbump/*.json >/dev/null 2>&1 || { echo "[!] missing speedbump/ configs — run ./reset.sh"; exit 1; }
echo "[+] lab data present: app/ (FastLane) + speedbump/ (SpeedBump)"
# 2. skills available to the agent? `ls` alone only proves the symlinks exist, not that
#    they resolve — [ -e "$f" ] on each one follows the link and catches a broken target
#    (e.g. cloned to the wrong place and shadowed by this folder's own bind mount).
SK="$HOME/.claude/skills"
if [ -d "$SK" ] && [ -n "$(ls "$SK" 2>/dev/null)" ]; then
  total=0; broken=0
  for f in "$SK"/*; do total=$((total+1)); [ -e "$f" ] || broken=$((broken+1)); done
  if [ "$broken" -eq 0 ]; then
    echo "[+] agent skills mounted at $SK ($total skills)"
  else
    echo "[!] $broken of $total skill symlink(s) in $SK are BROKEN — instructor: re-run ./setup-skills.sh"
  fi
else
  echo "[i] skills not in $SK. Instructor: run  ./setup-skills.sh"
fi
# 3. model access mode
if command -v claude >/dev/null 2>&1; then
  echo "[+] Claude Code found."
  [ -n "$ANTHROPIC_BASE_URL" ] && echo "    mode: OFFLINE/local ($ANTHROPIC_BASE_URL)" || echo "    mode: online (shared key)"
else
  echo "[i] 'claude' not found — use the printed ANSWER page (dry-run mode)."
fi
echo "----------------------------------------------"
echo "TWO SCENARIOS (pick one - your instructor will say which):"
echo "  [1] FastLane  (reactive):  investigate the breach — Loopline shipped fast,"
echo "      no review, and it shows. Evidence is in app/."
echo "  [2] SpeedBump (proactive): audit speedbump/ and find the Top 10 gotchas"
echo "      before they ship, not after."
echo "=============================================="
