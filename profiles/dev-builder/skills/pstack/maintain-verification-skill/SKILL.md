---
name: maintain-verification-skill
description: "Use to audit a repo's existing verification skill."
disable-model-invocation: true
version: 1.0.0
author: Lauren Tan; adapted for Hermes
license: MIT
source: https://github.com/cursor/plugins/tree/main/pstack/skills/maintain-verification-skill
metadata:
  hermes:
    tags: [verification, maintenance, e2e]
    related_skills: [create-verification-skill]
---

# Maintain a Verification Skill

## When to Use

Load after user-facing changes or periodically when a repository already has a verification skill and feature map.

Use for a repository-local verification skill, normally `.hermes/skills/verify-*/`, that contains launch/drive instructions and a feature map.

## Outcomes

Choose and report exactly one:

- **clean:** every feature received source and live coverage; no change worth shipping.
- **changed:** one focused change or PR contains proven verification-skill corrections.
- **blocked:** coverage or safe delivery could not finish; state the precise blocker.

## Edit scope

Edit only the target verification skill directory: its `SKILL.md`, `features/`, and owned harness scripts. Never change product code during this maintenance pass. Treat behavior drift as either verification documentation drift or a product regression; report product regressions rather than hiding them in the verification map.

## Maintenance pass

1. **Locate:** find `.hermes/skills/verify-*/` or another repository-local skill with launch, doctor, drive, evidence, cleanup, and a feature map. Ask only when several valid targets exist. If none exists, stop and use `create-verification-skill`.
2. **Index hygiene:** compare the feature README with sibling feature files; correct missing, duplicate, extra, or dead entries.
3. **Source wave:** delegate one read-only investigation per feature concurrently. Each returns a concise behavior summary, source entry points, likely drift with citations, and one live-verification recipe. Subagents do not drive the app or edit files.
4. **Reconcile:** account for every feature file, combine overlapping recipes, spot-check alleged drift, and inspect recent user-facing changes for features missing from the map.
5. **Live pass:** the coordinator follows the verification skill’s launch model and exercises every mapped feature. Doctor before the first drive, after surprising failures, and for every new isolated session when sessions are the unit. Preserve evidence through cleanup and remove residue from failed drives.
6. **Triage:** fix user-POV documentation drift and harness gaps inside the skill. Re-drive every harness correction. Report broken product behavior separately.
7. **Ship or stop:** for `changed`, deliver one focused set of proven corrections and reread every changed file. For `clean` or `blocked`, create no change merely to record the run.
8. **Teardown:** leave no owned process or disposable state running. Preserve named proof artifacts.

Keep concise scratch notes for features covered, unreachable prerequisites, confirmed drift, product gaps, and final outcome. Do not commit run notes.