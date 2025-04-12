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

    def self.claim(uri, ...)
      if Path === uri and not uri.located?
        is_s3? uri.find
      else
        is_s3? uri
      end
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

    def self.glob(uri, pattern="**/*")
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
      source_bucket, source_key = parse_s3_uri(source)
      target_bucket, target_key = parse_s3_uri(target)

      s3 = Aws::S3::Client.new
      s3.copy_object({
        copy_source: "#{source_bucket}/#{source_key}",
        bucket: target_bucket,
        key: target_key
      })
    end

    def self.exists?(uri)
      bucket, key = parse_s3_uri(uri)
      return false if key.empty? # Can't check existence of bucket this way

      s3 = Aws::S3::Client.new
      s3.head_object(bucket: bucket, key: key)
      true
    rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchBucket
      false
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


#$ ask -t code --file /home/miki/git/scout-camp/lib/scout/aws/s3.rb extend this file [[...]] to include a function called self.exists? that determines if a uri exists {{{
