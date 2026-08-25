## Context

The goal is to adopt a meta-requirements framework for formal-verification-driven development: WRSPM
(Gunter–Gunter–Jackson–Zave) as the ontology, with assume-guarantee contracts supplying the
composition algebra across heterogeneous verification tools, institution theory supplying
logic-independence, KAOS goal-obstacle analysis governing the layer above requirements, and AMDiRE as
the artifact-organizational macro-form. The two obligations are `W ∧ S ⇒ R` (the satisfaction
argument) and `P ⇒ S` (refinement). The full specification lives in
`docs/notes/development/methodology/meta-requirements-framework-integration.md`; this design
document, and `brainstorm.md`, are its decision record, not a second copy of it.

The predecessor on disk is
`docs/notes/development/methodology/acceptance-to-proof-co-optimization.md`, which already models
this territory as a closure operator over a Galois connection. This framework names the layer that
note left implicit: the requirements side of the connection.

This change is the first of three and carries only the write path — the schema and project config.
It runs under schema v1 because it authors v2, and nothing can author itself.

## Goals / Non-Goals

**Goals:**
- Give an author a stratum tag (`world`/`interface`/`behavioral`) to attach to each capability, and
  stratum-conditional vocabulary rules that make the distinction machine-legible during authoring.
- Add non-blocking, agent-executed checks (designation lint, discharge coherence, alphabet check) at
  verify time, so the stratum discipline is checkable rather than purely advisory.
- Correct the schema bundle's actual provenance and ownership so future edits target the right tree.
- Land as a change that dogfoods the schema it authors, under `openspec validate`.

**Non-Goals:**
- This change does not populate `specs/world-assumptions/` or any designation table — that is
  deferred, and section 8 is expected to report the absence rather than a clean pass (see
  Falsification criteria in brainstorm.md).
- This change does not touch the skills corpus or the routing between skills and this schema; that is
  the second and third changes in the three-change sequence.
- This change does not attempt mechanical verification of vocabulary grounding, alphabet discipline,
  or entailment. `openspec validate` checks markdown structure and delta well-formedness only.

## Decisions

### D1: One framework, checkable because its meta-requirements are entailment obligations

**Choice**: Adopt WRSPM as five artifacts (W, R, S, P, M) with two entailment obligations (`W ∧ S ⇒
R`, `P ⇒ S`), plus three logic-agnostic supplements (assume-guarantee contracts, institution theory,
KAOS) and one artifact-organizational macro-form (AMDiRE).
**Rationale**: the decisive property is that the framework's meta-requirements are entailment
obligations rather than stylistic advice, which is what makes them checkable at all — a
non-entailment framework would give this change nothing to attach a lint to.
**Alternatives considered**: none evaluated as seriously — a search across all 133 first-party skills
for the framework's vocabulary (`WRSPM`, `Zave`, `satisfaction argument`, `designation`, `indicative`,
`optative`, `shared phenomena`, `assume-guarantee`, `institution`, `KAOS`, `Parnas`, `four-variable`)
returned nothing, so there was no competing in-repo convention to reconcile against.

### D2: Fork the schema bundle rather than edit the parent in place

**Choice**: Fork `superpowers-bridge` to a new first-party tree,
`modules/home/ai/openspec/schemas/superpowers-bridge-wrspm/`, rather than editing the parent bundle.
**Rationale**: a change records its schema in its own `.openspec.yaml` at creation time and is never
repinned. Editing the parent in place would retroactively change the governing schema under every
change already pinned to it — four in-flight changes, at the time of this change, remain pinned to
`superpowers-bridge`. This crosses the vendored-versus-first-party boundary indirectly: the fork
target and the parent are both first-party (neither carries `generatedBy` frontmatter, neither is
under a path this project treats as vendored), so the fork decision is about the schema-pin hazard,
not about vendored-versus-first-party ownership.

**A correction recorded here rather than smoothed over**: the first attempt at this work justified
forking on the belief that the parent bundle was vendored third-party content and had to stay
pristine. That belief was wrong — the parent had already diverged from upstream `github.com/JiangWay/
openspec-schemas` by +79/−29 lines in `schema.yaml` and was itself a first-party fork under the
`assets/` name, not a mirror. The fork decision is still correct, but for the schema-pin reason above,
not the vendoring reason first given. The three READMEs under `modules/home/ai/openspec/` are
corrected accordingly.
**Alternatives considered**: editing the parent in place (rejected — breaks the four in-flight
changes pinned to it); symlinking the parent and layering WRSPM via override (rejected — OpenSpec
schemas are single YAML files with inline instruction text; there is no override mechanism, so a
symlink cannot add a stratum layer without editing the target).

### D3: Deliver both schema bundles via `schemaDirs`, not a single `schemaDir`

**Choice**: Convert `modules/home/ai/openspec/default.nix`'s `schemaDir` option (single path) to
`schemaDirs` (`attrsOf path`), keyed by bundle name, delivering both `superpowers-bridge` and
`superpowers-bridge-wrspm` as separate directory symlinks under
`~/.local/share/openspec/schemas/<name>`.
**Rationale**: this is the source-versus-delivered boundary. The source is the two first-party trees
(`assets/schemas/superpowers-bridge`, frozen, and `schemas/superpowers-bridge-wrspm`, live); the
delivered artifact is the set of directory symlinks OpenSpec's resolver reads. Since a change's schema
pin is never repinned, withdrawing a bundle from delivery strands every change already pinned to it
with an unresolvable schema and no diagnostic beyond the `schema=` attribute of `openspec
instructions` output. Delivering both keeps every existing pin resolvable.
**Alternatives considered**: deliver only the new bundle and require the four in-flight
`superpowers-bridge`-pinned changes to be repinned or archived first (rejected — repinning a change
mid-flight to a schema it wasn't authored against is a bigger and riskier edit than delivering one
more symlink).

### D4: Project-tier symlink, not an activation cycle, for local schema resolution

**Choice**: Resolve this repository's own schema from its own tree via a whole-directory symlink at
`openspec/schemas/superpowers-bridge-wrspm`, reported by the CLI as `Source: project`, rather than
requiring a nix activation cycle before the fork is usable.
**Rationale**: `openspec schema fork` is unusable against a nix-store source — it copies mode-444
files while preserving permissions, so its own staging temp file is unwritable and the fork aborts
with `EACCES`. This crosses the source-versus-delivered boundary: nix activation is the delivery
mechanism for the general (any-machine) case, but this repository owns the schema source, so
resolving it from the source tree directly removes activation lag entirely and makes testing a stale
delivered copy impossible during this change's own dogfood cycle. The symlink is deliberately
permanent, not a temporary bypass.
**Alternatives considered**: run `nix build`/home-manager activation before every schema edit
(rejected — activation lag would make iterative dogfooding of the schema itself impractical, and the
brainstorm's Q7 explicitly asks whether a mid-flight activation cycle is required and answers no).

### D5: Author v2 first, dogfood before broader specification

**Choice**: Author this change (the schema and project config) under schema v1, before writing the
skills change or the routing change that will run under v2.
**Rationale**: the schema is the only mechanically enforced artifact in the three-change plan — the
`requires[]` DAG, output containment, and the delta grammar are enforced by code, while everything
else (skill content, routing prose) is prompt-ware that degrades silently. Sequencing the schema first
means the two downstream changes dogfood a schema that has already validated itself, rather than
authoring against an unverified target.
**Alternatives considered**: specify all three changes' content before touching the schema (rejected
— defers the one mechanically-checked artifact past the point where its defects are cheapest to find).

### D6: Fifth framework edit — per-task discharge convention in `tasks.md`

**Choice**: Add the `— verify: <...>` convention to `templates/tasks.md` and the `tasks` instruction,
and rename the closing task group to `## Integration Verification`.
**Rationale**: regenerating the vendored `openspec-*` skills (unrelated maintenance, confirmed
separately) surfaced that upstream `openspec-schemas`'s own tasks template had independently converged
on per-task verification evidence with the same rename. That is discharge coherence at task
granularity — the same principle section 8 applies to specs, arrived at independently upstream. It
does not reach this schema automatically because this bundle ships its own bare `templates/tasks.md`
rather than inheriting upstream's, so it is applied here as a fifth, deliberate framework edit rather
than an upstream merge.
**Alternatives considered**: wait for a future bundle sync to pick this up (rejected — the schema
already required a `tasks.md` review pass for the stratum work, and the convention pays for itself
immediately at this change's own `tasks.md` and `verify.md` §2).

### D7: Populate `openspec/config.yaml`'s `context`, `rules`, and `operations.archive.guidance`

**Choice**: Fill in all three previously-empty project-config surfaces: `context` (the two
load-bearing boundaries, jj discipline, schema resolution path, and the `rules.tasks` dead-letter
explanation), `rules` for `proposal`/`specs`/`design`/`verify`, and `operations.archive.guidance` for
the satisfaction-projection rebuild.
**Rationale**: these are the only channel this schema exposes for project-specific instruction
injection (verified by reading `openspec instructions <artifact> --json` output, which shows
`context` and `rules` merged into the rendered instruction). Without them, every artifact's rendered
instruction would carry only the generic schema text, with no project-specific vocabulary discipline
or boundary guidance.
**Alternatives considered**: `rules.tasks` for the nix-verification guidance (rejected — confirmed
that OpenSpec 1.10.0 silently drops `rules` keyed to the `tasks` artifact; `openspec instructions
tasks --change <c> --json` carries no `rules` key at all while sibling artifacts carry theirs, with no
warning. The guidance was rerouted into `context`, which is not artifact-scoped and does render for
every artifact including `tasks`).

### D8: Remove the three dead `workspace-planning` guards; bump the declared baseline

**Choice**: Remove `actionContext.mode == "workspace-planning"` preconditions from the apply, verify,
and retrospective entry points in the wrspm fork (they remain, unremoved, in the frozen
`superpowers-bridge` parent), and bump the schema's declared OpenSpec baseline from `1.4.1` to
`1.10.0`.
**Rationale**: confirmed across four surfaces that the toolchain is actually at 1.10.0 — the CLI on
PATH, the flake-pinned version the refresh app injects, the regenerated vendored `openspec-*` skills
(`generatedBy: 1.10.0`), and the status JSON contract these guards read. That contract is intact on
1.10.0, so the guards are unreachable dead code rather than a live correctness defect; removing them
is cleanup, not a behavior fix.
**Alternatives considered**: leave the guards in place as defensive dead code (rejected — they were
added by the earlier fork alongside CLI-resolved artifact paths for a precondition that never
materializes on any confirmed-live toolchain surface; keeping unreachable guards contradicts the
comment-cleanup discipline this repository applies elsewhere).

## Risks / Trade-offs

[Trade-off] Section 8 (designation lint, discharge coherence, alphabet check) is agent-executed and
non-blocking → accepted because `openspec validate`'s delta grammar has no mechanism to check
vocabulary grounding, alphabet discipline, or entailment; a warn-and-record check is the available
alternative to no check at all, and is documented explicitly as buying structure and instruction, not
verification.

[Risk] A change's schema pin in `.openspec.yaml` is captured at creation and never updated when the
project's default schema is renamed, and the mismatch surfaces nowhere except the `schema=` attribute
of `openspec instructions` output → Mitigation: `schemaDirs` delivers every bundle any in-flight
change is pinned to, so a stale pin still resolves; there is no mitigation yet for the silent-mismatch
diagnostic gap itself, which is recorded as a known defect for a future schema-tooling change rather
than solved here.

[Risk] `openspec schema fork` aborts with `EACCES` against a read-only (nix-store) source tree →
Mitigation: this repository resolves its schema from its own writable tree via a project-tier
symlink instead of running `schema fork` against the delivered copy; the upstream defect itself is
unfixed and out of scope.

[Trade-off] Five changes are already in flight, two of which carry artifact drift → this change lands
alone rather than concurrently with the skills change and the routing change, deferring further
dogfooding until this write-path schema has validated itself in isolation.

## Migration Plan

No deployment or activation step is required for this repository: the project-tier symlink at
`openspec/schemas/superpowers-bridge-wrspm` makes the fork live immediately. `schemaDirs` on
`modules/home/ai/openspec/default.nix` takes effect for other machines on their next home-manager
activation, at which point both bundles become available under
`~/.local/share/openspec/schemas/<name>`; no existing pinned change requires action, because both
bundle names it could be pinned to remain deliverable. Rollback, if ever needed, is deleting the
`superpowers-bridge-wrspm` bundle and the `schemaDirs` entry that points to it — every change
currently pinned to `superpowers-bridge` is unaffected, and the two changes pinned to
`superpowers-bridge-wrspm` (this one and `requirements-engineering-skills`) would need to be
repinned or archived first.

## Open Questions

The Linear project binding: no existing project fits this work. The proposed key and name are
`satisfaction-argument` / "Ground requirements in a maintained satisfaction argument". Creating it is
an external artifact requiring explicit approval, so this change proceeds locally and Linear catches
up in a single transition via catch-up reconciliation.

Whether the schema-pin silent-mismatch defect (no diagnostic when a project's default schema is
renamed out from under a pinned change, beyond the `schema=` attribute of `openspec instructions`
output) warrants an upstream OpenSpec issue or a wrapper-level check is left for a future change.
