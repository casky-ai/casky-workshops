# Tailgate / GuestList — canonical story facts

Internal build reference (not attendee-facing) — every evidence artifact must agree with this
file. Keep it in sync as the narrative evolves; this is what SETUP.md's framing prose gets
written from in Week 2.

**Company:** Bellwood Logistics — `bellwoodlogistics.com`, AD domain `bellwood.local`
(NetBIOS `BELLWOOD`). Fictional, synthetic data only — same convention as TollBooth's "Acme
Rentals."

**Incident window:** 2026-08-10, all timestamps UTC.

**IP ranges (deliberately non-routable/documentation ranges, same convention TollBooth used):**
- Internal user subnet: `10.20.14.0/24`
- Internal server subnet: `10.20.1.0/24`
- Attacker-controlled / external: `203.0.113.0/24` (TEST-NET-3)

## Act 1 — Initial Access (T1566.001, T1078, T1133)

- **Victim:** Sandra Kim, Accounts Payable Coordinator, `sandra.kim@bellwoodlogistics.com`,
  host `SANDRA-KIM-PC` (`10.20.14.88`).
- **Lure:** email from `AP-Automation@bellwood-support.com` — a lookalike domain (hyphen added,
  registered days before the incident), subject "Invoice #BW-88291 Payment Confirmation
  Required," attachment `Invoice_BW88291.xlsm` (macro-enabled).
  - Attachment SHA-256 (synthetic, reused across `.eml`/gateway log/endpoint alert as the
    embedded "tell"): `a1e4c9d2f6b8034e7c1a29d5f3b6e8901c4d7f2a5b8e1c4f7a0d3b6e9c2f5a81`
- **Why it landed:** `bellwoodlogistics.com`'s DMARC policy is `p=none` (monitor-only) and SPF
  is `~all` (soft-fail, not hard-fail) — the mail gateway logs the lookalike domain's failed
  alignment but still delivers. This is the GuestList "email/gateway hygiene" finding, and it's
  labeled **exploited** (directly caused Act 1 to succeed).
- **Execution:** Sandra opens the attachment at 09:14 UTC; `EXCEL.EXE` spawns `POWERSHELL.EXE`
  with a base64-encoded command (T1204.002-flavored execution, folded into the T1566.001 finding).
- **Valid Accounts (T1078):** ~40 min later, Sandra's O365/VPN account authenticates from
  `203.0.113.77` (tagged Amsterdam-area hosting ASN in the log, nowhere near her normal Chicago
  office egress) — no MFA challenge recorded.
- **External Remote Services (T1133):** that same session is then used against Bellwood's
  external VPN gateway (`vpn.bellwoodlogistics.com`), which allows the authenticated session
  through and assigns an internal address — this is the pivot point into Act 2. VPN gateway
  allowing this without a stronger check is *not* one of the three named GuestList findings
  (kept to 3 per the plan) — it's supporting evidence inside Act 1's own artifacts, not a
  separate audited precondition.
- **VPN-assigned internal IP for the attacker's tunneled session:** `10.20.14.230`
  (hostname tag `REMOTE-SANDRA` in internal logs).

## Act 2 — Lateral Movement (T1570, T1021.002, T1021.001)

- From `10.20.14.230`, the session reaches two internal hosts it has no normal reason to talk to:
  - `FILESVR01` (`10.20.1.15`) — SMB/ADMIN$ session (event 4624 type 3), consistent with
    T1021.002.
  - `JMP-ADMIN01` (`10.20.1.50`) — interactive RDP logon (event 4624 type 10), consistent with
    T1021.001, and off-hours (02:1x UTC, well outside Bellwood's 13:00–01:00 UTC business hours).
- **Lateral Tool Transfer (T1570):** a netflow baseline shows a high-volume, off-hours flow
  `10.20.14.230 → 10.20.1.50` immediately before the RDP logon — consistent with staging a tool
  ahead of the AD reconnaissance in Act 3.
- **Why it spread:** Bellwood's internal network is flat — no ACL/VLAN boundary between the user
  subnet (`10.20.14.0/24`) and the server subnet (`10.20.1.0/24`), SMB is unrestricted between
  them, and there's no lateral-movement detection/alerting configured. GuestList "network
  segmentation" finding, labeled **exploited** (directly enabled Act 2).

## Act 3 — Domain Compromise (T1558.003, T1558.004)

- From `JMP-ADMIN01` (now attacker-controlled), a burst of 14 TGS requests (event 4769, RC4
  `etype 0x17` — a downgrade from AES) hits SPNs on three service accounts within a 90-second
  window at 02:22 UTC: `svc-sql01`, `svc-web01`, `svc-backup`. This is the Kerberoasting finding
  (T1558.003) — **exploited**.
- A fourth service account, `svc-legacyapp`, has `Do not require Kerberos preauthentication` set
  (AS-REP roastable) and is *equally exposed* — but no matching 4768-without-preauth event for it
  appears in the log window. **Deliberately left unexploited/only probed** (mirrors OpenDoor's
  "not every precondition was actually used" pattern) — attendees should notice the attacker had
  a second, easier path available and didn't take it, and an agent that claims "AS-REP Roasting
  was carried out" without a matching event is over-claiming. This is the built-in "catch the
  agent" check for this scenario, same pedagogical device TollBooth used.
- **Why the accounts were exposed:** `svc-sql01`, `svc-web01`, `svc-backup`, and `svc-legacyapp`
  all have SPNs registered and passwords last rotated 900+ days ago; `svc-legacyapp` additionally
  has preauth disabled. GuestList "AD hygiene" finding — **exploited** for the SPN/password-age
  part (that's what was actually used), **probed/exposed but not used** for the preauth-disabled
  part specifically.

## Report stage

`mapping-mitre-attack-techniques` + `conducting-post-incident-lessons-learned` tie the three acts
together: T1566.001 → T1078 → T1133 → T1570 → T1021.002/T1021.001 → T1558.003 (confirmed) /
T1558.004 (exposed, not confirmed exploited) — one continuous kill chain, phishing to domain
compromise.
