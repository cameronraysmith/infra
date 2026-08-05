# buzz - Buzz relay CLI, wrapped to inject the sops-provisioned nostr secret key
# and to default the relay endpoint. The decrypted file's path is resolved at
# eval time and read at runtime; --relay still wins over BUZZ_RELAY_URL through
# clap's own precedence.
{ ... }:
{
  flake.modules.homeManager.tools =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      # Gated on the secret existing. Every user's aggregate includes `tools`,
      # but only crs58 declares buzz-nsec, so an unguarded reference to it
      # throws while evaluating the other users. The gate also keeps the rust
      # closure out of their profiles.
      home.packages = lib.optionals (lib.hasAttrByPath [ "sops" "secrets" "buzz-nsec" "path" ] config) [
        (pkgs.writeShellApplication {
          name = "buzz";
          text = ''
            keyfile=${lib.escapeShellArg (lib.attrByPath [ "sops" "secrets" "buzz-nsec" "path" ] "" config)}

            # The key necessarily reaches the process environment: upstream
            # accepts it only through --private-key or $BUZZ_PRIVATE_KEY, and
            # argv is worse, being world-readable in the process table.
            #
            # Assignment and export are separate statements because `export x=$(…)`
            # masks the substitution's exit status (SC2155), and shellcheck runs
            # at build time here, so a lint failure is a build failure.
            #
            # writeShellApplication emits `set -o nounset`, hence ''${VAR:-}
            # rather than bare $VAR on anything a caller may not have set.
            if [ -z "''${BUZZ_PRIVATE_KEY:-}" ] && [ -n "$keyfile" ] && [ -r "$keyfile" ]; then
              BUZZ_PRIVATE_KEY=$(cat "$keyfile")
              export BUZZ_PRIVATE_KEY
            fi

            export BUZZ_RELAY_URL="''${BUZZ_RELAY_URL:-https://cameron.communities.buzz.xyz}"

            exec ${lib.getExe' pkgs.buzz-cli "buzz"} "$@"
          '';
          meta.description = "Buzz relay CLI with the sops-provisioned nostr key and a default relay endpoint";
        })
      ];
    };
}
