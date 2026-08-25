# Casky Workshops

Hands-on materials for live workshop sessions.

## Available

| Folder | Exercise | Wiki | Companion blog |
|---|---|---|---|
| [`tollbooth/`](tollbooth/SETUP.md) | TollBooth / OpenDoor — SSRF → IMDS credential leak → S3 exfil, plus the proactive cloud-config audit that would've prevented it. Trimmed from [BHUSA-Anthropic-CyberSecurity-Skills](https://github.com/mukul975/BHUSA-Anthropic-CyberSecurity-Skills). | [casky-ai.github.io/casky-workshops](https://casky-ai.github.io/casky-workshops/) | [casky.ai/blog/blackhat-workshop-lab02](https://casky.ai/blog/blackhat-workshop-lab02) |

Each exercise's own `SETUP.md` has the full walkthrough — the source of truth, kept in sync with
the hosted wiki. `tollbooth/SETUP.md` covers two ways to run the same scenario: the original
Kali/Claude Code setup (Section 1), and the same data driven through Casky Box (Section 2).

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
repo's `main` branch — the same TollBooth/OpenDoor setup and scenario content as
`tollbooth/SETUP.md` and `tollbooth/Arsenal-CheatSheet-Book.pdf`, reorganized for attendees to
follow along on a phone or second screen during the workshop, with the cheat sheet's answer pages
collapsed by default so attendees can attempt each phase first. To update it, edit both — `docs/`
is derived from `tollbooth/SETUP.md`'s content, not auto-generated from it.
