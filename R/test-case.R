# The TestCase object handed to property bodies (ARCHITECTURE.md section 5).
# Environment-based (no R6 dependency): new_test_case(tc_extptr, report).

# Build an error condition with extra classes. Conditions are plain
# named lists with a `message` element; conditionMessage() picks it up.
hegelr_condition <- function(class, message) {
  structure(
    list(message = message),
    class = c(class, "error", "condition")
  )
}

# One-line, <= 60 character preview of a drawn value for draw reports.
hegelr_preview <- function(value) {
  txt <- paste(deparse(value), collapse = " ")
  if (nchar(txt, type = "chars") > 60L) {
    txt <- paste0(substr(txt, 1L, 57L), "...")
  }
  txt
}

# Wrap a raw engine test-case handle in the environment users see as `tc`.
# `tc_extptr` must carry attribute "context" (the owning context extptr) -
# the shim attaches it to every non-context handle so GC can never free a
# context before its dependents (ARCHITECTURE.md section 4). The handle and
# context are re-exposed as $handle / $context for generator draw functions,
# which call the .Call bindings directly.
#
# `report = TRUE` enables the draw log used by the final failure replay and
# hegel_reproduce(): every tc$draw() appends a numbered assignment line
# ("draw_N <- <value>"), and $note() messages are collected for the report.
new_test_case <- function(tc_extptr, report = FALSE) {
  # A NULL handle constructs an engineless test case: assume()/note() and
  # engine-free generators like g_just() work on it (used by the offline
  # tests); any engine-touching draw fails at the bindings with a clear
  # error. A non-NULL handle must carry its owning context attribute.
  ctx <- attr(tc_extptr, "context")
  if (is.null(ctx) && !is.null(tc_extptr)) {
    stop('internal error: test case handle lacks its "context" attribute',
      call. = FALSE
    )
  }

  self <- new.env(parent = emptyenv())
  class(self) <- "hegelr_test_case"
  self$handle <- tc_extptr
  self$context <- ctx
  self$report <- report
  self$draw_count <- 0L
  self$draw_log <- character(0)
  self$note_log <- character(0)

  # Draw a value from a generator. Signals propagate: budget exhaustion and
  # engine-side rejections are raised by the generator layer as conditions
  # and must unwind the property body, so gen$draw() is called directly.
  # Draw lines use the family's numbered assignment shape (`draw_N <-
  # value`, cf. the TS binding's `var draw_N = ...` and Rust's
  # `let name_N = ...`), with the full deparsed value - no truncation.
  self$draw <- function(gen) {
    if (!inherits(gen, "hegelr_generator")) {
      stop("`gen` must be a hegelr generator (built by a g_*() function)",
        call. = FALSE
      )
    }
    value <- gen$draw(self)
    if (isTRUE(self$report)) {
      self$draw_count <- self$draw_count + 1L
      line <- sprintf(
        "draw_%d <- %s",
        self$draw_count,
        paste(deparse(value), collapse = " ")
      )
      self$draw_log <- c(self$draw_log, line)
    }
    value
  }

  # Reject the current test case when `condition` is not TRUE. NA also
  # rejects: an unknown precondition is not satisfied.
  self$assume <- function(condition) {
    if (!isTRUE(condition)) {
      stop(hegelr_condition("hegelr_assume", "assumption not satisfied"))
    }
    invisible(TRUE)
  }

  # Record a note; printed only on final replay / hegel_reproduce().
  self$note <- function(msg) {
    self$note_log <- c(self$note_log, paste(as.character(msg), collapse = " "))
    invisible(TRUE)
  }

  # Report a targeting score for the engine's target phase (Go's
  # TestCase.Target / Rust's TestCase::target): guides generation toward
  # larger scores for this label.
  self$target <- function(value, label = NULL) {
    invisible(hegelr_target(
      self$context, self$handle,
      hegelr_validate_number(value, "value"),
      label
    ))
  }

  # Accessors for the runner / reproduce layer.
  self$draws <- function() self$draw_log
  self$notes <- function() self$note_log

  self
}
