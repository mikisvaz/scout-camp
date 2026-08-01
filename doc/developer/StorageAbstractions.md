# Storage Abstractions

This document explains how scout-camp integrates S3 cloud storage transparently into Scout's I/O layer. It is intended for framework contributors who need to extend storage support or understand the Hook-based extension mechanism.

## Purpose

The S3 integration allows any `s3://bucket/key/path` URI to work with Scout's standard file operations (Open, Path, Persist) without any code changes in consumers. This is achieved by monkey-patching `Open` and `Path` with S3-aware behavior using the `Hook` module.

## Hook module: transparent extension

The core mechanism is the `Hook` module from scout-essentials, which allows injecting behavior into existing classes without inheritance:

```ruby
module Open
  module S3
    extend Hook

    def self.claim_path(path)
      Open::S3.is_s3?(path)
    end

    # Override: check if path is S3, handle if so, else delegate
    def self.exists?(path, ...)
      if Open::S3.is_s3?(path)
        # S3-specific existence check
      else
        orig_exists?(path, ...)   # original method
      end
    end
  end
end

Hook.apply(Open::S3, Open)
```

`Hook.apply` aliases the original method to `orig_*` and installs the extension. When called, it checks if the S3 module should handle the path.

## S3 path format

Paths follow the pattern: `s3://<bucket>/<key>` where key is the remainder of the path.

```ruby
Open.exists?('s3://my-bucket/data/file.txt')   # → true/false
Path.setup('s3://my-bucket/data/file')          # S3-backed path
```

## Operations overridden

### Open (file I/O)

| Method | Behavior |
|--------|----------|
| `Open.exists?` | Checks S3 object existence |
| `Open.sread` | Reads S3 object as string |
| `Open.swrite` | Writes to S3 object |
| `Open.get_stream` | Returns streaming reader for S3 object |
| `Open.consume_stream` | Uploads a stream to S3 |
| `Open.mkdir` | No-op (S3 is flat namespace) |
| `Open.glob` | Lists objects matching pattern |
| `Open.cp` | Copies S3 object |
| `Open.mv` | Moves (copies then deletes) |
| `Open.lnk` | Not supported on S3 |
| `Open.ls` | Lists objects in bucket |
| `Open.list` | Returns prefixed listing |

### Path (path manipulation)

`Path::S3` extends `Path` to handle S3 URI prefixes. When a Path is S3-backed, `find`, `find_all`, `produce`, and other methods dispatch to S3 operations.

### Persist (caching)

Persist databases can be stored on S3. `Persist::OPEN_MUTEX` synchronizes access. Persistence is implemented by reading/writing the entire database to S3 on each operation.

## Configuration

S3 access uses environment variables or AWS config:

- `AWS_ACCESS_KEY_ID`
- `Aws.secret_access_key` (not standard; check Config.get)
- `ENV["AWS_REGION"]` or `~/.aws/config`

`Open::S3.client(bucket)` creates an `Aws::S3::Client` configured from the environment.

## Performance considerations

- **No partial reads/writes** — S3 objects are read/written in full
- **No directories** — `mkdir` is a no-op
- **No symlinks** — `lnk` raises `NotImplementedError`
- **Glob is prefix-based** — S3 `list_objects_v2` with prefix + delimiter
- **Persist downloads/uploads the full database each time** — not efficient for large caches

## Lambda integration

S3 is the primary storage backend when running workflows on AWS Lambda. The Lambda handler sets:

```ruby
Path.path_maps[:bucket] = "s3://#{ENV["AWS_BUCKET"]}/{TOPLEVEL}/{SUBPATH}"
Path.path_maps[:default] = :bucket
```

This redirects all Scout paths to S3.

## Known issues

See [Impro Nassau Issues](../Improvements.md) for S3 persistence performance, glob limitations, and AWS credentials handling.

## Related

- [Architecture](Architecture.md) — How this fits into the overall system
- [Design Principles](DesignPrinciples.md) — Hook-based extension pattern
- scout-essentials [Working with Files](https://github.com/mikisvaz/scout-essentials/blob/main/doc/user/WorkingWithFiles.md)
- [research/s3-integration-analysis.md](../../research/05_s3_integration.md) — Deep investigation
