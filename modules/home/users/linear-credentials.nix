# schpet/linear-cli inline-format credentials, rendered immutably from sops.
#
# Inline format: flat `<workspace> = "<api-key>"` keys plus a top-level
# `default = "<workspace>"` (see schpet credentials.ts hasInlineKeys /
# parseInlineCredentials). schpet uses XDG on darwin too (Deno reads
# XDG_CONFIG_HOME, else ~/.config), so no per-platform path conditional.
# Read-only (0400): switch profiles via `--workspace` / a `default` change,
# never via mutating `linear auth` commands which would clobber this file.
#
# Every value is a sops placeholder, so the template carries nothing
# user-specific and every user declaring the four Linear secrets renders the
# same file from their own ciphertext. Kept here rather than in an aggregate
# because the credentials are identity-bound content, which `users/lib.nix`
# assigns to `contentPrivate`; the call site sits beside the secret
# declarations it depends on.
{ ... }:
{
  # Takes the home-manager `config` of the user declaring
  # `linear-{api-key,workspace}-{personal,work}`.
  flake.lib.mkLinearCredentialsTemplate = config: {
    mode = "0400";
    path = "${config.xdg.configHome}/linear/credentials.toml";
    content = ''
      default = "${config.sops.placeholder."linear-workspace-personal"}"

      ${config.sops.placeholder."linear-workspace-personal"} = "${
        config.sops.placeholder."linear-api-key-personal"
      }"
      ${config.sops.placeholder."linear-workspace-work"} = "${
        config.sops.placeholder."linear-api-key-work"
      }"
    '';
  };
}
