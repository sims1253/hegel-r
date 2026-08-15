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
#> <bytecode: 0x55ae288cb038>
#> <environment: 0x55ae288caba0>
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
