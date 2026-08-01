# Provisioning Infrastructure

This document explains how to use the Terraform DSL to define cloud infrastructure in Ruby and generate Terraform configuration files. It is intended for workflow authors who need to provision servers, networks, storage, and other cloud resources.

## When to use this

Use the Terraform DSL when you want to:

- Provision cloud infrastructure programmatically from Ruby
- Compose pre-built module templates (hosts, networks, buckets, etc.)
- Generate Terraform configuration without writing HCL by hand
- Track infrastructure deployments and their state

If you only need to run commands on an existing server, see [Remote Execution](RemoteExecution.md). If you need to deploy infrastructure you've already defined, see [Managing Deployments](ManagingDeployments.md).

## Core concepts

### TerraformDSL

A `TerraformDSL` instance is a configuration builder. You add modules to it, configure providers and backends, and then generate `.tf` files.

### Modules

Modules are pre-built Terraform module templates stored in `share/terraform/`. Each module is a directory with `main.tf`, `variables.tf`, and optionally `output.tf`. You add modules by provider and name:

```ruby
terraform.add :aws, :host, ami: 'ami-123', instance_type: 't3.micro'
```

This adds the `share/terraform/aws/host/` module with the given variables.

### Module references

When a module produces outputs, you can reference them directly. Module outputs are available as methods on the module object, and they serialize to Terraform's module reference syntax automatically:

```ruby
host = terraform.add :aws, :host, ami: 'ami-123', instance_type: 't3.micro'
network = terraform.add :aws, :network, vpc_id: host.vpc_id
```

Here, `host.vpc_id` produces a reference to the `vpc_id` output of the host module. This reference is written into the network module's configuration as a Terraform interpolation.

## Defining infrastructure

### Basic example

```ruby
require 'scout-camp'

terraform = TerraformDSL.new

# Add a provider configuration
terraform.aws region: 'us-east-1'

# Add modules
host = terraform.add :aws, :host,
  ami: 'ami-0c02fb55956c7d316',
  instance_type: 't3.micro',
  key_name: 'my-key'

network = terraform.add :aws, :network,
  vpc_id: host.vpc_id,
  subnet_id: host.subnet_id

# Generate configuration files
terraform.config '/path/to/deployment'
```

### Adding modules

The `add` method takes a provider name, a module name, and a hash of variables:

```ruby
terraform.add :aws, :host, ami: '...', instance_type: '...'
terraform.add :aws, :bucket, bucket_name: 'my-bucket'
terraform.add :ssh, :cmd, host: 'server.example.com', user: 'ubuntu', command: 'systemctl start nginx'
```

Available modules depend on what's in `share/terraform/`. See [the module catalog below](#available-modules) for the full list.

### Providers and backends

Configure providers at the top level:

```ruby
terraform.aws region: 'us-east-1'
```

Configure backends for state management:

```ruby
terraform.backend :s3, bucket: 'my-tf-state', key: 'terraform.tfstate', region: 'us-east-1'
```

Configure remote state backends:

```ruby
terraform.remote :s3, bucket: 'my-tf-state', key: 'terraform.tfstate'
```

### Custom blocks

For raw Terraform configuration that doesn't fit a module:

```ruby
terraform.custom do
  <<~EOF
    resource "aws_sns_topic" "alerts" {
      name = "alerts"
    }
  EOF
end
```

## Available modules

### AWS modules

| Module | Purpose | Key variables |
|--------|---------|---------------|
| `aws/host` | EC2 instance | `ami`, `instance_type`, `key_name` |
| `aws/network` | VPC, subnets, security groups | `vpc_id`, `subnet_id` |
| `aws/bucket` | S3 bucket | `bucket_name` |
| `aws/cluster` | Cluster of EC2 instances | `cluster_size`, `instance_type` |
| `aws/role_policy` | IAM role and policy | `role_name`, `policy_arn` |
| `aws/lambda` | Lambda function | `function_name`, `runtime`, `handler`, `filename` |
| `aws/provider` | AWS provider configuration and data sources | `region` |

### SSH modules

| Module | Purpose | Key variables |
|--------|---------|---------------|
| `ssh/cmd` | Run a command over SSH | `host`, `user`, `command` |

## Common patterns

### Referencing outputs between modules

```ruby
host1 = terraform.add :aws, :host, ami: 'ami-1', instance_type: 't3.micro'
host2 = terraform.add :aws, :host, ami: 'ami-2', instance_type: 't3.small', depends_on: [host1]

# Use outputs from host1 in another module
terraform.add :aws, :network, vpc_id: host1.vpc_id
```

### Multiple instances of the same module

Each `add` call creates a new named instance:

```ruby
web1 = terraform.add :aws, :host, ami: 'ami-web', instance_type: 't3.micro'
web2 = terraform.add :aws, :host, ami: 'ami-web', instance_type: 't3.micro'
db   = terraform.add :aws, :host, ami: 'ami-db', instance_type: 't3.large'
```

### Inspecting module variables and outputs

You can introspect available modules without instantiating them:

```ruby
TerraformDSL.module_variables(:aws, :host)  # => { ami: "string", instance_type: "string", ... }
TerraformDSL.module_outputs(:aws, :host)    # => { aws_host_ip: "...", vpc_id: "...", ... }
```

## Common mistakes

### Not requiring the library

```ruby
# Wrong
terraform = TerraformDSL.new  # NameError

# Right
require 'scout-camp'
terraform = TerraformDSL.new
```

### Using string keys for providers

```ruby
# Wrong - provider method uses symbols
terraform.add 'aws', :host  # may not resolve correctly

# Right
terraform.add :aws, :host
```

### Forgetting to call `config`

After adding modules, you must call `config` to write the `.tf` files:

```ruby
terraform = TerraformDSL.new
terraform.add :aws, :host, ami: 'ami-123'
terraform.config '/my/deployment'  # generates .tf files here
```

Without `config`, no files are generated.

## Next steps

- [Managing Deployments](ManagingDeployments.md) — How to deploy the infrastructure you've defined
- [Using Commands](UsingCommands.md) — CLI commands for working with Terraform
- scout-essentials [Working with Files](https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/WorkingWithFiles.md) — How Scout paths work
