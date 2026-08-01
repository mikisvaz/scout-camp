# Remote Execution Internals

This document explains how scout-camp's offsite execution subsystem works internally: persistent SSH connections, Scout script execution via Marshal, path synchronization, and remote resource production. It is intended for framework contributors.

## SSHLine: persistent SSH connections

### Channel model

`SSHLine` opens a persistent `bash -l` channel over `Net::SSH`. On initialization, it sources `~/.scout/environment` and `~/.rbbt/environment` if they exist. Commands are sent into the channel and completion is detected by appending `echo DONECMD: $?`. The output is parsed for a `DONECMD: <exit_status>` sentinel.

This avoids reconnecting for each command and reuses a single SSH session.

### Connection caching

`SSHLine.open(host, user)` maintains a class-level `@connections` cache keyed by `[host, user]`. If the host is `localhost`, a `SSHLine::Mock` is returned that executes locally via `CMD`.

### Scout script execution

The `scout` method is the key innovation. It wraps the user's Ruby script in `SSHLine.run_local`, which:

1. Redirects real STDOUT → STDERR (so logs go to the right place)
2. Runs the user block
3. Prints `Marshal.dump(result)` to the original STDOUT

The remote execution captures stdout, and the calling side unmarshals the result. This allows arbitrary Ruby objects to cross the SSH boundary.

### Default server

Defaults to `ENV["SCOUT_OFFSITE"]` || `ENV["SCOUT_SERVER"]` || `'localhost'`.

## OffsiteStep: annotation-based remote execution

### Annotation

```ruby
module OffsiteStep
  extend Annotation
  annotation :server, :workflow_name, :clean_id, :batch
end
```

When applied to a Step, it overrides `run`, `info`, `done?`, and other methods to execute on the annotated server.

### Execution flow

1. **Inputs sync** — If the step has provided inputs, they are serialized and rsynced to the remote at `.scout/tmp/step_inputs/<workflow>/<task>/<name>/`
2. **Script generation** — Generates a Ruby script that requires the workflow, creates a job, and runs it
3. **Remote execution** — Sends the script via `SSHLine.scout`
4. **Results sync** — `job.bundle_files` returns the list of result files to sync back via rsync

### Batch vs direct execution

- **Direct** (`exec`): `Workflow.produce(job)` on remote, sync results
- **Batch** (`orchestrate_batch`): Uses `Workflow::Scheduler.produce(job, rules)` for HPC orchestration (SLURM/LSF)

## File synchronization

### `SSHLine.sync(paths, source:, target:, map:)`

High-level sync that handles:
- Path identification via `Resource.identify` (resource-agnostic identifiers)
- Location resolution via `Path#find` on each server
- rsync with `-avztHP --copy-unsafe-links --omit-dir-times`

### `SSHLine.locate(server, paths, map:, source:)`

Resolves a list of paths on a remote server by running a Scout script that finds paths using the appropriate path map and returns `[located_paths, identified_paths]`.

## Remote resource production

`Resource.produce` is overridden with three-tier fallback:

1. **Sync server** — If configured in `Scout.etc/sync_servers.yaml`, rsync the resource from the remote
2. **File server** — If configured in `Scout.etc/file_servers.yaml`, download via HTTP
3. **Local production** — Fall back to the original `produce` (aliased as `local_produce`)

### Server configuration

```yaml
# Scout.etc/sync_servers.yaml
scout-essentials: hpc.cluster.edu
scout-camp: hpc.cluster.edu
```

## Prerequisites for remote execution

- Passwordless SSH access
- Ruby and Scout installed on the remote server
- `scout-camp` installed on the remote (for `SSHLine.run_local`)
- Shared directory structure (or use path maps for relocation)

## Known issues

See [Improvements](../Improvements.md) for SSH connection drop handling, hardcoded inputs directory path, and `orchestrate_batch` requiring HPC module.

## Related

- [Architecture](Architecture.md) — How this fits into the overall system
- [Storage Abstractions](StorageAbstractions.md) — S3 integration details
- [research/agent-delegation-analysis.md](../../research/04_offsite_remote_execution.md) — Deep investigation
