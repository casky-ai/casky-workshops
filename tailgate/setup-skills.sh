#!/usr/bin/env bash
echo "[*] installing prereqs (jq, tcpdump, tshark)"; sudo apt-get update -y >/dev/null 2>&1; sudo apt-get install -y jq tcpdump tshark >/dev/null 2>&1 || echo "   (install jq/tcpdump/tshark manually if this failed)"
# Instructor day-before: mount the skill library for the agent.
set -e
mkdir -p "$HOME/.claude/skills"
if [ ! -d Anthropic-Cybersecurity-Skills ]; then
  git clone --depth 1 https://github.com/mukul975/Anthropic-Cybersecurity-Skills.git
fi
for s in analyzing-email-headers-for-phishing-investigation conducting-phishing-incident-response \
         detecting-business-email-compromise hunting-for-spearphishing-indicators \
         detecting-lateral-movement-in-network detecting-pass-the-hash-attacks \
         detecting-kerberoasting-attacks mapping-attack-paths-with-bloodhound-ce \
         mapping-mitre-attack-techniques conducting-post-incident-lessons-learned; do
  ln -sfn "$PWD/Anthropic-Cybersecurity-Skills/skills/$s" "$HOME/.claude/skills/$s"
done
echo "[+] linked $(ls "$HOME/.claude/skills" | wc -l) skills into ~/.claude/skills"
