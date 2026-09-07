import assert from "node:assert/strict";
import { readFileSync, existsSync } from "node:fs";
import { mkdtemp, mkdir, writeFile, chmod } from "node:fs/promises";
import { setTimeout as delay } from "node:timers/promises";
import { createRequire } from "node:module";
import { resolve } from "node:path";

const require = createRequire(import.meta.url);
const [compilerPath, atomicPath] = process.argv.slice(2);
assert(compilerPath && atomicPath, "usage: node .atomic/workflows/bump/check.mjs <typescript/lib/typescript.js> <installed-atomic-package>");
const ts = require(resolve(compilerPath));
const root = ".atomic/workflows/bump-derivation.ts";
const options = {
  noEmit: true, strict: true, module: ts.ModuleKind.NodeNext, moduleResolution: ts.ModuleResolutionKind.NodeNext,
  target: ts.ScriptTarget.ES2022, skipLibCheck: true,
  typeRoots: [resolve(atomicPath, "node_modules/@types")], types: ["node"],
  paths: {
    "@bastani/atomic/workflows": [resolve(atomicPath, "dist/builtin/workflows/src/authoring.d.ts")],
    typebox: [resolve(atomicPath, "node_modules/typebox/build/index.d.mts")],
    "typebox/value": [resolve(atomicPath, "node_modules/typebox/build/value/index.d.mts")],
  },
};
const program = ts.createProgram([root], options);
const diagnostics = ts.getPreEmitDiagnostics(program);
if (diagnostics.length) {
  console.error(ts.formatDiagnosticsWithColorAndContext(diagnostics, { getCanonicalFileName: (f) => f, getCurrentDirectory: () => process.cwd(), getNewLine: () => "\n" }));
  process.exitCode = 1;
} else {
  console.log("PASS strict TypeScript: NodeNext/NodeNext ES2022 strict noEmit skipLibCheck (installed declarations)");
}
const source = program.getSourceFile(root);
assert(source);
const text = source.getFullText();
const namedCalls = [];
function visit(node) {
  if (ts.isCallExpression(node) && node.arguments[0] && ts.isStringLiteral(node.arguments[0])) namedCalls.push({ name: node.arguments[0].text, start: node.getStart() });
  ts.forEachChild(node, visit);
}
visit(source);
const position = (name) => { const call = namedCalls.find((c) => c.name === name); assert(call, `missing ${name}`); return call.start; };
assert(position("resolve-release") < position("map-derivation"));
const plan = text.indexOf("if (ctx.inputs.plan_only)");
assert(plan > position("map-derivation") && plan < position("run-updater"));
const planNode = (() => { let found; function walk(n) { if (ts.isIfStatement(n) && n.expression.getText(source) === "ctx.inputs.plan_only") found = n; ts.forEachChild(n, walk); } walk(source); return found; })();
assert(planNode && ts.isBlock(planNode.thenStatement));
assert(ts.isReturnStatement(planNode.thenStatement.statements.at(-1)), "plan-only branch must end with unconditional return");
assert(position("run-updater") < position("verify-vendored-delivery") && position("verify-vendored-delivery") < position("review") && position("review") < position("land"));
assert(text.includes("actual?.reasoningLevel") && text.includes("result.modelAttempts"));
assert(text.includes("completedRun(landed, changes,"));
for (const file of [".atomic/workflows/bump/types.ts", ".atomic/workflows/bump/tools.ts", root]) {
  const s = readFileSync(file, "utf8");
  const ast = ts.createSourceFile(file, s, ts.ScriptTarget.ES2022, true);
  function check(n) {
    if (ts.isSwitchStatement(n)) {
      const d = n.caseBlock.clauses.find(ts.isDefaultClause);
      assert(d && d.getText(ast).includes("unreachable("), `${file}: switch lacks blocking exhaustive default`);
    }
    ts.forEachChild(n, check);
  }
  check(ast);
}
console.log("PASS static control flow: plan-only returns before updater; stages ordered; switches exhaustive; metadata and witness seams present");
const moduleUrl = (file, replacements) => {
  let code = ts.transpileModule(readFileSync(file, "utf8"), { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } }).outputText;
  for (const [from, to] of Object.entries(replacements)) code = code.replaceAll(`"${from}"`, JSON.stringify(to));
  return `data:text/javascript;base64,${Buffer.from(code).toString("base64")}`;
};
const typesUrl = moduleUrl(".atomic/workflows/bump/types.ts", {
  typebox: `file://${resolve(atomicPath, "node_modules/typebox/build/index.mjs")}`,
  "typebox/value": `file://${resolve(atomicPath, "node_modules/typebox/build/value/index.mjs")}`,
});
const types = await import(typesUrl);
const tools = await import(moduleUrl(".atomic/workflows/bump/tools.ts", { "./types.js": typesUrl }));
const receiptFixture = await mkdtemp(resolve(".atomic/workflows/runs/bump-derivation/receipt-check-"));
const receiptCheckpoint = await tools.processCheckpoint("run", "large", async () => {
  const result = await tools.capture(receiptFixture, "printf '%010000d' 1; printf '\\nerror-tail\\n' >&2", AbortSignal.timeout(5_000));
  return { exitCode: result.exitCode };
});
function checkCheckpoint(value) {
  if (typeof value === "string") assert(Buffer.byteLength(value) <= 8192, "checkpoint strings are bounded");
  if (value && typeof value === "object") for (const [key, child] of Object.entries(value)) {
    assert(!["stdout", "stderr"].includes(key), "raw output cannot enter a checkpoint");
    checkCheckpoint(child);
  }
}
checkCheckpoint(receiptCheckpoint);
assert.equal(receiptCheckpoint.receipt.length, 1);
assert.equal(receiptCheckpoint.evidence.exitCode, 0);
const receipt = receiptCheckpoint.receipt[0];
assert(existsSync(resolve(receiptFixture, receipt.logPath)));
assert(readFileSync(resolve(receiptFixture, receipt.logPath), "utf8").length > 10_000);
assert.match(receipt.tail, /error-tail/);
console.log("PASS compact process checkpoint preserves full log without raw output fields or oversized strings");
await assert.rejects(tools.processCheckpoint("run", "raw", async () => ({ stdout: "not a receipt" })), /Raw process output/);
await assert.rejects(tools.processCheckpoint("run", "oversized", async () => ({ nested: { text: "x".repeat(8193) } })), /exceeds 8 KB/);
console.log("PASS checkpoint boundary rejects nested raw output and oversized domain strings");
const multipleReceipts = await tools.processCheckpoint("run", "multiple", async () => {
  await tools.capture(receiptFixture, `${tools.quote(process.execPath)} -e 'process.stdout.write("λ".repeat(5000))'`, AbortSignal.timeout(5_000));
  await tools.capture(receiptFixture, `${tools.quote(process.execPath)} -e 'process.stdout.write(Array.from({length:100},(_,i)=>i).join("\\n"))'`, AbortSignal.timeout(5_000));
  return { observed: true };
});
checkCheckpoint(multipleReceipts);
assert.equal(new Set(multipleReceipts.receipt.map((r) => r.logPath)).size, 2);
assert.equal(Buffer.byteLength(multipleReceipts.receipt[0].tail), 8192);
assert.equal(multipleReceipts.receipt[1].tail.split("\n").length, 60);
assert(multipleReceipts.receipt[1].tail.endsWith("99"));
console.log("PASS multiple process receipts retain separate logs and UTF-8 byte/line bounded tails");
const registeredClaim = { file: "skills/local/SKILL.md", lines: "1", text: "original", verifiedAgainst: "v1" };
const extraClaim = { ...registeredClaim, lines: "2", text: "discovered" };
const registeredSkill = { kind: "SelfMaintained", skillPath: "skills/local", dependsOn: { kind: "Package" }, citedClaims: [registeredClaim] };
const rewrittenClaim = { ...registeredClaim, lines: "2", text: "corrected", verifiedAgainst: "v2" };
assert.equal(types.validateClaimReplacement(registeredClaim, undefined, "original", "2"), null);
assert.deepEqual(types.validateClaimReplacement(registeredClaim, rewrittenClaim, "heading\ncorrected\n", "2"), rewrittenClaim);
for (const replacement of [undefined, { ...rewrittenClaim, file: "other.md" }, { ...rewrittenClaim, lines: "1" }, { ...rewrittenClaim, text: "absent" }, { ...rewrittenClaim, verifiedAgainst: "v1" }]) {
  assert.throws(() => types.validateClaimReplacement(registeredClaim, replacement, "heading\ncorrected\n", "2"), /Registry replacement/);
}
console.log("PASS registry replacements retain claim identity and match the new literal at the cited location");
const extraSkill = { kind: "Vendored", pinKind: "SrcCarried", deliveryExpr: "source/skills", upstreamSubtree: "skills/vendor" };
assert.deepEqual(types.verifyRegistrySkills([registeredSkill], [{ ...registeredSkill, citedClaims: [extraClaim, registeredClaim] }, extraSkill]), { deps: [extraSkill], claims: [{ skillPath: registeredSkill.skillPath, claim: extraClaim }] });
console.log("PASS registry subset accepts and reports extra dependencies and claims");
assert.throws(() => types.verifyRegistrySkills([registeredSkill], [{ ...registeredSkill, citedClaims: [extraClaim] }]), /Registry claim drift: skills\/local\/SKILL.md:1/);
assert.throws(() => types.verifyRegistrySkills([registeredSkill], [{ ...registeredSkill, citedClaims: [{ ...registeredClaim, verifiedAgainst: "v2" }] }]), /Registry claim drift/);
console.log("PASS registry missing or changed claim blocks");
assert.throws(() => types.verifyRegistrySkills([registeredSkill], [{ ...registeredSkill, dependsOn: { kind: "VendoredSkill", name: "vendor" } }]), /Registry skill dependency drift: skills\/local/);
assert.throws(() => types.verifyRegistrySkills([extraSkill], [{ ...extraSkill, pinKind: "NpmBundled" }]), /Registry skill dependency drift/);
assert.throws(() => types.verifyRegistrySkills([registeredSkill], [registeredSkill, registeredSkill]), /Registry skill dependency drift/);
console.log("PASS registry changed identity or duplicate match blocks");
const registry = (await import(moduleUrl(".atomic/workflows/bump/packages.ts", {}))).packages;
for (const dep of registry["linear-cli"].skillDeps) {
  if (dep.kind === "SelfMaintained") for (const claim of dep.citedClaims) {
    const content = readFileSync(claim.file, "utf8");
    assert(claim.text.split("; ").every((part) => content.includes(part)), `Nonliteral registry claim: ${claim.file}:${claim.lines}`);
  }
}
console.log("PASS Linear registry claims match literal source text");
assert.throws(() => tools.updaterCommand({ kind: "Manual" }, "2", "2", false), /Manual/);
assert.throws(() => tools.updaterCommand({ kind: "Unknown" }, "2", "2", false), /Unknown constructor/);
assert.equal(tools.updaterCommand({ kind: "PassthruScript", storePathOrRepoPath: "update.sh", acceptsVersionArg: false }, "2", "2", false), "'update.sh'");
assert.equal(tools.updaterCommand({ kind: "PassthruScript", storePathOrRepoPath: "update.sh", acceptsVersionArg: false }, "2", "2", true), "'update.sh'");
assert.throws(() => tools.updaterCommand({ kind: "PassthruScript", storePathOrRepoPath: "update.sh", acceptsVersionArg: false }, "1", "2", true), /non-latest/);
assert.equal(tools.updaterCommand({ kind: "PassthruScript", storePathOrRepoPath: "a'b", acceptsVersionArg: true }, "2", "2", true), "'a'\\''b' '2'");
assert.equal(tools.updaterCommand({ kind: "NixUpdate", flakeAttr: "foo" }, "2", "2", true), "nix-update --flake 'foo' --version '2'");
assert.deepEqual(tools.discoverReleaseSource('url = "https://registry.npmjs.org/@bastani/atomic/-/atomic-${version}.tgz";'), { kind: "Npm", name: "@bastani/atomic" });
assert.deepEqual(tools.discoverReleaseSource('fetchFromGitHub { owner = "o"; repo = "r"; rev = "v${version}";\n}'), { kind: "GitHubRelease", owner: "o", repo: "r", tagPrefix: "v" });
assert.throws(() => tools.discoverReleaseSource("unclassifiable"), /cannot be classified/);
assert.throws(() => types.validateMap({ releaseSource: { kind: "Unknown" } }, "foo"), /invalid structured/);
const closureMap = {
  pinSet: [{ file: "pkgs/by-name/linear-cli/package.nix", field: "denoDeps.outputHash", value: "sha256-same", mustChange: false }],
  releaseSource: { kind: "GitHubRelease", owner: "schpet", repo: "linear-cli", tagPrefix: "v" },
  updater: { kind: "Manual" }, skillDeps: [],
  gateAttrs: { system: "aarch64-darwin", attrs: ["packages.aarch64-darwin.linear-cli"] },
};
const unwitnessedPin = { message: "Unwitnessed pin: pkgs/by-name/linear-cli/package.nix:denoDeps.outputHash — no gate attribute realizes it" };
assert.throws(() => types.validateMap(closureMap, "linear-cli"), unwitnessedPin);
console.log("PASS unchanged closure pin without witness attribute blocks");
closureMap.pinSet[0].witnessAttr = "packages.x86_64-linux.linear-cli.denoDeps";
assert.throws(() => types.validateMap(closureMap, "linear-cli"), unwitnessedPin);
console.log("PASS closure witness omitted from build attributes blocks");
closureMap.gateAttrs.attrs.push(closureMap.pinSet[0].witnessAttr);
assert.deepEqual(types.validateMap(closureMap, "linear-cli"), closureMap);
console.log("PASS cross-system closure witness included in build attributes passes");
assert.throws(() => tools.scopeGate({ "pkgs/by-name/foo/package.nix": "1", other: "old" }, { "pkgs/by-name/foo/package.nix": "2", other: "new" }, ["pkgs/by-name/foo"]), /Out-of-scope/);
assert.deepEqual(tools.scopeGate({ outside: "old" }, { outside: "old", "pkgs/by-name/foo/package.nix": "2" }, ["pkgs/by-name/foo"]), ["pkgs/by-name/foo/package.nix"]);
const pins = { pinSet: [{ file: "p", field: "version", value: "1.0.0", mustChange: true }, { file: "p", field: "npmDepsHash", value: "sha256-same", mustChange: false }] };
assert.deepEqual(tools.pinGate(pins, { p: 'version = "1.0.0"; npmDepsHash = "sha256-same";' }, { p: 'version = "2.0.0"; npmDepsHash = "sha256-same";' }), [
  { file: "p", field: "version", mustChange: true, expected: { baseline: "1.0.0", relation: "changed" }, observed: "2.0.0", ok: true },
  { file: "p", field: "npmDepsHash", mustChange: false, expected: { baseline: "sha256-same", relation: "build-witnessed" }, observed: "sha256-same", ok: true },
]);
console.log("PASS pin evidence reports baseline predicates and observed literals, not expected new hashes");
assert.throws(() => tools.pinGate(pins, { p: 'version = "1.0.0"; npmDepsHash = "sha256-same";' }, { p: 'version = "1.0.0"; npmDepsHash = "sha256-same";' }), /Required pin unchanged/);
tools.pinGate(pins, { p: 'version = "1.0.0"; npmDepsHash = "sha256-same";' }, { p: 'version = "1.0.0-beta"; npmDepsHash = "sha256-same";' });
const sharedHashPins = { pinSet: [{ file: "p", field: "src.hash", value: "sha256-old", mustChange: true }, { file: "p", field: "npmDepsHash", value: "sha256-old", mustChange: false }] };
tools.pinGate(sharedHashPins, { p: 'src.hash="sha256-old"; npmDepsHash="sha256-old";' }, { p: 'src.hash="sha256-new"; npmDepsHash="sha256-old";' });
console.log("PASS F1 changed required field with identical optional dependency hash");
const sourcePin = { pinSet: [{ file: "p", field: "src.hash", value: "sha256-old", mustChange: true }] };
assert.throws(() => tools.pinGate(sourcePin, { p: 'src.hash="sha256-unchanged"; # sha256-old\n' }, { p: 'src.hash="sha256-unchanged"; # sha256-new\n' }), /Pin not observed/);
assert.throws(() => tools.pinGate(sourcePin, { p: 'src = fetchurl { hash="sha256-old"; }; other.hash="sha256-old";' }, { p: 'src = fetchurl { hash="sha256-old"; }; other.hash="sha256-new";' }), /Required pin unchanged/);
for (const current of [
  '/* src.hash="sha256-new"; */ other.hash="sha256-new";',
  'src.hash="sha256-new" + "suffix";',
  'src.hash="sha256-${version}";',
  'src.hash="sha256-new"; src = { hash="sha256-other"; };',
  'src = if condition then { hash="sha256-new"; } else { hash="sha256-other"; };',
  'src.${field}="sha256-new";',
  "postPatch = ''src.hash=\"sha256-new\";'';",
]) assert.throws(() => tools.pinGate(sourcePin, { p: 'src.hash="sha256-old";' }, { p: current }), /Unclassifiable pin/);
tools.pinGate(sourcePin, { p: 'src = fetchurl { hash="sha256-old"; };' }, { p: '/* src.hash="sha256-old"; */ src = fetchurl { hash="sha256-new"; };' });
for (const [pkg, fields] of [
  ["atomic", ["src.hash", "npmDepsHash"]],
  ["linear-cli", ["version", "binaries.aarch64-darwin.hash", "binaries.x86_64-darwin.hash", "src.hash", "denoDeps.outputHash"]],
]) {
  const file = `pkgs/by-name/${pkg}/package.nix`;
  const before = readFileSync(file, "utf8");
  const literals = pkg === "atomic" ? [...before.matchAll(/(?:hash|npmDepsHash) = "([^"]+)";/g)].map((m) => m[1]) : [...before.matchAll(/(?:version|hash|outputHash) = "([^"]+)";/g)].map((m) => m[1]);
  assert.equal(literals.length, fields.length);
  const map = { pinSet: fields.map((field, i) => ({ file, field, value: literals[i], mustChange: !["npmDepsHash", "denoDeps.outputHash"].includes(field) })) };
  const after = map.pinSet.reduce((body, pin) => pin.mustChange ? body.replace(JSON.stringify(pin.value), JSON.stringify(pin.value + "-updated")) : body, before);
  tools.pinGate(map, { [file]: before }, { [file]: after });
}
const manifestPin = { pinSet: [{ file: "manifest.json", field: "version", value: "1.0.0", mustChange: true }] };
tools.pinGate(manifestPin, { "manifest.json": '{"version":"1.0.0"}' }, { "manifest.json": '{"version":"1.0.0-beta","note":"1.0.0"}' });
assert.throws(() => tools.pinGate(manifestPin, { "manifest.json": '{"version":"unchanged","note":"1.0.0"}' }, { "manifest.json": '{"version":"unchanged","note":"2.0.0"}' }), /Pin not observed/);
console.log("PASS F1 named/comment boundaries, nested repository Nix pins, JSON manifest, nonliteral/ambiguous rejection");
const releaseSource = { kind: "GitHubRelease", owner: "example", repo: "sample", tagPrefix: "v" };
const releaseApi = "https://api.github.com/repos/example/sample/releases";
async function releaseFixture(responses, action) {
  const original = globalThis.fetch, calls = [], signal = AbortSignal.timeout(5_000);
  globalThis.fetch = async (url, options) => {
    assert.equal(options.signal, signal);
    calls.push(String(url));
    return Response.json(responses[String(url)] ?? {}, { status: Object.hasOwn(responses, String(url)) ? 200 : 404 });
  };
  try { await action(signal, calls); } finally { globalThis.fetch = original; }
}
await releaseFixture({ [`${releaseApi}/tags/v2.0.0-rc.1`]: { tag_name: "v2.0.0-rc.1" } }, async (signal, calls) => {
  assert.equal((await tools.resolveRelease(releaseSource, "2.0.0-rc.1", signal)).version, "2.0.0-rc.1");
  assert.deepEqual(calls, [`${releaseApi}/tags/v2.0.0-rc.1`]);
});
console.log("PASS F2 existing explicit prerelease resolves without latest metadata");
const versionScript = { kind: "PassthruScript", storePathOrRepoPath: "update.sh", acceptsVersionArg: true };
const latestScript = { ...versionScript, acceptsVersionArg: false };
await releaseFixture({ [`${releaseApi}/latest`]: { tag_name: "release-3.0.0" }, [`${releaseApi}/tags/v2.0.0`]: { tag_name: "v2.0.0" } }, async (signal, calls) => {
  const release = await tools.resolveRelease(releaseSource, "2.0.0", signal);
  assert.equal(await tools.resolveUpdaterCommand(versionScript, release, true, signal), "'update.sh' '2.0.0'");
  assert.equal(await tools.resolveUpdaterCommand({ kind: "NixUpdate", flakeAttr: "sample" }, release, true, signal), "nix-update --flake 'sample' --version '2.0.0'");
  assert.deepEqual(calls, [`${releaseApi}/tags/v2.0.0`]);
  await assert.rejects(tools.resolveUpdaterCommand(latestScript, release, true, signal), /Unclassifiable latest tag/);
});
await releaseFixture({ [`${releaseApi}/tags/v2.0.0-rc.1`]: { tag_name: "v2.0.0-rc.1" } }, async (signal, calls) => {
  const release = await tools.resolveRelease(releaseSource, "2.0.0-rc.1", signal);
  assert.equal(await tools.resolveUpdaterCommand(versionScript, release, true, signal), "'update.sh' '2.0.0-rc.1'");
  assert.deepEqual(calls, [`${releaseApi}/tags/v2.0.0-rc.1`]);
  await assert.rejects(tools.resolveUpdaterCommand(latestScript, release, true, signal), /HTTP 404/);
});
await releaseFixture({ [`${releaseApi}/latest`]: { tag_name: "v2.0.0" }, [`${releaseApi}/tags/v2.0.0`]: { tag_name: "v2.0.0" }, [`${releaseApi}/tags/v1.0.0`]: { tag_name: "v1.0.0" } }, async (signal, calls) => {
  const omitted = await tools.resolveRelease(releaseSource, undefined, signal);
  assert.equal(omitted.version, "2.0.0");
  const lookups = calls.length;
  assert.equal(await tools.resolveUpdaterCommand(latestScript, omitted, false, signal), "'update.sh'");
  assert.equal(calls.length, lookups);
  const exact = await tools.resolveRelease(releaseSource, "2.0.0", signal);
  assert.equal(await tools.resolveUpdaterCommand(latestScript, exact, true, signal), "'update.sh'");
  const old = await tools.resolveRelease(releaseSource, "1.0.0", signal);
  await assert.rejects(tools.resolveUpdaterCommand(latestScript, old, true, signal), /non-latest/);
  await assert.rejects(tools.resolveRelease(releaseSource, "missing", signal), /HTTP 404/);
});
const npmApi = "https://registry.npmjs.org/sample";
await releaseFixture({ [`${npmApi}/latest`]: { version: "2.0.0" }, [`${npmApi}/2.0.0`]: { version: "2.0.0", dist: { tarball: "https://example.test/sample.tgz" } } }, async (signal) => {
  assert.equal((await tools.resolveRelease({ kind: "Npm", name: "sample" }, undefined, signal)).version, "2.0.0");
});
await releaseFixture({ [`${npmApi}/2.0.0-rc.1`]: { version: "2.0.0-rc.1", dist: { tarball: "https://example.test/sample.tgz" } } }, async (signal, calls) => {
  const release = await tools.resolveRelease({ kind: "Npm", name: "sample" }, "2.0.0-rc.1", signal);
  assert.equal(await tools.resolveUpdaterCommand(versionScript, release, true, signal), "'update.sh' '2.0.0-rc.1'");
  assert.deepEqual(calls, [`${npmApi}/2.0.0-rc.1`]);
});
assert(position("map-derivation") < position("validate-updater-target") && position("validate-updater-target") < plan);
console.log("PASS F2 historical/different-prefix, npm, omitted latest, explicit latest-only acceptance/rejection and fail-closed metadata");
const fixture = await mkdtemp(resolve(".atomic/workflows/runs/bump-derivation/helper-check-"));
const abortLog = resolve(fixture, "abort.json");
const controller = new AbortController();
const abortedCapture = tools.capture(fixture, "printf 'stdout-before-abort\\n'; printf 'stderr-before-abort\\n' >&2; sleep 2", controller.signal, "abort.json");
const rejectedCapture = assert.rejects(abortedCapture, { name: "AbortError" });
try {
  for (let i = 0; i < 100 && (!existsSync(resolve(fixture, "abort.log.stream.jsonl")) || !readFileSync(resolve(fixture, "abort.log.stream.jsonl"), "utf8").includes("stderr-before-abort")); i++) await delay(10);
  const running = JSON.parse(readFileSync(abortLog, "utf8"));
  assert.equal(running.state, "running");
  const live = readFileSync(resolve(fixture, `${running.logPath}.stream.jsonl`), "utf8");
  assert.match(live, /stdout-before-abort/);
  assert.match(live, /stderr-before-abort/);
} finally { controller.abort(); await rejectedCapture; }
assert(existsSync(abortLog), "aborted capture must persist its observation");
const interrupted = JSON.parse(readFileSync(abortLog, "utf8"));
assert.match(readFileSync(resolve(fixture, interrupted.logPath), "utf8"), /stdout-before-abort/);
assert.match(readFileSync(resolve(fixture, interrupted.logPath), "utf8"), /stderr-before-abort/);
checkCheckpoint(interrupted);
assert.equal(interrupted.state, "interrupted");
assert.notEqual(interrupted.exitCode, 0);
console.log("PASS F3 cancelled capture rejects with persisted partial stdout/stderr and interruption state");
const deadlineStart = Date.now();
await assert.rejects(tools.capture(fixture, "sleep 2 & child=$!; printf 'shell=%s child=%s\\n' $$ $child; printf 'deadline-stderr\\n' >&2; wait", AbortSignal.timeout(150), "deadline.json"), (error) => {
  assert.equal(error.name, "AbortError");
  assert.match(error.receipt.tail, /shell=\d+ child=\d+/);
  assert.match(error.receipt.tail, /deadline-stderr/);
  checkCheckpoint(error.receipt);
  return true;
});
assert(Date.now() - deadlineStart < 1_500, "deadline must not wait for the sleeping descendant");
const deadline = JSON.parse(readFileSync(resolve(fixture, "deadline.json"), "utf8"));
assert.equal(deadline.state, "interrupted");
assert.notEqual(deadline.exitCode, 0);
assert.match(deadline.tail, /deadline-stderr/);
for (const pid of deadline.tail.match(/shell=(\d+) child=(\d+)/).slice(1).map(Number)) {
  let alive = true;
  for (let i = 0; i < 100 && alive; i++) {
    try { process.kill(pid, 0); await delay(10); }
    catch (error) { assert.equal(error.code, "ESRCH"); alive = false; }
  }
  assert.equal(alive, false, `capture process ${pid} must be gone`);
}
const failed = await tools.capture(fixture, "printf failure >&2; exit 7", AbortSignal.timeout(1_000), "failed.json");
assert.equal(failed.exitCode, 7);
assert.equal(failed.state, "exited");
assert.throws(() => tools.requireSuccess(failed), /exit 7/);
await assert.rejects(tools.capture(resolve(fixture, "absent-cwd"), "true", AbortSignal.timeout(1_000)), { code: "ENOENT" });
const success = await tools.capture(fixture, "printf success", AbortSignal.timeout(1_000), "success.json");
assert.equal(tools.requireSuccess(success), "success");
assert.equal(success.state, "exited");
console.log("PASS F3 live channel log, finite deadline, process-group cleanup, nonzero exit and unrelated spawn error");
const modeTree = resolve(fixture, "mode-tree");
await mkdir(modeTree);
const modeFile = resolve(modeTree, "README.md");
await writeFile(modeFile, "controlled fixture bytes\n");
const savedGit = { GIT_DIR: process.env.GIT_DIR, GIT_WORK_TREE: process.env.GIT_WORK_TREE };
process.env.GIT_DIR = resolve(".git");
process.env.GIT_WORK_TREE = modeTree;
try {
  const signal = AbortSignal.timeout(10_000);
  await chmod(modeFile, 0o644);
  const before = await tools.snapshot(modeTree, signal);
  await chmod(modeFile, 0o755);
  const after = await tools.snapshot(modeTree, signal);
  assert.throws(() => tools.scopeGate(before, after, []), /Out-of-scope edits: README.md/);
  assert.deepEqual(tools.scopeGate(before, after, ["README.md"]), ["README.md"]);
  assert.deepEqual(tools.scopeGate(after, await tools.snapshot(modeTree, signal), []), []);
  await chmod(modeFile, 0o600);
  assert.deepEqual(tools.scopeGate(before, await tools.snapshot(modeTree, signal), []), []);
  console.log("PASS F4 outside-prefix executable mode blocks, allowed mode classified, unchanged baseline and non-executable permissions preserved");
} finally {
  for (const [key, value] of Object.entries(savedGit)) { if (value === undefined) delete process.env[key]; else process.env[key] = value; }
}
assert.equal(types.witness("probe", { ok: false, error: "failed" }, () => { throw new Error("must not project failed tool"); }), null);
const observed = types.witness("probe", { ok: true, value: { landed: false } }, (v) => ({ value: v.landed, evidence: "observed false" }));
assert.equal(observed.value, false);
assert.equal(observed.evidence, "observed false");
console.log("PASS pure regressions: updater variants/latest-only, unknown constructors, release classification, scope preservation, required/optional pins, failed and negative tool witnesses");
const negativeFile = resolve(".atomic/workflows/bump/witness-negative.ts");
const negativeText = 'import { completedRun, type Witness, type CompletedOutputs } from "./types.js"; declare const rest: Omit<CompletedOutputs, "landed" | "changes">; declare const landed: Witness<boolean>; declare const changes: Witness<string[]>; completedRun(true, changes, rest); completedRun(landed, [], rest);';
const host = ts.createCompilerHost(options);
const getSource = host.getSourceFile.bind(host);
host.getSourceFile = (file, languageVersion, ...args) => resolve(file) === negativeFile ? ts.createSourceFile(file, negativeText, languageVersion, true) : getSource(file, languageVersion, ...args);
const negative = ts.createProgram([negativeFile], options, host);
const errors = ts.getPreEmitDiagnostics(negative).filter((d) => d.file && resolve(d.file.fileName) === negativeFile);
assert.equal(errors.filter((d) => d.code === 2345).length, 2, "literal landed and changes must each be rejected by TypeScript");
assert(text.includes('...RECON, ...READ_ONLY'));
assert(text.includes('tools: ["read", "search", "find", "ls"]'));
assert(text.includes('mcp: { allow: [] }'));
function checkTools(n) {
  if (ts.isCallExpression(n) && n.expression.getText(source) === "ctx.tool") {
    assert(n.arguments.at(-1).getText(source).includes("timeoutMs"), "tool callback needs finite timeout option");
    assert(n.arguments[2].getText(source).includes("signal"), "tool callback must forward signal");
    assert(n.arguments[2].getText(source).includes("processCheckpoint("), "process evidence must cross the compact checkpoint boundary");
  }
  ts.forEachChild(n, checkTools);
}
checkTools(source);
console.log("PASS negative type witnesses; read-only recon allowlist; timeout and cancellation call sites");
const deliveredFixture = resolve(fixture, "delivery");
const upstreamFixture = resolve(fixture, "upstream", "skills/sample");
for (const directory of [deliveredFixture, upstreamFixture]) {
  await mkdir(resolve(directory, "references"), { recursive: true });
  await writeFile(resolve(directory, "SKILL.md"), "skill\n");
  await writeFile(resolve(directory, "references/commands.md"), "commands\n");
}
assert.deepEqual(await tools.verifyVendored(fixture, deliveredFixture, resolve(fixture, "upstream"), "skills/sample", AbortSignal.timeout(5_000), "delivery.json"), { upstreamSubtree: "skills/sample", deliveredPath: deliveredFixture, comparedFiles: 2, identical: true });
await writeFile(resolve(deliveredFixture, "SKILL.md"), "different\n");
await assert.rejects(tools.verifyVendored(fixture, deliveredFixture, resolve(fixture, "upstream"), "skills/sample", AbortSignal.timeout(5_000), "delivery-different.json"), /exit 1/);
console.log("PASS vendored evidence enumerates subtree, delivered path and compared file count; differences block");
for (const kind of ["NpmBundled", "SrcCarried"]) {
  const npm = kind === "NpmBundled", packageRoot = `vendored/${kind}`;
  const subtree = npm ? "dist/builtin" : "skills/sample", archivePrefix = npm ? "package" : "";
  const sources = ["1.0.0", "2.0.0"].map((version) => resolve(fixture, kind, version));
  for (const [index, source] of sources.entries()) {
    const content = resolve(source, archivePrefix, subtree);
    await mkdir(content, { recursive: true });
    await writeFile(resolve(content, "kept.md"), `release ${index + 1}\n`);
    if (index === 0) await writeFile(resolve(content, "removed.md"), "removed in next release\n");
    tools.requireSuccess(await tools.capture(fixture, `tar -c${npm ? "z" : ""}f ${tools.quote(source + ".tar")} -C ${tools.quote(source)} ${tools.quote(archivePrefix || subtree)}`, AbortSignal.timeout(10_000)));
  }
  const artifacts = [];
  for (const [attempt, source] of [sources[0], sources[1], sources[1]].entries()) {
    const extracted = await tools.vendoredDirectory(fixture, packageRoot, 0);
    artifacts.push(extracted);
    const command = npm
      ? `curl --fail --location ${tools.quote("file://" + source + ".tar")} | tar -xz --strip-components=1 -C ${tools.quote(extracted)}`
      : `cat ${tools.quote(source + ".tar")} | tar -x -C ${tools.quote(extracted)}`;
    tools.requireSuccess(await tools.capture(fixture, command, AbortSignal.timeout(10_000), `${kind}-extract-${attempt}.json`));
    const comparison = await tools.capture(fixture, `diff -r ${tools.quote(resolve(source, archivePrefix, subtree))} ${tools.quote(resolve(extracted, subtree))}`, AbortSignal.timeout(10_000), `${kind}-diff-${attempt}.json`);
    assert.equal(comparison.exitCode, 0, `${kind} comparison ${attempt + 1}: ${comparison.stdout}`);
  }
  assert.equal(new Set(artifacts).size, 3, "Each comparison, including the same release again, needs its own artifact");
  for (const [index, source] of sources.entries()) {
    assert.equal(resolve(artifacts[index], ".."), resolve(fixture, packageRoot), "Extraction stays under package artifacts");
    const preserved = await tools.capture(fixture, `diff -r ${tools.quote(resolve(source, archivePrefix, subtree))} ${tools.quote(resolve(artifacts[index], subtree))}`, AbortSignal.timeout(10_000), `${kind}-preserved-${index}.json`);
    assert.equal(preserved.exitCode, 0, `Earlier ${kind} artifact must remain unchanged: ${preserved.stdout}`);
  }
  console.log(`PASS F5 ${kind} release deletion and same-version repeat compare cleanly; earlier artifacts unchanged`, artifacts);
}
