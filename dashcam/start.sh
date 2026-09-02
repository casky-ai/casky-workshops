#!/usr/bin/env bash
# Dashcam — participant start. Idempotent. Safe to re-run.
set -e
cd "$(dirname "$0")"
echo "=============================================="
echo "  Dashcam  ·  Catch PII Before It Leaves the Building"
echo "  a specific-skill workshop — anonymizing-pii-with-microsoft-presidio"
echo "=============================================="
# 1. sanity: data present
ls data/*.json data/*.txt data/*.png >/dev/null 2>&1 || { echo "[!] missing data/ — run ./reset.sh"; exit 1; }
echo "[+] lab data present: data/ (4 artifacts — 2 JSON, 1 chat log, 1 image)"
# 2. skills available to the agent?
SK="$HOME/.claude/skills"
if [ -d "$SK" ] && [ -e "$SK/anonymizing-pii-with-microsoft-presidio" ]; then
  echo "[+] agent skills mounted at $SK ($(ls "$SK" | wc -l) skills)"
else
  echo "[i] skills not in $SK. Instructor: run  ./setup-skills.sh"
fi
# 3. Presidio actually importable?
if python3 -c "import presidio_analyzer, presidio_anonymizer" >/dev/null 2>&1; then
  echo "[+] presidio-analyzer / presidio-anonymizer importable"
else
  echo "[i] Presidio not installed yet — see SETUP.md Step 2 (pip install + spaCy model)"
fi
# 4. model access mode
if command -v claude >/dev/null 2>&1; then
  echo "[+] Claude Code found."
  [ -n "$ANTHROPIC_BASE_URL" ] && echo "    mode: OFFLINE/local ($ANTHROPIC_BASE_URL)" || echo "    mode: online (shared key)"
else
  echo "[i] 'claude' not found — use the printed ANSWER page (dry-run mode)."
fi
echo "----------------------------------------------"
echo "ONE SCENARIO: RoadWitness (fictional dashcam rideshare app) is about to hand four"
echo "artifacts to a third-party LLM vendor and a staging environment. Find and de-identify"
echo "the PII in each — before it leaves. Evidence is in data/."
echo "=============================================="
