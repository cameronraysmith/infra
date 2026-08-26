## ADDED Requirements

### Requirement: Activation requires explicit permission

An agent MUST NOT run system activation unless given explicit permission to do so.
Before asking the human operator to run activation, the agent MUST record the current `/nix/var/nix/profiles/system` link and its resolved store path.
This requirement and `Post-activation confirmation gate` below claim nothing broader than activation and post-activation probing.

#### Scenario: Activation is proposed without explicit permission

- **WHEN** an agent has not been given explicit permission to run system activation
- **THEN** the agent does not run activation, and instead records the complete, nonempty single-line outputs of `readlink /nix/var/nix/profiles/system` and `readlink -f /nix/var/nix/profiles/system` before asking the human operator to run it

### Requirement: Post-activation confirmation gate

An agent MUST NOT begin any post-activation live-state probe until the human operator explicitly confirms that the activation succeeded.

#### Scenario: Activation success is unconfirmed

- **WHEN** the human operator has not explicitly confirmed that activation succeeded
- **THEN** the agent runs no live-state probe, and no post-activation task is marked complete

---

## MODIFIED Requirements

### Requirement: Rollback preservation

After activation, `/nix/var/nix/profiles/system` MUST point to the new active `system-N-link`, and the immediately previous generation `system-(N-1)-link` MUST remain present and resolvable for rollback.

#### Scenario: Activated system profile is inspected

- **WHEN** the nix-darwin system profile links are queried after activation
- **THEN** the active link resolves to a `system-N-link`, and the immediately previous `system-(N-1)-link` remains present and resolvable for rollback

---

## REMOVED Requirements

### Requirement: Stale Pi version cleanup

**Reason**: This was a one-time task, not a standing system property: it directed removal of active Pi 0.83 references from two named files while preserving Pi 0.84.1. That task is complete, and the version pin itself is already covered by the standing `Nix-owned Pi resources` requirement, which asserts the system obtains Pi 0.84.1 from Nix.

**Migration**: None needed. The archived change `2026-08-15-configure-pi-agent-environment` carries this requirement verbatim at `openspec/changes/archive/2026-08-15-configure-pi-agent-environment/specs/pi-agent-environment/spec.md:205-212`, with its design row at that change's `design.md:183`, task mapping at `tasks.md:54-55`, and verify coverage at `verify.md:122` naming the standing check locations (`modules/checks/pi-agent-environment.nix:2382-2383,2427-2429`) for anyone who needs the historical record.

### Requirement: Human-only activation

**Reason**: This requirement constrained "Implementation" — the archived change's own implementing agent, in that one episode — and named a specific human ("Cameron") and a specific command (`just activate --ask`), rather than stating the standing policy generically. It fails the corpus's durability test even though the underlying policy is real and still in force.

**Migration**: Replaced by `Activation requires explicit permission` above, which restates the same standing policy — no activation without explicit permission, record profile state before asking — generically, using the user's own verbatim policy wording, with the permission carve-out intact.

### Requirement: Confirmation-gated live verification

**Reason**: Same defect as `Human-only activation`: constrained post-activation verification to remain blocked until a specific named human confirms, rather than stating the standing policy generically.

**Migration**: Replaced by `Post-activation confirmation gate` above, restating the identical policy — no post-activation probe before explicit confirmation — generically.
