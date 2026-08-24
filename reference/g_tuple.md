# Generate tuples

Draws each of `...gens` in order inside a TUPLE span, returning their
values as a list, optionally named via `.names`.

## Usage

``` r
g_tuple(..., .names = NULL)
```

## Arguments

- ...:

  Element generators (built by `g_*()` functions).

- .names:

  Optional character vector of element names, of the same length as the
  number of generators.

## Value

A generator descriptor (class `hegelr_generator`) drawing one (named)
list per case.

## Examples

``` r
g_tuple(g_integers(), g_text(max_size = 4), .names = c("n", "s"))
#> $draw
#> function (tc) 
#> {
#>     hegelr_start_span(tc$context, tc$handle, HEGEL_LABEL_TUPLE)
#>     out <- lapply(gens, function(g) g$draw(tc))
#>     hegelr_stop_span(tc$context, tc$handle, FALSE)
#>     if (!is.null(.names)) {
#>         names(out) <- .names
#>     }
#>     out
#> }
#> <bytecode: 0x559a56ff5a58>
#> <environment: 0x559a56ff7ef0>
#> 
#> $label
#> [1] "g_tuple(g_integers(), g_text(min_size = 0, max_size = 4))"
#> 
#> $empty
#> NULL
#> 
#> attr(,"class")
#> [1] "hegelr_generator"
```
