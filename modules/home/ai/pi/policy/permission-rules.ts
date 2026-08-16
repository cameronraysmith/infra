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
// Reviewed no-value flags that cannot independently supply a method, body, or opaque config.
const CURL_SAFE_FLAG_LONG_OPTIONS = new Set([
  "--anyauth",
  "--append",
  "--basic",
  "--ca-native",
  "--cert-status",
  "--compressed",
  "--compressed-ssh",
  "--create-dirs",
  "--crlf",
  "--digest",
  "--disable",
  "--disable-eprt",
  "--disable-epsv",
  "--disallow-username-in-url",
  "--doh-cert-status",
  "--doh-insecure",
  "--dump-ca-embed",
  "--fail",
  "--fail-early",
  "--fail-with-body",
  "--false-start",
  "--follow",
  "--form-escape",
  "--ftp-create-dirs",
  "--ftp-pasv",
  "--ftp-pret",
  "--ftp-skip-pasv-ip",
  "--ftp-ssl-ccc",
  "--ftp-ssl-control",
  "--get",
  "--globoff",
  "--haproxy-protocol",
  "--head",
  "--http0.9",
  "--http1.0",
  "--http1.1",
  "--http2",
  "--http2-prior-knowledge",
  "--http3",
  "--http3-only",
  "--ignore-content-length",
  "--insecure",
  "--ipv4",
  "--ipv6",
  "--junk-session-cookies",
  "--list-only",
  "--location",
  "--location-trusted",
  "--mail-rcpt-allowfails",
  "--manual",
  "--metalink",
  "--mptcp",
  "--negotiate",
  "--netrc",
  "--netrc-optional",
  "--next",
  "--no-alpn",
  "--no-buffer",
  "--no-clobber",
  "--no-keepalive",
  "--no-npn",
  "--no-progress-meter",
  "--no-sessionid",
  "--ntlm",
  "--ntlm-wb",
  "--out-null",
  "--parallel",
  "--parallel-immediate",
  "--path-as-is",
  "--post301",
  "--post302",
  "--post303",
  "--progress-bar",
  "--proxy-anyauth",
  "--proxy-basic",
  "--proxy-ca-native",
  "--proxy-digest",
  "--proxy-http2",
  "--proxy-http3",
  "--proxy-insecure",
  "--proxy-negotiate",
  "--proxy-ntlm",
  "--proxy-ssl-allow-beast",
  "--proxy-ssl-auto-client-cert",
  "--proxy-tlsv1",
  "--proxytunnel",
  "--raw",
  "--remote-header-name",
  "--remote-name",
  "--remote-name-all",
  "--remote-time",
  "--remove-on-error",
  "--retry-all-errors",
  "--retry-connrefused",
  "--sasl-ir",
  "--show-error",
  "--show-headers",
  "--silent",
  "--skip-existing",
  "--socks5-basic",
  "--socks5-gssapi",
  "--socks5-gssapi-nec",
  "--ssl",
  "--ssl-allow-beast",
  "--ssl-auto-client-cert",
  "--ssl-no-revoke",
  "--ssl-reqd",
  "--ssl-revoke-best-effort",
  "--sslv2",
  "--sslv3",
  "--styled-output",
  "--suppress-connect-headers",
  "--tcp-fastopen",
  "--tcp-nodelay",
  "--tftp-no-options",
  "--tls-earlydata",
  "--tlsv1",
  "--tlsv1.0",
  "--tlsv1.1",
  "--tlsv1.2",
  "--tlsv1.3",
  "--tr-encoding",
  "--trace-ids",
  "--trace-time",
  "--use-ascii",
  "--verbose",
  "--version",
  "--xattr",
]);
const isSafeCurlLongFlag = (option: string): boolean => {
  if (CURL_SAFE_FLAG_LONG_OPTIONS.has(option)) return true;
  if (!option.startsWith("--no-") || option.startsWith("--no-no-")) return false;
  return CURL_SAFE_FLAG_LONG_OPTIONS.has(`--${option.slice("--no-".length)}`);
};

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
const CURL_SAFE_FLAG_SHORT_OPTIONS = new Set([
  "#",
  "0",
  "1",
  "2",
  "3",
  "4",
  "6",
  "B",
  "G",
  "I",
  "J",
  "L",
  "M",
  "N",
  "O",
  "R",
  "S",
  "V",
  "Z",
  "a",
  "f",
  "g",
  "i",
  "j",
  "k",
  "l",
  "n",
  "p",
  "q",
  "s",
  "v",
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
      if (isSafeCurlLongFlag(option)) {
        if (option === "--get" || option === "--no-get") usesGet = option === "--get";
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
      if (CURL_SAFE_FLAG_SHORT_OPTIONS.has(option)) {
        if (option === "G") usesGet = true;
        continue;
      }
      if (!CURL_VALUE_SHORT_OPTIONS.has(option)) {
        hasUnclassifiedOption = true;
        continue;
      }
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
  // A request body mutates whatever method is declared; -G is curl's documented
  // conversion of that data into the query string, so it transmits no body.
  if (analysis.hasData && !analysis.usesGet) return true;
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
  readonly flags: readonly string[];
  readonly values: readonly ConsumedGlobalValue[];
  readonly unknownLeadingOption: boolean;
}

const parseGlobalArguments = (args: string[], spec: GlobalOptionSpec): ParsedGlobalArguments => {
  const flags: string[] = [];
  const values: ConsumedGlobalValue[] = [];
  let index = 0;
  while (index < args.length) {
    const argument = args[index];
    if (argument === "--") {
      return { command: args.slice(index + 1), flags, values, unknownLeadingOption: false };
    }
    if (spec.flags.has(argument)) {
      flags.push(argument);
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
      flags,
      values,
      unknownLeadingOption: argument.startsWith("-"),
    };
  }
  return { command: [], flags, values, unknownLeadingOption: false };
};

const GIT_GLOBAL_OPTIONS: GlobalOptionSpec = {
  flags: new Set([
    "--bare",
    "--exec-path",
    "--glob-pathspecs",
    "--help",
    "--html-path",
    "--icase-pathspecs",
    "--info-path",
    "--literal-pathspecs",
    "--man-path",
    "--no-advice",
    "--no-lazy-fetch",
    "--no-optional-locks",
    "--no-pager",
    "--no-replace-objects",
    "--noglob-pathspecs",
    "--paginate",
    "--version",
    "-h",
    "-p",
    "-P",
    "-v",
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

const GIT_INFORMATIONAL_GLOBAL_OPTIONS = new Set([
  "--exec-path",
  "--help",
  "--html-path",
  "--info-path",
  "--man-path",
  "--version",
  "-h",
  "-v",
]);

const JJ_INFORMATIONAL_GLOBAL_OPTIONS = new Set(["--help", "--version", "-h", "-V"]);

const JJ_GLOBAL_OPTIONS: GlobalOptionSpec = {
  flags: new Set([
    "--debug",
    "--help",
    "--ignore-immutable",
    "--ignore-working-copy",
    "--no-integrate-operation",
    "--no-pager",
    "--quiet",
    "--version",
    "-V",
    "-h",
  ]),
  values: new Set([
    "--at-op",
    "--at-operation",
    "--color",
    "--config",
    "--config-file",
    "--config-toml",
    "--repository",
    "-R",
  ]),
  // "--at-op" must stay out of gluedValues: "--at-operation".startsWith("--at-op"),
  // so the glued branch would consume the long spelling as the value "eration".
  gluedValues: new Set(["-R"]),
};

// Git 2.55.0 `git --list-cmds=builtins,nohelpers`, from the deployed Nix package.
const KNOWN_GIT_BUILTIN_COMMANDS = new Set([
  "add",
  "am",
  "annotate",
  "apply",
  "archive",
  "backfill",
  "bisect",
  "blame",
  "branch",
  "bugreport",
  "bundle",
  "cat-file",
  "check-attr",
  "check-ignore",
  "check-mailmap",
  "check-ref-format",
  "checkout",
  "checkout-index",
  "cherry",
  "cherry-pick",
  "clean",
  "clone",
  "column",
  "commit",
  "commit-graph",
  "commit-tree",
  "config",
  "count-objects",
  "credential",
  "credential-cache",
  "credential-store",
  "describe",
  "diagnose",
  "diff",
  "diff-files",
  "diff-index",
  "diff-pairs",
  "diff-tree",
  "difftool",
  "fast-export",
  "fast-import",
  "fetch",
  "fetch-pack",
  "fmt-merge-msg",
  "for-each-ref",
  "for-each-repo",
  "format-patch",
  "format-rev",
  "fsck",
  "fsck-objects",
  "gc",
  "get-tar-commit-id",
  "grep",
  "hash-object",
  "help",
  "history",
  "hook",
  "index-pack",
  "init",
  "init-db",
  "interpret-trailers",
  "last-modified",
  "log",
  "ls-files",
  "ls-remote",
  "ls-tree",
  "mailinfo",
  "mailsplit",
  "maintenance",
  "merge",
  "merge-base",
  "merge-file",
  "merge-index",
  "merge-ours",
  "merge-recursive",
  "merge-recursive-ours",
  "merge-recursive-theirs",
  "merge-subtree",
  "merge-tree",
  "mktag",
  "mktree",
  "multi-pack-index",
  "mv",
  "name-rev",
  "notes",
  "pack-objects",
  "pack-redundant",
  "pack-refs",
  "patch-id",
  "pickaxe",
  "prune",
  "prune-packed",
  "pull",
  "push",
  "range-diff",
  "read-tree",
  "rebase",
  "receive-pack",
  "reflog",
  "refs",
  "remote",
  "remote-ext",
  "remote-fd",
  "repack",
  "replace",
  "replay",
  "repo",
  "rerere",
  "reset",
  "restore",
  "rev-list",
  "rev-parse",
  "revert",
  "rm",
  "send-pack",
  "shortlog",
  "show",
  "show-branch",
  "show-index",
  "show-ref",
  "sparse-checkout",
  "stage",
  "stash",
  "status",
  "stripspace",
  "switch",
  "symbolic-ref",
  "tag",
  "unpack-file",
  "unpack-objects",
  "update-index",
  "update-ref",
  "update-server-info",
  "upload-archive",
  "upload-pack",
  "url-parse",
  "var",
  "verify-commit",
  "verify-pack",
  "verify-tag",
  "version",
  "whatchanged",
  "worktree",
  "write-tree",
]);
// jj 0.43.0 top-level commands and built-in aliases, from the deployed Nix package (`jj --help`).
const KNOWN_JJ_COMMANDS = new Set([
  "abandon",
  "absorb",
  "arrange",
  "b",
  "bisect",
  "bookmark",
  "ci",
  "commit",
  "config",
  "desc",
  "describe",
  "diff",
  "diffedit",
  "duplicate",
  "edit",
  "evolog",
  "evolution-log",
  "file",
  "fix",
  "gerrit",
  "git",
  "help",
  "interdiff",
  "log",
  "metaedit",
  "new",
  "next",
  "op",
  "operation",
  "parallelize",
  "prev",
  "rebase",
  "redo",
  "resolve",
  "restore",
  "revert",
  "root",
  "run",
  "show",
  "sign",
  "simplify-parents",
  "sparse",
  "split",
  "squash",
  "st",
  "status",
  "tag",
  "undo",
  "unsign",
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
  informationalGlobalOptions: ReadonlySet<string>,
  aliasesFor: (values: readonly ConsumedGlobalValue[]) => ReadonlyMap<string, AliasExpansionKind>,
): boolean => {
  const parsed = parseGlobalArguments(args, spec);
  if (parsed.flags.some((flag) => informationalGlobalOptions.has(flag))) return false;
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
    KNOWN_GIT_BUILTIN_COMMANDS,
    GIT_INFORMATIONAL_GLOBAL_OPTIONS,
    (values) => gitAliasesFor(values, "worktree"),
  );

const createsWorkspace = (args: string[]): boolean =>
  couldCreateAfterGlobalOptions(
    args,
    JJ_GLOBAL_OPTIONS,
    "workspace",
    KNOWN_JJ_COMMANDS,
    JJ_INFORMATIONAL_GLOBAL_OPTIONS,
    (values) => jjAliasesFor(values, "workspace"),
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
          ["config", "install", "remove", "uninstall", "update"].includes(args[0] ?? ""),
        ),
      reason:
        "Pi package mutation is blocked. Change the Nix pin and Home Manager package selection instead.",
    },
  ] satisfies RuleEntry[];

  return { extraRules: rules };
}
