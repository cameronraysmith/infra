import { AsyncLocalStorage } from "node:async_hooks";
import { spawn } from "node:child_process";
import { createHash } from "node:crypto";
import { appendFileSync } from "node:fs";
import { lstat, mkdir, mkdtemp, readFile, readdir, readlink, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { Blocked, unreachable, within, type DerivationMap, type ReleaseSource, type Updater } from "./types.js";

export const quote = (text: string): string => `'${text.replaceAll("'", "'\\''")}'`;
export const lines = (text: string): string[] => text.split("\n").filter(Boolean);
export const save = async (cwd: string, file: string, data: unknown): Promise<void> => {
  await mkdir(dirname(join(cwd, file)), { recursive: true });
  await writeFile(join(cwd, file), JSON.stringify(data, null, 2) + "\n");
};
export type ProcessReceipt = {
  command: string; exitCode: number; state: "running" | "exited" | "interrupted" | "failed";
  terminationSignal: string | null; logPath: string; tail: string;
};
export type Observation = ProcessReceipt & { stdout: string; stderr: string };
const processContext = new AsyncLocalStorage<{ root: string; node: string; receipts: ProcessReceipt[]; next: number }>();
export async function processCheckpoint<T>(root: string, node: string, action: () => Promise<T>): Promise<{ receipt: ProcessReceipt[]; evidence: T }> {
  const context = { root, node, receipts: [] as ProcessReceipt[], next: 0 };
  return processContext.run(context, async () => {
    const evidence = await action();
    const checkpoint = { receipt: context.receipts, evidence };
    assertCompactCheckpoint(checkpoint);
    return checkpoint;
  });
}
export function assertCompactCheckpoint(value: unknown): void {
  if (typeof value === "string" && Buffer.byteLength(value) > 8192) throw new Blocked("Checkpoint string exceeds 8 KB; persist the evidence in an artifact");
  if (value && typeof value === "object") for (const [key, child] of Object.entries(value)) {
    if (key === "stdout" || key === "stderr") throw new Blocked("Raw process output cannot enter a checkpoint");
    assertCompactCheckpoint(child);
  }
}
export function processReceipt(observation: Observation): ProcessReceipt {
  const { command, exitCode, state, terminationSignal, logPath, tail } = observation;
  return { command, exitCode, state, terminationSignal, logPath, tail };
}
function boundedTail(text: string): string {
  const tail = text.split("\n").slice(-60).join("\n");
  let bytes = 0, start = tail.length;
  for (const char of [...tail].reverse()) {
    bytes += Buffer.byteLength(char);
    if (bytes > 8192) break;
    start -= char.length;
  }
  return tail.slice(start);
}
export async function capture(cwd: string, command: string, signal: AbortSignal, receiptPath = ""): Promise<Observation> {
  const context = processContext.getStore();
  if (!receiptPath && context) receiptPath = `${context.root}/${context.node}-${context.next++}.json`;
  const logPath = receiptPath ? receiptPath.replace(/\.json$/, "") + ".log" : "";
  const streamPath = logPath ? `${logPath}.stream.jsonl` : "";
  const observation: Observation = { command, stdout: "", stderr: "", exitCode: -1, logPath, state: "running", terminationSignal: null, tail: "" };
  if (receiptPath) {
    await save(cwd, receiptPath, processReceipt(observation));
    await writeFile(join(cwd, logPath), "");
    await writeFile(join(cwd, streamPath), "");
  }
  let failure: Error | undefined;
  try {
    await new Promise<void>((resolve) => {
      const child = spawn("bash", ["-c", `set -euo pipefail\n${command}`], { cwd, signal, detached: true });
      const terminate = () => {
        if (child.pid) {
          try { process.kill(-child.pid, "SIGKILL"); }
          catch (error) { if ((error as NodeJS.ErrnoException).code !== "ESRCH") failure ??= error as Error; }
        }
      };
      signal.addEventListener("abort", terminate, { once: true });
      if (signal.aborted) terminate();
      const output = (stream: "stdout" | "stderr", data: string) => {
        observation[stream] += data;
        observation.tail = boundedTail(observation.tail + data);
        if (logPath) {
          try {
            appendFileSync(join(cwd, logPath), data);
            appendFileSync(join(cwd, streamPath), JSON.stringify({ stream, data }) + "\n");
          } catch (error) { failure ??= error as Error; terminate(); }
        }
      };
      child.stdout.setEncoding("utf8").on("data", (data: string) => output("stdout", data));
      child.stderr.setEncoding("utf8").on("data", (data: string) => output("stderr", data));
      child.on("error", (error) => { failure ??= error; terminate(); });
      child.on("close", (code, terminationSignal) => {
        signal.removeEventListener("abort", terminate);
        observation.exitCode = code ?? -1; observation.terminationSignal = terminationSignal;
        resolve();
      });
    });
  } catch (error) { failure ??= error as Error; }
  if (signal.aborted) failure ??= new DOMException("Process interrupted", "AbortError");
  observation.state = signal.aborted ? "interrupted" : failure ? "failed" : "exited";
  const receipt = processReceipt(observation);
  context?.receipts.push(receipt);
  if (receiptPath) await save(cwd, receiptPath, receipt);
  if (failure) throw Object.assign(failure, { receipt });
  return observation;
}
export const requireSuccess = (observation: Observation): string => {
  if (observation.exitCode !== 0) throw new Blocked(`${observation.command}: exit ${observation.exitCode}\n${observation.logPath}\n${observation.tail}`);
  return observation.stdout.trimEnd();
};
export async function snapshot(cwd: string, signal: AbortSignal): Promise<Record<string, string>> {
  const files = requireSuccess(await capture(cwd, "git ls-files --cached --others --exclude-standard -z", signal)).split("\0").filter(Boolean);
  const result: Record<string, string> = {};
  for (const file of files) {
    try {
      const path = join(cwd, file), info = await lstat(path);
      const mode = info.isSymbolicLink() ? "120000" : info.isFile() ? (info.mode & 0o100 ? "100755" : "100644") : undefined;
      if (!mode) throw new Blocked(`Unclassifiable tracked file mode: ${file}`);
      const content = info.isSymbolicLink() ? await readlink(path) : await readFile(path);
      result[file] = `${mode}:${createHash("sha256").update(content).digest("hex")}`;
    }
    catch (error) { if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error; }
  }
  return result;
}
export function changed(before: Record<string, string>, after: Record<string, string>): string[] {
  return [...new Set([...Object.keys(before), ...Object.keys(after)])].filter((file) => before[file] !== after[file]);
}
export function scopeGate(before: Record<string, string>, after: Record<string, string>, prefixes: string[]): string[] {
  const paths = changed(before, after);
  if (paths.some((path) => !prefixes.some((prefix) => within(path, prefix)))) throw new Blocked(`Out-of-scope edits: ${paths.join(", ")}`);
  return paths;
}
export function discoverReleaseSource(text: string): ReleaseSource {
  const npm = text.match(/https:\/\/registry\.npmjs\.org\/((?:@[^/\s"]+\/)?[^/\s"]+)\/-\//);
  if (npm) return { kind: "Npm", name: npm[1]! };
  const source = text.match(/fetchFromGitHub\s*\{([\s\S]*?)\n\s*\}/)?.[1];
  const owner = source?.match(/owner\s*=\s*"([^"$]+)"/)?.[1];
  const repo = source?.match(/repo\s*=\s*"([^"$]+)"/)?.[1];
  const rev = source?.match(/(?:rev|tag)\s*=\s*"([^"$]*)\$\{(?:[^}]*version)\}"/)?.[1];
  if (owner && repo && rev !== undefined) return { kind: "GitHubRelease", owner, repo, tagPrefix: rev };
  throw new Blocked("Release source cannot be classified deterministically");
}
export type ResolvedRelease = { version: string; latest?: string; source: ReleaseSource; tarball?: string };
export async function resolveRelease(source: ReleaseSource, target: string | undefined, signal: AbortSignal): Promise<ResolvedRelease> {
  const get = async (url: string): Promise<Record<string, unknown>> => {
    const response = await fetch(url, { signal, headers: { accept: "application/json", "user-agent": "vanixiets-bump-derivation" } });
    if (!response.ok) throw new Blocked(`Release lookup ${url}: HTTP ${response.status}`);
    return await response.json() as Record<string, unknown>;
  };
  switch (source.kind) {
    case "GitHubRelease": {
      const base = `https://api.github.com/repos/${encodeURIComponent(source.owner)}/${encodeURIComponent(source.repo)}/releases`;
      let version = target;
      if (version === undefined) {
        const latestTag = (await get(`${base}/latest`)).tag_name;
        if (typeof latestTag !== "string" || !latestTag.startsWith(source.tagPrefix)) throw new Blocked("Unclassifiable latest tag");
        version = latestTag.slice(source.tagPrefix.length);
      }
      const release = await get(`${base}/tags/${encodeURIComponent(source.tagPrefix + version)}`);
      if (release.tag_name !== source.tagPrefix + version) throw new Blocked("Release tag differs from requested target");
      return { source, version, ...(target === undefined ? { latest: version } : {}) };
    }
    case "Npm": {
      const base = `https://registry.npmjs.org/${encodeURIComponent(source.name)}`;
      const version = target ?? (await get(`${base}/latest`)).version;
      if (typeof version !== "string") throw new Blocked("Missing latest npm version");
      const release = await get(`${base}/${encodeURIComponent(version)}`);
      const dist = release.dist as { tarball?: unknown } | undefined;
      if (release.version !== version || typeof dist?.tarball !== "string") throw new Blocked("Invalid npm release metadata");
      return { source, version, ...(target === undefined ? { latest: version } : {}), tarball: dist.tarball };
    }
    default: return unreachable(source);
  }
}
export async function resolveUpdaterCommand(updater: Updater, release: ResolvedRelease, explicit: boolean, signal: AbortSignal): Promise<string> {
  const latest = updater.kind === "PassthruScript" && !updater.acceptsVersionArg && explicit
    ? (await resolveRelease(release.source, undefined, signal)).version : release.latest;
  return updaterCommand(updater, release.version, latest, explicit);
}
export function updaterCommand(updater: Updater, version: string, latest: string | undefined, explicit: boolean): string {
  switch (updater.kind) {
    case "PassthruScript":
      if (!updater.acceptsVersionArg && explicit && version !== latest) throw new Blocked("Updater only supports latest; specific non-latest target requested");
      return `${quote(updater.storePathOrRepoPath)}${updater.acceptsVersionArg ? ` ${quote(version)}` : ""}`;
    case "NixUpdate": return `nix-update --flake ${quote(updater.flakeAttr)} --version ${quote(version)}`;
    case "Manual": throw new Blocked("Manual updater: models must never hand-edit hashes");
    default: return unreachable(updater);
  }
}
type NixToken = { text: string; literal?: string; children?: NixToken[] };
function nixTokens(text: string): NixToken[] {
  let at = 0;
  const fail = (): never => { throw new Blocked("Unclassifiable pin syntax: unclosed string, comment or delimiter"); };
  const scan = (end = ""): NixToken[] => {
    const tokens: NixToken[] = [];
    while (at < text.length) {
      if (/\s/.test(text[at]!)) { at++; continue; }
      if (text[at] === "#") { while (at < text.length && text[at] !== "\n") at++; continue; }
      if (text.startsWith("/*", at)) {
        const close = text.indexOf("*/", at + 2);
        if (close < 0) fail();
        at = close + 2; continue;
      }
      if (end && text[at] === end) { at++; return tokens; }
      if ("})]".includes(text[at]!)) fail();
      const indented = text.startsWith("''", at);
      if (text[at] === '"' || indented) {
        at += indented ? 2 : 1;
        let value = "", staticLiteral = !indented, closed = false;
        while (at < text.length) {
          if (indented && (text.startsWith("'''", at) || text.startsWith("''$", at))) { at += 3; continue; }
          if (indented && text.startsWith("''\\", at)) { at += 4; continue; }
          if (text.startsWith(indented ? "''" : '"', at)) { at += indented ? 2 : 1; closed = true; break; }
          if (!indented && text[at] === "\\") {
            const escaped = text[++at];
            if (escaped === undefined) fail();
            value += ({ n: "\n", r: "\r", t: "\t" } as Record<string, string>)[escaped!] ?? escaped;
            at++; continue;
          }
          if (text.startsWith("${", at)) { staticLiteral = false; at += 2; scan("}"); continue; }
          value += text[at++];
        }
        if (!closed) fail();
        tokens.push({ text: '"', ...(staticLiteral ? { literal: value } : {}) }); continue;
      }
      const open = text[at]!;
      if ("{([".includes(open)) {
        at++;
        tokens.push({ text: open, children: scan(({ "{": "}", "(": ")", "[": "]" } as Record<string, string>)[open]!) }); continue;
      }
      const identifier = text.slice(at).match(/^[A-Za-z_][A-Za-z0-9_'\-]*/)?.[0];
      tokens.push({ text: identifier ?? open }); at += identifier?.length ?? 1;
    }
    if (end) fail();
    return tokens;
  };
  return scan();
}
const nixAttrPath = (tokens: NixToken[]): string[] | undefined => {
  if (!tokens.length || tokens.length % 2 !== 1) return undefined;
  const path: string[] = [];
  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i]!;
    if (i % 2) { if (token.text !== ".") return undefined; }
    else if (token.literal !== undefined) path.push(token.literal);
    else if (/^[A-Za-z_][A-Za-z0-9_'\-]*$/.test(token.text)) path.push(token.text);
    else return undefined;
  }
  return path;
};
function nixPinValues(tokens: NixToken[], field: string[]): string[] {
  const fail = (): never => { throw new Blocked(`Unclassifiable pin boundary: ${field.join(".")}`); };
  const bindings = (items: NixToken[]): string[] => {
    const values: string[] = [];
    let start = 0, lets = 0;
    for (let i = 0; i < items.length; i++) {
      if (items[i]!.text === "let") lets++;
      if (items[i]!.text === "in") lets--;
      if (items[i]!.text !== ";" || lets) continue;
      const binding = items.slice(start, i); start = i + 1;
      if (binding[0]?.text === "inherit") continue;
      const equals = binding.findIndex((t) => t.text === "=");
      const path = nixAttrPath(binding.slice(0, equals));
      if (equals < 0 || !path) fail();
      if (!path!.every((part, n) => part === field[n])) continue;
      const rhs = binding.slice(equals + 1);
      if (path!.length < field.length) values.push(...nixPinValues(rhs, field.slice(path!.length)));
      else {
        if (rhs.length !== 1 || rhs[0]!.literal === undefined) fail();
        values.push(rhs[0]!.literal!);
      }
    }
    if (start !== items.length || lets) fail();
    return values;
  };
  if (tokens.length === 1 && tokens[0]!.text === "(") return nixPinValues(tokens[0]!.children!, field);
  if (tokens[1]?.text === ":" && (tokens[0]!.text === "{" || nixAttrPath(tokens.slice(0, 1)))) return nixPinValues(tokens.slice(2), field);
  if (tokens[0]?.text === "let") {
    let depth = 1;
    const end = tokens.findIndex((token, i) => i > 0 && (token.text === "let" ? (++depth, false) : token.text === "in" && --depth === 0));
    if (end < 0) fail();
    return [...bindings(tokens.slice(1, end)), ...nixPinValues(tokens.slice(end + 1), field)];
  }
  if (tokens[0]?.text === "rec") return nixPinValues(tokens.slice(1), field);
  if (tokens.length === 1 && tokens[0]!.text === "{") return bindings(tokens[0]!.children!);
  const argument = tokens.at(-1);
  if (argument?.children && nixAttrPath(tokens.slice(0, -1))) return nixPinValues([argument], field);
  if (tokens.at(-1)?.text === ";") return bindings(tokens);
  return fail();
}
function pinLiteral(text: string, file: string, field: string): string {
  const path = nixAttrPath(nixTokens(field));
  if (!path) throw new Blocked(`Unclassifiable pin field: ${file}:${field}`);
  if (file.endsWith(".json")) {
    let value: unknown = JSON.parse(text);
    for (const part of path) value = value !== null && typeof value === "object" && Object.hasOwn(value, part) ? (value as Record<string, unknown>)[part] : undefined;
    if (typeof value !== "string") throw new Blocked(`Pin not observed: ${file}:${field}`);
    return value;
  }
  const values = nixPinValues(nixTokens(text), path);
  if (values.length !== 1) throw new Blocked(`Unclassifiable pin boundary (expected one literal, observed ${values.length}): ${file}:${field}`);
  return values[0]!;
}
export type PinEvidence = {
  file: string; field: string; mustChange: boolean; witnessAttr?: string;
  expected: { baseline: string; relation: "changed" | "build-witnessed" }; observed: string; ok: true;
};
export function pinGate(map: DerivationMap, before: Record<string, string>, after: Record<string, string>): PinEvidence[] {
  const evidence: PinEvidence[] = [], failures: string[] = [];
  for (const pin of map.pinSet) {
    try {
      const old = before[pin.file], current = after[pin.file];
      if (old === undefined || current === undefined || pinLiteral(old, pin.file, pin.field) !== pin.value) throw new Blocked(`Pin not observed: ${pin.file}:${pin.field}`);
      const observed = pinLiteral(current, pin.file, pin.field);
      if (pin.mustChange && observed === pin.value) throw new Blocked(`Required pin unchanged: ${pin.file}:${pin.field}`);
      evidence.push({ file: pin.file, field: pin.field, mustChange: pin.mustChange, ...(pin.witnessAttr ? { witnessAttr: pin.witnessAttr } : {}), expected: { baseline: pin.value, relation: pin.mustChange ? "changed" : "build-witnessed" }, observed, ok: true });
    } catch (error) { failures.push(String(error)); }
  }
  if (failures.length) throw new Blocked(failures.join("\n"));
  return evidence;
}
export type Topology = { workingCopy: string; splice: string; descendants: string[]; children: string[] };
export async function topology(cwd: string, splice: string, signal: AbortSignal): Promise<Topology> {
  if (!/^[k-z]+$/.test(splice)) throw new Blocked("splice_after must be a jj change id");
  const ids = async (revset: string) => lines(requireSuccess(await capture(cwd, `jj --ignore-working-copy log --no-graph -r ${quote(revset)} -T 'change_id ++ "\\n"'`, signal)));
  const workingCopy = await ids("@");
  const base = await ids(splice);
  if (workingCopy.length !== 1 || base.length !== 1) throw new Blocked("Ambiguous working copy or splice change");
  return { workingCopy: workingCopy[0]!, splice: base[0]!, descendants: await ids(`${splice}::`), children: await ids(`${splice}+`) };
}
export async function verifyTopology(cwd: string, baseline: Topology, prefixes: string[][], signal: AbortSignal): Promise<{ landed: boolean; changes: string[]; evidence: string }> {
  const after = await topology(cwd, baseline.splice, signal);
  const added = after.descendants.filter((id) => !baseline.descendants.includes(id));
  if (after.workingCopy !== baseline.workingCopy || added.length !== prefixes.length) throw new Blocked("Working copy moved or unexpected new splice descendants");
  let parent = baseline.splice;
  const ordered: string[] = [];
  for (const allowed of prefixes) {
    const children = lines(requireSuccess(await capture(cwd, `jj --ignore-working-copy log --no-graph -r ${quote(`${parent}+`)} -T 'change_id ++ "\\n"'`, signal)));
    if (children.length !== 1 || !added.includes(children[0]!)) throw new Blocked("New changes do not form the required ordered chain");
    const id = children[0]!;
    const paths = lines(requireSuccess(await capture(cwd, `jj --ignore-working-copy diff -r ${quote(id)} --name-only`, signal)));
    if (!paths.length || paths.some((path) => !allowed.some((p) => within(path, p)))) throw new Blocked(`Wrong path set in ${id}: ${paths.join(", ")}`);
    ordered.push(id); parent = id;
  }
  const children = lines(requireSuccess(await capture(cwd, `jj --ignore-working-copy log --no-graph -r ${quote(`${parent}+`)} -T 'change_id ++ "\\n"'`, signal)));
  if (children.length !== baseline.children.length || baseline.children.some((id) => !children.includes(id))) throw new Blocked("Preexisting splice children were not preserved after new chain");
  const leftovers = lines(requireSuccess(await capture(cwd, "jj --ignore-working-copy diff -r @ --name-only", signal)));
  if (leftovers.some((path) => prefixes.flat().some((p) => within(path, p)))) throw new Blocked(`Allowed paths remain in @: ${leftovers.join(", ")}`);
  return { landed: true, changes: ordered, evidence: JSON.stringify({ baseline, after, ordered, leftovers }) };
}
export async function vendoredDirectory(cwd: string, root: string, index: number): Promise<string> {
  const directory = join(cwd, root);
  await mkdir(directory, { recursive: true });
  return mkdtemp(join(directory, `upstream-${index}-`));
}
export type VendoredEvidence = { upstreamSubtree: string; deliveredPath: string; comparedFiles: number; identical: true };
export async function verifyVendored(cwd: string, deliveredPath: string, upstream: string, upstreamSubtree: string, signal: AbortSignal, receiptPath: string): Promise<VendoredEvidence> {
  requireSuccess(await capture(cwd, `diff -r ${quote(deliveredPath)} ${quote(join(upstream, upstreamSubtree))}`, signal, receiptPath));
  const count = async (directory: string): Promise<number> => {
    const entries = await readdir(directory, { withFileTypes: true });
    return (await Promise.all(entries.map((entry) => entry.isDirectory() ? count(join(directory, entry.name)) : 1))).reduce((sum, n) => sum + n, 0);
  };
  return { upstreamSubtree, deliveredPath, comparedFiles: await count(deliveredPath), identical: true };
}
