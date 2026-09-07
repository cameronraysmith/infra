import { Type, type Static } from "typebox";
import { Value } from "typebox/value";

export const ReleaseSource = Type.Union([
  Type.Object({ kind: Type.Literal("GitHubRelease"), owner: Type.String(), repo: Type.String(), tagPrefix: Type.String() }),
  Type.Object({ kind: Type.Literal("Npm"), name: Type.String() }),
]);
export type ReleaseSource = Static<typeof ReleaseSource>;

export const Updater = Type.Union([
  Type.Object({ kind: Type.Literal("PassthruScript"), storePathOrRepoPath: Type.String(), acceptsVersionArg: Type.Boolean() }),
  Type.Object({ kind: Type.Literal("NixUpdate"), flakeAttr: Type.String() }),
  Type.Object({ kind: Type.Literal("Manual") }),
]);
export type Updater = Static<typeof Updater>;

export const Claim = Type.Object({ file: Type.String(), lines: Type.String(), text: Type.String(), verifiedAgainst: Type.String() });
export type Claim = Static<typeof Claim>;
export const SkillDep = Type.Union([
  Type.Object({
    kind: Type.Literal("Vendored"), deliveryExpr: Type.String(), upstreamSubtree: Type.String(),
    pinKind: Type.Union([Type.Literal("SrcCarried"), Type.Literal("ApmGitDep"), Type.Literal("NpmBundled")]),
  }),
  Type.Object({
    kind: Type.Literal("SelfMaintained"), skillPath: Type.String(),
    dependsOn: Type.Union([
      Type.Object({ kind: Type.Literal("Package") }),
      Type.Object({ kind: Type.Literal("VendoredSkill"), name: Type.String() }),
    ]),
    citedClaims: Type.Array(Claim),
  }),
]);
export type SkillDep = Static<typeof SkillDep>;

export const DerivationMap = Type.Object({
  pinSet: Type.Array(Type.Object({ file: Type.String(), field: Type.String(), value: Type.String(), mustChange: Type.Boolean(), witnessAttr: Type.Optional(Type.String()) }), { minItems: 1 }),
  releaseSource: ReleaseSource,
  updater: Updater,
  skillDeps: Type.Array(SkillDep),
  gateAttrs: Type.Object({ system: Type.String(), attrs: Type.Array(Type.String(), { minItems: 1, description: "Flake attribute paths without the .# prefix, for example checks.aarch64-darwin.package-linear-cli." }) }),
});
export type DerivationMap = Static<typeof DerivationMap>;
export function unreachable(value: never): never { throw new Blocked(`Unknown constructor: ${JSON.stringify(value)}`); }
export class Blocked extends Error {}
export const relativePath = (path: string): boolean => path.length > 0 && !path.startsWith("/") && !path.split("/").some((p) => p === ".." || p === "." || p === "");
export const within = (path: string, prefix: string): boolean => path === prefix || path.startsWith(`${prefix}/`);

export function validateMap(value: unknown, pkg: string): DerivationMap {
  if (!Value.Check(DerivationMap, value)) throw new Blocked("map-derivation returned an invalid structured manifest");
  if (value.gateAttrs.attrs.some((a) => a.includes("#"))) throw new Blocked("Gate attributes must omit the .# prefix and contain no #");
  if (!/^[a-z0-9_]+-[a-z0-9]+$/.test(value.gateAttrs.system) || value.gateAttrs.attrs.some((a) => !/^[A-Za-z0-9_][A-Za-z0-9._+-]*$/.test(a))) throw new Blocked("Invalid gate attributes");
  for (const pin of value.pinSet) {
    if (!relativePath(pin.file) || !within(pin.file, `pkgs/by-name/${pkg}`) || !pin.field || !pin.value) throw new Blocked("Invalid pin boundary or missing field/value");
    if (!pin.mustChange && (!pin.witnessAttr || !value.gateAttrs.attrs.includes(pin.witnessAttr))) throw new Blocked(`Unwitnessed pin: ${pin.file}:${pin.field} — no gate attribute realizes it`);
    if (pin.witnessAttr !== undefined && !/^[A-Za-z0-9_][A-Za-z0-9._+-]*$/.test(pin.witnessAttr)) throw new Blocked("Invalid witness attribute");
  }
  for (const dep of value.skillDeps) {
    switch (dep.kind) {
      case "Vendored":
        if (!relativePath(dep.upstreamSubtree)) throw new Blocked("Invalid upstream subtree");
        break;
      case "SelfMaintained":
        if (!relativePath(dep.skillPath)) throw new Blocked("Invalid skill path");
        for (const claim of dep.citedClaims) if (!relativePath(claim.file) || !within(claim.file, dep.skillPath)) throw new Blocked("Claim outside skill path");
        switch (dep.dependsOn.kind) {
          case "Package": break;
          case "VendoredSkill":
            if (!value.skillDeps.some((d) => d.kind === "Vendored" && d.upstreamSubtree.split("/").includes(dep.dependsOn.kind === "VendoredSkill" ? dep.dependsOn.name : ""))) throw new Blocked("Missing vendored skill dependency");
            break;
          default: unreachable(dep.dependsOn);
        }
        break;
      default: unreachable(dep);
    }
  }
  return value;
}

const sameClaim = (a: Claim, b: Claim): boolean => a.file === b.file && a.lines === b.lines && a.text === b.text && a.verifiedAgainst === b.verifiedAgainst;
const sameSkillIdentity = (a: SkillDep, b: SkillDep): boolean => {
  switch (a.kind) {
    case "Vendored": return b.kind === "Vendored" && a.deliveryExpr === b.deliveryExpr && a.upstreamSubtree === b.upstreamSubtree && a.pinKind === b.pinKind;
    case "SelfMaintained": return b.kind === "SelfMaintained" && a.skillPath === b.skillPath && a.dependsOn.kind === b.dependsOn.kind && (a.dependsOn.kind === "Package" || (b.dependsOn.kind === "VendoredSkill" && a.dependsOn.name === b.dependsOn.name));
    default: return unreachable(a);
  }
};
export function verifyRegistrySkills(registry: SkillDep[], recon: SkillDep[]): { deps: SkillDep[]; claims: Array<{ skillPath: string; claim: Claim }> } {
  const claims: Array<{ skillPath: string; claim: Claim }> = [];
  for (const dep of registry) {
    const matches = recon.filter((candidate) => sameSkillIdentity(dep, candidate));
    if (matches.length !== 1) throw new Blocked(`Registry skill dependency drift: ${dep.kind === "Vendored" ? dep.deliveryExpr : dep.skillPath}`);
    const matched = matches[0];
    if (dep.kind === "SelfMaintained" && matched.kind === "SelfMaintained") {
      for (const claim of dep.citedClaims) {
        if (!matched.citedClaims.some((candidate) => sameClaim(claim, candidate))) throw new Blocked(`Registry claim drift: ${claim.file}:${claim.lines}`);
      }
      for (const claim of matched.citedClaims) {
        if (!dep.citedClaims.some((registered) => sameClaim(claim, registered))) claims.push({ skillPath: dep.skillPath, claim });
      }
    }
  }
  return { deps: recon.filter((dep) => !registry.some((registered) => sameSkillIdentity(dep, registered))), claims };
}

export function validateClaimReplacement(previous: Claim, replacement: Claim | undefined, content: string, version: string): Claim | null {
  if (previous.text.split("; ").every((part) => content.includes(part))) return null;
  const location = replacement?.lines.match(/^([1-9][0-9]*)(?:-([1-9][0-9]*))?$/);
  const start = Number(location?.[1]), end = Number(location?.[2] ?? location?.[1]);
  const lines = content.split("\n");
  const excerpt = lines.slice(start - 1, end).join("\n");
  if (!replacement || replacement.file !== previous.file || replacement.verifiedAgainst !== `v${version}` || !location || end < start || end > lines.length || !replacement.text.trim() || !replacement.text.split("; ").every((part) => part.trim() && excerpt.includes(part))) throw new Blocked(`Registry replacement missing or not observed: ${previous.file}:${previous.lines}`);
  return replacement;
}
/** Assertions about effects can only enter completion through a tool outcome. */
declare const witnessBrand: unique symbol;
export type Witness<T> = { readonly [witnessBrand]: true; readonly value: T; readonly source: string; readonly evidence: string };
export type ToolOutcome<T> = { readonly ok: true; readonly value: T } | { readonly ok: false; readonly error: unknown };
export const witness = <A, T>(source: string, outcome: ToolOutcome<A>, read: (value: A) => { value: T; evidence: string }): Witness<T> | null =>
  outcome.ok ? ({ source, ...read(outcome.value) } as Witness<T>) : null;
export type CompletedOutputs = {
  status: string; summary: string; package: string; target_version: string; recon_artifact: string;
  build_log: string; build_attempts: number; review_verdict: string; landed: boolean; changes: string[];
  skill_deps_verified: boolean; self_maintained_repaired: string[];
};
export const completedRun = (landed: Witness<boolean>, changes: Witness<string[]>, rest: Omit<CompletedOutputs, "landed" | "changes">): CompletedOutputs => ({ ...rest, landed: landed.value, changes: changes.value });
