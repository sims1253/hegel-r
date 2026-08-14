# hegelr 0.1.0

First release: property-based testing for R, powered by the native Hegel
engine (libhegel) and modeled on the official Hegel bindings.

### Added

- Runtime loading of the native libhegel engine (never linked at install
  time): `hegel_library_path()`, `hegel_version()`,
  `hegel_library_available()`, and `hegel_install()` to download the
  published engine with sha256 verification; `HEGEL_LIBHEGEL_PATH`
  supports local builds. The engine version is gated: libhegel 0.32.x is
  required (hard error on older or major.minor-incompatible engines,
  once-per-process warning on patch drift).
- `hegel_test()`: the property runner. Engine-driven generation,
  integrated shrinking, and the persistent example database (disabled
  automatically in CI, like the other bindings). Settings mirror the
  official bindings: `test_cases`, `seed`, `derandomize`, `database`,
  `verbosity`, `phases`, `single_test_case`, `suppress_health_checks`,
  and `report_multiple_failures`.
- Test cases support `tc$draw()`, `tc$assume()`, `tc$note()`, and
  `tc$target()`. Failures raise `hegelr_failure` conditions carrying the
  minimal counterexample's draws, the property's own error message, a
  reproduce hint, and `blobs`/`draws`/`notes` fields; failures are
  grouped by call site, like the official bindings.
- `hegel_reproduce()` replays a stored failure blob; stale blobs raise
  `hegelr_stale_blob` errors.
- Composable `g_*` generators: `g_integers()`, `g_doubles()`,
  `g_logicals()`, `g_raw()`, `g_text()`, `g_characters()` (single
  codepoint), `g_from_regex()`, `g_emails()`, `g_urls()`, `g_domains()`,
  `g_vectors()`, `g_lists()`, `g_tuple()`, `g_one_of()`,
  `g_sampled_from()`, `g_just()`, `g_map()`, and `g_filter()`.
- testthat integration: properties are plain R closures usable inside
  `test_that()` with `stop()`, `stopifnot()`, or testthat expectations.
