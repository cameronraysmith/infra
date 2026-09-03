---
description: Standing override of the wait-for-permission default — commit atomically after each edit, and never rewrite history without explicit instruction.
---

## Commit behavior override

Absent this instruction, an agent defaults to waiting for explicit permission before committing and to batching edits into infrequent, larger commits; both defaults are overridden here as standing behavior, not per-task guidance.
Commit atomically immediately after each file edit rather than accumulating changes across edits.
Commit incremental and experimental work as it happens — a commit's existence never implies the work it captures is finished.
Never rewrite, squash, or amend existing commit history on your own initiative; only do so on explicit instruction.
