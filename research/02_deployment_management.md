# Deployment management investigation

> **Non-normative.** This is an architectural investigation, not maintained documentation. It may become outdated as the codebase evolves. Refer to `doc/developer/Architecture.md` for the authoritative summary.

## Overview

The `TerraformDSL::Deployment` class (`lib/scout/terraform_dsl/deployment.rb`, 285 lines) wraps the Terraform CLI to provide a Ruby-managed deployment lifecycle. Once a `TerraformDSL` instance has materialized its configuration into a directory via `config()`, a `Deployment` object manages init, plan, apply, destroy, and state inspection.

## Lifecycle

### Initialization

```ruby
deployment = TerraformDSL::Deployment.new(config_dir)
```

- `@directory` is set to the config directory (resolved via `Path#find` if it's a `Path`).
- `@init` flag starts as `false`.

### Lifecycle methods

| Method | Description | Prerequisites |
|--------|-------------|---------------|
| `init` | Runs `terraform init` in the config directory | None |
| `validate` | Runs `terraform validate` | Runs `init` if not done |
| `plan` | Runs `terraform plan -out <plan_file>`, saves timestamp | Runs `init` if not done |
| `apply` | Runs `terraform apply -auto-approve <plan_file>` | Runs `plan` if not done |
| `refresh` | Runs `terraform refresh` to update state | Runs `plan` if not done |
| `update` | Convenience: `init` → `plan` → `apply` | None |
| `destroy` | Runs `terraform destroy -auto-approve` | None (but should be after `apply`) |

All methods use `Misc.in_dir` to change to the deployment directory before running commands.

### State management flags

- `@init` — Whether `init` has been run.
- `@planned` — Timestamp of last `plan` (also used as a boolean check).

### `with_deployment`

The idiomatic pattern for managing temporary deployments:

```ruby
deployment.with_deployment do
  # infrastructure is provisioned
  ip = deployment.output('host1', 'ip')
  # ...
end
# infrastructure is automatically destroyed
```

This runs `apply`, yields, then ensures `destroy` is called in an `ensure` block.

## CLI integration

### `Deployment.run(cmd)` (class method)

- Uses `Open3.popen3("terraform #{cmd}")`.
- Logs the command and stderr to Scout's `Log`.
- Returns stdout as a string.
- Raises `TerraformException` with the error message if exit status is non-zero.

### `Deployment.run_log(cmd, log_file)` (class method)

- Like `run`, but also logs stdout and stderr to a file.
- Used for long-running operations (init, plan, apply, destroy).
- Error message extraction parses the log file and strips log formatting prefixes.

### Log file

`log_file` returns `@directory.log`. All `run_log` calls append to this file.

## State inspection

### `provisioned_elements`

```ruby
deployment.provisioned_elements
# => ["module.aws_provider.data.aws_ami.ubuntu2004", "module.host1", ...]
```

Runs `terraform state list`. Returns an empty array on error (e.g., before init).

### `element_state(element)`

```ruby
deployment.element_state("module.host1")
# => "module.host1:\n  resource = ...\n  ..."
```

Runs `terraform state show '<element>'`.

### `outputs`

```ruby
deployment.outputs
# => {"host1_ip" => "1.2.3.4", "host1_aws_instance_id" => "i-abc123", ...}
```

Runs `terraform output -json` and parses the result. Returns a hash mapping `module_output` names to values.

### `output(name, output)`

```ruby
deployment.output('host1', 'ip')       # String name
deployment.output(host1_module, 'ip')  # TerraformDSL::Module object
```

Resolves a module and output name to its value via `outputs`. Accepts either a string name or a `TerraformDSL::Module` object.

### `templates`

Lists the `.tf` files in the directory and organizes them by module type based on filename pattern `^([^.]+)\.([^.]+)\.tf`.

## Bundling

### `bundle(file)`

Creates a `.tar.gz` archive of the deployment directory. Used for transferring deployments between machines or archiving state.

### `Deployment.load(file, directory)`

Class method that:
1. Extracts the tarball into a directory.
2. Creates a new `Deployment` object.
3. Runs `refresh` to update the state.

### `with_bundle`

Intended to create a temporary bundle, yield, and clean up. **Note: contains a bug** — references `file` variable that is never defined in the method scope (should use `name`).

## Element management

### `delete(element)`

Removes an element's `.tf` and `.outputs.tf` files from the deployment directory. Does not run `terraform state rm`; a subsequent `plan`/`apply` is needed to update the actual infrastructure.

## Design patterns

### Command wrapper

`Deployment.run` and `Deployment.run_log` are thin wrappers around the `terraform` CLI using `Open3`. This avoids a Terraform Ruby API dependency and stays compatible with any Terraform version.

### Idempotent lifecycle

`init` resets `@planned`, and `apply` checks `@planned` before running `plan`. This makes the lifecycle idempotent within a single Deployment object's lifetime.

### Scoped execution with `with_deployment`

The `with_deployment` pattern is the Scout idiom for ensuring cleanup: apply, yield, destroy in ensure.

## Issues and observations

1. **`with_bundle` bug** (line ~258): The method defines `name` but references `file`:
   ```ruby
   def with_bundle(&block)
     name = 'deployment-bundle-tmp_' + rand(100000).to_s + '.tar.gz'
     TmpFile.with_file nil, extension: 'deployment_bundle' do |tmpfile|
       bundle(file)   # BUG: file is undefined; should be name or tmpfile
       yield file     # BUG: same issue
     end
   end
   ```

2. **Duplicate `stdin.close`** in `run_log` (line ~17): `stdin.close` appears twice.

3. **`delete` doesn't update state**: Removing `.tf` files without running `terraform state rm` can leave orphaned state entries.

4. **No locking**: Multiple processes could run terraform commands on the same directory concurrently without protection.

5. **Error parsing is brittle**: The error message extraction in `run_log` splits on `Error:` and strips prefixes, which may not work for all Terraform error formats.

6. **`Deployment.load` uses `refresh` which calls `plan`** (which calls `init`). This is correct but may be surprising — loading a bundle triggers a full terraform refresh.

## Cross-references

- Terraform DSL core: see `01_terraform_dsl_core.md`
- Module templates: see `03_module_templates.md`
- CLI commands: see `08_commands_and_cli.md`
