# Contributing

## Docker image naming

**Every Docker image this repo ships is branded `casky-<name>`** (`casky-fastlane`,
`casky-tailgate`, `casky-tollbooth`, `casky-dashcam`, `casky-loopline`, ...) — this is a standing
convention, not a per-workshop decision. If you add a new workshop or a new demo container, name
its image and its `docker build -t` tag `casky-<name>` from the start.

## Adding a Dockerfile to an existing or new workshop

Each workshop's `Dockerfile` bakes in, at build time, everything Section 1's setup used to
live-install over `docker exec`:

1. OS packages the scenario's `verify.sh`/agent commands need (`apt-get update -y && apt-get
   upgrade -y && apt-get install -y ...` — the `upgrade` matters, it's what makes the nightly
   rebuild actually pick up new patches instead of re-publishing the same bits).
2. Claude Code CLI (`curl -fsSL https://claude.ai/install.sh | bash`).
3. The skill set, via `COPY setup-skills.sh ./` + `RUN ./setup-skills.sh` — reuse that workshop's
   own script rather than duplicating its skill list in the Dockerfile, so the two paths
   (Docker-build-time and bare-metal/no-Docker) can't drift apart.
4. An `org.opencontainers.image.*` `LABEL` block (title/description/source/licenses) so the
   published GHCR package auto-links back to this repo.

The workshop's `data/`/scenario scripts are bind-mounted at `docker run` time, not baked into the
image — editing evidence or `verify.sh` doesn't require a rebuild; editing `setup-skills.sh`'s
skill list or the `Dockerfile` itself does.

## Publishing (GHCR + nightly hardening)

`.github/workflows/docker-images.yml` builds every `casky-*` image, runs a Trivy scan
(report-only — uploaded to this repo's Security tab, never blocks the pipeline; these are
Kali-rolling-based tool images that realistically always carry some unfixed CVEs in bundled
pentest tooling), and publishes to `ghcr.io/casky-ai/casky-<name>:latest`. It runs nightly
(06:00 UTC), on any push touching a Dockerfile/skill list, and on demand
(`workflow_dispatch`).

Confirmed by pulling every image with no `docker login` at all: on the `casky-ai` org, a package
published from a public repo comes up publicly pullable immediately, no manual visibility flip
needed. If a future org/repo doesn't behave this way, a maintainer with admin access would need to
open the new package's settings on GitHub (Package settings → Change visibility → Public) once,
after its first publish — but don't assume that step is required without checking first.

## Live sessions: pull, don't build

At a live session, **pull the pre-built image instead of running `docker build`** — building
takes 30 to 90+ seconds per image (longer on slow venue wifi), and every workshop's `SETUP.md`
leads with the pull for exactly that reason:

```bash
docker pull ghcr.io/casky-ai/casky-<name>:latest
docker tag ghcr.io/casky-ai/casky-<name>:latest casky-<name>
```

`docker build -t casky-<name> .` is still there as the fallback — use it when iterating on a
`Dockerfile` itself, or if GHCR is unreachable (offline/air-gapped venue).
