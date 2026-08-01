# Offsite remote execution investigation

> **Non-normative.** This is an architectural investigation, not maintained documentation. It may become outdated as the codebase evolves. Refer to `doc/developer/Architecture.md` for the authoritative summary.

## Overview

The `offsite/` subsystem extends Scout with remote execution capabilities. It provides:
1. `SSHLine` — Persistent SSH connections for running commands and Ruby scripts on remote servers.
2. `OffsiteStep` — A mixin that makes Scout `Step` objects execute on remote servers.
3. File synchronization via `rsync` for transferring inputs and outputs.
4. Remote `Resource` production for producing Scout resources on remote servers.

## SSHLine (`lib/scout/offsite/ssh.rb`, 175 lines)

### Purpose

`SSHLine` wraps `Net::SSH` to provide a persistent SSH connection that can execute shell commands and Ruby scripts on a remote server. It maintains a persistent bash login shell channel.

### Key design: persistent channel with sentinel-based completion detection

On initialization, `SSHLine` opens a channel executing `bash -l`. It sources `~/.scout/environment` and `~/.rbbt/environment` if they exist. Commands are sent into the channel and completion is detected by appending `echo DONECMD: $?` — the output is parsed for a `DONECMD: <exit_status>` sentinel.

This avoids reconnecting for each command and reuses a single SSH session.

### API

| Method | Description |
|--------|-------------|
| `SSHLine.new(host, user)` | Opens persistent connection. Defaults host from `SSHLine.default_server` |
| `SSHLine.open(host, user)` | Class-level connection cache (singleton per host/user pair) |
| `SSHLine.run(server, cmd, options)` | Execute a shell command on server |
| `SSHLine.ruby(server, script)` | Execute a Ruby script on server |
| `SSHLine.scout(server, script)` | Execute a Scout Ruby script; result returned via Marshal serialization |
| `SSHLine.workflow(server, workflow, script)` | Load a workflow and execute a script |
| `SSHLine.command(server, command, argv, options)` | Execute a scout CLI command |
| `SSHLine.mkdir(server, path)` | Create a directory on server |
| `SSHLine.reach?(server)` | Check if server is reachable (with caching) |

### Connection management

- `SSHLine.open` caches connections in `@connections[[host, user]]`.
- If host is `localhost`, returns a `SSHLine::Mock` that executes locally via `CMD`.
- Default server: `ENV["SCOUT_OFFSITE"]` || `ENV["SCOUT_SERVER"]` || `'localhost'`.

### Scout script execution pattern

The `scout` method is the key innovation: it wraps the provided script inside a `SSHLine.run_local` block, executes it remotely via the Ruby interpreter, captures stdout (with actual stdout redirected to stderr), and unmarshals the result. This works because `run_local` serializes the block's return value with `Marshal.dump` and prints it to stdout.

```ruby
# On remote server:
require 'scout'
require 'scout/offsite/ssh'
SSHLine.run_local do
  <user script>
end

# run_local redirects STDOUT to STDERR, runs the block,
# and puts Marshal.dump(result) to the (original) STDOUT
```

### Mock mode

`SSHLine::Mock` subclasses `SSHLine` but overrides `run` and `ruby` to execute locally via `CMD`. This is used when the server is `localhost`, enabling transparent local/remote execution.

## OffsiteStep (`lib/scout/offsite/step.rb`, 100 lines)

### Purpose

`OffsiteStep` is an Annotation module. When applied to a Scout `Step`, it overrides `run`, `info`, `done?`, and other methods to execute the step on a remote server.

### Annotations

```ruby
extend Annotation
annotation :server, :workflow_name, :clean_id, :batch
```

These annotations configure where and how the step runs:
- `:server` — Remote server hostname.
- `:workflow_name` — Workflow to load on the remote.
- `:clean_id` — Clean identifier for the job.
- `:batch` — If true, use HPC batch orchestration instead of direct execution.

### Execution flow

1. **Inputs directory**: If the step has provided inputs, they are serialized to a temp directory and rsynced to the remote server at `.scout/tmp/step_inputs/<workflow>/<task>/<name>/`.
2. **Script generation**: The step generates a Ruby script that:
   - Requires the workflow(s).
   - Creates a job with the task name, clean name, and load_inputs path.
3. **Remote execution**: The script is sent to the server via `SSHLine.scout`.
4. **Sync results**: After the job completes, `job.bundle_files` returns the list of files to sync back. These are rsynced from the remote server.

### Batch vs direct execution

- **Direct** (`exec`): Runs `Workflow.produce(job)` on the remote, syncs results back.
- **Batch** (`orchestrate_batch`): Uses `Workflow::Scheduler.produce(job, rules)` for HPC orchestration. Loads SLURM/LSF rules.

### `info` method

Fetches job info from the remote server by running `job.info` via SSH. Checks `job.running?` to add a `:running` flag.

### `offsite_path`

Returns the remote path of the job by executing `job.path.identify` on the server.

## File synchronization (`lib/scout/offsite/sync.rb`, 100 lines)

### `SSHLine.sync(paths, source:, target:, map:)`

High-level synchronization between local and remote paths. Handles:
- **Path identification**: Uses `Resource.identify` to compute resource-agnostic identifiers.
- **Location resolution**: On each server, `Path#find` resolves the identifier to a concrete path.
- **rsync**: Uses `CMD.cmd_log` to execute `rsync -avztHP --copy-unsafe-links --omit-dir-times`.

### `SSHLine.rsync(source_path, target_path, ...)`

Low-level rsync wrapper. Handles:
- Source/target being local or remote (`source:`, `target:` parameters are server names).
- Directory trailing slashes.
- Hard-linking (`--link-dest`).
- Dry-run mode.

### `SSHLine.locate(server, paths, map:, source:)`

Resolves a list of paths on a remote server. Runs a Scout script that:
1. Takes paths and finds them using the appropriate path map.
2. Returns `[located_paths, identified_paths]`.

This is the bridge between local `Path` identifiers and remote file locations.

## Resource production (`lib/scout/offsite/resource.rb`, 170 lines)

### Purpose

Extends the `Resource` module to support producing resources on remote servers. When a resource is needed locally but its production code is on a remote server, scout-camp can sync it down.

### Server configuration

Resources are configured via YAML files in `Scout.etc/`:
- `sync_servers.yaml` — Maps resource names to servers that can produce them.
- `file_servers.yaml` — Maps resource names to web servers that serve files.

Example `sync_servers.yaml`:
```yaml
scout-essentials: hpc.cluster.edu
scout-camp: hpc.cluster.edu
```

### `Resource.produce` override

The `produce` method is overridden to try three strategies in order:
1. **Sync server**: If a `sync_server` is configured, `Resource.sync` to pull the resource from the remote.
2. **File server**: If a `file_server` is configured, download via HTTP (`Resource.get_from_server`).
3. **Local production**: Fall back to the original `local_produce` (aliased from `produce`).

### `Resource.get_from_server`

Downloads a resource from a web server endpoint `/resource/<name>/get_file?file=<path>&create=false`. Handles:
- Direct file download (streaming).
- Directory download (HTTP redirect to a tar.gz, extracted locally).
- Caching of missing resources to avoid repeated failures.

## Design patterns

### Sentinel-based async completion

The `SSHLine` channel uses a `DONECMD: <status>` sentinel rather than timeouts or polling. This is robust and simple.

### Marshal serialization for remote returns

The `scout` method serializes return values via `Marshal.dump`, allowing arbitrary Ruby objects to be returned from remote execution. The `run_local` trick (redirecting real STDOUT to STDERR and using real STDOUT for Marshal output) is elegant.

### Annotation-based step extension

`OffsiteStep` uses Scout's `Annotation` module to add configuration (`:server`, `:batch`) to Step objects without modifying their class hierarchy.

### Three-tier fallback

`Resource.produce` tries sync server → file server → local production. This provides graceful degradation.

## Issues and observations

1. **`SSHLine.scout` requires `scout/offsite/ssh` on the remote**: The remote script requires `scout/offsite/ssh` to get `SSHLine.run_local`. This means scout-camp must be installed on the remote server.

2. **Error handling in SSH**: If the SSH connection drops mid-execution, there's no automatic reconnection. The `@ssh.loop` will block indefinitely.

3. **Inputs directory path is hardcoded**: `.scout/tmp/step_inputs/...` is not configurable.

4. **No streaming**: The `exec` method waits for the full job to complete before syncing results. Long-running jobs provide no progress feedback.

5. **`orchestrate_batch` requires HPC module**: `require 'rbbt/hpc'` is specific to the rbbt ecosystem and may not be available on all servers.

6. **`SSHLine::Mock` inherits from `SSHLine`** but its `initialize` takes no arguments and doesn't call `super`. This means a Mock instance doesn't have `@host`, `@user`, etc. — but that's fine since the overridden methods don't use them.

7. **Resource sync caching**: `@server_missing_resource_cache` is a class-level `Set` that prevents re-trying failed resources, but it's never cleared (potential memory growth in long-running processes).

## Cross-references

- S3 integration: see `05_s3_integration.md`
- Design philosophy: see `09_design_philosophy.md`
- scout-essentials Resource: https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/ProducingResources.md
- scout-essentials Path: https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/WorkingWithFiles.md
