# pi-vim modal editing: enablement evidence

Records why `lajarre/pi-vim` 0.14.1 is registered for pi alone, and what evidence stands behind each half of that claim.
Companion to [atomic npm-distribution compatibility findings](../atomic-npm-distribution-compat.md), which owns the per-extension load matrix.

## The downstream patch

`clipboard-mirror.ts:56` calls `import.meta.resolve("@earendil-works/pi-coding-agent")` at module scope, to embed the host agent's module URL in the source of a clipboard helper child process.
pi satisfies that specifier through its virtual-module map rather than through `node_modules`, so `import.meta.resolve` throws, and a throw at module scope fails the whole extension rather than the clipboard mirror alone.
`pkgs/by-name/pi-vim/package.nix` substitutes the bare specifier for the call.

The remedy is re-derived per version bump: `substituteInPlace --replace-fail` turns a moved or reworded call site into a build failure rather than a silently unpatched output.

The narrower upstream fix would resolve lazily at first clipboard use and degrade the OS-clipboard mirror, which is where this extension is already fragile — compare pi issue #3496, a macOS clipboard panic.
Filing it upstream is worth more than carrying the substitution indefinitely: the defect breaks upstream's own documented `pi install npm:pi-vim` and has been present since 0.11.2.

## Load evidence, and why the smoke regulator is severe

`pi-agent-environment-smoke` drives the deployed pi wrapper over RPC and fails on any `extension_error` or non-zero exit.
Its settings fixture takes `packageEntries` from pi's evaluated settings, so pi-vim entered its coverage with the wiring and no fixture edit.

Falsified deliberately by dropping `postPatch` from the derivation and re-running:

```
AssertionError: Pi exited 1: Error: Failed to load extension ".../pi-vim-0.14.1/index.ts":
Failed to load extension: ResolveMessage: Cannot find module '@earendil-works/pi-coding-agent'
from ".../pi-vim-0.14.1/clipboard-mirror.ts"
```

So the regulator does discriminate the patched build from the unpatched one, and the patch is load-bearing rather than precautionary.
Note the failure arrives at the driver's `returncode` guard, not at its `extension_error` conjunct: pi exits 1 having written zero bytes to stdout, so no RPC frame is ever emitted.

## Behaviour evidence

Loading is not working. pi-vim registers no slash command, so nothing on the RPC surface observes whether `ctx.ui.setEditorComponent` produced a live modal editor — the failure mode under atomic is exactly a clean load with a dead editor.
`pi-vim-modal-editing-probe.py` beside this note allocates a pty, sends `i`, `abc`, Esc, `x`, and reads the rendered frames.

pi's prompt starts in insert mode, so the leading `i` is literal text and the buffer reads `iabc`; Esc leaves insert mode and `x` deletes the character under the cursor.
Both arms observed on aarch64-darwin against pi 0.84.2:

| observation | pi-vim registered | pi-vim unregistered |
|---|---|---|
| INSERT mode label rendered | yes | no |
| NORMAL mode label rendered | yes | no |
| typed text reaches the buffer | yes | yes |
| final buffer | `iab` | `iabcx` |

The last row is the discriminating one: with modal editing live, `x` deleted a character; without it, `x` was inserted as literal text.

The probe is deliberately not a flake check. Every wait in it is a wall-clock sleep against TUI repaint, which a build sandbox running other derivations in parallel would make flaky. Promoting it means replacing those sleeps with a render-settled predicate first.

## Why pi only

Registration goes through `aiAgentSettings.piOnlyPackages` rather than the shared `packages` list.
That option's description in `modules/home/ai/agent-settings.nix` carries the mechanism and the reason; in short, atomic declaring its own `packages` key shadows pi's array wholesale, so the entry reaches pi alone with no force-exclude, and under atomic pi-vim would load, warn on the `setEditorComponent` stub, and leave the native editor in place with no modal keybindings.

`modules/checks/atomic-agent-environment.nix` asserts both halves — present in pi's declared packages, absent from atomic's — because atomic's half is invisible from atomic's side alone.
