# Using the Terraform DLS (Domain Specific Language)

This document describes how to use the Terraform DLS implemented in lib/scout/terraform_dsl to programmatically compose Terraform configurations and manage deployments from Ruby. It is written for AI agents (or developers) that will generate Ruby code to create, plan, apply and inspect Terraform deployments using the provided DSL.

Where things live

- Library implementation: lib/scout/terraform_dsl.rb and lib/scout/terraform_dsl/*.rb
- Utilities and runtime: lib/scout/terraform_dsl/util.rb and lib/scout/terraform_dsl/deployment.rb
- Example module templates: share/terraform (e.g. share/terraform/aws/*)

Key classes and concepts

- TerraformDSL: main class that models a planned Terraform deployment. You create a TerraformDSL instance, add modules, providers, backends, custom files, then call config to write template files into a directory.

- TerraformDSL::Module: returned by add(...) and acts as a reference to a module instance inside the generated Terraform configuration. You can call arbitrary methods on it to get references to its outputs (e.g. my_module.some_output), which serialize to Terraform references like module.<instance>.<output>.

- TerraformDSL::Module::Output: representation of an output reference that serializes to a module output reference in Terraform JSON form.

- TerraformDSL::Deployment: helper for interacting with Terraform in a directory created by TerraformDSL#config. It wraps terraform init/plan/apply/destroy/refresh and provides helpers for reading outputs and state.

- Misc helpers in TerraformDSL (util.rb):
  - TerraformDSL.module_variables(module_dir) -> inspect variables.tf for a module
  - TerraformDSL.module_outputs(module_dir) -> inspect output.tf for a module

Common workflow (example)

1) Create a TerraformDSL and add elements/modules

```ruby
require 'scout/terraform_dsl'

# Create DSL (by default it uses share/terraform as modules dir)
# You can pass a custom modules dir if needed
dsl = TerraformDSL.new

# Add a provider block (creates a provider config file)
# Returns a Module reference if a provider module exists at modules_dir/<name>/provider
# Example: add AWS provider configuration (set credentials/region via variables)
dsl.provider('aws', region: 'eu-west-1')

# Add a module instance using the shared templates under share/terraform
# add(provider, module_name, variables)
# variables[:name] defaults to "<provider>_<module_name>" but you can override
web = dsl.add('aws', 'host', name: 'web1', ami: 'ami-01234567', instance_type: 't3.micro')
db  = dsl.add('aws', 'host', name: 'db1', ami: 'ami-01234567', instance_type: 't3.small')

# You can connect modules using module output references returned by Module instances
# E.g. use an output from db as input to web
# (Assuming the module exposes the output name you want)
# web2 = dsl.add('aws', 'some_module', name: 'web2', subnet_id: db.subnet_id)

# Request that specific outputs from a module become deployment outputs
# Provide outputs in variables[:outputs] or use :outputs => 'all'
app = dsl.add('aws','host', name: 'app1', ami: 'ami-01234567', outputs: ['aws_instance_id', 'aws_instance_ip'])
```

2) Add custom provider/backend/remote files if needed

```ruby
# Add a backend configuration (example for s3 backend)
dsl.backend('s3', bucket: 'my-bucket', key: 'path/to/state', region: 'eu-west-1')

# Add a remote data block pointing to another state
# Returns a direct reference object you can use as a value in variables
other_state = dsl.remote('s3', 'shared_state', bucket: 'my-bucket', region: 'eu-west-1')
# other_state is a DirectReference object that serializes to a terraform reference

# Add arbitrary terraform content (for uncommon provider configs)
dsl.custom('provider.aws.extra', <<~TF)
  provider "aws" {
    # extra provider settings
  }
TF
```

3) Generate config files into a directory

```ruby
# Write files into a working dir (if you pass no arg, a directory based on elements digest is used)
config_dir = dsl.config # returns the directory path (Path-like) containing .tf files
# You can pass a path: dsl.config('/tmp/my-deploy')
```

4) Manage the terraform deployment

```ruby
# Create a Deployment helper for that directory
deployment = TerraformDSL::Deployment.new(config_dir)

# Initialize provider plugins and backend
deployment.init

# Validate if wanted
deployment.validate

# Create a plan (saves plan to main.plan)
deployment.plan

# Apply (will run plan if you didn't)
deployment.apply

# Read outputs (hash with output_name => value)
outs = deployment.outputs
puts outs['app1_aws_instance_ip']

# Destroy the whole deployment
deployment.destroy
```

Notes about Module references and variables

- When you call add(...) you get back a TerraformDSL::Module object representing that instance.
  - Calling arbitrary methods on that object returns a Module::Output that serializes into the Terraform reference module.<instance>.<output>. Example: web.ami_id or web.aws_instance_id depending on module output name.
  - You can directly use these Module output references when setting variables for other modules (they will be serialized correctly into the .tf generated files).

- The DSL also accepts values that are already Terraform-style strings such as "module.some_mod.some_output" — the DSL converts those into Output references when generating variable assignments.

Inspection utilities

- Inspect module variables (what variables a module expects):

```ruby
module_dir = Scout.share.terraform['aws']['host']
vars = TerraformDSL.module_variables(module_dir)
# vars is a hash: { 'ami' => {description: '...', type: 'string', default: ...}, ... }

outs = TerraformDSL.module_outputs(module_dir)
# outs is a hash of available outputs and their descriptions
```

Deployment helper details

- TerraformDSL::Deployment.run(cmd)
  - Executes terraform <cmd> and returns stdout. Raises TerraformException on non-zero exit.

- TerraformDSL::Deployment.run_log(cmd, log_file=nil)
  - Runs terraform <cmd> streaming STDERR and STDOUT into logs and raising TerraformException on error. Accepts a log_file to capture full logs.

- Useful methods on Deployment objects:
  - init, plan, apply, refresh, validate, update (init+plan+apply), destroy
  - plan_file -> path to stored plan (main.plan)
  - log_file -> path to log file for that work directory
  - outputs -> reads terraform output -json and returns a Ruby hash with values
  - element_state(element) -> shows terraform state show <element>
  - provisioned_elements -> terraform state list

Advanced: bundling and loading

- You can bundle a deployment directory into a tar.gz with Deployment#bundle(file) and load it back with Deployment.load(file). The loader will extract the bundle into a working dir and refresh the state.

Where to find module templates

- The default module directory is Scout.share.terraform which points to share/terraform in this repository. Look under share/terraform/aws, share/terraform/ssh etc. Each module is a directory containing Terraform templates (main.tf, variables.tf, output.tf, ...).

Example full script (end-to-end)

```ruby
require 'scout/terraform_dsl'

# Build DSL
dsl = TerraformDSL.new
dsl.provider('aws', region: 'eu-west-1')
app = dsl.add('aws', 'host', name: 'app1', ami: 'ami-01234567', instance_type: 't3.micro', outputs: ['aws_instance_id','aws_instance_ip'])

# Generate files
config_dir = dsl.config

# Manage terraform
deployment = TerraformDSL::Deployment.new(config_dir)
deployment.init
deployment.plan
deployment.apply
puts deployment.outputs # => hash of outputs

# Cleanup
deployment.destroy
```

Tips for agents generating code

- Always call dsl.config before creating a Deployment. config writes the .tf files and returns the directory path used by Deployment.
- Prefer using Module objects to pass references between modules instead of hard-coding strings. Example: db.private_ip (where db is the Module returned by add).
- Use TerraformDSL.module_variables and module_outputs to discover what a module expects/returns when generating variables and wiring between modules.
- Use Deployment.run_log when you want log files and streamed logs for troubleshooting.

If you need more examples, look at the modules under share/terraform/aws and share/terraform/ssh for real-world templates.

End of document
