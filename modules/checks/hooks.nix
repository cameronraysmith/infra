# Behavioral checks for the PreToolUse Bash hooks in modules/home/tools/hooks.
#
# The hooks are plain scripts read by writeShellApplication in the home module,
# so a check can drive the same file directly: feed it a hook JSON payload on
# stdin and assert whether it emits an "ask" decision or exits silently to fall
# through to the blanket Bash allow.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      checks.hook-gate-dangerous-commands =
        let
          # Each case is "<expected> <command>", where <expected> is ask or allow.
          cases = [
            # Explicit-PID kill is not a gated hazard: the PID names one already
            # identified process, unlike a pattern that can select processes the
            # author never inspected.
            "allow kill 1308"
            "allow kill -TERM 1308"
            "allow kill -9 1234"
            "allow kill -SIGKILL 1234"
            "allow kill -s TERM 1234"
            "allow kill 123 456 789"
            # kill -0 sends no signal; it only probes liveness.
            "allow kill -0 1308"
            "allow kill -0 $WATCHER_PID"
            "allow ps aux | grep watcher"

            # Pattern selectors stay gated in every form.
            "ask pkill watcher"
            "ask pkill -f 'firstmate.*watcher'"
            "ask pkill -9 -f watcher"
            "ask killall node"
            "ask killall -9 node"
            # Indirect kill targets stay gated: the target can resolve to a
            # process the author never named.
            "ask kill $PID"
            "ask kill $(pgrep -f watcher)"
            "ask kill `pgrep watcher`"
            "ask kill -TERM $(cat /tmp/pid)"
            "ask kill -f watcher"
            "ask kill %1"
            "ask kill"
            # A safe-looking segment must not launder a later unsafe one.
            "ask kill 1308; kill $OTHER"
            "ask ps aux | xargs kill"
            # A `kill` inside a quoted search pattern is data, not a command:
            # the `|` alternations of an rg pattern are not shell operators.
            # Observed 2026-08-12: the gate pattern-matched the quoted word and
            # stalled a crewmate on two read-only ripgrep searches.
            "allow rg -n \"process group|kill -.*-\\$|setsid|pgid|kill_tree|_drain\" bin/*.sh | head -40"
            "allow rg -n 'watchdog|kill -9' modules/ | head -20"
            # A genuine process termination next to a quoted pattern still gates.
            "ask rg -n \"kill\" bin/*.sh | head -5; kill $WATCHER_PID"

            # nix run/shell is ungated in every form. An "ask" is a hard stall for
            # an agent worker launched with permissions bypassed, and nix run is
            # unavoidable in normal work in this repository.
            "allow nix run nixpkgs#hello"
            "allow nix run .#some-app -- --flag"
            "allow nix shell nixpkgs#jq"
            # nix subcommands that were never gated stay ungated.
            "allow nix build .#checks.aarch64-darwin.hook-gate-dangerous-commands"

            # Ordinary git push is ungated for the same reason, including to the
            # default ref, which the repository's own merge helper pushes to.
            "allow git push"
            "allow git push -u origin fm/some-branch"
            "allow git -C /some/path push"
            "allow git push origin main"
            "allow git push origin HEAD:main"
            # --force-with-lease to a task branch is the rebase-then-push flow every
            # agent worker runs, and gating it is what stalled four of them. It fails
            # safe on its own: it refuses when the remote moved.
            "allow git push --force-with-lease origin fm/some-branch"
            "allow git push --force-with-lease=fm/some-branch origin fm/some-branch"
            "allow git -C /some/path push --force-with-lease origin fm/some-branch"
            # A branch name merely containing the default ref is not the default ref.
            "allow git push --force origin fm/main-guards"

            # The destructive push forms stay gated.
            "ask git push --force origin main"
            "ask git push -f origin main"
            "ask git push --force-with-lease origin main"
            "ask git push --force-with-lease=main origin main"
            "ask git push --force origin master"
            "ask git push --force origin HEAD:main"
            "ask git -C /some/path push --force origin main"
            "ask git push origin :some-branch"
            "ask git push origin --delete some-branch"
            "ask git push -d origin some-branch"
            "ask git push --mirror origin"
            "ask git push --all origin"

            # Neighbouring gates are unaffected by the two lifts above.
            "ask jj git push"
            "ask jj git push --all-bookmarks"
            "ask git reset --hard HEAD~1"
            "ask git clean -fd"
            "ask sudo systemctl restart foo"
            "ask dd if=/dev/zero of=/dev/disk2"
            "ask truncate -s 0 important.log"
            "ask shred -u secrets.env"
            "ask gh workflow run ci.yml"
            "ask kubectl delete pod foo"
          ];
        in
        pkgs.runCommand "hook-gate-dangerous-commands"
          {
            nativeBuildInputs = [
              pkgs.jq
              pkgs.gnugrep
            ];
            hook = ../home/tools/hooks/gate-dangerous-commands.sh;
            caseFile = pkgs.writeText "gate-dangerous-commands-cases" (
              builtins.concatStringsSep "\n" cases + "\n"
            );
          }
          ''
            set -uo pipefail
            failures=0

            while IFS= read -r line; do
              [ -n "$line" ] || continue
              expected="''${line%% *}"
              command="''${line#* }"

              payload=$(jq -Rn --arg c "$command" '{tool_input: {command: $c}}')
              output=$(printf '%s' "$payload" | bash "$hook" 2>/dev/null || true)

              if [ -n "$output" ]; then
                actual=ask
              else
                actual=allow
              fi

              if [ "$actual" != "$expected" ]; then
                echo "FAIL: expected $expected, got $actual for: $command" >&2
                failures=$((failures + 1))
              fi
            done < "$caseFile"

            if [ "$failures" -ne 0 ]; then
              echo "$failures gate-dangerous-commands case(s) failed" >&2
              exit 1
            fi

            touch $out
          '';
    };
}
