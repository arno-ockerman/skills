---
name: web-performance-audit
description: Audit web performance with real Lighthouse runs.
---

# Web Performance Audit

Evidence-first audit: measure production before reading code, then explain the numbers with code findings. Never report a performance claim you did not measure or cite.

## Setup (already provisioned)

Chrome and Lighthouse live persistently in this container — nothing to install on the host:

```bash
lighthouse-audit <url> [--desktop] [--runs 3] [--out DIR]
```

- Chrome: `/opt/data/profiles/dev-builder/tools/chrome/opt/google/chrome/google-chrome`
- Lighthouse: `/opt/data/profiles/dev-builder/tools/lighthouse/`
- Wrapper: `/opt/data/profiles/dev-builder/tools/bin/lighthouse-audit` (on PATH via `~/.bashrc`)

`/tmp` is wiped on container restart — always keep tools under `/opt/data`, and treat `/tmp` as scratch output only.

## Phase 1 — Measure the baseline

Target the **deployed production URL**, not a local dev server: dev builds are unminified and lie about the payload.

```bash
lighthouse-audit https://<prod-host>/ --runs 3 --out /tmp/lh-audit
lighthouse-audit https://<prod-host>/ --desktop --runs 3 --out /tmp/lh-desktop
```

**Always run 3+ timed runs.** Mobile Lighthouse on a shared container varies hugely on the same page (observed 60–83 on an unchanged build). A single run is noise; report the median and the spread. The wrapper warns automatically when the spread exceeds 15 points.

## Phase 2 — Explain the numbers from the JSON

The healthiest path from score to root cause, in order:

1. **`largest-contentful-paint-element` / `lcp-breakdown-insight`** — names the actual LCP element. It is often a cookie banner or consent text, not the hero, which tells you the bottleneck is JS, not images.
2. **`network-requests` sorted by `transferSize`** — one oversized image usually dominates the whole payload. Check its share of `total-byte-weight`.
3. **`unused-javascript`** — per-chunk `wastedBytes`. Tells you exactly which vendor chunk to split or defer.
4. **`bootup-time` + `third-parties-insight`** — which origin's script actually burns main-thread time. Third-party auth/analytics SDKs frequently cost more than the app itself.
5. **`render-blocking-resources` / `network-dependency-tree-insight`** — the critical request chain before first paint.

```bash
node -e '
const r=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")), a=r.audits;
const s=id=>a[id]?.details?.items||[];
console.log("LCP element:", JSON.stringify(a["largest-contentful-paint-element"]?.details?.items?.slice(0,2),null,1));
console.log("Chains:", JSON.stringify(a["network-dependency-tree-insight"]?.details?.items?.[0]?.value?.chains,null,1));
for (const x of (a["network-requests"]?.details?.items||[]).sort((p,q)=>(q.transferSize||0)-(p.transferSize||0)).slice(0,12))
  console.log(x.transferSize, "\t", x.url);
console.log("Unused JS:", JSON.stringify(s("unused-javascript"),null,1));
' /tmp/lh-audit/run-1.json
```

Also map the build tool's bundle output to reality: `vite build` reports **raw** size, while `transferSize` is **compressed**. Do not conflate them.

## Phase 3 — Parallel code lanes

Once you know which axis dominates, fan out with `delegate_task` — one lane per surface, so findings do not contaminate each other:

- **Frontend lane** — initial load, renders, code-splitting, images, i18n.
- **Data-access lane** — N+1 queries, unbounded reads, listeners, forced-server reads, caching.
- **Backend lane** — cold starts, sequential awaits, broad reads, heavy PDF/image/email work.

Give every lane: the repo path, the measured metrics as context, exact instruction to **change no code**, and required output `severity | file:lines | impact | minimal fix`. Ask for a max count so lanes stay signal-dense.

## Phase 4 — Report

Lead with the metrics table, then findings ordered by priority, then a smallest-diff-first plan. State clearly which findings are **proven** vs **conditional** (a cold-start claim without Cloud Logging evidence is conditional).

Tie every recommendation back to a number you measured.

## Pitfalls

- **PageSpeed Insights API is unusable here** — returns `429 / quota_limit_value: 0`. Use local Lighthouse.
- **`npx playwright install` hangs** in this container and Playwright browsers are absent. The Chrome `.deb` route is what works:
  ```bash
  curl -fL 'https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb' -o /tmp/chrome.deb
  dpkg-deb -x /tmp/chrome.deb /opt/data/profiles/dev-builder/tools/chrome
  ```
  No `apt` needed and no missing shared libs.
- **Verify the branch before quoting line numbers.** The working tree is often on a different branch than expected; run `git branch --show-current` and state any mismatch in the report.
- **Never touch the user's uncommitted changes.** Audit read-only unless explicitly asked to implement.
- **Skip local dev servers** for baselines — HMR/dev bundles invalidate every payload number.
- **Check both profiles.** A site can be 97 desktop and 71 mobile; reporting only one hides the real problem.
