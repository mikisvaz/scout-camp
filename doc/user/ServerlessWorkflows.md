# Serverless Workflows

This document explains how to run Scout workflows on AWS Lambda for serverless execution. It is intended for workflow authors who need to run tasks in the cloud without managing servers.

## When to use this

Use serverless workflows when you want to:

- Run workflow tasks on-demand without provisioning servers
- Process workloads triggered by events (e.g., API calls, queues)
- Scale workflow execution automatically with demand
- Pay only for actual compute time

If you need long-running processes (over 15 minutes), persistent servers, or tight latency, consider [Remote Execution](RemoteExecution.md) instead.

## Core concepts

### Lambda handler

The Lambda handler is a Ruby function that receives an event hash and executes a Scout workflow task. It is packaged with Scout and your workflows into a Lambda deployment zip.

### S3 persistence

Lambda functions are ephemeral. All workflow state, inputs, and results are persisted to S3 using Scout's [path map system](CloudStorage.md). This makes job results durable across Lambda invocations.

### S3 job queue

Jobs can be queued asynchronously using S3 as a message broker. The queue mechanism uses S3 object existence as a signaling mechanism.

### TryAgain pattern

After producing a job, the handler raises a `TryAgain` exception to retry the dispatch logic. On retry, the job status has changed and the result can be returned.

## Using serverless workflows

### Deploying a Lambda function

Deploy the Lambda function infrastructure using the Terraform DSL:

```ruby
require 'scout-camp'

terraform = TerraformDSL.new
terraform.aws region: 'us-east-1'

# Add the Lambda function module
terraform.add :aws, :lambda,
  function_name: 'scout-lambda',
  runtime: 'ruby_3_2',
  handler: 'lambda_function.lambda_handler',
  filename: 'scout-lambda.zip',
  memory_size: 2048,
  timeout: 900

terraform.config '/my/deployments/scout-lambda'
```

### Packaging the Lambda zip

The `scout terraform add lambda` command builds a Lambda-ready zip file that includes:
- The Lambda handler file (`lambda_function.rb`)
- A `Gemfile` with your dependencies
- Workflow files (symlinked)
- Bundled gems

```bash
scout terraform add lambda --workflows MyWorkflow --dependencies scout-camp
```

### Invoking a task

Use the `scout terraform task` command to invoke a task on the Lambda function:

```bash
# List available tasks
scout terraform task MyWorkflow

# Get task info
scout terraform task MyWorkflow MyTask --info

# Run a task
scout terraform task MyWorkflow MyTask --input value
```

Or use `scout terraform lambda_task` for queue and clean options:

```bash
# Queue the job asynchronously
scout terraform lambda_task MyWorkflow MyTask --queue --input value

# Clean before running
scout terraform lambda_task MyWorkflow MyTask --clean

# Get job info
scout terraform lambda_task MyWorkflow MyTask --info
```

### Programmatic invocation

The handler receives an event hash:

```ruby
{
  workflow: 'MyWorkflow',
  task_name: 'MyTask',
  jobname: 'job-1',
  inputs: { param: 'value' },
  queue: false,
  info: false,
  clean: false
}
```

Response depends on job status:

| Job status | Response |
|------------|----------|
| done | `{ result: <loaded_result> }` |
| error | `{ exception: ..., error: ... }` |
| started | `{ job: <path>, status: ... }` |
| queued | `{ job: <path> }` |

## Common patterns

### Asynchronous job queue

```ruby
# Queue the job (returns immediately)
# event = { workflow: 'WF', task_name: 'T', jobname: 'j1', inputs: {...}, queue: true }
# response = { job: "s3://bucket/var/jobs/WF/T/j1" }

# Later, check the job status
# event = { workflow: 'WF', task_name: 'T', jobname: 'j1', inputs: {...}, wait: true }
# On retry: if inputs exist → still queued; if result exists → done
```

### Loading a job by path

```ruby
# Load a previously created job directly by path
# event = { path: "s3://bucket/var/jobs/WF/T/j1" }
```

## Common mistakes

### Exceeding Lambda limits

AWS Lambda has constraints:
- **15 minute timeout**: Long-running tasks will fail.
- **10 GB ephemeral storage** (`/tmp`): Large intermediate files may exhaust space.
- **Memory**: Memory allocation affects CPU allocation.

If your workflow exceeds these limits, use [Remote Execution](RemoteExecution.md) instead.

### Not configuring S3 bucket

The Lambda function requires `AWS_BUCKET` environment variable to be set. Without it, path resolution fails:

```ruby
# In the handler, S3 paths are configured using:
Path.path_maps[:bucket] = "s3://#{ENV["AWS_BUCKET"]}/{TOPLEVEL}/{SUBPATH}"
```

### Forgetting that containers are reused

AWS Lambda may reuse execution environments across invocations. The handler clears `Workflow.job_cache` on each invocation to avoid stale state, but be aware that module-level caches in your code may persist.

### Expecting synchronous results from queued jobs

When using `queue: true`, the job is saved but not executed. You must later invoke with `wait: true` to check if the result is ready:

```bash
# Queue
scout terraform lambda_task WF T --queue

# Check later
scout terraform lambda_task WF T --wait
```

## Next steps

- [Cloud Storage](CloudStorage.md) — Understanding S3-backed paths
- [Provisioning Infrastructure](ProvisioningInfrastructure.md) — Provisioning Lambda infrastructure
- [Managing Deployments](ManagingDeployments.md) — Deploying and managing Lambda infrastructure
- scout-essentials [Caching Results](https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/CachingResults.md) — Persist and caching
