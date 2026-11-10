---
name: workspace-content-operations
description: "Operate document, note, spreadsheet, database, and slide workspaces across Google Workspace, Notion, Obsidian, Airtable, OCR pipelines, and PowerPoint."
version: 1.0.0
author: Hermes Curator
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [workspace, documents, notes, spreadsheets, slides, database, productivity, ocr]
    related_skills: [google-workspace, notion, obsidian, airtable, ocr-and-documents, powerpoint]
---

# Workspace Content Operations

Use this umbrella when the task is fundamentally about **moving, extracting, editing, organizing, or presenting knowledge artifacts** across common workspace surfaces rather than about one vendor in isolation.

This skill replaces several narrower siblings whose real distinction was the storage surface, not the workflow class.

## When to use

Choose this skill for:
- creating or editing notes, docs, spreadsheets, records, or decks
- extracting content from PDFs/scans before moving it into a workspace
- deciding which workspace surface fits a task best
- shuttling content between personal knowledge bases and collaborative tools
- producing presentation-ready outputs from upstream notes or documents

## Decision tree

- **Google-native collaboration surface needed** → Google Workspace mode
- **structured wiki/database workspace** → Notion mode
- **local markdown knowledge vault** → Obsidian mode
- **lightweight tabular app/database CRUD** → Airtable mode
- **source material is PDF/scan/image first** → OCR and document extraction mode
- **final deliverable is a slide deck or editable `.pptx`** → PowerPoint mode

## Shared workflow

1. Identify the source artifact and target surface.
2. Decide whether the job is extraction, transformation, organization, or presentation.
3. Normalize the content structure first: headings, fields, tables, bullets, citations, speaker notes, etc.
4. Use the narrowest tool path that preserves editability in the destination system.
5. Verify the artifact in its native form before declaring success.

## Mode: Google Workspace

Use for Gmail, Calendar, Drive, Docs, and Sheets work that benefits from Google's collaborative surfaces.

Carry forward:
- prefer the established CLI/Python workflow already documented in the original skill
- verify the exact file, sheet, doc, or message identifier after mutations
- preserve collaborative structure instead of flattening everything to plain text

## Mode: Notion

Use for page/database operations, workspace knowledge organization, and markdown-to-Notion publishing.

Carry forward:
- distinguish clearly between pages, databases/data sources, and their property schemas
- preserve rich structure and metadata on import/export
- prefer workflows that keep future edits easy, not one-off dumps

## Mode: Obsidian

Use for local markdown vault maintenance, note linking, search, daily logs, and research-wiki style personal knowledge work.

Carry forward:
- keep files portable and markdown-first
- preserve wiki-links, frontmatter, and vault conventions
- optimize for incremental maintenance, not just one-shot note creation

## Mode: Airtable

Use for records CRUD, filters, upserts, and lightweight operational databases.

Carry forward:
- treat schema awareness as mandatory before writes
- preserve field types and pagination details
- verify record IDs and mutation results from the API response

## Mode: OCR and document extraction

Use when the source artifact is a PDF, scan, or image and the first job is text extraction or document recovery.

Carry forward:
- choose the extractor based on quality/speed needs
- keep the extracted text structured enough for downstream import
- treat OCR as a preprocessing stage for workspace operations, not an end in itself

## Mode: PowerPoint

Use when the final deliverable must be an editable presentation deck rather than raw notes or markdown.

Carry forward:
- keep slide structure, speaker notes, and layout semantics intact
- prefer editable `.pptx` outputs over screenshots or HTML-only approximations
- verify the deck opens and the intended slides/notes exist

## What changed in this umbrella

These narrower siblings are now represented here as labeled subsections instead of as separate top-level discovery targets:
- `google-workspace`
- `notion`
- `obsidian`
- `airtable`
- `ocr-and-documents`
- `powerpoint`

Keep standalone skills only when the workflow class truly diverges; vendor-specific API differences alone are not enough.
