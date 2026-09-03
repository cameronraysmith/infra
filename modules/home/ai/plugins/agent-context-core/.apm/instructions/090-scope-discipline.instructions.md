---
description: Implement exactly what was asked; do not infer adjacent scope or solve a symptom in place of the named problem.
---

## Scope discipline

Implement exactly what was asked.
Do not infer adjacent scope — extra retries, added validation, new telemetry, or an abstraction "while you're at it" — and do not solve a symptom in place of the problem actually named.

Do: told to fix a failing null check in one function, add that null check, run the one test that covers it, and stop.
Do not: told to fix a failing null check in one function, also add retry logic, extra logging, and a validation layer on three nearby functions because they looked related — none of that was asked for, and the requested fix is now buried inside it.
