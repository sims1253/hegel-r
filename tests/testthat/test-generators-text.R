# Tests for R/generators-text.R: descriptor construction (offline), then
# engine draws (online, skipped without the libhegel engine).

test_that("text generators are descriptors with non-empty labels", {
  generators <- list(
    g_text(),
    g_characters(),
    g_from_regex("a[bc]d"),
    g_emails(),
    g_urls(),
    g_domains()
  )
  for (gen in generators) {
    expect_s3_class(gen, "hegelr_generator")
    expect_type(gen$label, "character")
    expect_true(nzchar(gen$label))
    expect_type(gen$draw, "closure")
  }
})

test_that("text generators carry typed empty prototypes for zero-length draws", {
  expect_identical(g_text()$empty, character(0))
  expect_identical(g_characters()$empty, character(0))
  expect_identical(g_from_regex("a")$empty, character(0))
})

test_that("g_text() draws single strings within size bounds", {
  skip_if_no_libhegel()
  draws <- draw_values(g_text(min_size = 1, max_size = 5))
  expect_true(all(vapply(draws, function(v) {
    is.character(v) && length(v) == 1L
  }, logical(1))))
  values <- unlist(draws)
  expect_length(values, 50L)
  expect_true(all(nchar(values) >= 1 & nchar(values) <= 5))
})

test_that("g_characters() draws exactly one codepoint", {
  skip_if_no_libhegel()
  draws <- draw_values(g_characters())
  values <- unlist(draws)
  expect_length(values, 50L)
  expect_true(all(nchar(values) == 1L))
})

test_that("g_from_regex() draws strings matching the pattern", {
  skip_if_no_libhegel()
  values <- unlist(draw_values(g_from_regex("a[bc]d")))
  expect_length(values, 50L)
  expect_true(all(grepl("^a[bc]d$", values)))
})

test_that("g_emails() draws strings containing @", {
  skip_if_no_libhegel()
  values <- unlist(draw_values(g_emails()))
  expect_length(values, 50L)
  expect_true(all(grepl("@", values, fixed = TRUE)))
})
