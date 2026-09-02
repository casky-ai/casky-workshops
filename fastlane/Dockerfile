# FastLane/SpeedBump — Kali image with tools + Claude Code + skills baked in at build time.
# Build once, reuse for every attendee's laptop instead of live-installing over `docker exec`:
#
#   docker build -t casky-fastlane .
#   docker run -d --name kali-fastlane --env-file .env -v "$(pwd)":/root/fastlane casky-fastlane
#
# See SETUP.md Section 1 for the full flow (this replaces that section's old apt-get/curl/
# setup-skills.sh docker-exec steps — the image already has them baked in).
FROM kalilinux/kali-rolling

LABEL org.opencontainers.image.title="casky-fastlane" \
      org.opencontainers.image.description="FastLane/SpeedBump workshop — Kali + Claude Code + 10 hand-picked skills, vibe-coding AppSec breach lab" \
      org.opencontainers.image.source="https://github.com/casky-ai/casky-workshops" \
      org.opencontainers.image.licenses="MIT"

# 1. OS packages this scenario's verify.sh/agent commands need. No tshark/tcpdump here on
#    purpose — FastLane/SpeedBump has no pcap, unlike Tailgate/TollBooth.
RUN apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && DEBIAN_FRONTEND=noninteractive apt-get install -y \
      jq git curl ca-certificates sudo bash \
    && rm -rf /var/lib/apt/lists/*

# 2. Claude Code CLI
RUN curl -fsSL https://claude.ai/install.sh -o /tmp/install.sh \
    && bash /tmp/install.sh \
    && rm -f /tmp/install.sh
ENV PATH="/root/.local/bin:${PATH}"

# 3. Skills — baked in via this workshop's own setup-skills.sh, the same script the
#    bare-metal/Section-1-without-Docker path uses, so the skill list can't drift between
#    the two. The workshop's data/scripts folder is bind-mounted at `docker run` time (see
#    above), not baked in, so ./reset.sh on the host still works between attendees.
WORKDIR /root/fastlane
COPY setup-skills.sh ./
RUN chmod +x setup-skills.sh && ./setup-skills.sh

CMD ["sleep", "infinity"]
