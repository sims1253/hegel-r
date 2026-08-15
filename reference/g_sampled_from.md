# Generate one of a fixed set of values

Draws an index with `generate_integer` inside a SAMPLED_FROM span and
returns the corresponding element of the atomic vector `values`.

## Usage

``` r
g_sampled_from(values)
```

## Arguments

- values:

  An atomic vector with at least one element.

## Value

A generator descriptor (class `hegelr_generator`) drawing one element of
`values` per case.

## Examples

``` r
g_sampled_from(c("alpha", "beta", "gamma"))
#> $draw
#> function (tc) 
#> {
#>     hegelr_start_span(tc$context, tc$handle, HEGEL_LABEL_SAMPLED_FROM)
#>     idx <- hegelr_stop_for_status(hegelr_generate_integer(tc$context, 
#>         tc$handle, 0, n - 1))
#>     value <- values[[idx + 1L]]
#>     hegelr_stop_span(tc$context, tc$handle, FALSE)
#>     value
#> }
#> <bytecode: 0x55ae2765a388>
#> <environment: 0x55ae27657a90>
#> 
#> $label
#> [1] "g_sampled_from(c(\"alpha\", \"beta\", \"gamma\"))"
#> 
#> $empty
#> character(0)
#> 
#> attr(,"class")
#> [1] "hegelr_generator"
```
