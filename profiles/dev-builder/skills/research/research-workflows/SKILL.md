---
name: research-workflows
description: "Research workflows: source ingestion, knowledge bases, market-data checks, stateful analysis, and paper writing."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [research, knowledge-base, papers, market-data, analysis, notebooks]
    related_skills: [research-source-ingestion, obsidian]
---

# Research Workflows

Use this class-level umbrella when the user is doing research work rather than ordinary software delivery: collecting sources, building a durable knowledge base, querying domain data, exploring data interactively, or turning results into a paper.

A human maintainer should not need separate top-level skills for every research surface. Choose the subsection that matches the branch, then load any referenced support material only when that branch needs detail.

## Workflow selector

| Situation | Branch |
|---|---|
| User provides papers, articles, videos, transcripts, or web sources | Source ingestion |
| User wants a durable markdown/wiki knowledge base | LLM wiki / knowledge base |
| User asks about odds, Polymarket, prediction markets, or event probabilities | Prediction-market data |
| User needs stateful Python exploration or notebook-style iteration | Live analysis kernel |
| User is writing an ML/AI conference paper | Research paper writing |

## Source ingestion

For one-off source capture and summarization, prefer the existing `research-source-ingestion` skill. This umbrella owns the routing decision; the ingestion skill owns the detailed scripts for arXiv search, YouTube transcripts, and source normalization.

Completion criterion: raw source captured, claims summarized with provenance, and reusable findings routed into either the user's wiki/notes or the task deliverable.

## LLM wiki / knowledge base

Use this branch when the user wants a persistent interlinked markdown wiki in the Karpathy style.

Core rules:
1. Resolve the wiki path from `WIKI_PATH`, falling back to `~/wiki`.
2. On every resumed wiki session, orient first: read `SCHEMA.md`, `index.md`, and recent `log.md`.
3. Capture raw sources immutably under `raw/` with frontmatter and hashes when applicable.
4. Create or update entity/concept/comparison/query pages only when they meet the wiki's page thresholds.
5. Maintain wikilinks, frontmatter, index entries, and the chronological log.
6. Lint periodically for orphan pages, broken wikilinks, missing frontmatter, source drift, oversized pages, and tag drift.

Pitfall: skipping orientation causes duplicate pages and contradictory claims. Do not write new wiki pages until the schema and index have been checked.

## Prediction-market data

Use this branch when the user asks for current market-implied probabilities, Polymarket prices, order books, or price history.

Core workflow:
1. Search Polymarket's Gamma API for the user's event/query.
2. Parse events and nested markets, including double-encoded fields such as `outcomePrices`, `outcomes`, and `clobTokenIds`.
3. Present prices as probabilities with volume and market question.
4. For deeper checks, use CLOB endpoints for real-time prices, orderbooks, or condition history.

Rules:
- Treat this as read-only market data unless the user explicitly asks for trading support and the system has a separate trading-safe workflow.
- Always label prices as market-implied probabilities, not facts.
- If a market is thin or new, mention low volume/liquidity before drawing conclusions.

## Live analysis kernel

Use this branch when the user would benefit from notebook-like state: exploratory data analysis, iterative API probing, DataFrame inspection, ML experimentation, or building up variables across steps.

Default tool choice:
- use normal `execute_code` for one-shot scripts and file/tool orchestration
- use a live Jupyter kernel when state across executions matters

Operational rules preserved from the old live-kernel skill:
1. Verify `uv`, JupyterLab, and a running server before relying on the kernel.
2. Use compact JSON output when a notebook bridge supports it.
3. Retry once on first-execution kernel/websocket timeout.
4. Remember the kernel Python environment may not match the Hermes tool Python.
5. For clean verification, restart the kernel and run the notebook top-to-bottom.

## Research paper writing

Use this branch for ML/AI papers targeting venues such as NeurIPS, ICML, ICLR, ACL, AAAI, and COLM.

Loop, do not linearly march:
1. Clarify the contribution, claims, baselines, and target venue.
2. Design experiments and evaluation that could actually support the claims.
3. Run or inspect experiments, then revise claims to match evidence.
4. Write the paper around the evidence: abstract, intro, related work, method, experiments, limitations, and reproducibility.
5. Check citations, statistical claims, tables/figures, formatting, and submission constraints.
6. Iterate from reviewer-style critique back into analysis or experiments.

Support package note: the former `research-paper-writing` skill carried substantial venue templates and references. It has been archived intact for recoverability; when those exact LaTeX templates are needed, restore or consult the archived package rather than recreating venue files from memory.

## Cross-branch pitfalls

- Do not present market data, wiki synthesis, or paper claims as more certain than their sources.
- Keep raw sources/provenance separate from synthesized pages or paper prose.
- Do not create a new narrow research skill for a single provider, venue, or source type; add a subsection or support file here instead.
- Ask before mass-updating a user's wiki or paper repository when more than ten files would be touched.

## Verification checklist

- [ ] Picked the correct branch from the selector.
- [ ] Captured sources or data with provenance.
- [ ] Used the right persistence target: wiki/notes for reusable knowledge, paper repo for manuscript assets, final answer for one-off synthesis.
- [ ] Verified live commands or analysis outputs when the task depended on current data.
- [ ] Stated uncertainty, source limitations, and any blocked credentials/tools clearly.
