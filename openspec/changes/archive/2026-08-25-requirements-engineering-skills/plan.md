# WRSPM requirements-engineering skills implementation plan

> **For agentic workers:** This plan was written after implementation, documenting the micro-steps
> actually taken across the commit range `804f0880d2bb..86f948422d74`, because `superpowers:writing-plans`
> was not invoked live during this cycle (see `retrospective.md` §4 for the skipped-skill accounting).
> It is retained in the schema-required `plan.md` shape rather than a narrative summary so the
> task/plan/verify chain stays mechanically checkable.

**Goal:** Give the agent instruction corpus a home for the `W ∧ S ⇒ R` satisfaction-argument obligation, paired with the operational audit that checks it, and wire every existing owner-adjacent skill and the generated agent context to the two new owners.

**Architecture:** Two new first-party skills under `formal-specification-and-refinement/.apm/skills/` (a conceptual `preferences-*` hub and a bare-named operational sibling, the corpus's standard pairing shape); two new reference files under `preferences-theoretical-foundations/references/`; one new disambiguation clause in `executable-specification-testing`; nine routing-edit files plus `agents-md.nix`; delivery through the existing `nix build .#apm-skills-compose` → `~/.claude/skills/` symlink path.

**Tech Stack:** Nix (flake-parts module composition, `apm-skills-compose` derivation), Markdown/YAML-frontmatter skill sources, the `superpowers-bridge-wrspm` OpenSpec schema for the planning-artifact chain.

---

## Task 1: Author `preferences-requirements-engineering`

- [x] **Step 1:** Draft frontmatter — `name`, and a `description` stating the pentad, the stratum-assignment triggers, and the deferrals to `refinement-driven-development`, `satisfaction-argument-audit`, `preferences-theoretical-foundations`, and `preferences-validation-assurance`. Commit: `804f0880d2bb`.
- [x] **Step 2:** Write the pentad section (`W`, `R`, `S`, `P`, `M`) and the two obligations with their alphabet side conditions.
- [x] **Step 3:** Write the four dark corners as checkable discipline, the designation table, obstacle analysis, and Parnas' four-variable model.
- [x] **Step 4:** Write the WRSPM-versus-AMDiRE shear section, naming the concrete consequence for this repository's own `docs/development/requirements/` tree.
- [x] **Step 5:** Write "What the evidence actually supports" with the vericoding calibration attributed as our own inference, not the paper's claim.
- [x] **Step 6:** Write Scope and See also sections with mutually exclusive trigger boundaries against the other four owner skills.

## Task 2: Author `satisfaction-argument-audit`

- [x] **Step 1:** Draft frontmatter — `description` naming the three-gate chain, the milestone-not-inner-loop trigger, and the pointer up to `preferences-requirements-engineering`. Commit: `95f23a5ab33e`.
- [x] **Step 2:** Write the three gates (program-satisfies-spec, spec-satisfies-intent by blind informalization, milestone audit), each with its own run cadence stated explicitly.
- [x] **Step 3:** Write the blind-informalization procedure with its four verdicts and three operational rules (direction, caching, no-exit-code-gating).
- [x] **Step 4:** Write the trust-surface inventory generalized per institution (Lean/Rust/Dafny/Verus), pointing to `preferences-essential-complexity` for the sorry-debt discipline it generalizes rather than restating it.
- [x] **Step 5:** Write the claims status table with satisfiability, non-vacuity, and co-vacuity checks, citing `bdd-gherkin-formulation`'s independent-literal-oracle rule as the sibling check.
- [x] **Step 6:** Write safe external wording and the absolute never-claim-end-to-end prohibition, stated in both a promise-section and boundary-section form.
- [x] **Step 7:** Write the "Where the audit runs in our workflow" section distinguishing this skill's gate three from the schema's per-change section 8.

## Task 3: Extend theoretical-foundations and the contract-senses passage

- [x] **Step 1:** Write `references/institution-theory.md` — signatures, sentences, models, the satisfaction condition, refinement as theory interpretation. Commit: `0c08eaace52a`.
- [x] **Step 2:** Write `references/assume-guarantee-contracts.md` — the `(A, G)` pair, refinement `⪰`, parallel composition `⊗`, conjunction `∧`.
- [x] **Step 3:** Update `preferences-theoretical-foundations`'s Rule 7 prose and reference-routing table to cite both new files.
- [x] **Step 4:** In `executable-specification-testing`, add the assume-guarantee sense to the contract disambiguation and correct "five" to "six" in both count-word occurrences.

## Task 4: Wire routing edits

- [x] **Step 1:** Edit `refinement-driven-development`, `preferences-compositional-continuous-verification`, `preferences-validation-assurance` to point to the new obligation owner. Commit: `d42961a35323`.
- [x] **Step 2:** Edit `preferences-documentation`'s AMDiRE-shear passage. Commit: `4fa43577ee2f`.
- [x] **Step 3:** Edit `openspec-bdd-bridge` and `atdd-outer-loop`'s stratum-verdict and spec-leakage sections. Commit: `4b18b32fc343`.
- [x] **Step 4:** Edit `preferences-discovery-process`, `ubiquitous-language`, `nucleus-platform`. Commit: `677342616299`.
- [x] **Step 5:** Update `formal-specification-and-refinement`'s `apm.yml` and `plugin.json` descriptions. Landed alongside commit `95f23a5ab33e`.

## Task 5: Amend `agents-md.nix`

- [x] **Step 1:** Add the two skill-index entries with house-style glosses.
- [x] **Step 2:** Add the discharge-obligation sentence to the operating-principles section.
- [x] **Step 3:** Extend the compositional-architecture standard with the companion-obligation sentence and the never-claim-end-to-end prohibition.
- [x] **Step 4:** Adopt the four selected reference-prompt directives (no-flattery/challenge-directly, do/do-not scope example, long-running-command routing, compact non-omp scope rule) and reject the others per the design record's explicit rejections. Commit: `0235fd2c3b74`.
- [x] **Step 5:** Record the two harness hazards as a Nix comment and correct the `nix flake check` self-contradiction in the nix-development index gloss.
- [x] **Step 6:** Run `nix-instantiate --parse modules/home/tools/agents-md.nix` to confirm the file still parses.

## Task 6: Build, deliver, and verify activation

- [x] **Step 1:** `nix build .#apm-skills-compose --no-link --print-out-paths`.
- [x] **Step 2:** Count skills under `$out/.claude/skills` and confirm both new names present (177 total).
- [x] **Step 3:** Confirm `~/.claude/skills/preferences-requirements-engineering` and `~/.claude/skills/satisfaction-argument-audit` resolve as nix-store symlinks post-activation.

## Task 7: Correct the stratum tagging

- [x] **Step 1:** Run section 8's discharge-coherence check by hand against the original all-`behavioral` proposal, as the schema's verify instruction directs. Recorded in the design record's "Falsification criteria, and the first result" section.
- [x] **Step 2:** Author `specs/skill-corpus-interface/spec.md` with three ADDED requirements at the interface stratum, plus a Trust boundary section stating what those properties do not reach.
- [x] **Step 3:** Rewrite `proposal.md`'s Capabilities and stratum-tagging-note sections to record the correction and its cause, rather than silently retagging. Commit: `86f948422d74`.

## Task 8: Complete the planning-artifact chain (this pass)

- [x] **Step 1:** Write `design.md`, recording the interface-capability correction (D3) and the two-skills-not-one rationale (D1) as first-class decisions.
- [x] **Step 2:** Write `tasks.md` with every task checked and a `— verify:` clause naming a concrete check.
- [x] **Step 3:** Write this `plan.md` documenting the micro-steps actually executed.
- [x] **Step 4:** Write `verify.md` with all eight sections, including the section-8 designation lint, discharge table, and alphabet check.
- [x] **Step 5:** Write `retrospective.md` with evidence-first §0–§6, honestly accounting for which superpowers apply-phase skills were and were not used this cycle.
