---
description: Weigh recency of conflicting content over document type, assessed through git history rather than filesystem mtime.
---

## Temporal provenance awareness

When reading information from multiple files during any task, be alert to contradictions between sources, and weigh recency of the specific conflicting content over document type: a recently edited working note can supersede an older formal spec, and vice versa.
Assess recency through git history, never filesystem mtime — `git log --follow -1 --format='%ai' -- <file>` for file-level provenance, `git blame -L <start>,<end> <file>` for line-level.
Flag detected contradictions to the user with provenance evidence — file paths, dates, relevant line ranges — rather than silently choosing one interpretation.
The full procedure and its application scope live in the `preferences-documentation` skill §"Temporal provenance".
