require 'scout/resource'
require_relative 'sync'
module Resource
  class << self
    attr_accessor :sync_servers, :file_servers

    def sync_servers
      @sync_servers ||= begin
                          config_file = Scout.etc.sync_servers.find_with_extension('yaml', produce: false)
                          if config_file.exists?(produce: false)
                            config_file.yaml
                          else
                            {}
                          end
                        end
    end

    def sync_server(resource)
      return sync_servers[resource.to_s]
    end

    def file_servers
      @file_servers ||= begin
                          config_file = Scout.etc.file_servers.find_with_extension('yaml', produce: false)
                          if config_file.exists?(produce: false)
                            config_file.yaml
                          else
                            {}
                          end
                        end
    end

    def file_server(resource)
      return file_servers[resource.to_s]
    end

  end

  def self.sync(path, map = nil, source: nil, target: nil, resource: nil, **kwargs)
    if source
      paths = [path]
      real_paths, identified_paths = SSHLine.locate(source, paths, map: nil)
    else
      resource = path.pkgdir if resource.nil? and path.is_a?(Path) and path.pkgdir.is_a?(Resource)
      resource = Resource.default_resource if resource.nil?

      if Path.located?(path)
        real_paths = [path]
      else
        path = Path.setup(path, pkgdir: resource) unless path.is_a?(Path)
        real_paths = path.directory? ? path.find_all : path.glob_all
      end

      identified_paths = real_paths.collect{|path| resource.identify(path) }
    end

    if target
      map = 'user' if map.nil?
      target_paths, identified_paths = SSHLine.locate(target, identified_paths, map: map)
    else
      target_paths = identified_paths.collect{|p| p.find(map) }
    end

    real_paths.zip(target_paths).each do |source_path,target_path|
      next if source_path.nil?
      Open.sync(source_path, target_path, kwargs.merge(source: source, target: target))
    end
  end

  def self.get_from_server(path, final_path, remote_server)
    url = File.join(remote_server, '/resource/', self.to_s, 'get_file')
    url << "?" << Misc.hash2GET_params(:file => path, :create => false)

    begin
      @server_missing_resource_cache ||= Set.new
      raise "Resource Not Found" if @server_missing_resource_cache.include? url
      Net::HTTP.get_response URI(url) do |response|
        case response
        when Net::HTTPSuccess, Net::HTTPOK
          Misc.sensiblewrite(final_path) do |file|
            response.read_body do |chunk|
              file.write chunk
            end
          end
        when Net::HTTPRedirection, Net::HTTPFound
          location = response['location']
          Log.debug("Feching directory from: #{location}. Into: #{final_path}")
          FileUtils.mkdir_p final_path unless File.exist? final_path
          Misc.in_dir final_path do
            CMD.cmd('tar xvfz -', :in => Open.open(location, :nocache => true))
          end
        when Net::HTTPInternalServerError
          @server_missing_resource_cache << url
          raise "Resource Not Found"
        else
          raise "Response not understood: #{response.inspect}"
        end
      end
    rescue
      Log.warn "Could not retrieve (#{self.to_s}) #{ path } from #{ remote_server }"
      Log.error $!.message
      Open.rm_rf final_path if Open.exist? final_path
      raise $!
    end
  end

  def file_server
    Resource.file_server(self)
  end

  def sync_server
    Resource.sync_server(self)
  end

  alias local_produce produce
  def produce(path, *args, **kwargs)
    if sync_server = self.sync_server
      begin
        Resource.sync(Resource.default_resource.identify(path), source: sync_server)
        return path if Open.exists?(path)
      rescue
        Log.exception $!
      end
    end

    if file_server = self.file_server
      begin
        Resource.get_from_server(Resource.default_resource.identify(path), path.find, file_server)
        return path if Open.exists?(path)
      rescue
        Log.exception $!
      end
    end

    local_produce(path, *args, **kwargs)
  end


end
