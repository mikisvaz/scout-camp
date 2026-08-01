# Building Web Apps

This document explains how to build web interfaces for Scout workflows using Sinatra extensions. It is intended for workflow authors who need to serve workflow results, browse knowledge bases, or create interactive web dashboards.

## When to use this

Use the Sinatra web framework when you want to:

- Serve workflow results as web pages
- Browse knowledge bases interactively
- Build dashboards for monitoring jobs
- Create APIs for workflow results
- Add authentication or asset management to your application

## Core concepts

### Sinatra extension composition

scout-camp provides a set of Sinatra extensions. You compose them into your application by registering the ones you need:

```ruby
class MyApp < Sinatra::Base
  register SinatraScoutBase
  register SinatraScoutWorkflow
  register SinatraScoutEntity
end
```

Each extension adds routes, helpers, and configuration. You only register what you need.

### Render engine

The `ScoutRender` module provides template rendering using the Tilt template engine. Templates are discovered via Scout's `Resource` system, so they can live in gems, local directories, or shared resources.

### Template discovery

Templates are looked up by name, with fallback to a `Default` template:

1. Specific template: `entity/MutatedIsoform`
2. Fallback: `entity/Default`
```

This lets you define a default look for all entities and override specific types.

### Step serving

Workflow steps (jobs) can be served via HTTP. The server handles different formats (HTML, JSON, raw file) and different statuses (done, error, running):

```
GET /:workflow/:task/:jobname  →  HTML job report
GET /:workflow/:task/:jobname?_format=json  →  JSON job info
GET /:workflow/:task/:jobname?_format=job  →  Raw job file
```

## Building a web app

### Basic application

```ruby
require 'scout-camp'
require 'sinatra/base'

class MyApp < Sinatra::Base
  register SinatraScoutBase
  register SinatraScoutWorkflow

  set :workflow, MyWorkflow
end

MyApp.run!
```

This gives you:
- Job listing and reports at `/:workflow/:task/:jobname`
- Job files at `/:workflow/:task/:jobname?_format=job`
- JSON API at `/:workflow/:task/:jobname?_format=json`
- Multiple format support (HTML, JSON, raw)
- Asset management (CSS, JS)
- Session management
- Authentication hooks
- htmx integration

### Adding entity support

If your workflow produces annotated entities (using Scout's `Entity` system), register the entity extension:

```class MyApp < Sinatra::Base
  register SinatraScoutBase
  register SinatraScertWorkflow
  register SinatraScoutEntity
end
```

This adds:
- Entity reports at `/entity/:type/:id`
- Entity actions at `/entity_action/:type/:action/:id`
- Entity properties at `/entity/:type/:property/:id`
- Entity lists at `/entity_list/:type/:id`
- Template lookup with fallbacks

### Custom routes

Add custom routes alongside the registered extensions:

```ruby
class MyApp < Sinatra::Base
  register SinatraScoutBase
  register SinatraScoutWorkflow

  get '/dashboard' do
    jobs = MyWorkflow.jobs
    render_template('dashboard', jobs: jobs)
  end
end
```

### Templates

Templates are discovered via `Resource` and rendered with Tilt:

```ruby
render_template('entity/MutatedIsoform', entity: entity)
render_partial('entity/list_item', entity: entity)
```

Templates live in `share/views/` directories and are found via the Resource system:

```
share/views/
  entity/
    Default.erb
    MutatedIsoform.erb
  entity_list/
    Default.erb
  layout.erb
```

## Available extensions

| Extension | Purpose |
|-----------|---------|
| `SinatraScoutBase` | Core helpers: format negotiation, JSON/HTML halt, step serving, asset management, sessions, parameter handling, common parameter registration. |
| `SinatraScoutWorkflow` | Workflow routes: job listing, job reports, task info, job files. |
| `SinatraScoutEntity` | Entity routes: entity reports, actions, properties, entity lists. |
| `SinatraScoutKnowledgeBase` | Knowledge base routes: registries, relationships, interactions. |
| `SinatraScoutHtmx | htmx integration for partial updates and dynamic loading. |
| `SinatraScoutAuth` | Authentication: AWS Cognito integration, session management, token validation. |
| `SinatraScoutTool` | Tool-serving routes for agent-facing web apps. |
| `SinatraScoutFragment` | Fragment rendering for modular page composition. |

## Common patterns

### Multi-format responses

The server automatically responds in different formats based on the `_format` parameter:

```
GET /WF/T/job1                    → HTML report
GET /WF/T/job1?_format=json       → JSON with job info
GET /WF/T/job1?_format=job        → Raw file download
```

### Entity links and URLs

Use the helper methods to create links between entities:

```ruby
entity_link(entity)
# => <a href="/entity/Gene/BRCA1" class="entity_entity">BRCA1</a>

entity_url(entity, :action, :annotate)
# => "/entity_action/Gene/annotate/BRCA1"
```

### Knowledge base browser

Register the knowledge base extension to browse relationships:

```ruby
class MyApp < Sinatra::Base
  register SinatraScoutBase
  register SinatraScoutKnowledgeBase
end
```

This adds routes for browsing registries and relationships in the knowledge base.

## Common mistakes

### Not registering the base extension

`SinatraScoutBase` provides the helpers that other extensions depend on:

```ruby
# Wrong
class MyApp < Sinatra::Base
  register SinatraScoutWorkflow  # helpers not found
end

# Right
class MyApp < Sinatra::Base
  register SinatraScoutBase       # required first
  register SinatraScoutWorkflow
end
```

### Forgetting that templates use the Resource system

Templates are not found relative to your app file. They are found via the `Resource` system in `share/views/` directories:

```ruby
# Ensure your templates are discoverable
Resource.add_path_to_search my_templates_dir
```

### Using standard Sinatra helpers instead of Scout helpers

```ruby
# Wrong - standard Sinatra may not handle Scout's step serving
get '/job/:name' do
  step = MyWorkflow.job(:task, params[:name])
  step.load.to_s
end

# Right - use the built-in step serving helpers
# (automatically available via SinatraScoutWorkflow)
```

## Next steps

- scout-essentials [Producing Resources](https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/ProducingResources.md) — Resource discovery
- scout-essentials [Annotating Data](https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/AnnotatingData.md) — Entity annotation system
- scout-essentials [Caching Results](https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/CachingResults.md) — Step persistence
