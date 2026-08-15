import { execFile } from "node:child_process";
import { realpath, stat } from "node:fs/promises";
import { basename, dirname, isAbsolute, join, relative, resolve, sep } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export const policyPresent = true;

export type EditWriteOperation = "edit" | "write";

export type PolicyDecision =
  | { readonly decision: "allow" }
  | { readonly decision: "prompt"; readonly reason: string }
  | { readonly decision: "block"; readonly reason: string };

export interface MutableTarget {
  readonly kind: "mutable";
  readonly canonicalPath: string;
}

export interface ImmutableTarget {
  readonly kind: "immutable";
  readonly canonicalPath: string;
  readonly root: string;
}

export interface JjCurrentState {
  readonly changeId: string;
  readonly commitId: string;
  readonly conflicted: boolean;
  readonly divergent: boolean;
  readonly parentCount: number;
}

interface JjCommonState {
  readonly root: string;
  readonly at: JjCurrentState;
  readonly defaultBookmarksAtCurrent: readonly ("main" | "master")[];
}

export type WipState =
  | { readonly kind: "healthy" }
  | { readonly kind: "absent" }
  | { readonly kind: "moved" }
  | { readonly kind: "divergent" };

export type GitHead =
  | { readonly kind: "protected"; readonly branch: "main" | "master" }
  | { readonly kind: "feature"; readonly branch: string }
  | { readonly kind: "detached" };

export type RepositoryState =
  | { readonly kind: "outside-repository" }
  | {
      readonly kind: "git";
      readonly root: string;
      readonly head: GitHead;
    }
  | ({ readonly kind: "jj-ordinary" } & JjCommonState)
  | ({
      readonly kind: "jj-diamond";
      readonly join: {
        readonly conflicted: boolean;
        readonly parentCount: number;
        readonly parentsConflicted: boolean;
      };
      readonly wip: WipState;
    } & JjCommonState)
  | { readonly kind: "invalid"; readonly diagnostic: string };

export type EditWriteInput =
  | {
      readonly operation: EditWriteOperation;
      readonly target: ImmutableTarget;
    }
  | {
      readonly operation: EditWriteOperation;
      readonly target: MutableTarget;
      readonly repository: RepositoryState;
    };

export interface ProcessResult {
  readonly stdout: string;
  readonly stderr: string;
  readonly code: number;
}

export type GitRootResult =
  | { readonly kind: "inside"; readonly root: string }
  | { readonly kind: "outside" }
  | { readonly kind: "invalid"; readonly diagnostic: string };

export interface PolicyCapabilities {
  readonly filesystem: {
    canonicalize(target: string, cwd: string): Promise<string>;
    inspectionDirectory(target: string): Promise<string>;
    immutableRoots(): Promise<readonly string[]>;
  };
  readonly git: {
    root(directory: string): Promise<GitRootResult>;
    head(root: string): Promise<ProcessResult>;
  };
  readonly jj: {
    run(argv: readonly string[], cwd: string): Promise<ProcessResult>;
  };
  readonly interaction: {
    readonly available: boolean;
    confirm(message: string): Promise<boolean>;
  };
}

export interface ToolCallEvent {
  readonly toolName: string;
  readonly input: unknown;
}

export interface ToolCallContext {
  readonly cwd: string;
  readonly hasUI: boolean;
  readonly ui: {
    confirm(title: string, message: string): Promise<boolean>;
  };
}

export type ToolCallResult = { readonly block: true; readonly reason: string } | undefined;

export type DecisionFunction = (input: EditWriteInput) => PolicyDecision;
export type CapabilityFactory = (context: ToolCallContext) => PolicyCapabilities;

const jjRead = (...args: string[]): readonly string[] => ["jj", "--ignore-working-copy", ...args];

export const JJ_READ_ARGV = {
  root: jjRead("root"),
  current: jjRead(
    "log",
    "-r",
    "@",
    "--no-graph",
    "-T",
    'change_id ++ "\\t" ++ commit_id ++ "\\t" ++ conflict ++ "\\t" ++ empty ++ "\\t" ++ parents.len() ++ "\\n"',
  ),
  currentIdentity: (changeId: string) =>
    jjRead("log", "-r", changeId, "--no-graph", "-T", 'commit_id ++ "\\n"'),
  defaultBookmarks: jjRead(
    "bookmark",
    "list",
    "exact:main",
    "exact:master",
    "-T",
    'if(!remote, added_targets.map(|c| name ++ "\\t" ++ c.commit_id() ++ "\\n").join(""))',
  ),
  classifyWip: jjRead(
    "bookmark",
    "list",
    "exact:wip",
    "-T",
    'if(!remote, name ++ "\\t" ++ conflict ++ "\\n")',
  ),
  resolveWip: jjRead(
    "bookmark",
    "list",
    "exact:wip",
    "-T",
    'if(!remote, added_targets.map(|c| c.commit_id() ++ "\\t" ++ conflict ++ "\\n").join(""))',
  ),
  join: jjRead(
    "log",
    "-r",
    "@-",
    "--no-graph",
    "-T",
    'commit_id ++ "\\t" ++ conflict ++ "\\t" ++ empty ++ "\\t" ++ parents.len() ++ "\\n"',
  ),
  parents: jjRead(
    "log",
    "-r",
    "parents(@-)",
    "--no-graph",
    "-T",
    'commit_id ++ "\\t" ++ conflict ++ "\\n"',
  ),
} as const;

const block = (reason: string): PolicyDecision => ({ decision: "block", reason });
const allow = (): PolicyDecision => ({ decision: "allow" });

const containsPath = (root: string, target: string): boolean => {
  const suffix = relative(root, target);
  return (
    suffix === "" || (suffix !== ".." && !suffix.startsWith(`..${sep}`) && !isAbsolute(suffix))
  );
};

const unreachable = (state: never): never => {
  throw new Error(`unhandled repository state: ${JSON.stringify(state)}`);
};

const validateJjCommon = (state: JjCommonState, target: string): PolicyDecision | undefined => {
  if (!containsPath(state.root, target)) {
    return block("jj repository identity does not contain the canonical target");
  }
  if (state.at.conflicted) return block("jj current change is conflicted");
  if (state.at.divergent) return block("jj current change identity is divergent");
  if (state.defaultBookmarksAtCurrent.length > 0) {
    return block(
      `jj current change carries protected bookmark ${state.defaultBookmarksAtCurrent.join(", ")}`,
    );
  }
  return undefined;
};

export function decideEditWrite(input: EditWriteInput): PolicyDecision {
  if (!("repository" in input)) {
    return block(
      `Target ${input.target.canonicalPath} is contained by immutable root ${input.target.root}`,
    );
  }

  const repository = input.repository;
  const target = input.target.canonicalPath;
  switch (repository.kind) {
    case "outside-repository":
      return {
        decision: "prompt",
        reason: `${input.operation} targets a mutable path outside a recognized repository`,
      };
    case "git":
      if (!containsPath(repository.root, target)) {
        return block("Git repository identity does not contain the canonical target");
      }
      if (repository.head.kind === "protected") {
        return block(`Mutation on protected Git branch ${repository.head.branch} is blocked`);
      }
      return allow();
    case "jj-ordinary": {
      const unhealthy = validateJjCommon(repository, target);
      return unhealthy ?? allow();
    }
    case "jj-diamond": {
      const unhealthy = validateJjCommon(repository, target);
      if (unhealthy !== undefined) return unhealthy;
      if (repository.wip.kind !== "healthy") {
        return block(`diamond wip bookmark is ${repository.wip.kind}`);
      }
      if (repository.at.parentCount !== 1) {
        return block("diamond wip does not have exactly one parent");
      }
      if (repository.join.conflicted) return block("diamond join is conflicted");
      if (repository.join.parentCount < 2) {
        return block("diamond join has fewer than two parents");
      }
      if (repository.join.parentsConflicted) {
        return block("diamond join has a conflicted immediate parent");
      }
      return allow();
    }
    case "invalid":
      return block(`Repository inspection failed: ${repository.diagnostic}`);
    default:
      return unreachable(repository);
  }
}

const strictOutputLines = (text: string): readonly string[] | undefined => {
  if (text.length === 0) return [];
  if (!text.endsWith("\n")) return undefined;
  const lines = text.slice(0, -1).split("\n");
  return lines.some((line) => line.length === 0 || line.trim() !== line) ? undefined : lines;
};

const parseBoolean = (value: string): boolean | undefined => {
  if (value === "true") return true;
  if (value === "false") return false;
  return undefined;
};

const singleOutputLine = (output: string): string | undefined => {
  const normalized = output.replaceAll("\r\n", "\n");
  const line = normalized.endsWith("\n") ? normalized.slice(0, -1) : normalized;
  if (line.length === 0 || line.includes("\n") || line.includes("\r") || line.trim() !== line) {
    return undefined;
  }
  return line;
};

const validGitBranch = (branch: string): boolean => {
  const forbidden = ["~", "^", ":", "?", "*", "[", "\\"];
  const components = branch.split("/");
  return (
    branch !== "HEAD" &&
    !branch.startsWith("-") &&
    !branch.startsWith("/") &&
    !branch.endsWith("/") &&
    !branch.endsWith(".") &&
    !branch.includes("..") &&
    !branch.includes("@{") &&
    !branch.includes("//") &&
    !/[\u0000-\u0020\u007f]/u.test(branch) &&
    !forbidden.some((character) => branch.includes(character)) &&
    components.every(
      (component) =>
        component.length > 0 &&
        component !== "." &&
        component !== ".." &&
        !component.endsWith(".lock"),
    )
  );
};

const parseGitHead = (result: ProcessResult): GitHead | string => {
  if (result.code === 1 && result.stdout.length === 0 && result.stderr.length === 0) {
    return { kind: "detached" };
  }
  if (result.code !== 0) {
    return `Git head probe failed (${result.code}): ${result.stderr.trim()}`;
  }
  const branch = singleOutputLine(result.stdout);
  if (branch === undefined || !validGitBranch(branch)) return "Git head probe is malformed";
  if (branch === "main" || branch === "master") return { kind: "protected", branch };
  return { kind: "feature", branch };
};

interface CurrentRecord {
  readonly changeId: string;
  readonly commitId: string;
  readonly conflicted: boolean;
  readonly empty: boolean;
  readonly parentCount: number;
}

const parseCurrent = (result: ProcessResult): CurrentRecord | string => {
  if (result.code !== 0) {
    return `jj current probe failed (${result.code}): ${result.stderr.trim()}`;
  }
  const lines = strictOutputLines(result.stdout);
  if (lines === undefined) return "jj current probe is malformed";
  if (lines.length !== 1) return "jj current probe is ambiguous";
  const fields = lines[0].split("\t");
  if (fields.length !== 5) return "jj current probe is malformed";
  const conflicted = parseBoolean(fields[2]);
  const empty = parseBoolean(fields[3]);
  const parentCount = Number.parseInt(fields[4], 10);
  if (
    fields[0].length === 0 ||
    fields[1].length === 0 ||
    conflicted === undefined ||
    empty === undefined ||
    !/^\d+$/.test(fields[4]) ||
    !Number.isSafeInteger(parentCount)
  ) {
    return "jj current probe is malformed";
  }
  return {
    changeId: fields[0],
    commitId: fields[1],
    conflicted,
    empty,
    parentCount,
  };
};

interface JoinRecord {
  readonly commitId: string;
  readonly conflicted: boolean;
  readonly empty: boolean;
  readonly parentCount: number;
}

const parseJoin = (result: ProcessResult): JoinRecord | string => {
  if (result.code !== 0) {
    return `jj join probe failed (${result.code}): ${result.stderr.trim()}`;
  }
  const lines = strictOutputLines(result.stdout);
  if (lines === undefined || lines.length !== 1) return "jj join probe is malformed or ambiguous";
  const fields = lines[0].split("\t");
  if (fields.length !== 4) return "jj join probe is malformed";
  const conflicted = parseBoolean(fields[1]);
  const empty = parseBoolean(fields[2]);
  const parentCount = Number.parseInt(fields[3], 10);
  if (
    fields[0].length === 0 ||
    conflicted === undefined ||
    empty === undefined ||
    !/^\d+$/.test(fields[3]) ||
    !Number.isSafeInteger(parentCount)
  ) {
    return "jj join probe is malformed";
  }
  return { commitId: fields[0], conflicted, empty, parentCount };
};

const invalid = (diagnostic: string): RepositoryState => ({
  kind: "invalid",
  diagnostic,
});

const JJ_OUTSIDE_REPOSITORY_DIAGNOSTIC = /^Error: There is no jj repo in "[^"\r\n]+"\n$/;
const GIT_OUTSIDE_REPOSITORY_DIAGNOSTIC =
  "fatal: not a git repository (or any of the parent directories): .git\n";

const isCharacterizedJjOutsideRepository = (result: ProcessResult): boolean =>
  result.code === 1 &&
  result.stdout.length === 0 &&
  JJ_OUTSIDE_REPOSITORY_DIAGNOSTIC.test(result.stderr);

export const parseGitRootResult = (result: ProcessResult): GitRootResult => {
  if (result.code === 0) {
    const root = singleOutputLine(result.stdout);
    return root !== undefined && isAbsolute(root)
      ? { kind: "inside", root }
      : { kind: "invalid", diagnostic: "Git root probe is malformed or ambiguous" };
  }
  if (
    result.code === 128 &&
    result.stdout.length === 0 &&
    result.stderr === GIT_OUTSIDE_REPOSITORY_DIAGNOSTIC
  ) {
    return { kind: "outside" };
  }
  return {
    kind: "invalid",
    diagnostic: `Git root probe failed (${result.code}): ${result.stderr.trim()}`,
  };
};

const runJj = async (
  capabilities: PolicyCapabilities,
  argv: readonly string[],
  cwd: string,
): Promise<ProcessResult> => capabilities.jj.run(argv, cwd);

const inspectJj = async (
  root: string,
  target: string,
  cwd: string,
  capabilities: PolicyCapabilities,
): Promise<RepositoryState> => {
  if (!containsPath(root, target)) {
    return invalid("canonical jj root does not contain the canonical target");
  }

  const currentResult = await runJj(capabilities, JJ_READ_ARGV.current, cwd);
  const current = parseCurrent(currentResult);
  if (typeof current === "string") return invalid(current);

  const identityResult = await runJj(
    capabilities,
    JJ_READ_ARGV.currentIdentity(current.changeId),
    cwd,
  );
  if (identityResult.code !== 0) {
    return invalid(
      `jj current identity probe failed (${identityResult.code}): ${identityResult.stderr.trim()}`,
    );
  }
  const identities = strictOutputLines(identityResult.stdout);
  if (identities === undefined) return invalid("jj current identity probe is malformed");
  if (identities.length === 0) return invalid("jj current identity probe is empty");
  const divergent = identities.length !== 1 || identities[0] !== current.commitId;

  const defaultsResult = await runJj(capabilities, JJ_READ_ARGV.defaultBookmarks, cwd);
  if (defaultsResult.code !== 0) {
    return invalid(
      `jj default bookmark probe failed (${defaultsResult.code}): ${defaultsResult.stderr.trim()}`,
    );
  }
  const defaultBookmarkLines = strictOutputLines(defaultsResult.stdout);
  if (defaultBookmarkLines === undefined) {
    return invalid("jj default bookmark probe is malformed");
  }
  const defaultBookmarksAtCurrent: ("main" | "master")[] = [];
  for (const line of defaultBookmarkLines) {
    const fields = line.split("\t");
    if (
      fields.length !== 2 ||
      (fields[0] !== "main" && fields[0] !== "master") ||
      fields[1].length === 0
    ) {
      return invalid("jj default bookmark probe is malformed");
    }
    if (fields[1] === current.commitId) defaultBookmarksAtCurrent.push(fields[0]);
  }

  const common: JjCommonState = {
    root,
    at: {
      changeId: current.changeId,
      commitId: current.commitId,
      conflicted: current.conflicted,
      divergent,
      parentCount: current.parentCount,
    },
    defaultBookmarksAtCurrent,
  };

  const classificationResult = await runJj(capabilities, JJ_READ_ARGV.classifyWip, cwd);
  if (classificationResult.code !== 0) {
    return invalid(
      `jj wip classification probe failed (${classificationResult.code}): ${classificationResult.stderr.trim()}`,
    );
  }
  const classification = strictOutputLines(classificationResult.stdout);
  if (classification === undefined) return invalid("jj wip classification probe is malformed");
  if (classification.length === 0) {
    return { kind: "jj-ordinary", ...common };
  }
  if (classification.length !== 1) {
    return invalid("jj wip classification probe is ambiguous");
  }
  const classificationFields = classification[0].split("\t");
  const classificationDivergent = parseBoolean(classificationFields[1] ?? "");
  if (
    classificationFields.length !== 2 ||
    classificationFields[0] !== "wip" ||
    classificationDivergent === undefined
  ) {
    return invalid("jj wip classification probe is malformed");
  }

  const resolutionResult = await runJj(capabilities, JJ_READ_ARGV.resolveWip, cwd);
  if (resolutionResult.code !== 0) {
    return invalid(
      `jj wip resolution probe failed (${resolutionResult.code}): ${resolutionResult.stderr.trim()}`,
    );
  }
  const resolutionLines = strictOutputLines(resolutionResult.stdout);
  if (resolutionLines === undefined) return invalid("jj wip resolution probe is malformed");
  const resolutionRecords = resolutionLines.map((line) => line.split("\t"));
  const malformedResolution = resolutionRecords.some(
    (fields) =>
      fields.length !== 2 || fields[0].length === 0 || parseBoolean(fields[1]) === undefined,
  );
  if (malformedResolution) return invalid("jj wip resolution probe is malformed");

  let wip: WipState;
  if (classificationDivergent) {
    wip = { kind: "divergent" };
  } else if (resolutionRecords.length === 0) {
    wip = { kind: "absent" };
  } else if (
    resolutionRecords.length !== 1 ||
    resolutionRecords.some((fields) => parseBoolean(fields[1]) === true)
  ) {
    wip = { kind: "divergent" };
  } else if (resolutionRecords[0][0] !== current.commitId) {
    wip = { kind: "moved" };
  } else {
    wip = { kind: "healthy" };
  }

  const joinResult = await runJj(capabilities, JJ_READ_ARGV.join, cwd);
  const join = parseJoin(joinResult);
  if (typeof join === "string") return invalid(join);

  const parentsResult = await runJj(capabilities, JJ_READ_ARGV.parents, cwd);
  if (parentsResult.code !== 0) {
    return invalid(
      `jj immediate parent probe failed (${parentsResult.code}): ${parentsResult.stderr.trim()}`,
    );
  }
  const parentLines = strictOutputLines(parentsResult.stdout);
  if (parentLines === undefined) return invalid("jj immediate parent probe is malformed");
  let parentsConflicted = false;
  for (const line of parentLines) {
    const fields = line.split("\t");
    const conflicted = parseBoolean(fields[1] ?? "");
    if (fields.length !== 2 || fields[0].length === 0 || conflicted === undefined) {
      return invalid("jj immediate parent probe is malformed");
    }
    parentsConflicted ||= conflicted;
  }

  if (parentLines.length !== join.parentCount) {
    return invalid("jj immediate parent probe count does not match the join");
  }

  return {
    kind: "jj-diamond",
    ...common,
    wip,
    join: {
      conflicted: join.conflicted,
      parentCount: join.parentCount,
      parentsConflicted,
    },
  };
};

export async function inspectRepository(
  target: string,
  inspectionDirectory: string,
  capabilities: PolicyCapabilities,
): Promise<RepositoryState> {
  if (!isAbsolute(inspectionDirectory) || !containsPath(inspectionDirectory, target)) {
    return invalid("repository inspection directory does not contain the canonical target");
  }

  const jjRootResult = await runJj(capabilities, JJ_READ_ARGV.root, inspectionDirectory);
  let jjRoot: string | undefined;
  if (jjRootResult.code === 0) {
    const roots = strictOutputLines(jjRootResult.stdout);
    if (roots === undefined || roots.length !== 1 || !isAbsolute(roots[0])) {
      return invalid("jj root probe is malformed or ambiguous");
    }
    jjRoot = await capabilities.filesystem.canonicalize(roots[0], inspectionDirectory);
  } else if (!isCharacterizedJjOutsideRepository(jjRootResult)) {
    return invalid(`jj root probe failed (${jjRootResult.code}): ${jjRootResult.stderr.trim()}`);
  }

  const gitRootResult = await capabilities.git.root(inspectionDirectory);
  if (gitRootResult.kind === "invalid") return invalid(gitRootResult.diagnostic);
  const gitRoot =
    gitRootResult.kind === "inside"
      ? await capabilities.filesystem.canonicalize(gitRootResult.root, inspectionDirectory)
      : undefined;

  if (jjRoot !== undefined && gitRoot !== undefined && jjRoot !== gitRoot) {
    return invalid("ambiguous Git and jj repository identities");
  }
  if (jjRoot !== undefined) {
    return inspectJj(jjRoot, target, inspectionDirectory, capabilities);
  }
  if (gitRoot !== undefined) {
    if (!containsPath(gitRoot, target)) {
      return invalid("canonical Git root does not contain the canonical target");
    }
    const head = parseGitHead(await capabilities.git.head(gitRoot));
    if (typeof head === "string") return invalid(head);
    return { kind: "git", root: gitRoot, head };
  }
  return { kind: "outside-repository" };
}

export async function evaluateEditWrite(
  operation: EditWriteOperation,
  target: string,
  cwd: string,
  capabilities: PolicyCapabilities,
  decide: DecisionFunction = decideEditWrite,
): Promise<PolicyDecision> {
  let input: EditWriteInput;
  try {
    const canonicalPath = await capabilities.filesystem.canonicalize(target, cwd);
    const immutableRoots = await capabilities.filesystem.immutableRoots();
    let immutableTarget: ImmutableTarget | undefined;
    for (const declaredRoot of immutableRoots) {
      const root = await capabilities.filesystem.canonicalize(declaredRoot, cwd);
      if (containsPath(root, canonicalPath)) {
        immutableTarget = { kind: "immutable", canonicalPath, root };
        break;
      }
    }
    if (immutableTarget !== undefined) {
      input = { operation, target: immutableTarget };
    } else {
      const mutableTarget: MutableTarget = { kind: "mutable", canonicalPath };
      const inspectionDirectory = await capabilities.filesystem.inspectionDirectory(canonicalPath);
      const repository = await inspectRepository(canonicalPath, inspectionDirectory, capabilities);
      input = { operation, target: mutableTarget, repository };
    }
  } catch (error) {
    return block(`policy capability failed: ${String(error)}`);
  }

  let decision: PolicyDecision;
  try {
    decision = decide(input);
  } catch (error) {
    return block(`policy evaluation failed: ${String(error)}`);
  }

  if (decision.decision !== "prompt") return decision;
  if (!capabilities.interaction.available) {
    return block("interaction unavailable for required mutation confirmation");
  }
  try {
    return (await capabilities.interaction.confirm(decision.reason))
      ? allow()
      : block("mutation rejected by user");
  } catch (error) {
    return block(`interaction capability failed: ${String(error)}`);
  }
}

const canonicalizePath = async (target: string, cwd: string): Promise<string> => {
  const absolute = resolve(cwd, target);
  try {
    return await realpath(absolute);
  } catch (error) {
    const code = (error as NodeJS.ErrnoException).code;
    if (code !== "ENOENT") throw error;
    const parent = dirname(absolute);
    if (parent === absolute) throw error;
    return join(await canonicalizePath(parent, "/"), basename(absolute));
  }
};

const runProcess = (argv: readonly string[], cwd: string): Promise<ProcessResult> =>
  new Promise((complete) => {
    execFile(argv[0], argv.slice(1), { cwd, encoding: "utf8" }, (error, stdout, stderr) => {
      const numericCode =
        error === null
          ? 0
          : typeof (error as NodeJS.ErrnoException).code === "number"
            ? ((error as NodeJS.ErrnoException).code as number)
            : 127;
      complete({ stdout, stderr, code: numericCode });
    });
  });

const deepestExistingDirectory = async (target: string): Promise<string> => {
  const candidate = dirname(target);
  try {
    const canonical = await realpath(candidate);
    if (!(await stat(canonical)).isDirectory()) {
      throw new Error(`repository inspection ancestor is not a directory: ${canonical}`);
    }
    return canonical;
  } catch (error) {
    const code = (error as NodeJS.ErrnoException).code;
    if (code !== "ENOENT") throw error;
    if (dirname(candidate) === candidate) throw error;
    return deepestExistingDirectory(candidate);
  }
};

const defaultGitRoot = async (directory: string): Promise<GitRootResult> =>
  parseGitRootResult(
    await runProcess(["git", "-C", directory, "rev-parse", "--show-toplevel"], directory),
  );

const defaultGitHead = (root: string): Promise<ProcessResult> =>
  runProcess(["git", "-C", root, "symbolic-ref", "--quiet", "--short", "HEAD"], root);

export const createNodePolicyCapabilities: CapabilityFactory = (context) => ({
  filesystem: {
    canonicalize: canonicalizePath,
    inspectionDirectory: deepestExistingDirectory,
    immutableRoots: async () => ["/nix/store"],
  },
  git: {
    root: defaultGitRoot,
    head: defaultGitHead,
  },
  jj: {
    run: runProcess,
  },
  interaction: {
    available: context.hasUI,
    confirm: (message) => context.ui.confirm("Confirm file mutation", message),
  },
});

const parseToolInput = (input: unknown): string | undefined => {
  if (input === null || typeof input !== "object") return undefined;
  const path = (input as { readonly path?: unknown }).path;
  if (typeof path !== "string") return undefined;
  const normalized = path.startsWith("@") ? path.slice(1) : path;
  return normalized.trim().length > 0 ? normalized : undefined;
};

export function createEditWriteToolCallHandler(
  capabilities: CapabilityFactory = createNodePolicyCapabilities,
  options: { readonly decide?: DecisionFunction } = {},
): (event: ToolCallEvent, context: ToolCallContext) => Promise<ToolCallResult> {
  return async (event, context) => {
    if (event.toolName !== "edit" && event.toolName !== "write") return undefined;
    const target = parseToolInput(event.input);
    if (target === undefined) {
      return {
        block: true,
        reason: "malformed edit/write tool input: path must be a nonempty string",
      };
    }

    try {
      const decision = await evaluateEditWrite(
        event.toolName,
        target,
        context.cwd,
        capabilities(context),
        options.decide,
      );
      return decision.decision === "block" ? { block: true, reason: decision.reason } : undefined;
    } catch (error) {
      return {
        block: true,
        reason: `edit/write policy adapter failed: ${String(error)}`,
      };
    }
  };
}

export default function editWritePolicy(pi: ExtensionAPI): void {
  pi.on("tool_call", createEditWriteToolCallHandler());
}
