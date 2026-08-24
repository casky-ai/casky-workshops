#!/usr/bin/env bash
# TollBooth — instructor self-test. Confirms this laptop's data AND tooling are intact.
cd "$(dirname "$0")"
KEY="ASIAJ7A6EXAMPLEK3Y99"; IMDS="169.254.169.254"; ATTK="203.0.113.66"
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

echo "== pcap =="
n=$(tshark -r lab-tollbooth.pcap -Y "ip.addr==$IMDS && http" 2>/dev/null | wc -l)
chk "$n" 1 "IMDS HTTP traffic present"
n=$(tshark -r lab-tollbooth.pcap -Y "http.request.uri contains \"$IMDS\"" 2>/dev/null | wc -l)
chk "$n" 1 "SSRF request references metadata service"
# version-proof: raw byte match, no http.file_data dependency (that field is inconsistent across tshark builds)
n=$(tshark -r lab-tollbooth.pcap -Y "frame contains \"$KEY\"" 2>/dev/null | wc -l)
chk "$n" 1 "leaked AccessKeyId recoverable from pcap"

echo "== cloudtrail =="
n=$(jq -s "[.[].Records[]|select(.userIdentity.accessKeyId==\"$KEY\" and .sourceIPAddress==\"$ATTK\")]|length" cloudtrail/*.json 2>/dev/null)
chk "$n" 10 "attacker actions on leaked key"
n=$(jq -s "[.[].Records[]|select(.userIdentity.accessKeyId==\"$KEY\" and .eventName==\"GetObject\")]|length" cloudtrail/*.json 2>/dev/null)
chk "$n" 6 "S3 GetObject exfil events"
n=$(jq -s "[.[].Records[]|select(.eventName==\"GetAccountAuthorizationDetails\" or .eventName==\"ListUsers\")]|length" cloudtrail/*.json 2>/dev/null)
chk "$n" 1 "IAM enumeration present"

echo "== scenario 2 (opendoor) =="
n=$(jq '[.Statement[]|select(.Principal=="*")]|length' opendoor/s3-bucket-policy.json 2>/dev/null)
chk "$n" 1 "S3 bucket policy is public (Principal *)"
n=$(jq '[.PolicyDocument.Statement[]|select(.Resource=="*" and (.Action[]|test("iam:")))]|length' opendoor/iam-policy-webapp-role.json 2>/dev/null)
chk "$n" 1 "IAM privilege-escalation path present"
t=$(jq -r '.Reservations[].Instances[].MetadataOptions.HttpTokens' opendoor/ec2-metadata-options.json 2>/dev/null)
if [ "$t" = "optional" ]; then echo "  PASS  IMDSv1 allowed (HttpTokens=optional)"; pass=$((pass+1));
else echo "  FAIL  IMDS check (got '${t:-empty}')"; fail=$((fail+1)); fi

echo "----"; echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "This laptop is READY." || echo "Review the FAIL lines above. If jq was just installed, re-run ./verify.sh (no reset needed)."
