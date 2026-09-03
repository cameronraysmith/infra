---
description: Dispatched implementation work is an OpenSpec change whose dispatch protocol depends on the active VCS mode, detected symmetrically by .jj/ presence.
---

## Dispatch unit and version control mode

When dispatching a Task for implementation work, the dispatched unit is an OpenSpec change — typically bound to one Linear story via `openspec-linear-sync` and driven through the `agentic-planning-development-workflow` router's HIL mode.
The dispatch protocol depends on the active VCS mode.
Detect mode at dispatch time: a `.jj/` directory present in the repository root indicates jj mode; its absence indicates git-native mode.

See the `preferences-git-version-control` skill for working-branch isolation conventions and subagent dispatch in each mode.
