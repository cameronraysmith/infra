import { spawn } from "node:child_process";
import process from "node:process";
import { workflow } from "@bastani/atomic/workflows";
import { Type } from "typebox";

const RECON = ".atomic/workflows/runs/bump-atomic/recon.md";
const REVIEW_NOTES = ".atomic/workflows/runs/bump-atomic/review.md";

/** The only tree this bump is allowed to land. */
const DERIVATION_PREFIX = "pkgs/by-name/atomic/";

// The first-party anthropic route to fable rejects this client's reported
// version (HTTP 400, "Claude Code 2.1.75 does not support this model"). The
// openrouter route reaches the same model without that gate, so it leads the
// fallback chain rather than a different model family.
const MODEL_RECON = "anthropic/claude-fable-5-1:medium";
const FALLBACK_RECON = [
  "openrouter/anthropic/claude-fable-5.1:medium",
  "anthropic/claude-sonnet-4-6:medium",
];
const MODEL_IMPL = "openai-codex/gpt-6-astra:high";
const FALLBACK_IMPL = ["openai-codex/gpt-5.6-terra:high"];
const MODEL_REVIEW = "anthropic/claude-opus-5:max";
const FALLBACK_REVIEW = ["anthropic/claude-opus-4-8:max"];
const MODEL_LAND = "anthropic/claude-opus-5:high";
const FALLBACK_LAND = ["anthropic/claude-opus-4-8:high"];

type ShellOutcome = {
  exitCode: number;
  logPath: string;
  tail: string;
  command: string;
};

type CaptureOutcome = {
  exitCode: number;
  stdout: string;
  stderr: string;
  command: string;
};

/**
 * An output that asserts something *happened* must carry where that belief came
 * from. `witness` is the only constructor and it only accepts a `ctx.tool`
 * outcome, so a `Witness<boolean>` cannot be conjured from a literal — which is
 * exactly the failure this workflow shipped once, reporting `landed: true` while
 * its land stage had explicitly done nothing.
 */
declare const witnessBrand: unique symbol;

type Witness<T> = {
  readonly [witnessBrand]: true;
  /** Read off real command output, never asserted. */
  readonly value: T;
  /** The ctx.tool node that produced the evidence. */
  readonly source: string;
  /** What that node actually observed, quoted into blocked reasons. */
  readonly evidence: string;
};

/** Structural subset of WorkflowToolOutcome; keeps this helper independent of it. */
type ToolOutcome<T> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly error: unknown };

const witness = <TValue, T>(
  source: string,
  outcome: ToolOutcome<TValue>,
  read: (value: TValue) => { readonly value: T; readonly evidence: string },
): Witness<T> | null =>
  // The brand exists only to stop structural forgery; this is the one cast.
  outcome.ok ? ({ source, ...read(outcome.value) } as unknown as Witness<T>) : null;

type CompletedOutputs = {
  status: string;
  summary: string;
  target_version: string;
  recon_artifact: string;
  build_log: string;
  build_attempts: number;
  review_verdict: string;
  landed: boolean;
};

/**
 * The only way to build a successful terminal result. `landed` is not a
 * parameter a caller can set: it is read off a Witness, so the success path is
 * unreachable without a tool node having observed the change.
 */
const completedRun = (
  landed: Witness<boolean>,
  rest: Omit<CompletedOutputs, "landed">,
): CompletedOutputs => ({ ...rest, landed: landed.value });

const stamp = (): string => {
  const d = new Date();
  const p = (n: number, w = 2) => String(n).padStart(w, "0");
  return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
};

const lines = (text: string): string[] =>
  text
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l.length > 0);

/**
 * Every long-running command is captured whole and only then narrowed. `tee`
 * writes the full stream to logs/<slug>-<ts>.log so a human can `tail -f` it
 * and a later stage can `rg` it; `tail` bounds only what re-enters the model
 * context. `set -o pipefail` is required — without it the pipeline reports
 * tail's status and a failing build is read as success.
 */
const shellLogged = (
  cwd: string,
  slug: string,
  command: string,
  signal: AbortSignal,
  tailLines = 60,
): Promise<ShellOutcome> => {
  const logPath = `logs/${slug}-${stamp()}.log`;
  const script = [
    "set -o pipefail",
    "mkdir -p logs",
    `${command} 2>&1 | tee ${JSON.stringify(logPath)} | tail -n ${tailLines}`,
  ].join("\n");

  return new Promise<ShellOutcome>((resolve, reject) => {
    const child = spawn("bash", ["-c", script], { cwd, signal });
    let tail = "";
    child.stdout.on("data", (c: Buffer) => {
      tail += c.toString();
    });
    child.stderr.on("data", (c: Buffer) => {
      tail += c.toString();
    });
    child.on("error", reject);
    child.on("close", (code) => {
      resolve({ exitCode: code ?? -1, logPath, tail: tail.slice(-16_000), command });
    });
  });
};

/**
 * For short read-only probes whose *value* matters rather than their volume:
 * streams are kept apart so a change id is never contaminated by a warning on
 * stderr, and nothing is teed because there is nothing to tail -f.
 */
const capture = (cwd: string, command: string, signal: AbortSignal): Promise<CaptureOutcome> =>
  new Promise<CaptureOutcome>((resolve, reject) => {
    const child = spawn("bash", ["-c", `set -o pipefail\n${command}`], { cwd, signal });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (c: Buffer) => {
      stdout += c.toString();
    });
    child.stderr.on("data", (c: Buffer) => {
      stderr += c.toString();
    });
    child.on("error", reject);
    child.on("close", (code) => {
      resolve({
        exitCode: code ?? -1,
        stdout: stdout.slice(-16_000),
        stderr: stderr.slice(-8_000),
        command,
      });
    });
  });

/** jj change ids of the working copy and of everything one hop from it. */
const JJ_WORKING_COPY_ID =
  "jj --ignore-working-copy log -r '@' --no-graph -T 'change_id.short() ++ \"\\n\"'";
const JJ_ADJACENT_IDS =
  "jj --ignore-working-copy log -r 'parents(@) | children(@)' --no-graph -T 'change_id.short() ++ \"\\n\"'";

const ATTR_PATTERN = /^\.#[A-Za-z0-9][A-Za-z0-9._+-]*$/;
const SYSTEM_PATTERN = /^[a-z0-9_]+-[a-z0-9]+$/;

type GateAttrs = {
  ok: boolean;
  problem: string;
  system: string;
  attrs: string[];
};

/**
 * The recon stage names the attributes that actually cover this package. Prose
 * naming them is not the same as a gate building them, so the structured value
 * is checked here — shape, shell-safety, and non-emptiness — and the run stops
 * rather than silently falling back to a guess.
 */
const validateGateAttrs = (structured: unknown): GateAttrs => {
  const reject = (problem: string): GateAttrs => ({ ok: false, problem, system: "", attrs: [] });

  if (typeof structured !== "object" || structured === null) {
    return reject(
      `map-derivation returned no structured value (got ${JSON.stringify(structured)}); the build attributes it enumerated cannot be trusted as prose alone.`,
    );
  }

  const record = structured as Record<string, unknown>;
  const system = record.system;
  const rawAttrs = record.check_attrs;

  if (typeof system !== "string" || !SYSTEM_PATTERN.test(system)) {
    return reject(`map-derivation reported system ${JSON.stringify(system)}, which is not a nix system double.`);
  }
  if (!Array.isArray(rawAttrs) || rawAttrs.length === 0) {
    return reject(`map-derivation enumerated no build attributes (got ${JSON.stringify(rawAttrs)}).`);
  }

  const attrs: string[] = [];
  for (const attr of rawAttrs) {
    if (typeof attr !== "string" || !ATTR_PATTERN.test(attr)) {
      return reject(
        `map-derivation returned build attribute ${JSON.stringify(attr)}, which is not a plain \`.#name\` flake attribute path; refusing to interpolate it into a shell command.`,
      );
    }
    if (!attrs.includes(attr)) attrs.push(attr);
  }

  return { ok: true, problem: "", system, attrs };
};

const keep = (text: string): string => `<keepContext>\n${text}\n</keepContext>`;

export default workflow({
  name: "bump-atomic-derivation",
  description:
    "Bump the vanixiets pkgs/by-name/atomic derivation to a target Atomic release, verified by a real nix build and an independent review, landed as one jj change.",
  autoAttach: true,
  inputs: {
    target_version: Type.String({
      description: "Atomic release to move the derivation to, without a leading v.",
      default: "0.9.18",
    }),
    max_repair_attempts: Type.Integer({
      description: "Bounded build-repair rounds before the run stops blocked.",
      default: 2,
    }),
    build_timeout_minutes: Type.Integer({
      description: "Per-attempt deadline for each nix build gate.",
      default: 45,
    }),
  },
  outputs: {
    status: Type.String({ description: "completed | blocked" }),
    summary: Type.String({ description: "One-paragraph account of what happened." }),
    target_version: Type.String({ description: "Version the derivation was moved to." }),
    recon_artifact: Type.String({ description: "Path to the derivation recon notes." }),
    build_log: Type.String({ description: "Path to the last nix build log." }),
    build_attempts: Type.Number({ description: "How many build gates ran." }),
    review_verdict: Type.String({ description: "approved | changes_requested" }),
    landed: Type.Boolean({
      description:
        "Whether a jj change was created. Derived from verify-land's observation of the change graph, never asserted.",
    }),
  },
  run: async (ctx) => {
    const version = String(ctx.inputs.target_version).replace(/^v/, "");
    const maxRepairs = Number(ctx.inputs.max_repair_attempts);
    const buildTimeoutMs = Number(ctx.inputs.build_timeout_minutes) * 60_000;
    // ctx.cwd is optional; every child process below needs a definite directory.
    const cwd = ctx.cwd ?? process.cwd();

    // ---- T1: does the release actually exist? ------------------------------
    const release = await ctx.tool(
      "resolve-release",
      { version, npm: "@bastani/atomic", repo: "bastani-inc/atomic" },
      async ({ signal }) => {
        const probe = async (url: string) => {
          try {
            const r = await fetch(url, {
              signal,
              headers: { accept: "application/json", "user-agent": "vanixiets-bump-atomic" },
            });
            return { url, status: r.status, ok: r.ok };
          } catch (e) {
            return { url, status: 0, ok: false, error: String(e) };
          }
        };
        const npm = await probe(`https://registry.npmjs.org/@bastani/atomic/${version}`);
        const gh = await probe(
          `https://api.github.com/repos/bastani-inc/atomic/releases/tags/v${version}`,
        );
        return { npm, gh, found: npm.ok || gh.ok };
      },
      { timeoutMs: 90_000, retriesAllowed: true, maxAttempts: 3 },
    );

    if (!release.found) {
      ctx.exit({
        status: "blocked",
        reason: `Atomic ${version} was not found on the npm registry or as a GitHub release tag; nothing to bump to.`,
        outputs: {
          status: "blocked",
          summary: `Release ${version} does not exist upstream (npm ${release.npm.status}, GitHub ${release.gh.status}).`,
          target_version: version,
          landed: false,
        },
      });
    }

    // ---- S1: map the derivation --------------------------------------------
    const derivationMap = await ctx.task("map-derivation", {
      context: "fresh",
      model: MODEL_RECON,
      fallbackModels: FALLBACK_RECON,
      output: RECON,
      outputMode: "file-only",
      schema: Type.Object({
        system: Type.String({
          description: "The nix system double this repository builds on, e.g. aarch64-darwin.",
        }),
        check_attrs: Type.Array(
          Type.String({
            description:
              "One flake attribute path exactly as it would be passed to nix build, e.g. .#atomic or .#checks.aarch64-darwin.atomic.",
          }),
          {
            minItems: 1,
            description:
              "Every attribute that builds or checks this package on the reported system. A downstream gate runs exactly these.",
          },
        ),
      }),
      prompt: [
        keep(
          [
            "You are producing reference notes only. Do NOT edit, create, or delete any file.",
            "Restrict your reading to the repository at the current working directory.",
            "Report only attribute paths you confirmed exist (for example with `nix flake show` or by reading the flake outputs). A downstream build gate runs exactly what you return, so a guessed attribute becomes a failing build or, worse, a gate that checks nothing.",
          ].join("\n"),
        ),
        "Map how the `atomic` package derivation is defined and updated in this Nix repository, and write your findings as the final assistant message (it becomes the artifact).",
        "",
        "Cover exactly these points, each with concrete file:line evidence:",
        "1. Every file under pkgs/by-name/atomic/ and its one-line purpose.",
        "2. The exact fields carrying the package version and every content hash (file, line, current literal value).",
        "3. The update mechanism: is there a passthru.updateScript, a nix-update invocation, or a manifest generator? Give the exact command a human would run, whether it needs network access, and whether it is non-interactive.",
        "4. Whether any lockfile, manifest.json, or node_modules fixed-output hash must be regenerated, and the exact command that regenerates it.",
        "5. Every other location in the repository that pins the current Atomic version (search the current literal version string). Report file:line for each.",
        "6. The exact attribute paths that build or check this package, e.g. `.#atomic` and any `.#checks.<system>.<name>` that covers it. Name the current system.",
        "",
        "Then call `structured_output` with the current system double and the full list of attribute paths from point 6. Your prose still becomes the artifact; the structured value is what the build gate executes, so the two must agree.",
        "",
        "Where the answer is genuinely ambiguous, say so explicitly instead of guessing; a downstream stage depends on these commands being literally correct.",
      ].join("\n"),
    });

    const gate = validateGateAttrs(derivationMap.structured);
    if (!gate.ok) {
      ctx.exit({
        status: "blocked",
        reason: `Cannot construct a build gate from the recon stage's output: ${gate.problem}`,
        outputs: {
          status: "blocked",
          summary: `The bump to ${version} was not attempted: ${gate.problem} See ${RECON}.`,
          target_version: version,
          recon_artifact: RECON,
          landed: false,
        },
      });
    }

    // The gate builds what recon enumerated, as one invocation.
    // `internal-json` keeps the full structured build stream on disk; `-v` keeps
    // per-derivation progress in it. Both are for the log, not for the tail.
    const gateCommand = `nix build --no-link --log-format internal-json -v ${gate.attrs
      .map((a) => JSON.stringify(a))
      .join(" ")}`;
    const gateCommandLogged = (slug: string) =>
      `set -o pipefail; ${gateCommand} 2>&1 | tee logs/${slug}-$(date +%Y%m%d-%H%M%S).log | tail -n 40`;

    // ---- S2: apply the bump -------------------------------------------------
    await ctx.task("apply-bump", {
      context: "fresh",
      model: MODEL_IMPL,
      fallbackModels: FALLBACK_IMPL,
      reads: [RECON],
      prompt: [
        keep(
          [
            `Move this repository's \`atomic\` package derivation to version ${version}.`,
            "Change ONLY what that bump requires: the version field, the content hashes it invalidates, and any other file the notes identify as pinning the same version.",
            "Do not refactor the derivation, do not restructure unrelated Nix code, and do not commit anything. Landing is a later stage's job.",
            "Never hand-write a hash you did not observe in real tool output.",
          ].join("\n"),
        ),
        `Reference notes: ${RECON}`,
        `Read the file at ${RECON} first. It records the exact version and hash fields, the update mechanism, the regeneration commands, and every other location pinning the current version.`,
        "",
        "Then apply the bump using the update mechanism those notes describe, preferring the repository's own update script over hand-editing when one exists.",
        "",
        "Capture every command that runs longer than a moment or prints more than a few lines as:",
        "  <command> 2>&1 | tee logs/<short-kebab-id>-$(date +%Y%m%d-%H%M%S).log | tail -n 40",
        "Run `set -o pipefail` first in the same shell so a failing command is not masked by tee/tail.",
        "",
        "Finish by reporting: the files you changed, the old and new value of every version and hash field, and the log paths you produced.",
      ].join("\n"),
    });

    // ---- T2..Tn: real build gates, with a bounded unrolled repair loop -------
    const buildGate = (n: number) =>
      ctx.tool(
        `build-gate-${n}`,
        { version, attempt: n, system: gate.system, attrs: gate.attrs.join(" ") },
        async ({ signal }) => shellLogged(cwd, `nix-build-atomic-${n}`, gateCommand, signal),
        { failureMode: "return", timeoutMs: buildTimeoutMs },
      );

    let attempts = 1;
    let build = await buildGate(attempts);
    let green = build.ok && build.value.exitCode === 0;
    let lastLog = build.ok ? build.value.logPath : "(build gate did not produce a log)";

    for (let round = 1; !green && round <= maxRepairs; round += 1) {
      const failureTail = build.ok ? build.value.tail : JSON.stringify(build.error);
      const failedLog = build.ok ? build.value.logPath : "(none)";

      await ctx.task(`repair-${round}`, {
        context: "fresh",
        model: MODEL_IMPL,
        fallbackModels: FALLBACK_IMPL,
        reads: [RECON],
        prompt: [
          keep(
            [
              `A nix build of this repository's \`atomic\` package failed. The gate ran: ${gateCommand}`,
              "Diagnose the real cause and fix it.",
              "Fix the derivation; do not disable, skip, or weaken the build to make it pass, do not narrow the set of attributes being built, and do not commit anything.",
              "Never hand-write a hash you did not observe in real tool output.",
            ].join("\n"),
          ),
          `Full build log: ${failedLog}`,
          `Reference notes on the derivation: ${RECON}`,
          "",
          "That log is `--log-format internal-json`: every line is `@nix {...}` JSON carrying the build's own stream, so it is machine-readable but unpleasant to read whole. Search it surgically rather than reading it:",
          `  rg -n -C 5 'error|mismatch|specified:|got:' ${failedLog} | tail -n 60`,
          `  sed -n 's/^@nix //p' ${failedLog} | jq -r 'select(.action == "msg") | .msg' | tail -n 80`,
          "",
          "Last lines of that build:",
          "```",
          failureTail.slice(-6_000),
          "```",
          "",
          "A hash mismatch reports both the specified and the actual hash — take the actual one from the log rather than recomputing it by hand.",
          "Re-run the same gate yourself to confirm your fix, capturing it as:",
          `  ${gateCommandLogged("repair-build")}`,
          "Report what was actually wrong, what you changed, and the log path proving it now builds.",
        ].join("\n"),
      });

      attempts += 1;
      build = await buildGate(attempts);
      green = build.ok && build.value.exitCode === 0;
      lastLog = build.ok ? build.value.logPath : lastLog;
    }

    if (!green) {
      ctx.exit({
        status: "blocked",
        reason: `The build gate (${gateCommand}) is still failing after ${maxRepairs} repair rounds; see ${lastLog}.`,
        outputs: {
          status: "blocked",
          summary: `The bump to ${version} does not build after ${attempts} gates and ${maxRepairs} repair rounds. Investigate ${lastLog}.`,
          target_version: version,
          recon_artifact: RECON,
          build_log: lastLog,
          build_attempts: attempts,
          landed: false,
        },
      });
    }

    // ---- S5: independent review, decorrelated from the implementer ----------
    const review = await ctx.task("review", {
      context: "fresh",
      model: MODEL_REVIEW,
      fallbackModels: FALLBACK_REVIEW,
      reads: [RECON],
      output: REVIEW_NOTES,
      schema: Type.Object({
        verdict: Type.Union([Type.Literal("approved"), Type.Literal("changes_requested")]),
        findings: Type.Array(
          Type.Object({
            severity: Type.Union([
              Type.Literal("blocking"),
              Type.Literal("major"),
              Type.Literal("minor"),
            ]),
            location: Type.String({ description: "file:line, or a command that reproduces it." }),
            problem: Type.String(),
            evidence: Type.String({ description: "What you actually observed. No speculation." }),
          }),
        ),
        rationale: Type.String(),
      }),
      prompt: [
        keep(
          [
            `You are reviewing an uncommitted change that moves this repository's \`atomic\` package derivation to version ${version}.`,
            "You did not write this change and must not assume it is correct. Do not edit any file.",
            "Report only problems you can evidence from the diff, the build log, or a command you ran. Invent no new requirements.",
            "Return `changes_requested` if and only if you found at least one blocking or major finding.",
          ].join("\n"),
        ),
        `Reference notes on the derivation: ${RECON}`,
        `Successful build log: ${lastLog} (produced by \`${gateCommand}\`, so it is line-delimited \`@nix {...}\` JSON; search it with rg rather than reading it whole).`,
        "",
        "Inspect the working-copy diff for the derivation and check specifically:",
        `- Every version-bearing field actually reads ${version}; no location still pins the old version. The notes list every such location — verify each one rather than trusting the list.`,
        "- Every content hash was regenerated from real tool output rather than carried over or invented.",
        "- No unrelated file was modified, and no build check was weakened, skipped, or disabled to make the build pass.",
        "- Any generated manifest or lockfile is internally consistent with the new version.",
        `- The gate that went green (${gateCommand}) actually covers this package. If the notes name an attribute that the gate did not build, say so: a green gate over the wrong attributes proves nothing.`,
        "",
        "A green build is necessary but not sufficient: a stale second pin or a copied hash can survive it.",
      ].join("\n"),
    });

    const verdict =
      (review.structured as { verdict?: string } | undefined)?.verdict === "changes_requested"
        ? "changes_requested"
        : "approved";

    if (verdict === "changes_requested") {
      await ctx.task("address-review", {
        context: "fresh",
        model: MODEL_IMPL,
        fallbackModels: FALLBACK_IMPL,
        reads: [RECON, REVIEW_NOTES],
        prompt: [
          keep(
            [
              "Address every blocking and major finding in the review notes. Do not commit anything.",
              "If you believe a finding is wrong, say so with evidence rather than silently ignoring it.",
              "Never hand-write a hash you did not observe in real tool output.",
            ].join("\n"),
          ),
          `Review findings: ${REVIEW_NOTES}`,
          `Reference notes on the derivation: ${RECON}`,
          `Read both files, then fix what they identify.`,
          "",
          "Re-verify with the same gate the workflow runs:",
          `  ${gateCommandLogged("post-review-build")}`,
          "Report each finding and how you resolved it, with the log path proving the build is still green.",
        ].join("\n"),
      });

      attempts += 1;
      const confirm = await buildGate(attempts);
      if (!confirm.ok || confirm.value.exitCode !== 0) {
        const failLog = confirm.ok ? confirm.value.logPath : lastLog;
        ctx.exit({
          status: "blocked",
          reason: `The build broke while addressing review findings; see ${failLog}.`,
          outputs: {
            status: "blocked",
            summary: `Review requested changes; the follow-up fix left the build gate red. Investigate ${failLog}.`,
            target_version: version,
            recon_artifact: RECON,
            build_log: failLog,
            build_attempts: attempts,
            review_verdict: verdict,
            landed: false,
          },
        });
      }
      lastLog = confirm.ok ? confirm.value.logPath : lastLog;
    }

    // ---- H1: nothing touches history without a human saying so --------------
    const approved = await ctx.ui.confirm(
      `Atomic ${version} builds green (${lastLog}) and review returned ${verdict}. Create a jj change for this bump?`,
    );

    if (!approved) {
      ctx.exit({
        status: "completed",
        reason: "Verified but not landed at the operator's request.",
        outputs: {
          status: "completed",
          summary: `Bump to ${version} is applied in the working copy and builds green (${lastLog}), but was deliberately not landed.`,
          target_version: version,
          recon_artifact: RECON,
          build_log: lastLog,
          build_attempts: attempts,
          review_verdict: verdict,
          landed: false,
        },
      });
    }

    // ---- T: capture the change graph before touching anything ---------------
    // @ is a multi-parent development join, so `@-` is ambiguous and cannot name
    // "the change the land stage made". The baseline is the set of change ids one
    // hop from @; the land stage is verified by what that set gains.
    const preLand = await ctx.tool(
      "capture-land-topology",
      { version, phase: "pre-land" },
      async ({ signal }) => {
        const log = await shellLogged(
          cwd,
          "jj-state-pre-land",
          "jj --ignore-working-copy status; echo '--- log ---'; jj --ignore-working-copy log -r '::@ & ~::main' --no-graph -T 'change_id.short() ++ \" \" ++ description.first_line() ++ \"\\n\"'",
          signal,
          80,
        );
        const wc = await capture(cwd, JJ_WORKING_COPY_ID, signal);
        const adjacent = await capture(cwd, JJ_ADJACENT_IDS, signal);
        const workingCopy = lines(wc.stdout)[0] ?? "";
        return {
          ok: log.exitCode === 0 && wc.exitCode === 0 && adjacent.exitCode === 0 && workingCopy !== "",
          logPath: log.logPath,
          working_copy: workingCopy,
          adjacent: lines(adjacent.stdout),
          detail: [
            `${wc.command} -> exit ${wc.exitCode} ${wc.stderr.trim()}`,
            `${adjacent.command} -> exit ${adjacent.exitCode} ${adjacent.stderr.trim()}`,
          ].join("\n"),
        };
      },
      { failureMode: "return", timeoutMs: 120_000 },
    );

    if (!preLand.ok || !preLand.value.ok) {
      const detail = preLand.ok ? preLand.value.detail : JSON.stringify(preLand.error);
      ctx.exit({
        status: "blocked",
        reason: `Could not read the jj change graph before landing, so nothing landed could be verified afterwards: ${detail}`,
        outputs: {
          status: "blocked",
          summary: `Bump to ${version} builds green (${lastLog}) and review returned ${verdict}, but the pre-land change graph was unreadable, so the workflow refused to touch history.`,
          target_version: version,
          recon_artifact: RECON,
          build_log: lastLog,
          build_attempts: attempts,
          review_verdict: verdict,
          landed: false,
        },
      });
    }

    const baseline = preLand.ok
      ? preLand.value
      : { logPath: "", working_copy: "", adjacent: [] as string[], detail: "", ok: false };

    // ---- S: land, under hard working-copy constraints -----------------------
    await ctx.task("land", {
      context: "fresh",
      model: MODEL_LAND,
      fallbackModels: FALLBACK_LAND,
      reads: [lastLog],
      prompt: [
        keep(
          [
            "This repository is a jj working copy that is a DEVELOPMENT JOIN: @ merges several independent chains, and other sessions may be coordinating through it.",
            "The working copy pointer @ MUST NOT move. Do not run `jj edit`, do not check out a branch, and do not reattach a detached git HEAD.",
            "Create the change with exactly `jj new --no-edit -B @ -m \"<message>\"` and route the bump into it with a PATH-SCOPED `jj squash`, passing both `--use-destination-message` and `--keep-emptied`.",
            `Squash ONLY paths under ${DERIVATION_PREFIX}. An unscoped squash would exhaust @ and take unrelated chains with it.`,
            "Never rewrite, amend, or squash any pre-existing commit that is not the change you just created.",
            "The bump is ALREADY BUILT and ALREADY REVIEWED. Do not re-run the build, and do not treat an unbuilt-looking working copy as a reason to stop: the successful build log is named below.",
            "If the working copy shows `(divergent)`, a conflicted state, or anything you did not expect, STOP and report it instead of proceeding.",
          ].join("\n"),
        ),
        `Objective: land the uncommitted \`atomic\` package bump to version ${version} as exactly one new jj change.`,
        "",
        `Successful build log for this bump: ${lastLog}`,
        `Working-copy state captured a moment ago: ${baseline.logPath}`,
        `Working copy @ is change ${baseline.working_copy}. Changes currently adjacent to it: ${baseline.adjacent.join(", ") || "(none)"}.`,
        "",
        "Procedure:",
        "1. Inspect the working copy with `jj --ignore-working-copy status` and confirm which paths this bump touched.",
        '2. Create the destination change with `jj new --no-edit -B @ -m "<message>"`, describing the bump in this repository\'s existing commit style (check `jj log` for how comparable package bumps are worded). `-B @` is required: it inserts the change directly before @, which is the topology the verification step looks for.',
        `3. Move only the bump's paths into it with a path-scoped \`jj squash --from @ --into <change> --use-destination-message --keep-emptied -- ${DERIVATION_PREFIX}\`. That path prefix is the whole allowed scope: if the bump also touched a pin outside it, do NOT squash that file — squash the derivation, then report the leftover path so a human can decide.`,
        "4. Verify with `jj --ignore-working-copy log` that @ still points at the join, the new change holds the bump, and no other change was altered.",
        "",
        "Capture each command as:",
        "  <command> 2>&1 | tee logs/jj-land-<step>-$(date +%Y%m%d-%H%M%S).log | tail -n 30",
        "",
        "A workflow-owned check runs immediately after you finish and asserts, from real `jj` output, that @'s change id is unchanged, that exactly one new change id is adjacent to @, and that its diff touches only the derivation. Reporting success you did not achieve will not survive it.",
        "Report the resulting change id, its description, and the verification output showing @ is unmoved. If you stopped early, say exactly what you saw and what you did not do.",
      ].join("\n"),
    });

    // ---- T: did the land stage actually do what it said? --------------------
    const verifyLand = await ctx.tool(
      "verify-land",
      {
        version,
        working_copy_before: baseline.working_copy,
        adjacent_before: baseline.adjacent.join(" "),
      },
      async ({ signal }) => {
        const wc = await capture(cwd, JJ_WORKING_COPY_ID, signal);
        const adjacent = await capture(cwd, JJ_ADJACENT_IDS, signal);
        const workingCopyAfter = lines(wc.stdout)[0] ?? "";
        const adjacentAfter = lines(adjacent.stdout);
        const before = baseline.adjacent;
        const added = adjacentAfter.filter((id) => !before.includes(id));
        const removed = before.filter((id) => !adjacentAfter.includes(id));

        const assertions: { name: string; pass: boolean; detail: string }[] = [
          {
            name: "working-copy-unmoved",
            pass: workingCopyAfter !== "" && workingCopyAfter === baseline.working_copy,
            detail: `@ was ${baseline.working_copy}, is now ${workingCopyAfter || "(unreadable)"} (exit ${wc.exitCode})`,
          },
          {
            name: "exactly-one-new-adjacent-change",
            pass: adjacent.exitCode === 0 && added.length === 1,
            detail: `adjacent before: ${before.join(", ") || "(none)"}; after: ${adjacentAfter.join(", ") || "(none)"}; new: ${added.join(", ") || "(none)"}; no longer adjacent: ${removed.join(", ") || "(none)"} (exit ${adjacent.exitCode})`,
          },
        ];

        let changedPaths: string[] = [];
        const newChange = added.length === 1 ? (added[0] ?? "") : "";
        if (newChange === "") {
          assertions.push({
            name: "new-change-touches-only-the-derivation",
            pass: false,
            detail: "not evaluated: there is no single new adjacent change to inspect",
          });
        } else {
          const diff = await capture(
            cwd,
            `jj --ignore-working-copy diff -r ${newChange} --name-only`,
            signal,
          );
          changedPaths = lines(diff.stdout);
          assertions.push({
            name: "new-change-touches-only-the-derivation",
            pass:
              diff.exitCode === 0 &&
              changedPaths.length > 0 &&
              changedPaths.every((p) => p.startsWith(DERIVATION_PREFIX)),
            detail: `${newChange} touches: ${changedPaths.join(", ") || "(nothing)"} (exit ${diff.exitCode})`,
          });
        }

        return {
          ok: assertions.every((a) => a.pass),
          working_copy_before: baseline.working_copy,
          working_copy_after: workingCopyAfter,
          new_adjacent: added,
          no_longer_adjacent: removed,
          changed_paths: changedPaths,
          assertions,
        };
      },
      { failureMode: "return", timeoutMs: 120_000 },
    );

    const landed = witness("verify-land", verifyLand, (v) => ({
      value: v.ok,
      evidence: v.assertions
        .map((a) => `${a.pass ? "PASS" : "FAIL"} ${a.name}: ${a.detail}`)
        .join("\n"),
    }));
    const landedChange = verifyLand.ok ? verifyLand.value.new_adjacent.join(", ") : "";

    if (landed !== null && landed.value) {
      return completedRun(landed, {
        status: "completed",
        summary: `Bumped the atomic derivation to ${version}: ${attempts} build gate(s) over ${gate.attrs.join(" ")}, review verdict ${verdict}, landed as change ${landedChange} adjacent to the unmoved development join. Last build log: ${lastLog}.`,
        target_version: version,
        recon_artifact: RECON,
        build_log: lastLog,
        build_attempts: attempts,
        review_verdict: verdict,
      });
    }

    const evidence =
      landed?.evidence ??
      `verify-land did not run to completion: ${JSON.stringify(verifyLand.ok ? "" : verifyLand.error)}`;

    ctx.exit({
      status: "blocked",
      reason: `The land stage finished, but the change graph does not show one new derivation-only change beside an unmoved @:\n${evidence}`,
      outputs: {
        status: "blocked",
        summary: `Bump to ${version} builds green (${lastLog}) and review returned ${verdict}, but landing could not be verified, so it is reported as not landed. Evidence:\n${evidence}`,
        target_version: version,
        recon_artifact: RECON,
        build_log: lastLog,
        build_attempts: attempts,
        review_verdict: verdict,
        landed: false,
      },
    });
    // ctx.exit() ends the run, but its `never` return is not visible to the
    // compiler through the context object, so state the unreachability here
    // rather than weakening the return type to `CompletedOutputs | undefined`.
    throw new Error("unreachable: ctx.exit() terminated the run");
  },
});
