# Generate integers

Draws integers in `[min, max]` (both inclusive). Values are returned as
R **doubles**: the ABI carries integers as doubles restricted to the
u64-safe subset (whole numbers with `|x| <= 2^53`). `g_integers()`
cannot produce or accept anything outside that range.

## Usage

``` r
g_integers(min = -2^53, max = 2^53)
```

## Arguments

- min:

  Lower bound (whole number, `>= -2^53`). Defaults to `-2^53`.

- max:

  Upper bound (whole number, `<= 2^53`). Defaults to `2^53`.

## Value

A generator descriptor (class `hegelr_generator`) drawing one numeric
value per
[`hegel_test()`](https://sims1253.github.io/hegel-r/reference/hegel_test.md)
case.

## Examples

``` r
# Building a generator needs no engine; gen$label previews the draw
# report.
gen <- g_integers(1, 10)
gen$label
#> [1] "g_integers(min = 1, max = 10)"
```
