# Design philosophy and conventions investigation

> **Non-normative.** This is an architectural investigation, not maintained documentation. It may become outdated as the codebase evolves.

## Overview

scout-camp extends the Scout ecosystem with infrastructure provisioning, remote execution, cloud storage, serverless workflows, and web application support. It follows the same design philosophy as the rest of Scout.

## Scout design conventions in scout-camp

### 1. The setup pattern (`Path.setup`)

Paths are annotated with metadata and methods. This is the Scout way of making plain strings into rich objects.

```ruby
# From lib/scout-camp.rb
Path.add_path :scout_camp_lib, File.join(Path.caller_lib_dir(__FILE__), "{TOPLEVEL}/{SUBPATH}")
```

### 2. Resource composition

scout-camp extends `Resource` in two places:
- `lib/scout/render/resource.rb` — adds `share/views` to the resource search path for templates.
- `lib/scout/offsite/resource.rb` — adds remote resource sync via SSH and file servers.

This follows the Scout pattern of composing module functionality rather than inheritance.

### 3. The `Hook` module for transparent file I/O extension

The S3 integration uses `Hook` to monkey-patch `Open` and `Path` transparently:

```ruby
# From lib/scout/aws/s3.rb
module Open
  module S3
    extend Hook
    # ... define S3-specific methods
  end
end

Hook.apply(Open::S3, Open)
Hook.apply(Path::S3, Path)
```

This means any code using `Open` or `Path` gets S3 support automatically when S3 paths are used. No code changes needed in consumers.

### 4. Annotation for extending Step behavior

The offsite execution uses `Annotation` to extend `Step` with remote execution capabilities:

```ruby
# From lib/scout/offsite/step.rb
module OffsiteStep
  extend Annotation
  annotation :server, :workflow_name, :on_batch

  def inputs_digest
    # ...
  end

  def exec(noload = false)
    # ...
  end
end
```

Steps can be annotated as "offsite" and gain remote execution methods while remaining regular Step objects.

### 5. Sinatra extension composition

Each Sinatra feature is a self-contained module with a `registered(app)` method:

```ruby
module SinatraScoutWorkflow
  def self.registered(app)
    # ...
  end
end
```

Applications compose features by registering what they need:

```ruby
register SinatraScoutBase
register SinatraScoutWorkflow
register SinatraScoutEntity
```

### 6. The DSL pattern (TerraformDSL)

The TerraformDSL uses Ruby's dynamic method dispatch to create a fluent, declarative DSL:

```ruby
terraform = TerraformDSL.new
host = terraform.add :aws, :host, ami: 'ami-123', instance_type: 't3.micro'
db = terraform.add :aws, :host, ami: 'ami-456', instance_type: 't3.small'

# Module references serialize to Terraform syntax via method_missing
terraform.add :aws, :network, vpc_id: host.vpc_id
```

The `Module#method_missing` returns `Output` objects that serialize to Terraform references.

### 7. TmpFile for reproducible temporary paths

scout-camp uses `TmpFile` for temporary directories and files:

```ruby
# From lambda packaging
TmpFile.with_path do |dir|
  # ... work in temp dir
end  # auto-cleanup
```

### 8. Persist for caching

Template rendering is wrapped in persisted Steps:

```ruby
ScoutRender.render_step(template_file, options) do
  # rendering block cached by Step persistence
end
 template engine code:
```

### 9. SOPT for CLI option parsing

All CLI commands follow the same SOPT pattern:

```ruby
options = SOPT.setup <<EOF
Description
$ #{$0} [<options>] <args>
-h--help Print this help
EOF
```

### 10. IndiferentHash for option processing

```ruby
prefix, clean, recursive_clean, queue, info = IndiferentHash.process_options options,
  :prefix, :clean, :recursive_clean, :queue, :info,
  prefix: "Scout"
```

### 11. Log subsystem

scout-camp uses the Scout `Log` system throughout for colored, leveled logging:

```ruby
Log.info "Payload: #{Log.fingerprint(event)}"
Log.exception $!
```

### 12. Location transparency

The offsite execution makes remote paths work like local paths. `Path` objects can be located on remote servers, and the `Resource` system can sync them automatically. This is the Scout principle of location transparency.

## Architecture overview

```
scout-camp architecture
├── Infrastructure (TerraformDSL)
│   ├── DSL core (terraform_dsl.rb)
│   ├── Deployment lifecycle (deployment.rb)
│   ├── Module templates (share/terraform/)
│   └── CLI commands (scout_commands/terraform/)
├── Remote execution (Offsite)
│   ├── SSH transport (ssh.rb)
│   ├── Path sync (sync.rb)
│   ├── Resource sync (resource.rb)
│   ├── Step execution (step.rb)
│   └── CLI commands (offsite, sync, find, glob)
├── Cloud storage (S3)
│   ├── Open::S3 (file I/O)
│   ├── Path::S3 (path management)
│   ├─
│   └── Resource sync via S3
├── Serverless (AWS Lambda)
│   ├── Handler (share/aws/lambda_function.rb)
│   ├── Packaging (terraform add lambda)
│   └── Invocation (terraform task/lambda_task)
├── Web framework (Sinatra + Render)
│   ├── ScoutRender (template engine)
│   ├── Sinatra extensions (13 modules)
│   └── Asset management
└── Integration with scout-essentials
    ├── Path (path management)
    ├── Open (file I/O)
    ├── Persist (caching)
    ├── Resource (file discovery)
    ├── CMD (command execution)
    ├── Log (logging)
    └── TmpFile (temporary files)
```

## Coding idioms

### Anonymous method dispatch for DSLs

```ruby
class Module
  def method_missing(name, *args)
    Output.new(self, name)
  end
end
```

This is how TerraformDSL module references work. It's a core Scout idiom: use `method_missing` to create fluent references.

### Open3 for command execution

```ruby
# From deployment.rb
def run(cmd)
  command = "cd #{directory} && terraform #{cmd}"
  stdout, stderr, status = Open3.capture3(command)
  raise TerraformException.new stderr if status != 0
  stdout
end
```

### String-based path manipulation

scout-camp treats paths as strings with metadata, not as separate objects. The `Path.setup` annotation adds methods to strings.

## Issues and observations

1. **Inconsistent module naming**: Some modules use `SinatraScout*` (PascalCase), others use `Open::S3` (nested). This is partly driven by the different integration patterns (Sinatra registration vs. Hook application).

2. **No automated tests for offsite/S3/Lambda**: The test suite only covers TerraformDSL. Remote execution, S3 integration, and Lambda integration are untested.

2. **Error handling inconsistencies**: Some commands catch exceptions, others don't. Lambda handler catches `TryAgain` but not other exceptions.

3. **Documentation generation**: No inline API docs. The old `doc/terraform.md` was manually written.

4. **The `finder.rb` Sinatra module is a stub**: `def finder; nil; end` is placeholder code.

5. **Session secret default**: The session module defaults to `"scout_secret"` if `SESSION_SECRET` is not set. This should be a hard error in production.

## Cross-references

- All investigation files: `00` through `08`
- scout-essentials documentation: https://github.com/mikisvaz/scout-essentials/blob/main/doc/StartHere.md
- scout-essentials design principles: https://github.com/mikisvaz/scout-essentials/blob/main/doc/developer/DesignPrinciples.md
