# Design Principles

This document explains the coding conventions and design philosophy used throughout scout-camp. It is intended for framework contributors who need to extend the codebase while maintaining its style and expressiveness.

## Scout conventions in scout-camp

scout-camp follows the same design principles as the broader Scout ecosystem. See the [scout-essentials design principles](https://github.com/mikisvaz/scout-essentials/blob/main/doc/developer/DesignPrinciples.md) for the foundational conventions (setup pattern, Path annotation, fluent APIs, module composition, TmpFile, Persist, Log, SOPT).

Below are the conventions specific to scout-camp.

## 1. Hook-based transparent extension

When you need to make existing Scout classes aware of a new URI scheme or storage backend, define a module and apply it with `Hook`:

```ruby
module Open
  module S3
    extend Hook

    def self.claim_uri(uri)
      uri.start_with? 's3://'
    end

    def self.get_stream(uri)
      # S3-specific implementation
    end
  end
end

Hook.apply(Open::S3, Open)
```

This aliases the original methods to `orig_*` and installs the extension. When a method is called, the extension checks whether it should handle the request (e.g., via `claim_uri`) and either processes it or delegates to the original.

**Why this matters:** It enables transparent S3 support across all of Scout's I/O without modifying any consumer code.

## 2. Annotation for step behavior

To add configuration and behavior to a `Step` without subclassing, use the `Annotation` module:

```ruby
module OffsiteStep
  extend Annotation
  annotation :server, :workflow_name, :clean_id, :batch

  def exec(noload = false)
    # Remote execution logic
  end
end
```

Any `Step` can be annotated as offsite and gain remote execution methods while remaining a regular Step.

## 3. Builder pattern with method_missing for DSLs

`TerraformDSL` uses `method_missing` on `Module` objects to create output references:

```ruby
host = terraform.add :aws, :host, ami: 'ami-123'
host.aws_instance_ip  # => Module::Output.new('host', 'aws_instance_ip')
```

The `Output` object's `to_json` serializes to `module.host.aws_instance_ip`, which is valid Terraform syntax. This allows fluent composition: outputs from one module can be passed as inputs to another.

## 4. Composition via Sinatra registration

Each web feature is a self-contained module:

```ruby
module SinatraScoutWorkflow
  def self.registered(app)
    app.helpers do ... end
    app.get '/:task_name/:jobname' do ... end
  end
end
```

Applications compose features:

```ruby
class MyApp < Sinatra::Base
  register SinatraScoutBase       # required first
  register SinatraScoutWorkflow   # workflow routes
  register SinatraScoutEntity     # entity routes
end
```

## 5. Sentinel-based async completion

`SSHLine` uses a `DONECMD: <exit_status>` sentinel to detect command completion on its persistent SSH channel, rather than timeouts or polling. This is robust and simple.

## 6. Marshal serialization for remote returns

The `SSHLine.scout` method wraps user scripts in `SSHLine.run_local`, which:
1. Redirects real STDOUT to STDERR
2. Runs the block
3. Prints `Marshal.dump(result)` to the original STDOUT

This allows arbitrary Ruby objects to be returned from remote execution. The result is unmarshalled on the calling side.

## 7. Three-tier fallback for resource production

`Resource.produce` tries three strategies in order:
1. Sync server (rsync from remote)
2. File server (HTTP download)
3. Local production (original behavior)

This provides graceful degradation.

## 8. TryAgain retry pattern

The Lambda handler uses a `TryAgain` exception to re-enter the dispatch logic after a state transition (e.g., after calling `job.produce`):

```ruby
begin
  job.produce
  raise TryAgain
rescue TryAgain
  retry
end
```

On retry, the job status has changed and the result can be returned. This avoids complex state machines.

## Anti-patterns to avoid

### Don't subclass Scout classes to add features

Use Annotation, Hook, or module composition instead.

### Don't parse HCL with regex

The DSL currently uses regex parsing for `variables.tf` and `output.tf`. This is fragile. Prefer a proper parser for any new template introspection code.

### Don't hardcode paths

Use `Scout.var`, `Scout.tmp`, `Scout.share`, or `Scout.etc` for path resolution. These respect path maps and work transparently with S3.

## Related

- [Architecture](Architecture.md) — How subsystems fit together
- scout-essentials [Design Principles](https://github.com/mikisvaz/scout-essentials/blob/main/doc/developer/DesignPrinciples.md) — Foundational conventions
- [Design Philosophy Investigation](../../research/09_design_philosophy.md) — Deep investigation of scout-camp conventions
