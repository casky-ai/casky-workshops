#!/usr/bin/env bash
# FastLane/SpeedBump — instructor self-test. Confirms this laptop's data AND tooling are intact.
cd "$(dirname "$0")"
KEYSTR="SYNTHETIC_SERVICE_ROLE_c71d"
pass=0; fail=0
num(){ case "$1" in ''|*[!0-9]*) echo 0;; *) echo "$1";; esac; }
chk(){ v=$(num "$1"); if [ "$v" -ge "$2" ]; then echo "  PASS  $3 ($v)"; pass=$((pass+1)); else echo "  FAIL  $3 (got $v, need >= $2)"; fail=$((fail+1)); fi; }
chkmax(){ v=$(num "$1"); if [ "$v" -le "$2" ]; then echo "  PASS  $3 ($v)"; pass=$((pass+1)); else echo "  FAIL  $3 (got $v, need <= $2)"; fail=$((fail+1)); fi; }

echo "== tooling =="
for t in jq grep; do
  if command -v "$t" >/dev/null 2>&1; then echo "  ok      $t";
  else echo "  MISSING $t"; fi
done
if ! command -v jq >/dev/null 2>&1; then
  echo "!! jq is required. Run: sudo apt-get update && sudo apt-get install -y jq"
  echo "   then re-run ./verify.sh"; exit 1
fi

echo "== gotcha 1/5 — RLS misconfiguration =="
n=$(grep -c '"rowsecurity": false' app/rls-policies.json)
chk "$n" 1 "customers table: RLS disabled entirely"
n=$(grep -c '"qual": "true"' app/rls-policies.json)
chk "$n" 1 "tickets table: RLS enabled but policy is USING (true)"

echo "== gotcha 2/8 — secret exposure (same key, two leak paths) =="
n=$(grep -rc "$KEYSTR" app/client-bundle-excerpt.txt app/git-history-env-leak.txt app/access-log.txt 2>/dev/null | awk -F: '{s+=$2} END{print s}')
chk "$n" 3 "service-role key present across bundle/git-history/access-log"

echo "== gotcha 3 — slopsquatting, caught pre-merge =="
n=$(grep -c '"react-csv-parser-pro":' app/package.json)
chkmax "$n" 0 "main branch package.json does NOT include the hallucinated package"
n=$(grep -c '"react-csv-parser-pro"' app/pr-branch-diff.txt)
chk "$n" 1 "the hallucinated package IS referenced in the unmerged PR branch"

echo "== gotcha 4 — IDOR on /api/tickets/[id] =="
n=$(grep -c "path=/api/tickets/" app/access-log.txt)
chk "$n" 5 "sequential ticket-ID enumeration present in access log"

echo "== gotcha 7 — CORS wildcard =="
n=$(grep -c 'value: "\*"' app/next-config-cors.txt)
chk "$n" 1 "Access-Control-Allow-Origin: * present in next.config.js"

echo "== gotcha 9 — exposed debug route =="
n=$(grep -c "/api/debug/seed" app/access-log.txt)
chk "$n" 1 "unauthenticated hit on /api/debug/seed present in access log"

echo "== gotcha 6 — dev-environment supply chain (MCP auto-trust) =="
n=$(grep -c "mcpServers" app/dev-environment-audit.txt)
chk "$n" 1 "starter template's auto-trusted MCP config documented"

echo "== gotcha 10 — general code scan =="
n=$(grep -c "FINDING" app/code-scan-summary.txt)
chk "$n" 2 "general OWASP-flavored findings present (XSS, no rate-limit)"

echo "== speedbump (proactive audit) =="
n=$(grep -c '"correlation_label"' speedbump/*.json | awk -F: '{s+=$2} END{print s}')
chk "$n" 7 "correlation labels present across all 4 audit reports"
n=$(grep -c "not exploited" speedbump/supply-chain-audit.json)
chk "$n" 1 "slopsquatting finding correctly labeled not-exploited (matches pr-branch-diff.txt)"

echo "----"; echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "This laptop is READY." || echo "Review the FAIL lines above."
