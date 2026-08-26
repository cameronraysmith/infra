<!--
Raw capture of superpowers:brainstorming output.

This file captures the output of the brainstorming skill verbatim; it does not impose any structure.
The skill's natural output is usually a decision-log format (background → decision chain Q1-Qn → design trade-offs),
but the organization may vary depending on the conversation.

design.md is extracted from this file and reorganized into a structured design document.

Do not copy this file's content into design.md — design.md is an independent, reorganized artifact;
the two are complementary but do not overlap.
-->

## Fallback notice

`superpowers:brainstorming` runs as an interactive Q&A loop with a human.
This change was authored by a subagent operating from a fully specified assignment, with no interactive
user available during authoring.
Per this schema's own documented fallback ("or that they can explicitly opt to write brainstorm.md
manually using the template below"), this file is a manual decision-log capture in the skill's natural
format, reconstructed from the research performed before writing any planning artifact.

## Background

`packages/docs/src/content/docs/development/traceability/satisfaction.md` is regenerated wholesale at
archive time from the OpenSpec corpus.
It reports, per requirement, whether that requirement is discharged — the `W ∧ S ⇒ R` obligation from
`stratified-change-authoring` and `requirements-stratification`.

Reading the current projection (`generated: 2026-08-25`) and its stated inputs:

- 68 requirements, 9 discharged, 10 partially discharged, 49 undischarged.
- Every `Under (W)` cell is empty (no `world-assumptions` capability exists yet — a separate, in-flight
  change, `extract-world-assumptions`, is addressing that gap; this change does not touch it).
- Of the 19 rows that carry any `Discharged by (S)` text at all, the text is one of two fixed phrases:
  `skill-corpus-interface: resolvability, trigger surface` (10 rows, verbatim, across two different
  capabilities' requirements) and `own interface properties` (9 rows, verbatim, across two different
  capabilities' requirements).

Reading `openspec/specs/*/spec.md` for the requirements those rows claim to discharge — none of them
contain any per-requirement annotation naming a check, a test, a scenario, a proof obligation, or a
manual inspection.
The two fixed phrases are not references to anything in the corpus; they are the archiving agent's own
capability-level gloss, repeated identically because there was nothing more specific to read.

Reading `modules/home/ai/openspec/assets/schemas/superpowers-bridge-wrspm/schema.yaml` (the schema
source; delivered to `~/.local/share/openspec/schemas/` on activation, referenced in `openspec/config.yaml`
as `schema: superpowers-bridge-wrspm`): the archive step's instruction (`apply.instruction`, step 5) says
the projection's `Discharged by (S)` column should name "at least one interface property," and `verify`'s
§8b instruction says the same, but neither points the agent at anything in the requirement's own text to
read that name from.
The generator — an agent, not a script, since this schema has no script step for the projection — has to
invent a plausible-sounding justification at archive time, which is exactly how the two fixed phrases
came to exist.

## Q1: Is the fix "make the generator try harder" or "give the generator something to read"?

Decision: give the generator something to read.
A better prompt for the archive-time agent does not change that the input is empty; it only changes how
convincing the fabricated justification looks.
The fix has to be upstream — a place in the corpus itself where discharge evidence is recorded, so a
later read (by an agent or, eventually, a script) has a concrete string to copy rather than a capability
name to free-associate from.

## Q2: Where does that evidence live — frontmatter, a sibling file, or inline in the requirement body?

Decision: inline in the requirement's own body text, as a `**label**:` line.

Considered and rejected:
- Frontmatter (YAML key on the spec file): rejected because it can only attach to a whole spec file, not
  to one requirement among several in that file, and because the corpus is read by both agents and
  humans as prose — a requirement's discharge evidence should be visible in the same place a human
  reading that requirement would look, not in a machine-only header.
- A sibling file (e.g. `discharge.yaml` next to `spec.md`, keyed by requirement name): rejected because
  it reintroduces exactly the two-artifacts-that-can-drift problem the existing "regenerate wholesale,
  never patch" discipline for `satisfaction.md` exists to prevent, one layer earlier — a requirement
  renamed in `spec.md` silently orphans its sibling-file entry with no structural check catching it.
- A new `#### Discharge:` level-4 header, parallel to `#### Scenario:`: investigated by reading the
  OpenSpec CLI's parser (`requirement-text.js`, `requirement-blocks.js`) directly. `SCENARIO_HEADER` is
  `/^####\s+/` — it matches *any* level-4 header, not only ones literally labeled `Scenario:`, and both
  `countScenarios` (used by the "at least one scenario" check) and `parseScenarioBlocks` (used by the
  MODIFIED-requirement scenario-loss check, which is a blocking ERROR) treat every `####` child as a
  scenario. A `#### Discharge:` header would therefore inflate the scenario count and would need its
  name preserved verbatim on every future MODIFIED of that requirement or `openspec validate` would
  report a scenario loss ERROR. Rejected: it works, but only by accident, by pretending to be a scenario
  the tooling never sees.
- A `**Discharged by**:` metadata line inside the requirement body, before the first `#### Scenario:`:
  accepted. The parser already has a named, load-bearing construct for exactly this shape —
  `METADATA_LINE = /^\*\*[^*]+\*\*:/`  in `requirement-text.js`, the same pattern the existing corpus
  already uses for lines like `**ID**:` / `**Priority**:`. A metadata line is captured separately from
  the requirement's descriptive prose and is invisible to `countScenarios` (it is not a header) and to
  the scenario-loss check (same reason), so it cannot inflate or corrupt either structural check. It
  reads naturally as prose, greps cleanly (`grep -r '\*\*Discharged by\*\*:' openspec/specs/`), and reuses
  a convention the corpus and its tooling already recognize rather than inventing a new one.

## Q3: Should the annotation distinguish discharge kinds — a test-name field, a scenario-ref field, a proof-obligation field, a manual-inspection field?

Decision: no. One free-text form, one label, capable of naming any of the four kinds the assignment
names (a check or test name, a scenario reference, a proof obligation, or a dated manual inspection).
The distinguishing information is in the *content* of the named artifact (its own name usually makes its
kind obvious — a test name looks like a test name, a date makes a manual inspection self-evident), not
in which of four fields it was typed into. Four fields is a taxonomy; a taxonomy is explicitly the
failure mode the assignment calls out, and it buys nothing a human or an agent reading the value cannot
already tell from the value itself.

## Q4: Does the annotation need to be mandatory to close the gap?

Decision: no, optional. A requirement genuinely has no discharge evidence yet for 49 of 68 rows in the
current corpus — making the annotation mandatory would force either a fabricated value (recreating the
exact staleness problem this change exists to fix) or a blocking validation error on every currently
undischarged requirement, which is not this change's job to resolve. Absence must remain the honest
default and must continue to render as `undischarged`, exactly as the existing "Archive step regenerates
the satisfaction projection" requirement already specifies for the no-evidence case.

## Q5: Does the annotation need machine enforcement against "bare assertions" (e.g. a line that just says "discharged", naming nothing)?

Decision: no new machine check. `openspec validate` checks markdown structure and delta well-formedness
only — it has never checked content semantics, and `verify`'s existing §8 checks (designation lint,
discharge coherence, alphabet check) are already documented as agent-executed and non-blocking, for the
same reason: no vocabulary grounding or entailment check exists in the CLI to hook into. The discipline
against bare assertions belongs in the same place the discipline against bare "own interface properties"
already lives — the requirement text itself, read by the same agent that already reads §8b and the
archive step. This change writes that discipline into the requirement text (a scenario naming the bare-
assertion case explicitly, so an agent following it is told, not left to infer, that a valueless
assertion is equivalent to no annotation).

## Q6: Which capability owns this delta?

Decision: `stratified-change-authoring`. Read all nine `openspec/specs/*/spec.md` files. Two candidates:

- `stratified-change-authoring` — its own spec purpose line reads "created by archiving change
  stratify-change-write-path," and its existing requirements already govern exactly this territory: the
  `specs` artifact's format rules, the `verify` artifact's §8 (including the discharge-coherence table
  this change extends), and the archive step's projection rebuild (the exact generator this change gives
  something to read). Every requirement in this capability is tagged `interface` in the existing
  projection ("discharged directly against the schema and config artifacts it constrains") — consistent
  with a schema/write-path convention rather than a runtime behavior.
- `requirements-stratification` — owns the general reasoning discipline ("Discharge of a requirement is
  stated, not implied": an agent MUST be able to name what discharges a requirement or record it
  undischarged). Close, but this requirement is about an agent's judgment process, not about where in
  the corpus that judgment gets written down. Adding the annotation syntax here would conflate "how an
  agent reasons about discharge" with "what markdown construct records the reasoning's output" — the
  second belongs with the other write-path mechanics (proposal's stratum tag, specs' vocabulary rules,
  verify's §8, archive's rebuild), all of which already live in `stratified-change-authoring`.

Rejected: `requirements-stratification`, for the reason above. Accepted: `stratified-change-authoring`,
because the assignment's own framing — "the delta specs belong to whichever existing capability owns the
change write path" — names exactly what this capability's own purpose line says it is.

## Q7: Does this authoring pass edit the schema (`schema.yaml`) or the archive-step instruction itself?

Decision: no. Both live in `modules/home/ai/openspec/assets/schemas/superpowers-bridge-wrspm/schema.yaml`,
delivered to `~/.local/share/openspec/schemas/` on activation and referenced by every in-flight change's
`.openspec.yaml` pinning `schemaName: superpowers-bridge-wrspm`. At least one other change is actively
running against that pinned schema right now; editing the schema file mid-flight would change the
instructions that in-flight agent is reading out from under it. This authoring pass is planning-only: it
specifies what the schema's `specs`, `verify`, and archive instructions should say once the schema *can*
be edited (recorded in `design.md` and `tasks.md`), and does not perform that edit.

## Agreed direction

Add one optional, per-requirement `**Discharged by**:` metadata line, written inline in the requirement's
own body before its first `#### Scenario:`, naming the concrete artifact (check/test name, scenario
reference, proof obligation, or dated manual inspection) that discharges it. Absence renders
`undischarged`. One free-text form, no per-kind taxonomy. Owned by `stratified-change-authoring` as a
MODIFIED extension of its existing `specs`, `verify`, and archive requirements, plus one ADDED
requirement stating the annotation's own contract. The schema file itself and the archive-step generator
prompt are not edited in this pass — both are recorded as deferred implementation work with the pinning
reason stated.
