---
name: principle-prove-it-works
description: "Use after changes to prove the real artifact works."
disable-model-invocation: true
version: 1.0.0
author: Lauren Tan; adapted for Hermes
license: MIT
source: https://github.com/cursor/plugins/tree/main/pstack/skills/principle-prove-it-works
metadata:
  hermes:
    tags: [verification, quality-gates, evidence]
    related_skills: [create-verification-skill]
---

# Prove It Works

## When to Use

Load after implementing or changing something, before reporting completion.

Verify every task output by checking the real thing directly. Do not infer from proxies, self-reports, or “it compiles.”

Unverified work has unknown correctness. Indirect verification—file timestamps, output freshness, agent self-reports, or cached screenshots—feels cheaper than direct observation, but acting on a wrong inference costs more than checking the source.

Check the real thing, not a proxy:

- Check process liveness directly, not indirectly through derived state.
- Read the actual value, not a cached or derived representation.
- Inspect or exercise the final artifact through the interface its user relies on.
- When verification fails, inspect the observation method before diagnosing the system.

## Script the check when possible

Prefer a deterministic script that reruns the same comparison over a one-time visual check. Write the script, run it, and retain enough output for another reviewer or agent to reproduce the proof.

Keep proof visible to the user. Commit proof tooling only when it remains useful for future verification; keep transient evidence out of the repository unless the work requires an auditable trail.