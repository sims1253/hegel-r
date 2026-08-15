# Tests for R/runner.R — the hegel_test() run loop: passing properties,
# failing properties (shrinking and the failure report), assumptions,
# testthat expectation failures, and derandomized determinism. The run-loop
# tests need the engine (skip_if_no_libhegel()); the settings-argument
# validation tests at the end run offline.

test_that("a passing property returns invisible TRUE", {
  skip_if_no_libhegel()
  out <- withVisible(hegel_test(function(tc) TRUE, test_cases = 10L))
  expect_false(out$visible)
  expect_true(out$value)
})

test_that("a failing property signals hegelr_failure with a falsifying example", {
  skip_if_no_libhegel()
  property <- function(tc) {
    x <- tc$draw(g_vectors(g_integers(min = -100, max = 100)))
    stopifnot(sum(x) >= 0)
  }
  failure <- expect_error(
    hegel_test(property, test_cases = 100L),
    class = "hegelr_failure"
  )
  expect_match(conditionMessage(failure), "draw_1 <-")
  expect_match(conditionMessage(failure), "Reproduce with")
})

test_that("assumptions discard cases without failing the run", {
  skip_if_no_libhegel()
  expect_true(hegel_test(function(tc) {
    x <- tc$draw(g_integers(min = 1, max = 100))
    tc$assume(x > 50)
    TRUE
  }, test_cases = 50L))
})

test_that("a testthat expectation failure inside the body becomes a hegelr failure", {
  skip_if_no_libhegel()
  expect_error(
    hegel_test(function(tc) {
      x <- tc$draw(g_integers(min = -10, max = -1))
      expect_true(x > 0)
    }, test_cases = 10L),
    class = "hegelr_failure"
  )
})

test_that("derandomized runs with a database key are deterministic", {
  skip_if_no_libhegel()
  property <- function(tc) {
    x <- tc$draw(g_integers(min = 0, max = 100))
    stopifnot(x < 50)
  }
  run_once <- function() {
    tryCatch(
      hegel_test(
        property,
        test_cases = 20L,
        derandomize = TRUE
      ),
      error = function(e) e
    )
  }
  first <- run_once()
  second <- run_once()
  expect_identical(
    inherits(first, "hegelr_failure"),
    inherits(second, "hegelr_failure")
  )
  if (inherits(first, "hegelr_failure")) {
    expect_match(conditionMessage(first), "draw_1 <-")
    expect_match(conditionMessage(second), "Reproduce with")
  }
})

test_that("single_test_case runs exactly one case and reports its draws", {
  skip_if_no_libhegel()
  count <- 0L
  out <- testthat::capture_messages(
    hegel_test(function(tc) {
      count <<- count + 1L
      tc$note("single-case note")
      tc$draw(g_integers(min = 1, max = 10))
    }, single_test_case = TRUE)
  )
  expect_identical(count, 1L)
  expect_true(any(grepl("single-case note", out, fixed = TRUE)))
  expect_true(any(grepl("draw_1 <-", out, fixed = TRUE)))
})

test_that("phases = 'explicit' never runs the property body", {
  skip_if_no_libhegel()
  count <- 0L
  expect_true(hegel_test(function(tc) {
    count <<- count + 1L
  }, phases = "explicit", test_cases = 10L))
  expect_identical(count, 0L)
})

test_that("report_multiple_failures surfaces distinct origins", {
  skip_if_no_libhegel()
  property <- function(tc) {
    if (tc$draw(g_logicals())) {
      stop("bug one")
    } else {
      stop("bug two")
    }
  }
  failure <- expect_error(
    hegel_test(property, report_multiple_failures = TRUE, test_cases = 50L,
               database = FALSE),
    class = "hegelr_failure"
  )
  expect_gte(length(failure$blobs), 1L)
  expect_match(conditionMessage(failure), "bug one")
  expect_match(conditionMessage(failure), "bug two")
})

test_that("suppress_health_checks accepts names and runs", {
  skip_if_no_libhegel()
  expect_true(hegel_test(
    function(tc) tc$draw(g_integers(min = 0, max = 9)),
    suppress_health_checks = c("filter_too_much", "too_slow"),
    test_cases = 10L
  ))
})

test_that("tc$target reports scores without failing the run", {
  skip_if_no_libhegel()
  expect_true(hegel_test(function(tc) {
    x <- tc$draw(g_integers(min = 0, max = 100))
    tc$target(x, "magnitude")
  }, test_cases = 10L))
})

test_that("verbosity = 2 emits per-case draws and verbosity = 0 quiets reports", {
  skip_if_no_libhegel()
  out <- testthat::capture_messages(
    hegel_test(function(tc) tc$draw(g_integers(0, 9)), test_cases = 5L,
               verbosity = 2L)
  )
  expect_true(any(grepl("draw_1 <-", out, fixed = TRUE)))

  failure <- expect_error(
    hegel_test(function(tc) {
      stopifnot(tc$draw(g_integers(0, 9)) < 0)
    }, test_cases = 10L, verbosity = 0L),
    class = "hegelr_failure"
  )
  # Quiet: no draw lines, no reproduce hint - just the failing call site.
  expect_false(grepl("draw_1", conditionMessage(failure)))
  expect_false(grepl("Reproduce with", conditionMessage(failure)))
})

test_that("phase and health-check names map to engine bitmasks", {
  expect_null(hegelr:::hegelr_phase_mask(NULL))
  expect_identical(hegelr:::hegelr_phase_mask("shrink"), 16)
  # OR of the unique bits, order- and duplicate-insensitive.
  expect_identical(
    hegelr:::hegelr_phase_mask(c("reuse", "generate")),
    hegelr:::hegelr_phase_mask(c("generate", "reuse", "reuse"))
  )
  expect_identical(
    hegelr:::hegelr_phase_mask(names(hegelr:::HEGELR_PHASES)),
    31
  )
  expect_error(hegelr:::hegelr_phase_mask("bogus"), "unknown phase")
  expect_error(hegelr:::hegelr_phase_mask(1), "phase names")

  expect_null(hegelr:::hegelr_health_check_mask(NULL))
  expect_identical(hegelr:::hegelr_health_check_mask("too_slow"), 2)
  expect_identical(
    hegelr:::hegelr_health_check_mask(names(hegelr:::HEGELR_HEALTH_CHECKS)),
    15
  )
  expect_error(hegelr:::hegelr_health_check_mask("nope"), "unknown health-check")
})

test_that("hegel_test validates new parity arguments before engine load", {
  prop <- function(tc) TRUE
  expect_error(hegel_test(prop, phases = "bogus"), "unknown phase")
  expect_error(hegel_test(prop, suppress_health_checks = "bogus"),
    "unknown health-check"
  )
  expect_error(hegel_test(prop, single_test_case = "yes"),
    "single_test_case"
  )
  expect_error(hegel_test(prop, report_multiple_failures = NA),
    "report_multiple_failures"
  )
})
