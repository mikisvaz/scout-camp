# Terraform DSL Internals

This document explains how the Terraform DSL works internally: how configuration builders accumulate elements, how module references serialize, and how `.tf` files are generated. It is intended for framework contributors who need to extend the DSL or add new module template types.

## Purpose

The DSL lets you define cloud infrastructure programmatically in Ruby, then materialize it into a directory of Terraform `.tf` files that can be managed by the standard `terraform` CLI.

## Core classes

### `TerraformDSL`

The top-level builder. It accumulates elements (module instances), custom files (provider/backend/remote definitions), and then materializes everything via `config`.

Key state:
- `@elements` — Array of `[provider, module_name, module_directory, variables]` tuples
- `@custom_files` — Array of `[filename, text]` pairs
- `@modules` — Base directory for module templates (defaults to `Scout.share.terraform`)

### `TerraformDSL::Module`

Represents a module **instance** (not the template). Created by `TerraformDSL#add`. Has:
- `@name` — Instance name (defaults to `provider_module_name`)
- `@type` — Module template name
- `@deployment` — Reference to the parent `TerraformDSL`

**Key mechanism:** `method_missing` generates output references. Calling any undefined method returns a `Module::Output`.

### `TerraformDSL::Module::Output`

Holds a reference to a module's output variable. Its `to_json` serializes to `module.<module_name>.<output_name>`.

### `TerraformDSL::DirectReference`

A module that can be extended onto any String to make it behave like a Terraform reference. Used by the `remote` method for `data.terraform_remote_state.<key>` references. `method_missing` allows chaining.

## Config generation pipeline

```
add() calls ──→ @elements[]
                 │
config(dir) ────┤
                 ├── main(dir)         → <module>.<name>.tf
                 ├── outputs(dir)      → <module>.<name>.outputs.tf
                 ├── custom_files(dir) → provider_config.<name>.tf, etc.
                 │
                 └── @elements → @processed_elements (cleared)
```

### File naming convention

| File type | Pattern |
|-----------|---------|
| Module instance | `<module_name>.<instance_name>.tf` |
| Outputs | `<module_name>.<instance_name>.outputs.tf` |
| Provider config | `provider_config.<provider_name>.tf` |
| Backend config | `backend_config.<type>.tf` |
| Remote state | `remote.<type>.<key>.tf` |

### Variable serialization

The `variable_block` method serializes a variables hash into Terraform HCL format. It skips `:name` and `:outputs`, and handles:
- `Module::Output` objects → serialized as `module.X.Y`
- Strings matching `module.X.Y` pattern → converted to Output objects
- Symbols → resolved from the variables hash

### Incremental updates

After `config()` is called, `@elements` and `@custom_files` are moved to `@processed_elements` and `@processed_custom_files`. This allows adding new elements and calling `config(dir)` again on the same directory for incremental updates.

## Template introspection

`TerraformDSL.module_variables` and `TerraformDSL.module_outputs` parse `variables.tf` and `output.tf` files using line-by-line regex matching. This extracts variable names, descriptions, types, and defaults.

**Warning:** This regex-based approach is fragile with multi-line defaults, HCL2 syntax, or inline comments.

## Known issues

See [Improvements](../Improvements.md) for a list of identified issues including the `with_bundle` bug, duplicate `stdin.close` in `run_log`, and regex-based HCL parsing.

## Related

- [Architecture](Architecture.md) — How this fits into the overall system
- [Deployment Lifecycle](DeploymentLifecycle.md) — How generated configs are deployed
- [research/terraform-dsl-core-analysis.md](../../research/01_terraform_dsl_core.md) — Deep investigation
