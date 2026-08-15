# Load the libhegel engine

Loads the engine through the compiled shim, at the path resolved by
[`hegel_library_path()`](https://sims1253.github.io/hegel-r/reference/hegel_library_path.md),
and records the engine version. The call is idempotent: once the engine
is loaded (and has passed the version gate) later calls are no-ops.
Every public entry point
([`hegel_test()`](https://sims1253.github.io/hegel-r/reference/hegel_test.md),
[`hegel_version()`](https://sims1253.github.io/hegel-r/reference/hegel_version.md),
...) calls this automatically.

## Usage

``` r
hegel_load()
```

## Value

`TRUE`, invisibly.
