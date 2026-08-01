# Remote Execution

This document explains how to run Scout workflow steps on remote servers over SSH. It is intended for workflow authors who need to offload computation to remote machines or run jobs across multiple servers.

## When to use this

Use remote execution when you want to:

- Run computationally expensive workflow steps on a remote server
- Distribute workflow execution across multiple machines
- Run steps on infrastructure you've provisioned with Terraform

If you only need to run a single command on a remote server, consider using SSH commands in the [Terraform DSL](ProvisioningInfrastructure.md) (`ssh/cmd` module) or the `scout offsite` CLI command.

## Core concepts

### Offsite execution

Scout-camp extends Scout workflow steps with the ability to execute on remote servers. A step annotated as "offsite" runs its computation on a remote server, with inputs, dependencies, and results synchronized automatically.

### SSH transport

Remote execution uses `SSHLine`, a wrapper around the `net/ssh` library. Commands and Ruby code are executed on the remote server via SSH.

### Path synchronization

For a step to execute remotely, its inputs and dependencies must be available on the remote server. Scout-camp uses `rsync` to synchronize paths between the local and remote machines.

### Resource synchronization

Scout's `Resource` system discovers files across multiple sources (gems, local directories, etc.). Scout-camp extends this to discover and sync files from remote servers.

## Using remote execution

### Configuring a server

Set the default server for offsite execution:

```ruby
SSHLine.default_server = 'compute.example.com'
```

Or specify per-step:

```ruby
step = MyWorkflow.job(:task, 'job-name', input: 'value')
step.annotate(:offsite, server: 'compute.example.com')
```

### Running a step remotely

```ruby
require 'scout-camp'

# Set up the server
SSHLine.default_server = 'compute.example.com'

# Create a workflow job
job = MyWorkflow.job(:heavy_computation, 'job-1', param: 42)

# Annotate as offsite and run
job.run_offsite
```

### Path synchronization

Paths are synchronized automatically before remote execution. The system handles three types of paths:

1. **Job inputs** — Files provided as inputs to the job
2. **Dependencies** — Files from upstream steps
3. **Results** — The job's output, synced back after completion

```ruby
# Inputs are synced to the remote server
job = MyWorkflow.job(:task, 'job1', matrix: '/local/data/matrix.tsv')
job.run_offsite
# The matrix file is rsynced to the remote server before execution
```

### Resource sync

Scout's `Resource` system can discover files from remote servers:

```ruby
# Configure resource sync servers
Resource.sync_servers = ['compute.example.com:~/.scout/var']

# Now Resource lookups check remote servers
Resource.identify('workflow/share/file')  # may sync from remote
```

## Common patterns

### Running on provisioned infrastructure

```ruby
# Provision a server (see ProvisioningInfrastructure.md)
terraform = TerraformDSL.new
terraform.aws region: 'us-east-1'
host = terraform::add :aws, :host, ami: '...', instance_type: 't3.large'
terraform.config dir
deployment = TerraformDSL::Deployment.new dir
deployment.apply

# Get the server IP
ip = deployment.output host, :aws_instance_ip

# Use it for remote execution
SSHLine.default_server = ip
job = MyWorkflow.job(:heavy_task, 'job-1')
job.run_offsite
```

### Batch execution

Run multiple jobs on a remote server:

```ruby
SSHLine.default_server = 'compute.example.com'

jobs = inputs.map do |input|
  job = MyWorkflow.job(:process, input[:name], data: input[:file])
  job.annotate(:offsite, server: 'compute.example.com', batch: true)
  job
end

jobs.each(&:run_offsite)
```

## Common mistakes

### Not configuring SSH access

Remote execution requires SSH access to the remote server. Ensure:
- SSH keys are set up for passwordless access
- The user account exists on the remote server
- The remote server has Ruby and Scout installed

### Forgetting to sync resources

If a step depends on a file from a Scout `Resource` (e.g., a database file or reference genome), the resource must be available on the remote server:

```ruby
# Configure resource sync so resources are discovered remotely
Resource.sync_servers = ['compute.example.com:~/.scout/var']
```

### Using absolute local paths

Paths that are absolute on the local machine may not exist on the remote server. Use Scout's `Path` system, which can relocate paths to the appropriate location:

```ruby
# Wrong
job = MyWorkflow.job(:task, 'job1', input: '/home/user/data/file.tsv')

# Right - use a Scout path that can be relocated
job = MyWorkflow.job(:task, 'job1', input: Scout.root.data['file.tsv'].find)
```

## Next steps

- [Cloud Storage](CloudStorage.md) — Using S3 for transparent path persistence
- [Provisioning Infrastructure](ProvisioningInfrastructure.md) — Provisioning servers to run on
- scout-essentials [Working with Files](https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/WorkingWithFiles.md) — Understanding Scout paths
- scout-essentials [Producing Resources](https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/ProducingResources.md) — Resource discovery
