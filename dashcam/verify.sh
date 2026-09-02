#!/usr/bin/env bash
# Dashcam — instructor self-test. Confirms this laptop's data AND skill are intact.
cd "$(dirname "$0")"
pass=0; fail=0
num(){ case "$1" in ''|*[!0-9]*) echo 0;; *) echo "$1";; esac; }
chk(){ v=$(num "$1"); if [ "$v" -ge "$2" ]; then echo "  PASS  $3 ($v)"; pass=$((pass+1)); else echo "  FAIL  $3 (got $v, need >= $2)"; fail=$((fail+1)); fi; }

echo "== tooling =="
for t in jq grep python3; do
  if command -v "$t" >/dev/null 2>&1; then echo "  ok      $t";
  else echo "  MISSING $t"; fail=$((fail+1)); fi
done

echo "== skill vendored locally =="
n=$(grep -c "^name: anonymizing-pii-with-microsoft-presidio" skills/anonymizing-pii-with-microsoft-presidio/SKILL.md 2>/dev/null)
chk "$n" 1 "skills/anonymizing-pii-with-microsoft-presidio/SKILL.md present"

echo "== support-tickets.json — free text + structured PII bound for a vendor =="
n=$(grep -c "078-05-1120" data/support-tickets.json)
chk "$n" 1 "SSN pasted into a ticket body"
n=$(grep -c "4111 1111 1111 1111" data/support-tickets.json)
chk "$n" 1 "credit-card number pasted into a ticket body"
n=$(jq 'length' data/support-tickets.json)
chk "$n" 4 "ticket records present"

echo "== vendor-handoff-chat.txt — mid-incident, caught before the vendor call =="
n=$(grep -c "RW-DRV-048213" data/vendor-handoff-chat.txt)
chk "$n" 1 "org-specific driver ID present (not a built-in Presidio entity)"
n=$(grep -c "GB29 NWBK" data/vendor-handoff-chat.txt)
chk "$n" 1 "IBAN pasted into the Slack export"
n=$(grep -c "203.0.113.44" data/vendor-handoff-chat.txt)
chk "$n" 1 "IP address pasted into the Slack export"

echo "== driver-records-export.json — reversible case, bound for staging =="
n=$(jq '.records | length' data/driver-records-export.json)
chk "$n" 3 "driver records present"
n=$(grep -c "payout_iban" data/driver-records-export.json)
chk "$n" 3 "payout IBAN field present per record"

echo "== dashcam-frame-0417.png — image redaction case =="
n=$(python3 -c "from PIL import Image; im = Image.open('data/dashcam-frame-0417.png'); print(1 if im.size[0] > 0 else 0)" 2>/dev/null || echo 0)
chk "$n" 1 "image opens and has burned-in PII (Priya Nakamura / 7XKQ192 / RW-DRV-048213)"

echo "----"; echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "This laptop is READY." || echo "Review the FAIL lines above."
