# Tests for R/test-case.R — the TestCase object's protocol, exercised
# enginelessly through new_test_case(NULL) and g_just().

test_that("tc$assume(FALSE) signals a hegelr_assume condition", {
  tc <- hegelr:::new_test_case(NULL)
  expect_error(tc$assume(FALSE), class = "hegelr_assume")
  expect_no_error(tc$assume(TRUE))
})

test_that("g_just() draws enginelessly and report = TRUE records draws", {
  tc <- hegelr:::new_test_case(NULL, report = TRUE)
  expect_identical(tc$draw(g_just(42)), 42)
  expect_identical(tc$draw(g_just("a")), "a")

  # Something in the test case recorded the drawn value for the report.
  recorded <- unlist(unname(lapply(ls(tc), function(nm) {
    value <- tc[[nm]]
    if (is.character(value)) value else NULL
  })))
  expect_true(any(grepl("42", recorded, fixed = TRUE)))

  # Without reporting enabled, nothing is recorded.
  quiet <- hegelr:::new_test_case(NULL)
  expect_identical(quiet$draw(g_just(42)), 42)
  recorded_quiet <- unlist(unname(lapply(ls(quiet), function(nm) {
    value <- quiet[[nm]]
    if (is.character(value)) value else NULL
  })))
  expect_false(any(grepl("42", recorded_quiet, fixed = TRUE)))
})
