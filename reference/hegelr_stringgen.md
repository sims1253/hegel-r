# Get-or-create a cached string generator

String generators are immutable and shareable, so they are created once
per schema and cached in `hegelr_env` for the process lifetime.
`schema_key` is a deparse digest of the schema; `builder` is a closure
`function(ctx)` calling the appropriate `hegelr_string_generator_*`
constructor - the context it receives is the dedicated cache context,
never a run context.

## Usage

``` r
hegelr_stringgen(schema_key, builder)
```

## Arguments

- schema_key:

  Character string uniquely identifying the schema.

- builder:

  Closure `function(ctx)` constructing the sg extptr.

## Value

An external pointer to a `hegel_string_generator` handle.
