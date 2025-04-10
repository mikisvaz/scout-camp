require 'scout/resource'
require_relative 'sync'
module Resource
  def self.sync(path, map = nil, source: nil, target: nil, resource: nil, **kwargs)
    map = 'user' if map.nil?

    if source
      paths = [path]
      real_paths, identified_paths = SSHLine.locate(source, paths)
    else
      resource = path.pkgdir if resource.nil? and path.is_a?(Path) and path.pkgdir.is_a?(Resource)
      resource = Resource.default_resource if resource.nil?

      if File.exist?(path)
        real_paths = [path]
      else
        path = Path.setup(path, pkgdir: resource) unless path.is_a?(Path)
        real_paths = path.directory? ? path.find_all : path.glob_all
      end
      
      identified_paths = real_paths.collect{|path| resource.identify(path) }
    end

    if target
      target_paths = SSHLine.locate(target, identified_paths, map: map)
    else
      target_paths = identified_paths.collect{|p| p.find(map) }
    end

    real_paths.zip(target_paths).each do |source_path,target_path|
      Open.sync(source_path, target_path, kwargs.merge(source: source, target: target))
    end
  end
end
