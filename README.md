# Casky Workshops

Hands-on materials for live workshop sessions.

## Available

| Folder | Exercise | Wiki | Companion blog |
|---|---|---|---|
| [`tollbooth/`](tollbooth/SETUP.md) | TollBooth / OpenDoor — SSRF → IMDS credential leak → S3 exfil, plus the proactive cloud-config audit that would've prevented it. Trimmed from [BHUSA-Anthropic-CyberSecurity-Skills](https://github.com/mukul975/BHUSA-Anthropic-CyberSecurity-Skills). | [casky-ai.github.io/casky-workshops](https://casky-ai.github.io/casky-workshops/) | [casky.ai/blog/blackhat-workshop-lab02](https://casky.ai/blog/blackhat-workshop-lab02) |
| [`tailgate/`](tailgate/SETUP.md) | Tailgate / GuestList — a phishing email → lateral movement → AD domain compromise (Kerberoasting/AS-REP), a 3-act kill chain, plus the proactive email/network/AD audit that would've prevented it. | [tailgate.html](https://casky-ai.github.io/casky-workshops/tailgate.html) | — |
| [`fastlane/`](fastlane/SETUP.md) | FastLane / SpeedBump — "The Vibe Coding Security Top 10 Gotchas." A vibe-coded SaaS app breached through a real, sourced pattern (RLS misconfig, leaked secrets, IDOR, slopsquatting), grounded in CVE-2025-48757/Moltbook/Base44, plus the proactive pre-ship audit. | [fastlane.html](https://casky-ai.github.io/casky-workshops/fastlane.html) | — |

Each exercise's own `SETUP.md` has the full walkthrough — the source of truth, kept in sync with
the hosted wiki. Each `SETUP.md` covers two ways to run the same scenario: the original
Kali/Claude Code setup (Section 1), and the same data driven through Casky Box (Section 2).

## Skill-focused workshops

A separate, lighter series: each one is built around a single skill from the Anthropic
Cybersecurity Skills library, exercised end-to-end against one scenario, no reactive/proactive
pair and no Casky Box section.

| Folder | Exercise | Wiki |
|---|---|---|
| [`dashcam/`](dashcam/SETUP.md) | Dashcam — catch PII before it leaves the building, using `anonymizing-pii-with-microsoft-presidio` across a support-ticket export, a Slack thread, a driver-records export, and a dashcam frame image. | [dashcam.html](https://casky-ai.github.io/casky-workshops/dashcam.html) |

`dashcam/SETUP.md` covers two ways to run it: Option A (Docker, same pattern as the other
workshops) and Option B (local Python, no Docker).

## Docker images

Every workshop's `Dockerfile` bakes in its tools, Claude Code, and skill set at build time (see
[`CONTRIBUTING.md`](CONTRIBUTING.md)) instead of live-installing over `docker exec`. All five are
published to GHCR and rebuilt nightly (tools/OS patches, Trivy-scanned, report-only) by
[`.github/workflows/docker-images.yml`](.github/workflows/docker-images.yml) — **at a live
session, `docker pull` the pre-built image** (each workshop's `SETUP.md` leads with this);
`docker build -t casky-<name> .` inside that workshop's folder is the fallback for iterating on a
Dockerfile or when GHCR is unreachable:

- `ghcr.io/casky-ai/casky-fastlane`
- `ghcr.io/casky-ai/casky-tailgate`
- `ghcr.io/casky-ai/casky-tollbooth`
- `ghcr.io/casky-ai/casky-dashcam`
- `ghcr.io/casky-ai/casky-loopline` (the FastLane Lightning Lesson's Loopline demo server)

## Readiness check

Right before attendees arrive, run:

```bash
./scripts/workshop-check.sh
```

It checks both sections in one pass — `kali-tollbooth` (tooling, lab data, `verify.sh`'s 9/9) and
the `casky-runner-phase1` Casky Box stack (containers healthy, `casky-ui` reachable, evidence
mount, API key) — plus the wiki and companion blog links above. Exits non-zero if anything needs
attention before you start. Pass `--skip-network` on flaky venue wifi, or set `CASKY_RUNNER_DIR`
if `casky-runner-phase1` isn't a sibling of this repo.

## Wiki

`docs/` is a static, dependency-free site (no build step) published via GitHub Pages from this
repo's `main` branch — the same setup and scenario content as each exercise's own `SETUP.md`
(and, for TollBooth/OpenDoor, `tollbooth/Arsenal-CheatSheet-Book.pdf`), reorganized for attendees
to follow along on a phone or second screen during the workshop, with answer pages collapsed by
default so attendees can attempt each phase first. To update it, edit both — `docs/` is derived
from each exercise's `SETUP.md`, not auto-generated from it.
