#!/usr/bin/env bash
# TollBooth / OpenDoor — workshop readiness check.
# Run this right before attendees show up. Checks BOTH sections:
#   Section 1 (Arsenal/Kali)  -> kali-tollbooth container + tooling + lab data
#   Section 2 (Casky Box)     -> casky-runner-phase1's docker compose stack
# Safe to re-run any number of times; makes no changes.
#
# Usage:
#   ./scripts/workshop-check.sh
#   CASKY_RUNNER_DIR=/path/to/casky-runner-phase1 ./scripts/workshop-check.sh
#   ./scripts/workshop-check.sh --skip-network   # skip the wiki/blog reachability checks (e.g. flaky venue wifi)

set -u
cd "$(dirname "$0")/.."   # repo root (casky-workshops/)

SKIP_NETWORK=0
for a in "$@"; do
  [ "$a" = "--skip-network" ] && SKIP_NETWORK=1
done

# Sibling repo by default (../casky-runner-phase1) — override if yours lives elsewhere.
CASKY_RUNNER_DIR="${CASKY_RUNNER_DIR:-$(cd .. 2>/dev/null && pwd)/casky-runner-phase1}"

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
echo "  TollBooth / OpenDoor — workshop readiness check"
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
echo "== Section 2: Casky Box (casky-runner-phase1) =="
if [ -d "$CASKY_RUNNER_DIR" ]; then
  ok "casky-runner-phase1 found at $CASKY_RUNNER_DIR"
else
  bad "casky-runner-phase1 not found at $CASKY_RUNNER_DIR — set CASKY_RUNNER_DIR=/path/to/it"
fi

for c in casky-db casky-runner casky-ui; do
  if container_running "$c"; then
    if container_healthy_or_running "$c"; then ok "$c is up and healthy"
    else soft "$c is running but not yet healthy — give it a few seconds and re-run"; fi
  else
    bad "$c is not running — run: (cd $CASKY_RUNNER_DIR && docker compose up -d)"
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
    soft "ANTHROPIC_API_KEY missing/malformed in casky-runner — check $CASKY_RUNNER_DIR/.env"
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
