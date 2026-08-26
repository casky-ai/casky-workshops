#!/usr/bin/env bash
# Tailgate/GuestList — instructor self-test. Confirms this laptop's data AND tooling are intact.
cd "$(dirname "$0")"
KEYHASH="a1e4c9d2f6b8034e7c1a29d5f3b6e8901c4d7f2a5b8e1c4f7a0d3b6e9c2f5a81"
pass=0; fail=0
num(){ case "$1" in ''|*[!0-9]*) echo 0;; *) echo "$1";; esac; }
chk(){ v=$(num "$1"); if [ "$v" -ge "$2" ]; then echo "  PASS  $3 ($v)"; pass=$((pass+1)); else echo "  FAIL  $3 (got $v, need >= $2)"; fail=$((fail+1)); fi; }

echo "== tooling =="
for t in tshark jq tcpdump; do
  if command -v "$t" >/dev/null 2>&1; then echo "  ok      $t";
  else echo "  MISSING $t   ->  sudo apt-get install -y $t"; fi
done
if ! command -v jq >/dev/null 2>&1; then
  echo "!! jq is required. Run: sudo apt-get update && sudo apt-get install -y jq tcpdump"
  echo "   then re-run ./verify.sh"; exit 1
fi

echo "== act 1 — initial access (T1566.001, T1078, T1133) =="
n=$(grep -rc "$KEYHASH" phishing-email.eml mail-gateway.log endpoint-alert.log 2>/dev/null | awk -F: '{s+=$2} END{print s}')
chk "$n" 3 "malicious attachment hash present across phishing-email.eml/mail-gateway.log/endpoint-alert.log"
n=$(grep -c "action=ALLOWED" mail-gateway.log 2>/dev/null)
chk "$n" 1 "mail gateway ALLOWED verdict (DMARC p=none let it through)"
n=$(grep -c "mitre=T1078" endpoint-alert.log 2>/dev/null)
chk "$n" 1 "Valid Accounts (T1078) sign-in event present"
n=$(grep -c "mitre=T1133" endpoint-alert.log 2>/dev/null)
chk "$n" 1 "External Remote Services (T1133) VPN session event present"

echo "== act 2 — lateral movement (T1570, T1021.002, T1021.001) =="
n=$(grep -c "NEW PEER" network/netflow.txt 2>/dev/null)
chk "$n" 2 "first-time-seen internal host-pair flows (lateral tool transfer signal)"
n=$(grep -c "T1021.002" network/smb-rdp-events.txt 2>/dev/null)
chk "$n" 1 "SMB/Admin Shares (T1021.002) logon event present"
n=$(grep -c "T1021.001" network/smb-rdp-events.txt 2>/dev/null)
chk "$n" 1 "RDP (T1021.001) logon event present"

echo "== act 3 — domain compromise (T1558.003, T1558.004) =="
n=$(grep -c "0x17 (RC4-HMAC)" ad/kerberos-events.txt 2>/dev/null)
chk "$n" 5 "Kerberoasting TGS burst with RC4 downgrade (T1558.003)"
n=$(grep -c "NOT FOUND" ad/kerberos-events.txt 2>/dev/null)
chk "$n" 1 "AS-REP Roasting (T1558.004) confirmed NOT exploited — the built-in over-claim check"
n=$(grep -c "900+ days old" ad/spn-listing.txt 2>/dev/null)
chk "$n" 3 "SPN-registered service accounts with stale passwords"
n=$(grep -c "TRUE" ad/spn-listing.txt 2>/dev/null)
chk "$n" 1 "service account with Kerberos preauth disabled (svc-legacyapp)"

echo "== guestlist (proactive audit) =="
n=$(grep -c "p=none" guestlist/email-security-policy.json 2>/dev/null)
chk "$n" 1 "DMARC p=none finding present"
n=$(grep -c '"id": "NET-' guestlist/network-segmentation.json 2>/dev/null)
chk "$n" 3 "network segmentation findings present"
n=$(grep -c "probed, not confirmed exploited" guestlist/ad-service-accounts.json 2>/dev/null)
chk "$n" 1 "AD-2 correctly labeled probed-not-exploited (matches ad/kerberos-events.txt's NOT FOUND)"

echo "----"; echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "This laptop is READY." || echo "Review the FAIL lines above. If jq was just installed, re-run ./verify.sh (no reset needed)."
