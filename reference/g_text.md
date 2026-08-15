# Generate text strings

Draws strings with a length in `[min_size, max_size]` (unbounded above
by default, per the family's
[`text()`](https://rdrr.io/r/graphics/text.html)) from codepoints in
`[min_codepoint, max_codepoint]`, optionally restricted to (or
excluding) Unicode categories and character sets. Backed by the engine's
text string generator.

`alphabet` is sugar for `include_characters`: a string whose characters
form the allowed set. Pass either `alphabet` or `include_characters`,
not both.

## Usage

``` r
g_text(
  min_size = 0,
  max_size = Inf,
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

- min_size:

  Minimum string length (whole number `>= 0`).

- max_size:

  Maximum string length (whole number `>= 0`, or `Inf` for unbounded -
  the default).

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

A generator descriptor (class `hegelr_generator`) drawing one character
string per case.

## Examples

``` r
g_text(max_size = 8)
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
#> <bytecode: 0x560435283d98>
#> <environment: 0x5604343d7160>
#> 
#> $label
#> [1] "g_text(min_size = 0, max_size = 8)"
#> 
#> $empty
#> character(0)
#> 
#> attr(,"class")
#> [1] "hegelr_generator"
g_text(alphabet = "abc")
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
#> <bytecode: 0x560435283d98>
#> <environment: 0x56043442fef0>
#> 
#> $label
#> [1] "g_text(min_size = 0, max_size = Inf)"
#> 
#> $empty
#> character(0)
#> 
#> attr(,"class")
#> [1] "hegelr_generator"
```
