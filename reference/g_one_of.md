# Generate a choice among generators

Draws an index with `generate_integer` inside a ONE_OF span and
delegates to the corresponding generator, producing a value of one of
`...gens`' types.

## Usage

``` r
g_one_of(...)
```

## Arguments

- ...:

  Candidate generators (built by `g_*()` functions). At least one.

## Value

A generator descriptor (class `hegelr_generator`).

## Examples

``` r
g_one_of(g_integers(), g_text(max_size = 3))
#> $draw
#> function (tc) 
#> {
#>     hegelr_start_span(tc$context, tc$handle, HEGEL_LABEL_ONE_OF)
#>     idx <- hegelr_stop_for_status(hegelr_generate_integer(tc$context, 
#>         tc$handle, 0, n - 1))
#>     value <- gens[[idx + 1L]]$draw(tc)
#>     hegelr_stop_span(tc$context, tc$handle, FALSE)
#>     value
#> }
#> <bytecode: 0x55ae26de3ad8>
#> <environment: 0x55ae26de1370>
#> 
#> $label
#> [1] "g_one_of(g_integers(), g_text(min_size = 0, max_size = 3))"
#> 
#> $empty
#> NULL
#> 
#> attr(,"class")
#> [1] "hegelr_generator"
```
