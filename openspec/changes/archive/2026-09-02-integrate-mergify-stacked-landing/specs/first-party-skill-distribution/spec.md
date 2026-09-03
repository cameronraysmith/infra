## ADDED Requirements

### Requirement: Distinct first-party policy and upstream mechanism skills

The composed corpus SHALL expose `git-stacked-pr-integration` and `mergify-stack` as distinct flat skill names.
The first-party skill SHALL retain the fleet's policy, role contracts, VCS routing, and base landing evidence while referring to the upstream skill for Mergify mechanism detail.
Adding `mergify-stack` MUST NOT retire, rename, replace, or overwrite `git-stacked-pr-integration`.

This interface establishes that both named skill documents are present and separately addressable in the composed output.
It does not establish which skill a harness selects or whether a consumer follows either document correctly.

#### Scenario: Both stacked-landing skills are composed

- **WHEN** the version-control-and-forge package and its pinned Mergify dependency are composed for the `agent-skills` and `claude` targets
- **THEN** the output contains independently resolvable `git-stacked-pr-integration` and `mergify-stack` skill documents under both target trees

#### Scenario: Evidence and routing text retain distinct provenance

- **WHEN** `git-stacked-pr-integration` is revised to refer to the upstream Mergify mechanism
- **THEN** its base statement recording the landing of PRs 2738, 2739, and 2740 remains present verbatim
- **AND** adjacent prose limits that evidence to the observed fast-forward landing and GitHub reachability rather than Mergify authoring or publication
- **AND** the transcript-prescribed soft routing statement between Git-native and `.jj/` repositories is added verbatim by this change rather than described as pre-existing text

#### Scenario: Upstream skill is added

- **WHEN** `mergify-stack` becomes available in the composed corpus
- **THEN** `git-stacked-pr-integration` remains available under its existing flat name rather than being removed or aliased to the upstream name
