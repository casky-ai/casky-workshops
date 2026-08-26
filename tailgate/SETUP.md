# Tailgate / GuestList — Simplified Workshop Setup

Two scenarios, one shared story ("Bellwood Logistics"): **Tailgate** (reactive DFIR — a phishing
email → lateral movement → domain compromise, a full 3-act kill chain) and **GuestList**
(proactive audit — find the 3 misconfigurations that let it happen). Full background:
[`NARRATIVE.md`](NARRATIVE.md).

This doc has two independent sections. Run whichever matches today's session — they use the same
data, two different ways of driving the investigation.

- **Section 1** — the same Kali-container pattern as TollBooth/OpenDoor: hand-picked skills,
  symlinked, driven interactively with Claude Code.
- **Section 2** — the same data, run through Casky Box's auto-classifier instead of a curated
  skill list.

Both were run end-to-end against this exact data before writing this doc — not just described.

---

## Section 1 — Kali container, hand-picked skills

### Prerequisites

- Docker, with the `kalilinux/kali-rolling` image (`docker pull kalilinux/kali-rolling` if you
  don't have it yet).
- A `.env` file **in this folder** (`tailgate/.env`, copied from `casky-runner-phase1/.env`) with
  a working `ANTHROPIC_API_KEY`. It's git-ignored and lives here, not the repo root, same reasoning
  as TollBooth's setup:
  ```bash
  cp /path/to/casky-runner-phase1/.env tailgate/.env
  ```

<!-- markdownlint-disable -->
> **Strip the quotes — this will break auth otherwise.** `casky-runner-phase1/.env` writes values
> as `ANTHROPIC_API_KEY="sk-ant-..."` (quoted). `docker run --env-file` does **not** strip quotes —
> Claude Code fails with `Invalid API key`, which looks like a bad/revoked key but isn't. Fix once:
> ```bash
> sed -i.bak -E 's/^([A-Z_][A-Z0-9_]*)="(.*)"$/\1=\2/' tailgate/.env && rm tailgate/.env.bak
> grep '^ANTHROPIC_API_KEY=' tailgate/.env | cut -d= -f2- | grep -c '^sk-ant-'   # confirm: prints 1
> ```

### Steps

```bash
# Run every command below from THIS folder (casky-workshops/tailgate/).

# 0. Start a persistent Kali container with this folder mounted + the shared key available
docker run -d --name kali-tailgate \
  --env-file .env \
  -v "$(pwd)":/root/tailgate \
  kalilinux/kali-rolling sleep infinity

docker exec kali-tailgate test -f /root/tailgate/verify.sh \
  && echo "[+] mount OK" || echo "[!] wrong directory — re-run from casky-workshops/tailgate/"

# 1. tshark, jq, tcpdump
docker exec kali-tailgate bash -c \
  "apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get install -y tshark jq tcpdump python3-scapy git curl ca-certificates"

# 2. Install Claude Code; pre-authenticate with the shared key
docker exec kali-tailgate bash -c "curl -fsSL https://claude.ai/install.sh -o /tmp/install.sh && bash /tmp/install.sh"
docker exec kali-tailgate bash -c 'export PATH="$HOME/.local/bin:$PATH"; claude --version'

# 3. Mount the 10 hand-picked skills into ~/.claude/skills
docker exec -w /root/tailgate kali-tailgate bash -c "chmod +x setup-skills.sh verify.sh reset.sh start.sh && ./setup-skills.sh"

# 4. Run ./verify.sh — expect 14/14 PASS.
docker exec -w /root/tailgate kali-tailgate ./verify.sh

# 5. Bash into the container and start Claude Code interactively.
docker exec -it -w /root/tailgate kali-tailgate bash
#   ...now inside the container's shell:
export PATH="$HOME/.local/bin:$PATH"
./start.sh    # welcome banner + sanity check
claude        # drops into an interactive Claude Code session
```

**Verified end-to-end just now** — all packages installed clean, Claude Code 2.1.246 on `PATH`,
10/10 skills linked, and a real round-trip against the Anthropic API:

```
$ claude --print "Reply with exactly the single word: PONG"
PONG
```

```
== tooling ==
  ok      tshark
  ok      jq
  ok      tcpdump
== act 1 — initial access (T1566.001, T1078, T1133) ==
  PASS  malicious attachment hash present across phishing-email.eml/mail-gateway.log/endpoint-alert.log (3)
  PASS  mail gateway ALLOWED verdict (DMARC p=none let it through) (1)
  PASS  Valid Accounts (T1078) sign-in event present (1)
  PASS  External Remote Services (T1133) VPN session event present (1)
== act 2 — lateral movement (T1570, T1021.002, T1021.001) ==
  PASS  first-time-seen internal host-pair flows (lateral tool transfer signal) (3)
  PASS  SMB/Admin Shares (T1021.002) logon event present (1)
  PASS  RDP (T1021.001) logon event present (1)
== act 3 — domain compromise (T1558.003, T1558.004) ==
  PASS  Kerberoasting TGS burst with RC4 downgrade (T1558.003) (6)
  PASS  AS-REP Roasting (T1558.004) confirmed NOT exploited — the built-in over-claim check (1)
  PASS  SPN-registered service accounts with stale passwords (3)
  PASS  service account with Kerberos preauth disabled (svc-legacyapp) (1)
== guestlist (proactive audit) ==
  PASS  DMARC p=none finding present (2)
  PASS  network segmentation findings present (3)
  PASS  AD-2 correctly labeled probed-not-exploited (matches ad/kerberos-events.txt's NOT FOUND) (1)
----
RESULT: 14 passed, 0 failed
This laptop is READY.
```

`./start.sh` confirmed too:

```
[+] lab data present: Act 1-3 evidence (Tailgate) + guestlist/ (GuestList)
[+] agent skills mounted at /root/.claude/skills (10 skills)
[+] Claude Code found.
    mode: online (shared key)
```

Work Tailgate or GuestList inside that interactive Claude Code session (skills already mounted).
`exit` the `claude` session and the container shell (two `exit`s) between attendees, then run
`docker exec -w /root/tailgate kali-tailgate ./reset.sh` from outside to restore the data.

---

## Section 2 — Same scenarios, run on Casky Box

### Prerequisites

`casky-runner-phase1` running, using its own `.env` — nothing to copy in here:

```bash
cd /path/to/casky-runner-phase1
docker compose up -d
```

If `casky-runner`/`casky-db` are already up, this is a no-op — confirm with `docker compose ps`.

### Steps

```bash
# Run every command below from THIS folder (casky-workshops/tailgate/).
cd /path/to/casky-workshops/tailgate
test -f phishing-email.eml && echo "[+] correct folder" || echo "[!] cd to casky-workshops/tailgate first"

# 1-3. Evidence is already text (unlike TollBooth's pcap, no tshark pre-processing needed) —
#    concatenate each act's files into one bundle per scenario.
{
  echo "=== Act 1 - Phishing email (initial access) ==="; cat phishing-email.eml
  echo; echo "=== Act 1 - Mail gateway delivery/detonation log ==="; cat mail-gateway.log
  echo; echo "=== Act 1 - Endpoint + auth telemetry (execution, valid accounts, external remote service) ==="; cat endpoint-alert.log
  echo; echo "=== Act 2 - Internal netflow baseline vs. incident window (lateral tool transfer) ==="; cat network/netflow.txt
  echo; echo "=== Act 2 - SMB/RDP Windows Security event excerpts (lateral movement) ==="; cat network/smb-rdp-events.txt
  echo; echo "=== Act 3 - Kerberos event excerpts (Kerberoasting / AS-REP Roasting) ==="; cat ad/kerberos-events.txt
  echo; echo "=== Act 3 - Service account / SPN audit export ==="; cat ad/spn-listing.txt
} > tailgate-full.txt

for f in guestlist/*.json; do echo "--- $(basename "$f") ---"; cat "$f"; echo; done > guestlist-full.txt

# 4. Copy both into casky-runner-phase1's evidence bind mount (live mount, no restart needed).
cp tailgate-full.txt guestlist-full.txt /path/to/casky-runner-phase1/evidence/
docker exec casky-runner ls /var/casky/evidence/   # confirm they're already there

# 5. Investigate — Tailgate (reactive). --auto runs every step's agent for real;
#    drop --auto for the manual mode where you paste each step's tool output yourself.
docker exec -it casky-runner casky harness --auto -i /var/casky/evidence/tailgate-full.txt

# 6. Investigate — GuestList (proactive)
docker exec -it casky-runner casky harness --auto -i /var/casky/evidence/guestlist-full.txt
```

**Verified just now** against the real Tailgate evidence — the classifier independently found and
validated **11 MITRE techniques at 87.0% confidence** from the combined phishing/network/AD text
alone, no hints, no pre-picked skill list (Postgres investigation id
`25d28e33-22ed-4a53-bcae-067ec2860bb5`):

| # | Technique | Skill | Category |
|---|---|---|---|
| 1 | Phishing: Spearphishing Attachment (T1566.001) | analyzing-email-headers-for-phishing-investigation | forensics |
| 2 | Phishing: Spearphishing Attachment (T1566.001) | analyzing-macro-malware-in-office-documents | malware |
| 3 | User Execution: Malicious File (T1204.002) | analyzing-lnk-file-and-jump-list-artifacts | forensics |
| 4 | Command and Scripting Interpreter: PowerShell (T1059.001) | analyzing-powershell-script-block-logging | incident-response |
| 5 | Command and Scripting Interpreter: PowerShell (T1059.001) | detecting-suspicious-powershell-execution | threat-hunting |
| 6 | Ingress Tool Transfer (T1105) | analyzing-indicators-of-compromise | threat-intel |
| 7 | Valid Accounts: Default Accounts (T1078.001) | analyzing-security-logs-with-splunk | incident-response |
| 8 | Valid Accounts: Default Accounts (T1078.001) | analyzing-windows-event-logs-in-splunk | incident-response |
| 9 | Remote Services: RDP (T1021.001) | detecting-rdp-brute-force-attacks | threat-hunting |
| 10 | Remote Services: SMB/Windows Admin Shares (T1021.002) | moving-laterally-with-netexec | exploitation |
| 11 | Remote Services: SMB/Windows Admin Shares (T1021.002) | analyzing-windows-event-logs-in-splunk | incident-response |
| 12 | Steal or Forge Kerberos Tickets: AS-REP Roasting (T1558.004) | deploying-active-directory-honeytokens | recon |
| 13 | Steal or Forge Kerberos Tickets: Kerberoasting (T1558.003) | analyzing-windows-event-logs-in-splunk | incident-response |
| 14 | Account Discovery: Domain Account (T1087.002) | conducting-internal-reconnaissance-with-bloodhound-ce | exploitation |
| 15 | Phishing: Spearphishing Attachment (T1566.001) | building-incident-timeline-with-timesketch | incident-response |
| 16 | Ingress Tool Transfer (T1105) | collecting-indicators-of-compromise | incident-response |
| 17 | Valid Accounts: Default Accounts (T1078.001) | containing-active-breach | incident-response |

**Worth noting, live-caught:** row 12 is exactly the built-in "catch the agent" check this scenario
is designed around — the classifier validated AS-REP Roasting (T1558.004) as present in the
evidence purely from `svc-legacyapp`'s exposed preauth-disabled flag, even though
`ad/kerberos-events.txt` explicitly shows no matching request was ever made. **Validated ≠
confirmed exploited.** This is the same nuance an attendee (or the agent, unprompted) needs to
catch — see `NARRATIVE.md`'s Act 3 section.

GuestList's evidence produced an even richer result — **15 MITRE techniques at 70.5% confidence**,
22 selected skills (Postgres investigation id `84031c23-ed85-490f-9150-4c73ac50de22`), correctly
picking up T1570 (Lateral Tool Transfer), both phishing sub-techniques, and the Kerberos findings
purely from the correlation notes embedded in the audit JSON.

`--auto` runs every step's agent for real and produces a real, inspectable tool-call transcript per
step (`[VERIFIED] Skill script executed: YES/NO`). Open casky-ui (`http://localhost:8766`)
afterward for the Plan / Execution / Findings / Remediation tabs.

### What's different from Section 1

| | Section 1 (Kali + Claude Code) | Section 2 (Casky Box) |
|---|---|---|
| Skill selection | 10 hand-picked skills, symlinked | Auto-classified from all 818 skills, per investigation |
| Agent runtime | Claude Code installed in the container | One shared `casky-runner` container |
| Verification | `verify.sh` — 14 raw grep/jq checks on the data | `[VERIFIED]` transcript per step |
| Output | Cheat-sheet answer pages | Structured plan → findings → CISO-style consolidated report |
| Reset between attendees | `./reset.sh` (<10s) | Each investigation run is already fresh |

---

## Cleanup

`./cleanup.sh` removes everything a run of this exercise creates outside this folder: the
`kali-tailgate` container (Section 1) and any evidence files Section 2 copied into
`casky-runner-phase1/evidence/`. Safe to re-run.

```bash
./cleanup.sh                                                  # container + copied evidence
./cleanup.sh --casky-runner-path ../../casky-runner-phase1    # if that repo isn't a sibling
./cleanup.sh --with-image                                      # also remove kalilinux/kali-rolling
```

It does **not** touch `casky-runner-phase1`'s own containers, and doesn't delete Postgres
investigation records — those are history, not litter.

---

*Source narrative and technique framing trimmed from `casky_pipeline/playbooks/{incident-response-initial-access,network-lateral-movement,active-directory-kerberoasting}.yaml` — same repo, real MITRE technique IDs, no invented story beats.*
