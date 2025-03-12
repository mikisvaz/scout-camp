require_relative 'terraform_dsl/util'
require_relative 'terraform_dsl/deployment'
require 'scout-gear'
require 'json'

# Objects of this class contain the elements that will form
# a terraform deployment configuration
class TerraformDSL

  attr_accessor :elements, :modules, :name, :processed_elements, :processed_custom_files

  # Module objects hold the identity of a module and
  # its :name, and can be used to create
  # references to its outputs to pass as inputs for
  # another module
  class Module

    attr_accessor :name, :type, :deployment

    # Output objects are references to a Module output
    # that can be used as parameters for other modules
    # inputs
    class Output

      attr_accessor :module, :name

      # Create an Output object
      #
      # @param mod [String] module template name
      # @param name [String] instance name
      def initialize(mod, name)
        @module = mod
        @name = name
      end

      # Callback to produce the json content when we serialize
      # variable values. It becomes a reference to a Module
      # output variable
      #
      # @param args [Array] Extra arguments to to_json, not used
      # @return [String] A reference of an output for terraform 
      #         (e.g.module.<modulename>.<name>)
      def to_json(*_args)
        ['module', @module, @name].join('.')
      end

    end

    # Create a new Module
    #
    # @param name [String] instance name
    # @param type [String] module template name
    def initialize(name, type, deployment)
      @name = name
      @type = type
      @deployment = deployment
    end

    # Construct output variable references to use on templates. They
    # will be serialized when used in templates
    #
    # @param output [String] the name of the output
    # @return [Output] An output variable for Terraform templates
    def method_missing(output)
      Output.new(@name, output)
    end

    # Any missing method call can be the name of an output
    def respond_to_missing?(_method_name, _include_private = false)
      true
    end

    # Callback to produce the json content when we serialize
    # variable values. It becomes a reference to a Module itself,
    # and can be used in depends_on statements
    #
    # @param args [Array] Extra arguments to to_json, not used
    # @return [String] A reference to a module in Terraform format
    #         (e.g. module.<modulename>)
    def to_json(*_args)
      ['module', @name].join('.')
    end

  end

  MODULES_DIR = Scout.share.terraform
  ANSIBLE_DIR = Scout.share.ansible
  WORK_DIR = Scout.var.terraform

  # Create a new terraform deployment configuration
  #
  # @param modules [String] directory containing module templates
  def initialize(modules = MODULES_DIR)
    @modules = modules
    @elements = []
    @custom_files = []
    @variables = {}
    @element_files = []
  end

  # Add a new module instance
  #
  # @param provider [String] first level of template organization subdirectory
  # @param module_name [String] subdirectory containing the module to use
  # @param variables [Hash] values for variables in the module template, and
  #   :name to name the module instance, and :outputs to define the module
  #   variables that will become deployment outputs
  # @return [Module] A module object used as a reference in Terraform templates
  def add(provider = nil, module_name = nil, variables = {})
    variables[:name] ||= variables["name"] ||= [provider, module_name].join('_')
    module_directory = @modules[provider][module_name]
    @elements << [provider, module_name, module_directory, variables]
    @variables.merge!(variables)
    Module.new(variables[:name], module_name, self)
  end

  # Terraform text that describes variables passed to a given module instance
  #
  # @param variables [Hash] module variables and their values, :name and
  #   :outputs are ignored as they are not module variables themselves
  #
  # @return [String] text to include inside the terraform module definition
  #   containing the variable assignments
  def variable_block(variables)
    variables.each_with_object([]) do |p, acc|
      name, value = p
      next acc if name.to_s == 'name'
      next acc if name.to_s == 'outputs'

      if value.is_a?(String) && (m = value.match(/^module\.(.*)\.(.*)/))
        value = Module::Output.new m[1], m[2]
      end

      acc << "  #{name} = #{value.to_json}"
    end * "\n"
  end

  # Populate a directory with the terraform templates corresponding to the
  # defined elements
  #
  # @param dir [String] directory from which to manage the deployment
  def main(dir)
    @elements.each do |info|
      _provider, _module_name, template, variables = info

      template = template.find
      # Add an additional / to mark the base_path of the module directory and
      # allow modules to reference other modules relatively
      template = template.split('/').tap {|l| l[-2] = '/'+l[-2] } * '/'

      name = variables[:name]

      text =<<~EOF
          module "#{name}" {
            source = "#{template}"
          #{variable_block(variables)}
          }
      EOF

      element_file = [_module_name, name.to_s.sub(/_#{_module_name}$/,'')] * "."

      # rubocop: disable Layout/LineLength
      raise Deployment::TerraformException,
        "Warning: element file '#{element_file}' already exists, consider renaming it by using the parameter ':name'" if @element_files.include?(element_file)
      # rubocop: enable Layout/LineLength

      @element_files << element_file

      Open.write(dir[element_file + '.tf'], text)
    end
  end

  # Add a terraform file with custom content. Used only
  # to support defining non Hashicorp provider configuration
  #
  # @param file [String] name of the file
  # @param text [String] content of the file
  def custom(file, text)
    @custom_files << [file, text]
    nil
  end

  # Add a provider template file without using modules.
  # Defining providers in modules is problematic when providers
  # are not managed by Hashicorp. Hopefully we can
  # find a fix for this soon.
  #
  # @param name [String] name of the provider
  # @param variables [Hash] variables for the provider:
  #   :source & :version
  # @return [nil, Module] If a Module is found at <modules_dir>/<name>/provider 
  #         it returns it
  def provider(name, variables = {})
    variables = variables.dup

    if Open.exist?(@modules[name].provider)
      provider = add name, :provider
    else
      provider = nil
    end

    source = variables.delete :source
    version = variables.delete :version

    text = ''

    if source
      if version
        text +=<<~EOF
            terraform {
              required_providers {
                #{name} = {
                source = "#{source}"
                version = "#{version}"
                }
              }
            }
        EOF
      else
        text +=<<~EOF
            terraform {
              required_providers {
                #{name} = {
                source = "#{source}"
                }
              }
            }
        EOF
      end
    end

    text +=<<~EOF
        provider "#{name}" {
        #{variable_block(variables)}
        }
    EOF

    element_file = ['provider_config', name.to_s].join('.')

    custom(element_file, text)

    provider
  end

  # Populate a directory with the terraform templates corresponding to the
  # custom defined elements
  #
  # @param dir [String] directory from which to manage the deployment
  def custom_files(dir)
    @custom_files.each do |element_file, text|
      Open.write(dir[element_file + '.tf'], text)
    end
  end

  # Populate a directory with the terraform templates corresponding to the
  # defined element outputs variables
  #
  # @param dir [String] directory from which to manage the deployment
  def outputs(dir)
    @elements.each do |info|
      _provider, module_name, template, variables = info
      outputs = variables[:outputs]
      module_outputs = TerraformDSL.module_outputs(template)
      outputs = module_outputs.keys if outputs.to_s == 'all'
      next unless outputs && outputs.any?

      name = variables[:name]

      outputs = outputs.collect do |o|
        (o.is_a?(String) || o.is_a?(Symbol)) && o.to_s == 'all' ? module_outputs.keys : o
      end.flatten.uniq if outputs.is_a?(Array)

      text = ''
      outputs.each do |output, output_rename = nil|
        output, output_rename = output.collect.first if output.is_a?(Hash)

        output_rename = output if output_rename.nil?

        description = module_outputs[output.to_s][:description]
        description ||= "Value of #{output} from module #{name} (type #{module_name})"

        text +=<<~EOF
            output "#{name}_#{output_rename}"{
              description = "#{description}"
              value = module.#{name}.#{output}
            }
        EOF
      end

      element_file = [module_name, name.to_s] * "."

      Open.write(dir[element_file + '.outputs.tf'], text)
    end
  end

  # Populate a directory all the necessary templates: modules, outputs,
  # and custom
  #
  # @param dir [String] directory from which to manage the deployment. If none
  #   provided a unique one will be generated based on a md5 digest of
  #   the elements defined
  def config(dir = nil)
    dir = WORK_DIR[TerraformDSL.obj2digest(@elements)] if dir.nil?
    Open.mkdir dir
    main(dir)
    outputs(dir)
    custom_files(dir)
    @processed_elements ||= []
    @processed_elements.concat(@elements)
    @processed_custom_files ||= []
    @processed_custom_files.concat(@custom_files)
    @elements = []
    @custom_files = []
    dir
  end

end
