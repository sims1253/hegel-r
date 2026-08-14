# The property run loop (ARCHITECTURE.md section 5).
#
# Status integers passed to C_hegelr_mark_complete (mirroring
# hegel_status_t): VALID = 0, INVALID = 1, OVERRUN = 2, INTERESTING = 3.
HEGELR_STATUS_VALID <- 0L
HEGELR_STATUS_INVALID <- 1L
HEGELR_STATUS_OVERRUN <- 2L
HEGELR_STATUS_INTERESTING <- 3L

# Engine bitmasks mirrored from hegel.h (hegel_phase_t, hegel_health_check_t)
# and the single-test-case mode, named per the official Hegel bindings
# (Rust Settings::phases / Mode::SingleTestCase, Go WithPhases /
# WithSingleTestCase / SuppressHealthCheck).
HEGELR_PHASES <- c(explicit = 1, reuse = 2, generate = 4, target = 8, shrink = 16)
HEGELR_HEALTH_CHECKS <- c(
  filter_too_much = 1,
  too_slow = 2,
  test_cases_too_large = 4,
  large_initial_test_case = 8
)
HEGELR_MODE_SINGLE_TEST_CASE <- 1

# `phases` argument -> engine bitmask, or NULL for the engine default (all
# phases). Validated eagerly so bad names error before the engine loads.
hegelr_phase_mask <- function(phases) {
  if (is.null(phases)) {
    return(NULL)
  }
  if (!is.character(phases) || !length(phases) || anyNA(phases) ||
    !all(nzchar(phases))) {
    stop(sprintf(
      "`phases` must be NULL or a character vector of phase names (one of: %s)",
      paste(names(HEGELR_PHASES), collapse = ", ")
    ), call. = FALSE)
  }
  bad <- setdiff(phases, names(HEGELR_PHASES))
  if (length(bad)) {
    stop(sprintf(
      "unknown phase name(s): %s (valid: %s)",
      paste(bad, collapse = ", "), paste(names(HEGELR_PHASES), collapse = ", ")
    ), call. = FALSE)
  }
  sum(HEGELR_PHASES[unique(phases)])
}

# `suppress_health_checks` argument -> engine bitmask, or NULL (suppress
# nothing).
hegelr_health_check_mask <- function(checks) {
  if (is.null(checks)) {
    return(NULL)
  }
  if (!is.character(checks) || !length(checks) || anyNA(checks) ||
    !all(nzchar(checks))) {
    stop(sprintf(
      paste0(
        "`suppress_health_checks` must be NULL or a character vector of ",
        "health-check names (one of: %s)"
      ),
      paste(names(HEGELR_HEALTH_CHECKS), collapse = ", ")
    ), call. = FALSE)
  }
  bad <- setdiff(checks, names(HEGELR_HEALTH_CHECKS))
  if (length(bad)) {
    stop(sprintf(
      "unknown health-check name(s): %s (valid: %s)",
      paste(bad, collapse = ", "),
      paste(names(HEGELR_HEALTH_CHECKS), collapse = ", ")
    ), call. = FALSE)
  }
  sum(HEGELR_HEALTH_CHECKS[unique(checks)])
}

# Location-based origin, family-style: identify the failing call site (Go's
# findCaller() with isNotHegelFrame, Rust's panic location, TS's first
# non-node_modules frame). The error message is deliberately NOT part of
# the origin: the engine groups failures by call site, so one failing line
# with varying messages is one bug, and distinct lines are distinct bugs.
#
# The stack is walked innermost-first, skipping hegelr frames and R's
# internal condition-dispatch frames (`h`, `.handleSimpleError`,
# `signalCondition`), which sit between the handler and the failing call
# and are identical for every error. conditionCall() is only a fallback:
# for stop() it carries the enclosing function invocation (identical for
# every failure site in one property), not the failing call. Must run
# inside a calling handler (withCallingHandlers), where sys.calls() is the
# failing stack. Falls back to the condition message.
hegelr_dispatch_frames <- "^h\\(|^signalCondition\\(|^\\.handleSimpleError\\("

hegelr_origin_of <- function(e) {
  calls <- sys.calls()
  ns <- asNamespace("hegelr")
  for (i in rev(seq_along(calls))) {
    frame <- tryCatch(
      list(call = calls[[i]], fn = sys.function(i)),
      error = function(e) NULL
    )
    if (is.null(frame)) {
      next
    }
    env <- tryCatch(environment(frame$fn), error = function(e) NULL)
    if (is.null(env) || !identical(topenv(env), ns)) {
      call_txt <- deparse(frame$call)[[1L]]
      if (grepl(hegelr_dispatch_frames, call_txt)) {
        next
      }
      srcref <- attr(frame$call, "srcref")
      if (!is.null(srcref)) {
        file <- tryCatch(utils::getSrcFilename(frame$call), error = function(e) "")
        line <- tryCatch(utils::getSrcLocation(frame$call), error = function(e) NA)
        if (nzchar(file) && !is.na(line)) {
          return(sprintf("%s:%d", file, as.integer(line)))
        }
      }
      return(call_txt)
    }
  }
  call <- conditionCall(e)
  if (!is.null(call)) {
    return(deparse(call)[[1L]])
  }
  conditionMessage(e)
}

# CI detection for the database default: the family disables the example
# database in CI (TS `database: inCI ? disabled : unset`; the engine itself
# auto-disables under CI env vars when no explicit path is set).
hegelr_in_ci <- function() {
  nzchar(Sys.getenv("CI")) || nzchar(Sys.getenv("GITHUB_ACTIONS"))
}

# Best-effort identity for the example database, derived from the
# property's deparsed head (signature + first body lines).
hegelr_property_key <- function(property) {
  body_txt <- deparse(utils::head(body(property), 2L))
  paste0(
    "function(", paste(names(formals(property)), collapse = ", "), ") ",
    paste(body_txt, collapse = " ")
  )
}

# Resolve the `database` argument to an engine path. The family default is
# the engine's own `./.hegel/examples/` with automatic disabling in CI; the
# R translation redirects to a stable per-user cache dir because writing
# into the working directory violates CRAN's policy during R CMD check
# (documented deviation, ARCHITECTURE.md section 9). NULL passes the
# engine default through untouched; "" (FALSE) disables; a string is a
# path.
hegelr_database_path <- function(database) {
  if (is.null(database)) {
    return(NULL)
  }
  if (identical(database, FALSE)) {
    return("")
  }
  if (isTRUE(database)) {
    if (hegelr_in_ci()) {
      return("")
    }
    return(file.path(tools::R_user_dir("hegelr", "cache"), "examples"))
  }
  if (is.character(database) && length(database) == 1L &&
    !is.na(database) && nzchar(database)) {
    return(database)
  }
  stop("`database` must be TRUE, FALSE, a directory path, or NULL", call. = FALSE)
}

# Re-run one reproduction blob with draw reporting enabled, for the final
# failure report. The failure has already happened, so every condition
# raised by the property is swallowed; the family re-raises the test's own
# error, so capture its message for the report body. Returns
# list(draws, notes, message).
hegelr_replay_case <- function(ctx, settings, blob, property) {
  tc_handle <- hegelr_test_case_from_blob(ctx, settings, blob)
  tc <- new_test_case(tc_handle, report = TRUE)
  msg <- NULL
  tryCatch(
    property(tc),
    error = function(e) {
      msg <<- conditionMessage(e)
      NULL
    }
  )
  list(draws = tc$draws(), notes = tc$notes(), message = msg)
}

#' @title Run a property-based test
#'
#' @description `hegel_test()` drives the Hegel engine for `property`, a
#'   plain R closure taking one argument: the test case object `tc`. Inside
#'   the body:
#'
#' - `tc$draw(gen)` draws a value from a generator (`g_integers()`,
#'   `g_vectors()`, ...); all randomness must come from draws so the
#'   engine can shrink and replay.
#' - `tc$assume(cond)` rejects the current case when `cond` is not `TRUE`
#'   (the case is retried, not failed).
#' - `tc$note(msg)` records a message shown only in the failure report.
#' - `stop()`, `stopifnot()` and testthat expectations fail the case.
#'
#' Each case's outcome maps to an engine status: a body that returns
#' normally is VALID, `hegelr_assume` conditions are INVALID, budget
#' exhaustion is OVERRUN (the engine signals `hegelr_stop_test` when the
#' draw budget runs out), and any other error is INTERESTING - a
#' counterexample to shrink and report. This includes testthat expectation
#' failures, which inherit from `error`.
#'
#' When the run fails, `hegel_test()` replays each shrunk counterexample
#' once with draw reporting, then signals a condition of class
#' `hegelr_failure` (inheriting from `error`). The message lists each
#' failure's draws as numbered assignment lines, an optional reproduce
#' hint, and the property's own error message; multiple failures get a
#' count headline:
#'
#' ```
#' draw_1 <- c(0, 0)
#' Reproduce with: hegel_reproduce("<blob>", property)
#' identical(my_sort(x), sort(x)) is not TRUE
#' ```
#'
#' The condition carries `blobs`, `draws` and `notes` fields for
#' programmatic use. `verbosity = 0` reduces the report to the failing
#' call sites.
#'
#' @param property A function taking a single argument (the test case).
#' @param test_cases Number of test cases to aim for (whole number
#'   `>= 1`). Defaults to 100.
#' @param seed Optional fixed seed (whole number, `|seed| <= 2^53`),
#'   making the run deterministic; negative values wrap like a two's
#'   complement cast, matching the Go binding.
#' @param derandomize Use a fixed seed derived from the database key
#'   instead of a random one. `NULL` (the default) defers to the engine,
#'   which enables derandomization in CI environments; pass `TRUE`/`FALSE`
#'   to decide explicitly.
#' @param database `TRUE` (default): persist failing examples under
#'   `tools::R_user_dir("hegelr", "cache")/examples/`, a stable location
#'   (the engine's own default depends on the working directory); hegelr
#'   disables the database automatically in CI, like the other Hegel
#'   bindings. `FALSE`: disable the database. A directory path string: use
#'   that directory.
#' @param verbosity Engine verbosity, `NULL` (default) for the engine
#'   default, or a whole number in `0..3`. At `verbosity >= 2` each test
#'   case's draws and notes are shown as it runs; `verbosity = 0` (quiet)
#'   reduces the failure report to the failing call site.
#' @param phases Which engine phases to run: `NULL` (default) for all, or a
#'   character vector subset of `"explicit"`, `"reuse"`, `"generate"`,
#'   `"target"`, `"shrink"` (named per the official bindings' `Phase`
#'   enums). E.g. `phases = c("reuse", "generate")` disables shrinking;
#'   `phases = "generate"` runs only freshly generated examples.
#' @param single_test_case Run exactly one generated test case with no
#'   shrinking, replay, or example database (Go binding's
#'   `WithSingleTestCase()`, Rust's `Mode::SingleTestCase`). Useful for
#'   long-running workloads or bodies not safely re-runnable on the same
#'   inputs; draw and note output is shown for the case.
#' @param suppress_health_checks `NULL` (default) or a character vector of
#'   health checks to disable: `"filter_too_much"`, `"too_slow"`,
#'   `"test_cases_too_large"`, `"large_initial_test_case"`.
#' @param report_multiple_failures Keep generating after the first failure
#'   to surface additional distinct bugs (grouped by origin). Defaults to
#'   `FALSE` (stop at the first failure).
#'
#' @return `TRUE`, invisibly, when the property holds. On failure or an
#'   engine-level error, an error condition is signaled (class
#'   `hegelr_failure` for falsified properties, `hegelr_run_error` for
#'   engine errors).
#'
#' @examples
#' if (hegel_library_available()) {
#'   # Passing property: sorting is idempotent.
#'   hegel_test(function(tc) {
#'     xs <- tc$draw(g_vectors(g_integers(-100, 100), max_size = 20))
#'     stopifnot(identical(sort(xs), sort(sort(xs))))
#'   })
#'
#'   # Failing property: the classic sort-with-dedup bug. Hegel shrinks it
#'   # to a minimal counterexample (two equal elements); the example
#'   # catches the failure and prints it.
#'   my_sort <- function(x) {
#'     out <- sort(x)
#'     out[!duplicated(out)] # silently drops duplicates: the bug
#'   }
#'   tryCatch(
#'     hegel_test(function(tc) {
#'       xs <- tc$draw(g_vectors(g_integers(-100, 100), max_size = 20))
#'       if (!identical(my_sort(xs), sort(xs))) {
#'         stop("my_sort() does not match base::sort()")
#'       }
#'     }),
#'     error = function(e) cat("caught:", conditionMessage(e), "\n")
#'   )
#' }
#' @export
hegel_test <- function(property, test_cases = 100, seed = NULL,
                       derandomize = NULL, database = TRUE,
                       verbosity = NULL,
                       phases = NULL, single_test_case = FALSE,
                       suppress_health_checks = NULL,
                       report_multiple_failures = FALSE) {
  if (!is.function(property)) {
    stop("`property` must be a function", call. = FALSE)
  }
  test_cases <- hegelr_validate_number(test_cases, "test_cases",
    min = 1, max = hegelr_max_integer, whole = TRUE
  )
  if (!is.null(seed)) {
    seed <- hegelr_validate_number(seed, "seed",
      min = -hegelr_max_integer, max = hegelr_max_integer, whole = TRUE
    )
  }
  if (!is.null(derandomize)) {
    derandomize <- hegelr_validate_flag(derandomize, "derandomize")
  }
  if (!is.null(verbosity)) {
    verbosity <- hegelr_validate_number(verbosity, "verbosity",
      min = 0, max = 3, whole = TRUE
    )
  }
  db_path <- hegelr_database_path(database)
  phases_mask <- hegelr_phase_mask(phases)
  single_test_case <- hegelr_validate_flag(single_test_case, "single_test_case")
  health_mask <- hegelr_health_check_mask(suppress_health_checks)
  report_multiple_failures <- hegelr_validate_flag(
    report_multiple_failures, "report_multiple_failures"
  )

  hegel_load()

  # Handle lifetime: the ABI (ARCHITECTURE.md section 4) exposes no free
  # wrappers - every extptr releases its engine handle through a registered
  # finalizer when GC collects it. All handles below are ordinary locals so
  # they become unreachable (and collectable, LIFO) as soon as hegel_test()
  # exits, including on error; nothing further is required or possible.
  ctx <- hegelr_context_new()
  settings <- hegelr_settings_new(ctx)
  hegelr_settings_set_test_cases(ctx, settings, test_cases)
  if (!is.null(seed)) {
    hegelr_settings_set_seed(ctx, settings, seed, TRUE)
  }
  if (!is.null(verbosity)) {
    hegelr_settings_set_verbosity(ctx, settings, verbosity)
  }
  if (!is.null(db_path) && nzchar(db_path)) {
    dir.create(db_path, recursive = TRUE, showWarnings = FALSE)
  }
  hegelr_settings_set_database(ctx, settings, db_path)
  # The database key is derived from the property (best effort, its
  # deparsed head); family bindings keep it private the same way.
  hegelr_settings_set_database_key(ctx, settings, hegelr_property_key(property))
  if (!is.null(derandomize)) {
    hegelr_settings_set_derandomize(ctx, settings, derandomize)
  }
  if (single_test_case) {
    hegelr_settings_set_mode(ctx, settings, HEGELR_MODE_SINGLE_TEST_CASE)
  }
  if (!is.null(phases_mask)) {
    hegelr_settings_set_phases(ctx, settings, phases_mask)
  }
  if (!is.null(health_mask)) {
    hegelr_settings_set_suppress_health_check(ctx, settings, health_mask)
  }
  hegelr_settings_set_report_multiple_failures(
    ctx, settings, report_multiple_failures
  )

  run <- hegelr_run_start(ctx, settings)

  # Draw/note reporting: on for single-case mode and (per the Rust
  # binding's verbose behavior) for every case at verbosity >= 2; silent
  # during exploration otherwise.
  single_report <- isTRUE(single_test_case)
  verbose_report <- !is.null(verbosity) && verbosity >= 2L
  quiet <- identical(as.integer(verbosity), 0L)
  single_draws <- character(0)
  single_notes <- character(0)
  single_error_msg <- NULL

  repeat {
    tc_handle <- hegelr_next_test_case(ctx, run)
    if (is.null(tc_handle)) {
      break
    }
    tc <- new_test_case(tc_handle, report = single_report || verbose_report)

    # A calling handler observes the error on the failing stack, so the
    # location-based origin sees the user's frames; the condition then
    # propagates to the tryCatch handlers below for classification.
    origin <- ""
    case_error_msg <- NULL
    outcome <- tryCatch(
      withCallingHandlers(
        {
          property(tc)
          list(status = HEGELR_STATUS_VALID, origin = "")
        },
        error = function(e) {
          if (!inherits(e, "hegelr_stop_test") &&
            !inherits(e, "hegelr_assume")) {
            origin <<- hegelr_origin_of(e)
            case_error_msg <<- conditionMessage(e)
          }
          NULL
        }
      ),
      hegelr_stop_test = function(e) {
        list(status = HEGELR_STATUS_OVERRUN, origin = "")
      },
      hegelr_assume = function(e) {
        list(status = HEGELR_STATUS_INVALID, origin = "")
      },
      error = function(e) {
        # Engine/binding errors (the shim prefixes its messages with the
        # wrapper name) abort the run instead of becoming counterexamples,
        # matching the Rust binding's InvalidArgument/InternalError path.
        if (grepl("^C_hegelr_", conditionMessage(e))) {
          stop(structure(
            list(message = conditionMessage(e)),
            class = c("hegelr_run_error", "error", "condition")
          ))
        }
        list(status = HEGELR_STATUS_INTERESTING, origin = origin)
      }
    )
    hegelr_mark_complete(ctx, tc_handle, outcome$status, outcome$origin)
    if (single_report) {
      single_draws <- tc$draws()
      single_notes <- tc$notes()
      single_error_msg <- case_error_msg
    } else if (verbose_report) {
      lines <- c(tc$draws(), tc$notes())
      if (length(lines)) {
        message(paste0("  ", lines, collapse = "\n"))
      }
    }
    # mark_complete() was called, so advancing the engine run is legal.
    # The tc extptr itself is freed by its finalizer once GC collects the
    # reference dropped here; handles stay bounded because nothing retains
    # them across iterations.
    tc <- NULL
    tc_handle <- NULL
  }

  result <- hegelr_run_result(ctx, run)
  status <- as.integer(hegelr_run_result_status(ctx, result))

  if (identical(status, 0L)) {
    if (single_report) {
      lines <- c(single_draws, single_notes)
      if (length(lines)) {
        message(paste0("  ", lines, collapse = "\n"))
      }
    }
    return(invisible(TRUE))
  }

  if (identical(status, 2L)) {
    err <- hegelr_run_result_error(ctx, result)
    if (is.null(err) || !nzchar(err)) {
      err <- "engine reported an error without a message"
    }
    stop(structure(
      list(message = err),
      class = c("hegelr_run_error", "error", "condition")
    ))
  }

  if (!identical(status, 1L)) {
    stop(sprintf("unknown engine run status: %s", status), call. = FALSE)
  }

  # Run failed. Report format follows the family: numbered draw lines
  # (`draw_N <- value`, the TS/Rust assignment shape), then the property's
  # own error message as the body - no synthesized headers. Multiple
  # failures get Rust's count headline. Under quiet (verbosity = 0) the
  # report shrinks to the failing call sites. The reproduce hint is shown
  # only when the engine produced a blob (R-specific affordance: R has no
  # attribute macro, so the hint is how users learn about
  # hegel_reproduce()).
  count <- as.integer(hegelr_run_result_failure_count(ctx, result))
  sections <- character(0)
  blobs <- character(0)
  all_draws <- character(0)
  all_notes <- character(0)
  for (i in seq_len(count)) {
    failure <- hegelr_run_result_failure(ctx, result, i - 1L)
    origin <- hegelr_failure_origin(ctx, failure)
    blob <- hegelr_failure_blob(ctx, failure)
    has_blob <- !is.null(blob) && nzchar(blob)
    if (!has_blob) {
      blob <- ""
    }
    if (quiet) {
      sections <- c(sections, origin)
      blobs <- c(blobs, blob)
      next
    }
    lines <- character(0)
    error_msg <- origin
    if (single_report) {
      # Nothing was shrunk; the collected draws of the one case are exact.
      lines <- c(single_draws, single_notes)
      error_msg <- single_error_msg %||% origin
    } else if (has_blob) {
      replay <- hegelr_replay_case(ctx, settings, blob, property)
      lines <- c(replay$draws, replay$notes)
      error_msg <- replay$message %||% origin
      all_draws <- c(all_draws, replay$draws)
      all_notes <- c(all_notes, replay$notes)
    }
    block <- paste0("  ", lines)
    if (has_blob) {
      block <- c(block, sprintf(
        'Reproduce with: hegel_reproduce("%s", property)', blob
      ))
    }
    sections <- c(sections, block, error_msg)
    blobs <- c(blobs, blob)
  }
  if (count > 1L) {
    sections <- c(
      sprintf("Property-based test failed with %d distinct failures.", count),
      sections
    )
  }

  stop(structure(
    list(
      message = paste(sections, collapse = "\n"),
      blobs = blobs,
      draws = all_draws,
      notes = all_notes
    ),
    class = c("hegelr_failure", "error", "condition")
  ))
}
