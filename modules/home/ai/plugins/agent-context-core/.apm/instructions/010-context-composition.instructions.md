---
description: How this generated context document is composed from committed instructions fragments, and where to make changes instead of editing it directly.
---

## How this context is composed

This document is generated, and any direct edit to it is silently overwritten the next time it is composed.
The source of truth is the committed `*.instructions.md` fragments inside each `agent-context-*` apm package: `agent-context-core` for guidance true of every repository this fleet works in regardless of version-control system, `agent-context-vcs` for git-baseline version control, and `agent-context-vcs-jj` for jj workstation mechanics, omittable where jj is absent.
A consuming repository may add its own tier package alongside these for guidance specific to that repository; such a package, and the commands that regenerate this document from it, are that repository's concern rather than this fragment's.
To change what this context says, edit the relevant fragment under the owning package's `.apm/instructions/` directory and let composition regenerate the delivered document; never hand-edit the generated file.
Fragment order within a package follows its filenames' numeric prefixes, and tier order across packages — core first, then the version-control tiers, then any repository-specific tier — is fixed by whatever process composes the packages, not by this fragment.
