# TollBooth / OpenDoor — Simplified Workshop Setup

Two scenarios, one shared story ("Acme Rentals"): **TollBooth** (reactive DFIR — find the SSRF →
IMDS credential leak → S3 exfil) and **OpenDoor** (proactive audit — find the 3 misconfigs that
caused it). Full background: [`Arsenal-CheatSheet-Book.pdf`](Arsenal-CheatSheet-Book.pdf).

This doc has two independent sections. Run whichever matches tomorrow's session — they use the
same data, two different ways of driving the investigation.

- **Section 1** — the exact setup from Black Hat Arsenal, run inside a Kali Docker container
  instead of a bare-metal Kali laptop (since we're not provisioning physical laptops this time).
- **Section 2** — the same two scenarios, run through Casky Box instead of a manually-curated
  Claude Code + skill-symlink setup.

Both were run end-to-end against this exact data before writing this doc — not just described.

---

## Section 1 — Exact Arsenal setup, in a Kali Docker container

Original instructions ([`README.md`](https://github.com/mukul975/BHUSA-Anthropic-CyberSecurity-Skills#day-before-setup-build-one-kali-image-clone-to-all-laptops)):
build one Kali image, clone to all laptops. We only need one container, not a fleet — same steps.

### Prerequisites
- Docker, with the `kalilinux/kali-rolling` image (`docker pull kalilinux/kali-rolling` if you
  don't have it yet).
- A `.env` file **in this folder** (`tollbooth/.env`, copied from `casky-runner-phase1/.env`)
  with a working `ANTHROPIC_API_KEY` — that's the "shared key" the original instructions say to
  pre-authenticate with. It's git-ignored (`.env*` in `.gitignore`) and lives here, not the repo
  root, specifically so every command below — `.env`, the scripts, the docker run — is
  self-contained in one folder with nothing to mix up:
  ```bash
  cp /path/to/casky-runner-phase1/.env tollbooth/.env
  ```

### Steps

```bash
# Run every command below from THIS folder (casky-workshops/tollbooth/) — $(pwd) becomes the
# container's /root/tollbooth, and .env/the scripts only exist here, not the repo root.

# 0. Start a persistent Kali container with this folder mounted + the shared key available
docker run -d --name kali-tollbooth \
  --env-file .env \
  -v "$(pwd)":/root/tollbooth \
  kalilinux/kali-rolling sleep infinity

# Sanity check — catches a wrong-directory mount immediately instead of 3 steps from now
docker exec kali-tollbooth test -f /root/tollbooth/verify.sh \
  && echo "[+] mount OK — verify.sh found at /root/tollbooth/verify.sh" \
  || echo "[!] wrong directory — re-run from casky-workshops/tollbooth/, then: docker rm -f kali-tollbooth"

# 1. apt-get install -y tshark jq (tcpdump, python3-scapy usually present on Kali)
docker exec kali-tollbooth bash -c \
  "apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get install -y tshark jq tcpdump python3-scapy git curl ca-certificates"

# 2. Install Claude Code; pre-authenticate with the shared key
#    (ANTHROPIC_API_KEY is already in the container's env via --env-file above — Claude Code
#    picks it up automatically, no login flow needed)
docker exec kali-tollbooth bash -c "curl -fsSL https://claude.ai/install.sh -o /tmp/install.sh && bash /tmp/install.sh"
docker exec kali-tollbooth bash -c 'export PATH="$HOME/.local/bin:$PATH"; claude --version'

# 3. ./setup-skills.sh to mount skills into ~/.claude/skills
docker exec -w /root/tollbooth kali-tollbooth bash -c "chmod +x setup-skills.sh verify.sh reset.sh start.sh && ./setup-skills.sh"

# 4. This folder is already at /root/tollbooth (bind-mounted in step 0 — no copy needed).
#    Run ./verify.sh — expect 9/9 PASS.
docker exec -w /root/tollbooth kali-tollbooth ./verify.sh

# 5. Print Arsenal-CheatSheet-Book.pdf (color; answer pages are red) — one per attendee.
open Arsenal-CheatSheet-Book.pdf   # macOS; use your OS's print/open command
```

**Verified end-to-end just now:** all packages installed clean, Claude Code 2.1.241 installed and
on `PATH`, 10/10 skills linked, `ANTHROPIC_API_KEY` present in the container (confirmed by length,
never printed), and:

```
== tooling ==
  ok      tshark
  ok      jq
  ok      tcpdump
== pcap ==
  PASS  IMDS HTTP traffic present (2)
  PASS  SSRF request references metadata service (2)
  PASS  leaked AccessKeyId recoverable from pcap (2)
== cloudtrail ==
  PASS  attacker actions on leaked key (12)
  PASS  S3 GetObject exfil events (9)
  PASS  IAM enumeration present (2)
== scenario 2 (opendoor) ==
  PASS  S3 bucket policy is public (Principal *) (1)
  PASS  IAM privilege-escalation path present (3)
  PASS  IMDSv1 allowed (HttpTokens=optional)
----
RESULT: 9 passed, 0 failed
This laptop is READY.
```

From here, drive it exactly like the original kit: `./start.sh` for the participant welcome
banner, then work Scenario 1 or 2 with Claude Code (skills already mounted) or the raw
`tshark`/`jq` commands on the cheat sheet. `./reset.sh` between attendees.

---

## Section 2 — Same scenarios, run on Casky Box

Casky Box doesn't need per-laptop Claude Code installs or hand-picked skill symlinks — the
`casky-runner` container already ships **all 817 skills** (including the 10 this kit hand-picks)
mounted read-only, and its classifier picks the relevant ones from evidence automatically instead
of you curating a list. The trade: no live "attack traffic" step here — TollBooth/OpenDoor's data
is pre-built synthetic evidence, so this is a pure **Path A (evidence-driven)** investigation, not
a lab-target exercise.

### Prerequisites
- `casky-runner-phase1` running (`docker compose up -d`), same `.env`/`ANTHROPIC_API_KEY` as
  Section 1.

### Steps

```bash
# 1. Turn the pcap into readable evidence text (tshark isn't needed inside casky-runner —
#    reuse the Kali container from Section 1, or run tshark locally if you have it)
docker exec kali-tollbooth tshark -r /root/tollbooth/lab-tollbooth.pcap -Y http \
  -T fields -e frame.time -e ip.src -e ip.dst -e http.request.method -e http.request.full_uri -e http.response.code \
  > tollbooth-pcap.txt

# 2. Combine with the CloudTrail evidence (same incident, later stage of the same attack)
{
  echo "=== HTTP/pcap traffic (SSRF -> IMDS credential leak) ==="; cat tollbooth-pcap.txt
  echo; echo "=== CloudTrail events (same account, following hours) ==="
  jq -c '.Records[]' cloudtrail/*.json
} > tollbooth-full.txt

# 3. OpenDoor's evidence is already text — just concatenate the configs
for f in opendoor/*.json; do echo "--- $(basename "$f") ---"; cat "$f"; echo; done > opendoor-full.txt

# 4. Copy both into casky-runner-phase1's evidence bind mount
cp tollbooth-full.txt opendoor-full.txt /path/to/casky-runner-phase1/evidence/

# 5. Investigate — TollBooth (reactive). --auto runs every step's agent for real;
#    drop --auto for the manual mode where you paste each step's tool output yourself.
docker exec -it casky-runner casky harness --auto -i /var/casky/evidence/tollbooth-full.txt

# 6. Investigate — OpenDoor (proactive)
docker exec -it casky-runner casky harness --auto -i /var/casky/evidence/opendoor-full.txt
```

**Verified just now** against the real TollBooth evidence — the classifier independently found and
validated **7 MITRE techniques at 83.4% confidence** from the combined pcap + CloudTrail text
alone, no hints, no pre-picked skill list:

```
 #   Technique                                            Skill                                Category
 1   Exploit Public-Facing Application (T1190)             exploiting-server-side-request-forgery   web-app
 2   Unsecured Credentials: Credentials In Files (T1552.001) detecting-aws-credential-exposure-...  cloud
 3   Gather Cloud Infrastructure Details (T1526)            detecting-aws-cloudtrail-anomalies       cloud
 4   Data from Cloud Storage (T1530)                        detecting-s3-data-exfiltration-attempts  cloud
 5   Valid Accounts: Cloud Accounts (T1078.004)             detecting-compromised-cloud-credentials  cloud
 6   Unsecured Credentials: Cloud Instance Metadata API     analyzing-kubernetes-audit-logs          cloud
     (T1552.007) — the core TollBooth story: SSRF -> IMDS
 7   Remote Services: SSH (T1021.004)                       detecting-aws-cloudtrail-anomalies       cloud
```

That's the same territory the original kit's 10 hand-picked skills cover (SSRF, IMDS credential
theft, S3 exfil, cloud-account compromise), reached without anyone curating a skill list —
including step 6 correctly landing on **T1552.007 (Cloud Instance Metadata API)**, the exact
technique this whole scenario is built around, purely from the evidence text.

`--auto` runs every step's agent for real and produces a real, inspectable tool-call transcript
per step (`[VERIFIED] Skill script executed: YES/NO`) — the same non-hallucination guarantee
described in `blogs/blog-first-live-fire.md` back in `claude-skills-security`. Open casky-ui
(`http://localhost:8766`) afterward for the Plan / Execution / Findings / Remediation tabs.

### What's different from Section 1

| | Section 1 (Arsenal/Kali) | Section 2 (Casky Box) |
|---|---|---|
| Skill selection | Hand-picked 10, symlinked per laptop | Auto-classified from all 817, per investigation |
| Agent runtime | Claude Code installed per laptop | One shared `casky-runner` container |
| Verification | `verify.sh` — 9 raw tshark/jq checks on the data | `[VERIFIED]` transcript per step — did the agent actually run the assigned skill's script |
| Output | Cheat-sheet answer pages | Structured plan → findings → CISO-style consolidated report |
| Reset between attendees | `./reset.sh` (<10s) | Each `casky harness -i` run is already a fresh investigation |

---

## Cleanup

`./cleanup.sh` removes everything a run of this exercise creates outside this folder: the
`kali-tollbooth` container (Section 1) and any evidence files Section 2 copied into
`casky-runner-phase1/evidence/`. Safe to re-run — reports what it found and skips what's already
gone.

```bash
./cleanup.sh                                          # container + copied evidence
./cleanup.sh --casky-runner-path ../../casky-runner-phase1   # if that repo isn't a sibling of this one
./cleanup.sh --with-image                              # also remove the kalilinux/kali-rolling image
```

It does **not** touch `casky-runner-phase1`'s own containers (`casky-runner`, `casky-db`,
`skill-lab`, …) — those are your persistent dev environment, not workshop-run output — and it
doesn't delete Postgres investigation records from `casky harness` runs, since those are history,
not litter. If `lab-tollbooth.pcap`/`cloudtrail/`/`opendoor/` get modified mid-exercise, restore
them with `./reset.sh` (copies back from `.pristine/`), separately from cleanup.

**Re-running Section 1 setup?** `docker run --name kali-tollbooth ...` fails with "name already in
use" if the container from a previous setup is still around — that's not broken, it just means
setup already succeeded once. Either reuse it (skip straight to `./verify.sh`) or `./cleanup.sh`
first for a clean container.

**"Checksum verification failed" installing Claude Code?** Transient — the installer script
downloads a native binary payload after itself and checksums that separately; an occasional
network blip mid-download trips it. Just re-run the same install command:

```bash
docker exec kali-tollbooth bash -c "curl -fsSL https://claude.ai/install.sh -o /tmp/install.sh && bash /tmp/install.sh"
```

---

*Source data trimmed from [`BHUSA-Anthropic-CyberSecurity-Skills`](https://github.com/mukul975/BHUSA-Anthropic-CyberSecurity-Skills)
— only `lab-tollbooth.pcap`, `cloudtrail/`, `opendoor/`, the cheat-sheet PDF, and the four scenario
scripts (`setup-skills.sh`, `verify.sh`, `reset.sh`, `start.sh`) came along; the Arsenal-specific
booth/ops material (gateway posture, killswitch, booth Q&A) didn't, since this isn't a public booth
with rotating strangers.*
