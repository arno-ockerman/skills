#!/usr/bin/env python3
"""Apply a fallback policy to one or more Hermes config.yaml files.

Policy: whenever a pinned provider (default: openai-codex) fails, fall back to a
chosen model on a chosen provider (default: deepseek/deepseek-v4-flash).

Per config file:
  1. top-level ``fallback_providers``          -> fallback chain
  2. ``auxiliary.<task>.fallback_chain``       -> fallback chain, for every aux task
     whose provider is the pinned provider (the main chain is NOT consulted for
     tasks with an explicit provider, so they need their own chain)

Surgical line edits: comments and unrelated keys are preserved verbatim.
Writes a timestamped .bak-<ts> next to each file and validates the result with
yaml.safe_load before finishing. Idempotent — already-patched tasks are skipped.

Usage:
    python3 apply_fallback_policy.py CONFIG [CONFIG ...]
    python3 apply_fallback_policy.py --provider openai-codex \
        --model deepseek-v4-flash --target deepseek CONFIG [CONFIG ...]

Run with a Python that has PyYAML (e.g. /opt/hermes/.venv/bin/python).
"""
import argparse
import sys
import time
from pathlib import Path

import yaml

PINNED_DEFAULT = "openai-codex"
TARGET_DEFAULT = "deepseek"
MODEL_DEFAULT = "deepseek-v4-flash"


def block_range(lines, header):
    """Return (start, end) of a YAML block starting at an exact header line."""
    for i, line in enumerate(lines):
        if line.rstrip("\n") == header:
            indent = len(line) - len(line.lstrip())
            j = i + 1
            while j < len(lines):
                if lines[j].strip() == "":
                    j += 1
                    continue
                if len(lines[j]) - len(lines[j].lstrip()) <= indent:
                    break
                j += 1
            return i, j
    return None, None


def pinned_aux_tasks(lines, pinned, aux_header="auxiliary:"):
    """Names of auxiliary.<task> blocks whose provider is ``pinned``."""
    s, e = block_range(lines, aux_header)
    if s is None:
        return []
    tasks = []
    for k in range(s + 1, e):
        line = lines[k]
        indent = len(line) - len(line.lstrip())
        if indent != 2 or not line.strip().endswith(":"):
            continue
        name = line.strip()[:-1]
        t_end = k + 1
        while t_end < e and (lines[t_end].strip() == ""
                             or len(lines[t_end]) - len(lines[t_end].lstrip()) > 2):
            t_end += 1
        body = lines[k + 1:t_end]
        if any(b.strip() == f"provider: {pinned}" for b in body):
            tasks.append(name)
    return tasks


def process(path, pinned, target, model):
    p = Path(path)
    original = p.read_text()
    lines = original.splitlines()
    fb_task = ["    fallback_chain:", f"      - provider: {target}",
               f"        model: {model}"]
    top_chain = ["fallback_providers:", f"  - provider: {target}",
                 f"    model: {model}"]
    report = {"file": str(p), "aux": [], "skipped": []}

    s, e = block_range(lines, "fallback_providers:")
    if s is None:
        report["skipped"].append("no fallback_providers block")
    else:
        report["old_top"] = [l.strip() for l in lines[s:e]]
        lines[s:e] = top_chain

    for task in pinned_aux_tasks(lines, pinned):
        s, e = block_range(lines, f"  {task}:")
        if s is None:
            report["skipped"].append(f"{task}: block vanished")
            continue
        if any(l.strip().startswith("fallback_chain:") for l in lines[s:e]):
            report["skipped"].append(f"{task}: already set")
            continue
        ins = next((k + 1 for k in range(s + 1, e)
                    if lines[k].strip().startswith("provider:")), None)
        if ins is None:
            report["skipped"].append(f"{task}: no provider line")
            continue
        lines[ins:ins] = fb_task
        report["aux"].append(task)

    bak = p.with_name(p.name + ".bak-fallback-" + time.strftime("%Y%m%d%H%M%S"))
    bak.write_text(original)
    p.write_text("\n".join(lines) + "\n")

    data = yaml.safe_load(p.read_text())  # validation: raises on bad YAML
    report["parsed_top"] = data.get("fallback_providers")
    report["parsed_aux"] = {
        t: ((data.get("auxiliary") or {}).get(t) or {}).get("fallback_chain")
        for t in report["aux"]
    }
    report["backup"] = str(bak)
    return report


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--provider", default=PINNED_DEFAULT,
                    help=f"provider whose tasks/primary get a fallback (default {PINNED_DEFAULT})")
    ap.add_argument("--target", default=TARGET_DEFAULT,
                    help=f"fallback provider (default {TARGET_DEFAULT})")
    ap.add_argument("--model", default=MODEL_DEFAULT,
                    help=f"fallback model (default {MODEL_DEFAULT})")
    ap.add_argument("configs", nargs="+")
    args = ap.parse_args()
    for arg in args.configs:
        r = process(arg, args.provider, args.target, args.model)
        print(f"\n=== {r['file']}")
        print("  backup:", r["backup"])
        print("  old top chain:", r.get("old_top"))
        print("  new top chain:", r["parsed_top"])
        print("  aux tasks given a fallback_chain:", r["aux"])
        print("  parsed aux chains:", r["parsed_aux"])
        if r["skipped"]:
            print("  skipped:", r["skipped"])
    print("\nReminder: chains are read at agent init — the running session keeps the old"
          " chain until /new or a gateway restart. Re-run to verify idempotency.")


if __name__ == "__main__":
    sys.exit(main())
