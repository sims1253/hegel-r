# Run a property-based test

`hegel_test()` drives the Hegel engine for `property`, a plain R closure
taking one argument: the test case object `tc`. Inside the body:

- `tc$draw(gen)` draws a value from a generator
  ([`g_integers()`](https://sims1253.github.io/hegel-r/reference/g_integers.md),
  [`g_vectors()`](https://sims1253.github.io/hegel-r/reference/g_vectors.md),
  ...); all randomness must come from draws so the engine can shrink and
  replay.

- `tc$assume(cond)` rejects the current case when `cond` is not `TRUE`
  (the case is retried, not failed).

- `tc$note(msg)` records a message shown only in the failure report.

- `tc$target(value, label = NULL)` reports a targeting score for the
  engine's target phase, guiding generation toward larger scores.

- [`stop()`](https://rdrr.io/r/base/stop.html),
  [`stopifnot()`](https://rdrr.io/r/base/stopifnot.html) and testthat
  expectations fail the case.

Each case's outcome maps to an engine status: a body that returns
normally is VALID, `hegelr_assume` conditions are INVALID, budget
exhaustion is OVERRUN (the engine signals `hegelr_stop_test` when the
draw budget runs out), and any other error is INTERESTING - a
counterexample to shrink and report. This includes testthat expectation
failures, which inherit from `error`.

When the run fails, `hegel_test()` replays each shrunk counterexample
once with draw reporting, then signals a condition of class
`hegelr_failure` (inheriting from `error`). The message lists each
failure's draws as numbered assignment lines, an optional reproduce
hint, and the property's own error message; multiple failures get a
count headline:

    draw_1 <- c(0, 0)
    Reproduce with: hegel_reproduce("<blob>", property)
    identical(my_sort(x), sort(x)) is not TRUE

The condition carries `blobs`, `draws` and `notes` fields for
programmatic use. `verbosity = 0` reduces the report to the failing call
sites.

## Usage

``` r
hegel_test(
  property,
  test_cases = 100,
  seed = NULL,
  derandomize = NULL,
  database = TRUE,
  verbosity = NULL,
  phases = NULL,
  single_test_case = FALSE,
  suppress_health_checks = NULL,
  report_multiple_failures = FALSE
)
```

## Arguments

- property:

  A function taking a single argument (the test case).

- test_cases:

  Number of test cases to aim for (whole number `>= 1`). Defaults to
  100.

- seed:

  Optional fixed seed (whole number, `|seed| <= 2^53`), making the run
  deterministic; negative values wrap like a two's complement cast,
  matching the Go binding.

- derandomize:

  Use a fixed seed derived from the database key instead of a random
  one. `NULL` (the default) defers to the engine, which enables
  derandomization in CI environments; pass `TRUE`/`FALSE` to decide
  explicitly.

- database:

  `TRUE` (default): persist failing examples under
  `tools::R_user_dir("hegelr", "cache")/examples/`, a stable location
  (the engine's own default depends on the working directory); hegelr
  disables the database automatically in CI, like the other Hegel
  bindings. `FALSE`: disable the database. A directory path string: use
  that directory.

- verbosity:

  Engine verbosity, `NULL` (default) for the engine default, or a whole
  number in `0..3`. At `verbosity >= 2` each test case's draws and notes
  are shown as it runs; `verbosity = 0` (quiet) reduces the failure
  report to the failing call site.

- phases:

  Which engine phases to run: `NULL` (default) for all, or a character
  vector subset of `"explicit"`, `"reuse"`, `"generate"`, `"target"`,
  `"shrink"` (named per the official bindings' `Phase` enums). E.g.
  `phases = c("reuse", "generate")` disables shrinking;
  `phases = "generate"` runs only freshly generated examples.

- single_test_case:

  Run exactly one generated test case with no shrinking, replay, or
  example database (Go binding's `WithSingleTestCase()`, Rust's
  `Mode::SingleTestCase`). Useful for long-running workloads or bodies
  not safely re-runnable on the same inputs; draw and note output is
  shown for the case.

- suppress_health_checks:

  `NULL` (default) or a character vector of health checks to disable:
  `"filter_too_much"`, `"too_slow"`, `"test_cases_too_large"`,
  `"large_initial_test_case"`.

- report_multiple_failures:

  Keep generating after the first failure to surface additional distinct
  bugs (grouped by origin). Defaults to `FALSE` (stop at the first
  failure).

## Value

`TRUE`, invisibly, when the property holds. On failure or an
engine-level error, an error condition is signaled (class
`hegelr_failure` for falsified properties, `hegelr_run_error` for engine
errors).

## Examples

``` r
if (hegel_library_available()) {
  # Passing property: sorting is idempotent.
  hegel_test(function(tc) {
    xs <- tc$draw(g_vectors(g_integers(-100, 100), max_size = 20))
    stopifnot(identical(sort(xs), sort(sort(xs))))
  })

  # Failing property: the classic sort-with-dedup bug. Hegel shrinks it
  # to a minimal counterexample (two equal elements); the example
  # catches the failure and prints it.
  my_sort <- function(x) {
    out <- sort(x)
    out[!duplicated(out)] # silently drops duplicates: the bug
  }
  tryCatch(
    hegel_test(function(tc) {
      xs <- tc$draw(g_vectors(g_integers(-100, 100), max_size = 20))
      if (!identical(my_sort(xs), sort(xs))) {
        stop("my_sort() does not match base::sort()")
      }
    }),
    error = function(e) cat("caught:", conditionMessage(e), "\n")
  )
}
```
