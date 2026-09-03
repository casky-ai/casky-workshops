#!/usr/bin/env bash
# TollBooth — participant start. Idempotent. Safe to re-run.
set -e
cd "$(dirname "$0")"
echo "=============================================="
echo "  TollBooth  ·  Arsenal Lab  ·  Station 2"
echo "  From packet to cloud with AI agent skills"
echo "=============================================="
# 1. sanity: data present
[ -f lab-tollbooth.pcap ] || { echo "[!] missing pcap — run ./reset.sh"; exit 1; }
ls cloudtrail/*.json >/dev/null 2>&1 || { echo "[!] missing CloudTrail — run ./reset.sh"; exit 1; }
ls opendoor/*.json  >/dev/null 2>&1 || { echo "[!] missing opendoor configs — run ./reset.sh"; exit 1; }
echo "[+] lab data present: pcap + cloudtrail/ (S1) + opendoor/ (S2)"
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
echo "  [1] TollBooth (reactive): investigate the breach in lab-tollbooth.pcap + cloudtrail/"
echo "  [2] OpenDoor  (proactive): audit opendoor/ and find the 3 holes that caused it"
echo "Open the cheat-sheet book: pages 1-3 = Scenario 1, pages 4-6 = Scenario 2."
if [ -d bigcloud ]; then echo "[+] ADVANCED TIER available: big CloudTrail corpus in bigcloud/ (python3 bigquery.py --anomaly)"; fi
echo "=============================================="
