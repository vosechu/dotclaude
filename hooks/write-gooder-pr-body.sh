#!/usr/bin/env bash
# write-gooder-pr-body: PreToolUse(Bash) guard for commands that WRITE a PR body.
#
# Same shape as gh-stack-steer.sh. Different failure it exists to catch.
#
# The failure is NOT "forgot the skill exists". CLAUDE.md already says to invoke
# write-gooder before writing a PR body, and it gets read every session. The
# failure is publishing a body without ever computing the LENGTH BUDGET, which
# is the one step that turns the skill from advice into a pass/fail gate. So
# this hook does not say "consider write-gooder"; it states the gate and the number.
#
# Observed 2026-08-31: PR #12's body shipped at 136 prose words against a
# 60-word budget (2.3x), with 6 test items against a cap of 5, one of which was
# a different PR's evidence. Every one of those is caught by measuring.
#
# Targets the commands that actually PUT PROSE INTO A PR:
#   gh pr create                  (any form)
#   gh pr edit ... --body/-b/--body-file/-F
#   gh stack submit               (drafts bodies for every new PR in the stack)
# Deliberately NOT targeted: git commit (write-gooder has no commit-message
# template; its PR template governs PR bodies), gh pr edit --title/--base/--add-label
# (no prose), and every read-only gh command.
#
# Adds context and never sets permissionDecision: a prompt on every PR write
# cost the human an approval for no safety gain. The docs place PreToolUse
# additionalContext alongside the tool result, so the reminder lands after the
# command runs and the fix for an unmeasured body is gh pr edit.
#
# NOT repo-scoped: unlike gh stack, write-gooder applies wherever PRs are
# written, so there is no marker file to test for.
#
# Command-position anchoring, ENV=val prefixes, and global-flag tolerance are
# copied from gh-stack-steer.sh; see that file's header for the reasoning.
# Determined evasion is out of scope: guardrail, not security boundary.

cmd=$(jq -r '.tool_input.command // empty' 2>/dev/null)

gh_pos='(^|[;&|(])[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*gh[[:space:]]+(-[^[:space:]]+[[:space:]]+([^-[:space:]][^[:space:]]*[[:space:]]+)?)*'

# gh pr create (any form), gh stack submit, or gh pr edit carrying a body flag.
if printf '%s' "$cmd" | grep -Eq "${gh_pos}pr[[:space:]]+create([[:space:]]|$)" \
|| printf '%s' "$cmd" | grep -Eq "${gh_pos}stack[[:space:]]+submit([[:space:]]|$)" \
|| { printf '%s' "$cmd" | grep -Eq "${gh_pos}pr[[:space:]]+edit([[:space:]]|$)" \
     && printf '%s' "$cmd" | grep -Eq '(^|[[:space:]])(--body|--body-file|-b|-F)([[:space:]=]|$)'; }; then
  context="That command writes a PR body, which the write-gooder skill (templates/pr.md) governs. Its length gate:
  1. BUDGET = files touched x 40, clamped to [60, 200]. Get the file count with: gh pr diff <N> --name-only | wc -l
  2. PROSE = description + pointer notes + concerns, counted with wc -w. The checkbox and the test plan are exempt.
  3. Over budget is a failure and the only fix is DELETION. Restructuring to fit is cheating.
  4. Caps: description 3 sentences, pointers 3, test-plan items 5, concerns 1 line each. No em dashes.
  5. gh pr edit --body-file REPLACES the whole body and will silently untick a checkbox the human ticked. Read the live body first (gh pr view <N> --json body -q .body) and confirm it after.
This context arrives with the tool result, so a body that was published unmeasured is measured now and fixed with gh pr edit."
  jq -cn --arg c "$context" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$c}}'
fi

exit 0
