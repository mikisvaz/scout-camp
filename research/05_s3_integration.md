# S3 integration investigation

> **Non-normative.** This is an architectural investigation, not maintained documentation. It may become outdated as the codebase evolves. Refer to `doc/CRITICAL_PATHS.md` for the authoritative summary.

## Overview

The S3 integration (`lib/scout/aws/s3.rb`, 344 lines) makes S3 paths (`s3://bucket/key`) work transparently with Scout's `Open` and `Path` abstractions. It uses the `aws-sdk-s3` gem for the S3 API and Scout's `Hook` module to inject S3-aware behavior.

## Architecture

### The Hook pattern

Scout-essentials provides a `Hook` module (in `scout/misc/hook`) that allows modules to override methods on existing classes by aliasing the original method and substituting their own. The pattern is:

```ruby
module MyExtension
  def my_method
    if should_handle?
      # custom behavior
    else
      orig_my_method  # fall back to original
    end
  end
end

Hook.apply(MyExtension, TargetClass)
```

`Hook.apply` takes the extension module and applies it to the target class, renaming the original `my_method` to `orig_my_method` and installing the extension.

In scout-camp:

```ruby
Hook.apply(Open::S3, Open)    # S3-aware Open operations
Hook.apply(Path::S3, Path)    # S3-aware Path operations
```

### `Open::S3` module

Provides S3-aware versions of all core `Open` operations:

| Method | S3 Behavior |
|--------|-------------|
| `claim_uri(uri)` | Returns true if URI starts with `s3://` |
| `get_stream(uri)` | Streams object content from S3 |
| `write(uri, content)` | Uploads content to S3 |
| `exists?(uri)` | Checks file or directory existence in S3 |
| `file_exists?(uri)` | Checks object existence via HEAD |
| `directory?(uri)` | Checks if prefix has objects (S3 has no real directories) |
| `size(uri)` | Returns object content length |
| `rm(uri)` | Deletes a single object |
| `rm_rf(uri)` | Deletes all objects under a prefix (batched 1000 at a time) |
| `cp(source, target)` | S3-to-S3 copy, S3-to-local, or local-to-S3 |
| `mv(source, target)` | Copy then delete source |
| `glob(uri, pattern)` | Lists objects and matches against pattern |
| `sync(source, target)` | Uses `aws s3 sync` CLI for directory sync |
| `touch(uri)` | Copy-to-self or write empty content |
| `mkdir(path)` | No-op (S3 has no directories) |
| `link/ln/ln_s` | Implemented as copy (S3 has no links) |
| `sensible_write` | Delegates to `Open::S3.write` |
| `lock` | No-op lock (just yields) |

### `Path::S3` module

| Method | S3 Behavior |
|--------|-------------|
| `located?` | Returns true if path is an S3 URI |
| `glob(*args)` | Uses `Open::S3.glob` if path resolves to S3 |

### URI parsing

```ruby
Open::S3.parse_s3_uri("s3://my-bucket/path/to/file.txt")
# => ["my-bucket", "path/to/file.txt"]
```

Strips the `s3://` prefix, splits on first `/`, bucket is the first component, key is the rest.

### Glob implementation

S3 has no native glob support. The implementation:
1. Lists all objects under the prefix using `list_objects_v2` (paginated).
2. For each object key, strips the prefix to get the relative path.
3. Matches the relative path against the glob pattern using `File.fnmatch?` with `File::FNM_PATHNAME`.
4. Also matches intermediate directory names.

### Sync implementation

Uses the `aws s3 sync` CLI command (not the SDK) for directory synchronization. Supports:
- `--exclude` patterns.
- `--files-from` for selective sync.
- `--delete` to remove source after sync.
- Dry-run mode (`-nv`).

## Lambda integration

The `share/aws/lambda_function.rb` file is an AWS Lambda handler that:
1. Sets `Path.path_maps[:bucket]` to use an S3 bucket as the default path map.
2. Requires a workflow module from a resource (e.g., `scout/lambda`).
3. Receives an event with a job path.
4. Produces the job, handling the async Lambda pattern with `TryAgain` retry.

This makes Scout workflows runnable as Lambda functions, with S3 as the persistent storage backend.

## Design patterns

### Hook-based monkey-patching

The `Hook.apply` pattern is the Scout way to extend core classes without inheritance. It's clean and reversible — the extension is a module that can be applied or not.

### Transparent S3 support

Because `Open` and `Path` are the central I/O abstractions in Scout, making them S3-aware means all higher-level abstractions (Workflow, Step, Persist, Resource) work transparently with S3.

### S3 directory abstraction

S3 has no real directories — only keys with prefixes. The `directory?` method checks if any objects share the prefix. The `glob` method works by listing all objects under a prefix and filtering.

## Issues and observations

1. **`puts` in `size` method**: Lines 113 and 116 use `puts` for error output instead of `Log.warn` or `Log.error`. This is inconsistent with the rest of the codebase.

2. **`touch` implementation**: `touch` copies the file to itself if it exists (to update timestamps), but S3 doesn't have native timestamps that work this way. The `cp(uri, uri)` call may fail or be a no-op.

3. **`lock` is a no-op**: `Open::S3.lock` simply yields without any locking. This means concurrent writes to the same S3 key have no protection.

4. **No multipart upload**: `write` uses `put_object` with the full body. For large files, a multipart upload would be more efficient.

4. **`sensible_write` doesn't handle blocks**: The override doesn't accept or yield a block, unlike the original `Open.sensible_write`.

5. **`mkdir` is a no-op**: Expected for S3, but should be documented for users who expect directory creation.

6. **Glob performance**: `glob` lists all objects under a prefix and filters in Ruby. For buckets with millions of objects, this will be slow.

7. **`sync` uses CLI, not SDK**: `Open::S3.sync` shells out to `aws s3 sync`. This requires the AWS CLI to be installed, which is an additional dependency beyond the SDK.

8. **No streaming download in `get_stream`**: The current implementation reads the entire object into the pipe. The SDK supports streaming via block, but the pipe approach may buffer.

## Cross-references

- Offsite remote execution: see `04_offsite_remote_execution.md`
- Design philosophy: see `09_design_philosophy.md`
- scout-essentials Open: https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/WorkingWithFiles.md
- scout-essentials Path: https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/WorkingWithFiles.md
