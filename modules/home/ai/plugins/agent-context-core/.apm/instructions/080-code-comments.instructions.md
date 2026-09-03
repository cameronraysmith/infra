---
description: Treat code comments as noise by default, reserving them for what the code cannot express, and preserve the named load-bearing categories.
---

## Code comments

Write self-explanatory code and treat code comments as noise by default: reserve comments for what the code cannot express, such as a true non-obvious reason behind a choice, a surprising external constraint, an upstream-bug workaround with a link, or a correctness or security footgun.
Proactively remove comments that fail this bar wherever you encounter them in our own code, treating comment cleanup as a standing responsibility rather than one gated to the current change.
Never remove license or SPDX headers, shebangs, encoding declarations, linter or type-checker or formatter pragmas, public-API docstrings and doc comments, code-generation markers, or tooling-parsed directives, and never touch vendored, generated, or upstream-mirrored trees; when unsure whether a comment is load-bearing, preserve it and surface the question.
The style-and-conventions skill's Code comments section holds the full policy and carve-out list, and `preferences-comment-cleanup` is its operational arm: an uncomment-driven workflow for auditing and removing noise comments while preserving load-bearing markers.
