# FastLane / SpeedBump — canonical story facts

Internal build reference (not attendee-facing) — every evidence artifact must agree with this
file. Same role as `tailgate/NARRATIVE.md`.

**Company/app:** **Loopline** — a customer-support ticketing SaaS for small businesses
(`app.loopline.io`, fictional). Built in a single weekend by one founder using Lovable (frontend +
Supabase scaffolding) + Supabase (Postgres/auth/storage) + Vercel (hosting), then shipped straight
to its first 40 paying customers — the FastLane story: no security review, straight to production.
Grounded in the real, sourced Top 10 from `plans/042_fastlane_speedbump_workshop.md` — every
gotcha below maps to one of that plan's 10 entries and the real incidents behind them
(CVE-2025-48757, the Moltbook breach, Base44/Wiz, GitGuardian, the slopsquatting research).

**Incident window:** 2026-08-18, all timestamps UTC. **Domain:** `app.loopline.io`. **Public repo:**
`github.com/loopline-app/loopline` (fictional, mirrors the "vibe coders ship in public" pattern).

## The 10 gotchas, as they exist in Loopline (mirrors plan 042 §2's ranking)

1. **RLS misconfigured** (gotcha #1 — strongest real-world evidence, CVE-2025-48757/Moltbook
   pattern) — `customers` table has Row-Level Security **disabled entirely** (never turned on when
   Lovable scaffolded it); `tickets` table has RLS **enabled** but the SELECT policy is
   `USING (true)` — technically "on," functionally wide open. Both let any authenticated user (the
   `tickets` case) or literally anyone with the anon key (the `customers` case) read every
   customer's data across every org.
2. **Hardcoded secret in the client bundle** (gotcha #2) — the production Next.js bundle ships the
   Supabase **service-role key** (not just the anon key) because an env var was named
   `NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY` — the `NEXT_PUBLIC_` prefix ships anything to the
   browser bundle by Next.js design, and the founder didn't know that when the AI assistant
   suggested the name.
3. **Slopsquatting** (gotcha #3) — during a "add CSV export" prompt, the coding assistant suggested
   `react-csv-parser-pro`, a package that doesn't exist under that name from any real maintainer.
   It was proposed in a PR branch; **the PR was never merged to main** — the built-in nuance for
   this scenario (see below).
4. **IDOR / broken object-level authorization** (gotcha #4) — `GET /api/tickets/[id]` checks that a
   user is authenticated but never checks the ticket's `org_id` against the requester's own
   org — any logged-in user can view or edit any other org's ticket by changing the numeric ID.
5. **Insecure platform default** (gotcha #5) — root cause of #1: Lovable's generated Supabase
   migration didn't enable RLS on new tables by default at scaffold time (same root cause as
   CVE-2025-48757); the founder added a policy to `tickets` later by hand, but never went back to
   `customers`.
6. **Prompt injection / auto-trust in the coding tool** (gotcha #6, developer-side not app-side) —
   the founder started from a community "Lovable + Supabase starter" template cloned from GitHub
   that included an `.mcp.json` auto-connecting to an unfamiliar remote MCP server on project open
   (the TrustFall pattern) — caught in a later dev-environment review, not exploited.
7. **CORS wildcard** (gotcha #7) — `Access-Control-Allow-Origin: *` on the API routes, added by the
   assistant as a quick fix for a local cross-origin error during development, never scoped down
   before shipping.
8. **Leaked env vars via the public repo** (gotcha #8) — an early commit
   (`a4f1e2c`, "wip: supabase setup") committed a real `.env` instead of `.env.example`; a later
   commit removed it, but the values are still recoverable from git history.
9. **Exposed debug/admin route** (gotcha #9) — `/api/debug/seed`, left over from initial Lovable
   scaffolding to reset demo data, has no auth check and is still reachable in production.
10. **Elevated general OWASP-flavored defect rate** (gotcha #10, least vibe-coding-specific per
    plan 042) — a general code scan turned up a reflected-XSS path in ticket-comment rendering and
    no rate-limiting on login, consistent with (not uniquely caused by) the generally elevated
    defect rate in AI-generated code.

## The breach (FastLane, reactive)

A researcher (motive unspecified — could be white-hat, could not) finds Loopline's public GitHub
repo, recovers the leaked Supabase credentials from git history (#8), confirms the service-role
key is also sitting in the live client bundle (#2), and uses it to pull the entire `customers`
table directly — RLS being off (#1/#5) means the key alone is sufficient, no clever exploit
needed. Separately, access logs show someone enumerating `/api/tickets/{id}` sequentially (#4) —
CORS being wildcarded (#7) means this could be triggered from any origin. The `/api/debug/seed`
route (#9) shows one external hit but no evidence it was used to cause damage. The slopsquatting
package (#3) never shipped — caught before merge.

## The audit (SpeedBump, proactive) — correlation labels

Mirrors GuestList's non-uniform "exploited / probed / bypassed" convention:

| Finding | Correlates to | Label |
|---|---|---|
| RLS off on `customers` / `USING (true)` on `tickets` | the breach | **exploited** — full table pulled |
| Service-role key in client bundle | the breach | **exploited** — used to authenticate the pull |
| Leaked env vars in git history | the breach | **exploited** — how the key was actually recovered |
| IDOR on `/api/tickets/[id]` | access-log enumeration | **probed** — enumeration observed, no confirmed data exfil via this specific path (the customers-table pull covers the same data more directly) |
| CORS wildcard | — | **latent** — compounds IDOR risk but not independently evidenced as the access vector |
| Exposed `/api/debug/seed` | one external hit | **probed** — hit once, no confirmed damaging use |
| Slopsquatting package | — | **not exploited — caught pre-merge.** The built-in "catch the agent" check for this scenario: an agent (or attendee) that claims the malicious package "was installed and running in production" is over-claiming — the PR history shows it never reached `main`. |
| Starter-template MCP auto-trust | — | **latent**, developer-tooling risk, not app-facing |
| Exposed debug route + general OWASP defect rate (XSS, no rate-limit) | — | **latent**, not the confirmed breach path |
