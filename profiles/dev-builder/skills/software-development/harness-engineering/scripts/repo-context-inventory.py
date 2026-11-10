#!/usr/bin/env python3
"""Deterministic repository context inventory.

Usage:
    python repo-context-inventory.py /path/to/repo [--top 20]

Prints JSON only. It does not read file contents or follow symlinks.
"""

from __future__ import annotations

import argparse
import json
import os
from collections import defaultdict
from pathlib import Path

DEFAULT_EXCLUDES = {
    ".git",
    "node_modules",
    "dist",
    "build",
    "coverage",
    ".firebase",
    "firebase-data",
    "playwright-report",
    "test-results",
    ".next",
    ".expo",
    ".turbo",
}

TEXT_EXTENSIONS = {
    ".c", ".cc", ".cpp", ".css", ".go", ".graphql", ".h", ".html",
    ".java", ".js", ".json", ".jsx", ".kt", ".md", ".mjs", ".py",
    ".rb", ".rs", ".sh", ".sql", ".swift", ".toml", ".ts", ".tsx",
    ".txt", ".xml", ".yaml", ".yml",
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("repo", type=Path)
    parser.add_argument("--top", type=int, default=20)
    parser.add_argument("--exclude", action="append", default=[])
    args = parser.parse_args()

    repo = args.repo.resolve()
    if not repo.is_dir():
        parser.error(f"not a directory: {repo}")

    excludes = DEFAULT_EXCLUDES | set(args.exclude)
    files: list[dict[str, object]] = []
    by_dir: dict[str, dict[str, int]] = defaultdict(lambda: {"files": 0, "bytes": 0})
    by_ext: dict[str, dict[str, int]] = defaultdict(lambda: {"files": 0, "bytes": 0})

    for root, dirs, names in os.walk(repo, followlinks=False):
        dirs[:] = sorted(d for d in dirs if d not in excludes)
        root_path = Path(root)
        relative_root = root_path.relative_to(repo)
        top_level = "." if relative_root == Path(".") else relative_root.parts[0]

        for name in sorted(names):
            path = root_path / name
            if path.is_symlink():
                continue
            try:
                size = path.stat().st_size
            except OSError:
                continue

            relative = path.relative_to(repo).as_posix()
            extension = path.suffix.lower() or "[none]"
            textual = extension in TEXT_EXTENSIONS
            files.append({"path": relative, "bytes": size, "textual": textual})
            by_dir[top_level]["files"] += 1
            by_dir[top_level]["bytes"] += size
            by_ext[extension]["files"] += 1
            by_ext[extension]["bytes"] += size

    top = max(1, args.top)
    largest = sorted(files, key=lambda row: int(row["bytes"]), reverse=True)
    largest_text = [row for row in largest if row["textual"]]

    result = {
        "repo": str(repo),
        "excluded_directories": sorted(excludes),
        "totals": {
            "files": len(files),
            "bytes": sum(int(row["bytes"]) for row in files),
            "textual_files": sum(1 for row in files if row["textual"]),
            "textual_bytes": sum(int(row["bytes"]) for row in files if row["textual"]),
        },
        "largest_files": largest[:top],
        "largest_text_files": largest_text[:top],
        "largest_top_level_directories": [
            {"path": path, **stats}
            for path, stats in sorted(by_dir.items(), key=lambda item: item[1]["bytes"], reverse=True)[:top]
        ],
        "largest_extensions": [
            {"extension": extension, **stats}
            for extension, stats in sorted(by_ext.items(), key=lambda item: item[1]["bytes"], reverse=True)[:top]
        ],
    }
    print(json.dumps(result, indent=2, sort_keys=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
