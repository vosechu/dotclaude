#!/usr/bin/env ruby
# frozen_string_literal: true

# Runs hook scripts with a PreToolUse payload on stdin. Stdlib only.
#   ruby test/hooks_test.rb

require 'minitest/autorun'
require 'json'
require 'open3'

class HooksTest < Minitest::Test
  HOOK = File.expand_path('../hooks/write-gooder-pr-body.sh', __dir__)

  def run_hook(command)
    out, status = Open3.capture2(HOOK, stdin_data: { tool_input: { command: command } }.to_json)
    assert status.success?
    out
  end

  def test_a_command_that_writes_a_pr_body_adds_context_without_asking
    output = JSON.parse(run_hook('gh pr create --title x --body-file b.md')).fetch('hookSpecificOutput')
    assert_equal 'PreToolUse', output['hookEventName']
    assert_includes output['additionalContext'], 'write-gooder'
    refute output.key?('permissionDecision'), 'a decision here would prompt the user'
  end

  def test_editing_a_pr_body_is_covered
    refute_empty run_hook('gh pr edit 5 --body-file b.md')
  end

  def test_gh_stack_submit_is_covered
    refute_empty run_hook('gh stack submit')
  end

  def test_other_commands_stay_silent
    assert_empty run_hook('gh pr edit 5 --add-label bug')
    assert_empty run_hook('git commit -m "gh pr create"')
  end
end
