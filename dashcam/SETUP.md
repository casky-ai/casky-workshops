# Dashcam — Workshop Setup

**Catch PII before it leaves the building.** This is the first exercise in a new, separate
series: instead of a reactive-breach/proactive-audit pair built around a broad narrative (like
FastLane/SpeedBump or Tailgate/GuestList), each workshop in this series is built around **one
specific skill** from the Anthropic Cybersecurity Skills library, exercised end-to-end.

**Skill:** [`anonymizing-pii-with-microsoft-presidio`](skills/anonymizing-pii-with-microsoft-presidio/SKILL.md)
— currently an open, unmerged PR against upstream
([mukul975/Anthropic-Cybersecurity-Skills#141](https://github.com/mukul975/Anthropic-Cybersecurity-Skills/pull/141)),
vendored locally in this folder under `skills/` until it lands. Two already-merged, complementary
skills round out the set: `testing-for-sensitive-data-exposure` and
`performing-privacy-impact-assessment`.

**Scenario:** RoadWitness (fictional dashcam rideshare app) is about to hand four artifacts —
a support-ticket export, a Slack thread, a bulk driver-records export, and a dashcam frame image —
to a third-party LLM vendor and a staging environment. None of it has been through a PII scrub
step. Find and de-identify what's in each, using the operator that matches where it's going:

| Artifact | Where it's headed | Right operator |
|---|---|---|
| `data/support-tickets.json` | third-party LLM vendor (triage) | one-way (`redact`/`mask`) — no need to reverse it |
| `data/vendor-handoff-chat.txt` | same vendor, mid-incident | one-way, plus a **custom recognizer** for `RW-DRV-######` (not a built-in Presidio entity) |
| `data/driver-records-export.json` | staging (QA needs to join it back) | reversible (`encrypt`/`decrypt`) |
| `data/dashcam-frame-0417.png` | cloud storage | `presidio-image-redactor` (OCR-based, not the text engines) |

~15–20 min, free to run yourself. No narrative deep-dive doc — the scenario above and
`CLAUDE.md` are the whole brief.

---

## Option A — Docker (recommended, same pattern as every other workshop in this repo)

A `Dockerfile` here bakes in Python, Presidio + the `en_core_web_sm` spaCy model, Claude Code,
and the skill set at `docker build` time — no live installs over `docker exec`, same approach
as FastLane/Tailgate/TollBooth's containers.

### Prerequisites

- Docker (no local build needed — `docker pull` fetches the pre-built image from GHCR).
- A `.env` file **in this folder** (`dashcam/.env`, copied from `casky-box/.env`,
  quotes stripped — same steps as the other workshops' Section 1).

### Steps

```bash
# Run every command below from THIS folder (casky-workshops/dashcam/).

# 0. Pull the pre-built image from GHCR (rebuilt nightly with the latest patches) instead
#    of building locally — much faster at a live session.
docker pull ghcr.io/casky-ai/casky-dashcam:latest
docker tag ghcr.io/casky-ai/casky-dashcam:latest casky-dashcam

# Fallback, kept for reference — Python, Presidio, spaCy's small model, Claude Code, and
# the 3 skills are still baked into the image at build time (see Dockerfile); rebuild
# locally if you're iterating on the Dockerfile/skill list itself, or if GHCR is
# unreachable:
#   docker build -t casky-dashcam .

docker run -d --name casky-dashcam \
  --env-file .env \
  -v "$(pwd)":/root/dashcam \
  casky-dashcam

docker exec casky-dashcam test -f /root/dashcam/verify.sh \
  && echo "[+] mount OK" || echo "[!] wrong directory"

# 1. Run ./verify.sh — expect 10/10 PASS.
docker exec -w /root/dashcam casky-dashcam ./verify.sh

# 2. Bash into the container and start Claude Code interactively.
docker exec -it -w /root/dashcam casky-dashcam bash
#   ...now inside the container's shell:
export PATH="$HOME/.local/bin:$PATH"
./start.sh
claude
```

## Option B — Local Python, no Docker

For a quick laptop-only run without building an image:

```bash
# Run every command below from THIS folder (casky-workshops/dashcam/).

# 1. Python environment + Presidio
python3 -m venv .venv && source .venv/bin/activate
pip install presidio-analyzer presidio-anonymizer presidio-image-redactor
python -m spacy download en_core_web_sm   # small model — plenty for this lab, ~500x smaller than en_core_web_lg

# sanity check
python -c "from presidio_analyzer import AnalyzerEngine; \
a = AnalyzerEngine(); \
print(a.analyze(text='Call John Smith at 212-555-0100', language='en'))"
```

If you use `en_core_web_sm` instead of the SKILL.md's default `en_core_web_lg`, point the
analyzer at it explicitly (small model doesn't self-select):

```python
from presidio_analyzer.nlp_engine import NlpEngineProvider

provider = NlpEngineProvider(nlp_configuration={
    "nlp_engine_name": "spacy",
    "models": [{"lang_code": "en", "model_name": "en_core_web_sm"}],
})
analyzer = AnalyzerEngine(nlp_engine=provider.create_engine())
```

```bash
# 2. Mount the skill library for the agent
chmod +x setup-skills.sh verify.sh reset.sh start.sh cleanup.sh
./setup-skills.sh

# 3. Run ./verify.sh — expect 10/10 PASS.
./verify.sh

# 4. Start Claude Code from this folder (needs Claude Code installed separately —
#    curl -fsSL https://claude.ai/install.sh | bash — Option A bakes it in instead).
./start.sh
claude
```

Then, inside Claude Code, hand it the scenario — e.g.:

> Everything in `data/` is about to go out to a vendor or staging. Use
> `anonymizing-pii-with-microsoft-presidio` to find and de-identify the PII in each file,
> matching the operator to where each one is headed (see the table in SETUP.md). Show me the
> audit trail — what you found and what you did about it — not just the redacted output.

**What a good run looks like:**
- Detects the SSN and credit-card number in `support-tickets.json` via `AnalyzerEngine` +
  `BatchAnalyzerEngine`, applies `redact`/`mask`, keeps `.items` as the audit trail.
- Notices `RW-DRV-048213` in `vendor-handoff-chat.txt` is **not** a Presidio built-in, writes a
  `PatternRecognizer` for it (`RW-DRV-\d{6}`), and still catches the IBAN and IP address with
  built-ins.
- Treats `driver-records-export.json` differently on purpose — `encrypt`/`decrypt` with a key,
  not a one-way hash, because staging QA needs to join the pseudonymized records back.
- Runs `presidio-image-redactor`'s `ImageRedactorEngine` against `dashcam-frame-0417.png` and
  produces a redacted copy — the driver name, plate, phone, and driver ID are burned into the
  image as text (OCR target), not stored as metadata.

---

## Cleanup

```bash
./cleanup.sh                # venv + cloned upstream skills repo
./cleanup.sh --keep-venv    # keep the venv around for the next attendee
```

`data/`, `skills/`, and the scenario scripts are untouched by cleanup — use `./reset.sh` between
attendees if `data/` got modified mid-exercise (Presidio output should go to new files, not
overwrite the originals, but reset is there if it happens).

---

*Built from [mukul975/Anthropic-Cybersecurity-Skills#141](https://github.com/mukul975/Anthropic-Cybersecurity-Skills/pull/141)
— "Add skill: anonymizing-pii-with-microsoft-presidio." Not yet merged upstream as of
2026-09-02; this workshop vendors the skill locally and should switch to the upstream clone
once the PR lands.*
