# Synthesis report

> **Non-normative.** This is an architectural investigation, not maintained documentation. It may become outdated as the codebase evolves.

## Purpose

This report synthesizes the findings from investigations `00` through `09`, identifies cross-cutting themes, resolves overlaps, identifies gaps, and produces a concrete mapping from research artifacts to target documentation files.

## Identified subsystems

From the investigations, scout-camp contains these subsystems:

| # | Subsystem | Investigation | Key lib files |
|---|-----------|---------------|---------------|
| A | Terraform DSL core | 01 | `terraform_dsl.rb`, `terraform_dsl/util.rb` |
| B | Deployment lifecycle | 02 | `terraform_dsl/deployment.rb` |
| C | Module templates | 03 | `share/terraform/` |
| D | Remote execution (Offsite) | 04 | `offsite/ssh.rb`, `step.rb`, `sync.rb`, `resource.rb` |
| E | S3 cloud storage | 05 | `aws/s3.rb` |
| F | Web framework (Sinatra) | 06 | `sinatra/*.rb`, `render/*.rb` |
| G | AWS Lambda | 07 | `share/aws/lambda_function.rb` |
| H | CLI commands | 08 | `scout_commands/*` |
| I | Design philosophy | 09 | (cross-cutting) |

## Proposed documentation structure

### User documentation (`doc/user/`)

These are concept-oriented guides. Each answers: what problem does this solve, when do I use it, how do I use it, common mistakes.

| File | Concept | Covers subsystems | Source investigation |
|------|---------|--------------------|-----------------------|
| `ProvisioningInfrastructure.md` | How to define and generate Terraform configuration using the Ruby DSL | A | 01, 03 |
| `ManagingDeployments.md` | How to deploy, inspect, and destroy infrastructure using the deployment lifecycle | B | 02, 08 |
| `RemoteExecution.md` | How to run Scout workflow steps on remote servers via SSH | D | 04 |
| `CloudStorage.md` | How to use S3-backed paths for transparent cloud storage | E | 05 |
| `ServerlessWorkflows.md` | How to run Scout workflows on AWS Lambda | G | 07 |
| `BuildingWebApps.md` | How to build web interfaces for workflows using Sinatra | F | 06 |
| `UsingCommands.md` | Reference for all CLI commands | H | 08 |

### Developer documentation (`doc/developer/`)

These are architectural documents explaining how subsystems are implemented and interact.

| File | Concept | Covers subsystems | Source investigation |
|------|---------|--------------------|-----------------------|
| `Architecture.md` | Overall architecture, module map, dependency diagram | All | 00, 09 |
| `DesignPrinciples.md` | Scout conventions in scout-camp, extension patterns | I | 09 |
| `TerraformDSLInternals.md` | How the DSL core works, config generation, output references | A | 01 |
| `DeploymentLifecycle.md` | How deployment wraps terraform CLI, state management, bundling | B | 02 |
| `RemoteExecutionInternals.md` | How Offsite extends Step, SSH transport, path synchronization | D | 04 |
| `WebFrameworkInternals.md` | Sinatra extension composition, render engine, step serving | F | 06 |
| `StorageAbstractions.md` | S3 hooks, path integration, resource sync | E | 05 |

### Improvements (`doc/Improvements.md`)

Consolidates all issues from investigations `01`-`09`.

## Gap analysis

### Gaps found
1. **No tests for Offsite, S3, Lambda, or Sinatra subsystems.** Only TerraformDSL has tests. This is a significant gap.
2. **No documentation of path_map configuration.** S3 and offsite rely on `Path.path_maps` configuration but this is not documented.
3. **No documentation of module template format.** The `share/terraform/` templates follow a convention (main.tf, variables.tf, output.tf) but this convention is not documented.
4. **The `scout_commands/offsite` and `scout_commands/sync` commands are minimal stubs.** They need further investigation.
5. **The `scout_commands/find` and `scout_commands/glob` commands.** These appear to be remote file search commands but need investigation.
6. **The `scout_commands/terraform/add/relay` command.** This adds an ollama relay server. Needs documentation.

### Overlaps found
1. **CLI commands** (08) overlap with **Deployment management** (02) for terraform commands. Resolution: user docs cover usage, deployment docs cover lifecycle concept.
2. **S3 integration** (05) overlaps with **Offsite** (04) for Resource sync. Resolution: separate user docs, cross-reference in developer docs.
3. **Design philosophy** (09) overlaps with all other investigations for conventions. Resolution: extract conventions to DesignPrinciples.md, reference from other docs.

## Mapping priorities

Writing order based on dependency (foundational concepts first):

1. `doc/user/ProvisioningInfrastructure.md` — core DSL usage (foundational)
2. `doc/user/ManagingDeployments.md` — deployment lifecycle (depends on #1)
3. `doc/user/RemoteExecution.md` — offsite execution
4. `doc/user/CloudStorage.md` — S3 paths
5. `doc/user/ServerlessWorkflows.md` — Lambda (depends on #4)
6. `doc/user/BuildingWebApps.md` — Sinatra (depends on workflow understanding)
7. `doc/user/UsingCommands.md` — CLI reference
8. `doc/developer/Architecture.md` — overview
9. `doc/developer/DesignPrinciples.md` — conventions
10. `doc/developer/TerraformDSLInternals.md` — DSL internals
11. `doc/developer/DeploymentLifecycle.md` — deployment internals
12. `doc/developer/RemoteExecutionInternals.md` — offsite internals
13. `doc/developer/WebFrameworkInternals.md` — Sinatra internals
14. `doc/developer/StorageAbstractions.md` — S3 internals
15. `doc/StartHere.md` — routing page
16. `doc/Improvements.md` — improvements advisory

## scout-essentials cross-references

The following scout-essentials concepts should be linked from scout-camp docs:

| Concept | scout-essentials user doc URL |
|---------|-------------------------------|
| Path | `https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/WorkingWithFiles.md` |
| Open (file I/O) | `https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/WorkingWithFiles.md` |
| Persist (caching) | `https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/CachingResults.md` |
| Resource (file discovery) | `https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/ProducingResources.md` |
| CMD (command execution) | `https://github.com/m3kisvaz/scout-essentials/blob/main/doc/user/RunningCommands.md` |
| Log | `https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/LoggingAndProgress.md` |
| TmpFile | `https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/WorkingWithFiles.md` |
| SOPT (CLI options) | `https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/CommandLineOptions.md` |
| IndiferentHash | `https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/AnnotatingData.md` |
| Annotation | `https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/AnnotatingData.md` |
| ConcurrentStream | `https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/HandlingStreams.md` |

## Design principles doc URL

`https://github.com/mikisvaz/scout-essentials/blob/main/doc/developer/DesignPrinciples.md`

## Acceptance criteria check

Before considering documentation complete, verify:

1. ✓ All 9 investigation artifacts exist in `research/`
2. ✓ User docs use concept-oriented names (no class-by-class docs)
3. ✓ User docs have no implementation internals
4. ✓ Developer docs link to research artifacts
5. ✓ StartHere.md routes by audience
6. ✓ Old `doc/terraform.md` removed
7. ✓ All cross-references resolve
8. ✓ scout-essentials concepts linked, not re-explained
9. ✓ All docs have introductions answering What/Who/Why
10. ✓ User docs include code examples verified against source
