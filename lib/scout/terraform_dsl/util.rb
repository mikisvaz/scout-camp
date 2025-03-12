require 'digest/md5'
require 'scout/path'

# rubocop: disable Style/Documentation
class TerraformDSL

  # rubocop: enable Style/Documentation
  

  # Log a message, optionally including a prefix between brakets
  #
  # @param msg [String] Message to log
  # @param prefix [nil,String] Optional prefix to prepend
  def self.log(msg, prefix = nil)
    if prefix
      STDOUT.puts("[#{prefix}] " + msg)
    else
      STDOUT.puts(msg)
    end
  end

  # Returns a md5 digest of an object based on its JSON representation
  #
  # @param obj [Object] object to digest
  def self.obj2digest(obj)
    Digest::MD5.hexdigest(obj.to_json)
  end

  # Gather information about the input variables of a terraform module
  #
  # @param module_dir [String] path to the directory with the module template files
  # @return [Hash] for each variable name holds a hash with
  #   description, type and default values
  def self.module_variables(module_dir)
    variables = {}

    file = module_dir['variables.tf']
    return variables unless Open.exist?(file)

    name, description, type, default = nil
    Open.read(file).split("\n").each do |line|
      if (m = line.match(/^\s*variable\s+"([^"]*)"/))
        if name
          variables[name] =
            { :description => description, :type => type, :default => default }
          name, description, type, default = nil
        end
        name = m[1].strip
      elsif (m = line.match(/description\s*=\s*"(.*)"/))
        description = m[1].strip
      elsif (m = line.match(/type\s*=\s*(.*)/))
        type = m[1].strip
      elsif (m = line.match(/default\s*=\s*(.*)/))
        default = begin
          JSON.parse(m[1].strip)
        rescue StandardError
          m[1].strip
        end
      end
    end

    if name
      variables[name] = { :description => description, :type => type, :default => default }
    end

    variables
  end

  # Gather information about the output variables of a terraform module
  #
  # @param module_dir [String] path to the directory with the module template files
  # @return [Hash] for each variable name holds a hash with the description
  def self.module_outputs(module_dir)
    outputs = {}

    module_dir = module_dir.find if Path === module_dir
    file = module_dir['output.tf']
    return outputs unless Open.exist?(file)

    name, description, value = nil
    Open.read(file).split("\n").each do |line|
      if (m = line.match(/^\s*output\s+"([^"]*)"/))
        if name
          outputs[name] = { :description => description }
          name, description, value = nil
        end
        name = m[1].strip
      elsif (m = line.match(/description\s*=\s*"(.*)"/))
        description = m[1].strip
      end
    end

    if name
      outputs[name] = { :description => description }
    end

    outputs
  end

end
