# Online tests: every test needs the libhegel engine and starts with
# skip_if_no_libhegel(). CI installs the engine before R CMD check; locally
# run hegelr::hegel_install() once or set HEGEL_LIBHEGEL_PATH.

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

test_that("g_vectors() draws vectors within size and value bounds", {
  skip_if_no_libhegel()
  values <- draw_values(g_vectors(g_integers(min = -5, max = 5), max_size = 8))
  expect_length(values, 50L)
  sizes <- vapply(values, length, integer(1))
  expect_true(all(sizes >= 0 & sizes <= 8))
  expect_true(all(vapply(values, function(v) {
    is.numeric(v) && all(v >= -5 & v <= 5)
  }, logical(1))))
})

test_that("g_lists() draws lists preserving the element type", {
  skip_if_no_libhegel()
  values <- draw_values(g_lists(g_logicals()))
  expect_length(values, 50L)
  expect_true(all(vapply(values, is.list, logical(1))))
  expect_true(all(vapply(values, function(v) {
    all(vapply(v, is.logical, logical(1)))
  }, logical(1))))
})

test_that("g_tuple() preserves length, order, and types", {
  skip_if_no_libhegel()
  values <- draw_values(g_tuple(g_just("a"), g_just(2), g_just(TRUE)))
  expect_length(values, 50L)
  expect_true(all(vapply(values, function(v) {
    length(v) == 3L &&
      identical(v[[1]], "a") &&
      identical(v[[2]], 2) &&
      identical(v[[3]], TRUE)
  }, logical(1))))
})

test_that("g_one_of() returns values from one of its generators", {
  skip_if_no_libhegel()
  # One draw per test case, not 50 draws in one case: the engine's first
  # generated test case is a deterministic "all-simplest" pre-trial where
  # every draw returns the simplest value in range (see
  # NativeTestCase::for_simplest in hegel-c), so a test_cases = 1 run
  # draws only minimal values for every generator.
  values <- character(0)
  hegel_test(function(tc) {
    values <<- c(values, tc$draw(g_one_of(g_just("x"), g_just("y"))))
  }, test_cases = 50L, database = FALSE)
  expect_true(all(values %in% c("x", "y")))
  expect_setequal(unique(values), c("x", "y"))
})

test_that("g_sampled_from() returns elements of the given set", {
  skip_if_no_libhegel()
  values <- unlist(draw_values(g_sampled_from(letters[1:3])))
  expect_length(values, 50L)
  expect_true(all(values %in% c("a", "b", "c")))
})

test_that("g_map() transforms drawn values", {
  skip_if_no_libhegel()
  values <- unlist(draw_values(g_map(
    g_integers(min = 0, max = 10),
    function(x) x + 1
  )))
  expect_length(values, 50L)
  expect_true(all(values >= 1 & values <= 11))
  expect_true(all(values == floor(values)))
})

test_that("g_filter() only yields values satisfying the predicate", {
  skip_if_no_libhegel()
  values <- unlist(draw_values(g_filter(
    g_integers(min = 0, max = 10),
    function(x) x %% 2 == 0
  )))
  expect_length(values, 50L)
  expect_true(all(values %% 2 == 0))
})
