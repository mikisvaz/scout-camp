# Rendering and Sinatra integration investigation

> **Non-normative.** This is an architectural investigation, not maintained documentation. It may become outdated as the codebase evolves. Refer to `doc/developer/Architecture.md` for the authoritative summary.

## Overview

scout-camp provides two web-oriented subsystems:

1. **ScoutRender** (`lib/scout/render/`) — A template rendering engine that wraps `Tilt` and integrates with Scout's `Step` caching. Supports Slim, ERB, and Haml templates found via the `Resource` system.

2. **Sinatra extensions** (`lib/scout/sinatra/`) — A collection of Sinatra modules that add Scout-aware features to web applications: parameter handling, asset management, workflow integration, entity rendering, fragments, HTMX support, authentication, and more.

---

## ScoutRender (`lib/scout/render/`, 3 files)

### Files

- `resource.rb` (35 lines) — Extends `Resource`, sets `subdir = 'share/views'`. Template files are searched under `share/views/`.
- `helpers.rb` (110 lines) — HTML helper methods: `escape_html`, `hash_to_html_tag_attributes`, `html_tag`, URL manipulation (`add_GET_param`, `remove_GET_param`, `add_GET_params`), template dependency tracking (`add_checks`, `outdated?`).
- `engine.rb` (130 lines) — The rendering engine using `Tilt`.

### Rendering pipeline

#### `ScoutRender.render(template_file, params, &block)`

Lowest level. Uses `Tilt.new(template_file).render(exec_context, params)` to render any template format. The `exec_context` is where template helpers are evaluated.

If only a block is given (no template), the block is called directly with params.

#### `ScoutRender.render_step(template_file, options, &block)`

Wraps rendering in a Scout `Step` for caching. The rendered output is persisted to disk and reused on subsequent requests. Key design:

1. Extracts `:persist` options from the options hash.
2. Computes a persistence path using `Persist.persistence_path`.
3. Creates a `Step` with the template rendering as its block.
4. The Step is extended with `ScoutRenderHelpers` so the template context has access to HTML helpers.

#### `ScoutRender.render_template(template, options, &block)`

High-level API. This is the main entry point for rendering. It:

1. Finds the template file via `ScoutRender.find_resource` (searches `share/views/`).
2. If `cache: false`, renders directly.
3. If `cache: true` (default), creates a cached `Step` via `render_step`.
4. Handles cache invalidation based on `update` option and template dependency checks.
5. Runs the Step if `run: true` (default).

#### `ScoutRender.render_partial(template, options)`

Alias for `render_template`. Used for partial templates.

### Template resolution

```ruby
ScoutRender.find_resource('users/show', extension: %w[slim erb haml])
# Searches for:
#   share/views/users/show.slim
#   share/views/users/show.erb
#   share/views/users/show.haml
```

### Template dependency tracking

The `add_checks` method records template dependencies so that when a dependency changes, the cached output is invalidated. This is used in the `outdated?` check.

### Helper methods

The `ScoutRenderHelpers` module is mixed into the Step's execution context. It provides:
- `html_tag(tag, content, params)` — Generate HTML tags.
- `hash_to_html_tag_attributes(hash)` — Convert a hash to HTML attributes.
- `add_GET_param(url, param, value)` / `remove_GET_param(url, param)` — URL manipulation for building links.
- `log(...)` — Delegate to the Step's log.
- `add_checks(checks)` — Track template dependencies for cache invalidation.
- `outdated?` — Check if cached output is outdated based on dependencies.

---

## Sinatra extensions (`lib/scout/sinatra/`, 14 files)

All Sinatra extensions follow the `registered(app)` pattern:

```ruby
module SinatraScoutSomething
  def self.registered(app)
    app.helpers do ... end
    app.before do ... end
    app.get '/path' do ... end
  end
end
```

### Base extensions (`lib/scout/sinatra/base/`)

These are composed together in `base.rb`:

#### `base/helpers.rb` — `format_name`

Formats a job name (e.g., `Process:data:a1b2c3`) into styled HTML showing the clean name and hash separately.

#### `base/parameters.rb` — Common parameter handling

Registers a `common_parameters` list and a `consume_parameter` helper. Common parameters are universal across all routes. Parameters are parsed from `params`, JSON body, or route params with type coercion.

Registered common parameters include: `page`, `size`, `_format`, `_text`, `_fragment`, `_partial`, `_layout`, `_no_layout`, `_debug_js`, `_debug_css`, `_step`, `_`.

#### `base/post_processing.rb` — Post-processing pipeline

Allows registration of post-processing blocks that run after the main route handler. Used by fragments to extract and process a specific part of the rendered output.

#### `base/headers.rb` — Request headers and URL helpers

Provides `environment`, `production?`, `add_GET_params`, `fullpath`, `script_name`.

#### `base/assets.rb` — JS/CSS asset management

Manages recording and rendering of JS and CSS files. Provides:
- `reset_js_css` — Clear recorded assets.
- `record_js(path)`, `record_css(path)` — Record asset dependencies.
- `render_js`, `render_css` — Output `<script>` and `<link>` tags.
- Asset serving from `share/views/public/`.

#### `base/session.rb` — Session and preferences

Configures Sinatra sessions with a secret from `Scout::Config`. Provides:
- User preference storage (`record_preference`, `current_preference`).
- Preference toggling via URL parameters.

#### `base/favicon.rb` — SVG favicon

Serves an SVG favicon at `/favicon.ico`.

### Feature extensions

#### `knowledge_base.rb` — Knowledge Base integration

Sets up a default `KnowledgeBase` instance accessible via the `knowledge_base` helper.

#### `workflow.rb` — Workflow integration

Provides REST endpoints for workflow tasks. The core route is:

```ruby
app.get '/:task_name/:jobname' do
  wf = settings.workflow
  job = wf.job(task_name, jobname, clean_params)
  # produce and render the job
end
```

Supports job listing, status checking, cleaning, and production.

#### `entity.rb` — Entity rendering

Renders entities from the knowledge base with support for multiple formats (HTML, JSON). Registers common parameters for entity properties and formatting.

#### `fragment.rb` — Fragment extraction

Registers the `_fragment` parameter. When set, post-processing extracts a specific fragment from the rendered output using CSS selector. This is used for HTMX-style partial updates.

#### `htmx.rb` — HTMX response headers

Sets `HX-Trigger` headers for HTMX client-side event triggers based on response status.

#### `tool.rb` — Reusable UI tools

Provides a `tool(name, params)` helper that renders a reusable UI component from a template, optionally loading JS and CSS assets.

#### `auth.rb` — Authentication

Integrates `OmniAuth` with Google OAuth2. Manages user sessions, preferences, and login/logout.

#### `finder.rb` — Finder stub

A placeholder module with a `finder` helper that returns nil. Likely a future extension point.

---

## Integration architecture

The typical Sinatra app using scout-camp would register all relevant modules:

```ruby
class MyApp < Sinatra::Base
  register SinatraScoutHelpers       # base, parameters, assets, session, etc.
  register SinatraScoutWorkflow      # workflow REST endpoints
  register SinatraScoutKnowledgeBase # KB access
  register SinatraScoutEntity        # entity rendering
  register SinatraScoutHTMX          # HTMX headers
  register SinatraScoutAuth          # OAuth if needed
end
```

### Request flow

1. **Parameters**: `consume_parameter` extracts and type-coerces common parameters.
2. **Route handler**: Produces content (possibly a workflow job).
3. **Post-processing**: Runs registered post-processing blocks (e.g., fragment extraction).
4. **Assets**: JS/CSS dependencies recorded during rendering are included in the response.
5. **HTMX headers**: `HX-Trigger` headers set based on response status.

---

## Design patterns

### Step-based caching for templates

Template rendering is wrapped in a `Step`, leveraging Scout's entire caching and dependency tracking infrastructure. Template outputs are persisted and reused. This is the Scout way: `render_template` is just another `Step` computation.

### Composition via Sinatra registration

Each feature is a separate `registered(app)` module. Applications compose them by registering only what they need. This avoids monolithic framework coupling.

### Resource-based template discovery

Templates are discovered via the `Resource` system (`ScoutRender.find_resource`), meaning templates can live in gems, local directories, or remote resources. This is consistent with how Scout finds all other assets.

### Fragment extraction for partial updates

The `_fragment` parameter combined with post-processing enables HTMX-style partial page updates without a separate API. The server renders the full page, then extracts just the requested fragment.

## Issues and observations

1. **`parameters.rb` is complex** (140 lines): The parameter type coercion and default value logic is dense. Consider simplifying the type system.

2. **No CSRF protection**: The Sinatra extensions don't include CSRF protection. This would need to be added by the application.

3. **Session secret default**: The session secret defaults to `"scout_<something>"` if not configured. This should be a hard error in production.

4. **`finder.rb` is a stub**: The `finder` helper returns nil. This is either a placeholder or dead code.

5. **Render step naming**: `render_step` uses `Persist.persistence_path` for caching, which may produce long hash-based names. The `step_name` option allows custom names.

6. **Template cache invalidation**: The `add_checks` mechanism tracks file dependencies, but the invalidation logic in `render_template` has multiple branches that are hard to follow.

7. **Fragment implementation complexity**: The fragment extraction uses a custom HTML parsing approach that may not handle all edge cases (e.g., nested fragments).

8. **No streaming support**: Template rendering is synchronous. For large pages or long-running workflow jobs, there's no streaming or SSE support.

## Cross-references

- S3 integration: see `05_s3_integration.md`
- Design philosophy: see `09_design_philosophy.md`
- scout-essentials Resource: https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/ProducingResources.md
- scout-essentials Persist: https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/CachingResults.md
