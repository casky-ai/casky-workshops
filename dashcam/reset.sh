#!/usr/bin/env bash
# Dashcam — reset between attendees (<10s). Restores data, clears agent chat.
cd "$(dirname "$0")"
rm -rf data && cp -r .pristine/data ./ 2>/dev/null
# clear per-user agent conversation state (keep skills/config)
rm -rf "$HOME/.claude/projects/"*dashcam* 2>/dev/null
rm -f  "$HOME/.claude/history"* 2>/dev/null
echo "[+] Dashcam reset. Ready for the next attendee."
