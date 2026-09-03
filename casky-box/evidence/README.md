# Evidence directory

Drop evidence files here on the host (CloudTrail JSON exports, pcap-derived
text from `tshark`/`tcpdump`, log excerpts, each workshop's own generated
`*-full.txt` bundles). This directory is bind-mounted read-only into the
`runner` container at `/var/casky/evidence` (see `../docker-compose.yml`), so
anything you save here is immediately visible inside the container at the
same relative path — no `docker cp` needed.

```bash
docker exec -it casky-runner casky harness -i /var/casky/evidence/fastlane-full.txt
```

**Use the in-container path, not a host path.** `-i` runs inside the `runner`
container, which has its own isolated filesystem — a host path like
`~/Downloads/...` will never resolve there. Copy the file into this directory
first, then pass `/var/casky/evidence/<filename>`.

**50,000-character limit.** Evidence text is embedded verbatim into every LLM
prompt in the classifier pipeline, so a large, unfiltered file (a full pcap, a
multi-MB log dump) would blow past any provider's context window — `-i`
rejects anything over the limit before even reading it. Pre-process large
files first (`jq` for JSON, `tshark`/`grep`/`awk` for pcap-derived text)
rather than passing a raw capture — every workshop's own SETUP.md already
does this for you.

Everything in this directory except this file is gitignored — evidence can
contain synthetic-but-realistic secrets and must never be committed.
