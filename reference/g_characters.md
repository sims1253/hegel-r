# Generate single characters

Draws a single character (one Unicode codepoint) per case - the family's
`characters()`: a text generator fixed to length 1. Constraint
parameters are identical to
[`g_text()`](https://sims1253.github.io/hegel-r/reference/g_text.md).

## Usage

``` r
g_characters(
  codec = "utf-8",
  min_codepoint = 0,
  max_codepoint = 2^32 - 1,
  categories = NULL,
  exclude_categories = NULL,
  include_characters = NULL,
  exclude_characters = NULL,
  alphabet = NULL
)
```

## Arguments

- codec:

  Encoding hint, `"utf-8"` by default, or `NULL` for the engine default.

- min_codepoint:

  Smallest allowed codepoint (default 0).

- max_codepoint:

  Largest allowed codepoint (default `2^32 - 1`).

- categories:

  Optional character vector of allowed Unicode categories.

- exclude_categories:

  Optional character vector of excluded Unicode categories.

- include_characters:

  Optional string of always-allowed characters.

- exclude_characters:

  Optional string of excluded characters.

- alphabet:

  Optional string of allowed characters; sugar for `include_characters`.

## Value

A generator descriptor (class `hegelr_generator`) drawing one
single-character string per case.

## Examples

``` r
g_characters(categories = c("Lu", "Ll"))
#> $draw
#> function (tc) 
#> {
#>     sg <- hegelr_stringgen(key, function(ctx) {
#>         hegelr_string_generator_text(ctx, min_size, max_size, 
#>             codec, min_codepoint, max_codepoint, categories, 
#>             exclude_categories, include_characters, exclude_characters)
#>     })
#>     hegelr_stop_for_status(hegelr_generate_string(tc$context, 
#>         sg, tc$handle))
#> }
#> <bytecode: 0x559a57987158>
#> <environment: 0x559a5798edd8>
#> 
#> $label
#> [1] "g_characters()"
#> 
#> $empty
#> character(0)
#> 
#> attr(,"class")
#> [1] "hegelr_generator"
```
