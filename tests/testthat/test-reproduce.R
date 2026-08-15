# Tests for R/reproduce.R — replay of stored counterexample blobs. The
# argument-validation test runs offline; the replay tests need the engine.

test_that("hegel_reproduce() requires both blob and property", {
  expect_error(hegel_reproduce(), "blob|argument")
  expect_error(hegel_reproduce("x"), "property|argument")
})

test_that("a failure blob can be replayed with hegel_reproduce()", {
  skip_if_no_libhegel()
  property <- function(tc) {
    x <- tc$draw(g_vectors(g_integers(min = -100, max = 100)))
    stopifnot(sum(x) >= 0)
  }
  failure <- expect_error(
    hegel_test(property, test_cases = 100L),
    class = "hegelr_failure"
  )
  msg <- conditionMessage(failure)
  expect_match(msg, 'Reproduce with: hegel_reproduce\\("([^\"]+)"')
  blob <- sub('.*Reproduce with: hegel_reproduce\\("([^\"]+)".*', "\\1", msg)
  expect_true(nzchar(blob))
  expect_false(grepl("Reproduce with", blob, fixed = TRUE))

  # Replaying the blob against the same property fails again.
  expect_error(hegel_reproduce(blob, property), class = "hegelr_failure")
})

test_that("hegel_reproduce() rejects malformed blobs clearly", {
  skip_if_no_libhegel()
  property <- function(tc) TRUE
  expect_error(hegel_reproduce("not-a-real-blob", property))
})
