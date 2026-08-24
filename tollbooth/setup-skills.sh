#!/usr/bin/env bash
echo "[*] installing prereqs (jq, tcpdump, tshark)"; sudo apt-get update -y >/dev/null 2>&1; sudo apt-get install -y jq tcpdump tshark >/dev/null 2>&1 || echo "   (install jq/tcpdump/tshark manually if this failed)"
# Instructor day-before: mount the skill library for the agent.
set -e
mkdir -p "$HOME/.claude/skills"
if [ ! -d Anthropic-Cybersecurity-Skills ]; then
  git clone --depth 1 https://github.com/mukul975/Anthropic-Cybersecurity-Skills.git
fi
for s in analyzing-network-traffic-with-wireshark performing-network-packet-capture-analysis \
         analyzing-network-packets-with-scapy detecting-aws-cloudtrail-anomalies \
         detecting-s3-data-exfiltration-attempts performing-cloud-forensics-with-aws-cloudtrail \
         exploiting-server-side-request-forgery auditing-aws-s3-bucket-permissions \
         performing-aws-privilege-escalation-assessment auditing-cloud-with-cis-benchmarks; do
  ln -sfn "$PWD/Anthropic-Cybersecurity-Skills/skills/$s" "$HOME/.claude/skills/$s"
done
echo "[+] linked $(ls "$HOME/.claude/skills" | wc -l) skills into ~/.claude/skills"
