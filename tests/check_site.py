#!/usr/bin/env python3
"""Checks for the host root of vadneyk.github.io. Fails on anything that must never ship.

This site is the only place crawlers read robots.txt for every vadneyk.github.io project
site, so a mistake here reaches all of them:
  - robots.txt allows everything, for every crawler, and blocks no one;
  - every Sitemap line and every sitemap in the index answers 200 (live mode only);
  - no em or en dash, no tracking or analytics host, no AI byline;
  - the home page redirects to the portfolio and every page has a title.

Usage: check_site.py               (files in public/)
       check_site.py --live        (also fetch every sitemap named)
       check_site.py --live-root   (also fetch the live root files, after a deploy)
"""
import pathlib
import re
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
PUB = ROOT / "public"
BASE = "https://vadneyk.github.io/"
errors = []

BANNED = [
    (chr(0x2014), "em dash"), (chr(0x2013), "en dash"),
    (re.compile(r"googletagmanager|google-analytics|plausible|clarity\.ms|hotjar|segment\.com|posthog|umami", re.I), "tracking host"),
    (re.compile(r"Co-Authored-By|Generated with|written by (Claude|AI)", re.I), "AI byline"),
]

for f in sorted(PUB.rglob("*")) + [ROOT / "README.md"]:
    if not f.is_file() or f.suffix not in {".html", ".txt", ".xml", ".md"}:
        continue
    text = f.read_text(encoding="utf-8")
    for pat, label in BANNED:
        if (pat.search(text) if hasattr(pat, "search") else pat in text):
            errors.append("%s: %s" % (f.relative_to(ROOT), label))
    # A Search Console verification file is one plain line, not a page.
    if f.suffix == ".html" and not re.match(r"google[0-9a-f]+\.html$", f.name) and not re.search(r"<title>[^<]+</title>", text):
        errors.append("%s: no title" % f.relative_to(ROOT))

robots = (PUB / "robots.txt").read_text(encoding="utf-8")
lines = [l.strip() for l in robots.splitlines() if l.strip() and not l.strip().startswith("#")]
agents = [l for l in lines if l.lower().startswith("user-agent:")]
if agents != ["User-agent: *"]:
    errors.append("robots.txt: must have exactly one group, User-agent: * (found %s)" % agents)
if any(l.lower().startswith("disallow:") and l.split(":", 1)[1].strip() for l in lines):
    errors.append("robots.txt: has a Disallow rule; a block here hits every site under vadneyk.github.io")
if "Allow: /" not in lines:
    errors.append("robots.txt: no 'Allow: /'")
sitemaps = [l.split(":", 1)[1].strip() for l in lines if l.lower().startswith("sitemap:")]
if not sitemaps:
    errors.append("robots.txt: no Sitemap lines")
for s in sitemaps:
    if not s.startswith(BASE) or not s.endswith("/sitemap.xml"):
        errors.append("robots.txt: odd Sitemap line %s" % s)

index_locs = re.findall(r"<loc>([^<]+)</loc>", (PUB / "sitemap.xml").read_text(encoding="utf-8"))
if sorted(index_locs) != sorted(sitemaps):
    errors.append("sitemap.xml and robots.txt name different sitemaps")

home = (PUB / "index.html").read_text(encoding="utf-8")
if 'http-equiv="refresh" content="0; url=https://vadneyk.github.io/portfolio/"' not in home:
    errors.append("index.html: no instant redirect to the portfolio")
llms = (PUB / "llms.txt").read_text(encoding="utf-8")
if not llms.startswith("# ") or "\n> " not in llms:
    errors.append("llms.txt: needs an H1 line and a '> ' summary line")


def status(url):
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "check_site"}), timeout=20) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception:
        return 0


if "--live" in sys.argv:
    for s in sitemaps:
        if status(s) != 200:
            errors.append("live: %s does not answer 200" % s)
if "--live-root" in sys.argv:
    for name in ("robots.txt", "sitemap.xml", "llms.txt"):
        if status(BASE + name) != 200:
            errors.append("live: %s%s does not answer 200" % (BASE, name))

if errors:
    print("check_site FAILED:")
    for e in errors:
        print("  " + e)
    sys.exit(1)
print("check_site ok: robots.txt allows all, %d sitemaps, redirect and llms.txt in place%s"
      % (len(sitemaps), ", live root files answer" if "--live-root" in sys.argv else ""))
