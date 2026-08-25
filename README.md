# Casky Workshops

Hands-on materials for live workshop sessions.

## Available

| Folder | Exercise | Wiki | Companion blog |
|---|---|---|---|
| [`tollbooth/`](tollbooth/SETUP.md) | TollBooth / OpenDoor — SSRF → IMDS credential leak → S3 exfil, plus the proactive cloud-config audit that would've prevented it. Trimmed from [BHUSA-Anthropic-CyberSecurity-Skills](https://github.com/mukul975/BHUSA-Anthropic-CyberSecurity-Skills). | [casky-ai.github.io/casky-workshops](https://casky-ai.github.io/casky-workshops/) | [blog-tollbooth-opendoor.md](https://github.com/casky-ai/claude-skills-security/blob/master/blogs/blog-tollbooth-opendoor.md) |

Each exercise's own `SETUP.md` has the full walkthrough — the source of truth, kept in sync with
the hosted wiki. `tollbooth/SETUP.md` covers two ways to run the same scenario: the original
Kali/Claude Code setup (Section 1), and the same data driven through Casky Box (Section 2).

## Wiki

`docs/` is a static, dependency-free site (no build step) published via GitHub Pages from this
repo's `main` branch — the same TollBooth/OpenDoor setup and scenario content as
`tollbooth/SETUP.md` and `tollbooth/Arsenal-CheatSheet-Book.pdf`, reorganized for attendees to
follow along on a phone or second screen during the workshop, with the cheat sheet's answer pages
collapsed by default so attendees can attempt each phase first. To update it, edit both — `docs/`
is derived from `tollbooth/SETUP.md`'s content, not auto-generated from it.
