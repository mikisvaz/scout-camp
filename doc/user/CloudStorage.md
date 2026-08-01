# Cloud Storage

This document explains how to use S3-backed paths for transparent cloud storage in Scout workflows. It is intended for workflow authors who need to store data, job results, or configuration in the cloud.

## When to use this

Use cloud storage when you want to:

- Store workflow results persistently in S3
- Share data between machines without rsync
- Run serverless workflows on AWS Lambda (which requires S3 persistence)
- Make local files transparently available via S3

## Core concepts

### S3-backed paths

Scout-camp extends Scout's `Path` and `Open` modules to support S3 URLs (`s3://bucket/key`) transparently. Any operation that works on a local file path also works on an S3 path.

### Path maps

Scout's `Path.path_maps` system routes path segments to different locations. Scout-camp adds an `s3` map type that routes paths to S3 URLs:

```ruby
Path.path_maps[:bucket] = "s3://my-bucket/{TOPLEVEL}/{SUBPATH}"
Path.path_maps[:default] = :bucket
```

This makes ALL Scout paths default to S3, which is how serverless workflows work.

### Transparent I/O

The `Open` module is extended so that `Open.read`, `Open.write`, `Open.glob`, `Open.exists?`, `Open.mkdir`, and other methods work on S3 paths just like local paths:

```ruby
Open.write("s3://my-bucket/data.txt", "hello")
content = Open.read("s3://my-bucket/data.txt")  # => "hello"
Open.exists?("s3://my-bucket/data.txt")         # => true
```

## Using S3 storage

### Basic file operations

```ruby
require 'scout-camp'

# Write to S3
Open.write("s3://my-bucket/path/to/file.txt", "content")

# Read from S3
content = Open.read("s3://my-buffer/path/to/file.txt")

# Check existence
Open.exists?("s3://my-bucket/path/to/file.txt")

# Glob
Open.glob("s3://my-bucket/data/*.tsv").each do |file|
  puts file
end

# Streaming read
Open.open("s3://my-bucket/large_file.tsv") do |stream|
  stream.each_line { |line| /* process */ }
end
```

### Configuring path maps

To make all Scout paths default to S3:

```ruby
Path.path_maps[:bucket] = "s3://#{ENV['AWS_BUCKET']}/{TOPLEVEL}/{SUBPATH}"
Path.path_maps[:default] = :bucket
```

After this, all Scout paths (like `Scout.var.jobs`, `Scout.tmp`, etc.) will resolve to S3 locations.

### Using S3 for workflow persistence

```ruby
# Configure S3 as default persistence location
Path.path_maps[:bucket] = "s3://my-workflow-bucket/{TOPLEVEL}/{SUBPATH}"
Path.path_maps[:default] = :bucket

# Now workflow jobs persist to S3
job = MyWorkflow.job(:task, 'job-1', input: 'value')
job.produce  # results stored on S3
job.load     # reads result from S3
```

### Resource sync via S3

Scout's `Resource` system can discover files from remote servers or S3:

```ruby
# Resource can find files in S3
path = Resource.identify('data/reference.fa')
# If the file is in S3, it will be found and used
```

## Common patterns

### Serverless workflow with S3

This is the canonical pattern used by AWS Lambda integration:

```ruby
# In the Lambda handler:
Path.path_maps[:bucket] = "s3://#{ENV['AWS_BUCKET']}/{TOPLEVEL}/{SUBPATH}"
Path.path_maps[:default] = :bucket

# All Scout operations now use S3
workflow = Workflow.require_workflow 'MyWorkflow'
job = workflow.job(:task, 'job-1', inputs)
job.produce
result = job.load  # loaded from S3
```

### Mixed local/S3 storage

```ruby
# Use S3 for specific path types
Path.path_maps[:results] = "s3://my-results-bucket/{TOPLEVEL}/{SUBPATH}"

# Keep other paths local (default)
Scout.root.find  # still local
Scout.var.results['my-result'].find  # resolves to S3
```

### S3 as a job queue

The Lambda integration uses S3 object existence as a signaling mechanism:

```ruby
# Producer: save inputs to S3 path
input_path = Scout.var.queue['MyWorkflow']['task']['job1'].find(:bucket)
Open.write(input_path, data)

# Consumer: check if inputs exist
if Open.exists?(input_path)
  # process
end
```

## Common mistakes

### Not setting AWS credentials

S3 operations require AWS credentials. Ensure `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_REGION` environment variables are set.

### Using S3 paths without requiring scout-camp

```ruby
# Wrong - S3 support not loaded
Open.read("s3://bucket/file")  # NoMethodError or similar

# Right
require 'scout-camp'
Open.read("s3://bucket/file")
```

### Expecting directory operations on S3

S3 doesn't have real directories. Operations like `Open.mkdir` on S3 paths are no-ops or behave differently. Files are listed using prefix-based globbing.

```ruby
# This may not work as expected
Open.mkdir "s3://bucket/new_dir"

# Use glob with prefixes instead
Open.glob("s3://bucket/data/*")
```

### Forgetting that S3 reads are network operations

S3 reads and writes are network operations. For performance:
- Use streaming reads for large files
- Cache frequently accessed data locally
- Consider the latency implications for tight loops

## Next steps

- [Serverless Workflows](ServerlessWorkflows.md) — Running workflows on AWS Lambda with S3
- [Remote Execution](RemoteExecution.md) — Using SSH for remote computation
- scout-essentials [Working with Files](https://github.com/mikisvaz/scout-essentials/json/main/doc/user/WorkingWithFiles.md) — Scout path system fundamentals
- scout-essentials [Caching Results](https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/CachingResults.md) — Persist and caching
