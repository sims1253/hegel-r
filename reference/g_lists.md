# Generate lists

Like
[`g_vectors()`](https://sims1253.github.io/hegel-r/reference/g_vectors.md)
but returns a plain [`list()`](https://rdrr.io/r/base/list.html), so
elements may be of any type (including nested generators' outputs of
differing kinds). Uses the same LIST span and collection session
protocol.

## Usage

``` r
g_lists(gen, min_size = 0, max_size = Inf)
```

## Arguments

- gen:

  Element generator (built by a `g_*()` function).

- min_size:

  Minimum length (whole number `>= 0`).

- max_size:

  Maximum length (whole number, or `Inf` for unbounded).

## Value

A generator descriptor (class `hegelr_generator`).

## Examples

``` r
g_lists(g_logicals(), max_size = 5)
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
#>     out
#> }
#> <bytecode: 0x55ae285efd08>
#> <environment: 0x55ae285f7710>
#> 
#> $label
#> [1] "g_lists(gen = g_logicals(), max_size = 5)"
#> 
#> $empty
#> list()
#> 
#> attr(,"class")
#> [1] "hegelr_generator"
```
