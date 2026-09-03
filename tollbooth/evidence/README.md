# Scratch evidence bundles

Section 2's own generated output lives here — `tollbooth-pcap.txt` (tshark's text rendering
of `../lab-tollbooth.pcap`), `tollbooth-full.txt` (that plus the CloudTrail evidence), and
`opendoor-full.txt` (the concatenated OpenDoor configs). See `../SETUP.md`'s Section 2 for the
exact commands that produce them and what happens to them next (copied into
`../../casky-box/evidence/` for `casky harness -i` to read).

Everything in here is derived from committed source data (`../lab-tollbooth.pcap`,
`../cloudtrail/`, `../opendoor/`) — regenerate anytime by re-running Section 2's Steps.
Gitignored and removed by `../cleanup.sh`; not workshop content in its own right.
