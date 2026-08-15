# Generate a constant

Always produces `value`; draws nothing from the engine.

## Usage

``` r
g_just(value)
```

## Arguments

- value:

  Any R object, returned as-is.

## Value

A generator descriptor (class `hegelr_generator`).

## Examples

``` r
g_just(42)
#> $draw
#> function (tc) 
#> value
#> <bytecode: 0x560434d16d60>
#> <environment: 0x560434d1a768>
#> 
#> $label
#> [1] "g_just(42)"
#> 
#> $empty
#> NULL
#> 
#> attr(,"class")
#> [1] "hegelr_generator"
```
