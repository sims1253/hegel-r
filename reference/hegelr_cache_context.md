# Process-lifetime engine context for cached string generators

String-generator handles are cached for the whole process (see
[`hegelr_stringgen()`](https://sims1253.github.io/hegel-r/reference/hegelr_stringgen.md)),
so their extptr finalizers must never reference a run-scoped context
that might be collected first. This returns a single dedicated context,
created on first use and stored in `hegelr_env`.

## Usage

``` r
hegelr_cache_context()
```

## Value

An external pointer to a `hegel_context`, created once per process.
