# Managing Deployments

This document explains how to deploy infrastructure to the cloud, inspect its state, and tear it down. It is intended for workflow authors who have already defined infrastructure using the [Terraform DSL](ProvisioningInfrastructure.md) and now need to execute and manage the deployment.

## When to use this

Use the deployment lifecycle when you want to:

- Apply Terraform configuration to create real cloud resources
- Check what resources exist and their status
- Read deployment outputs (e.g., instance IPs)
- Destroy infrastructure when it's no longer needed
- Bundle a deployment for transfer or backup

## Core concepts

### Deployment

A `TerraformDSL::Deployment` wraps a directory containing Terraform configuration files and manages the infrastructure lifecycle. It corresponds to a single Terraform working directory.

### Lifecycle

The deployment lifecycle mirrors Terraform's standard workflow:

```
init → plan → apply → (use) → destroy
```

Each step is a method you call on the deployment object.

## Using deployments

### Creating a deployment

First, define your infrastructure and generate configuration files:

```ruby
require 'scout-camp'

terraform = TerraformDSL.new
terraform.aws region: 'us-east-1'
terraform.add :aws, :host, ami: 'ami-0c02fb55956c7d316', instance_type: 't3.micro'

# Generate configuration into a directory
terraform.config '/my/deployments/web-server'
```

Then create a deployment from that directory:

```ruby
deployment = TerraformDSL::Deployment.new '/my/deployments/web-server'
```

### Initialization

Before any other operation, initialize the deployment:

```ruby
deployment.init
```

This runs `terraform init`, downloading providers and setting up the backend.

### Planning

See what changes Terraform will make before applying them:

```ruby
deployment.plan
```

This runs `terraform plan` and shows the planned changes.

### Applying

Create or update the infrastructure:

```ruby
deployment.apply
```

This runs `terraform apply`. If the plan requires approval, it will prompt you.

### Validating

Check that the configuration is valid:

```ruby
deployment.validate
```

### Refreshing

Update the state from the real infrastructure (useful after manual changes):

```ruby
deployment.refresh
```

### Destroying

Remove all infrastructure:

```ruby
deployment.destroy
```

### Full lifecycle example

```ruby
require 'scout-camp'

# Define infrastructure
terraform = TerraformDSL.new
terraform.aws region: 'us-east-1'
host = terraform.add :aws, :host,
  ami: 'ami-0c02fb55956c7d316',
  instance_type: 't3.micro',
  key_name: 'my-key'

# Generate and deploy
terraform.config '/my/deployments/web-server'
deployment = TerraformDSL::Deployment.new '/my/deployments/web-server'

deployment.init
deployment.plan
deployment.apply

# Use the infrastructure
ip = deployment.output host, :aws_instance_ip
puts "Server IP: #{ip}"

# When done
deployment.destroy
```

## Reading deployment state

### Outputs

Read the output values from a deployment:

```ruby
ip = deployment.output host, :aws_instance_ip
# => "1.2.3.4"
```

### Element inspection

See what resources have been provisioned:

```ruby
deployment.provisioned_elements.each do |element|
  puts "#{element}: #{deployment.element_state(element)}"
end
```

### State file

The state is stored in `terraform.tfstate` within the deployment directory. After `refresh`, the deployment object reads the latest state.

## Bundling deployments

### Saving a deployment

Bundle a deployment (configuration + state) into a portable archive:

```ruby
deployment.bundle '/tmp/web-server.tar.gz'
```

### Loading a deployment

Load a previously bundled deployment:

```ruby
deployment = TerraformDSL::Deployment.load '/tmp/web-server.tar.gz'
```

The loader extracts the archive and runs `refresh` to synchronize with the real infrastructure.

## Common patterns

### Deployment directory convention

Deployment directories are typically managed under `Scout.var.deployments`:

```ruby
dir = Scout.var.deployments['my-server'].find
terraform.config dir
deployment = TerraformDSL::Deployment.new dir
```

### Conditional apply

```ruby
deployment.init
deployment.plan

# Only apply if plan shows changes
if deployment.has_changes?
  deployment.apply
end
```

### Combining with offsite execution

```ruby
deployment.apply
ip = deployment.output host, :aws_instance_ip

# Now use the server for remote execution
# See RemoteExecution.md
```

## Common mistakes

### Not calling `init` first

```ruby
# Wrong
deployment = TerraformDSL::Deployment.new '/my/dir'
deployment.plan  # fails - providers not downloaded

# Right
deployment.init
deployment.plan
```

### Forgetting to refresh after manual changes

If resources change outside of Terraform (e.g., via the AWS console), the state file is stale:

```ruby
# Update state from real infrastructure
deployment.refresh
```

### Confusing module references with outputs

```ruby
host = terraform.add :aws, :host, ...

# Wrong - host is a DSL module reference, not a deployment output
ip = host.aws_instance_ip

# Right - read from deployment after apply
ip = deployment.output host, :aws_instance_ip
```

## Next steps

- [Provisioning Infrastructure](ProvisioningInfrastructure.md) — How to define infrastructure using the DSL
- [Remote Execution](RemoteExecution.md) — How to run commands on deployed servers
- [Using Commands](UsingCommands.md) — CLI commands for managing deployments
