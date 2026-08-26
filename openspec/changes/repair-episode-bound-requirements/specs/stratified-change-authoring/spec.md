## MODIFIED Requirements

### Requirement: Archive step regenerates the satisfaction projection

The apply phase's archive step SHALL rebuild `docs/development/traceability/satisfaction.md` wholesale
from the post-sync corpus each time `openspec archive` runs, rather than patching the existing file,
and SHALL record any undischarged requirement it finds rather than omitting it.

#### Scenario: archive completes

- **WHEN** `openspec archive` finishes syncing the change's delta specs into the main capability
  specs and before the change folder moves under the archive directory
- **THEN** the archive step regenerates the satisfaction projection from the synced main specs as a
  full rebuild, so the PR diff for this cycle carries the projection's post-sync state

#### Scenario: undischarged requirement found during projection rebuild

- **WHEN** the rebuilt projection contains a behavioral requirement with no interface property and no
  world assumption discharging it
- **THEN** the projection records that requirement's row as `undischarged` with a follow-up reference,
  never omitted and never silently accepted
