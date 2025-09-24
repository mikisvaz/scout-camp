require 'scout'
module ScoutRender
  extend Resource

  self.subdir = 'share/views'

  def self.find_resource(name, extension: %(slim erb haml)  )
    return name.find_with_extension(extension) if Path === name && name.find_with_extension(extension).exists?
    ScoutRender.root[name].find_with_extension(extension)
  end

  def self.find_haml(name)
    find_resource(name, extension: 'haml')
  end

  def self.find_slim(name)
    find_resource(name, extension: 'slim')
  end

  def self.find_js(name)
    find_resource(name, extension: 'js')
  end

  def self.find_sass(name)
    find_resource(name, extension: 'sass')
  end

  class << self
    undef :method_missing

    attr_accessor :app_dir, :cache_dir, :files_dir

    def app_dir
      @app_dir ||= Scout.var.render[self.to_s]
    end

    def cache_dir
      @cache_dir ||= app_dir.cache
    end

    def files_dir
      @files_dir ||= app_dir.files
    end
  end
end
