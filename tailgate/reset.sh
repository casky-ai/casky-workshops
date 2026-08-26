#!/usr/bin/env bash
# Tailgate/GuestList — reset between attendees (<10s). Restores data, clears agent chat.
cd "$(dirname "$0")"
cp -f .pristine/phishing-email.eml ./ 2>/dev/null
cp -f .pristine/mail-gateway.log ./ 2>/dev/null
cp -f .pristine/endpoint-alert.log ./ 2>/dev/null
rm -rf network   && cp -r .pristine/network   ./ 2>/dev/null
rm -rf ad        && cp -r .pristine/ad        ./ 2>/dev/null
rm -rf guestlist && cp -r .pristine/guestlist ./ 2>/dev/null
# clear per-user agent conversation state (keep skills/config)
rm -rf "$HOME/.claude/projects/"*tailgate* 2>/dev/null
rm -f  "$HOME/.claude/history"* 2>/dev/null
echo "[+] Tailgate/GuestList reset. Ready for the next attendee."
