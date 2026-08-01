# Deployment Lifecycle

This document explains how `TerraformDSL::Deployment` wraps the `terraform` CLI to manage infrastructure lifecycles. It is intended for framework contributors who need to extend deployment management or add new lifecycle operations.

## Purpose

A `Deployment` wraps a directory containing Terraform configuration files and manages the infrastructure lifecycle: initialization, planning, applying, inspecting state, and destroying.

## Execution model

### `Deployment.run(cmd)` (class method)

Executes `terraform <cmd>` using `Open3.popen3`. STDERR is logged in real time. STDOUT is returned as a string. Raises `TerraformException` on non-zero exit, extracting the error message after `Error:`.

### `Deployment.run_log(cmd, log_file)` (class method)

Like `run`, but streams both STDOUT and STDERR to logs and to a log file. Used for long-running operations (init, plan, apply, destroy).

## Lifecycle methods

| Method | Description |
|--------|-------------|
| `init` | Downloads providers, sets up backend. Required first. |
| `plan` | Generates a saved plan (`main.plan`). Runs init if needed. |
| `apply` | Applies the saved plan. Runs plan if needed. |
| `validate` | Validates configuration. Runs init if needed. |
| `refresh` | Updates state from real infrastructure. |
| `destroy` | Removes all resources. |
| `update` | Runs init + plan + apply in sequence. |

### Lazy initialization

Each method calls `init` automatically if not already initialized, and `plan` calls `apply` automatically if not already planned. This means calling `deployment.apply` directly will trigger `init` → `plan` → `apply` in sequence.

## State inspection

- `provisioned_elements` — Lists all resources via `terraform state list`
- `element_state(element)` — Shows details of a specific resource via `terraform state show`
- `outputs` — Reads all outputs as a Ruby hash via `terraform output -json`
- `output(name, output)` — Reads a specific output, accepting either a Module reference or a string name
- `templates` — Lists `.tf` files grouped by module type

## Bundling

- `bundle(file)` — Creates a `tar.gz` archive of the deployment directory (including state and lock files)
- `Deployment.load(file, directory)` — Extracts a bundle into a working directory and refreshes state

**Known bug:** The `with_bundle` method has a variable naming error (`file` is used instead of `name`). See [Improvements](../Improvements.md).

## Directory and logging conventions

- Deployment directories live under `Scout.var.terraform` by default
- Plan files: `main.plan`
- Log files: `log` within the deployment directory
- All operations run inside the deployment directory via `Misc.in_dir`

## Error handling

`TerraformException` is raised on any non-zero terraform exit. The exception message is extracted from the error output after `Error:`.

For `run_log`, the error message is extracted from the log file, stripping log prefixes.

## Related

- [Terraform DSL Internals](TerraformDSLInternals.md) — How configs are generated
- [Architecture](Architecture.md) — How this fits into the overall system
- [research/deployment-management-analysis.md](../../research/02_deployment_management.md) — Deep investigation
