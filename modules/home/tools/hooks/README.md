---
title: Claude Code hook scripts
created: 2026-08-26
---

## Claude Code hook scripts

A hook only takes effect through two files, and the two must be kept in sync by hand because nothing checks that they agree.
`default.nix` in this directory packages each script as a `pkgs.writeShellApplication` derivation inside `flake.modules.homeManager.tools`, gives it a `name`, declares its `runtimeInputs`, and appends it to `home.packages` so the built executable lands on the global PATH.
Because that script is on PATH by its bare `name` after home-manager activation, a hook can be exercised by hand without triggering its event, by piping the same JSON shape the harness would send: `echo '{}' | redirect-rm-to-rip`.
`../ai/claude-code/hooks.nix` wires events inside `flake.modules.homeManager.ai`, setting `programs.claude-code.settings.hooks.<Event>` to a list of `{ matcher; hooks = [ { type = "command"; command = "<bare-name>"; } ]; }` entries, where `<bare-name>` is a plain string.
The two files connect only by that string matching the derivation's `name`; there is no nix-level reference between them.
A derivation added to `default.nix` without a corresponding `command` entry in `hooks.nix` sits on PATH and never fires.
A `command` entry added to `hooks.nix` without a matching derivation (and `home.packages` entry) in `default.nix` resolves to nothing at runtime and the hook invocation fails.
Not every derivation in `default.nix` is wired to an event this way: `notify-permission-wait` is built and added to `home.packages` but appears in `hooks.nix` nowhere, because `gate-mutating-http` and `gate-dangerous-commands` consume it only as a `runtimeInputs` entry, calling it internally rather than being invoked directly by an event.

The event names currently wired in `hooks.nix`, i.e. the top-level keys under `programs.claude-code.settings.hooks`, are `PreToolUse`, `WorktreeCreate`, `WorktreeRemove`, `PostToolUse`, `SessionStart`, `UserPromptSubmit`, and `Notification`.

A script's own file-mode executable bit is irrelevant.
Each `.sh` file here is never invoked directly; `default.nix` pulls its contents in with `builtins.readFile ./foo.sh` and hands that text to `writeShellApplication`, which builds a wrapped executable at `<derivation>/bin/<name>` with its own shebang and permissions.
The build does run `shellcheck` against that text, so a script with an unaddressed finding fails the build regardless of whether it is ever wired to an event.

A script's runtime dependencies are declared explicitly through `runtimeInputs`, either as `pkgs.*` packages or, for a hook that calls another hook script internally (as `gate-mutating-http` and `gate-dangerous-commands` call `notify-permission-wait`), as a reference to that other derivation's `let`-bound name.
`writeShellApplication` constrains the built executable's `PATH` to exactly its `runtimeInputs`.
Omitting a dependency is not a build-time error: `shellcheck` lints syntax, not command availability, so a missing dependency surfaces only as a "command not found" failure the first time the hook actually runs.

Several scripts (`enforce-branch-before-edit.sh`, `gate-worktree-surfaces.sh`, `gate-git-worktree.sh`, `verify-diamond-before-edit.sh`) share repository-context helpers from `lib-repo-context.sh`.
Because shell has no `import`, `default.nix` composes this in textually, prepending `repoContextLib` (the file's contents, read once) to the consuming script's `text`.
Each consumer only calls a subset of the shared helpers, so `default.nix` also sets `excludeShellChecks = repoContextShellChecks` (`[ "SC2329" ]`) on those derivations; omitting that exclusion fails the build on the helpers a given script does not happen to call.

Finally, flake sources in this repository are git-tracked only.
A new `.sh` file, or a `default.nix` edit that reads one, is invisible to a flake build until the file is tracked by git (`jj file track` in this jj-colocated repository), regardless of whether it exists on disk.
