#!/usr/bin/env bash
# check_2_secrets.sh: Loopline demo, Top 10 Gotcha #2: secrets shipped in the bundle.
#
# Requires the Loopline demo container running:
#   cd fastlane && docker build -f Dockerfile.demo -t loopline-demo:latest .
#   docker run -d --name loopline-demo -p 8787:8787 loopline-demo:latest
set -euo pipefail

HOST="${LOOPLINE_HOST:-http://localhost:8787}"
BUNDLE_PATH="/_next/static/chunks/app-a91f3c2e.js"

echo "=== Check 2: is a secret sitting in plain sight in the shipped bundle? ==="
echo "\$ curl -s $HOST$BUNDLE_PATH \\"
echo "    | grep -oiE '(service_role|sk-live-|AKIA)[A-Za-z0-9_.\":-]{5,}'"
echo

if ! BUNDLE=$(curl -sf "$HOST$BUNDLE_PATH"); then
  echo "Couldn't reach $HOST, is the loopline-demo container running?"
  echo "  docker run -d --name loopline-demo -p 8787:8787 loopline-demo:latest"
  exit 1
fi

FOUND=$(echo "$BUNDLE" | grep -oiE '(service_role|sk-live-|AKIA)[A-Za-z0-9_.":-]{5,}' || true)

if [ -z "$FOUND" ]; then
  echo "Nothing matched. (If you're pointing this at your own app instead of the demo,"
  echo "that's good, but check the full bundle, not just this one chunk.)"
  exit 0
fi

echo "$FOUND"
echo
echo "----"
echo "FINDING:  a Supabase SERVICE_ROLE key, sitting in a client-side JS bundle."
echo "WHY IT MATTERS:"
echo "  - The anon key (public, meant to ship to browsers) respects RLS."
echo "  - The service_role key is Supabase's admin key. By design it BYPASSES RLS"
echo "    entirely, correctly configured or not. It's meant only for trusted,"
echo "    server-side code."
echo "  - It ended up here because an env var was named"
echo "    NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY, the NEXT_PUBLIC_ prefix ships"
echo "    anything to the browser bundle, by Next.js design, not a bug in Next.js."
echo "SAME AS:  Escape.tech's scan of 5,600 vibe-coded apps found 400+ exposed"
echo "          secrets this way."
