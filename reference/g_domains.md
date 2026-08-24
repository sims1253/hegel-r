# Generate domain names

Draws syntactically valid domain names of at most `max_length`
characters, via the engine's domain string generator.

## Usage

``` r
g_domains(max_length = 255)
```

## Arguments

- max_length:

  Maximum domain length (whole number `>= 1`). Defaults to 255.

## Value

A generator descriptor (class `hegelr_generator`) drawing one character
string per case.

## Examples

``` r
g_domains(max_length = 63)
#> $draw
#> function (tc) 
#> {
#>     sg <- hegelr_stringgen(key, function(ctx) {
#>         hegelr_string_generator_domain(ctx, max_length)
#>     })
#>     hegelr_stop_for_status(hegelr_generate_string(tc$context, 
#>         sg, tc$handle))
#> }
#> <bytecode: 0x559a57aba980>
#> <environment: 0x559a57abd828>
#> 
#> $label
#> [1] "g_domains(max_length = 63)"
#> 
#> $empty
#> character(0)
#> 
#> attr(,"class")
#> [1] "hegelr_generator"
```
