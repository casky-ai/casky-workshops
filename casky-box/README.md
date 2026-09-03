# Casky Box — shared by every workshop's Section 2

Casky Box (the `casky-runner` auto-classifier + Postgres + skills library, and
optionally the `casky-ui` viewer), pulled pre-built from GHCR. This folder is
what every workshop's "Section 2 — Same scenarios, run on Casky Box" points
at — start it once here, then work FastLane, Tailgate, or TollBooth (and each
one's proactive-audit pair) against the same running instance.

There's no repo to clone for this anymore — the three images below are
published straight to GHCR, so `docker compose pull && docker compose up -d`
is the whole setup:

- `ghcr.io/casky-ai/skills-library:latest` — the 800+ skill library
- `ghcr.io/casky-ai/box/runner:latest` — the classifier + harness
- `ghcr.io/casky-ai/box/ui:latest` — the web viewer (optional)

## Setup

```bash
cd casky-workshops/casky-box
cp .env.example .env
# edit .env, set ANTHROPIC_API_KEY

docker compose pull
docker compose up -d
docker compose ps   # confirm casky-skills exited 0, casky-db and casky-runner are healthy
```

Each workshop's own SETUP.md tells you when to drop evidence into
[`evidence/`](evidence/) and which `docker exec casky-runner casky harness ...`
command to run from there.

## Cleanup

```bash
docker compose down          # stop + remove containers, keep volumes (skills library, findings, Postgres data)
docker compose down -v       # also wipe volumes — re-pulls the skills library next time
```

Each workshop's own `./cleanup.sh` only removes evidence files it copied into
[`evidence/`](evidence/) — it doesn't touch this box's containers, so you can
leave Casky Box running across multiple exercises/attendees in one session.
