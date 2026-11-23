#!/usr/bin/env ruby
# frozen_string_literal: true

# Checks the plugin manifests and the skills they would load.
#   ruby test/plugin_test.rb

require 'minitest/autorun'
require 'json'

class PluginTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)

  def test_plugin_manifest_names_the_plugin
    assert_equal 'chuck-shared', read_json('.claude-plugin/plugin.json')['name']
  end

  def test_marketplace_lists_the_plugin_from_a_relative_source_that_exists
    entry = read_json('.claude-plugin/marketplace.json')['plugins'].find { |plugin| plugin['name'] == 'chuck-shared' }
    refute_nil entry, 'marketplace must list chuck-shared'
    assert entry['source'].start_with?('./'), 'relative sources must start with ./'
    assert File.directory?(File.expand_path(entry['source'], ROOT))
  end

  def test_every_skill_directory_has_a_skill_md
    assert_empty skill_dirs.reject { |dir| File.file?(File.join(dir, 'SKILL.md')) }.map { |dir| File.basename(dir) }
  end

  # A skill without a name takes its directory's name, so only a mismatch breaks it.
  def test_a_skill_that_declares_a_name_matches_its_directory
    problems = skill_dirs.select do |dir|
      name = frontmatter(File.join(dir, 'SKILL.md'))['name']
      name && name != File.basename(dir)
    end
    assert_empty problems.map { |dir| File.basename(dir) }
  end

  def test_every_skill_declares_a_description
    assert_empty skill_dirs.select { |dir| frontmatter(File.join(dir, 'SKILL.md'))['description'].to_s.empty? }
                           .map { |dir| File.basename(dir) }
  end

  private

  def read_json(rel)
    JSON.parse(File.read(File.join(ROOT, rel)))
  end

  def skill_dirs
    Dir.glob(File.join(ROOT, 'skills', '*')).select { |path| File.directory?(path) }.sort
  end

  # Top-level `key: value` lines of a leading --- block; empty when there is none.
  def frontmatter(path)
    return {} unless File.file?(path)

    lines = File.readlines(path, chomp: true)
    return {} unless lines.first == '---'

    body = lines.drop(1).take_while { |line| line != '---' }
    body.filter_map { |line| line.match(/\A(\w[\w-]*):\s*(.*)\z/)&.captures }.to_h
  end
end
