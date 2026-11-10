---
name: rendered-page-extraction
description: "Use when a page only yields content in a browser."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Scraping, Playwright, SPA, Marketplace, Extraction]
    related_skills: [blocked-page-recovery]
---

# Rendered-Page Extraction

For pages that return nothing useful to `web_extract` or `curl` but render fully in a real
browser: JS-rendered SPAs, marketplace and social listing pages, search results, and content
behind a login wall.

This skill owns the *render it yourself and mine the payload* route. `blocked-page-recovery`
owns the archive/API-first routes (Wayback, archive.today, Jina, `/api/` endpoints) — try
those first when they apply, and come here when the content only exists client-side.

## Procedure

### 1. Choose the path by symptom

| Symptom | Path |
|---------|------|
| `web_extract` reports the site as unsupported | Render it yourself |
| `curl` returns 4xx but a browser renders fine | Render it yourself |
| Visible text is only a login form | Render, then read the embedded JSON |
| Page fetches, but content is truncated | Read the embedded JSON, not `og:` meta |

A user-agent-spoofed `curl` is still worth one attempt, but a hard 4xx there says nothing
about whether a browser will succeed.

### 2. Render with Playwright

When the agent browser tool is unavailable in the session, drive Playwright directly — it is
usually already installed as a project dependency:

```bash
export PLAYWRIGHT_BROWSERS_PATH=<dir holding the browser builds>
```

```js
(async () => {                                    // node -e has no top-level await
  const { chromium } = require('<repo>/node_modules/playwright');
  const b = await chromium.launch({ args: ['--no-sandbox', '--disable-dev-shm-usage'] });
  const p = await b.newPage({ userAgent: '<desktop Chrome UA>', locale: '<target locale>' });
  await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await p.waitForTimeout(8000);                   // let the SPA hydrate
  console.log(await p.title(), p.url());           // the redirect reveals the canonical URL
  require('fs').writeFileSync('/tmp/page.html', await p.content());
  await b.close();
})();
```

`await p.url()` after load resolves share/redirect links to the canonical item id that every
follow-up request needs. Dump the full HTML and parse it in Python — do not scrape rendered
text.

### 3. Mine the embedded JSON, not the DOM

The content you want is usually in the page's own serialized data, not in the rendered text.
On a login-walled page the `innerText` is just the login form while the payload holds the full
record — **never conclude "login required" from `innerText`**.

Search the dumped HTML for:

- **`og:` / `twitter:` meta** — cheap and always present. Treat `og:description` as a
  *truncated teaser* (it commonly ends mid-sentence with an ellipsis): take the title from it,
  never the body.
- **`*_description` / `*_text` fields** (e.g. `redacted_description`) — the full body copy,
  and precisely what the login wall truncated in the meta tags.
- **Structured numeric fields** (`price.amount` + `currency`, `formatted_price.text`) — exact,
  where the rendered price string is locale-formatted and ambiguous.
- **`application/ld+json`** — the cleanest source when present, frequently absent on the
  hardest sites.

Decode JSON escapes properly (`unicode_escape`, then re-decode as UTF-8); naive decoding
mangles the accented characters and currency symbols you actually need.

### 4. Verify the harvest — pages ship their neighbours too

**This is the pitfall that costs the most credibility.** Listing and search pages embed other
sellers' items: recommendation carousels, "more like this" rows, sponsored slots. Harvesting
`https://...jpg` URLs out of the HTML returns those neighbours alongside the real item, so a
gallery built from "the first N images found" is mostly unrelated products.

Before presenting any harvested asset as belonging to the target:

1. Filter on an anchor tied to the target id (the item id in the URL or filename, or the
   specific image set the canonical record references) — never on position in the document.
2. Confirm visually before forwarding anything to the user.
3. If a gallery comes out mostly wrong, the filter is wrong: fix the filter rather than
   hand-picking the good ones.

### 5. Inspect many images without image tooling

No PIL or ImageMagick needed — use the browser you already have running:

1. Base64-encode each candidate and inline it as a `data:image/...;base64,...` `<img>` in a
   CSS-grid HTML file, with a caption per cell naming its source.
2. Open that file with Playwright and `screenshot({ fullPage: true })`.
3. Inspect the PNG with vision.

This costs one screenshot instead of one vision call per image, keeps provenance attached in
the captions, and is the fastest way to *detect* contamination — if the sheet shows unrelated
objects, the filter in step 4 is wrong.

### 6. Citing

This is live content, so cite it normally. When a listing can change or expire and the user
will act on what you report, quote the exact field values you read rather than linking and
assuming the page still says that.

## Pitfalls

- Reporting a login wall or an empty extraction without first reading the page's own payload.
- Taking body copy from `og:description` / `meta[name=description]`, which is deliberately
  truncated.
- Building a gallery from document order instead of an id-tied anchor.
- Forwarding harvested images or specs to the user unverified.
- Hardcoding one session's browser path: read `PLAYWRIGHT_BROWSERS_PATH` from the environment
  or locate the project's installed browser build.
