# Scout-camp scope and themes

> **Non-normative.** This is an architectural investigation, not maintained documentation. It may become outdated as the codebase evolves. Refer to `doc/developer/` for the authoritative summary.

## Repository identity

- **Gem name:** `scout-camp`
- **GitHub:** `git@github.com:mikisvaz/scout-camp`
- **Summary:** "Deploy your scouts"
- **Description:** "Functionalities to deploy and use scouts in remote servers like AWS"
- **Version:** 0.2.1
- **License:** MIT

## High-level purpose

Scout-camp extends the Scout ecosystem with capabilities for:

1. **Infrastructure provisioning** — A Ruby DSL that programmatically composes Terraform configurations, manages deployment lifecycles, and reads state.
2. **Remote execution** — Running Scout workflow steps on remote servers over SSH, including file synchronization and resource production.
3. **Cloud storage** — S3 integration so that Scout `Open` and `Path` operations work transparently with `s3://` URIs.
4. **Web serving** — A set of modular Sinatra extensions for building Scout-powered web applications (rendering, routing, entities, workflows, auth, HTMX fragments).
5. **Serverless** — An AWS Lambda handler that can run any Scout workflow in a Lambda function.

## Dependency graph

```
scout-camp
├── scout-essentials  (foundation: Annotation, Path, Persist, Resource, CMD, Log, Open, TmpFile, Misc)
├── scout-gear        (workflow engine: Workflow, Step, Task, etc.)
├── aws-sdk-s3        (S3 storage operations)
├── net/ssh           (remote SSH execution)
├── sinatra           (web framework)
├── tilt              (template engines: ERB, Haml, Slim)
├── omniauth + omniauth-google-oauth2  (authentication)
└── mimemagic          (content-type detection)
```

## Source layout

```
lib/scout/
├── terraform_dsl.rb              # Core DSL class (375 lines)
├── terraform_dsl/
│   ├── deployment.rb             # Deployment lifecycle management (285 lines)
│   └── util.rb                   # Utilities: logging, introspection (90 lines)
├── offsite.rb                    # Entry point for remote execution
├── offsite/
│   ├── ssh.rb                    # SSH command execution (SSHLine)
│   ├── step.rb                   # Remote Step (OffsiteStep)
│   ├── sync.rb                   # File synchronization via rsync
│   ├── resource.rb               # Resource production on remote servers
│   └── exceptions.rb             # SSHProcessFailed exception
├── aws/
│   └── s3.rb                     # S3 integration for Open and Path (344 lines)
├── render.rb                     # Entry point for rendering
├── render/
│   ├── engine.rb                 # Template rendering engine
│   ├── helpers.rb                # HTML/view helpers
│   └── resource.rb               # Resource-based template location
└── sinatra/
    ├── base.rb                   # Base Sinatra app module (composes sub-modules)
    ├── base/                     # Base sub-modules (helpers, headers, parameters, assets, session, favicon, post_processing)
    ├── fragment.rb               # HTMX-style fragment rendering
    ├── entity.rb                 # Entity-based routes
    ├── workflow.rb               # Workflow job routes
    ├── knowledge_base.rb         # KnowledgeBase integration
    ├── auth.rb                   # OmniAuth authentication (Google OAuth2)
    ├── htmx.rb                   # HTMX trigger headers
    ├── tool.rb                   # Tool rendering helper
    └── finder.rb                 # Finder stub
```

## Share assets

```
share/
├── terraform/
│   ├── aws/
│   │   ├── host/                 # EC2 instance module
│   │   ├── network/              # VPC, security groups, EFS
│   │   ├── bucket/               # S3 bucket
│   │   └── lambda/               # Lambda function
│   └── ssh/
│       └── cmd/                  # SSH command execution module
└── aws/
    └── lambda_function.rb        # AWS Lambda handler
```

## CLI commands

```
scout_commands/
├── find                          # Scout-camp file finder
└── terraform/                    # Terraform sub-commands
    ├── list                      # List available module templates
    ├── config                    # Generate Terraform configuration
    ├── plan                      # Plan a deployment
    ├── apply                     # Apply a deployment
    ├── destroy                   # Destroy a deployment
    ├── add/                      # Add specific infrastructure
    │   └── ollama                # Deploy an Ollama inference server
    └── example                   # Example configuration DSL
```

## Identified themes for investigation

1. **Terraform DSL core** — The DSL class, Module/Output objects, provider/backend/remote methods, config generation pipeline.
2. **Deployment management** — Lifecycle (init/plan/apply/destroy/validate/refresh), state inspection, outputs reading, bundling.
3. **Module templates** — Available modules, their variables/outputs, conventions.
4. **Offsite remote execution** — SSHLine, OffsiteStep, file sync, remote resource production.
5. **S3 integration** — How `Open::S3` and `Path::S3` make S3 transparent.
6. **Rendering engine** — ScoutRender, template location, fragment support.
7. **Sinatra web framework** — Base composition, parameters, assets, fragments, entities, workflows, auth, HTMX.
8. **CLI commands** — Terraform DSL commands and the find command.
9. **Serverless (Lambda)** — How Scout workflows run in AWS Lambda.
10. **Design philosophy** — Scout conventions in this repo.
