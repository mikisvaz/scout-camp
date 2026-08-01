# Using Commands

This document is a reference for all CLI commands provided by scout-camp. It is intended for workflow authors and operators who manage infrastructure, remote servers, and deployments from the command line.

## When to use this

Use these commands when you want to:

- Manage Terraform deployments from the CLI
- Run commands on remote servers
- Search for files across local and remote locations
- Synchronize resources between machines

## Command reference

### Terraform commands

All Terraform commands are invoked as `scout terraform <subcommand>`.

#### `scout terraform add`

Add a new deployment from a DSL definition.

```bash
scout terraform add <name> [options]
```

**Options:**
- `-s--server*` — Server name
- `-u--user*` — User in server
- `-m--model*` — Model name

#### `scout terraform add lambda`

Package and add a Lambda deployment.

```bash
scout terraform add lambda [options]
```

**Options:**
- `--workflows*` — Workflows to include
- `--dependencies*` — Gem dependencies
- `--function_name` — Lambda function name
- `--handler` — Handler name (default: `lambda_function.lambda_handler`)
- `--runtime` — Lambda runtime (default: `ruby_3_2`)
- `--memory_size` — Memory in MB (default: 2048)
- `--timeout` — Timeout in seconds (default: 900)

#### `scout terraform add relay`

Add a relay server (e.g., an ollama relay).

```bash
scout terraform add relay <name> -s <server> -u <user> -m <model>
```

This sets up an SSH `cmd` module that starts ollama and configures scout-ai to use it.

#### `scout terraform plan`

Plan a deployment.

```bash
scout terraform plan [<name>] [options]
```

**Options:**
- `-d--deployment*` — Deployment directory

#### `scout terraform apply`

Apply a deployment.

```bash
scout terraform apply [<name>] [options]
```

#### `scout terraform destroy`

Destroy a deployment.

```bash
scout terraform destroy [<name>] [options]
```

#### `scout terraform list`

List all deployments.

```bash
scout terraform list
```

Lists deployments stored under `Scout.var.deployments`.

#### `scout terraform status`

Show the status of all elements in a deployment.

```bash
scout terraform status [<name>]
```

Shows each provisioned element and its Terraform state.

#### `scout terraform outputs`

Show all outputs of a deployment.

```bash
scout terraform outputs [<name>]
```

#### `scout terraform task`

Run a task on the Lambda function associated with a deployment.

```bash
scout terraform task [<workflow>] [<task>] [options]
```

**Options:**
- `-i--input*` — Input value
- `-d--deployment*` — Deployment name

#### `scout terraform lambda_task`

Queue or run a task on a Lambda with clean/queue options.

```bash
scout terraform lambda_task [<workflow>] [<task>] [options]
```

**Options:**
- `-i--input*` — Input value
- `-d--deployment*` — Deployment name
- `-q--queue` — Queue the job (don't wait for result)
- `-c--clean` — Clean the job before running
- `-w--wait` — Wait for queued job to complete
- `-i--info` — Show job info instead of running

### Remote execution commands

#### `scout offsite`

Run a workflow task on a remote server.

```bash
scout offsite [<workflow>] [<task>] [options]
```

**Options:**
- `-s--server*` — Remote server hostname
- `-u--user*` — SSH user
- `--clean` — Clean before running
- `--recursive_clean` — Recursively clean dependencies

#### `scout sync`

Synchronize files between local and remote servers.

```bash
scout sync <path> [options]
```

**Options:**
- `-s--server*` — Remote server
- `-u--user*` — SSH user
- `-m--map` — Path map to use

### File search commands

#### `scout find`

Find files across local and remote locations.

```bash
scout find <pattern>
```

#### `scout glob`

Glob files across local and remote locations.

```bash
scout glob <pattern>
```

## Common patterns

### Full deployment lifecycle from CLI

```bash
# Add a deployment
scout terraform add my-server

# Plan
scout terraform plan my-server

# Apply
scout terraform apply my-server

# Check status
scout terraform status my-server

# Destroy when done
scout terraform destroy my-server
```

### Lambda deployment lifecycle

```bash
# Add and package
scout terraform add lambda --workflows MyWorkflow

# Apply
scout terraform apply

# Run a task
scout terraform task MyWorkflow MyTask --input value

# Queue a task
scout terraform lambda_task MyWorkflow MyTask --queue
```

### Running on a remote server

```bash
# Run a task offsite
scout offsite MyWorkflow MyTask --server compute.example.com --user ubuntu

# Sync a file
scout sync /local/path --server compute.example.com
```

## Common mistakes

### Not specifying the deployment name

Most terraform commands can work without a name if there's only one deployment, but it's safer to specify it:

```bash
# Risky - may pick wrong deployment if multiple exist
scout terraform apply

# Better
scout terraform apply my-server
```

### Confusing `task` and `lambda_task`

- `scout terraform task` invokes the Lambda function directly.
- `scout terraform lambda_task` adds queue/clean/wait options for asynchronous execution.

### Forgetting SSH prerequisites

Remote execution commands require:
- Passwordless SSH access (`ssh-keygen`, `ssh-copy-id`)
- Ruby and Scout installed on the remote server
- The same directory structure (or use path maps)

## Next steps

- [Provisioning Infrastructure](ProvisioningInfrastructure.md) — Defining infrastructure
- [Managing Deployments](ManagingDeployments.md) — Deployment lifecycle
- [Remote Execution](RemoteExecution.md) — Offsite execution concepts
- scout-essentials [Command Line Options](https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/CommandLineOptions.md) — SOPT option parsing
