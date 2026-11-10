---
name: research-source-ingestion
description: "Ingest research sources from papers, feeds, and videos into summaries or downstream research workflows."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [research, ingestion, arxiv, rss, youtube, transcripts, feeds, sources]
    related_skills: [ocr-and-documents, research-paper-writing, llm-wiki]
---

# Research Source Ingestion

## Overview

Use this umbrella when the user needs to pull information from an external research/content source and turn it into something usable: candidate papers, feed updates, transcripts, summaries, chapter notes, or downstream research inputs.

This class replaces separate micro-skills for arXiv search, blog/RSS watching, and YouTube transcript extraction. The right maintainer shape is one source-ingestion umbrella with labeled subsections.

## When to Use

Use this skill for:
- finding papers on arXiv
- retrieving paper metadata, abstracts, PDFs, or citation context
- monitoring blogs and RSS/Atom feeds for new posts
- fetching YouTube transcripts and turning them into summaries, chapters, or blog/thread drafts
- collecting upstream source material before synthesis in `llm-wiki` or `research-paper-writing`

Do not use this skill for:
- OCR/extraction from local PDFs or scans — use `ocr-and-documents`
- final paper drafting/submission workflow — use `research-paper-writing`
- long-lived wiki curation itself — use `llm-wiki`

## Source Selection

Choose the subsection by source type:

| Source type | Best path |
|---|---|
| Academic papers / metadata / PDF URLs | arXiv subsection |
| Blog / RSS / Atom monitoring | feed-watching subsection |
| Video transcripts / chaptering / content repackaging | YouTube subsection |

## arXiv and academic-paper discovery

Use this when the user wants papers by keyword, author, category, or arXiv ID.

High-value rules:
- arXiv search is for discovery; `web_extract` is for reading abstracts/PDFs.
- Preserve version suffixes when the exact paper version matters.
- Check for withdrawal language before treating a result as a valid paper.
- Use Semantic Scholar after arXiv when citation counts, references, or related-paper recommendations matter.

Fast paths:
- Search: `python scripts/search_arxiv.py "query" --max 5 --sort date`
- Abstract: `web_extract(urls=["https://arxiv.org/abs/<id>"])`
- Full paper: `web_extract(urls=["https://arxiv.org/pdf/<id>"])`

## Feed-watching and blog monitoring

Use this when the user wants to track blogs or RSS/Atom feeds over time.

High-value rules:
- Prefer real feed discovery first; fall back to scraping only when necessary.
- Keep the database path/runtime explicit when running from cron or containers.
- Distinguish one-time scan/summarize tasks from durable monitoring setups.
- Use quiet runs when the task is scheduled and the user only wants meaningful updates.

Typical commands:
- `blogwatcher-cli add "Name" https://example.com`
- `blogwatcher-cli scan`
- `blogwatcher-cli articles`

## YouTube transcript extraction and repackaging

Use this when the user provides a YouTube URL/video ID and wants transcript-derived output.

High-value rules:
- Fetch the transcript first, then transform it.
- Retry without explicit language if a requested language is unavailable.
- If the transcript is very large, chunk before summarizing.
- Default to a summary when the user does not specify chapters/thread/blog/quotes.

Typical command:
- `python3 scripts/fetch_transcript.py "https://youtube.com/watch?v=..." --text-only --timestamps`

Common output shapes:
- concise summary
- chapter list
- chapter summaries
- X/Twitter thread
- blog post draft
- notable quotes with timestamps

## Common workflow

1. Identify the upstream source type.
2. Fetch or search the raw source material.
3. Validate that the fetch/search returned usable content.
4. Transform it into the requested intermediate output.
5. Hand it off to the next class of workflow if needed (`llm-wiki`, `research-paper-writing`, or direct user-facing summary).

## Common Pitfalls

1. Treating source retrieval and synthesis as the same job — separate them.
2. Skipping validation of empty/disabled transcripts or broken feeds.
3. Forgetting that citation data is not part of arXiv itself.
4. Turning scheduled monitoring into noisy spam instead of quiet delta reporting.
5. Losing timestamps/version identifiers that the downstream workflow still needs.

## Verification Checklist

- [ ] Source type matched to the right subsection
- [ ] Fetch/search actually returned usable content
- [ ] Any helper script path used from this umbrella resolves correctly
- [ ] Output format matches the user's requested artifact
- [ ] Important identifiers (paper ID/version, timestamps, feed/article URLs) were preserved when relevant
