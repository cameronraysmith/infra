# Claude Code hooks configuration
# Hook scripts are packaged in modules/home/tools/hooks/ and available on PATH.
{ ... }:
{
  flake.modules = {
    homeManager.ai =
      { ... }:
      {
        programs.claude-code.settings.hooks = {
          PreToolUse = [
            {
              matcher = "Bash";
              hooks = [
                {
                  type = "command";
                  command = "redirect-rm-to-rip";
                }
                {
                  type = "command";
                  command = "gate-mutating-http";
                }
                {
                  type = "command";
                  command = "gate-dangerous-commands";
                }
                {
                  type = "command";
                  command = "gate-git-worktree";
                }
              ];
            }
            {
              matcher = "Edit|Write|MultiEdit";
              hooks = [
                {
                  type = "command";
                  command = "enforce-branch-before-edit";
                }
              ];
            }
            {
              matcher = "Edit|Write|MultiEdit";
              hooks = [
                {
                  type = "command";
                  command = "verify-diamond-before-edit";
                }
              ];
            }
            {
              # Subagent dispatch surfaces as tool_name "Agent". Across
              # ~/.claude/projects transcripts, the last tool_use block named
              # "Task" is dated 2026-02-28 and blocks named "Agent" run from
              # that day onward.
              matcher = "Agent";
              hooks = [
                {
                  type = "command";
                  command = "gate-worktree-surfaces";
                }
              ];
            }
            {
              matcher = "EnterWorktree";
              hooks = [
                {
                  type = "command";
                  command = "gate-worktree-surfaces";
                }
              ];
            }
          ];

          WorktreeCreate = [
            {
              hooks = [
                {
                  type = "command";
                  command = "jj-worktree-create";
                }
              ];
            }
          ];

          WorktreeRemove = [
            {
              hooks = [
                {
                  type = "command";
                  command = "jj-worktree-remove";
                }
              ];
            }
          ];

          SessionStart = [
            {
              hooks = [
                {
                  type = "command";
                  command = "session-start";
                }
              ];
            }
          ];

          UserPromptSubmit = [
            {
              hooks = [
                {
                  type = "command";
                  command = "clarify-vague-request";
                }
              ];
            }
          ];

          Notification = [
            {
              matcher = "permission_prompt";
              hooks = [
                {
                  type = "command";
                  command = "notify-permission-prompt";
                  async = true;
                }
              ];
            }
          ];
        };
      };
  };
}
