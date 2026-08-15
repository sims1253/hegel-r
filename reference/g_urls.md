# Generate URLs

Draws syntactically valid URLs via the engine's URL string generator.

## Usage

``` r
g_urls()
```

## Value

A generator descriptor (class `hegelr_generator`) drawing one character
string per case.

## Examples

``` r
g_urls()
#> $draw
#> function (tc) 
#> {
#>     sg <- hegelr_stringgen(key, function(ctx) {
#>         hegelr_string_generator_url(ctx)
#>     })
#>     hegelr_stop_for_status(hegelr_generate_string(tc$context, 
#>         sg, tc$handle))
#> }
#> <bytecode: 0x560434755118>
#> <environment: 0x560434754430>
#> 
#> $label
#> [1] "g_urls()"
#> 
#> $empty
#> character(0)
#> 
#> attr(,"class")
#> [1] "hegelr_generator"
```
