# vadneyk.github.io

The host root of https://vadneyk.github.io/. It sends visitors to the projects page and holds the
few files that only work at the top of the host:

- `robots.txt`: crawlers read robots.txt only here, so this one file covers every project site under
  vadneyk.github.io. It allows every crawler and names each site's sitemap. It must never block anything:
  a block here reaches all of the sites, and a page that a crawler may not fetch can still be listed by its
  bare address, because the crawler never sees the page's own noindex.
- `sitemap.xml`: a sitemap index that names each site's own sitemap, so one address can be submitted to
  Google Search Console and Bing Webmaster Tools.
- `llms.txt`: a short plain list of the sites for AI answer engines; each site has its own with more detail.
- `index.html`: an instant redirect to https://vadneyk.github.io/portfolio/, with a list of the sites for
  anyone whose browser does not follow it.
- `404.html`: the page shown for an address that does not exist.
- `e72f642df69795931faca64c89f7d45b.txt`: the IndexNow key. Bing (and so Copilot) and other IndexNow engines accept
  URL updates for any site under vadneyk.github.io from `tools/indexnow.py` in the hub, which names this file.
  The key is public by design; it only proves the sender controls the host.

No tracking, no analytics, nothing that collects data.

## Release

```bash
make check   # file checks, and every sitemap named answers 200 on the live sites
make ship    # check, merge the open PR, wait for the deploy, smoke-test the live root, revert on failure
```

When a new site with a sitemap goes live under vadneyk.github.io, add its sitemap to both `robots.txt` and
`sitemap.xml`, and a line to `llms.txt`, `index.html` and `404.html`.
