#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @useDynLib hegelr, .registration = TRUE
## usethis namespace: end
NULL

# Internal null-coalescing operator. Base R (>= 4.4) ships one; defining it
# here keeps the package usable on slightly older R without an import.
`%||%` <- function(x, y) if (is.null(x)) y else x # nolint: object_name_linter

# Package-level runtime state. Everything in here is created lazily on
# first use and lives for the process lifetime:
#
# - `lib_path`: cached result of hegel_library_path() (positive resolutions
#   only; the bare-name fallback is never cached so that a later install
#   or env var change can still be picked up).
# - `lib_loaded`: TRUE once hegel_load() has succeeded (and passed the
#   version gate).
# - `engine_version`: the engine version string recorded at load time.
# - `version_warned`: TRUE once the pinned-version mismatch warning has
#   been issued (it fires once per process, not per call).
# - `cache_context`: process-lifetime engine context owning the cached
#   string-generator handles (see hegelr_cache_context() in bindings.R).
# - `stringgen_cache`: environment keyed by schema digest holding shared
#   string-generator extptrs (see hegelr_stringgen() in bindings.R).
hegelr_env <- new.env(parent = emptyenv())
hegelr_env$lib_path <- NULL
hegelr_env$lib_loaded <- FALSE
hegelr_env$engine_version <- NULL
hegelr_env$version_warned <- FALSE
hegelr_env$cache_context <- NULL
hegelr_env$stringgen_cache <- new.env(parent = emptyenv())

.onLoad <- function(libname, pkgname) {
  # Runtime state (library path cache, loaded flag, string-generator cache,
  # cache context) is deliberately lazy and process-local: there is nothing
  # to initialize or reset here. The DLL itself is never loaded at package
  # load time - every public entry point calls hegel_load() on first use.
  invisible(NULL)
}
