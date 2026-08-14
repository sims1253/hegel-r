# Single-case replay of a stored reproduction blob (ARCHITECTURE.md
# section 5), the R rendering of the Rust binding's
# #[hegel::reproduce_failure("...")]: replays the encoded choice sequence
# once, prints the draws and notes it made, re-raises a reproduced failure,
# and errors on a stale blob exactly like the Rust binding panics on one.
# No run is started, so nothing is written to any example database.

#' @title Replay a stored counterexample
#'
#' @description Re-runs one property case from a reproduction `blob`, as
#'   printed by a failing [hegel_test()] report, driving the property once
#'   with draw reporting enabled.
#'
#' If the property fails again, the failure is re-raised as a `hegelr_failure`
#' condition (inheriting from `error`) carrying the draw report and the
#' original message. If the property passes, the blob no longer reproduces
#' and an error of class `hegelr_stale_blob` is signaled. The Rust
#' binding treats this as a hard failure too: the bug may have been fixed,
#' or the blob may be stale.
#'
#' @param blob A reproduction blob string, as shown in a failure report.
#' @param property The property, as passed to [hegel_test()].
#' @param ... Unused; must be empty. Present for forward compatibility.
#'
#' @return Called for its output and side effects; a reproduced failure or
#'   a stale blob is signaled as an error condition rather than returned.
#'
#' @examples
#' \donttest{
#' if (hegel_library_available()) {
#'   my_sort <- function(x) {
#'     out <- sort(x)
#'     out[!duplicated(out)] # the bug: drops duplicates
#'   }
#'   property <- function(tc) {
#'     xs <- tc$draw(g_vectors(g_integers(-100, 100), max_size = 20))
#'     if (!identical(my_sort(xs), sort(xs))) {
#'       stop("my_sort() does not match base::sort()")
#'     }
#'   }
#'   blob <- tryCatch(
#'     hegel_test(property),
#'     hegelr_failure = function(e) {
#'       b <- e$blobs[[1L]]
#'       if (!is.na(b) && nzchar(b)) b else NULL
#'     },
#'     error = function(e) NULL
#'   )
#'   if (is.character(blob)) {
#'     tryCatch(
#'       hegel_reproduce(blob, property),
#'       hegelr_failure = function(e) cat("still failing\n"),
#'       hegelr_stale_blob = function(e) cat("fixed or stale\n")
#'     )
#'   }
#' }
#' }
#' @export
hegel_reproduce <- function(blob, property, ...) {
  if (!is.character(blob) || length(blob) != 1L || is.na(blob) || !nzchar(blob)) {
    stop("`blob` must be a single non-empty reproduction string", call. = FALSE)
  }
  if (!is.function(property)) {
    stop("`property` must be a function", call. = FALSE)
  }
  dots <- list(...)
  if (length(dots)) {
    stop("`...` must be empty; extra arguments are not supported", call. = FALSE)
  }

  hegel_load()

  # Handle lifetime: as in hegel_test(), the ABI has no free wrappers;
  # these locals become unreachable on exit and the finalizers release the
  # engine handles. Default settings: no run is started, so the example
  # database is never written to (Rust reuses the test's settings the same
  # way).
  ctx <- hegelr_context_new()
  settings <- hegelr_settings_new(ctx)

  tc_handle <- hegelr_test_case_from_blob(ctx, settings, blob)
  tc <- new_test_case(tc_handle, report = TRUE)

  res <- tryCatch(
    {
      property(tc)
      list(failed = FALSE, cond = NULL)
    },
    error = function(e) list(failed = TRUE, cond = e)
  )

  lines <- c(tc$draws(), tc$notes())

  if (isTRUE(res$failed)) {
    msg <- paste(c(
      "Reproduced Hegel failure:",
      paste0("  ", lines),
      sprintf("Original error: %s", conditionMessage(res$cond))
    ), collapse = "\n")
    stop(structure(
      list(message = msg, blob = blob, draws = tc$draws(), notes = tc$notes()),
      class = c("hegelr_failure", "error", "condition")
    ))
  }

  stop(structure(
    list(message = paste(
      "The supplied failure blob no longer reproduces a failure. ",
      "The failure may have been fixed, or the blob is stale.",
      if (length(lines)) paste0("\n", paste0("  ", lines, collapse = "\n")) else ""
    )),
    class = c("hegelr_stale_blob", "error", "condition")
  ))
}
