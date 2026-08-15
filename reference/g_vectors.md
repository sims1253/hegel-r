# Generate atomic vectors

Draws an atomic vector whose elements come from `gen`; the engine
chooses the length through a collection session (`new_collection` /
`collection_more`) inside a LIST span. Elements are unified into an
atomic vector of the element type: doubles, logicals and characters via
[`c()`](https://rdrr.io/r/base/c.html); raw elements via
[`as.raw()`](https://rdrr.io/r/base/raw.html). An empty draw yields the
element generator's typed empty prototype when the type is knowable
without a draw (`numeric(0)` for
[`g_integers()`](https://sims1253.github.io/hegel-r/reference/g_integers.md),
`raw(0)` for
[`g_raw()`](https://sims1253.github.io/hegel-r/reference/g_raw.md),
...). Otherwise the result is `NULL` (e.g. under
[`g_map()`](https://sims1253.github.io/hegel-r/reference/g_map.md),
whose output type depends on the transform).

## Usage

``` r
g_vectors(gen, min_size = 0, max_size = Inf)
```

## Arguments

- gen:

  Element generator (built by a `g_*()` function).

- min_size:

  Minimum length (whole number `>= 0`).

- max_size:

  Maximum length (whole number, or `Inf` for unbounded). `Inf` is sent
  to the engine as the 2^53 "no bound" sentinel.

## Value

A generator descriptor (class `hegelr_generator`).

## Examples

``` r
g_vectors(g_integers(-100, 100), max_size = 20)
#> $draw
#> function (tc) 
#> {
#>     hegelr_start_span(tc$context, tc$handle, HEGEL_LABEL_LIST)
#>     coll <- hegelr_new_collection(tc$context, tc$handle, min_size, 
#>         max_bound)
#>     out <- list()
#>     repeat {
#>         more <- hegelr_stop_for_status(hegelr_collection_more(tc$context, 
#>             tc$handle, coll))
#>         if (!isTRUE(more)) {
#>             break
#>         }
#>         out[[length(out) + 1L]] <- gen$draw(tc)
#>     }
#>     hegelr_stop_span(tc$context, tc$handle, FALSE)
#>     if (!length(out)) {
#>         return(gen$empty %||% NULL)
#>     }
#>     if (is.raw(out[[1L]])) {
#>         as.raw(do.call(c, lapply(out, as.integer)))
#>     }
#>     else {
#>         do.call(c, out)
#>     }
#> }
#> <bytecode: 0x55f93416a748>
#> <environment: 0x55f93416e240>
#> 
#> $label
#> [1] "g_vectors(gen = g_integers(min = -100, max = 100), max_size = 20)"
#> 
#> $empty
#> numeric(0)
#> 
#> attr(,"class")
#> [1] "hegelr_generator"
```
