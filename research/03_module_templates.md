# Module templates investigation

> **Non-normative.** This is an architectural investigation, not maintained documentation. It may become outdated as the codebase evolves. Refer to `doc/developer/Architecture.md` for the authoritative summary.

## Overview

Module templates are plain Terraform `.tf` files stored under `share/terraform/<provider>/<module>/`. They are consumed by the `TerraformDSL#add` method. Each module directory must contain at minimum a `main.tf`; most also include `variables.tf` and `output.tf`.

## Available module catalog

### AWS modules

| Module | Purpose | Key variables | Key outputs |
|--------|---------|---------------|-------------|
| `aws/provider` | Data sources: AMI lookup, availability zones, instance offerings | — | `default_ami`, `my_zones`, `available_aws_offerings`, `ipam` |
| `aws/host` | EC2 instance | `ami`, `instance_type`, `subnet_id`, `vpc_security_group_ids`, `volume_size`, `ssh_key`, `user_data`, `availability_zone` | `aws_instance_id`, `aws_instance_ip` |
| `aws/network` | Security groups (SSH + EFS/NFS) | — | `efs_sg_id`, `ssh_sg_id` |
| `aws/cluster` | VPC, subnet, internet gateway, route table | `cidr_block_base`, `cidr_block_mask`, `availability_zone`, `map_public_ip_on_launch` | `aws_subnet_id`, `aws_security_group_id` |
| `aws/efs` | EFS file system + mount targets | `remote` (remote state name), `sg_keys` | `id` |
| `aws/efs_host` | Host with EFS mount | — | — |
| `aws/bucket` | S3 bucket | `bucket_name` | `bucket_id` |
| `aws/lambda` | Lambda function | `function_name`, `runtime`, `filename`, `policies`, `environment_variables`, `timeout` | — |
| `aws/container_lambda` | Container-based Lambda | — | — |
| `aws/role` | IAM role | `role_name`, `principal`, `action` | `arn`, `role_name`, `id` |
| `aws/role_policy` | IAM role policy (inline) | — | — |
| `aws/policy` | IAM managed policy | `policy_name`, `statement` | `arn`, `name`, `id` |
| `aws/policy_attachment` | IAM policy-to-role attachment | — | — |
| `aws/iam_instance_profile` | IAM instance profile | — | — |
| `aws/fargate` | Fargate cluster + service | — | — |
| `aws/event_bridge` | EventBridge rule | — | — |

### SSH modules

| Module | Purpose | Key variables | Key outputs |
|--------|---------|---------------|-------------|
| `ssh/cmd` | Execute commands on a remote host via SSH | `host`, `user`, `commands` (create), `commands_destroy` (destroy) | (text result from SSH) |

## Template conventions

### Required files

- `main.tf` — The core resource definitions. **Required.**
- `variables.tf` — Variable declarations. **Optional but standard.**
- `output.tf` — Output declarations. **Optional.**

Some modules additionally use `data.tf` (data sources) and `locals.tf` (local values).

### File naming

The DSL looks for `variables.tf` and `output.tf` specifically (in `TerraformDSL.module_variables` and `module_outputs`). Note the **inconsistency**: some module output files are named `output.tf` while the DSL code references `output.tf` (singular) — but some modules have `output.tf` and some have `output.tf` (both singular). The `module_outputs` method looks for `output.tf` (singular). [VERIFY: some modules have no output file, some have `output.tf`]

### Variable and output discovery

The DSL parses `variables.tf` and `output.tf` using line-by-line regex (see `util.rb`). This is used for:
- Documentation and help text in CLI commands.
- The `:outputs` parameter in `add()` to determine which outputs to surface.

## Module compositing patterns

### Provider + host pattern

```ruby
terraform = TerraformDSL.new
terraform.provider :aws, source: 'hashicorp/aws', version: '~> 5.0'
provider = terraform.add :aws, :provider
host = terraform.add :aws, :host,
  ami: provider.default_ami,
  instance_type: 't2.micro'
```

### Network → host pattern

```ruby
network = terraform.add :aws, :network
cluster = terraform.add :aws, :cluster
host = terraform.add :aws, :host,
  subnet_id: cluster.aws_subnet_id,
  vpc_security_group_ids: [network.ssh_sg_id]
```

### Remote state reference

Modules can reference outputs from other Terraform states via `remote`:

```ruby
policies_state = terraform.remote :s3, 'policies', bucket: 'my-tf-state', region: 'us-east-1'
```

This returns a `DirectReference` string (`data.terraform_remote_state.policies`) that can be used as a variable value.

## The `ssh/cmd` module

The `ssh/cmd` module uses the `loafoe/ssh` Terraform provider to execute SSH commands. It has separate commands for create and destroy lifecycle phases:

- `commands` — Executed when the resource is created.
- `commands_destroy` — Executed when the resource is destroyed.

This is a powerful pattern for provisioning steps that need to run after infrastructure is up (e.g., installing software, starting services).

## CLI integration

The `scout terraform list` command lists available modules by scanning `share/terraform/`:

```bash
scout terraform list
# aws: host, network, cluster, efs, bucket, lambda, ...
# ssh: cmd
```

The `scout terraform config` command reads a Ruby DSL file and calls `terraform.config dir` to generate the `.tf` files.

## Issues and observations

1. **Inconsistent output file naming**: The DSL's `module_outputs` method looks for `output.tf` (singular), but the template naming convention should be verified for all modules. Some modules (e.g., `aws/lambda`) have no output file.

2. **Regex-based parsing limitations**: The regex parser in `module_variables`/`module_outputs` does not handle complex HCL types (e.g., `list(object({...}))` spans multiple lines). This means multi-line type definitions may not parse correctly.

3. **Missing provider module path**: The `provider` method checks for `@modules[name].provider` — when `provider` is `:aws`, it checks `share/terraform/aws/provider/`. This is found because `aws/provider/` exists as a template. Other providers would need similar template directories.

4. **No validation of required variables**: The DSL does not check whether all required module variables have been provided. This is deferred to `terraform validate` / `plan`.

5. **The `ssh/cmd` module is especially useful** for combining infrastructure provisioning with software provisioning without needing a separate tool like Ansible.

## Cross-references

- Terraform DSL core: see `01_terraform_dsl DSL_core.md`
- Deployment management: see `02_deployment_management.md`
- CLI commands: see `08_commands_and_cli.md`
