# Start Here

This page helps you find the right documentation in scout-camp. Scout-camp extends the Scout ecosystem with five capabilities: infrastructure provisioning, remote execution, cloud storage, serverless workflows, and web serving.

## What is scout-camp?

scout-camp is a Scout ecosystem library that provides:

- A **Terraform DSL** for provisioning cloud infrastructure in Ruby
- **Remote execution** of Scout workflow steps on remote servers over SSH
- **S3 cloud storage** integration transparently in Scout's file I/O
- **AWS Lambda** support for running workflows serverlessly
- **Sinatra web framework** extensions for building Scout-powered web apps

## Which documentation do you need?

### I want to build things with scout-camp

Go to the [user documentation](user/).

**Start here:** [Provisioning Infrastructure](user/ProvisioningInfrastructure.md) — Learn the Terraform DSL

**Then explore:** [Managing Deployments](user/ManagingDeployments.md), [Remote Execution](user/RemoteExecution.md), [Cloud Storage](user/CloudStorage.md), [Serverless Workflows](user/ServerlessWorkflows.md), [Building Web Apps](user/BuildingWebApps.md)

### I want to understand how scout-camp works internally

Go to the [developer documentation](developer/).

**Start here:** [Architecture](developer/Architecture.md) — Overall map

**Then explore:** [Design Principles](developer/DesignPrinciples.md), [Terraform DSL Internals](developer/TerraformDSLInternals.md), [Deployment Lifecycle](developer/DeploymentLifecycle.md), [Remote Execution Internals](developer/RemoteExecutionInternals.md), [Web Framework Internals](developer/WebFrameworkInternals.md), [Storage Abstractions](developer/StorageAbstractions.md)

### I want to see detailed code investigations

Go to the [research directory](../research/). These are non-normative architectural analyses preserved from the documentation effort. They contain code walkthroughs, call graphs, and historical context. They may be outdated.

## Documentation structure

```
doc/
    StartHere.md                   ← You are here
    Improvements.md                ← Actionable code improvement recommendations
    user/                          ← How to use scout-camp
        ProvisioningInfrastructure.md
        ManagingDeployments.md
        RemoteExecution.md
        CloudStorage.md
        ServerlessWorkflows.md
        BuildingWebApps.md
        UsingCommands.md
    developer/                     ← How scout-camp works internally
        Architecture.md
        DesignPrinciples.md
        TerraformDSLInternals.md
        DeploymentLifecycle.md
        RemoteExecutionInternals.md
        WebFrameworkInternals.md
        StorageAbstractions.md
```

## Related Scout documentation

scout-camp builds on foundational Scout libraries. These concepts are documented in the scout-essentials repository:

- [scout-essentials StartHere](https://github.com/mikisvaz/scout-essentials/blob/main/doc/StartHere.md)
- [scout-essentials Working with Files](https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/WorkingWithFiles.md)
- [scout-essentials Producing Resources](https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/ProducingResources.md)
- [scout-essentials Caching Results](https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/CachingResults.md)
- [scout-essentials Design Principles](https://github.com/mikisvaz/scout-essentials/blob/main/doc/developer/DesignPrinciples.md)
- [scout-essentials Command Line Options](https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/CommandLineOptions.md)
- [scout-essentials Running Commands](https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/RunningCommands.md)
- [scout-essentials Logging and Progress](https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/LoggingAndProgress.md)
- [scout-essentials Handling Streams](https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/HandlingStreams.md)
- [scout-essentials Annotating Data](https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/AnnotatingData.md)
- [scout-essentials Annotation System](https://github.com/mikisvaz/scout-essentials/blob/main/doc/developer/AnnotationSystem.md)
