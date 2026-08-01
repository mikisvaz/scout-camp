# Architecture

This document explains the overall architecture of scout-camp: how its subsystems fit together, what design patterns they share, and how they integrate with the broader Scout ecosystem. It is intended for framework contributors and advanced workflow developers who need to understand the codebase as a whole.

## Purpose of scout-camp

scout-camp extends the Scout ecosystem with five capabilities:

1. **Infrastructure provisioning** — A Ruby DSL for composing Terraform configurations
2. **Remote execution** — Running Scout workflow steps on remote servers over SSH
3. **Cloud storage** — Transparent S3 support for Scout's file I/O abstractions
4. **Serverless workflows** — Running Scout workflows on AWS Lambda
5. **Web serving** — Sinatra extensions for building Scout-powered web applications

## Module map

```
scout-camp
├── lib/scout/
│   ├── terraform_dsl.rb          # DSL builder + Module/Output references
│   ├── terraform_dsl/
│   │   ├── deployment.rb         # Terraform lifecycle wrapper
│   │   └── util.rb               # Introspection + logging helpers
│   ├── offsite.rb                # Entry point
│   ├── offsite/
│   │   ├── ssh.rb                # Persistent SSH connections (SSHLine)
│   │   ├── step.rb               # OffsiteStep annotation
│   │   ├── sync.rb               # File synchronization (rsync)
│   │   ├── resource.rb           # Remote resource production
│   │   └── exceptions.rb
│   ├── aws/
│   │   └── s3.rb                 # S3 hooks for Open and Path
│   ├── render.rb                 # Entry point
│   ├── render/
│   │   ├── engine.rb             # Tilt-based template engine with Step caching
│   │   ├── helpers.rb            # HTML helper methods
│   │   └── resource.rb           # Template discovery via Resource
│   └── sinatra/
│       ├── base.rb               # Core Sinatra composition
│       ├── base/                 # Sub-modules (parameters, assets, session, etc.)
│       ├── entity.rb             # Entity routes
│       ├── workflow.rb           # Workflow job routes
│       ├── fragment.rb           # Fragment rendering
│       ├── htmx.rb               # HTMX trigger headers
│       ├── auth.rb               # OmniAuth authentication
│       ├── knowledge_base.rb
│       ├── tool.rb
│       └── finder.rb
├── share/
│   ├── terraform/                # Module templates (aws/*, ssh/*)
│   └── aws/                      # Lambda handler
└── scout_commands/               # CLI commands
```

## Dependency graph

```
scout-camp
├── scout-essentials  (Path, Open, Persist, Resource, CMD, Log, TmpFile, Misc)
├── scout-gear        (Workflow, Step)
├── aws-sdk-s3        (S3 storage operations)
├── net/ssh           (remote SSH execution)
├── sinatra           (web framework)
├── tilt              (template engines: ERB, Haml, Slim)
├── omniauth          (authentication)
└── mimemagic         (content-type detection)
```

## Cross-cutting design patterns

scout-camp reuses the same design idioms found throughout Scout. See the [scout-essentials design principles](https://github.com/mikisvaz/scout-essentials/blob/main/doc/developer/DesignPrinciples.md) for a general introduction.

### Hook-based extension

The S3 integration uses `Hook.apply` to inject S3-aware behavior into `Open` and `Path` without inheritance or code changes in consumers:

```ruby
Hook.apply(Open::S3, Open)   # S3 paths now work with all Open operations
Hook.apply(Path::S3, Path)   # S3 paths now work with all Path operations
```

### Annotation-based step extension

`OffsiteStep` extends Scout's `Step` with remote execution capabilities via the `Annotation` module, without modifying the class hierarchy.

### Composition via Sinatra registration

Each web feature is a self-contained Sinatra module with a `registered(app)` class method. Applications compose only what they need.

### Builder pattern with `method_missing`

`TerraformDSL` uses `method_missing` on `Module` objects to create fluent output references that serialize to Terraform syntax.

## How subsystems interact

The subsystems are designed to be used independently, but they compose naturally:

```
Provision infrastructure ──→ Deploy ──→ Get server IP
  (TerraformDSL)           (Deployment)     │
                                            ↓
                              Run workflow steps remotely
                                   (OffsiteStep)
                                        │
                            ┌───────────┼───────────┐
                            ↓           ↓           ↓
                       SSH sync     S3 storage   Web serving
                      (SSHLine)     (Open::S3)  (Sinatra)
                                        │           │
                                   Lambda handler    │
                                   (serverless) ─────┘
```

For deeper detail on each subsystem, see the related investigation reports in `research/` and the corresponding developer documents below.

## Next steps

- [Design Principles](DesignPrinciples.md) — Conventions and coding idioms
- [Terraform DSL Internals](TerraformDSLInternals.md) — How the DSL generates configuration
- [Deployment Lifecycle](DeploymentLifecycle.md) — How deployments are managed
- [Remote Execution Internals](RemoteExecutionInternals.md) — How SSH-based execution works
- [Web Framework Internals](WebFrameworkInternals.md) — How the Sinatra extensions compose
- [Storage Abstractions](StorageAbstractions.md) — How S3 support is injected
