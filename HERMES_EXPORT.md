# Used Hermes skills

A sanitized snapshot of skills with recorded usage across four Hermes profiles. This is not the full installed skill catalog, not a credential backup, and not a claim that every historical invocation completed its task successfully.

## Contents

- `profiles/default/`: 44 profile-specific skill copies.
- `profiles/dev-builder/`: 66 profile-specific skill copies.
- `profiles/health-coach/`: 34 profile-specific skill copies.
- `profiles/herbalife-business/`: 23 profile-specific skill copies.
- `recovered/`: 3 available copies of historically used skills whose original profile copy no longer exists.
- `manifest.json`: machine-readable selection evidence, state, file locations and exclusions.

**128 distinct skill names, 170 skill-directory copies.** Copies are deliberately not merged: profiles may contain different instructions, scripts and references for the same skill name.

Each profile separates:

- `skills/`: currently present, non-archived skills with recorded use (including stale entries).
- `archived/`: previously used skills that are now archived. These are historical material, not a recommendation to activate obsolete workflows.

## Selection rule

A skill qualifies when local Hermes usage telemetry reports `use_count > 0`, or session history records a `skill_view` invocation. A skill's installation, mention in the available-skills catalog, or edit alone does not qualify. Fully qualified skill aliases are normalized to the canonical skill name.

Usage telemetry can have been inherited when a profile was cloned; counters are evidence of recorded use, not an independent proof that every use happened after profile creation. The manifest includes session-call counts separately. No conversations or session databases are included.

For the three recovered skills, `used_in_profiles` identifies the historical usage and `source_profile` identifies the available source copy. These are not reconstructions of the missing original bytes.

One historically used skill, `audiocraft-audio-generation`, is absent from all inspected skill trees and could not be exported. Its missing entries are recorded in the manifest rather than replaced with invented content.

## Public-export safety

The destination repository is public. Exported text is sanitized: detected credentials are replaced with `[REDACTED]`; selected private endpoints, contact identifiers and precise coordinates are replaced with examples/placeholders. Runtime databases, environment files and private-key material are not exported. Eight binary example PDFs are omitted and listed in the manifest.

This is a documentation/code export, not a ready-to-run backup of a personal server. Replace placeholders and review commands, access scope, infrastructure names and old instructions before use. The original Hermes profiles have not been changed.

## Layout and reuse

Each skill directory retains its `SKILL.md` and the exportable references, templates, scripts and text assets shipped with it. Choose the intended profile version instead of installing every duplicate or archived skill at once.

## Attribution and licensing

Original authors, provenance and license declarations are retained where present in each skill and supporting files. This repository does not relicense third-party content under a blanket license. Check the individual skill's terms before redistribution or reuse.
