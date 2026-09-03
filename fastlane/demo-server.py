#!/usr/bin/env python3
"""
Loopline demo server: a local stand-in for `app.loopline.io` so the two
five-minute-check curl commands from the Lightning Lesson deck actually run
against something real, instead of narrating over captured evidence.

No external dependencies, no outbound network calls, nothing leaves this
machine. Data below is synthetic (matches casky-workshops/fastlane/NARRATIVE.md
and app/rls-policies.json: Loopline is a fictional customer-support SaaS built
for this workshop).

Usage (bare):
    python3 demo-server.py [port]      # default port 8787

Usage (Docker): see fastlane/Dockerfile.demo

Then, in another terminal:
    curl -s "http://localhost:8787/"                      # homepage
    curl -s "http://localhost:8787/rest/v1/customers?select=*" \
      -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIn0.SYNTHETIC_ANON_9f2a"
    curl -s http://localhost:8787/_next/static/chunks/app-a91f3c2e.js \
      | grep -oiE '(service_role|sk-live-|AKIA)[A-Za-z0-9_.":-]{5,}'
"""
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse

PORT = int(os.environ.get("PORT", sys.argv[1] if len(sys.argv) > 1 else 8787))

# Synthetic rows, same shape a real `customers` table with RLS off would hand
# back to anyone holding the public anon key. Fabricated data, matches the
# "40 paying customers" figure in NARRATIVE.md.
CUSTOMERS = [
    {"id": 1, "org_name": "Acme Plumbing Co", "email": "billing@acme-plumbing.example", "plan": "pro", "support_pin": "4471"},
    {"id": 2, "org_name": "Riverside Dental", "email": "ops@riverside-dental.example", "plan": "starter", "support_pin": "9902"},
    {"id": 3, "org_name": "Northwind Movers", "email": "admin@northwind-movers.example", "plan": "pro", "support_pin": "1188"},
    {"id": 4, "org_name": "Bluepeak Landscaping", "email": "hello@bluepeak-landscaping.example", "plan": "starter", "support_pin": "6620"},
    {"id": 5, "org_name": "Cedar & Co Bakery", "email": "orders@cedarco-bakery.example", "plan": "pro", "support_pin": "3345"},
]

# The exact leaked-bundle content from app/client-bundle-excerpt.txt, served
# as if it were the production Next.js chunk. This is the real finding text
# already captured for the workshop, not re-derived here.
BUNDLE_JS = (
    "var __NEXT_PUBLIC_ENV__ = {\n"
    '  NEXT_PUBLIC_SUPABASE_URL:"https://xzqlnrjk.supabase.co",\n'
    '  NEXT_PUBLIC_SUPABASE_ANON_KEY:"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIn0.SYNTHETIC_ANON_9f2a",\n'
    '  NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY:"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UifQ.SYNTHETIC_SERVICE_ROLE_c71d"\n'
    "};\n"
)

# Loopline's own landing page: a "fast cars" SaaS, the FastLane workshop's
# racing metaphor applied to the product itself. Dark CyberForge palette
# (marketing/Casky_Brand.md), teal accent, checkered-flag motif. Clearly
# labeled as a synthetic demo, not a real product.
HOME_HTML = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<title>Loopline - Support tickets, pit-lane fast</title>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<link rel="preconnect" href="https://fonts.googleapis.com"/>
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin/>
<link href="https://fonts.googleapis.com/css2?family=Sora:wght@700;800;900&family=Inter:wght@400;500;600&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet"/>
<style>
  :root {
    --brand: #00C0A3; --brand-dark: #009E88; --bg: #030308;
    --surface1: #0D0D18; --surface2: #13131F; --border: rgba(255,255,255,0.08);
    --text: #EAF2FF; --muted: rgba(255,255,255,0.5); --dimmed: rgba(255,255,255,0.28);
    --critical: #FF3D57; --high: #FF8C00;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; background: var(--bg); color: var(--text);
    font-family: "Inter", system-ui, sans-serif;
    background-image: repeating-linear-gradient(-45deg, var(--surface1) 0 28px, var(--bg) 28px 56px);
    background-size: 100% 6px, auto;
  }
  .flagbar {
    height: 8px;
    background: repeating-linear-gradient(90deg, #EAF2FF 0 18px, #030308 18px 36px);
  }
  header {
    display: flex; align-items: center; justify-content: space-between;
    padding: 22px 6vw; border-bottom: 1px solid var(--border); background: var(--bg);
  }
  .brand { display: flex; align-items: center; gap: 10px; font-family: "Sora", sans-serif; font-weight: 800; font-size: 20px; }
  .brand .flag { font-size: 22px; }
  nav a { color: var(--muted); text-decoration: none; font-size: 14px; margin-left: 28px; }
  .hero { padding: 8vh 6vw 6vh; max-width: 900px; }
  .eyebrow {
    font-family: "JetBrains Mono", monospace; font-size: 12px; letter-spacing: 0.18em;
    text-transform: uppercase; color: var(--brand); margin-bottom: 18px;
  }
  h1 {
    font-family: "Sora", sans-serif; font-weight: 900; font-size: clamp(34px, 5vw, 56px);
    line-height: 1.06; letter-spacing: -0.02em; margin: 0 0 20px;
  }
  h1 .accent { color: var(--brand); }
  p.sub { font-size: 18px; color: var(--muted); line-height: 1.6; max-width: 600px; margin: 0 0 34px; }
  .cta-row { display: flex; gap: 14px; margin-bottom: 54px; }
  .cta {
    font-family: "Sora", sans-serif; font-weight: 700; font-size: 15px; padding: 14px 24px;
    border-radius: 10px; text-decoration: none;
  }
  .cta.primary { background: linear-gradient(90deg, #00C0A3, #009E88); color: #030308; }
  .cta.ghost { border: 1px solid var(--border); color: var(--text); }
  .stats { display: flex; gap: 40px; flex-wrap: wrap; }
  .stat b { display: block; font-family: "Sora", sans-serif; font-weight: 800; font-size: 26px; color: var(--brand); }
  .stat span { font-size: 12px; color: var(--dimmed); font-family: "JetBrains Mono", monospace; }
  .warn {
    margin: 0 6vw 6vh; padding: 20px 24px; border-radius: 12px;
    background: rgba(255,61,87,0.08); border: 1px solid rgba(255,61,87,0.28);
    font-family: "JetBrains Mono", monospace; font-size: 13px; color: #FCA5A5; line-height: 1.7;
    max-width: 760px;
  }
  .warn b { color: #FF3D57; }
  footer { padding: 24px 6vw; border-top: 1px solid var(--border); font-size: 12px; color: var(--dimmed); font-family: "JetBrains Mono", monospace; }
</style>
</head>
<body>
<div class="flagbar"></div>
<header>
  <div class="brand"><span class="flag">🏁</span> Loopline</div>
  <nav><a href="#">Product</a><a href="#">Pricing</a><a href="#">Login</a></nav>
</header>
<main class="hero">
  <div class="eyebrow">Support tickets. Pit-lane fast.</div>
  <h1>Ship customer support<br/>at <span class="accent">race-day speed.</span></h1>
  <p class="sub">Loopline is ticketing built for small teams who move fast. Vibe-coded in a
    weekend, shipped straight to our first 40 customers. No review lap. Just green light,
    go.</p>
  <div class="cta-row">
    <a class="cta primary" href="#">Start free trial</a>
    <a class="cta ghost" href="#">See a demo</a>
  </div>
  <div class="stats">
    <div class="stat"><b>40</b><span>PAYING CUSTOMERS</span></div>
    <div class="stat"><b>1</b><span>WEEKEND TO BUILD</span></div>
    <div class="stat"><b>0</b><span>SECURITY REVIEWS</span></div>
  </div>
</main>
<div class="warn">
  <b>⚠ This is a synthetic demo app,</b> built for Casky's FastLane / SpeedBump workshop
  (casky-ai.github.io/casky-workshops/fastlane.html). Nothing here is a real company, a real
  customer, or a real secret. The vulnerabilities it ships are real patterns, sourced from
  CVE-2025-48757, the Moltbook breach, and Base44's Wiz-disclosed bypass: see
  casky.ai/blog/vibe-coding-security-top-10-gotchas.
</div>
<footer>LOOPLINE &middot; A CASKY FASTLANE DEMO &middot; NOT A REAL PRODUCT</footer>
</body>
</html>
"""


class LooplineHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        sys.stderr.write("[casky-loopline] %s - %s\n" % (self.address_string(), fmt % args))

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/":
            body = HOME_HTML.encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif path == "/rest/v1/customers":
            # Real RLS would check the caller's identity against org_id before
            # returning anything. Loopline's `customers` table has RLS
            # disabled entirely, so any apikey (even just the public anon
            # key) gets every row, no login required. That's the finding.
            body = json.dumps(CUSTOMERS, indent=2).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif path.startswith("/_next/static/chunks/"):
            body = BUNDLE_JS.encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/javascript")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_response(404)
            self.end_headers()


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", PORT), LooplineHandler)
    print(f"[casky-loopline] serving synthetic Loopline on http://localhost:{PORT}  (Ctrl+C to stop)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[casky-loopline] stopped")
