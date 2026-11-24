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

  def test_rules_are_linked
    with_home do |home|
      assert File.symlink?(File.join(home, 'rules', 'testing.md'))
    end
  end

  # The chuck-shared plugin ships these; a symlink as well would load each twice.
  def test_what_the_plugin_ships_is_not_linked
    with_home do |home|
      %w[skills agents commands hooks].each do |dir|
        refute File.exist?(File.join(home, dir)), "#{dir}/ is the plugin's, not linked into ~/.claude"
      end
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

  def test_settings_declares_no_hooks_because_the_plugin_does
    settings = JSON.parse(File.read(File.join(SRC, 'settings.json')))
    refute settings.key?('hooks'), 'a hook in settings.json and in hooks/hooks.json runs twice'
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
    junk = File.join(SRC, 'rules', '.DS_Store')
    File.write(junk, '')
    with_home do |home|
      refute File.exist?(File.join(home, 'rules', '.DS_Store')),
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
