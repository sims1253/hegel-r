# Generate email addresses

Draws syntactically valid email addresses via the engine's email string
generator.

## Usage

``` r
g_emails()
```

## Value

A generator descriptor (class `hegelr_generator`) drawing one character
string per case.

## Examples

``` r
g_emails()
#> $draw
#> function (tc) 
#> {
#>     sg <- hegelr_stringgen(key, function(ctx) {
#>         hegelr_string_generator_email(ctx)
#>     })
#>     hegelr_stop_for_status(hegelr_generate_string(tc$context, 
#>         sg, tc$handle))
#> }
#> <bytecode: 0x559a57e0d098>
#> <environment: 0x559a57e0fe98>
#> 
#> $label
#> [1] "g_emails()"
#> 
#> $empty
#> character(0)
#> 
#> attr(,"class")
#> [1] "hegelr_generator"
```
