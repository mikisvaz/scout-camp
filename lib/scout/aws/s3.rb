require 'aws-sdk-s3'
require 'uri'

require 'scout/path'
require 'scout/open'
require 'scout/misc/hook'

module Open
  module S3
    extend Hook

    def self.lock(*args, &block)
      begin
        yield nil
      rescue KeepLocked
        $!.payload
      end
    end

    def self.is_s3?(uri)
      uri.start_with? 's3://'
    end

    def self.claim_uri(uri)
      if Path === uri and not uri.located?
        is_s3?(uri.find)
      else
        is_s3? uri
      end
    end

    def self.claim(uri, uri2=nil, ...)
      claim_uri(uri) || (String === uri2 && claim_uri(uri2))
    end

    def self.parse_s3_uri(uri)
      uri = uri.find if Path === uri and not uri.located?
      uri = uri.sub(%r{^s3://}, '')
      bucket, *key_parts = uri.split('/', -1)
      key = key_parts.join('/').sub(%r{^/}, '')
      [bucket, key]
    end

    def self.get_stream(uri, *args)
      bucket, key = parse_s3_uri(uri)
      return nil if key.empty?

      Open.open_pipe do |sin|
        s3 = Aws::S3::Client.new
        s3.get_object(bucket: bucket, key: key) do |block|
          sin.write block
        end
      end
    rescue Aws::S3::Errors::NoSuchKey
      nil
    end

    def self.write(uri, content = nil, &block)
      bucket, key = parse_s3_uri(uri)
      s3 = Aws::S3::Client.new
      content = Open.open_pipe(&block).read if block_given?
      content = content.read if IO === content
      s3.put_object(bucket: bucket, key: key, body: content)
    end

    def self.touch(uri)
      if self.exists?(uri)
      else
        self.cp(uri, uri)
      end
    end

    def self.glob(uri, pattern="*")
      bucket, prefix = parse_s3_uri(uri)
      s3 = Aws::S3::Client.new
      matches = []
      continuation_token = nil

      loop do
        resp = s3.list_objects_v2(
          bucket: bucket,
          prefix: prefix,
          continuation_token: continuation_token
        )

        resp.contents.each do |object|
          key = object.key

          if prefix.empty?
            remaining = key.sub(%r{^/}, '')
          else
            remaining = key[prefix.length..-1] || ''
            remaining = remaining.sub(%r{^/}, '')
          end

          Log.debug "Glob: #{remaining}"

          if File.fnmatch?(pattern, remaining, File::FNM_PATHNAME)
            matches << "s3://#{bucket}/#{key}"
          else
            dir = File.dirname(remaining)
            while dir 
              if File.fnmatch?(pattern, dir, File::FNM_PATHNAME)
                matches << "s3://#{bucket}/#{File.join(prefix,dir)}"
              end
              break if dir == File.dirname(dir)
              dir = File.dirname(dir)
            end
          end
        end

        continuation_token = resp.next_continuation_token
        break unless continuation_token
      end

      matches
    end

    def self.rm(uri)
      bucket, key = parse_s3_uri(uri)
      return false if key.empty? # Prevent accidental bucket deletion attempts

      s3 = Aws::S3::Client.new
      s3.delete_object(bucket: bucket, key: key)
      true
    rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NoSuchBucket
      false
    end

    def self.rm_rf(uri)
      bucket, prefix = parse_s3_uri(uri)
      s3 = Aws::S3::Client.new
      continuation_token = nil

      loop do
        resp = s3.list_objects_v2(
          bucket: bucket,
          prefix: prefix,
          continuation_token: continuation_token
        )

        if resp.contents.any?
          # Delete objects in batches of 1000 (S3 limit per request)
          objects = resp.contents.map { |obj| { key: obj.key } }
          s3.delete_objects(
            bucket: bucket,
            delete: { objects: objects, quiet: true }
          )
        end

        continuation_token = resp.next_continuation_token
        break unless continuation_token
      end

      true
    rescue Aws::S3::Errors::NoSuchBucket
      false
    end

    def self.cp(source, target)
      if is_s3?(target)
        if is_s3?(source)
          source_bucket, source_key = parse_s3_uri(source)
          target_bucket, target_key = parse_s3_uri(target)

          s3 = Aws::S3::Client.new
          s3.copy_object({
            copy_source: "#{source_bucket}/#{source_key}",
            bucket: target_bucket,
            key: target_key
          })
        else
          self.write(target, Open.get_stream(source))
        end
      else
        Open.sensible_write(target, get_stream(source))
      end
    end

    def self.mv(source, target)
      self.cp(source, target)
      Open.rm_rf source
    end

    def self.file_exists?(uri)
      bucket, key = parse_s3_uri(uri)
      return false if key.empty? # Can't check existence of bucket this way

      s3 = Aws::S3::Client.new
      s3.head_object(bucket: bucket, key: key)
      true
    rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchBucket
      false
    end
    
    def self.directory?(uri)
      bucket, key = parse_s3_uri(uri)
      return false if key.empty? # Can't check existence of bucket this way

      key += '/' unless key.end_with?('/')
      s3 = Aws::S3::Client.new
      response = s3.list_objects_v2({
        bucket: bucket,
        prefix: key,
        max_keys: 1
      })

      !response.contents.empty?
    end

    def self.exists?(uri)
      begin
        file_exists?(uri) || directory?(uri)
      rescue
        false
      end
    end

    self.singleton_class.alias_method :exist?, :exists?

    def self.sensible_write(path, content = nil, options = {}, &block)
      content = content.to_s if content.respond_to?(:write_file)
      Open::S3.write(path, content)
    end

    def self.mkdir(path)
    end

    def self.link(source, target, options = {})
      cp(source, target)
    end

    def self.ln(source, target, options = {})
      cp(source, target)
    end

    def self.ln_s(source, target, options = {})
      cp(source, target)
    end

    def self.sync(source, target, options = {})
      excludes, files, hard_link, test, print, delete, other = IndiferentHash.process_options options,
        :excludes, :files, :hard_link, :test, :print, :delete, :other

      excludes ||= %w(.save .crap .source tmp filecache open-remote)
      excludes = excludes.split(/,\s*/) if excludes.is_a?(String) and not excludes.include?("--exclude")

      if File.directory?(source) || source.end_with?("/")
        source += "/" unless source.end_with? '/'
        target += "/" unless target.end_with? '/'
      end

      if source == target
        Log.warn "Asking to sync with itself"
        return
      end

      Log.low "Migrating #{source} #{files.length} files to #{target} - #{Misc.fingerprint(files)}}" if files

      sync_args = %w()
      sync_args << excludes.collect{|s| "--exclude '#{s}'" } if excludes and excludes.any?
      sync_args << "-nv" if test

      if files
        tmp_files = TmpFile.tmp_file 's3_sync_files-'
        Open.write(tmp_files, files * "\n")
        sync_args << "--files-from='#{tmp_files}'"
      end

      if Open.directory?(source)
        cmd = "aws s3 sync #{sync_args * " "} #{source} #{target}"
      else
        cmd = "aws s3 cp #{source} #{target}"
      end
      case other
      when String
        cmd << " " << other
      when Array
        cmd << " " << other * " "
      end
      cmd << " && rm -Rf #{source}" if delete && ! files

      if print
        cmd
      else
        CMD.cmd_log(cmd, :log => Log::HIGH)

        if delete && files
          remove_files = files.collect{|f| File.join(source, f) }
          dirs = remove_files.select{|f| File.directory? f }
          remove_files.each do |file|
            next if dirs.include? file
            Open.rm file
          end

          dirs.each do |dir|
            FileUtils.rmdir dir if Dir.glob(dir).empty?
          end
        end
      end
    end
  end
end

module Path
  extend Hook

  module S3
    def located?
      Open::S3.is_s3?(self) || orig_located?
    end

    def glob(*args)
      if Open::S3.is_s3?(self.find)
        Open::S3.glob(self.find, *args)
      else
        orig_glob(*args)
      end
    end
  end
end

Hook.apply(Open::S3, Open)
Hook.apply(Path::S3, Path)
