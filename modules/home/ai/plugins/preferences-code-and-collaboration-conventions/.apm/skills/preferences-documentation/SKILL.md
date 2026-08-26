---
name: preferences-documentation
description: Documentation conventions including structure, formatting, and maintenance practices, including how the AMDiRE-shaped docs/development/ tree relates to an openspec/ corpus and where a satisfaction argument belongs. Load when writing or reviewing documentation, or when deciding whether content belongs in docs/ or in the openspec/ corpus.
---

# Documentation

## References

1. Méndez Fernández, D., Penzenstadler, B.: Artefact-based requirements
   engineering: The AMDiRE approach. Requir. Eng. 20, 405–434 (2015).
   https://arxiv.org/abs/1611.10024
2. Chuprina, T., Mendez, D., Wnuk, K.: Towards artefact-based requirements
   engineering for data-centric systems. arXiv [cs.SE]. (2021)
3. ISO/IEC/IEEE international standard - systems and software engineering
   – life cycle processes – requirements engineering, (2018)
4. IEEE standard for information technology–systems design–software design
   descriptions, (2009)
5. Diátaxis: A systematic approach to technical documentation authoring.
   https://diataxis.fr.

## Location

- Most repositories use `docs/` for their active documentation but some have
  both `docs/` and another directory like `site/`, `website/`, `nbs/`, etc.
- Most `README.md` files in the repository root should aim to include minimal
  content with relevant links to the docs website unless they do not yet have
  docs.

## The README hierarchy

`README.md` files form a third documentation tier alongside the user-facing and development trees below.
They are the local tier: what someone must know to work in a particular directory.

This tier exists because we do not split documentation by audience.
There is no separate agent-facing corpus; there is user-facing documentation, development documentation, and this local tier, and agents read whichever of the three serves the task.
Everything an agent needs is therefore something a human can read, which is the property that makes the arrangement worth maintaining.

Two consequences follow directly.
Documentation systems generally do not render repository `README.md` files — an Astro content loader scoped to its own content directory will not see them — so this tier is read by whoever opens the tree, on a forge or at a keyboard, rather than by a site visitor.
And a per-directory agent instruction file, such as an `AGENTS.md` containing only a pointer to the adjacent `README.md`, is prohibited: it is an artifact that exists solely for agents and that no human would ever open, which is exactly what this arrangement avoids. State a convention once in a skill rather than materialising a stub beside every file it applies to.

### Index and leaf roles

A README at a branch of the tree has two jobs: state its own directory's contract, and index its children so a reader can navigate downward.
A README at a leaf states only the contract.

This is the same shard-and-index discipline described under "Document evolution" below, applied to the source tree rather than to `docs/`.
A branch index is a table of contents and carries the same maintenance obligation as `index.md` does after sharding: when a child is added or removed, the index is wrong until updated.

### What earns a README

A README earns its place the way an inline comment does, and the test is the same: would someone editing files in this directory get it wrong without it?
Navigational seams and non-obvious contracts qualify.
A directory whose contents are self-describing does not; a tree of skill definitions, each carrying its own frontmatter and prose, needs no README restating that it contains skills.

Expect tens of these across a repository, not hundreds.
A README that paraphrases its own directory listing is the same failure as a comment that restates the line beneath it, one tier up, and should be deleted on sight.

### What belongs here rather than in a comment

Rationale that is true of a whole directory belongs in that directory's README rather than repeated in the comments of the files inside it.
A constraint such as "this tree is generated and regenerating it discards local edits" is one README sentence, not five comments.

Three classes cannot move, and attempting it destroys them.
File-level load-bearing markers — licence and SPDX headers, shebangs, encoding declarations, linter and formatter pragmas — are positional, because tooling parses them where they sit.
Docstrings and language-canonical doc comments are API contract and feed generated reference documentation, so they stay with their symbol.
Block-local correctness and safety notes are load-bearing precisely because of where they are; a safety note moved two directories up no longer guards anything.

One asymmetry to account for when deciding what to move.
A comment sits in the editor's viewport when the code beside it changes, so its staleness is visible at the moment it is introduced.
A README two directories up does not, so it rots less visibly than the comment it replaced.
Move only what is true of the whole directory and changes rarely — the contract, not the implementation — and treat anything volatile as belonging next to the code.

### Maintenance trigger

Update a README when the directory's contract changed, not when a file inside it changed.
That distinction is what keeps this tier from generating edits that record no information.

### Prose and diagrams

This tier is prose, and `preferences-prose-clarity` governs it as it governs any other prose we write; this skill does not restate that discipline.

Prefer a diagram over prose where the structure is not recoverable from the tree itself — dependency direction, layering, a lifecycle, a state machine, a data flow.
Do not diagram an inventory.
A graph of a directory's children duplicates the filesystem, and the filesystem cannot drift from itself while the diagram can, so such a diagram is a second copy of the one self-maintaining thing in the repository.
A branch index is an inventory and stays a list.

`preferences-architecture-diagramming` owns format selection and the C4 zoom hierarchy; reach for Mermaid in Markdown when a forge or documentation site should render the diagram without a build step.

## Structure

Generally assume we intend to follow this standard structure for repository
documentation combining user-facing and development documentation:

```
docs/
├── tutorials/           # Diataxis: Learning-oriented lessons
├── guides/              # Diataxis: Task-oriented how-tos
├── concepts/            # Diataxis: Understanding-oriented explanations
├── reference/           # Diataxis: Information-oriented API docs (optional)
├── about/               # Contributing, conduct, links into development
├── development/         # Development documentation (adapted AMDiRE-based)
│   ├── index.md         # Development overview and navigation
│   ├── context/         # Context Specification (problem domain)
│   │   ├── index.md     # Context overview and table of contents
│   │   └── context.md   # Problem domain, stakeholders, objectives
│   ├── requirements/    # Requirements Specification (problem ↔ solution bridge)
│   │   ├── index.md     # Requirements overview and traceability matrix
│   │   └── requirements.md  # Functional/non-functional requirements
│   ├── architecture/    # System Specification (solution space)
│   │   ├── index.md     # Architecture overview and table of contents
│   │   └── architecture.md  # System design and component structure
│   └── traceability/    # Requirements traceability
│       ├── index.md     # Traceability overview
│       ├── testing.md   # Test framework and validation approach
│       └── satisfaction.md  # Satisfaction argument, regenerated at archive time
└── notes/               # EPHEMERAL: Working notes excluded from rendering
    └── [category]/      # Temporary staging (see "Working notes" section)
```

### The WRSPM shear

AMDiRE's own strata do not coincide with the world/machine boundary that `preferences-requirements-engineering` states its two verification obligations against.
Its Context Specification is approximately the world together with goals.
Its Requirements Specification is approximately the requirements-to-specification interface zone rather than requirements proper: a usage or use-case model describes interaction at the machine interface, which is specification-side vocabulary.
Its System Specification sits below the specification stratum, already in refinement-toward-implementation territory.

Two consequences follow, and they are the reason the shear matters rather than being a taxonomy curiosity.
Genuinely environment-referent requirements — statements about world phenomena the machine never touches — have no home in the tree's `requirements/` directory, above, because that directory is already specification-side; they get exiled upward into `context/` goals, informally.
And a document titled "System Specification" — this tree's `architecture.md` — typically carries both specification-stratum content and sub-specification content in one file, with no marked seam between them.

`preferences-requirements-engineering` owns the pentad and the two obligations this shear is stated against; load it before deciding which stratum a passage in this tree belongs in.

The repair is cheap precisely because the AMDiRE content model this skill follows already requires a glossary.
Promoting it to a stratified designation table — one row per term naming the world phenomenon it denotes and whether that phenomenon is world-only or shared with the machine — turns a list of definitions into the artifact the grounding condition needs.
`ubiquitous-language` owns the per-term glossary record and the columns that extend it into a designation table; this skill does not restate them.

### Document evolution

Many projects will begin with only `docs/development/` and add the user docs
directories later. Initial development drafts context.md, requirements.md,
architecture.md, and testing.md as single comprehensive documents. As complexity
grows—expected for most real projects—decompose each document by major
subsection into separate files with descriptive names (e.g., context.md →
stakeholders.md, objectives.md, constraints.md). Update the corresponding
index.md to serve as table of contents and navigation after sharding. This
pattern maintains manageability while preserving traceability as documentation
scales. If the documentation becomes sufficiently complex, we can continue to
refactor into a directory tree with additional levels.

### Working notes

The `docs/notes/` directory serves as ephemeral staging for development notes
that have not been formalized into the permanent documentation structure. These
notes are explicitly temporary and must be either migrated to formal
documentation or discarded.

**Organization**: Use category-based subdirectories with kebab-case filenames:
```
docs/notes/
├── security/           # Security investigations
├── architecture/       # Architectural exploration
├── performance/        # Performance analysis
└── [category]/         # Other categorized notes
```

**Exclusion from rendering**: Working notes must never appear in rendered
documentation sites. Configure your documentation system accordingly:

- **Astro** (content collections): Only include specific directories in
  `src/content/config.ts`, implicitly excluding `notes/`
- **Quarto** (`_quarto.yml`):
  ```yaml
  project:
    render:
      - "!docs/notes/**"
  ```
- **Docusaurus** (`docusaurus.config.js`):
  ```javascript
  docs: {
    exclude: ['**/notes/**']
  }
  ```
- **MkDocs** (`mkdocs.yml`):
  ```yaml
  exclude_docs: |
    notes/
  ```

**Lifecycle**: Every working note must eventually follow one of two paths:

1. **Migrate to formal documentation**: Extract valuable insights, revoice from
   informal working notes to formal documentation style, and move content to the
   appropriate location in the user-facing docs (`tutorials/`, `guides/`,
   `concepts/`, `reference/`) or development docs
   (`development/context/`, `development/requirements/`,
   `development/architecture/`, etc.). Delete the working note after migration.

2. **Discard when no longer relevant**: Delete notes that served temporary
   investigation purposes, documented abandoned approaches, or have been
   superseded by other documentation.

Working notes should not persist indefinitely. Regularly audit `docs/notes/` for
stale content and progress notes through their lifecycle. The goal is to keep
this directory empty or minimal in stable projects.

**Relationship to implementation tracking**: The permanent record of development efforts, with traceability to issues and PRs, lives in `openspec/changes/` while a change is active and in `openspec/changes/archive/` once it is complete — see "Relationship to the OpenSpec corpus" below.
Working notes in `docs/notes/` are a separate, ephemeral thing: drafts that get cleaned up after their content is either formalized into `docs/` or determined to be no longer needed.

### Markdown formatting conventions

Some documentation generators like Astro Starlight require markdown files to use YAML frontmatter with a title like
```yaml
---
title: "Title: subtitle"
---
```
instead of the `# Title: subtitle` format.
As such it's best to primarily use this convention when authoring markdown.
Note that quotes are required in YAML when the title contains special characters like colons; simple titles without special characters don't require quotes.
Not all markdown documents require subtitles—the subtitle format is shown here for completeness to demonstrate proper quoting.

Plain markdown systems (GitHub, static markdown) also support frontmatter titles, making this convention broadly compatible.
When working in a documentation directory, check for frontmatter in existing files to confirm the convention in use.
If files contain `title:` in YAML frontmatter, use `##` to start content sections to avoid duplicate titles in rendered output.

Consecutive `**Term**: description` lines merge into one paragraph when rendered.
Use `- **Term**: description` bullet format for 2+ definitions.

### Key principles

- Separate user documentation (diataxis framework) from development
  documentation (AMDiRE methodology)
- User docs focus on helping users learn, accomplish tasks, understand concepts,
  and find reference information
- Development docs provide traceability: context (why) → requirements (what) →
  architecture (how); implementation tracking is not a docs/ artifact — see
  "Relationship to the OpenSpec corpus" below.
- Maintain bidirectional traceability between requirements, architecture
  decisions, and the openspec/changes/ corpus that implements them.
- Reference GitHub issues, pull requests, ADRs, RFCs, or RFDs from archived
  OpenSpec changes for full audit trail.
- Everything in all three tiers is prose we write, so `preferences-prose-clarity`
  governs it — reader-expectation structure, calibrated claims, and the smallest
  safe repair when editing someone else's text. This skill does not restate that
  discipline and defers to it on any sentence-level question.
- Prefer a diagram wherever the structure is not recoverable from the surrounding
  prose or from the tree: dependency direction, layering, a lifecycle, a state
  machine, a data flow. A reader should be able to take the shape in at a glance
  rather than reconstruct it from paragraphs. Do not diagram an inventory, and do
  not diagram something a short list states exactly. `preferences-architecture-diagramming`
  owns format selection and the C4 zoom hierarchy; Mermaid in Markdown is the
  default where a forge or documentation site should render it without a build step.

### Architecture decision records

ADRs live in `docs/development/architecture/adrs/` following the AMDiRE structure above.
Authoring conventions covering section structure, status lifecycle, commanding voice, business justification requirements, and antipatterns are in `references/adr-conventions.md`.
Load that companion file when writing, reviewing, or evaluating ADRs.

## Relationship to the OpenSpec corpus

In repositories that use OpenSpec, normative behavioral requirements live in an `openspec/specs/` corpus with a delta-and-archive lifecycle: a change proposes deltas under `openspec/changes/<id>/`, and archiving folds them into `openspec/specs/` and moves the change to `openspec/changes/archive/`.
The AMDiRE-shaped tree above and that corpus are not two places to keep the same information.

The governing rule is that the repository never contains two committed copies of the same information.
Everything normative, transactional, or delta-derived lives under `openspec/`.
The documentation tree above is a lens over that corpus, not a destination for it: most of what it would otherwise hold is a rendered view, generated at build time and never committed.
The only projection that earns persistence is one with semantic content of its own, beyond what the corpus already states.

Exactly one projection meets that bar: the satisfaction argument at `docs/development/traceability/satisfaction.md`.
It is regenerated wholesale at archive time and never patched — a patched discharge table accumulates exactly the staleness the artifact exists to prevent.
It lives in the documentation tree rather than in the corpus because the corpus has no lifecycle to host it: the OpenSpec CLI confines a change's generated artifacts to that change's own directory, and the only writers that touch `openspec/specs/` outside a change directory are the archive merge and the sync-specs mechanism, both delta-mediated and both scoped to the corpus.
A file with no change directory and no delta behind it has nothing in OpenSpec that would ever write or validate it.

Everything else this skill's tree prescribes is honestly what remains once the normative content is subtracted out: narrative context (`context/`), architecture narrative and its decision records (`architecture/`, `adrs/`), and pre-transaction backlog intent in working notes (`notes/`) before it becomes a change.
All of it is human-authored, none of it normative, and none of it should be read as an alternate record of what the corpus already states.

Where a repository does not use OpenSpec, none of this section applies, and the tree above stands as originally prescribed.

## Temporal provenance

Documents carry temporal context that informs their reliability.
Use the following frontmatter fields to make provenance explicit.

### Provenance frontmatter fields

These fields are optional but recommended for any document in `docs/` that persists beyond a single session.

- `created: YYYY-MM-DD` — date the document was first authored.
- `last-validated: YYYY-MM-DD` — date the document's content was last reviewed and confirmed accurate, independent of incidental edits (typo fixes, formatting). Session-checkpoint updates this field for documents reviewed during a session. Session-orient uses it for staleness scanning: a file modified recently for formatting but last validated months ago is stale; an unmodified file validated recently is not.
- `superseded-by: <path or description>` — marks a document as replaced by another. Documents with this field older than 30 days should be deleted or archived during session-orient health checks.

### Conflict detection and resolution

No rigid precedence hierarchy exists between document types.
A recently edited working note can supersede an older formal spec, and vice versa.
When information from different documents contradicts, recency of the specific conflicting content is the primary signal.

Use git history rather than filesystem modification times to assess recency.
Filesystem mtime is unreliable — it changes on `git checkout`, `git rebase`, and other operations that do not represent content edits.
Prefer `git log --follow -1 --format='%ai' -- <file>` for file-level provenance and `git blame -L <range> <file>` for line-level provenance.

When contradictions are detected during any task, flag them to the user with provenance evidence (file paths, dates, relevant line ranges) rather than silently preferring one source.
The user decides which source is authoritative; the agent's role is to surface the contradiction and the temporal evidence.

### docs/notes/ index

Maintain a `docs/notes/README.md` file as a table of contents for the ephemeral notes directory.
Each entry should include the subdirectory or file name, a one-line description of its purpose, and the date it was created or last validated.
This index helps agents and humans quickly assess which notes exist and their approximate currency without reading each file.
Update the index when creating, deleting, or significantly revising working notes.

## Citing source files

Cite a source file by naming the symbol it contains — a function, struct, constant, or test — rather than a line number.
Write `run_git_gc` in `lib/src/git_backend.rs`, not `lib/src/git_backend.rs:921-940`.

Line numbers rot on every upstream commit that touches the file above them, and they rot silently.
The citation still resolves, so it goes on reading as authoritative while pointing at whatever now occupies that line.
A symbol name survives most refactors, and a symbol that has moved or been renamed fails loudly: a search for it returns nothing, which is unmistakable.

The silent failure is worse than a small offset.
An audit of the jj skill corpus found the anchor `lib/src/git.rs:1127-1148`, cited for the claim that import reads only git's HEAD, resting inside `remotely_pinned_commit_ids` — a different function that reads no HEAD at all.
The function the claim was actually about, `import_head`, had moved elsewhere in the file.
A reader who followed that citation would find plausible-looking code rather than an obvious miss, and that is what makes this class of rot expensive to detect.

Where no symbol encloses the material — a bare match arm, a comment, a stretch of prose — name the nearest enclosing symbol and say what within it the citation refers to.
Drop the citation instead if it carries no weight.
Where a citation supports a claim about runtime behavior, record the version the claim was verified against, because the claim and the source drift independently.

A local clone of an upstream repository sits at whatever revision it was fetched at, which is rarely the revision of whatever build is installed.
Use such a clone to confirm that a symbol exists, not to look up a line number for it.

The same caution applies to a document's own generated copy.
Where a build system materializes documentation into a second location — nix home-manager linking generated skill files into place, for example — that copy changes only when the build reruns, so it holds pre-change content indefinitely after the source is edited.
Verify an edit against the source tree, never against the generated copy, and treat a generated path as a read-only artifact.

Two properties make the staleness hard to notice, so check for them before trusting a negative result.
Generated files may carry a fixed epoch timestamp rather than a real one, which is the same reason provenance questions route to git history rather than mtime; a nix store path reports a 1970 mtime whatever its content.
And a search that does not follow symlinks reports nothing at all for a symlinked tree rather than reporting an error, which reads as agreement with whatever was expected — `rg` needs `-L` to descend into one.

## Code

- In code, prefer docstrings relevant to a given programming language over code comments
  as the docstrings end up in `docs/reference/` files automatically generated by
  most language API reference documentation tools.
- For whether an inline comment should exist at all, and for when to remove existing comments,
  follow the Code comments policy in preferences-style-and-conventions: reserve inline comments
  for what the code cannot express and remove those that merely restate it.

## Maintenance

- When making code changes, immediately identify all affected documentation artifacts
  with surgical precision:
  - `docs/development/context/` if problem domain or stakeholders change
  - `docs/development/requirements/` if functional/non-functional requirements change
  - `docs/development/architecture/` if design decisions, components, or technology change
  - `docs/development/traceability/` if test strategy or validation approach changes
  - Implementation status tracking is not a `docs/` artifact — see "Relationship to the OpenSpec corpus"
  - Repository README.md and user-facing docs/ if behavior changes
- Update affected documentation immediately in the same session, not at an undetermined
  future point.
- Commit documentation updates atomically in series with the related code changes,
  following the same proactive atomic commit workflow specified in
  `~/.claude/skills/preferences-git-version-control/SKILL.md`.
- Be judicious in the use of documentation, ensuring that it is clear, concise,
  and accurate for humans to read and understand.
- Proactively remove, refactor, and consolidate documentation as relevant to
  maintain optimal correspondence between the code and documentation.
