#!/usr/bin/env bash
# Dashcam — mount the skill library for the agent.
# The headline skill (anonymizing-pii-with-microsoft-presidio) is vendored locally in
# ./skills/ because it's from an open, unmerged PR against upstream
# (mukul975/Anthropic-Cybersecurity-Skills#141) — swap this to the upstream clone once it lands.
set -e
mkdir -p "$HOME/.claude/skills"

# 1. the headline skill — local copy, not yet upstream
ln -sfn "$PWD/skills/anonymizing-pii-with-microsoft-presidio" \
  "$HOME/.claude/skills/anonymizing-pii-with-microsoft-presidio"

# 2. two complementary, already-merged upstream skills
if [ ! -d Anthropic-Cybersecurity-Skills ]; then
  git clone --depth 1 https://github.com/mukul975/Anthropic-Cybersecurity-Skills.git
fi
for s in testing-for-sensitive-data-exposure performing-privacy-impact-assessment; do
  ln -sfn "$PWD/Anthropic-Cybersecurity-Skills/skills/$s" "$HOME/.claude/skills/$s"
done

echo "[+] linked $(ls "$HOME/.claude/skills" | wc -l) skills into ~/.claude/skills"
