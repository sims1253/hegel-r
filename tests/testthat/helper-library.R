# Shared helpers for the hegelr test suite. This file is sourced before any
# test file runs.

# Skip a test when the native libhegel engine is not available. Offline tests
# (argument validation, descriptor construction) run everywhere; online tests
# need the engine, which CI installs via hegelr::hegel_install() and local
# users get from hegelr::hegel_install() or HEGEL_LIBHEGEL_PATH.
skip_if_no_libhegel <- function() {
  if (!hegelr::hegel_library_available()) {
    testthat::skip("libhegel engine not available")
  }
}

# Minimal withr::local_envvar() replacement so the test suite stays
# dependency-free: set named environment variables now and restore the
# previous values when the calling frame exits. A value of NA unsets the
# variable, mirroring withr semantics.
local_envvar_ <- function(...) {
  new <- list(...)
  if (length(new) == 0L) {
    return(invisible(NULL))
  }
  nms <- names(new)
  if (is.null(nms) || !all(nzchar(nms))) {
    stop("`...` must be fully named", call. = FALSE)
  }

  restore <- function(values) {
    for (nm in names(values)) {
      value <- values[[nm]]
      if (is.na(value)) {
        Sys.unsetenv(nm)
      } else {
        do.call(Sys.setenv, stats::setNames(list(value), nm))
      }
    }
    invisible(NULL)
  }

  old <- as.list(Sys.getenv(nms, unset = NA_character_))
  names(old) <- nms

  restore(new)
  do.call(
    "on.exit",
    list(bquote(.(restore)(.(old))), add = TRUE),
    envir = parent.frame()
  )
  invisible(new)
}

# Draw n values from a generator by running a single passing test case whose
# body draws n times.
draw_values <- function(gen, n = 50L) {
  out <- vector("list", n)
  hegel_test(
    function(tc) {
      for (i in seq_len(n)) {
        out[[i]] <<- tc$draw(gen)
      }
    },
    test_cases = 1L,
    database = FALSE
  )
  out
}
