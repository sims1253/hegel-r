# hegelr — architecture and interface contract

`hegelr` is the R member of the [Hegel](https://hegel.dev) family of
property-based testing libraries. It drives the native **libhegel**
engine (the Rust core from `hegeldev/hegel-rust`, exposed as a C-ABI
shared library: `libhegel.so` / `libhegel.dylib` / `hegel.dll`) and
wraps it in an idiomatic, testthat-friendly R API.

Sister packages for reference (cloned locally during development):
`hegel-go`, `hegel-typescript`, `hegel-rust` (contains `hegel-c`, the C
ABI).

## 1. Design principles

1.  **Zero hard runtime dependencies.** `Imports:` is empty. Everything
    is base R. `Suggests:` only (testthat, jsonlite). This matches the
    hegel-x family, where the only “dependency” is the native engine.
2.  **The engine is loaded at runtime, never linked at install time.**
    The package’s compiled shim (`src/`) has no external link
    dependencies. It `dlopen()`s / `LoadLibraryW()`s libhegel on first
    use. Users get the engine via
    [`hegel_install()`](https://sims1253.github.io/hegel-r/reference/hegel_install.md)
    (downloads the published artifact) or point `HEGEL_LIBHEGEL_PATH` at
    a local build.
3.  **One source of truth for the ABI.** Every C symbol the shim
    resolves is declared in `src/hegel_abi.h` as a function pointer in a
    single table. Adding engine features means adding a typedef + table
    entry + wrapper.
4.  **Idiomatic R surface.** Property bodies are ordinary R closures
    using [`stop()`](https://rdrr.io/r/base/stop.html) /
    [`stopifnot()`](https://rdrr.io/r/base/stopifnot.html) / testthat
    expectations for failure and `tc$assume()` for preconditions.
    Generators are composable descriptor objects drawn via
    `tc$draw(gen)`.

## 2. Data flow

    test_that("...", {                       tests/testthat/*.R (user code)
      hegel_test(function(tc) { ... })       R/runner.R — run loop
      })                                       |
                                              | .Call on registered C wrappers
                                         src/hegel_wrappers.c  (SEXP <-> C)
                                              |  function-pointer table
                                         src/hegel_loader.c   (dlopen/dlsym)
                                              |
                                         libhegel.{so,dylib,dll}  (engine:
                                           generation, shrinking, database)

- The engine decides *how many* test cases to run and *what choices*
  each one makes (including during shrinking). The R layer only executes
  the property body per test case and reports the outcome back.
- Shrinking re-executes the property body with different choice
  sequences, so the body must be deterministic given `tc`, and all
  randomness must come from `tc$draw()`.

## 3. Engine library resolution (R side, `R/libhegel.R`)

[`hegel_library_path()`](https://sims1253.github.io/hegel-r/reference/hegel_library_path.md)
resolves in this order, caching the result:

1.  `Sys.getenv("HEGEL_LIBHEGEL_PATH")` — used directly if the file
    exists.
2.  `tools::R_user_dir("hegelr", "cache")/libhegel/<version>/` — pick
    the highest version directory (sortable), looking for `libhegel.so`,
    `libhegel.dylib`, or `hegel.dll` inside (recursive `list.files`).
3.  Standard system locations on Unix-alikes: `/usr/local/lib`,
    `/usr/lib`, `/opt/homebrew/lib`, `/usr/local/homebrew/lib`.
4.  Bare library name (lets the OS loader search `PATH` / system dirs,
    notably Windows `LoadLibrary` semantics).

[`hegel_load()`](https://sims1253.github.io/hegel-r/reference/hegel_load.md)
(idempotent, called by every public entry point) loads the resolved path
through `C_hegelr_load` and records the engine version.
`hegel_install(version = "latest")` downloads the matching asset from
`https://github.com/hegeldev/hegel-rust/releases` into the cache dir.
Releases publish **bare library files** (`libhegel-windows-amd64.dll`,
`libhegel-linux-amd64.so`, `libhegel-darwin-arm64.dylib`, …) each with a
`.sha256` sidecar — no archives. The installer picks the platform asset
(arch from `R.version$arch`;
[`Sys.info()`](https://rdrr.io/r/base/Sys.info.html)’s “machine”
hyphenates `x86-64`), downloads it directly under its canonical name
(`hegel.dll`, `libhegel.dylib`, `libhegel.so`), verifies the sidecar
checksum when
[`tools::sha256sum()`](https://rdrr.io/r/tools/sha256sum.html) exists (R
\>= 4.5, skipped with a message otherwise), and writes the
`installed.rds` marker. Suggests jsonlite for the GitHub API response;
clear error listing available asset names if no platform match.
[`hegel_library_available()`](https://sims1253.github.io/hegel-r/reference/hegel_library_available.md)
returns TRUE/FALSE without signaling.

Constants: `LIBHEGEL_MIN_VERSION <- "0.32.0"` (error if older),
`LIBHEGEL_PINNED_VERSION <- "0.32.5"` (warning if different; the ABI
this scaffold was written against).

## 4. C shim contract (`src/`)

All wrappers follow these rules:

- Registered via `init.c` `R_registerRoutines` +
  `R_useDynamicSymbols(., FALSE)` with **exact arities** given below.
  roxygen: `@useDynLib hegelr, .registration = TRUE`.
- Handles (`context`, `settings`, `run`, `test_case`, `run_result`,
  `failure`, `collection`, `string_generator`) are R external pointers.
  Every non-context handle extptr carries attribute `"context"` = the
  owning context extptr so GC can never free a context before its
  dependents. Finalizers call the matching `*_free`.
- **Draw primitives return `list(value = <SEXP>, status = <int>)`**
  where `status` is `0` = OK, `-1` = `HEGEL_E_STOP_TEST`, `-2` =
  `HEGEL_E_ASSUME`. The R layer turns `-1`/`-2` into conditions (see
  §5). All other error codes raise an R error immediately via
  `Rf_error`, message from `hegel_context_last_error(ctx)`.
- All other fallible wrappers raise R errors directly on failure and
  return values otherwise.
- Integers cross the boundary as R doubles, validated as whole numbers
  with `|x| <= 2^53`. Labels and sizes likewise pass as doubles
  (u64-safe subset).

Wrapper list (name — SEXP signature — return):

| wrapper | signature | returns |
|----|----|----|
| `C_hegelr_load` | (path_str) | `TRUE` (invisible); error if load/symbol resolution fails, message names missing symbols |
| `C_hegelr_is_loaded` | () | logical |
| `C_hegelr_version` | () | character(1), uses a temporary context |
| `C_hegelr_context_new` | () | ctx extptr (finalizer: `hegel_context_free`) |
| `C_hegelr_settings_new` | (ctx) | settings extptr |
| `C_hegelr_settings_set_test_cases` | (ctx, s, n_dbl) | invisible TRUE |
| `C_hegelr_settings_set_seed` | (ctx, s, seed_dbl, has_lgl) | invisible TRUE |
| `C_hegelr_settings_set_derandomize` | (ctx, s, lgl) | invisible TRUE |
| `C_hegelr_settings_set_verbosity` | (ctx, s, int 0..3) | invisible TRUE |
| `C_hegelr_settings_set_database` | (ctx, s, path_str_or_NULL) | invisible TRUE (`NULL` -\> engine default `./.hegel/examples/`, `""` disables) |
| `C_hegelr_settings_set_database_key` | (ctx, s, key_str_or_NULL) | invisible TRUE |
| `C_hegelr_settings_set_mode` | (ctx, s, mode_int 0=test run, 1=single test case) | invisible TRUE |
| `C_hegelr_settings_set_phases` | (ctx, s, mask_dbl 0..31) | invisible TRUE |
| `C_hegelr_settings_set_suppress_health_check` | (ctx, s, mask_dbl 0..15) | invisible TRUE |
| `C_hegelr_settings_set_report_multiple_failures` | (ctx, s, lgl) | invisible TRUE |
| `C_hegelr_run_start` | (ctx, s) | run extptr; output callback routes engine lines to `Rprintf` |
| `C_hegelr_next_test_case` | (ctx, run) | tc extptr, or `NULL` when the run is finished |
| `C_hegelr_mark_complete` | (ctx, tc, status_int, origin_str) | invisible TRUE |
| `C_hegelr_target` | (ctx, tc, value_dbl, label_str_or_NULL) | invisible TRUE |
| `C_hegelr_run_result` | (ctx, run) | result extptr |
| `C_hegelr_run_result_status` | (ctx, result) | int: 0 passed, 1 failed, 2 error |
| `C_hegelr_run_result_error` | (ctx, result) | string or NULL |
| `C_hegelr_run_result_failure_count` | (ctx, result) | int |
| `C_hegelr_run_result_failure` | (ctx, result, i0_dbl) | failure extptr |
| `C_hegelr_failure_origin` | (ctx, failure) | string |
| `C_hegelr_failure_blob` | (ctx, failure) | string or NULL |
| `C_hegelr_test_case_from_blob` | (ctx, s, blob) | tc extptr |
| `C_hegelr_start_span` | (ctx, tc, label_dbl) | invisible TRUE |
| `C_hegelr_stop_span` | (ctx, tc, discard_lgl) | invisible TRUE |
| `C_hegelr_new_collection` | (ctx, tc, min_dbl, max_dbl) | collection extptr |
| `C_hegelr_collection_more` | (ctx, tc, coll) | `list(value=lgl, status=int)` |
| `C_hegelr_collection_reject` | (ctx, tc, coll, why_or_NULL) | invisible TRUE |
| `C_hegelr_generate_boolean` | (ctx, tc, p_dbl) | `list(value=lgl, status)` |
| `C_hegelr_generate_integer` | (ctx, tc, min_dbl, max_dbl) | `list(value=dbl, status)` |
| `C_hegelr_generate_float` | (ctx, tc, min, max, allow_nan_lgl, allow_inf_lgl, excl_min_lgl, excl_max_lgl, smallest_nonzero_dbl) | `list(value=dbl, status)` (width fixed at 64) |
| `C_hegelr_generate_bytes` | (ctx, tc, min_dbl, max_dbl) | `list(value=raw, status)` |
| `C_hegelr_string_generator_text` | (ctx, min_dbl, max_dbl, codec_or_NULL, min_cp_dbl, max_cp_dbl, categories_chr_or_NULL, exclude_categories_chr_or_NULL, include_characters_or_NULL, exclude_characters_or_NULL) | sg extptr |
| `C_hegelr_string_generator_regex` | (ctx, pattern, fullmatch_lgl) | sg extptr |
| `C_hegelr_string_generator_email` | (ctx) | sg extptr |
| `C_hegelr_string_generator_url` | (ctx) | sg extptr |
| `C_hegelr_string_generator_domain` | (ctx, max_length_dbl) | sg extptr |
| `C_hegelr_generate_string` | (ctx, sg, tc) | `list(value=chr, status)` |

String results may contain interior NULs (the engine warns about
U+0000); the wrapper truncates at the first NUL for R (documented
caveat). All strings are marked UTF-8 (`Rf_mkCharLenCE` with `CE_UTF8`).

String generators are immutable and shareable: the R side caches them
per schema for the process lifetime (like hegel-typescript) in
`hegelr_env$stringgen_cache`, key = `digest`-style
`paste(deparse(schema), collapse="")`. Their finalizers use a dedicated
process-lifetime “cache context”
([`hegelr_cache_context()`](https://sims1253.github.io/hegel-r/reference/hegelr_cache_context.md)
in `R/bindings.R`), never a run context.

Engine `hegel_output_callback_t`: a C trampoline writing via `Rprintf`
(user_data unused). Passed to `hegel_run_start` and
`hegel_test_case_from_blob`.

## 5. R layer semantics

### Conditions

| class | raised when | meaning |
|----|----|----|
| `hegelr_stop_test` | a draw returns status `-1` | engine budget exhausted; abort body; case counts as OVERRUN (2) |
| `hegelr_assume` | a draw returns status `-2`, or `tc$assume(FALSE)` | case counts as INVALID (1) |
| `error` or `expectation_failure` caught by runner | body fails | case counts as INTERESTING (3); origin = condition message + first call |

Status integers passed to `C_hegelr_mark_complete`: VALID = 0, INVALID =
1, OVERRUN = 2, INTERESTING = 3 (mirrors `hegel_status_t`).

### Engine behavior worth knowing: the all-simplest pre-trial

The first test case a run generates is a deterministic probe where
**every draw returns the simplest value in its range** (`shrink_towards`
— default 0 — clamped into the bounds; see
`NativeTestCase::for_simplest` in hegel-c’s `core/state.rs`).
`g_integers(5, 10)` draws all 5s,
[`g_logicals()`](https://sims1253.github.io/hegel-r/reference/g_logicals.md)
draws all `FALSE`,
[`g_vectors()`](https://sims1253.github.io/hegel-r/reference/g_vectors.md)
draws the minimum size. Random sampling begins with the second test
case. Consequences: a `test_cases = 1` run only ever sees minimal
values; tests asserting value diversity must draw per test case over
several cases, not many times inside one case.

### Run loop (`R/runner.R`, `hegel_test`)

    ctx <- context; settings from args (test_cases, seed, derandomize,
           verbosity, database); run <- run_start
    repeat {
      tc <- next_test_case(run); if (is.null(tc)) break
      drive body with tryCatch(hegelr_stop_test -> OVERRUN,
                               hegelr_assume -> INVALID,
                               error/expectation_failure -> INTERESTING + origin)
      mark_complete(tc, status, origin); free tc
    }
    result <- run_result(run)
    if FAILED: for each failure -> replay blob for draw report, then signal
               failure (class `hegelr_failure`, inherits `error`)
    if ERROR: stop with run_result_error message

[`hegel_test()`](https://sims1253.github.io/hegel-r/reference/hegel_test.md)
defaults: `test_cases = 100`, `seed = NULL`, `derandomize = NULL` (defer
to the engine, which derandomizes in CI), `database = TRUE` (per-user
cache dir locally, disabled in CI; see section 9), `verbosity = NULL`
(engine default; \>= 2 shows each case’s draws and notes, 0 quiets the
failure report to the failing call site). Parity arguments mirroring the
official bindings (Rust `Settings` / Go `With...` options):
`phases = NULL` (character subset of explicit/reuse/generate/
target/shrink), `single_test_case = FALSE` (Go `WithSingleTestCase()` —
exactly one generated case, draws and notes shown),
`suppress_health_checks = NULL` (character subset of filter_too_much/
too_slow/test_cases_too_large/large_initial_test_case),
`report_multiple_failures = FALSE`. The database key is derived from the
property and is not a public argument, as in every family binding. On
success: invisible TRUE.

**Failure reports follow the family**: numbered draw lines
(`draw_N <- value`, the TS/Rust assignment shape; full values, no
truncation), the property’s own error message as the body, no
synthesized headers; multiple failures get Rust’s
`Property-based test failed with N distinct failures.` headline. The
reproduce hint is printed only when the engine produced a blob (an R
affordance: no attribute macro exists to auto-reproduce). Origins are
location-based (first non-hegelr stack frame at failure time, via a
calling handler — the analog of Go’s findCaller/Rust’s panic location),
so failures group by call site, not message. Errors raised by the shim
itself (message prefixed `C_hegelr_`) abort the run instead of becoming
counterexamples, matching Rust’s InvalidArgument/InternalError handling.

### Failure report

On failure, re-run the blob test case once with draw reporting enabled
(`tc` records numbered `draw_N <- <value>` lines and `tc$note()`
messages), then signal a `hegelr_failure` condition whose message is,
per failure (see the fuller spec earlier in this section):

      draw_1 <- c(0, 0)
    Reproduce with: hegel_reproduce("<blob>", property)
    <the property's own error message>

Multiple failures are preceded by
`Property-based test failed with N distinct failures.`; the reproduce
line is omitted when the engine produced no blob (e.g. single-case
mode).

`hegel_reproduce(blob, property)`: replays one case via
`test_case_from_blob`; re-raises a `hegelr_failure` if the property
fails again; otherwise signals a `hegelr_stale_blob` error (Rust binding
semantics: the bug may be fixed or the blob stale).

### TestCase object (`R/test-case.R`)

Environment-based (no R6 dependency):
`new_test_case(tc_extptr, report = FALSE)`.

- `tc$draw(gen)` — dispatches on `gen$draw(tc)`; records draw lines when
  `report = TRUE`. The generator descriptor protocol: a list with class
  `"hegelr_generator"`, element `draw = function(tc) value`, element
  `label = "short name"` used in draw reports.
- `tc$assume(condition)` — FALSE signals `hegelr_assume`.
- `tc$note(msg)` — recorded, printed only on final replay / reproduce.

### Generators (`R/generators-*.R`)

Naming: `g_*` prefix. Generator descriptors carry `draw`, `label`, and
`empty` (a typed empty prototype of the produced type, used by
`g_vectors` for zero-length draws — R’s `x[[i]] <- NULL` deletes
entries, so a NULL empty silently corrupts callers’ collections; NULL
when the type is unknowable without a draw, e.g. `g_map`). Spans label
the compound structure for the shrinker (`hegel_label_t` values):
`g_vectors`/`g_lists` -\> LIST (1) around the whole collection;
`g_tuple` -\> TUPLE (7); `g_one_of` -\> ONE_OF (8); `g_filter` -\>
FILTER (12) with `stop_span(discard=TRUE)` + retry (cap 3 attempts, then
signal `hegelr_assume`); `g_map` -\> MAPPED (13); `g_sampled_from` -\>
SAMPLED_FROM (14).

| generator | produces | backed by |
|----|----|----|
| `g_integers(min = -2^53, max = 2^53)` | integer-ish double | `generate_integer` |
| `g_doubles(min = -Inf, max = Inf, allow_nan = TRUE, allow_infinity = TRUE, exclude_min = FALSE, exclude_max = FALSE, smallest_nonzero = 5e-324)` | double | `generate_float` |
| `g_logicals(p = 0.5)` | logical | `generate_boolean` |
| `g_raw(min_size = 0, max_size = Inf)` | raw vector (unbounded above, per the Go/TS `Binary` default) | `generate_bytes` |
| `g_text(min_size = 0, max_size = Inf, codec = "utf-8", min_codepoint = 0, max_codepoint = 2^32-1, categories = NULL, exclude_categories = NULL, include_characters = NULL, exclude_characters = NULL, alphabet = NULL)` | character(1) (the family [`text()`](https://rdrr.io/r/graphics/text.html); unbounded above by default) | `string_generator_text` |
| `g_characters(codec, min_codepoint, max_codepoint, categories, exclude_categories, include_characters, exclude_characters, alphabet)` | one codepoint (the family `characters()`: text fixed to length 1) | `string_generator_text` (sizes 1,1) |
| `g_from_regex(pattern, fullmatch = TRUE)` | character(1) | `string_generator_regex` |
| [`g_emails()`](https://sims1253.github.io/hegel-r/reference/g_emails.md), [`g_urls()`](https://sims1253.github.io/hegel-r/reference/g_urls.md), `g_domains(max_length = 255)` | character(1) | matching sg constructors |
| `g_vectors(gen, min_size = 0, max_size = Inf)` | atomic vector of `gen`’s type | LIST span + `new_collection` loop |
| `g_lists(gen, min_size = 0, max_size = Inf)` | list() | same |
| `g_tuple(...gens, .names = NULL)` | named/unnamed list | TUPLE span |
| `g_one_of(...gens)` | value of one gen | index draw + ONE_OF span |
| `g_sampled_from(values)` | one element of atomic `values` | index draw + SAMPLED_FROM span |
| `g_just(value)` | `value` as-is | no draws |
| `g_map(gen, f)` | `f(draw(gen))` | MAPPED span |
| `g_filter(gen, predicate)` | first draw satisfying `predicate` | FILTER span retry loop |

`g_characters(alphabet=)` composes `include_characters` from the
alphabet string (sugar for `include_characters`).

## 6. File ownership

    DESCRIPTION, NAMESPACE, LICENSE, .Rbuildignore, .gitignore, NEWS.md,
    README.md, .github/workflows/R-CMD-check.yaml,
    tests/testthat.R, tests/testthat/{helper-library.R, test-offline.R,
      test-generators.R, test-runner.R, test-reproduce.R}
        <- meta agent (with the architect)

    src/hegel_abi.h, src/hegel_loader.c, src/hegel_wrappers.c, src/init.c,
    src/Makevars, src/Makevars.win
        <- native agent

    R/hegelr-package.R, R/libhegel.R, R/bindings.R, R/test-case.R,
    R/generators-primitive.R, R/generators-text.R, R/generators-composite.R,
    R/runner.R, R/reproduce.R
        <- R-layer agent

## 7. Testing strategy

- **Offline (always run, no engine needed):** argument validation of
  every public function; generator descriptor construction;
  [`hegel_library_path()`](https://sims1253.github.io/hegel-r/reference/hegel_library_path.md)
  resolution logic with temp dirs and env var; failure-report
  formatting; `skip_if_no_libhegel()` helper itself.
- **Online (skip when the engine is absent; they run in CI with
  [`hegel_install()`](https://sims1253.github.io/hegel-r/reference/hegel_install.md)
  first):** draws produce in-range values; shrinking finds the minimal
  counterexample (the README sort example is the canonical integration
  test); `hegel_reproduce` round-trip; database replay.

## 8. Modern R standards checklist

- DESCRIPTION: `Authors@R`, `Encoding: UTF-8`,
  `Roxygen: list(markdown = TRUE)`, `RoxygenNote`,
  `Config/testthat/edition: 3`, `URL`/`BugReports`,
  `SystemRequirements: libhegel 0.32.x, loaded at runtime`.
- roxygen2 with
  `#' @title`/`@description`/`@param`/`@return`/`@examples` (examples
  guarded with `if (hegel_library_available())`), `@export`,
  `@useDynLib hegelr, .registration = TRUE`, `@importFrom` only for base
  packages if needed (none expected).
- testthat 3rd edition: `expect_error(..., class=)`,
  `capture_messages()` + [`grepl()`](https://rdrr.io/r/base/grep.html)
  for failure-report formatting, `local_tempdir()`-style patterns.
- Native routine registration, `R_useDynamicSymbols(FALSE)`.
- NEWS.md (Keep a Changelog style), MIT LICENSE, `.Rbuildignore`
  covering `ARCHITECTURE.md`, `AGENTS.md`, `^\.github$`, `*.md`
  handling.
- CI: `r-lib/actions` v2 `check-r-package` matrix (release + devel, 3
  OSes), with a setup step running
  `Rscript -e 'hegelr::hegel_install()'`.
- Code style: tidyverse-style, 2-space indent, no `T`/`F`, snake_case
  for functions, snake_case for arguments; C follows R-exts conventions
  (`Rinternals.h`, PROTECT discipline, `Rf_error` for programmer
  errors).

## 9. Deviations from the family (deliberate, R-specific)

Everything else mirrors hegel-rust / hegel-go / hegel-typescript, down
to naming (`test_cases`, phases, health checks,
`report_multiple_failures`), defaults (100 test cases, filter cap 3,
NaN/Inf conditional defaults, single-codepoint `characters`), and report
semantics (location-based origins, numbered draw lines, Rust’s
multi-failure headline, stale-blob errors, hard major.minor version
gate). These are the deviations that remain, each forced by R or CRAN:

1.  **Database location.** The family default is the engine’s
    `./.hegel/examples/`, which would write into the working directory
    during `R CMD check` (a CRAN policy violation and a “left-over
    files” NOTE). hegelr’s `database = TRUE` redirects to
    `tools::R_user_dir("hegelr", "cache")/examples/` while keeping the
    family’s CI behavior (disabled in CI). `NULL` passes the engine
    default through untouched.
2.  **`hegelr_failure` condition object.** Family bindings re-raise the
    original panic/error; R signals a condition carrying `blobs`,
    `draws`, `notes` fields with the original message as the body -
    conditions are R’s signaling mechanism and the fields are how tests
    extract blobs.
3.  **Reproduce hint printed when a blob exists.** Rust’s `print_blob`
    defaults to false and Go/TS never print one; hegelr always prints
    the
    [`hegel_reproduce()`](https://sims1253.github.io/hegel-r/reference/hegel_reproduce.md)
    line when the engine produced a blob because R has no attribute
    macro to auto-wire reproduction - the hint is the only discovery
    path for the feature.
4.  **Engine output via Rprintf.** The shim routes engine lines to R’s
    stdout unconditionally (Go swaps sinks between exploration and
    replay); an R package cannot leave output on C stderr cleanly.
5.  **Integer range ±2^53** (doubles only; matches the TS binding’s
    `MAX_SAFE_INTEGER` default) and **typed empty prototypes** for
    zero-length draws (R’s `x[[i]] <- NULL` deletes entries).
6.  **[`hegel_reproduce()`](https://sims1253.github.io/hegel-r/reference/hegel_reproduce.md)
    as a function** - the Rust-only `#[hegel::reproduce_failure]`
    attribute rendered as a runtime call.

Known gaps vs the family (roadmap, not deviations): sets/maps,
`optional`, `flat_map`, date/time/datetime/UUID/IP generators,
`bigIntegers` escape hatch, stateful testing (rules, pools,
`stateful_step_count`), backend selection, the `print_blob` knob, and
Rust’s `HEGEL_TEST_CASES`/`HEGEL_DATABASE` env overrides.
