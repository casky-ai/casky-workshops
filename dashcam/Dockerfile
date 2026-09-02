# Dashcam — Kali image with Python + Presidio + Claude Code + skills baked in at build time.
# Build once, reuse for every attendee's laptop instead of live-installing over `docker exec`:
#
#   docker build -t casky-dashcam .
#   docker run -d --name kali-dashcam --env-file .env -v "$(pwd)":/root/dashcam casky-dashcam
#
# See SETUP.md for the full flow (this replaces its old venv/pip/curl/setup-skills.sh steps —
# the image already has them baked in; no venv needed since the whole container is dedicated
# to this one exercise).
FROM kalilinux/kali-rolling

LABEL org.opencontainers.image.title="casky-dashcam" \
      org.opencontainers.image.description="Dashcam workshop — Kali + Claude Code + Presidio, catch PII before it leaves the building (anonymizing-pii-with-microsoft-presidio)" \
      org.opencontainers.image.source="https://github.com/casky-ai/casky-workshops" \
      org.opencontainers.image.licenses="MIT"

# 1. OS packages — Python for Presidio, jq/git/curl for the same reasons every other
#    workshop in this repo needs them.
RUN apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && DEBIAN_FRONTEND=noninteractive apt-get install -y \
      python3 python3-pip \
      jq git curl ca-certificates sudo bash \
    && rm -rf /var/lib/apt/lists/*

# 2. Presidio + a small spaCy model (en_core_web_sm — ~500x smaller than the SKILL.md's
#    default en_core_web_lg, plenty for this lab's synthetic data). PIP_BREAK_SYSTEM_PACKAGES
#    covers both this pip install AND the nested pip call `spacy download` makes internally
#    (a bare --break-system-packages flag only covers the former) — safe here since the
#    whole container is dedicated to this one exercise, no other Python workload to conflict
#    with.
ENV PIP_BREAK_SYSTEM_PACKAGES=1
RUN pip install --no-cache-dir \
      presidio-analyzer presidio-anonymizer presidio-image-redactor \
    && python3 -m spacy download en_core_web_sm

# presidio-analyzer's OWN default config still names en_core_web_lg — a bare `AnalyzerEngine()`
# (exactly what the SKILL.md's Step 1 shows, and what an attendee will type first) would
# otherwise silently trigger a ~400MB spaCy model download on first use, live, at the booth.
# Repoint that packaged default at the small model we actually baked in above.
RUN python3 -c "import presidio_analyzer, os; print(os.path.join(os.path.dirname(presidio_analyzer.__file__), 'conf', 'default.yaml'))" \
      | xargs -I{} sed -i 's/en_core_web_lg/en_core_web_sm/' {}

# 3. Claude Code CLI
RUN curl -fsSL https://claude.ai/install.sh -o /tmp/install.sh \
    && bash /tmp/install.sh \
    && rm -f /tmp/install.sh
ENV PATH="/root/.local/bin:${PATH}"

# 4. Skills — the headline skill is vendored locally (COPY'd in below) since it's from an
#    open, unmerged PR against upstream (mukul975/Anthropic-Cybersecurity-Skills#141); the
#    two complementary skills come from the real upstream clone. Baked in via this
#    workshop's own setup-skills.sh, the same script the bare-metal path uses, so the skill
#    list can't drift between the two. The workshop's data/scripts folder is bind-mounted at
#    `docker run` time (see above), not baked in, so ./reset.sh on the host still works
#    between attendees.
WORKDIR /root/dashcam
COPY skills/ ./skills/
COPY setup-skills.sh ./
RUN chmod +x setup-skills.sh && ./setup-skills.sh

CMD ["sleep", "infinity"]
