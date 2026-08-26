#!/usr/bin/env bash
echo "[*] installing prereqs (jq)"; sudo apt-get update -y >/dev/null 2>&1; sudo apt-get install -y jq >/dev/null 2>&1 || echo "   (install jq manually if this failed)"
# Instructor day-before: mount the skill library for the agent.
set -e
mkdir -p "$HOME/.claude/skills"
if [ ! -d Anthropic-Cybersecurity-Skills ]; then
  git clone --depth 1 https://github.com/mukul975/Anthropic-Cybersecurity-Skills.git
fi
for s in exploiting-idor-vulnerabilities testing-api-for-broken-object-level-authorization \
         testing-cors-misconfiguration detecting-typosquatting-packages \
         detecting-aws-credential-exposure-with-trufflehog implementing-secret-scanning-with-gitleaks \
         testing-for-sensitive-data-exposure auditing-aws-s3-bucket-permissions \
         auditing-mcp-servers-for-tool-poisoning testing-api-security-with-owasp-top-10; do
  ln -sfn "$PWD/Anthropic-Cybersecurity-Skills/skills/$s" "$HOME/.claude/skills/$s"
done
echo "[+] linked $(ls "$HOME/.claude/skills" | wc -l) skills into ~/.claude/skills"
