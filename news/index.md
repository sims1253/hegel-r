# Changelog

## hegelr 0.1.0

First release: property-based testing for R, powered by the native Hegel
engine (libhegel) and modeled on the official Hegel bindings.

#### Added

- Runtime loading of the native libhegel engine (never linked at install
  time):
  [`hegel_library_path()`](https://sims1253.github.io/hegel-r/reference/hegel_library_path.md),
  [`hegel_version()`](https://sims1253.github.io/hegel-r/reference/hegel_version.md),
  [`hegel_library_available()`](https://sims1253.github.io/hegel-r/reference/hegel_library_available.md),
  and
  [`hegel_install()`](https://sims1253.github.io/hegel-r/reference/hegel_install.md)
  to download the published engine with sha256 verification;
  `HEGEL_LIBHEGEL_PATH` supports local builds. The engine version is
  gated: libhegel 0.32.x is required (hard error on older or
  major.minor-incompatible engines, once-per-process warning on patch
  drift).
- [`hegel_test()`](https://sims1253.github.io/hegel-r/reference/hegel_test.md):
  the property runner. Engine-driven generation, integrated shrinking,
  and the persistent example database (disabled automatically in CI,
  like the other bindings). Settings mirror the official bindings:
  `test_cases`, `seed`, `derandomize`, `database`, `verbosity`,
  `phases`, `single_test_case`, `suppress_health_checks`, and
  `report_multiple_failures`.
- Test cases support `tc$draw()`, `tc$assume()`, `tc$note()`, and
  `tc$target()`. Failures raise `hegelr_failure` conditions carrying the
  minimal counterexample’s draws, the property’s own error message, a
  reproduce hint, and `blobs`/`draws`/`notes` fields; failures are
  grouped by call site, like the official bindings.
- [`hegel_reproduce()`](https://sims1253.github.io/hegel-r/reference/hegel_reproduce.md)
  replays a stored failure blob; stale blobs raise `hegelr_stale_blob`
  errors.
- Composable `g_*` generators:
  [`g_integers()`](https://sims1253.github.io/hegel-r/reference/g_integers.md),
  [`g_doubles()`](https://sims1253.github.io/hegel-r/reference/g_doubles.md),
  [`g_logicals()`](https://sims1253.github.io/hegel-r/reference/g_logicals.md),
  [`g_raw()`](https://sims1253.github.io/hegel-r/reference/g_raw.md),
  [`g_text()`](https://sims1253.github.io/hegel-r/reference/g_text.md),
  [`g_characters()`](https://sims1253.github.io/hegel-r/reference/g_characters.md)
  (single codepoint),
  [`g_from_regex()`](https://sims1253.github.io/hegel-r/reference/g_from_regex.md),
  [`g_emails()`](https://sims1253.github.io/hegel-r/reference/g_emails.md),
  [`g_urls()`](https://sims1253.github.io/hegel-r/reference/g_urls.md),
  [`g_domains()`](https://sims1253.github.io/hegel-r/reference/g_domains.md),
  [`g_vectors()`](https://sims1253.github.io/hegel-r/reference/g_vectors.md),
  [`g_lists()`](https://sims1253.github.io/hegel-r/reference/g_lists.md),
  [`g_tuple()`](https://sims1253.github.io/hegel-r/reference/g_tuple.md),
  [`g_one_of()`](https://sims1253.github.io/hegel-r/reference/g_one_of.md),
  [`g_sampled_from()`](https://sims1253.github.io/hegel-r/reference/g_sampled_from.md),
  [`g_just()`](https://sims1253.github.io/hegel-r/reference/g_just.md),
  [`g_map()`](https://sims1253.github.io/hegel-r/reference/g_map.md),
  and
  [`g_filter()`](https://sims1253.github.io/hegel-r/reference/g_filter.md).
- testthat integration: properties are plain R closures usable inside
  [`test_that()`](https://testthat.r-lib.org/reference/test_that.html)
  with [`stop()`](https://rdrr.io/r/base/stop.html),
  [`stopifnot()`](https://rdrr.io/r/base/stopifnot.html), or testthat
  expectations.
