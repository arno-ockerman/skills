---
name: homelab-hardware-buying
description: "Buy/evaluate 2nd-hand dev-server hardware & local-LLM GPUs."
---

# Secondhand Homelab / Dev-Server Hardware Buying

Domain advisory for buying used/refurbished hardware for de gebruiker's homelab (TrueNAS, dev-server, Archon, local LLM). Covers workload→hardware mapping, platform shortlists, price anchors, listing evaluation, and the deals-scout cron that watches the market daily.

## Workload → hardware mapping (do this BEFORE looking at listings)

Profile the real workload first; conclusions follow from it. Reference profile (Archon + parallel coding agents, cloud LLM inference, 24/7):

- Cloud-API/cloud-subscription LLM (Claude Code, Codex) → **GPU is NOT needed** at purchase time. Never pay a gaming-PC premium for a GPU the workload won't use.
- Coding agents + builds + Docker + DBs → RAM capacity and NVMe matter most, then single-core. Multiple agents = many concurrent Node/container processes → 64 GB preferred (32 GB minimum, 16 GB floor).
- Local agentic LLM *later* → drives the GPU decision, not the base machine (see `references/local-llm-hardware-levels.md`).
- Energy: Belgium ~€0.30-0.40/kWh. A 24/7 workstation at ~60 W idle ≈ €150-180/yr vs a Mac mini at ~7 W ≈ €25/yr. State the tradeoff explicitly.

## Platform shortlist (BE/NL/EU used market, 2026)

| Platform | Verdict | Why |
|---|---|---|
| Lenovo ThinkStation P520 / HP Z4 G4 / Dell Precision 5820 (Xeon W-2135/W-2145, 64 GB ECC) | **Best €500 dev-server buy** | 8 DIMM slots (→256 GB), cheap ECC RDIMM, 2x PCIe x16, Platinum PSU, quiet tower, proven 24/7. Single-core ~35% below Zen 3 but fine when LLM latency is cloud-bound |
| Ryzen 9 3900X/5900X + 64 GB DDR4 | Runner-up, faster builds | 2x cores vs W-2135, better single-core; but non-ECC, 4 DIMM max 128 GB, and complete systems < €500 are rare (mostly CPU-only or GPU-inflated gaming listings) |
| Mac mini M1/M2 16 GB | Only if iOS/Xcode or power efficiency is the priority | 16 GB non-upgradeable ceiling, ARM Docker limits, no NVIDIA path. M4 16 GB still > €600 used |
| Mini-PC (i5-12400T/i7-12700T) | Secondary node only | Great single-core and 10-15 W idle but 2 SODIMM cap, no GPU path |
| Old rack servers (R730/DL380 G9) | **Reject** | 100-150 W idle, loud, E5 v3/v4 single-core ~1.9-2.1k PassMark, proprietary parts. Cheap cores are a trap |

## Evaluation workflow + de gebruiker's required deliverable format

de gebruiker wants, in Dutch, direct and practical: (1) top-5 table with exact CPU/RAM/storage/GPU, price, performance, power, upgradeability, pros/cons; (2) **price-limit table** — "Koop tot €X / Goede deal < €X / Overslaan boven €X" so he can judge listings in seconds; (3) explicit Mac-vs-x86 comparison; (4) ONE final pick with reasoning; (5) one iOS alternative; (6) upgrade path; (7) concrete live ads with verdicts (KOPEN / BIEDEN ≤ X / TWIJFEL / OVERSLAAN), links, location, red flags.

Do real web research (2dehands.be, marktplaats.nl, Tweakers V&A, eBay BE/NL, refurb resellers). Give live prices, not theory. Be critical — don't rubber-stamp the user's own guess.

## Marketplaces & refurb resellers (BE/NL)

- Private: 2dehands.be, marktplaats.nl (check the Adevinta cross-listing — same ad on both), Tweakers V&A, eBay.
- Refurb with warranty: queensystems.nl (HP Z-series), technimax.be / technimax.nl (Dell Precision), thatsit.nl (Dell), dubbelgaaf.nl, mac-store24.com (Mac). Reseller markup ~10-25% buys 1-2 yr warranty; private is cheaper but as-is.
- Up-to-date price anchors: `references/used-market-benchmarks.md`. Re-anchor every few months — this market moves.
- Verify shortlisted Adevinta ads beyond search snippets: fetch the direct page, read `<title>`/description metadata, extract the embedded `"price"` and `cityName`, and treat a current rendered page plus matching listing ID as active evidence. If only the search index exposes price/status, label it indexed rather than verified; search snippets can be stale.

## Pitfalls (learned the hard way)

- **P520/Precision 5820 accept registered ECC RDIMM ONLY** — unbuffered DDR4 will not work. RAM must be ECC RDIMM DDR4-2666.
- **Check PSU wattage before GPU upgrades**: P520 ships 690 W OR 900 W — a 3090 needs the 900 W. Ask the seller explicitly. Z4 G4: 750/1000 W. Also check PCIe 8-pin count (3090 wants 2-3x 8-pin).
- Treat Tesla P40 as a budget experiment, not a drop-in GPU: it is passive, has no display output, uses a Tesla EPS-style 8-pin pinout (wrong PCIe/EPS cabling can destroy hardware), and needs a shroud/high-static-pressure fan. Prefer a P520 900 W, keep a small display GPU or run headless, and use llama.cpp/Ollama rather than promising vLLM support.
- Distinguish VRAM capacity from serving quality: RTX 3060 12 GB is good for 7B/14B autocomplete/chat but does not hold the preferred 30B agentic coder; P40 24 GB holds it cheaply but has slower prompt ingestion and legacy software constraints; RTX 3090 24 GB is the durable level-3 target.
- 4-core Xeon W (W-2123/2125/2102) are weak buys unless < €350 — W-2102 has no HT at all.
- Sub-€350 RTX 3090 listings are almost certainly scams; €1300+ is new-stock price.
- Used 3090s may have mined: require a stress-test / GPU-Z temps at pickup.
- Rack servers: only consider if the user has a server closet AND you've checked the seller's actual idle draw.
- Mac mini 256 GB (M2) is single-NAND → noticeably slower SSD.
- Ollama default context is 2-4k tokens — useless for agents; always set `num_ctx ≥ 32768` (details in local-LLM reference).
- When comparing modern “AI mini PCs” with a GPU workstation, separate cloud development from local inference: a modern mobile CPU can be much faster and more efficient for Archon/cloud agents, but an integrated GPU/NPU using shared RAM does not replace 24 GB of CUDA VRAM. OCuLink permits an external NVIDIA GPU but adds a dock, PSU, cabling, and cost.
- For Bosgame M7-class systems, treat 32 GB as borderline for parallel agents + Docker/Supabase. Require a 64 GB upgrade; when both SODIMM slots ship occupied, budget for replacing the kit. Weigh modern CPU/NVMe/dual-2.5GbE and ~12 W measured idle against non-ECC RAM, soldered CPU, small-vendor RMA risk, and no internal PCIe GPU.
- Ad freshness: search snippets carry date stamps; if page extraction is blocked, say you could not verify the ad is still live rather than claiming it is.

## Operationalizing

- Daily market watch: cron job `deals-scout-dev-server` (08:00) searches for the target workstation + RTX 3090 specs and reports new deals with verdicts. Its prompt embeds the full spec/limit set — copy from the job, not from memory.
- Cron jobs created from a desktop/CLI session default to `deliver='local'` (no live channel); set `deliver='all'` explicitly so results reach connected channels.
- If de gebruiker asks to save a dossier into `/opt/ai-context/ProductivityCenter`: `write_file` is restricted to `/opt/data` (HERMES_WRITE_SAFE_ROOT). Use the terminal, and get his explicit go-ahead first — the interactive consent prompt may otherwise time out and block the write.

## References

- `references/used-market-benchmarks.md` — rolling price anchors and buy-limits per platform.
- `references/local-llm-hardware-levels.md` — model/VRAM matrix for local coding LLMs (levels 1-3) and Ollama/agent wiring.
