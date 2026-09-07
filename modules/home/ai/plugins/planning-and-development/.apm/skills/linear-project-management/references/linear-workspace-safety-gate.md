# Linear workspace safety gate

This is the hardest constraint in the entire linear project management hub.
Read it before proposing any Linear mutation, in this hub or in the openspec-linear-sync overlay.

## The gate

Never propose a Linear mutation until the correct personal-versus-work workspace is confirmed via `linear auth whoami`.
Confirm explicitly which workspace `whoami` reports before any create, update, transition, comment, or document write.
Optionally scope the check to a candidate workspace with `linear auth whoami --workspace <slug>`.

Every linear-cli read or mutation must pass an explicit workspace-selecting `--workspace <slug>`; refuse commands that do not expose that selector.
The command help was verified against v2.6.0 for `auth whoami`, `team list`, `project list`, `issue query`, `issue view`, `document list`, `issue create`, and `issue update`.
For `label list`, `--workspace` is a boolean label filter, described as "Show only workspace-level labels (not team-specific)", not a workspace selector; do not run `label list` under this gate.
Omitting the selector can resolve through environment or config credentials before reaching the credentials default, so do not rely on an ambient workspace.

Never run mutating `linear auth` commands (`linear auth login`, `linear auth logout`, or any auth subcommand that writes credentials).
Credentials are nix-managed and immutable here, rendered from sops into a read-only (0400) inline `credentials.toml` (flat `<workspace> = "<api-key>"` keys plus a top-level `default = "<workspace>"`), so a mutating `linear auth` would fail against the read-only file and is in any case ineffective and dangerous.
linear-cli also supports an OS-keyring credential mode (macOS Keychain via `/usr/bin/security`; Linux secret-tool/libsecret; Windows CredentialManager), but that is not the mode in use; this operator's credentials live in the inline file.
The auth surface is read-only here: `linear auth whoami` confirms identity, nothing more.
The `whoami`, `migrate`, and `--plaintext` verbs and the keyring-versus-plaintext credential modes are documented in the `linear-cli` skill's `references/auth.md`, which is also the authoritative home for the `credentials.toml` flat-key-plus-`default` format; the separate `.linear.toml` project config is covered in the `linear-cli` skill's `references/config.md`.

## Why the gate keys on confirmed credentials, not LINEAR_WORKSPACE

Do not key the gate on `LINEAR_WORKSPACE`.
It is the wrong lever because it is env-overridable and silently outranked by `--workspace` and the API-key tiers, not because of where it sits relative to the credentials default.

The credential precedence and the conflict-throw below are derived from linear-cli upstream source, not from the bundled skill, which does not document them: the resolution chain and the throw live in `src/utils/graphql.ts` (plus the config resolution in `src/config.ts`) in the upstream schpet/linear-cli repository.
These were verified against v2.6.0; re-check them against the pinned version on any linear-cli bump, since a reordering of the tiers would silently change which workspace a mutation hits.

The credential precedence has five tiers, highest first, verified against v2.6.0 in `getResolvedApiKey` and `resolveRawOption`:

1. A nonempty `LINEAR_API_KEY` environment variable.
2. `getOption("api_key")`, which checks the environment, then project config, then global config.
3. The `--workspace <slug>` flag, resolved through `getCredentialApiKey()`; an unknown explicit workspace throws rather than falling back.
4. `getOption("workspace")`, which checks `LINEAR_WORKSPACE`, then project config, then global config, and resolves a nonempty result through `getCredentialApiKey()`.
5. The `credentials.toml` `default` key.

`LINEAR_WORKSPACE` resolves at tier 4 — above the `credentials.toml` default but below `--workspace` and below the API-key tiers.
Because tier 4 sits under tier 3 and tiers 1-2, a `--workspace` flag or an `api_key` silently outranks whatever `LINEAR_WORKSPACE` names, and because it is an environment variable it can be set out from under you.
A gate keyed on `LINEAR_WORKSPACE` therefore gives a false sense of which workspace a mutation will actually hit.

The safe gate keys on `linear auth whoami` plus an explicit `--workspace`.
`whoami` reports the workspace that the resolved credentials actually authenticate against, after the full five-tier resolution, so confirming it closes the personal-versus-work ambiguity that `LINEAR_WORKSPACE` cannot.

## Pre-gate environment assertion

Before running the `linear auth whoami` gate, assert that both `LINEAR_API_KEY` and `LINEAR_WORKSPACE` are unset.
`LINEAR_API_KEY` is tier 1; without the selector it chooses the credentials, and with the selector it causes an error, so refuse to proceed while it is present.
linear-cli throws when both `LINEAR_API_KEY` and a `--workspace` flag are nonempty, verified against v2.6.0 in upstream `getResolvedApiKey` in `src/utils/graphql.ts`; re-verify on a version bump.
`LINEAR_WORKSPACE` is tier 4 and env-overridable, so it too must be unset to keep the gate keyed on the explicit workspace and confirmed credentials.
The shell-env assertion is necessary but not sufficient: `loadEnvFiles` can read a `./.env` or git-root `.env` and inject `LINEAR_*` keys into its process, invisible to a shell check.
This behavior and `ENV_ASSIGNMENT` accepting optional `export` and whitespace before `=` were verified against v2.6.0 in `src/config.ts`; the assertion below rejects those forms for both credential variables.

```bash
[ -z "${LINEAR_API_KEY:-}" ] || { echo "refuse: LINEAR_API_KEY is set and outranks the gate; unset it first" >&2; exit 1; }
[ -z "${LINEAR_WORKSPACE:-}" ] || { echo "refuse: LINEAR_WORKSPACE is set; unset it before the gate" >&2; exit 1; }
git_root=$(git rev-parse --show-toplevel 2>/dev/null || echo .)
for envfile in ./.env "$git_root/.env"; do [ -f "$envfile" ] && grep -Eq '^[[:space:]]*(export[[:space:]]+)?(LINEAR_API_KEY|LINEAR_WORKSPACE)[[:space:]]*=' "$envfile" && { echo "refuse: $envfile defines LINEAR_API_KEY/LINEAR_WORKSPACE; linear-cli reads it into its own process" >&2; exit 1; }; done
```

## Checklist before any mutation

Assert `LINEAR_API_KEY` and `LINEAR_WORKSPACE` are unset (the pre-gate assertion above); refuse to proceed if `LINEAR_API_KEY` is present.
Run `linear auth whoami --workspace <slug>` and confirm the reported workspace is the intended personal-versus-work workspace.
Pass the workspace-selecting `--workspace <slug>` on every read or mutation; refuse commands without that selector, including `label list`, whose boolean filter was verified against v2.6.0.
Never reach for `LINEAR_WORKSPACE` and never run a mutating `linear auth` subcommand.
