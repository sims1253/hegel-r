# Generate doubles

Draws doubles in `[min, max]`, backed by the engine's `generate_float`
primitive (64-bit width). `allow_nan` and `allow_infinity` default to
`NULL`, resolved per the family rule: NaN only when the range is
unbounded on both ends, infinities only when at least one end is
unbounded. (Go: "true when no bounds are set, false otherwise";
TypeScript: NaN when *neither* side is bounded, infinity when *either*
side is open.) Pass `TRUE`/`FALSE` to decide explicitly.

## Usage

``` r
g_doubles(
  min = -Inf,
  max = Inf,
  allow_nan = NULL,
  allow_infinity = NULL,
  exclude_min = FALSE,
  exclude_max = FALSE,
  smallest_nonzero = 4.94065645841247e-324
)
```

## Arguments

- min:

  Lower bound. Defaults to `-Inf`.

- max:

  Upper bound. Defaults to `Inf`.

- allow_nan:

  Whether NaN may be generated (`NULL` = family conditional default).

- allow_infinity:

  Whether infinite values may be generated (`NULL` = family conditional
  default).

- exclude_min:

  Exclude `min` itself from the range (finite `min` only).

- exclude_max:

  Exclude `max` itself from the range (finite `max` only).

- smallest_nonzero:

  Smallest nonzero magnitude the engine will produce; a positive finite
  number (default `5e-324`).

## Value

A generator descriptor (class `hegelr_generator`) drawing one double per
case.

## Examples

``` r
gen <- g_doubles(0, 1, smallest_nonzero = 1e-10)
gen$label
#> [1] "g_doubles(min = 0, max = 1)"
```
