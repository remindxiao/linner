require "nokogiri"

require "linner/version"
require "linner/command"
require "linner/asset"
require "linner/cache"
require "linner/helper"
require "linner/reactor"
require "linner/wrapper"
require "linner/template"
require "linner/notifier"
require "linner/compressor"
require "linner/environment"

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

module Linner
  extend self

  attr_accessor :compile

  def root
    @root ||= Pathname('.').expand_path
  end

  def env
    @env ||= Environment.new begin
      linner_file = root.join("Linnerfile")
      config_file = root.join("config.yml")
      File.exist?(linner_file) ? linner_file : config_file
    end
  end

  def cache
    @cache ||= Cache.new
  end

  def manifest
    @manifest ||= begin
      hash = {}
      env.groups.each do |config|
        config["concat"].to_h.each do |dest, pattern|
          asset = Asset.new(File.join env.public_folder, dest)
          hash[dest] = asset.relative_digest_path
          asset.revision!
        end
      end
      hash
    end
  end

  def compile?
    @compile
  end

  def sass_engine_options
    @options ||= begin
      options = Compass.configuration.to_sass_engine_options
      env.paths.each do |load_path|
        options[:load_paths] << Sass::Importers::Filesystem.new(load_path)
      end
      options
    end
  end

  def perform(*asset)
    env.groups.each do |config|
      copy(config) if config["copy"]
      concat(config) if config["concat"]
    end
    revision if compile? and env.revision
  end

private
  def concat(config)
    config["concat"].each_with_index do |pair, index|
      dest, pattern, order = pair.first, pair.last, config["order"]||[]
      matches = Dir.glob(pattern).sort_by(&:downcase).order_by(order)
      next if matches.select {|p| cache.miss? p}.empty?
      write_asset(dest, matches)
    end
  end

  def copy(config)
    config["copy"].each do |dest, pattern|
      Dir.glob(pattern).each do |path|
        next if not cache.miss?(path)
        logical_path = Asset.new(path).logical_path
        dest_path = File.join(env.public_folder, dest, logical_path)
        FileUtils.mkdir_p File.dirname(dest_path)
        FileUtils.cp_r path, dest_path
      end
    end
  end

  def revision
    dump_manifest
    [env.revision].flatten.each do |rev|
      file = File.join env.public_folder, rev.to_s
      next if not File.exist?(file)
      replace_attributes file
    end
  end

  private

  def write_asset(dest, child_assets)
    asset = Asset.new(File.join env.public_folder, dest)
    definition = (asset.path == env.definition ? Wrapper.definition : "")
    asset.content = child_assets.inject(definition) {|s, m| s << cache[m].content}
    asset.compress if compile?
    asset.write
  end

  def replace_attributes file
    doc = Nokogiri::HTML.parse(File.read file)
    replace_tag_with_manifest_value doc, "script", "src"
    replace_tag_with_manifest_value doc, "link", "href"
    File.open(file, "w") {|f| f.write doc.to_html}
  end

  def replace_tag_with_manifest_value doc, tag, attribute
    doc.search(tag).each do |x|
      next unless node = x.attributes[attribute]
      x.set_attribute attribute, manifest[node.value]
    end
  end

  def dump_manifest
    File.open(File.join(env.public_folder, env.manifest), "w") do |f|
      YAML.dump(manifest, f)
    end
  end
end
