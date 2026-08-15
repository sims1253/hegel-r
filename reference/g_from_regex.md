# Generate strings matching a regular expression

Draws strings matching `pattern`, via the engine's regex string
generator.

## Usage

``` r
g_from_regex(pattern, fullmatch = TRUE)
```

## Arguments

- pattern:

  A single regular expression string.

- fullmatch:

  When `TRUE` (the default) the whole string must match; otherwise a
  partial match suffices.

## Value

A generator descriptor (class `hegelr_generator`) drawing one character
string per case.

## Examples

``` r
g_from_regex("[a-z]{3,8}")
#> $draw
#> function (tc) 
#> {
#>     sg <- hegelr_stringgen(key, function(ctx) {
#>         hegelr_string_generator_regex(ctx, pattern, fullmatch)
#>     })
#>     hegelr_stop_for_status(hegelr_generate_string(tc$context, 
#>         sg, tc$handle))
#> }
#> <bytecode: 0x55ae28b2ab60>
#> <environment: 0x55ae28b2d8f0>
#> 
#> $label
#> [1] "g_from_regex(\"[a-z]{3,8}\")"
#> 
#> $empty
#> character(0)
#> 
#> attr(,"class")
#> [1] "hegelr_generator"
```
