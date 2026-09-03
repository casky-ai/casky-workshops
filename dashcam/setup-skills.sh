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

# 2. two complementary, already-merged upstream skills — cloned under $HOME, not $PWD.
#    $PWD is this workshop's own folder, which gets bind-mounted over at `docker run`
#    time (-v "$(pwd)":/root/dashcam) — that would silently shadow whatever
#    setup-skills.sh cloned in here at `docker build` time and leave the symlinks below
#    dangling. $HOME isn't part of that mount, so it survives. (The vendored skill above
#    is fine as-is — ./skills/ is real, committed repo content, not an ephemeral clone.)
if [ ! -d "$HOME/Anthropic-Cybersecurity-Skills" ]; then
  git clone --depth 1 https://github.com/mukul975/Anthropic-Cybersecurity-Skills.git \
    "$HOME/Anthropic-Cybersecurity-Skills"
fi
for s in testing-for-sensitive-data-exposure performing-privacy-impact-assessment; do
  ln -sfn "$HOME/Anthropic-Cybersecurity-Skills/skills/$s" "$HOME/.claude/skills/$s"
done

echo "[+] linked $(ls "$HOME/.claude/skills" | wc -l) skills into ~/.claude/skills"
