module Linner
  class Asset

    attr_accessor :path, :content

    def initialize(path)
      @path = path
      @content ||= begin
        File.exist?(path) ? Tilt.new(path).render : ""
      rescue RuntimeError
        File.read(path)
      end
    end

    def wrap
      Wrapper.wrap(logical_path.chomp(File.extname logical_path), @content)
    end

    def wrappable?
      !!(@path.include? Linner.environment.app_folder and Template.template_for_script?(@path))
    end

    def write
      FileUtils.mkdir_p File.dirname(@path)
      File.open @path, "w" do |file|
        file.write @content
      end
    end

    def compress
      @content = Compressor.compress(self)
    end

    def logical_path
      @logical_path ||= @path.gsub(/#{Linner.environment.app_folder}\/\w*\//, "")
    end
  end
end
