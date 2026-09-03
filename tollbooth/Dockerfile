# TollBooth/OpenDoor — Kali image with tools + Claude Code + skills baked in at build time.
# Build once, reuse for every attendee's laptop instead of live-installing over `docker exec`:
#
#   docker build -t casky-tollbooth .
#   docker run -d --name casky-tollbooth --env-file .env -v "$(pwd)":/root/tollbooth casky-tollbooth
#
# See SETUP.md Section 1 for the full flow (this replaces that section's old apt-get/curl/
# setup-skills.sh docker-exec steps — the image already has them baked in).
FROM kalilinux/kali-rolling

LABEL org.opencontainers.image.title="casky-tollbooth" \
      org.opencontainers.image.description="TollBooth/OpenDoor workshop — Kali + Claude Code + 10 hand-picked skills, SSRF to IMDS credential leak to S3 exfil lab" \
      org.opencontainers.image.source="https://github.com/casky-ai/casky-workshops" \
      org.opencontainers.image.licenses="MIT"

# 1. OS packages this scenario's verify.sh/agent commands need — tshark/tcpdump for the pcap,
#    python3-scapy for packet-level work the agent may want to do beyond tshark filters.
RUN apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && DEBIAN_FRONTEND=noninteractive apt-get install -y \
      tshark tcpdump python3-scapy \
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
WORKDIR /root/tollbooth
COPY setup-skills.sh ./
RUN chmod +x setup-skills.sh && ./setup-skills.sh

CMD ["sleep", "infinity"]
