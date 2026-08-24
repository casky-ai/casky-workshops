#!/usr/bin/env bash
# TollBooth — reset between attendees (<10s). Restores data, clears agent chat.
cd "$(dirname "$0")"
cp -f .pristine/lab-tollbooth.pcap ./ 2>/dev/null
rm -rf cloudtrail && cp -r .pristine/cloudtrail ./ 2>/dev/null
rm -rf opendoor  && cp -r .pristine/opendoor  ./ 2>/dev/null
# clear per-user agent conversation state (keep skills/config)
rm -rf "$HOME/.claude/projects/"*tollbooth* 2>/dev/null
rm -f  "$HOME/.claude/history"* 2>/dev/null
echo "[+] TollBooth reset. Ready for the next attendee."
