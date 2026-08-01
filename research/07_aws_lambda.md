# AWS Lambda investigation

> **Non-normative.** This is an architectural investigation, not maintained documentation. It may become outdated as the codebase evolves.

## Overview

scout-camp provides AWS Lambda integration that allows Scout workflows to run in a serverless environment. This enables workflow execution without provisioning or managing servers, with state and results persisted to S3.

## Components

### Lambda handler (`share/aws/lambda_function.rb`)

This is the entry point for the AWS Lambda function. It's a standalone Ruby file (not part of the library) that gets packaged with the scout-camp gem and Scout workflows into a Lambda deployment zip.

### Lambda packaging (`scout_commands/terraform/add/lambda`)

The `scout terraform add lambda` command packages the Lambda function with:
- The handler file
- A Gemfile with specified dependencies
- Workflow files (symlinked)
- Bundled gems (via `bundle install`)

### Lambda invocation (`scout_commands/terraform/task`, `scout_commands/terraform/lambda_task`)

CLI commands for invoking tasks on the Lambda function remotely.

---

## Handler logic (`share/aws/lambda_function.rb`)

The handler receives an event hash with these keys:

| Key | Purpose |
|-----|---------|
| `workflow` | Workflow name (required) |
| `task_name` | Task to run (optional - if nil, lists workflow tasks) |
| `jobname` | Job name (for named jobs) |
| `inputs` | Task inputs hash |
| `clean` | Clean mode: `true` = clean, `'recursive'` = recursive clean |
| `queue` | Queue the job instead of running synchronously |
| `info` | Return job info instead of result |
| `path` | Load a job by path instead of creating new |

### Handler flow

```
event → parse options → dispatch based on task_name
```

1. **Setup**: Configures S3 path maps for Scout persistence. `Path.path_maps[:bucket] = "s3://#{ENV["AWS_BUCKET"]}/{TOPLEVEL}/{SUBPATH}"`. Sets `Path.path_maps[:default] = :bucket` so all Scout paths default to S3.

2. **No task_name**: Return available tasks and workflow documentation.

3. **task_name = "info"**: Return task info (inputs, types, description).

4. **Normal execution**:
   - Clears `Workflow.job_cache` (Lambda containers may be reused).
   - Sets up temp directories under `/tmp`.
   - Creates or loads a job.
   - Handles clean operations.
   - Dispatches based on job status:
     - `info: true` → return job info with path
     - `done` → return loaded result
     - `error` → return exception info
     - `started` → return job path and status
     - `queue: true` → save inputs to S3 queue, return job path
     - `wait: true` → check if inputs are ready
     - Default → `job.produce` then `retry` (TryAgain pattern)

### The TryAgain pattern

```ruby
begin
  # ... try to complete the job
  job.produce
  raise TryAgain
rescue TryAgain
  retry
end
```

This is a key pattern: after producing a job, it raises `TryAgain` to retry. On retry, the job will be `done?` and the result is returned. This handles the case where `produce` returns before the job is complete.

### S3 queue mechanism

When `queue: true`:
1. Job inputs are saved to `Scout.var.queue[workflow][task][job].find(:bucket)` (S3).
2. Job status is saved as `:queue`.
3. Returns `{job: job.path}`.

When `wait: true` (for queued jobs):
1. Checks if inputs exist at the S3 queue path.
2. If inputs exist: `{job: job.path}` (job is queued).
3. If inputs don't exist: `job.join` then `raise TryAgain` (wait for the result).

This creates an asynchronous job queue using S3 as the message broker.

---

## Lambda packaging (`scout_commands/terraform/add/lambda`)

### `lambda_package(dependencies, workflows, function_file, pkg)`

Builds a Lambda-ready zip file:

1. Creates a temp directory.
2. Copies the Lambda handler file.
3. Writes a `Gemfile` with dependencies.
4. Symlinks workflow directories.
5. Runs `bundle config set path 'vendor/bundle'` and `bundle install`.
6. Removes gem cache and RubyInline to reduce size.
7. Zips `vendor/bundle`, `lambda_function.rb`, and workflow directory.

### Terraform configuration

The command also generates Terraform config for:
- IAM role (`aws/role`) with Lambda principal.
- Policy attachments for `AWSLambdaBasicExecutionRole` and `AmazonS3FullAccess`.
- Lambda function (`aws/lambda`) with:
  - The packaged zip file.
  - The IAM role ARN.
  - Environment variables: HOME, HOSTNAME, AWS_BUCKET, SCOUT_NOCOLOR.

---

## CLI invocation

### `scout terraform task`

Invokes a Lambda function:

```
event = {workflow: WF, task_name: TASK}
↓
Lambda(info) → task_info
↓
build SOPT from task_info
↓
parse local options
↓
Lambda(execute) → result
```

1. If no task_name: list all tasks.
2. If task_name: fetch task info from Lambda, build SOPT options string, parse local command-line options, invoke Lambda with inputs.

### `scout terraform lambda_task`

Same as `task` but with additional support for:
- `--queue`: Queue the job asynchronously.
- `--clean`: Clean the job before running.
- `--info`: Return job info instead of result.
- `--recursive_clean`: Clean recursively.

---

## Architecture: Lambda + S3 + Scout

```
Local Machine                      AWS
┌─────────────────┐               ┌──────────────────────────────┐
│ scout terraform │               │ ┌──────────────────────────┐ │
│ task WF TASK    │──── invoke ──→│ │ Lambda Function          │ │
│                 │               │ │  ┌─────────────────────┐ │ │
│                 │               │ │  │ lambda_function.rb  │ │ │
│                 │               │ │  │  - Parse event      │ │ │
│                 │               │ │  │  - Create/load job  │ │ │
│                 │               │ │  │  - Queue or produce │ │ │
│                 │               │ │  └─────────┬─────────┘ │ │
│                 │               │ └────────────┼────────────┘ │
│                 │               │              ↓              │
│                 │               │ ┌──────────────────────────┐ │
│                 │←── response ──│ │ S3 Bucket                │ │
│                 │               │ │  - Job state             │ │
│                 │               │ │  - Job results           │ │
│                 │               │ │  - Queue                 │ │
└─────────────────┘               │ └──────────────────────────┘ │
                                  └──────────────────────────────┘
```

Scout's `Path` system routes all persistence to S3 when `Path.path_maps[:default] = :bucket` is set in the Lambda handler. This means:
- Workflow job state is stored on S3.
- Job results are stored on S3.
- The queue mechanism uses S3 paths for inter-invocation communication.

---

## Design patterns

### Serverless Scout workflows

The key insight is that Scout's entire path and persistence system works transparently over S3. By configuring `Path.path_maps`, the Lambda handler makes the Lambda function behave as if it were a local Scout execution with S3-backed storage.

### TryAgain retry pattern

The `TryAgain` exception is used to re-enter the dispatch logic after a state transition (e.g., after `produce` is called). This avoids complex state machines by using Ruby's exception mechanism for control flow.

### S3 as a message queue

The queue mechanism uses S3 object existence as a signaling mechanism:
- **Producer**: Saves inputs to an S3 path.
- **Consumer**: Checks if inputs exist at the S3 path.
- **Completion**: Saves results to the S3 path (standard Scout persistence).

This is a simple, durable, serverless job queue without additional infrastructure.

## Issues and observations

1. **`TryAgain` is not defined in scout-camp**: It's referenced in `lambda_function.rb` but not defined. It's likely defined in scout-gear or scout-essentials, or it should be defined here.

2. **Handler file is in `share/aws/`, not `lib/`**: This is correct since it's a deployment artifact, not library code. But it means it's not part of the gem's load path.

3. **No dead letter queue**: Failed Lambda invocations are not retried or dead-lettered.

4. **`Workflow.job_cache.clear` on every invocation**: This is a workaround for Lambda container reuse. The cache might need to be more sophisticated.

5. **No timeout handling**: Lambda has a 15-minute timeout. Long-running workflows will fail silently.

6. **Error response format**: Error responses include raw Ruby exception information, which may expose internals.

7. **No concurrency control**: Multiple Lambda invocations could operate on the same job simultaneously.

8. **Gem packaging**: The `bundle install` step in packaging installs gems into the zip, which makes the zip large. Consider using Lambda layers.

## Cross-references

- S3 integration: see `05_s3_integration.md`
- CLI commands: see `08_commands_and_cli.md`
- Deployment management: see `02_deployment_management.md`
- scout-essentials Path: https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/WorkingWithFiles.md
- scout-essentials Persist: https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/CachingResults.md
