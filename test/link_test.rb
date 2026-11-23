#!/usr/bin/env ruby
# frozen_string_literal: true

# Exercises the shared link.rb against a throwaway CLAUDE_HOME. Stdlib only.
#   ruby test/link_test.rb

require 'minitest/autorun'
require 'json'
require 'tmpdir'

class SharedLinkTest < Minitest::Test
  SRC = File.expand_path('..', __dir__)

  def link(home)
    system({ 'CLAUDE_HOME' => home }, File.join(SRC, 'link.rb'),
           out: File::NULL, err: File::NULL)
  end

  def with_home
    Dir.mktmpdir do |home|
      link(home)
      yield home
    end
  end

  def test_skills_is_a_real_dir_not_a_symlink
    with_home do |home|
      assert File.directory?(File.join(home, 'skills'))
      refute File.symlink?(File.join(home, 'skills'))
    end
  end

  def test_content_links
    with_home do |home|
      assert File.symlink?(File.join(home, 'skills', 'write-gooder'))
      assert File.symlink?(File.join(home, 'skills', 'double-check'))
      assert File.symlink?(File.join(home, 'rules', 'testing.md'))
      assert File.symlink?(File.join(home, 'hooks', 'learning-opportunities-commit-nudge.sh'))
      assert File.symlink?(File.join(home, 'hooks', 'gh-stack-steer.sh'))
      assert File.symlink?(File.join(home, 'hooks', 'write-gooder-pr-body.sh'))
    end
  end

  def test_shared_settings_excludes_work_only_keys
    settings = JSON.parse(File.read(File.join(SRC, 'settings.json')))
    refute settings.key?('apiKeyHelper'), 'NR credential helper must stay work-only'
    refute settings.dig('env', 'ANTHROPIC_BASE_URL'), 'NR gateway URL must stay work-only'
    refute settings.key?('statusLine'), 'work statusLine must stay work-only'
    refute settings.key?('model'), 'home picks its own model'
    assert settings.dig('env', 'CLAUDE_CODE_SCROLL_SPEED'), 'general env must be preserved'
    assert_includes settings.dig('permissions', 'deny'), 'Bash(spr:*)'
  end

  def test_every_hook_script_is_wired_in_settings
    settings = JSON.parse(File.read(File.join(SRC, 'settings.json')))
    commands = settings['hooks'].values.flatten.flat_map { |entry| entry['hooks'] }.map { |hook| hook['command'] }
    unwired = Dir.children(File.join(SRC, 'hooks')).reject { |script| commands.any? { |cmd| cmd.include?(script) } }
    assert_empty unwired
  end

  def test_pr_hooks_guard_bash_before_it_runs
    settings = JSON.parse(File.read(File.join(SRC, 'settings.json')))
    bash = settings.dig('hooks', 'PreToolUse').select { |entry| entry['matcher'] == 'Bash' }
    commands = bash.flat_map { |entry| entry['hooks'] }.map { |hook| hook['command'] }
    %w[gh-stack-steer.sh write-gooder-pr-body.sh].each do |script|
      assert(commands.any? { |cmd| cmd.end_with?(script) }, "#{script} must run on PreToolUse(Bash)")
    end
  end

  def test_engineering_standards_stays_work_only
    with_home do |home|
      refute File.exist?(File.join(home, 'rules', 'engineering-standards.md'))
    end
  end

  def test_claude_md_is_not_linked
    with_home do |home|
      refute File.exist?(File.join(home, 'CLAUDE.md')), 'CLAUDE.md is merged by hand, not linked'
    end
  end

  def test_settings_json_is_not_linked
    with_home do |home|
      refute File.exist?(File.join(home, 'settings.json')),
             'settings.json is merged by hand, not linked'
    end
  end

  def test_dotfiles_are_not_linked
    junk = File.join(SRC, 'skills', '.DS_Store')
    File.write(junk, '')
    with_home do |home|
      refute File.exist?(File.join(home, 'skills', '.DS_Store')),
             'Finder junk must not be linked into ~/.claude'
    end
  ensure
    File.delete(junk) if junk && File.exist?(junk)
  end

  def test_no_nr_account_ids_in_public_content
    ids = /\b(?:1037563|313870|11044818|3172319|332029)\b/
    hits = Dir.glob(File.join(SRC, '{skills,rules}', '**', '*'))
              .select { |f| File.file?(f) && File.read(f).match?(ids) }
    assert_empty hits, "NR account IDs must not appear in public content: #{hits}"
  end
end
