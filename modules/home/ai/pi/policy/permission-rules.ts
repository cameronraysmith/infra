import type {
  GateConfig,
  GateHelpers,
  RuleEntry,
} from "pi-agent-extensions/permission-gate/types.ts";

export const policyPresent = true;

const READ_ONLY_METHODS = new Set(["GET", "HEAD", "OPTIONS"]);
const CURL_DATA_LONG_OPTIONS = new Set([
  "--data",
  "--data-ascii",
  "--data-binary",
  "--data-raw",
  "--data-urlencode",
  "--form",
  "--form-string",
  "--json",
  "--upload-file",
]);
const CURL_VALUE_LONG_OPTIONS = new Set([
  "--abstract-unix-socket",
  "--alt-svc",
  "--aws-sigv4",
  "--cacert",
  "--capath",
  "--cert",
  "--cert-type",
  "--ciphers",
  "--config",
  "--connect-timeout",
  "--connect-to",
  "--cookie",
  "--cookie-jar",
  "--create-file-mode",
  "--crlfile",
  "--curves",
  "--delegation",
  "--dns-interface",
  "--dns-ipv4-addr",
  "--dns-ipv6-addr",
  "--dns-servers",
  "--dump-header",
  "--egd-file",
  "--engine",
  "--etag-compare",
  "--etag-save",
  "--expect100-timeout",
  "--ftp-account",
  "--ftp-alternative-to-user",
  "--ftp-port",
  "--happy-eyeballs-timeout-ms",
  "--header",
  "--hostpubmd5",
  "--hsts",
  "--interface",
  "--key",
  "--key-type",
  "--limit-rate",
  "--local-port",
  "--mail-auth",
  "--mail-from",
  "--mail-rcpt",
  "--max-filesize",
  "--max-redirs",
  "--max-time",
  "--netrc-file",
  "--oauth2-bearer",
  "--output",
  "--pass",
  "--pinnedpubkey",
  "--preproxy",
  "--proto",
  "--proto-default",
  "--proto-redir",
  "--proxy",
  "--proxy-cacert",
  "--proxy-capath",
  "--proxy-cert",
  "--proxy-cert-type",
  "--proxy-ciphers",
  "--proxy-crlfile",
  "--proxy-header",
  "--proxy-key",
  "--proxy-key-type",
  "--proxy-pass",
  "--proxy-service-name",
  "--proxy-tls13-ciphers",
  "--proxy-tlsauthtype",
  "--proxy-tlspassword",
  "--proxy-tlsuser",
  "--proxy-user",
  "--pubkey",
  "--quote",
  "--range",
  "--rate",
  "--referer",
  "--request",
  "--resolve",
  "--retry",
  "--retry-delay",
  "--retry-max-time",
  "--sasl-authzid",
  "--service-name",
  "--speed-limit",
  "--speed-time",
  "--socks4",
  "--socks4a",
  "--socks5",
  "--socks5-hostname",
  "--telnet-option",
  "--tftp-blksize",
  "--time-cond",
  "--tls-max",
  "--tls13-ciphers",
  "--tlsauthtype",
  "--tlspassword",
  "--tlsuser",
  "--unix-socket",
  "--url",
  "--user",
  "--user-agent",
  "--write-out",
]);
const CURL_VALUE_SHORT_OPTIONS = new Set([
  "A",
  "b",
  "c",
  "C",
  "d",
  "D",
  "e",
  "E",
  "F",
  "H",
  "h",
  "K",
  "m",
  "o",
  "P",
  "Q",
  "r",
  "t",
  "T",
  "U",
  "u",
  "w",
  "x",
  "X",
  "y",
  "Y",
  "z",
]);
const WGET_BODY_OPTIONS = new Set(["--body-data", "--body-file", "--post-data", "--post-file"]);
const WGET_OPAQUE_OPTIONS = new Set(["--config", "--execute"]);
const WGET_VALUE_LONG_OPTIONS = new Set([
  ...WGET_BODY_OPTIONS,
  ...WGET_OPAQUE_OPTIONS,
  "--accept",
  "--accept-regex",
  "--append-output",
  "--base",
  "--bind-address",
  "--ca-certificate",
  "--ca-directory",
  "--certificate",
  "--certificate-type",
  "--connect-timeout",
  "--cut-dirs",
  "--directory-prefix",
  "--dns-timeout",
  "--domains",
  "--exclude-directories",
  "--exclude-domains",
  "--follow-tags",
  "--ftp-password",
  "--ftp-user",
  "--header",
  "--http-password",
  "--http-user",
  "--ignore-tags",
  "--include-directories",
  "--input-file",
  "--level",
  "--limit-rate",
  "--load-cookies",
  "--local-encoding",
  "--max-redirect",
  "--method",
  "--output-document",
  "--output-file",
  "--password",
  "--preferred-family",
  "--private-key",
  "--progress",
  "--proxy-password",
  "--proxy-user",
  "--quota",
  "--reject",
  "--reject-regex",
  "--save-cookies",
  "--secure-protocol",
  "--timeout",
  "--tries",
  "--user",
  "--user-agent",
  "--wait",
  "--waitretry",
]);
const WGET_FLAG_LONG_OPTIONS = new Set([
  "--continue",
  "--debug",
  "--help",
  "--no-clobber",
  "--no-config",
  "--no-verbose",
  "--quiet",
  "--recursive",
  "--server-response",
  "--spider",
  "--timestamping",
  "--verbose",
  "--version",
]);
const WGET_VALUE_SHORT_OPTIONS = new Set([
  "a",
  "A",
  "B",
  "D",
  "e",
  "i",
  "l",
  "o",
  "O",
  "P",
  "Q",
  "R",
  "t",
  "T",
  "U",
  "w",
  "X",
]);
const WGET_FLAG_SHORT_OPTIONS = new Set(["c", "d", "h", "n", "N", "q", "r", "S", "v", "V"]);

interface CurlAnalysis {
  readonly explicitMethod?: string;
  readonly hasData: boolean;
  readonly usesGet: boolean;
  readonly hasOpaqueConfig: boolean;
  readonly hasUnclassifiedOption: boolean;
  readonly malformed: boolean;
}

const analyzeCurlTransfer = (args: readonly string[]): CurlAnalysis => {
  let explicitMethod: string | undefined;
  let hasData = false;
  let usesGet = false;
  let hasOpaqueConfig = false;
  let hasUnclassifiedOption = false;
  let malformed = false;

  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument === "--") break;
    if (argument.startsWith("--")) {
      const equals = argument.indexOf("=");
      const option = equals === -1 ? argument : argument.slice(0, equals);
      const inlineValue = equals === -1 ? undefined : argument.slice(equals + 1);
      if (option === "--get") {
        usesGet = true;
        malformed ||= inlineValue !== undefined;
        continue;
      }
      const takesValue =
        option === "--request" ||
        CURL_DATA_LONG_OPTIONS.has(option) ||
        CURL_VALUE_LONG_OPTIONS.has(option);
      if (!takesValue) {
        hasUnclassifiedOption = true;
        continue;
      }
      const value = inlineValue ?? args[index + 1];
      if (inlineValue === undefined) index += 1;
      if (value === undefined || value.length === 0) malformed = true;
      if (option === "--request") explicitMethod = value;
      if (option === "--config") hasOpaqueConfig = true;
      if (CURL_DATA_LONG_OPTIONS.has(option)) hasData = true;
      continue;
    }
    if (!argument.startsWith("-") || argument === "-") continue;

    const cluster = argument.slice(1);
    for (let position = 0; position < cluster.length; position += 1) {
      const option = cluster[position];
      if (option === "G") usesGet = true;
      if (!CURL_VALUE_SHORT_OPTIONS.has(option)) continue;
      const inlineValue = cluster.slice(position + 1);
      const value = inlineValue.length > 0 ? inlineValue : args[index + 1];
      if (inlineValue.length === 0) index += 1;
      if (value === undefined || value.length === 0) malformed = true;
      if (option === "X") explicitMethod = value;
      if (option === "K") hasOpaqueConfig = true;
      if (option === "d" || option === "F" || option === "T") hasData = true;
      break;
    }
  }

  return {
    explicitMethod,
    hasData,
    usesGet,
    hasOpaqueConfig,
    hasUnclassifiedOption,
    malformed,
  };
};

const curlTransferMutates = (args: readonly string[]): boolean => {
  const analysis = analyzeCurlTransfer(args);
  if (analysis.malformed || analysis.hasOpaqueConfig || analysis.hasUnclassifiedOption) return true;
  if (analysis.explicitMethod !== undefined) {
    return !READ_ONLY_METHODS.has(analysis.explicitMethod);
  }
  return !analysis.usesGet && analysis.hasData;
};

const curlTransfers = (args: readonly string[]): readonly string[][] => {
  const transfers: string[][] = [[]];
  let endOfOptions = false;
  const nextTransfer = (): void => {
    transfers.push([]);
    endOfOptions = false;
  };
  const append = (argument: string): void => {
    transfers[transfers.length - 1].push(argument);
  };

  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (endOfOptions) {
      append(argument);
      continue;
    }
    if (argument === "--") {
      append(argument);
      endOfOptions = true;
      continue;
    }
    if (argument === "--next") {
      nextTransfer();
      continue;
    }
    if (argument.startsWith("--")) {
      append(argument);
      const option = argument.split("=", 1)[0];
      const hasInlineValue = argument.includes("=");
      const takesValue =
        option === "--request" ||
        CURL_DATA_LONG_OPTIONS.has(option) ||
        CURL_VALUE_LONG_OPTIONS.has(option);
      if (takesValue && !hasInlineValue && args[index + 1] !== undefined) {
        append(args[index + 1]);
        index += 1;
      }
      continue;
    }
    if (!argument.startsWith("-") || argument === "-") {
      append(argument);
      continue;
    }

    const cluster = argument.slice(1);
    let pending = "";
    for (let position = 0; position < cluster.length; position += 1) {
      const option = cluster[position];
      if (option === ":") {
        if (pending.length > 0) append(`-${pending}`);
        pending = "";
        nextTransfer();
        continue;
      }
      pending += option;
      if (!CURL_VALUE_SHORT_OPTIONS.has(option)) continue;
      const inlineValue = cluster.slice(position + 1);
      if (inlineValue.length > 0) {
        pending += inlineValue;
      } else {
        append(`-${pending}`);
        pending = "";
        if (args[index + 1] !== undefined) {
          append(args[index + 1]);
          index += 1;
        }
      }
      break;
    }
    if (pending.length > 0) append(`-${pending}`);
  }

  return transfers;
};

const curlMutates = (args: string[]): boolean => curlTransfers(args).some(curlTransferMutates);

interface WgetAnalysis {
  readonly explicitMethod?: string;
  readonly hasBody: boolean;
  readonly hasOpaqueConfig: boolean;
  readonly malformedOrAmbiguous: boolean;
}

const analyzeWget = (args: readonly string[]): WgetAnalysis => {
  let explicitMethod: string | undefined;
  let hasBody = false;
  let hasOpaqueConfig = false;
  let malformedOrAmbiguous = false;

  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument === "--") break;
    if (argument.startsWith("--")) {
      const equals = argument.indexOf("=");
      const option = equals === -1 ? argument : argument.slice(0, equals);
      const inlineValue = equals === -1 ? undefined : argument.slice(equals + 1);
      if (WGET_FLAG_LONG_OPTIONS.has(option)) {
        malformedOrAmbiguous ||= inlineValue !== undefined;
        continue;
      }
      if (!WGET_VALUE_LONG_OPTIONS.has(option)) {
        malformedOrAmbiguous = true;
        continue;
      }
      const value = inlineValue ?? args[index + 1];
      if (inlineValue === undefined) index += 1;
      if (value === undefined || value.length === 0) malformedOrAmbiguous = true;
      if (option === "--method") explicitMethod = value;
      if (WGET_BODY_OPTIONS.has(option)) hasBody = true;
      if (WGET_OPAQUE_OPTIONS.has(option)) hasOpaqueConfig = true;
      continue;
    }
    if (!argument.startsWith("-") || argument === "-") continue;

    const cluster = argument.slice(1);
    let consumed = false;
    for (let position = 0; position < cluster.length; position += 1) {
      const option = cluster[position];
      if (WGET_VALUE_SHORT_OPTIONS.has(option)) {
        const inlineValue = cluster.slice(position + 1);
        const value = inlineValue.length > 0 ? inlineValue : args[index + 1];
        if (inlineValue.length === 0) index += 1;
        if (value === undefined || value.length === 0) malformedOrAmbiguous = true;
        if (option === "e") hasOpaqueConfig = true;
        consumed = true;
        break;
      }
      if (!WGET_FLAG_SHORT_OPTIONS.has(option)) malformedOrAmbiguous = true;
    }
    if (!consumed && cluster.length === 0) malformedOrAmbiguous = true;
  }

  return { explicitMethod, hasBody, hasOpaqueConfig, malformedOrAmbiguous };
};

const wgetMutates = (args: string[]): boolean => {
  const analysis = analyzeWget(args);
  if (analysis.malformedOrAmbiguous || analysis.hasOpaqueConfig || analysis.hasBody) return true;
  return analysis.explicitMethod !== undefined && !READ_ONLY_METHODS.has(analysis.explicitMethod);
};

interface GlobalOptionSpec {
  readonly flags: ReadonlySet<string>;
  readonly values: ReadonlySet<string>;
  readonly gluedValues: ReadonlySet<string>;
}

interface ConsumedGlobalValue {
  readonly option: string;
  readonly value: string | undefined;
}

interface ParsedGlobalArguments {
  readonly command: readonly string[];
  readonly values: readonly ConsumedGlobalValue[];
  readonly unknownLeadingOption: boolean;
}

const parseGlobalArguments = (args: string[], spec: GlobalOptionSpec): ParsedGlobalArguments => {
  const values: ConsumedGlobalValue[] = [];
  let index = 0;
  while (index < args.length) {
    const argument = args[index];
    if (argument === "--") {
      return { command: args.slice(index + 1), values, unknownLeadingOption: false };
    }
    if (spec.flags.has(argument)) {
      index += 1;
      continue;
    }
    if (spec.values.has(argument)) {
      values.push({ option: argument, value: args[index + 1] });
      index += 2;
      continue;
    }
    const equalsOption = [...spec.values].find((option) => argument.startsWith(`${option}=`));
    if (equalsOption !== undefined) {
      values.push({ option: equalsOption, value: argument.slice(equalsOption.length + 1) });
      index += 1;
      continue;
    }
    const gluedOption = [...spec.gluedValues].find(
      (option) => argument.startsWith(option) && argument.length > option.length,
    );
    if (gluedOption !== undefined) {
      values.push({ option: gluedOption, value: argument.slice(gluedOption.length) });
      index += 1;
      continue;
    }
    return {
      command: args.slice(index),
      values,
      unknownLeadingOption: argument.startsWith("-"),
    };
  }
  return { command: [], values, unknownLeadingOption: false };
};

const GIT_GLOBAL_OPTIONS: GlobalOptionSpec = {
  flags: new Set([
    "--bare",
    "--glob-pathspecs",
    "--icase-pathspecs",
    "--literal-pathspecs",
    "--no-optional-locks",
    "--no-pager",
    "--no-replace-objects",
    "--noglob-pathspecs",
    "--paginate",
    "-p",
    "-P",
  ]),
  values: new Set([
    "--config-env",
    "--exec-path",
    "--git-dir",
    "--namespace",
    "--super-prefix",
    "--work-tree",
    "-C",
    "-c",
  ]),
  gluedValues: new Set(["-C", "-c"]),
};

const JJ_GLOBAL_OPTIONS: GlobalOptionSpec = {
  flags: new Set([
    "--debug",
    "--ignore-immutable",
    "--ignore-working-copy",
    "--no-pager",
    "--quiet",
  ]),
  values: new Set([
    "--at-operation",
    "--color",
    "--config",
    "--config-file",
    "--config-toml",
    "--repository",
    "-R",
  ]),
  gluedValues: new Set(["-R"]),
};

const KNOWN_GIT_COMMANDS = new Set([
  "add",
  "branch",
  "checkout",
  "cherry-pick",
  "clean",
  "clone",
  "commit",
  "config",
  "diff",
  "fetch",
  "init",
  "log",
  "merge",
  "mv",
  "notes",
  "pull",
  "push",
  "rebase",
  "remote",
  "reset",
  "restore",
  "revert",
  "rm",
  "show",
  "sparse-checkout",
  "stash",
  "status",
  "submodule",
  "switch",
  "tag",
  "worktree",
]);
const KNOWN_JJ_COMMANDS = new Set([
  "abandon",
  "absorb",
  "bookmark",
  "commit",
  "config",
  "describe",
  "diff",
  "duplicate",
  "edit",
  "evolog",
  "file",
  "fix",
  "git",
  "interdiff",
  "log",
  "new",
  "next",
  "operation",
  "parallelize",
  "prev",
  "rebase",
  "resolve",
  "restore",
  "root",
  "run",
  "show",
  "simplify-parents",
  "sparse",
  "split",
  "squash",
  "status",
  "tag",
  "undo",
  "unsquash",
  "util",
  "version",
  "workspace",
]);

type AliasExpansionKind = "base-command" | "command-with-add" | "unknown";

const aliasExpansionKind = (
  expansion: string,
  commandName: "worktree" | "workspace",
): AliasExpansionKind => {
  const trimmed = expansion.trim();
  const simple = trimmed.match(new RegExp(`^${commandName}(?:\\s+(add|"add"|'add'))?$`));
  if (simple !== null) return simple[1] === undefined ? "base-command" : "command-with-add";

  const array = trimmed.match(/^\[\s*(["'])([^"']+)\1(?:\s*,\s*(["'])([^"']+)\3)?\s*\]$/);
  if (array === null || array[2] !== commandName) return "unknown";
  if (array[4] === undefined) return "base-command";
  return array[4] === "add" ? "command-with-add" : "unknown";
};

const gitAliasesFor = (
  values: readonly ConsumedGlobalValue[],
  commandName: "worktree",
): ReadonlyMap<string, AliasExpansionKind> => {
  const aliases = new Map<string, AliasExpansionKind>();
  for (const entry of values) {
    if (entry.option !== "-c" || entry.value === undefined) continue;
    const match = entry.value.match(/^alias\.([^=]+)=(.*)$/i);
    if (match === null) continue;
    aliases.set(match[1], aliasExpansionKind(match[2], commandName));
  }
  return aliases;
};

const jjAliasesFor = (
  values: readonly ConsumedGlobalValue[],
  commandName: "workspace",
): ReadonlyMap<string, AliasExpansionKind> => {
  const aliases = new Map<string, AliasExpansionKind>();
  for (const entry of values) {
    if (
      (entry.option !== "--config" && entry.option !== "--config-toml") ||
      entry.value === undefined
    ) {
      continue;
    }
    const match = entry.value.match(/^aliases\.([^=\s]+)\s*=\s*(.*)$/i);
    if (match === null) continue;
    aliases.set(match[1], aliasExpansionKind(match[2], commandName));
  }
  return aliases;
};

const couldCreateAfterGlobalOptions = (
  args: string[],
  spec: GlobalOptionSpec,
  commandName: "worktree" | "workspace",
  knownCommands: ReadonlySet<string>,
  aliasesFor: (values: readonly ConsumedGlobalValue[]) => ReadonlyMap<string, AliasExpansionKind>,
): boolean => {
  const parsed = parseGlobalArguments(args, spec);
  const command = parsed.command;
  if (command[0] === commandName && command[1] === "add") return true;
  const aliasKind = aliasesFor(parsed.values).get(command[0] ?? "");
  if (aliasKind === "unknown" || aliasKind === "command-with-add") return true;
  if (aliasKind === "base-command" && command[1] === "add") return true;
  if (parsed.unknownLeadingOption) return true;
  const invokedCommand = command[0];
  return invokedCommand !== undefined && !knownCommands.has(invokedCommand);
};

const createsWorktree = (args: string[]): boolean =>
  couldCreateAfterGlobalOptions(
    args,
    GIT_GLOBAL_OPTIONS,
    "worktree",
    KNOWN_GIT_COMMANDS,
    (values) => gitAliasesFor(values, "worktree"),
  );

const createsWorkspace = (args: string[]): boolean =>
  couldCreateAfterGlobalOptions(args, JJ_GLOBAL_OPTIONS, "workspace", KNOWN_JJ_COMMANDS, (values) =>
    jjAliasesFor(values, "workspace"),
  );

export default function permissionRules(helpers: GateHelpers): GateConfig {
  const rules = [
    {
      label: "remove with rm",
      group: "files",
      action: "block",
      test: (pipeline) => helpers.anyCmd(pipeline, "rm"),
      reason: "Direct rm is blocked. Use rip so removal is recoverable, then retry.",
    },
    {
      label: "mutating HTTP request",
      group: "exec",
      action: "prompt",
      test: (pipeline) =>
        helpers.anyCmd(pipeline, "curl", curlMutates) ||
        helpers.anyCmd(pipeline, "wget", wgetMutates),
    },
    {
      label: "create worktree or workspace",
      group: "vcs",
      action: "prompt",
      test: (pipeline) =>
        helpers.anyCmd(pipeline, "git", createsWorktree) ||
        helpers.anyCmd(pipeline, "jj", createsWorkspace),
    },
    {
      label: "mutate Pi packages",
      group: "files",
      action: "block",
      test: (pipeline) =>
        helpers.anyCmd(pipeline, "pi", (args) =>
          ["install", "remove", "uninstall", "update"].includes(args[0] ?? ""),
        ),
      reason:
        "Pi package mutation is blocked. Change the Nix pin and Home Manager package selection instead.",
    },
  ] satisfies RuleEntry[];

  return { extraRules: rules };
}
