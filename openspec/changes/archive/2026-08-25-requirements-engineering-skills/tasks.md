## 1. Author the requirements-engineering skill pair

- [x] 1.1 Create `preferences-requirements-engineering` as the conceptual hub, owning the WRSPM pentad, the two obligations and their alphabet side conditions, the four dark corners, the designation table, indicative/optative separation, KAOS obstacle analysis, Parnas' four-variable model, and the WRSPM-versus-AMDiRE shear — verify: `read modules/home/ai/plugins/formal-specification-and-refinement/.apm/skills/preferences-requirements-engineering/SKILL.md` shows all named sections present (lines 24–117); commit `804f0880d2bb` adds the 156-line file.
- [x] 1.2 Create `satisfaction-argument-audit` as the operational sibling, owning the three-gate chain generalized across institutions, blind informalization, the trust-surface inventory, the claims status table, and safe external wording with the never-claim-end-to-end prohibition — verify: `read` of the file shows all named sections present (lines 21–100); commit `95f23a5ab33e` adds the 123-line file.
- [x] 1.3 Host both skills in the `formal-specification-and-refinement` plugin group beside `refinement-driven-development` — verify: `glob modules/home/ai/plugins/formal-specification-and-refinement/.apm/skills/**` lists `preferences-requirements-engineering/SKILL.md` and `satisfaction-argument-audit/SKILL.md` alongside `refinement-driven-development/`.
- [x] 1.4 Keep both frontmatter descriptions within the harness's trigger-surface length limit — verify: YAML-parsed `description` length is 1015 characters (`preferences-requirements-engineering`) and 837 characters (`satisfaction-argument-audit`), both under the 1024-character limit.

## 2. Extend theoretical-foundations and the contract-senses disambiguation

- [x] 2.1 Add `references/institution-theory.md` and `references/assume-guarantee-contracts.md` to `preferences-theoretical-foundations` — verify: `glob` of the skill's `references/` directory lists both files (62 and 59 lines respectively per commit `0c08eaace52a`'s diffstat).
- [x] 2.2 Update `preferences-theoretical-foundations`'s frontmatter description and reference-routing table to cover institution theory and assume-guarantee contracts — verify: `read` of the SKILL.md shows Rule 7 citing both references (lines 30, 34) and the reference table carrying both rows (lines 75–76); YAML-parsed description length 1004 characters.
- [x] 2.3 Add the sixth "assume-guarantee contract" sense to `executable-specification-testing`'s contract disambiguation and correct the count words from five to six — verify: `grep` of the SKILL.md shows "none of the other six senses" (line 46) and "holding those six senses apart" (line 53), and the new clause naming `preferences-theoretical-foundations`'s Benveniste `(A, G)` sense (line 52).

## 3. Wire routing edits across the corpus

- [x] 3.1 Route the verification triad (`preferences-validation-assurance`, `preferences-compositional-continuous-verification`, `refinement-driven-development`) to the new skills — verify: commit `d42961a35323` touches all three files (16 insertions); `grep` confirms each names `preferences-requirements-engineering` and the obligation it owns.
- [x] 3.2 Route `preferences-documentation`'s AMDiRE-shear section to `preferences-requirements-engineering` — verify: commit `4fa43577ee2f` (50 insertions, 24 deletions); `grep` confirms two references (lines 63, 72).
- [x] 3.3 Route the acceptance layer (`atdd-outer-loop`, `openspec-bdd-bridge`) to the shared-phenomena restriction and the specification-versus-intent check — verify: commit `4b18b32fc343` (18 insertions); `grep` confirms references in both files.
- [x] 3.4 Ground discovery, glossary, and the router (`preferences-discovery-process`, `ubiquitous-language`, `nucleus-platform`) in the designation discipline — verify: commit `677342616299` (48 insertions); `grep` confirms references in all three files.
- [x] 3.5 Update the `formal-specification-and-refinement` plugin group's `apm.yml` and `plugin.json` descriptions to include the new skills — verify: commit `95f23a5ab33e`'s diffstat shows both files touched (1 line changed each).

## 4. Amend the generated agent context (`agents-md.nix`)

- [x] 4.1 Index both new skills in the guidelines block, glossed in house style — verify: `grep` of `modules/home/tools/agents-md.nix` shows the two index lines (107–108) naming both skills with parenthetical glosses.
- [x] 4.2 State the discharge obligation as a principle: every requirement names the world assumptions and specification properties that discharge it, and an undischarged requirement is recorded as such — verify: `grep` shows the sentence in the operating-principles section (lines 172–174).
- [x] 4.3 Extend the compositional-architecture standard with the companion obligation and the never-claim-end-to-end prohibition — verify: `grep` shows the extension naming `preferences-requirements-engineering`, `satisfaction-argument-audit`, and the prohibition (lines 212–218).
- [x] 4.4 Adopt four directives verified absent from the corpus: no-flattery-without-reason paired with challenging incorrect assumptions directly, a worked do/do-not example on unrequested scope expansion, long-running-command routing to the managed-process tool, and a compact scope rule for non-omp consumers — verify: `grep` confirms the no-flattery sentence (lines 179–182), the do/do-not pair (lines 250–255), and the long-running-command section (lines 321–325) are present in the generated file.
- [x] 4.5 Record two harness hazards (an `~/.omp/agent/AGENTS.md` destination would silently shadow `~/.claude/CLAUDE.md` at priority 100 vs 80; omp's containment dedupe drops the user-level file if a project file's paragraph sequence contains it) and resolve the `nix flake check` self-contradiction between `preferences-nix-development` and `nix-flake-pr-cycle` — verify: `grep` shows the hazard comment (lines 25–32) and the corrected nix-development index gloss routing to targeted `nix eval`/`nix build` probes and `just check-fast` instead of a bare `nix flake check` sweep (line 132).
- [x] 4.6 Confirm the generator file still parses as valid Nix after all edits — verify: `nix-instantiate --parse modules/home/tools/agents-md.nix` exits 0.

## 5. Build and deliver the composed skill tree

- [x] 5.1 Build the composed skill tree and confirm both new skills are included — verify: `nix build .#apm-skills-compose --no-link --print-out-paths` succeeds; `find "$out/.claude/skills" -maxdepth 1 -mindepth 1 -type d | wc -l` reports 177, including `preferences-requirements-engineering` and `satisfaction-argument-audit`.
- [x] 5.2 Confirm both new skills resolve under the live delivery path after activation — verify: `readlink -f ~/.claude/skills/preferences-requirements-engineering` and `readlink -f ~/.claude/skills/satisfaction-argument-audit` both resolve to nix-store paths without error.

## 6. Correct the stratum tagging (the discharge-coherence finding)

- [x] 6.1 Run section 8's discharge-coherence check by hand against this change's original all-`behavioral` tagging, per the schema's own verify instruction — verify: `docs/notes/development/methodology/meta-requirements-framework-integration.md`, "Falsification criteria, and the first result" section (lines 255–337), records ten requirements returned, all undischarged, against zero interface capabilities.
- [x] 6.2 Add `skill-corpus-interface` as a third capability, tagged `interface`, and rewrite the proposal's stratum-tagging note to record the correction rather than silently fix it — verify: `proposal.md` §"Capabilities" lists `skill-corpus-interface` tagged `interface` (lines 75–79) and §"Stratum tagging note, corrected" states the original argument and why it was wrong (lines 87–113); `specs/skill-corpus-interface/spec.md` exists with three ADDED requirements.

## 7. Integration Verification

- [x] 7.1 `openspec validate requirements-engineering-skills --type change` passes — verify: command output is `Change 'requirements-engineering-skills' is valid`.
- [x] 7.2 The full implementation range is present in the shared jj working copy across all nine skill/context/spec commits — verify: `jj log -r 'ancestors(wrspm-requirements-framework) ~ ::main'` lists `804f0880d2bb` through `86f948422d74` (9 commits) with no gaps; `git diff --stat 804f0880d2bb~1 86f948422d74` reports 26 files changed, 1043 insertions(+), 41 deletions(-).
- [x] 7.3 No automated test suite guards this change's content — verify: no test file references any of the touched skills or `agents-md.nix`; recorded as a known gap (guard level: none) rather than hidden, since the corpus convention for skill prose has no unit-test equivalent and `skill-corpus-interface`'s own trust boundary states it does not reach content correctness.
