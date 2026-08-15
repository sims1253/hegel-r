# Tests for R/generators-primitive.R: argument validation and descriptor
# construction (offline), then engine draws (online, skipped without the
# libhegel engine).

test_that("g_integers() rejects an empty range", {
  expect_error(g_integers(min = 10, max = -10), "min|max")
})

test_that("g_doubles() rejects an empty range", {
  expect_error(g_doubles(min = 10, max = -10), "min|max")
})

test_that("g_logicals() rejects probabilities outside [0, 1]", {
  expect_error(g_logicals(p = 2), "0.*1|probab")
  expect_error(g_logicals(p = -1), "0.*1|probab")
})

test_that("primitive generators are descriptors with non-empty labels", {
  generators <- list(
    g_integers(),
    g_doubles(),
    g_logicals(),
    g_raw()
  )
  for (gen in generators) {
    expect_s3_class(gen, "hegelr_generator")
    expect_type(gen$label, "character")
    expect_true(nzchar(gen$label))
    expect_type(gen$draw, "closure")
  }
})

test_that("primitive generators carry typed empty prototypes for zero-length draws", {
  expect_identical(g_integers()$empty, numeric(0))
  expect_identical(g_doubles()$empty, numeric(0))
  expect_identical(g_logicals()$empty, logical(0))
  expect_identical(g_raw()$empty, raw(0))
})

test_that("g_integers() draws whole numbers within bounds", {
  skip_if_no_libhegel()
  values <- unlist(draw_values(g_integers(min = -10, max = 10)))
  expect_length(values, 50L)
  expect_true(all(values >= -10 & values <= 10))
  expect_true(all(values == floor(values)))
})

test_that("g_doubles() draws finite values within bounds", {
  skip_if_no_libhegel()
  values <- unlist(draw_values(g_doubles(
    min = -1.5,
    max = 1.5,
    allow_nan = FALSE,
    allow_infinity = FALSE
  )))
  expect_length(values, 50L)
  expect_true(all(is.finite(values)))
  expect_true(all(values >= -1.5 & values <= 1.5))
})

test_that("g_logicals() draws logicals", {
  skip_if_no_libhegel()
  values <- unlist(draw_values(g_logicals()))
  expect_type(values, "logical")
  expect_length(values, 50L)
})

test_that("g_raw() draws raw vectors within size bounds", {
  skip_if_no_libhegel()
  values <- draw_values(g_raw(min_size = 0, max_size = 8))
  expect_length(values, 50L)
  expect_true(all(vapply(values, is.raw, logical(1))))
  sizes <- vapply(values, length, integer(1))
  expect_true(all(sizes >= 0 & sizes <= 8))
})
