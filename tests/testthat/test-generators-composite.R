# Tests for R/generators-composite.R: argument validation and descriptor
# construction (offline), then engine draws (online, skipped without the
# libhegel engine).

test_that("g_vectors() and g_lists() reject negative size bounds", {
  expect_error(g_vectors(g_integers(), min_size = -1), "size")
  expect_error(g_lists(g_integers(), min_size = -1), "size")
})

test_that("g_map() requires a function", {
  expect_error(g_map(g_integers(), 2), "function")
})

test_that("g_one_of() requires at least one generator", {
  expect_error(g_one_of(), "generator|one")
})

test_that("composite generators are descriptors with non-empty labels", {
  generators <- list(
    g_vectors(g_integers()),
    g_lists(g_integers()),
    g_tuple(g_integers(), g_logicals()),
    g_one_of(g_integers(), g_logicals()),
    g_sampled_from(letters[1:3]),
    g_just(1),
    g_map(g_integers(), identity),
    g_filter(g_integers(), function(x) TRUE)
  )
  for (gen in generators) {
    expect_s3_class(gen, "hegelr_generator")
    expect_type(gen$label, "character")
    expect_true(nzchar(gen$label))
    expect_type(gen$draw, "closure")
  }
})

test_that("composite generators carry typed empty prototypes for zero-length draws", {
  # Composites propagate the element type.
  expect_identical(g_vectors(g_integers())$empty, numeric(0))
  expect_identical(g_vectors(g_raw())$empty, raw(0))
  expect_identical(g_filter(g_text(), function(x) TRUE)$empty, character(0))
  expect_identical(g_sampled_from(letters[1:3])$empty, character(0))
  expect_identical(g_lists(g_integers())$empty, list())
  # Unknown output types stay NULL rather than guessing.
  expect_null(g_map(g_integers(), identity)$empty)
  expect_null(g_one_of(g_integers(), g_characters())$empty)
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
