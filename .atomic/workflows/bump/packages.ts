import type { ReleaseSource, SkillDep } from "./types.js";

export type PackageEntry = { releaseSource?: ReleaseSource; skillDeps: SkillDep[] };
const skills = "modules/home/ai/plugins/planning-and-development/.apm/skills";
const safety = `${skills}/linear-project-management/references/linear-workspace-safety-gate.md`;
const mapping = `${skills}/openspec-linear-sync/references/linear-cli-mapping.md`;

export const packages: Record<string, PackageEntry> = {
  atomic: {
    releaseSource: { kind: "Npm", name: "@bastani/atomic" },
    skillDeps: [{
      kind: "Vendored", pinKind: "NpmBundled", upstreamSubtree: "dist/builtin",
      deliveryExpr: "${pkgs.atomic}/lib/node_modules/@bastani/atomic/dist/builtin",
    }],
  },
  "linear-cli": {
    releaseSource: { kind: "GitHubRelease", owner: "schpet", repo: "linear-cli", tagPrefix: "v" },
    skillDeps: [
      { kind: "Vendored", pinKind: "SrcCarried", deliveryExpr: "${pkgs.linear-cli.src}/skills", upstreamSubtree: "skills/linear-cli" },
      {
        kind: "SelfMaintained", skillPath: `${skills}/linear-project-management`, dependsOn: { kind: "Package" },
        citedClaims: [
          { file: safety, lines: "12-14", text: "Every linear-cli read or mutation must pass an explicit workspace-selecting `--workspace <slug>`; refuse commands that do not expose that selector.", verifiedAgainst: "v2.6.0" },
          { file: safety, lines: "29", text: "These were verified against v2.6.0; re-check them against the pinned version on any linear-cli bump, since a reordering of the tiers would silently change which workspace a mutation hits.", verifiedAgainst: "src/utils/graphql.ts and src/config.ts v2.6.0" },
          { file: safety, lines: "50", text: "linear-cli throws when both `LINEAR_API_KEY` and a `--workspace` flag are nonempty", verifiedAgainst: "src/utils/graphql.ts v2.6.0" },
          { file: safety, lines: "66", text: "Pass the workspace-selecting `--workspace <slug>` on every read or mutation; refuse commands without that selector, including `label list`, whose boolean filter was verified against v2.6.0.", verifiedAgainst: "v2.6.0" },
          { file: safety, lines: "31-53", text: "The credential precedence has five tiers, highest first, verified against v2.6.0 in `getResolvedApiKey` and `resolveRawOption`:; The shell-env assertion is necessary but not sufficient: `loadEnvFiles` can read a `./.env` or git-root `.env` and inject `LINEAR_*` keys into its process, invisible to a shell check.", verifiedAgainst: "src/utils/graphql.ts and src/config.ts v2.6.0" },
          { file: `${skills}/linear-project-management/references/linear-conventions.md`, lines: "22", text: "both `linear issue create` and `linear issue update` accept `-a self` (or `--assignee self`), which linear-cli resolves against the confirmed workspace identity", verifiedAgainst: "v2.6.0" },
        ],
      },
      {
        kind: "SelfMaintained", skillPath: `${skills}/openspec-linear-sync`, dependsOn: { kind: "VendoredSkill", name: "linear-cli" },
        citedClaims: [
          { file: mapping, lines: "31-43", text: "linear auth whoami; linear team list; linear project list; linear label list; linear issue query; linear issue view; linear issue comment list; linear issue update; linear issue comment add; linear document list; linear document create; linear document update", verifiedAgainst: "linear-cli bundled skill references" },
          { file: mapping, lines: "66-70", text: "linear document update <stored-id> --title; linear document list --project <p> --json; linear document create --project <p> --title", verifiedAgainst: "linear-cli references/document.md" },
          { file: mapping, lines: "75-80", text: "linear api; linear schema", verifiedAgainst: "linear-cli references/api.md and references/schema.md" },
          { file: mapping, lines: "13", text: "A command that omits `--workspace` can resolve through environment or config credentials before reaching the credentials default, so do not rely on an ambient workspace: an unscoped read can query the wrong workspace exactly as an unscoped mutation can write to it.", verifiedAgainst: "src/utils/graphql.ts and src/config.ts v2.6.0" },
          { file: mapping, lines: "28", text: "Every command, read or mutation, passes an explicit `--workspace <slug>` after the `linear auth whoami` gate has confirmed the workspace, because a command lacking it can resolve through environment or config credentials before reaching the credentials default, so do not rely on an ambient workspace.", verifiedAgainst: "src/utils/graphql.ts and src/config.ts v2.6.0" },
          { file: mapping, lines: "4", text: "Verbs are at linear-cli v2.6.0.", verifiedAgainst: "v2.6.0" },
          { file: mapping, lines: "96", text: "The concrete flags and the two `.nodes[]` jq filters below are illustrative at linear-cli v2.0.0", verifiedAgainst: "v2.0.0 (historical worked example)" },
        ],
      },
    ],
  },
};
