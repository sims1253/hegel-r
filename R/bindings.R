# Internal thin wrappers over the native shim. --------------------------------
#
# These mirror, one-to-one, the wrapper table in section 4 of
# ARCHITECTURE.md: for every registered `C_hegelr_*` symbol there is
# exactly one `hegelr_*` function below with the same short name, a bare
# `.Call()`, and no logic of its own. Argument validation, status-code
# translation, span bookkeeping and handle lifetime all live in the R
# layer above these wrappers (test-case.R, generators-*.R, runner.R,
# reproduce.R). None of these are exported.
#
# Naming warning: `hegelr_load(path)` (below) is the raw `.Call` on
# `C_hegelr_load`; the public, idempotent loader with path resolution and
# the version gate is `hegel_load()` in libhegel.R. Not the same function.
#
# Draw/collection wrappers return `list(value = <SEXP>, status = <int>)`
# untouched; status 0 = OK, -1 = HEGEL_E_STOP_TEST, -2 = HEGEL_E_ASSUME.
# All other fallible wrappers raise R errors directly from C.

# --- engine --------------------------------------------------------------

# (path_str) -> TRUE; errors (with the missing symbol names) if the library
# cannot be loaded or any ABI symbol fails to resolve.
hegelr_load <- function(path) .Call(C_hegelr_load, path)

# () -> logical
hegelr_is_loaded <- function() .Call(C_hegelr_is_loaded)

# () -> character(1); uses a temporary context, safe right after hegelr_load().
hegelr_version <- function() .Call(C_hegelr_version)

# --- context / settings ----------------------------------------------------

# () -> ctx extptr (finalizer: hegel_context_free)
hegelr_context_new <- function() .Call(C_hegelr_context_new)

# (ctx) -> settings extptr
hegelr_settings_new <- function(ctx) .Call(C_hegelr_settings_new, ctx)

# (ctx, s, n_dbl) -> invisible TRUE
hegelr_settings_set_test_cases <- function(ctx, s, n) {
  .Call(C_hegelr_settings_set_test_cases, ctx, s, n)
}

# (ctx, s, seed_dbl, has_lgl) -> invisible TRUE
hegelr_settings_set_seed <- function(ctx, s, seed, has) {
  .Call(C_hegelr_settings_set_seed, ctx, s, seed, has)
}

# (ctx, s, lgl) -> invisible TRUE
hegelr_settings_set_derandomize <- function(ctx, s, value) {
  .Call(C_hegelr_settings_set_derandomize, ctx, s, value)
}

# (ctx, s, int 0..3) -> invisible TRUE
hegelr_settings_set_verbosity <- function(ctx, s, value) {
  .Call(C_hegelr_settings_set_verbosity, ctx, s, value)
}

# (ctx, s, path_str_or_NULL) -> invisible TRUE; NULL = engine default
# (./.hegel/examples/), "" disables the database.
hegelr_settings_set_database <- function(ctx, s, path) {
  .Call(C_hegelr_settings_set_database, ctx, s, path)
}

# (ctx, s, key_str_or_NULL) -> invisible TRUE
hegelr_settings_set_database_key <- function(ctx, s, key) {
  .Call(C_hegelr_settings_set_database_key, ctx, s, key)
}

# (ctx, s, mode_int) -> invisible TRUE; 0 = test run, 1 = single test case
hegelr_settings_set_mode <- function(ctx, s, mode) {
  .Call(C_hegelr_settings_set_mode, ctx, s, mode)
}

# (ctx, s, mask_dbl) -> invisible TRUE; OR of phase bits (0..31)
hegelr_settings_set_phases <- function(ctx, s, mask) {
  .Call(C_hegelr_settings_set_phases, ctx, s, mask)
}

# (ctx, s, mask_dbl) -> invisible TRUE; OR of health-check bits (0..15)
hegelr_settings_set_suppress_health_check <- function(ctx, s, checks) {
  .Call(C_hegelr_settings_set_suppress_health_check, ctx, s, checks)
}

# (ctx, s, lgl) -> invisible TRUE
hegelr_settings_set_report_multiple_failures <- function(ctx, s, yes) {
  .Call(C_hegelr_settings_set_report_multiple_failures, ctx, s, yes)
}

# --- run loop ---------------------------------------------------------------

# (ctx, s) -> run extptr; engine output lines are routed to Rprintf
hegelr_run_start <- function(ctx, s) .Call(C_hegelr_run_start, ctx, s)

# (ctx, run) -> tc extptr, or NULL when the run is finished
hegelr_next_test_case <- function(ctx, run) .Call(C_hegelr_next_test_case, ctx, run)

# (ctx, tc, status_int, origin_str) -> invisible TRUE
hegelr_mark_complete <- function(ctx, tc, status, origin) {
  .Call(C_hegelr_mark_complete, ctx, tc, status, origin)
}

# (ctx, tc, value_dbl, label_str_or_NULL) -> invisible TRUE
hegelr_target <- function(ctx, tc, value, label) {
  .Call(C_hegelr_target, ctx, tc, value, label)
}

# (ctx, run) -> result extptr
hegelr_run_result <- function(ctx, run) .Call(C_hegelr_run_result, ctx, run)

# (ctx, result) -> int: 0 passed, 1 failed, 2 error
hegelr_run_result_status <- function(ctx, result) {
  .Call(C_hegelr_run_result_status, ctx, result)
}

# (ctx, result) -> string or NULL
hegelr_run_result_error <- function(ctx, result) {
  .Call(C_hegelr_run_result_error, ctx, result)
}

# (ctx, result) -> int
hegelr_run_result_failure_count <- function(ctx, result) {
  .Call(C_hegelr_run_result_failure_count, ctx, result)
}

# (ctx, result, i0_dbl) -> failure extptr (i is 0-based)
hegelr_run_result_failure <- function(ctx, result, i0) {
  .Call(C_hegelr_run_result_failure, ctx, result, i0)
}

# (ctx, failure) -> string
hegelr_failure_origin <- function(ctx, failure) {
  .Call(C_hegelr_failure_origin, ctx, failure)
}

# (ctx, failure) -> string or NULL
hegelr_failure_blob <- function(ctx, failure) {
  .Call(C_hegelr_failure_blob, ctx, failure)
}

# (ctx, s, blob) -> tc extptr
hegelr_test_case_from_blob <- function(ctx, s, blob) {
  .Call(C_hegelr_test_case_from_blob, ctx, s, blob)
}

# --- spans / collections ----------------------------------------------------

# (ctx, tc, label_dbl) -> invisible TRUE
hegelr_start_span <- function(ctx, tc, label) .Call(C_hegelr_start_span, ctx, tc, label)

# (ctx, tc, discard_lgl) -> invisible TRUE
hegelr_stop_span <- function(ctx, tc, discard) .Call(C_hegelr_stop_span, ctx, tc, discard)

# (ctx, tc, min_dbl, max_dbl) -> collection extptr
hegelr_new_collection <- function(ctx, tc, min, max) {
  .Call(C_hegelr_new_collection, ctx, tc, min, max)
}

# (ctx, tc, coll) -> list(value = lgl, status = int)
hegelr_collection_more <- function(ctx, tc, coll) {
  .Call(C_hegelr_collection_more, ctx, tc, coll)
}

# (ctx, tc, coll, why_or_NULL) -> invisible TRUE
hegelr_collection_reject <- function(ctx, tc, coll, why) {
  .Call(C_hegelr_collection_reject, ctx, tc, coll, why)
}

# --- draw primitives (return list(value, status) unmodified) ----------------

# (ctx, tc, p_dbl) -> list(value = lgl, status)
hegelr_generate_boolean <- function(ctx, tc, p) {
  .Call(C_hegelr_generate_boolean, ctx, tc, p)
}

# (ctx, tc, min_dbl, max_dbl) -> list(value = dbl, status)
hegelr_generate_integer <- function(ctx, tc, min, max) {
  .Call(C_hegelr_generate_integer, ctx, tc, min, max)
}

# (ctx, tc, min, max, allow_nan_lgl, allow_inf_lgl, excl_min_lgl,
#  excl_max_lgl, smallest_nonzero_dbl) -> list(value = dbl, status)
hegelr_generate_float <- function(ctx, tc, min, max, allow_nan, allow_inf,
                                  excl_min, excl_max, smallest_nonzero) {
  .Call(C_hegelr_generate_float, ctx, tc, min, max, allow_nan, allow_inf,
        excl_min, excl_max, smallest_nonzero)
}

# (ctx, tc, min_dbl, max_dbl) -> list(value = raw, status)
hegelr_generate_bytes <- function(ctx, tc, min, max) {
  .Call(C_hegelr_generate_bytes, ctx, tc, min, max)
}

# --- string generators --------------------------------------------------------

# (ctx, min_dbl, max_dbl, codec_or_NULL, min_cp_dbl, max_cp_dbl,
#  categories_chr_or_NULL, exclude_categories_chr_or_NULL,
#  include_characters_or_NULL, exclude_characters_or_NULL) -> sg extptr
hegelr_string_generator_text <- function(ctx, min, max, codec, min_cp, max_cp,
                                         categories, exclude_categories,
                                         include_characters, exclude_characters) {
  .Call(C_hegelr_string_generator_text, ctx, min, max, codec, min_cp, max_cp,
        categories, exclude_categories, include_characters, exclude_characters)
}

# (ctx, pattern, fullmatch_lgl) -> sg extptr
hegelr_string_generator_regex <- function(ctx, pattern, fullmatch) {
  .Call(C_hegelr_string_generator_regex, ctx, pattern, fullmatch)
}

# (ctx) -> sg extptr
hegelr_string_generator_email <- function(ctx) .Call(C_hegelr_string_generator_email, ctx)

# (ctx) -> sg extptr
hegelr_string_generator_url <- function(ctx) .Call(C_hegelr_string_generator_url, ctx)

# (ctx, max_length_dbl) -> sg extptr
hegelr_string_generator_domain <- function(ctx, max_length) {
  .Call(C_hegelr_string_generator_domain, ctx, max_length)
}

# (ctx, sg, tc) -> list(value = chr, status)
hegelr_generate_string <- function(ctx, sg, tc) {
  .Call(C_hegelr_generate_string, ctx, sg, tc)
}

# --- string-generator cache ---------------------------------------------------

#' Process-lifetime engine context for cached string generators
#'
#' String-generator handles are cached for the whole process (see
#' `hegelr_stringgen()`), so their extptr finalizers must never reference a
#' run-scoped context that might be collected first. This returns a single
#' dedicated context, created on first use and stored in `hegelr_env`.
#'
#' @keywords internal
#' @return An external pointer to a `hegel_context`, created once per process.
hegelr_cache_context <- function() {
  if (is.null(hegelr_env$cache_context)) {
    hegelr_env$cache_context <- hegelr_context_new()
  }
  hegelr_env$cache_context
}

#' Get-or-create a cached string generator
#'
#' String generators are immutable and shareable (ARCHITECTURE.md section 4),
#' so they are created once per schema and cached in `hegelr_env` for the
#' process lifetime. `schema_key` is a deparse digest of the schema;
#' `builder` is a closure `function(ctx)` calling the appropriate
#' `hegelr_string_generator_*` constructor - the context it receives is the
#' dedicated cache context, never a run context.
#'
#' @param schema_key Character string uniquely identifying the schema.
#' @param builder Closure `function(ctx)` constructing the sg extptr.
#' @keywords internal
#' @return An external pointer to a `hegel_string_generator` handle.
hegelr_stringgen <- function(schema_key, builder) {
  cache <- hegelr_env$stringgen_cache
  if (exists(schema_key, envir = cache, inherits = FALSE)) {
    return(get(schema_key, envir = cache, inherits = FALSE))
  }
  sg <- builder(hegelr_cache_context())
  assign(schema_key, sg, envir = cache)
  sg
}
