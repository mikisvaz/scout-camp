# Improvements

This document lists actionable recommendations for code improvements in scout-camp, discovered during the documentation investigation. Items are grouped by category and labeled with status: **open**, **resolved**, or **won't fix**.

## Bugs

### B1: `with_bundle` method has incorrect variable reference — **open**

In `lib/scout/terraform_dsl/deployment.rb`, the `with_bundle` method uses the variable `file` where it should use `name` or the bundle file path. The variable is referenced inconsistently, which would cause a `NameError` or incorrect behavior at runtime.

**Fix:** Use the correct variable (likely `file` should be `name` in the parameter list, or vice versa).

### B2: Duplicate `stdin.close` in `run_log` — **open**

In `lib/scout/terraform_dsl/deployment.rb`, the `run_log` method calls `stdin.close` twice. The second call is unnecessary and may raise an error on some Ruby versions.

**Fix:** Remove the duplicate `stdin.close` call.

### B3: Incorrect GitHub URL in `RemoteExecution.md` — **open**

In `doc/user/RemoteExecution.md`, there is a reference to `kikisvaz/scout-essentials` (with `k` instead of `m`). All other references use `mikisvaz/scout-essentials`.

**Fix:** Correct the URL to `mikisvaz/scout-essentials`.

### B3b: Incorrect GitHub URLs in `StartHere.md` — **open**

In `doc/StartHere.md`, several scout-essentials links have typos in the GitHub URLs (e.g., `jikisvaz`, `chartlyrics`, `mukisvaz`, `-based-on-the.net`, `scout-existing`). These need correction.

**Fix:** Correct all GitHub URLs to `https://github.com/mikisvaz/scout-essentials/...`.

## Code Quality

### C1: Regex-based HCL parsing for module templates — **open**

`TerraformDSL.module_variables` and `TerraformDSL.module_outputs` use line-by-line regex matching to parse Terraform `variables.tf` and `output.tf` files. This approach is fragile with:
- Multi-line string defaults
- HCL2 syntax (e.g., `type = list(string)`)
- Inline comments
- Nested blocks

**Recommendation:** Consider using a proper HCL parser (e.g., the `ruby-hcl` gem) or the `terraform validate -json` output for reliable introspection.

### C2: `info` command may be outdated — **open**

As noted in the original task description, the `scout_commands/llm/info` command (in scout-ai) may be outdated. Within scout-camp, the corresponding `scout_commands/` commands should be verified against current code behavior.

### C3: `finder.rb` is a stub — **open**

`lib/scout/sinatra/finder.rb` appears to be a stub or incomplete implementation. It should either be completed or removed if not needed.

### C4: Hardcoded inputs directory path — **open**

In `lib/scout/offsite/step.rb`, the path for syncing step inputs is hardcoded as `.scout/tmp/step_inputs/`. This should use `Scout.tmp.step_inputs` for consistency with path map conventions.

### C4b: SSHLine conpass() method — **open**

The `SSHLine.conpass()` method name is unclear. Consider renaming to something more descriptive like `wait_for_completion` or `read_until_done`.

### C5: Lambda handler has no error handling for missing workflow — **open**

The `share/aws/lambda_function.rb` handler assumes the workflow exists and is require-able. If the workflow is not found, the handler would crash with an unhelpful error. Consider adding a rescue clause with a descriptive error message.

### C6: S3 `Persist` reads/writes the entire database per operation — **open**

S3-backed `Persist` databases are downloaded on read and uploaded on write. For large databases, this is inefficient. Consider adding a local caching layer or using a key-value store that supports partial access.

### C7: S3 glob only supports prefix-based patterns — **open**

The S3 `glob` implementation uses `list_objects_v2` with prefix/delimiter, which only matches prefix patterns. It does not support full glob syntax (e.g., `*` in the middle of a path). Document this limitation or add a fallback that lists all objects and filters client-side.

### C8: Lambda `TryAgain` retry loop has no limit — **open**

The `TryAgain` retry loop in the Lambda handler retries indefinitely. If a job never completes, the Lambda function will timeout. Consider adding a maximum retry count or using the Lambda timeout as the bound.

### C9: Web framework lacks CSRF protection — **open**

`SinatraScoutBase` does not include CSRF protection. If the app accepts POST requests, it is vulnerable to cross-site request forgery. Consider adding `rack-protection` or a similar middleware.

### C9b: Session secret is default — **open**

`SinatraScoutBase` does not set a custom session secret. Sinatra uses a random default that changes on restart, invalidating sessions. Consider requiring an explicit configuration.

### C10: `SSHLine` connection drop handling — **on hold**

Persistent SSH connections may drop due to network issues or server-side timeouts. The current code does not detect dropped connections or attempt reconnection. The `@connections` cache may return a dead connection.

**Status:** On hold because adding reconnection logic is complex and the frequency of drops depends on the deployment environment.

### C10b: `orchestrate_batch` requires HPC module — **open**

The `orchestrate_batch` method in `OffsiteStep` calls `Workflow::Scheduler.produce`, which requires the `rbbt-util` HPC module to be available. If it's not available, the method will raise `NameError`. Consider adding a check or a graceful fallback.

## Missing Features

### M1: No S3 presigned URLs — **open**

The S3 integration does not provide presigned URLs, which would be useful for direct browser uploads/downloads without proxying through the application.

### M2: No web UI for deployment management — **in consideration**

Currently, deployments are managed via CLI commands. A web UI for viewing deployment state, outputs, and logs would be useful, but would require significant new UI work.

### M3: No remote execution of arbitrary code blocks — **open**

The `SSHLine.scout` method executes Scout scripts. It does not support executing arbitrary Ruby blocks sent from the calling side (like `Marshal.dump(block)`). This would enable more flexible remote execution patterns.

### M4: No SSH connection pooling limit — **open**

`SSHLine` caches connections per `[host, user]`. There is no limit on the number of cached connections. If many different servers are used, this could exhaust resources.

### M5: No support for Terraform Cloud / Terraform Enterprise — **open**

The deployment lifecycle currently supports local state files and backends. There is no support for Terraform Cloud or Terraform Enterprise integration.

## Documentation

### D1: Old `doc/terraform.md` should be removed — **open**

The old flat documentation file `doc/terraform.md` is still present. It should be removed once the new structured documentation is validated.

### D2: Reorganize research artifacts — **open**

The research artifacts currently have numbered filenames (e.g., `01_terraform_dsl_core.md`). These could be renamed to descriptive names for better discoverability.

## Priority recommendations

1. **Fix B1, B2 bugs** — These affect the core deployment workflow
2. **Fix B3, B3b** — Correct all GitHub URLs to `mikisvaz/scout- Improvements.md`
3. **Address C1** — Regex-based HCL parsing is a fragility risk
4. **Address C4** — Use Scout.tmp instead of hardcoded paths
5. **Address C9/C9b** — Web security is important for production deployments
6. **Address C6/C7** — S3 persistence performance and glob limitations
7. D1 and D2 are documentation cleanup tasks

## Related

- [Start Here](StartHere.md)
- [Architecture](developer/Architecture.md)
