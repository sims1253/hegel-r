# Transform a generator's output

Draws from `gen` inside a MAPPED span and returns `f(value)`. During
shrinking the whole span shrinks as one unit.

## Usage

``` r
g_map(gen, f)
```

## Arguments

- gen:

  Inner generator (built by a `g_*()` function).

- f:

  Function applied to each drawn value.

## Value

A generator descriptor (class `hegelr_generator`).

## Examples

``` r
g_map(g_integers(0, 9), function(x) x^2)
#> $draw
#> function (tc) 
#> {
#>     hegelr_start_span(tc$context, tc$handle, HEGEL_LABEL_MAPPED)
#>     value <- f(gen$draw(tc))
#>     hegelr_stop_span(tc$context, tc$handle, FALSE)
#>     value
#> }
#> <bytecode: 0x55f93420b958>
#> <environment: 0x55f9342109e8>
#> 
#> $label
#> [1] "g_map(g_integers(min = 0, max = 9), f)"
#> 
#> $empty
#> NULL
#> 
#> attr(,"class")
#> [1] "hegelr_generator"
```
