# Generate logicals

Draws `TRUE`/`FALSE` values, with `TRUE` probability `p`, backed by the
engine's `generate_boolean` primitive.

## Usage

``` r
g_logicals(p = 0.5)
```

## Arguments

- p:

  Probability of drawing `TRUE`; a single number in `[0, 1]`.

## Value

A generator descriptor (class `hegelr_generator`) drawing one logical
value per case.

## Examples

``` r
gen <- g_logicals(p = 0.25)
gen$label
#> [1] "g_logicals(p = 0.25)"
```
