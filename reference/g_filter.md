# Filter a generator's output

Repeatedly draws from `gen` inside a FILTER span. When `predicate`
rejects a value the span is stopped with `discard = TRUE`, reverting the
engine's choices for that attempt, and the draw is retried. After 3
rejected attempts (the family cap, per the Rust and Go bindings), the
generator signals `hegelr_assume`, rejecting the test case (the case
counts as INVALID, exactly like `tc$assume(FALSE)`); the engine's
`filter_too_much` health check is the real guard against over-filtered
generators.

## Usage

``` r
g_filter(gen, predicate)
```

## Arguments

- gen:

  Inner generator (built by a `g_*()` function).

- predicate:

  Function returning `TRUE`/`FALSE` for acceptable values.

## Value

A generator descriptor (class `hegelr_generator`).

## Examples

``` r
g_filter(g_integers(0, 100), function(x) x %% 7 == 0)
#> $draw
#> function (tc) 
#> {
#>     for (attempt in seq_len(HEGELR_MAX_FILTER_ATTEMPTS)) {
#>         hegelr_start_span(tc$context, tc$handle, HEGEL_LABEL_FILTER)
#>         value <- gen$draw(tc)
#>         keep <- isTRUE(predicate(value))
#>         hegelr_stop_span(tc$context, tc$handle, !keep)
#>         if (keep) {
#>             return(value)
#>         }
#>     }
#>     stop(hegelr_condition("hegelr_assume", sprintf("g_filter rejected %d draws in a row; rejecting this test case", 
#>         HEGELR_MAX_FILTER_ATTEMPTS)))
#> }
#> <bytecode: 0x56043515c038>
#> <environment: 0x5604351b25a0>
#> 
#> $label
#> [1] "g_filter(g_integers(min = 0, max = 100), predicate)"
#> 
#> $empty
#> numeric(0)
#> 
#> attr(,"class")
#> [1] "hegelr_generator"
```
