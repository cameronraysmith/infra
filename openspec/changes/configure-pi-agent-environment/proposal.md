---
linear_story_id: daaea691-9e59-4cba-a99d-0df1e0236b4a
linear_story_identifier: CAM-33
linear_story_title: "Configure the Nix-first Pi agent environment"
linear_story_url: https://linear.app/cameronraysmith/issue/CAM-33/configure-the-nix-first-pi-agent-environment
linear_story_state: In Progress
linear_team: CAM
linear_project: pi-agent-environment
last_synced_state: In Progress
last_synced_at: 2026-08-15T00:49:02Z
review_round: 0
max_review_rounds: 3
attempt_log:
  - { at: "2026-08-13T21:37:14Z", transition: "Backlog->Todo", outcome: "posted", note: "proposal bind; existing business-facing description already current; canonical crossing comment posted" }
  - { at: "2026-08-15T00:49:02Z", transition: "Todo->In Progress", outcome: "posted", note: "first tasks.md checkbox completed; canonical crossing comment posted" }
---

## Why

Pi currently receives its executable and one extension from Nix, but its selected user-interface extensions, theme, and harness-neutral safety boundaries are not yet reproducible as one reviewed environment.
Moving executable resources and policy baselines under Nix and Home Manager makes the environment auditable while preserving Pi-managed runtime state without claiming global exclusivity over every possible path.

## What Changes

**Extension resources**
- From: Pi loads the `llm-agents` executable and `pi-openai-server-compaction`, while other extension resources remain unmanaged.
- To: Nix adds one source-only `pi-agent-extensions` package at an exact commit and hash, rejects `node_modules`, and Home Manager loads exactly six positive extension paths while explicitly excluding `fetch` and `notify`.
- Reason: Source identity and enabled resources must be reproducible and reviewable.
- Impact: Additive and operator-gated; the existing compaction extension remains enabled, the existing ordinary package map remains unmodified, package realization rejects `node_modules`, and a pre-activation diff scan proves exactly one new by-name package with no flake input.

**Safety policy and presentation**
- From: Pi uses the built-in dark theme and does not carry the approved shell, edit, Git default-branch, typed jj-repository, or package-mutation boundaries.
- To: Pi uses the pinned Catppuccin Mocha theme, the pinned permission-gate parser and project-trust boundary, Nix-owned shell rules, and a compact first-party pure decision core with a thin Pi adapter for non-Bash edit and write calls; healthy ordinary and diamond-managed jj repositories are eligible under distinct predicates.
- Reason: Policy should preserve harness-neutral invariants through Pi-native surfaces without duplicating permission-gate parsing.
- Impact: Parser, ambiguity, capability, and headless failures fail closed; pure-core rows run without one Pi process per case, and the exported Pi adapter seam is executed directly for translation, pass-through, malformed-input, and exception cases.

**Assurance and rollout**
- From: The mutable settings seed and retained runtime state exist without the complete resource and policy assurance model.
- To: One ordinary flake-parts logical-group module exposes exactly three independent derivations with separated inputs and cache boundaries: structural, policy, and smoke; the structural oracle includes evaluated Pi package version `0.84.1`, and the smoke uses an explicit registered model identifier, closes stdin, and requires clean process exit.
- Reason: Assurance should target distinct failure modes without proliferating checks or conflating physical co-location with a monolithic check.
- Impact: Discovery empirically characterized the exact installed/deployed Pi 0.84.1 wrapper from the current locked package in a disposable `HOME`: credential-free `review-local/review-model` used inert base URL `http://127.0.0.1:9/v1`, API `openai-completions`, no `apiKey`, `get_state` returned that model, no prompt or provider request occurred, and stdin closure exited zero.
  The smoke must reproduce that behavior at assertion level inside its hermetic derivation without hardcoding the discovered Nix store hash; any difference stops implementation for a question.
  Activation remains a human-only effect with rollback preservation.

## Capabilities

### New Capabilities

- `pi-agent-environment`: Reproducible Pi resource composition, Pi-native safety policy, secret-safe runtime boundaries, three independent regulators, and operator-gated rollout.

### Modified Capabilities

No existing OpenSpec capability requirements are modified.

## Impact

The change adds exactly one new by-name package, `pkgs/by-name/pi-agent-extensions/package.nix`.
It adds first-party Pi theme and policy resources under `modules/home/ai/pi/`, adds one ordinary logical-group check module at `modules/checks/pi-agent-environment.nix`, and modifies `modules/home/ai/pi/default.nix` plus the stale Pi-version reconnaissance note.
Within Pi-managed paths, Home Manager preserves the installed mutable `settings.json` copy and does not convert runtime-managed settings, sessions, compaction, authentication, project trust, model selection, thinking preferences, or extension state into immutable executable-resource links.
Executable policy, theme, extensions, and global instructions remain immutable; this boundary does not claim to enumerate every possible Pi runtime path.
It does not modify `modules/checks/packages.nix`, whose existing auto-map supplies `package-pi-agent-extensions` coverage.
It adds no `modules/checks/fixtures` directory or fixture file, flake input, aggregate Pi package, standalone theme package, Pi-specific skill sink, secret-bearing store content, or Herdr package or configuration change.
The existing Herdr environment continues to provide external delegation unchanged and outside this change.
Integration of `nicobailon/pi-subagents` is an explicit non-goal and may be reconsidered in a separate future change when upstream public seams warrant it; this deferral is not a general safety judgment about upstream.
