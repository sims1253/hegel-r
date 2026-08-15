# Generate raw byte vectors

Draws raw vectors with a length chosen by the engine in
`[min_size, max_size]`, backed by the engine's `generate_bytes`
primitive. `max_size = Inf` (the default) means unbounded, matching the
Go and TypeScript bindings' `Binary` defaults; the engine's own size
budget and health checks cap what is generated.

## Usage

``` r
g_raw(min_size = 0, max_size = Inf)
```

## Arguments

- min_size:

  Minimum length (whole number `>= 0`).

- max_size:

  Maximum length (whole number `>= 0`, or `Inf` for unbounded).

## Value

A generator descriptor (class `hegelr_generator`) drawing one raw vector
per case.

## Examples

``` r
gen <- g_raw(0, 16)
gen$label
#> [1] "g_raw(max_size = 16)"
```
