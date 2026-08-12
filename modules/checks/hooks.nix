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
