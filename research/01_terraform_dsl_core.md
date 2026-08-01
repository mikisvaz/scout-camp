# Terraform DSL core investigation

> **Non-normative.** This is an architectural investigation, not maintained documentation. It may become outdated as the codebase evolves. Refer to `doc/developer/Architecture.md` for the authoritative summary.

## Overview

The `TerraformDSL` class (`lib/scout/terraform_dsl.rb`, 375 lines) is the centerpiece of scout-camp's infrastructure provisioning subsystem. It provides a Ruby DSL for programmatically composing Terraform configurations, which are then managed by the companion `Deployment` class.

## Class structure

### `TerraformDSL`

The top-level orchestrator. It maintains:
- `@elements` — Array of `[provider, module_name, module_directory, variables]` tuples for each module instance added.
- `@custom_files` — Array of `[filename, text]` pairs for custom Terraform files (providers, backends, remotes).
- `@modules` — The base directory for module templates (defaults to `Scout.share.terraform`).
- `@processed_elements` / `@processed_custom_files` — Snapshots of elements/custom_files after `config()` has been called (used for incremental updates).

### `TerraformDSL::Module`

Represents a **module instance** (not the template). Created by `TerraformDSL#add`. Has:
- `@name` — The instance name (defaults to `provider_module_name`).
- `@type` — The module template name.
- `@deployment` — Reference to the parent TerraformDSL.

Key behavior: **`method_missing` generates output references.** Calling any undefined method on a Module object returns a `Module::Output` referencing that module's output variable. Example:

```ruby
host = terraform.add :aws, :host, name: 'host1', ...
host.aws_instance_ip  # => Module::Output.new('host1', 'aws_instance_ip')
```

When serialized via `to_json`, this produces `module.host1.aws_instance_ip` — valid Terraform syntax for referencing a module output. This is the core mechanism that makes the DSL composable: outputs from one module can be passed as inputs to another.

### `TerraformDSL::Module::Output`

Holds a reference to a module's output variable. Its `to_json` method serializes to `module.<module_name>.<output_name>`.

### `TerraformDSL::DirectReference`

A module that can be extended onto any String to make it behave like a Terraform reference. Used by the `remote` method for `data.terraform_remote_state.<key>` references. `method_missing` allows chaining (e.g., `ref.sub_field`).

## Public API

### `add(provider, module_name, variables = {})`

The primary method for adding infrastructure. Adds a module instance to the configuration.

- `provider` — First-level subdirectory under `share/terraform/` (e.g., `:aws`, `:ssh`).
- `module_name` — Second-level subdirectory (e.g., `:host`, `:cmd`).
- `variables` — Hash of variable values. Special keys:
  - `:name` — Instance name (auto-generated as `provider_module_name` if not provided).
  - `:outputs` — Controls which module outputs are surfaced as deployment-level outputs.
    - `:all` or `'all'` — All module outputs.
    - Hash `{ original_name: renamed_name }` — Rename specific outputs.
    - Array — Mix of the above.
    - Symbol/String — Name of a specific output.

Returns a `TerraformDSL::Module` object.

### `provider(name, variables = {})`

Defines a Terraform provider. Two paths:
1. If a `provider` template exists under `<modules_dir>/<name>/provider/`, it uses it as a module.
2. Otherwise, generates raw provider configuration.

Variables `:source` and `:version` configure the required_providers block.

### `backend(type, variables = {})`

Defines a Terraform backend for state management. Generates raw backend configuration (not module-based).

### `remote(type, key, variables = {})`

Defines a `terraform_remote_state` data source. Returns a `DirectReference` string for use in other modules' variables.

### `custom(file, text)`

Adds an arbitrary `.tf` file with custom content.

### `config(dir = nil)`

**The materialization method.** Generates all `.tf` files into a directory:
1. Calls `main(dir)` — generates module instance files.
2. Calls `outputs(dir)` — generates output variable files.
3. Calls `custom_files(dir)` — generates custom files (providers, backends).
4. Moves `@elements` and `@custom_files` to `@processed_*` (enabling incremental updates).
5. Returns the directory path.

If `dir` is nil, generates a unique path based on MD5 of the elements.

### `variable_block(variables)`

Serializes variables into Terraform HCL format. Skips `:name` and `:outputs`. Handles:
- `Module::Output` objects → `module.X.Y`
- Strings matching `module.X.Y` pattern → converted to Output objects.
- Symbols → resolved from the variables hash.

## Config generation pipeline

```
add() calls ──→ @elements[]
                 │
config(dir) ────┤
                 ├── main(dir)     → <module>.<name>.tf
                 ├── outputs(dir)  → <module>.<name>.outputs.tf
                 ├── custom_files(dir) → provider_config.<name>.tf, backend_config.<type>.tf, etc.
                 │
                 └── @elements → @processed_elements (cleared)
```

### File naming convention

- Module instances: `<module_name>.<instance_name>.tf`
- Outputs: `<module_name>.<instance_name>.outputs.tf`
- Provider configs: `provider_config.<provider_name>.tf`
- Backend configs: `backend_config.<type>.tf`
- Remote state: `remote.<type>.<key>.tf`

### Error handling

If two elements produce the same filename, a `Deployment::TerraformException` is raised suggesting the use of the `:name` parameter.

## Constants

- `MODULES_DIR = Scout.share.terraform` — Default location for module templates.
- `ANSIBLE_DIR = Scout.share.ansible` — Location for Ansible playbooks.
- `WORK_DIR = Scout.var.terraform` — Default working directory for deployments.

## Design patterns

### Builder pattern with composable references

The DSL follows a builder pattern where `add` returns Module objects whose outputs can be referenced via `method_missing`. This allows fluent composition:

```ruby
terraform = TerraformDSL.new
network = terraform.add :aws, :network
host = terraform.add :aws, :host,
  subnet_id: network.aws_subnet_id  # Output reference passed as input
```

### Materialization via config()

The DSL accumulates elements lazily. `config()` materializes them into files. The `@processed_*` tracking enables incremental updates: after `config()`, new elements can be added and `config(dir)` called again on the same directory.

### Template-based modules

Module templates are plain Terraform files (`main.tf`, `variables.tf`, `output.tf`) stored under `share/terraform/<provider>/<module>/`. The DSL does not parse HCL; it reads `variables.tf` and `output.tf` using regex parsing to extract metadata.

## Issues and observations

1. **Regex-based HCL parsing** (`util.rb`): `module_variables` and `module_outputs` use line-by-line regex parsing of `.tf` files. This is fragile and will fail with multi-line defaults, HCL2 syntax, or inline comments. A proper HCL parser would be more robust.

2. **`_module_name` variable shadowing in `main()`**: The variables `_provider, _module_name, template, variables = info` in `main()` reference the loop-local variable, but `element_file` uses `[_module_name, ...]` which comes from the destructured assignment, not the original `module_name` parameter. This works but is confusing.

3. **`with_bundle` bug**: The `with_bundle` method creates a variable `name` for the bundle filename but then uses `file` (which is undefined in that scope). It should use `name`. See `deployment.rb` line ~258.

4. **Duplicate `stdin.close`**: In `run_log`, `stdin.close` is called twice (likely copy-paste error).

5. **No validation of provider/module existence**: `add` doesn't check if the template directory exists until `config()` tries to read it.

6. **String multiplication for HCL**: The `variable_block` method returns `acc * "\n"` (array join), which is idiomatic Ruby but uncommon.

## Cross-references

- Deployment lifecycle: see `02_deployment_management.md`
- Module templates: see `03_module_templates.md`
- CLI commands: see `08_commands_and_cli.md`
