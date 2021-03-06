require "yaml"

module Linner
  class Environment

    def initialize(path)
      @env ||= (YAML::load(File.read path) || Hash.new)
      @convension = YAML::load File.read(File.join File.dirname(__FILE__), "../../vendor", "config.default.yml")
      @env = @convension.rmerge!(@env)
    end

    %w(app test vendor public).each do |method|
      define_method("#{method}_folder") do
        @env["paths"][method]
      end
    end

    def paths
      groups.map { |group| group["paths"] }.flatten.uniq
    end

    def watched_paths
      [app_folder, vendor_folder, test_folder].select do |path|
        File.exists? path
      end
    end

    %w(revision notification manifest).each do |method|
      define_method("#{method}") do
        @env[method]
      end
    end

    def modules_ignored
      Dir.glob(@env["modules"]["ignored"])
    end

    def wrapper
      @env["modules"]["wrapper"]
    end

    def definition
      File.join public_folder, @env["modules"]["definition"]
    end

    def groups
      @env["groups"].values
    end
  end
end
