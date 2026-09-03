# FastLane / SpeedBump — Simplified Workshop Setup

Two scenarios, one shared story ("Loopline" — a customer-support SaaS vibe-coded in a weekend):
**FastLane** (reactive DFIR — the breach that happened because nobody checked) and **SpeedBump**
(proactive audit — find the Top 10 gotchas before they ship). Full background:
[`NARRATIVE.md`](NARRATIVE.md).

This doc has two independent sections. Run whichever matches today's session — they use the same
data, two different ways of driving the investigation.

---

## Section 1 — Kali container, hand-picked skills

### Prerequisites

- Docker (no local build needed — `docker pull` fetches the pre-built image from GHCR).
- A `.env` file **in this folder** (`fastlane/.env`, copied from `casky-runner-phase1/.env`,
  quotes stripped) — same steps as TollBooth/Tailgate's Section 1.

### Steps

```bash
# Run every command below from THIS folder (casky-workshops/fastlane/).

# 0. Pull the pre-built image from GHCR (rebuilt nightly with the latest patches) instead
#    of building locally — much faster at a live session.
docker pull ghcr.io/casky-ai/casky-fastlane:latest
docker tag ghcr.io/casky-ai/casky-fastlane:latest casky-fastlane

# Fallback, kept for reference — tools, Claude Code, and the 10 skills are still baked
# into the image at build time (see Dockerfile); rebuild locally if you're iterating on
# the Dockerfile/skill list itself, or if GHCR is unreachable (offline/air-gapped venue):
#   docker build -t casky-fastlane .

docker run -d --name kali-fastlane \
  --env-file .env \
  -v "$(pwd)":/root/fastlane \
  casky-fastlane

docker exec kali-fastlane test -f /root/fastlane/verify.sh \
  && echo "[+] mount OK" || echo "[!] wrong directory"

# 1. Run ./verify.sh — expect 12/12 PASS.
docker exec -w /root/fastlane kali-fastlane ./verify.sh

# 2. Bash into the container and start Claude Code interactively.
docker exec -it -w /root/fastlane kali-fastlane bash
#   ...now inside the container's shell:
export PATH="$HOME/.local/bin:$PATH"
./start.sh
claude
```

**Verified just now** — `docker pull ghcr.io/casky-ai/casky-fastlane:latest` (no `docker login`
needed, publicly pullable), Claude Code 2.1.258 on `PATH`, 10/10 skills linked, and `verify.sh`
passes 12/12 against a container run from that image:

```
== tooling ==
  ok      jq
  ok      grep
== gotcha 1/5 — RLS misconfiguration ==
  PASS  customers table: RLS disabled entirely (1)
  PASS  tickets table: RLS enabled but policy is USING (true) (1)
== gotcha 2/8 — secret exposure (same key, two leak paths) ==
  PASS  service-role key present across bundle/git-history/access-log (3)
== gotcha 3 — slopsquatting, caught pre-merge ==
  PASS  main branch package.json does NOT include the hallucinated package (0)
  PASS  the hallucinated package IS referenced in the unmerged PR branch (1)
== gotcha 4 — IDOR on /api/tickets/[id] ==
  PASS  sequential ticket-ID enumeration present in access log (5)
== gotcha 7 — CORS wildcard ==
  PASS  Access-Control-Allow-Origin: * present in next.config.js (1)
== gotcha 9 — exposed debug route ==
  PASS  unauthenticated hit on /api/debug/seed present in access log (2)
== gotcha 6 — dev-environment supply chain (MCP auto-trust) ==
  PASS  starter template's auto-trusted MCP config documented (1)
== gotcha 10 — general code scan ==
  PASS  general OWASP-flavored findings present (XSS, no rate-limit) (2)
== speedbump (proactive audit) ==
  PASS  correlation labels present across all 4 audit reports (8)
  PASS  slopsquatting finding correctly labeled not-exploited (matches pr-branch-diff.txt) (1)
----
RESULT: 12 passed, 0 failed
This laptop is READY.
```

The interactive round-trip below (`./start.sh` + a live `claude --print`) was verified against
this same image contents when this flow was first built — now baked in at `docker build` time
instead of installed live over `docker exec`:

```
[+] lab data present: app/ (FastLane) + speedbump/ (SpeedBump)
[+] agent skills mounted at /root/.claude/skills (10 skills)
[+] Claude Code found.
    mode: online (shared key)

$ claude --print "Reply with exactly the single word: PONG"
PONG
```

---

## Section 2 — Same scenarios, run on Casky Box

### Prerequisites

`casky-runner-phase1` running (`docker compose up -d`), same as every other exercise in this repo.

### Steps

```bash
cd /path/to/casky-workshops/fastlane
test -f app/rls-policies.json && echo "[+] correct folder" || echo "[!] cd to casky-workshops/fastlane first"

{
  echo "=== Gotcha 1/5 - Supabase RLS policy export ==="; cat app/rls-policies.json
  echo; echo "=== Gotcha 2 - Production client bundle excerpt (secret exposure) ==="; cat app/client-bundle-excerpt.txt
  echo; echo "=== Gotcha 3 - main branch package.json ==="; cat app/package.json
  echo; echo "=== Gotcha 3 - open PR branch diff (slopsquatting) ==="; cat app/pr-branch-diff.txt
  echo; echo "=== Gotcha 4 - /api/tickets/[id] route source (IDOR) ==="; cat app/api-tickets-route.js
  echo; echo "=== Breach evidence - access logs ==="; cat app/access-log.txt
  echo; echo "=== Gotcha 7 - next.config.js CORS headers ==="; cat app/next-config-cors.txt
  echo; echo "=== Gotcha 8 - git history env leak ==="; cat app/git-history-env-leak.txt
  echo; echo "=== Gotcha 6 - dev environment / MCP auto-trust audit ==="; cat app/dev-environment-audit.txt
  echo; echo "=== Gotcha 10 - general code scan summary ==="; cat app/code-scan-summary.txt
} > fastlane-full.txt

for f in speedbump/*.json; do echo "--- $(basename "$f") ---"; cat "$f"; echo; done > speedbump-full.txt

cp fastlane-full.txt speedbump-full.txt /path/to/casky-runner-phase1/evidence/
docker exec casky-runner ls /var/casky/evidence/

# Investigate — FastLane (reactive)
docker exec -it casky-runner casky harness --auto -i /var/casky/evidence/fastlane-full.txt

# Investigate — SpeedBump (proactive)
docker exec -it casky-runner casky harness --auto -i /var/casky/evidence/speedbump-full.txt
```

**Verified just now** against the real Loopline evidence — the classifier independently found and
validated **7 MITRE techniques at 84.5% confidence** from the app-side evidence alone, no hints
(Postgres investigation id `acd32379-8c20-4672-985d-eb116d4e689a`):

| # | Technique | Skill | Category |
|---|---|---|---|
| 1 | Exploit Public-Facing Application (T1190) | conducting-api-security-testing | web-app |
| 2 | Exploit Public-Facing Application (T1190) | detecting-api-enumeration-attacks | web-app |
| 3 | Exploit Public-Facing Application (T1190) | exploiting-idor-vulnerabilities | web-app |
| 4 | Unsecured Credentials (T1552) | detecting-aws-credential-exposure-with-trufflehog | cloud |
| 5 | Unsecured Credentials (T1552) | analyzing-sbom-for-supply-chain-vulnerabilities | recon |
| 6 | Gather Victim Identity Information (T1526) | enumerating-cloud-with-cloudfox | cloud |
| 7 | Gather Victim Identity Information (T1526) | detecting-shadow-api-endpoints | web-app |
| 8 | Account Discovery (T1087) | detecting-broken-object-property-level-authorization | web-app |
| 9 | Account Discovery (T1087) | testing-api-for-broken-object-level-authorization | web-app |
| 10 | Valid Accounts (T1078) | analyzing-api-gateway-access-logs | web-app |
| 11 | Valid Accounts (T1078) | detecting-anomalous-authentication-patterns | threat-hunting |
| 12 | Trusted Relationship (T1199) | detecting-supply-chain-attacks-in-ci-cd | incident-response |
| 13 | Trusted Relationship (T1199) | managing-third-party-vendor-risk | recon |

SpeedBump's evidence produced an even richer, and notably self-aware, result —
**6 MITRE techniques at 85.5% confidence**, 20 selected skills (Postgres id
`9ea4e0cd-1933-4b18-acc1-326a85ccd543`). **Worth noting, live-caught:** the classifier's own
evidence-gap reasoning explicitly named **CVE-2025-48757** unprompted — asking to confirm whether
Loopline's RLS-disabled default "matches the known CVE-2025-48757 pattern" — independently
converging on the exact real-world incident this scenario is modeled on, from the audit data
alone.

`--auto` runs every step's agent for real and produces a real, inspectable tool-call transcript
per step (`[VERIFIED] Skill script executed: YES/NO`). Open casky-ui (`http://localhost:8766`)
afterward for the Plan / Execution / Findings / Remediation tabs.

---

## Cleanup

```bash
./cleanup.sh                                                  # container + copied evidence
./cleanup.sh --casky-runner-path ../../casky-runner-phase1
./cleanup.sh --with-image
```

Same non-destructive guarantees as every other exercise in this repo — see `NARRATIVE.md` for the
full story and correlation labels behind each finding.

---

*Grounded in real, sourced 2025-2026 incidents — CVE-2025-48757 (Lovable), the Moltbook breach,
Base44 (Wiz), GitGuardian's 2026 secrets report, and the slopsquatting research — see
`plans/042_fastlane_speedbump_workshop.md` for full citations.*
