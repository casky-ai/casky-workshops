#!/usr/bin/env bash
# Tailgate/GuestList — participant start. Idempotent. Safe to re-run.
set -e
cd "$(dirname "$0")"
echo "=============================================="
echo "  Tailgate / GuestList  ·  DFIR Lab"
echo "  Phishing to domain compromise, with AI agent skills"
echo "=============================================="
# 1. sanity: data present
[ -f phishing-email.eml ]      || { echo "[!] missing phishing-email.eml — run ./reset.sh"; exit 1; }
ls network/*.txt >/dev/null 2>&1 || { echo "[!] missing network/ evidence — run ./reset.sh"; exit 1; }
ls ad/*.txt      >/dev/null 2>&1 || { echo "[!] missing ad/ evidence — run ./reset.sh"; exit 1; }
ls guestlist/*.json >/dev/null 2>&1 || { echo "[!] missing guestlist/ configs — run ./reset.sh"; exit 1; }
echo "[+] lab data present: Act 1-3 evidence (Tailgate) + guestlist/ (GuestList)"
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
echo "  [1] Tailgate  (reactive):  investigate the phishing -> lateral movement ->"
echo "      domain compromise kill chain across phishing-email.eml, network/, ad/"
echo "  [2] GuestList (proactive): audit guestlist/ and find the 3 misconfigurations"
echo "      that let Tailgate happen"
echo "Open the cheat-sheet book: pages 1-4 = Tailgate, pages 5-7 = GuestList."
echo "=============================================="
