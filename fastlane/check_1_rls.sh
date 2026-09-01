#!/usr/bin/env bash
# check_1_rls.sh: Loopline demo, Top 10 Gotcha #1: Row-Level Security left off.
#
# Requires the Loopline demo container running:
#   cd fastlane && docker build -f Dockerfile.demo -t loopline-demo:latest .
#   docker run -d --name loopline-demo -p 8787:8787 loopline-demo:latest
set -euo pipefail

HOST="${LOOPLINE_HOST:-http://localhost:8787}"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIn0.SYNTHETIC_ANON_9f2a"

echo "=== Check 1: does the public anon key read every customer row? ==="
echo "\$ curl -s \"$HOST/rest/v1/customers?select=*\" -H \"apikey: <key shipped in the JS bundle>\""
echo

if ! RESULT=$(curl -sf "$HOST/rest/v1/customers?select=*" -H "apikey: $ANON_KEY"); then
  echo "Couldn't reach $HOST, is the loopline-demo container running?"
  echo "  docker run -d --name loopline-demo -p 8787:8787 loopline-demo:latest"
  exit 1
fi

echo "$RESULT"
echo

COUNT=$(echo "$RESULT" | grep -c '"id":' || true)
echo "----"
echo "FINDING:  $COUNT customer rows returned. No login. No org check. Just the public"
echo "          anon key that ships in every visitor's browser by design."
echo "WHY:      Loopline's 'customers' table has Row-Level Security (RLS) disabled"
echo "          entirely, rowsecurity: false. Postgres never checked who was asking."
echo "SAME AS:  CVE-2025-48757 (170 of 1,645 scanned Lovable apps) and the Moltbook"
echo "          breach (1.5M tokens, 35K emails exposed), same root cause, same fix"
echo "          missing."
