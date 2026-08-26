#!/usr/bin/env bash
# FastLane/SpeedBump — reset between attendees (<10s). Restores data, clears agent chat.
cd "$(dirname "$0")"
rm -rf app       && cp -r .pristine/app       ./ 2>/dev/null
rm -rf speedbump && cp -r .pristine/speedbump ./ 2>/dev/null
# clear per-user agent conversation state (keep skills/config)
rm -rf "$HOME/.claude/projects/"*fastlane* 2>/dev/null
rm -f  "$HOME/.claude/history"* 2>/dev/null
echo "[+] FastLane/SpeedBump reset. Ready for the next attendee."
