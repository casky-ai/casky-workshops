#!/usr/bin/env bash
# Casky Workshops — readiness check, all exercises.
# Run this right before attendees show up. Checks, per exercise:
#   Section 1 (Kali)      -> kali-<exercise> container + tooling + lab data
#   Section 2 (Casky Box) -> casky-box's docker compose stack (shared across exercises,
#                            pulled from GHCR — no separate repo to clone)
# Safe to re-run any number of times; makes no changes.
#
# Usage:
#   ./scripts/workshop-check.sh
#   CASKY_BOX_DIR=/path/to/casky-box ./scripts/workshop-check.sh
#   ./scripts/workshop-check.sh --skip-network   # skip the wiki/blog reachability checks (e.g. flaky venue wifi)

set -u
cd "$(dirname "$0")/.."   # repo root (casky-workshops/)

SKIP_NETWORK=0
for a in "$@"; do
  [ "$a" = "--skip-network" ] && SKIP_NETWORK=1
done

# Lives in this repo by default (casky-workshops/casky-box) — override if yours lives elsewhere.
CASKY_BOX_DIR="${CASKY_BOX_DIR:-$(pwd)/casky-box}"

pass=0; fail=0; warn=0
ok()   { echo "  PASS  $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL  $1"; fail=$((fail+1)); }
soft() { echo "  WARN  $1"; warn=$((warn+1)); }

container_running() {
  docker inspect -f '{{.State.Running}}' "$1" >/dev/null 2>&1 && \
    [ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" = "true" ]
}
container_healthy_or_running() {
  # true if container has no healthcheck (falls back to Running) or Health.Status=healthy
  local status
  status=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$1" 2>/dev/null)
  [ "$status" = "healthy" ] || [ "$status" = "running" ]
}

echo "=================================================="
echo "  Casky Workshops — readiness check"
echo "=================================================="

echo
echo "== docker daemon =="
if docker info >/dev/null 2>&1; then ok "docker daemon reachable"
else bad "docker daemon not reachable — start Docker Desktop"; fi

echo
echo "== Section 1: Kali container =="
if container_running kali-tollbooth; then
  ok "kali-tollbooth is running"

  for t in tshark jq tcpdump; do
    if docker exec kali-tollbooth sh -c "command -v $t" >/dev/null 2>&1; then ok "$t present in kali-tollbooth"
    else bad "$t MISSING in kali-tollbooth"; fi
  done

  # claude lives at ~/.local/bin, not on the default non-login PATH — check the real path.
  if docker exec kali-tollbooth bash -c 'export PATH="$HOME/.local/bin:$PATH"; command -v claude' >/dev/null 2>&1; then
    ver=$(docker exec kali-tollbooth bash -c 'export PATH="$HOME/.local/bin:$PATH"; claude --version' 2>/dev/null)
    ok "claude CLI installed ($ver)"
  else
    soft "claude CLI not found in kali-tollbooth — attendees fall back to the printed ANSWER page (dry-run mode)"
  fi

  if docker exec kali-tollbooth sh -c 'case "$ANTHROPIC_API_KEY" in sk-ant-*) exit 0;; *) exit 1;; esac' >/dev/null 2>&1; then
    ok "ANTHROPIC_API_KEY present in kali-tollbooth (sk-ant- prefix)"
  else
    soft "ANTHROPIC_API_KEY missing/malformed in kali-tollbooth — check tollbooth/.env is unquoted (see SETUP.md)"
  fi

  for f in /root/tollbooth/lab-tollbooth.pcap /root/tollbooth/cloudtrail /root/tollbooth/opendoor; do
    if docker exec kali-tollbooth test -e "$f" >/dev/null 2>&1; then ok "$f present"
    else bad "$f MISSING in kali-tollbooth — run: docker exec -w /root/tollbooth kali-tollbooth ./reset.sh"; fi
  done
else
  bad "kali-tollbooth is not running — see tollbooth/SETUP.md Section 1"
fi

echo
echo "== Section 1 data integrity (verify.sh, run inside kali-tollbooth — needs tshark) =="
if container_running kali-tollbooth && docker exec kali-tollbooth test -f /root/tollbooth/verify.sh >/dev/null 2>&1; then
  out=$(docker exec -w /root/tollbooth kali-tollbooth ./verify.sh 2>&1)
  echo "$out" | sed 's/^/  /'
  # verify.sh never sets its exit code on failure — parse its own summary line instead.
  fails_in_verify=$(echo "$out" | grep -o 'RESULT: [0-9]* passed, [0-9]* failed' | grep -o '[0-9]* failed' | grep -o '[0-9]*')
  if [ -n "$fails_in_verify" ] && [ "$fails_in_verify" -eq 0 ]; then
    ok "tollbooth/verify.sh: all data checks passed"
  else
    bad "tollbooth/verify.sh: ${fails_in_verify:-an unknown number of} check(s) failed (see above) — try: docker exec -w /root/tollbooth kali-tollbooth ./reset.sh"
  fi
else
  soft "verify.sh not found in kali-tollbooth (or container not running) — skipping data-integrity checks"
fi

echo
echo "== Tailgate/GuestList: Kali container =="
if container_running kali-tailgate; then
  ok "kali-tailgate is running"

  for t in tshark jq tcpdump; do
    if docker exec kali-tailgate sh -c "command -v $t" >/dev/null 2>&1; then ok "$t present in kali-tailgate"
    else bad "$t MISSING in kali-tailgate"; fi
  done

  if docker exec kali-tailgate bash -c 'export PATH="$HOME/.local/bin:$PATH"; command -v claude' >/dev/null 2>&1; then
    ver=$(docker exec kali-tailgate bash -c 'export PATH="$HOME/.local/bin:$PATH"; claude --version' 2>/dev/null)
    ok "claude CLI installed ($ver)"
  else
    soft "claude CLI not found in kali-tailgate — attendees fall back to the printed ANSWER page (dry-run mode)"
  fi

  if docker exec kali-tailgate sh -c 'case "$ANTHROPIC_API_KEY" in sk-ant-*) exit 0;; *) exit 1;; esac' >/dev/null 2>&1; then
    ok "ANTHROPIC_API_KEY present in kali-tailgate (sk-ant- prefix)"
  else
    soft "ANTHROPIC_API_KEY missing/malformed in kali-tailgate — check tailgate/.env is unquoted (see SETUP.md)"
  fi

  for f in /root/tailgate/phishing-email.eml /root/tailgate/network /root/tailgate/ad /root/tailgate/guestlist; do
    if docker exec kali-tailgate test -e "$f" >/dev/null 2>&1; then ok "$f present"
    else bad "$f MISSING in kali-tailgate — run: docker exec -w /root/tailgate kali-tailgate ./reset.sh"; fi
  done
else
  bad "kali-tailgate is not running — see tailgate/SETUP.md Section 1"
fi

echo
echo "== Tailgate/GuestList data integrity (verify.sh, run inside kali-tailgate — needs tshark) =="
if container_running kali-tailgate && docker exec kali-tailgate test -f /root/tailgate/verify.sh >/dev/null 2>&1; then
  out=$(docker exec -w /root/tailgate kali-tailgate ./verify.sh 2>&1)
  echo "$out" | sed 's/^/  /'
  fails_in_verify=$(echo "$out" | grep -o 'RESULT: [0-9]* passed, [0-9]* failed' | grep -o '[0-9]* failed' | grep -o '[0-9]*')
  if [ -n "$fails_in_verify" ] && [ "$fails_in_verify" -eq 0 ]; then
    ok "tailgate/verify.sh: all data checks passed"
  else
    bad "tailgate/verify.sh: ${fails_in_verify:-an unknown number of} check(s) failed (see above) — try: docker exec -w /root/tailgate kali-tailgate ./reset.sh"
  fi
else
  soft "verify.sh not found in kali-tailgate (or container not running) — skipping data-integrity checks"
fi

echo
echo "== FastLane/SpeedBump: Kali container =="
if container_running kali-fastlane; then
  ok "kali-fastlane is running"

  if docker exec kali-fastlane sh -c "command -v jq" >/dev/null 2>&1; then ok "jq present in kali-fastlane"
  else bad "jq MISSING in kali-fastlane"; fi

  if docker exec kali-fastlane bash -c 'export PATH="$HOME/.local/bin:$PATH"; command -v claude' >/dev/null 2>&1; then
    ver=$(docker exec kali-fastlane bash -c 'export PATH="$HOME/.local/bin:$PATH"; claude --version' 2>/dev/null)
    ok "claude CLI installed ($ver)"
  else
    soft "claude CLI not found in kali-fastlane — attendees fall back to the printed ANSWER page (dry-run mode)"
  fi

  if docker exec kali-fastlane sh -c 'case "$ANTHROPIC_API_KEY" in sk-ant-*) exit 0;; *) exit 1;; esac' >/dev/null 2>&1; then
    ok "ANTHROPIC_API_KEY present in kali-fastlane (sk-ant- prefix)"
  else
    soft "ANTHROPIC_API_KEY missing/malformed in kali-fastlane — check fastlane/.env is unquoted (see SETUP.md)"
  fi

  for f in /root/fastlane/app /root/fastlane/speedbump; do
    if docker exec kali-fastlane test -e "$f" >/dev/null 2>&1; then ok "$f present"
    else bad "$f MISSING in kali-fastlane — run: docker exec -w /root/fastlane kali-fastlane ./reset.sh"; fi
  done
else
  bad "kali-fastlane is not running — see fastlane/SETUP.md Section 1"
fi

echo
echo "== FastLane/SpeedBump data integrity (verify.sh, run inside kali-fastlane) =="
if container_running kali-fastlane && docker exec kali-fastlane test -f /root/fastlane/verify.sh >/dev/null 2>&1; then
  out=$(docker exec -w /root/fastlane kali-fastlane ./verify.sh 2>&1)
  echo "$out" | sed 's/^/  /'
  fails_in_verify=$(echo "$out" | grep -o 'RESULT: [0-9]* passed, [0-9]* failed' | grep -o '[0-9]* failed' | grep -o '[0-9]*')
  if [ -n "$fails_in_verify" ] && [ "$fails_in_verify" -eq 0 ]; then
    ok "fastlane/verify.sh: all data checks passed"
  else
    bad "fastlane/verify.sh: ${fails_in_verify:-an unknown number of} check(s) failed (see above) — try: docker exec -w /root/fastlane kali-fastlane ./reset.sh"
  fi
else
  soft "verify.sh not found in kali-fastlane (or container not running) — skipping data-integrity checks"
fi

echo
echo "== Dashcam: Kali container =="
if container_running kali-dashcam; then
  ok "kali-dashcam is running"

  if docker exec kali-dashcam sh -c "command -v jq" >/dev/null 2>&1; then ok "jq present in kali-dashcam"
  else bad "jq MISSING in kali-dashcam"; fi

  if docker exec kali-dashcam sh -c "python3 -c 'import presidio_analyzer, presidio_anonymizer, presidio_image_redactor'" >/dev/null 2>&1; then
    ok "presidio-analyzer/anonymizer/image-redactor importable in kali-dashcam"
  else
    bad "Presidio packages MISSING/broken in kali-dashcam"
  fi

  if docker exec kali-dashcam bash -c 'export PATH="$HOME/.local/bin:$PATH"; command -v claude' >/dev/null 2>&1; then
    ver=$(docker exec kali-dashcam bash -c 'export PATH="$HOME/.local/bin:$PATH"; claude --version' 2>/dev/null)
    ok "claude CLI installed ($ver)"
  else
    soft "claude CLI not found in kali-dashcam — attendees fall back to the printed ANSWER page (dry-run mode)"
  fi

  if docker exec kali-dashcam sh -c 'case "$ANTHROPIC_API_KEY" in sk-ant-*) exit 0;; *) exit 1;; esac' >/dev/null 2>&1; then
    ok "ANTHROPIC_API_KEY present in kali-dashcam (sk-ant- prefix)"
  else
    soft "ANTHROPIC_API_KEY missing/malformed in kali-dashcam — check dashcam/.env is unquoted (see SETUP.md)"
  fi

  if docker exec kali-dashcam test -e /root/dashcam/data >/dev/null 2>&1; then ok "/root/dashcam/data present"
  else bad "/root/dashcam/data MISSING in kali-dashcam — run: docker exec -w /root/dashcam kali-dashcam ./reset.sh"; fi
else
  soft "kali-dashcam is not running — see dashcam/SETUP.md Option A (Option B runs without Docker)"
fi

echo
echo "== Dashcam data integrity (verify.sh, run inside kali-dashcam) =="
if container_running kali-dashcam && docker exec kali-dashcam test -f /root/dashcam/verify.sh >/dev/null 2>&1; then
  out=$(docker exec -w /root/dashcam kali-dashcam ./verify.sh 2>&1)
  echo "$out" | sed 's/^/  /'
  fails_in_verify=$(echo "$out" | grep -o 'RESULT: [0-9]* passed, [0-9]* failed' | grep -o '[0-9]* failed' | grep -o '[0-9]*')
  if [ -n "$fails_in_verify" ] && [ "$fails_in_verify" -eq 0 ]; then
    ok "dashcam/verify.sh: all data checks passed"
  else
    bad "dashcam/verify.sh: ${fails_in_verify:-an unknown number of} check(s) failed (see above) — try: docker exec -w /root/dashcam kali-dashcam ./reset.sh"
  fi
else
  soft "verify.sh not found in kali-dashcam (or container not running) — skipping data-integrity checks"
fi

echo
echo "== Section 2: Casky Box (casky-box/, pulled from GHCR) — shared by all exercises =="
if [ -d "$CASKY_BOX_DIR" ]; then
  ok "casky-box found at $CASKY_BOX_DIR"
else
  bad "casky-box not found at $CASKY_BOX_DIR — set CASKY_BOX_DIR=/path/to/it"
fi

for c in casky-db casky-runner casky-ui; do
  if container_running "$c"; then
    if container_healthy_or_running "$c"; then ok "$c is up and healthy"
    else soft "$c is running but not yet healthy — give it a few seconds and re-run"; fi
  else
    bad "$c is not running — run: (cd $CASKY_BOX_DIR && docker compose pull && docker compose up -d)"
  fi
done

if container_running casky-runner; then
  if docker exec casky-runner casky help >/dev/null 2>&1; then ok "casky-runner: 'casky help' responds"
  else bad "casky-runner: 'casky help' failed — check container logs"; fi

  if docker exec casky-runner test -d /var/casky/evidence >/dev/null 2>&1; then ok "casky-runner: evidence bind mount present"
  else bad "casky-runner: /var/casky/evidence mount missing"; fi

  if docker exec casky-runner sh -c 'case "$ANTHROPIC_API_KEY" in sk-ant-*) exit 0;; *) exit 1;; esac' >/dev/null 2>&1; then
    ok "ANTHROPIC_API_KEY present in casky-runner (sk-ant- prefix)"
  else
    soft "ANTHROPIC_API_KEY missing/malformed in casky-runner — check $CASKY_BOX_DIR/.env"
  fi
fi

if container_running casky-skills; then
  soft "casky-skills init container still running — should have exited 0 after populating the skills volume"
elif docker inspect casky-skills >/dev/null 2>&1; then
  exitcode=$(docker inspect -f '{{.State.ExitCode}}' casky-skills 2>/dev/null)
  [ "$exitcode" = "0" ] && ok "casky-skills: skills library populated (exited 0)" || bad "casky-skills exited $exitcode — skills library may be incomplete"
else
  soft "casky-skills container not found — was 'docker compose up' run at least once?"
fi

if container_running casky-ui; then
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:8766/ 2>/dev/null)
  case "$code" in
    200|30[0-9]) ok "casky-ui reachable at http://localhost:8766 (HTTP $code)" ;;
    "") bad "casky-ui not reachable at http://localhost:8766 (connection failed)" ;;
    *) bad "casky-ui returned HTTP $code at http://localhost:8766" ;;
  esac
fi

if [ "$SKIP_NETWORK" -eq 0 ]; then
  echo
  echo "== External links (README) =="
  code=$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 5 https://casky-ai.github.io/casky-workshops/ 2>/dev/null)
  [ "$code" = "200" ] && ok "wiki reachable (casky-ai.github.io/casky-workshops)" || soft "wiki returned HTTP ${code:-timeout} — check connectivity"

  code=$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 5 https://casky.ai/blog/blackhat-workshop-lab02 2>/dev/null)
  [ "$code" = "200" ] && ok "companion blog reachable (casky.ai/blog/blackhat-workshop-lab02)" || soft "companion blog returned HTTP ${code:-timeout} — check connectivity"
fi

echo
echo "----"
echo "RESULT: $pass passed, $warn warned, $fail failed"
if [ "$fail" -eq 0 ]; then
  echo "READY for the workshop.$( [ "$warn" -gt 0 ] && echo " (review the WARN lines above — non-blocking.)" )"
else
  echo "NOT READY — fix the FAIL lines above and re-run."
fi
exit "$fail"
