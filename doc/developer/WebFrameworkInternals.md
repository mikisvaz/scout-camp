# Web Framework Internals

This document explains how scout-camp's web framework works internally: the rendering engine, Sinatra extension composition, parameter handling, fragment rendering, and asset management. It is intended for framework contributors.

## ScoutRender: template rendering engine

### Rendering pipeline

```
render_template(name, options)
       │
       ├─ find_resource(name)  →  locate template via Resource
       │
       ├─ cache: false?  ──→  render directly via Tilt
       │
       └─ cache: true   ──→  render_step(template_file, options)
                                │
                                ├─ Create Step with rendering as block
                                ├─ Step extended with ScoutRenderHelpers
                                ├─ Handle cache invalidation (update option)
                                └─ Run Step if requested
```

Three levels of rendering:
1. `ScoutRender.render` — Lowest level, uses `Tilt.new(template_file).render(context, params)`
2. `ScoutRender.render_step` — Wraps rendering in a `Step` for caching
3. `ScoutRender.render_template` — High-level API with template lookup and cache invalidation

### Template discovery

Templates are found via the `Resource` system under `share/views/`. Multiple extensions are tried in order: `slim`, `haml`, `erb`.

```ruby
ScoutRender.find_resource('entity/MutatedIsoform', extension: %w[slim erb haml])
# Searches share/views/entity/MutatedIsoform.slim, .erb, .haml
```

### Template dependency tracking

The `add_checks` method records file dependencies during rendering. The `outdated?` method checks if the cached output is stale based on these dependencies.

### Step-based caching

Template rendering is wrapped in a `Step`, leveraging Scout's caching infrastructure. Rendered output is persisted and reused on subsequent requests. Cache invalidation depends on the `update` option and dependency checks.

## Sinatra extensions

### Composition model

Each feature is a self-contained module with `self.registered(app)`:

```ruby
module SinatraScoutWorkflow
  def self.registered(app)
    app.helpers do ... end
    app.get '/:task_name/:jobname' do ... end
  end
end
```

### Extension registry

| Extension | Module | Purpose |
|-----------|--------|---------|
| Base | `SinatraScoutBase` | Core: format negotiation, step serving, assets, session, parameters |
| Workflow | `SinatraScoutWorkflow` | Job listing, reports, task info, job files |
| Entity | `SinatraScoutEntity` | Entity reports, actions, properties, entity lists |
| Knowledge Base | `SinatraScoutKnowledgeBase` | Registry/relationship browsing |
| Fragment | `SinatraScoutFragment` | Fragment extraction for partial updates |
| HTMX | `SinatraScoutHTMX` | `HX-Trigger` response headers |
| Auth | `SinatraScoutAuth` | OmniAuth Google OAuth2 |
| Tool | `SinatraScoutTool` | Tool-serving for agent-facing apps |

### Parameter handling

`SinatraScoutParameters` provides a common parameter system:
- `register_common_parameter(name, type, default)` — Register a parameter with type coercion
- `consume_parameter(name)` — Extract a parameter from the request
- `clean_params` — Filter and process parameters (removes internal params, handles file uploads)
- `process_common_parameters` — Called in the `before` hook

Common parameters: `_format`, `_layout`, `_update`, `_cache_type`, `splat`, `_step`, `_`.

### Step serving

The base extension provides `serve_step`, `serve_step_info`, `serve_step_json`, `serve_step_raw` for handling workflow jobs:

```
GET /:workflow/:task/:jobname            → HTML report
GET /:workflow/:task/:jobname?_format=json  → JSON job info
GET /:workflow/:task/:jobname?_format=raw   → Raw file download
GET /:workflow/:task/:jobname?_format=info  → Step info
```

### Fragment rendering

The `_fragment` parameter combined with post-processing enables partial page updates:
1. During rendering, the `fragment` helper spawns a child process to compute a fragment
2. The response includes a placeholder link
3. On subsequent requests, the client requests the fragment by its code
4. The post-processing pipeline intercepts and serves the fragment content

### Asset management

JS and CSS dependencies are recorded during rendering and included in the response:
- `record_js(path)`, `record_css(path)` — Record dependencies
- `render_js`, `render_css` — Output `<script>` and `<link>` tags

### Authentication

`SinatraScoutAuth` integrates OmniAuth with Google OAuth2:
- Login flow at `/auth/login`
- Callback at `/auth/:provider/callback`
- Logout at `/auth/logout`
- Session-based user info
- User preferences stored per-user

## Request flow

```
1. before hook:
   - Parse JSON body if POST
   - process_common_parameters
   - Set CORS headers

2. Route handler:
   - Create/load job
   - render_template → Step (cached)
   - initiate_step → run/serve

3. serve_step:
   - done → halt with rendered content
   - error → halt with error
   - running → halt 202 with wait template

4. after hook:
   - Set SCOUT_RENDER_STEP header
   - Handle _update == :reload redirect
```

## Known issues

See [Improvements](../Improvements.md) for CSRF protection, session secret default, and stub `finder.rb`.

## Related

- [Architecture](Architecture.md) — How this fits into the overall system
- [Design Principles](DesignPrinciples.md) — Sinatra composition convention
- [research/rendering-and-sinatra-analysis.md](../../research/06_rendering_and_sinatra.md) — Deep investigation
