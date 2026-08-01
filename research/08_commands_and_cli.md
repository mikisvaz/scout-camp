# CLI commands investigation

> **Non-normative.** This is an architectural investigation, not maintained documentation. It may become outdated as the codebase evolves. Refer to `doc/user/CommandLineTools.md` for the authoritative summary.

## Overview

scout-camp adds CLI commands to the Scout ecosystem via the `scout_commands/` directory. These commands extend the `scout` CLI with infrastructure management, remote execution, and cloud integration capabilities.

## Command catalog

### Infrastructure commands

| Command | File | Purpose |
|---------|------|---------|
| `scout terraform list` | `scout_commands/terraform/list` | List all deployments |
| `scout terraform plan` | `scout_commands/terraform/plan` | Show Terraform plan for a deployment |
| `scout terraform apply` | `scout_commands/terraform/apply` | Apply a deployment |
| `scout terraform destroy` | `scout_commands/terraform/destroy` | Destroy a deployment |
| `scout terraform status` | `scout_commands/terraform/status` | Show state of deployment elements |
| `scout terraform outputs` | `scout_commands/terraform/outputs` | Show deployment outputs |
| `scout terraform remove` | `scout_commands/terraform/remove` | Destroy and remove a deployment directory |

### Infrastructure setup commands

| Command | File | Purpose |
|---------|------|---------|
| `scout terraform add lambda` | `scout_commands/terraform/add/lambda` | Add an AWS Lambda deployment for Scout workflows |
| `scout terraform add relay` | `scout_commands/terraform/add/relay` | Add an LLM relay deployment (Ollama on a remote server) |

### Remote execution commands

| Command | File | Purpose |
|---------|------|---------|
| `scout offsite` | `scout_commands/offsite` | Run a command on a remote server via SSH |
| `scout sync` | `scout_commands/sync` | Sync resources between path maps or between hosts |
| `scout find` | `scout_commands/find` | Find a resource file (with offsite fallback) |
| `scout glob` | `scout_commands/glob` | Glob for resource files (with offsite fallback) |

### Cloud task commands

| Command | File | Purpose |
|---------|------|---------|
| `scout terraform task` | `scout_commands/terraform/task` | Call a Scout task on AWS Lambda |
| `scout terraform lambda_task` | `scout_commands/terraform/lambda_task` | Call a Scout task on AWS Lambda (enhanced with queueing) |

## Command conventions

All commands follow the Scout CLI conventions:
1. `require 'scout'` or `require 'scout-camp'` at the top.
2. `$0 = "scout #{$previous_commands...}"` for nested command display.
3. `SOPT.setup <<EOF ... EOF` for option parsing documentation.
4. Help check: `if options[:help]; puts SOPT.doc; exit 0; end`.
5. Arguments from `ARGV`.
6. The command framework comes from scout-gear's `bin/scout` script.

## Key command details

### `scout terraform add lambda`

Creates an AWS Lambda deployment that can run Scout workflows. The command:

1. Creates a deployment directory under `Scout.var.deployments[name]`.
2. Builds a Lambda package:
   - Copies `share/aws/lambda_function.rb` as the handler.
   - Creates a `Gemfile` with specified dependencies.
   - Symlinks workflow files.
   - Runs `bundle install` and zips everything.
3. Generates Terraform config for:
   - IAM role with Lambda execution permissions.
   - S3 full access policy.
   - Lambda function with environment variables (HOME, bucket, etc.).

Usage:
```bash
scout terraform add lambda my_lambda \
  -w MyWorkflow \
  -b my-s3-bucket \
  --dependencies scout-gear,scout-camp
```

### `scout terraform add relay`

Creates an LLM relay deployment on a remote server using Ollama. Uses two `ssh/cmd` Terraform modules:

1. Start Ollama server: `module load ollama; ollama serve`.
2. Start Scout LLM process: `scout-ai llm process -ck 'backend ollama ask,model <model> ask'`.

This creates an inference relay on a remote GPU server that can be used by local Scout-AI agents.

Usage:
```bash
scout terraform add relay my_relay \
  -s gpu.cluster.edu \
  -u myuser \
  -m llama3
```

### `scout offsite`

Runs any command on a remote server via SSH. Uses `SSHLine.command`:

```bash
scout offsite gpu.cluster.edu scout workflow list
```

### `scout sync`

Synchronizes resources between path maps or between hosts. Supports `--source` and `--target` for cross-host sync:

```bash
# Sync to user path map
scout sync my_resource user

# Sync from remote host
scout sync my_resource --source gpu.cluster.edu
```

### `scout find` and `scout glob`

File discovery commands that use the `Resource` system. Key feature: if `--where` is a server name (not a path map), the command delegates to `SSHLine.command` to run remotely:

```bash
# Find locally
scout find scout-camp share/terraform/aws/host/main.tf

# Find on remote server
scout find scout-camp share/terraform/aws/host/main.tf -w gpu.cluster.edu
```

### `scout terraform task`

Invokes a Scout workflow task on an AWS Lambda function. The workflow:
1. Fetches task info from the Lambda (`task_name: "info"`).
2. Builds SOPT string from the task's input types.
3. Parses local options.
4. Invokes the task on Lambda.
5. Prints the result using `iii` (Scout's pretty-printer).

Usage:
```bash
scout terraform task MyWorkflow my_task --input1 value1
```

## Issues and observations

1. **Code duplication between `task` and `lambda_task`**: The two commands share almost identical code (`aws_lambda`, `SOPT_str`, `get_SOPT` functions). They should be refactored to share a common module.

2. **Typo in `task`**: Line 29 says `ParamterException` instead of `ParameterException`. Bug.

3. **`terraform/list`**: The `active` option code is commented out (`#active = ...`), but the `--active` flag is still documented in SOPT. Stale code.

4. **No `terraform/plan` command body visible**: The plan command exists in the directory listing but its content was truncated. It likely just calls `deployment.plan`.

5. **`add/lambda` uses `Open.cp` and inline `Gemfile`**: The lambda packaging process is well-designed but hardcodes certain assumptions (e.g., `bundle config set path 'vendor/bundle'`).

6. **`offsite` command**: The `--` separator is mentioned in help but not actually handled in the code. The separator should protect options from being parsed by the local SOPT.

7. **No validation of server reachability**: Commands like `offsite` and `sync` don't check if the server is reachable before attempting.

8. **Error handling**: Most commands don't catch exceptions. A failed deployment or SSH connection will produce raw Ruby backtraces.

## Cross-references

- Terraform DSL core: see `01_terraform_dsl_core.md`
- Deployment management: see `02_deployment_management.md`
- Offsite remote execution: see `04_offsite_remote_execution.md`
- S3 integration: see `05_s3_integration.md`
