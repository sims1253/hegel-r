# Composite generators (ARCHITECTURE.md section 5 table). Compound
# structures are wrapped in labeled spans so the engine's shrinker knows
# what it is shrinking (hegel_label_t values, mirrored below as private
# constants).

# hegel_label_t values used by this layer (engine enum mirrors).
HEGEL_LABEL_LIST <- 1
HEGEL_LABEL_TUPLE <- 7
HEGEL_LABEL_ONE_OF <- 8
HEGEL_LABEL_FILTER <- 12
HEGEL_LABEL_MAPPED <- 13
HEGEL_LABEL_SAMPLED_FROM <- 14

# Retry cap for g_filter() before the case is rejected, per the family
# (Rust generators.rs and Go generators.go both use 3 attempts); the
# engine's filter_too_much health check is the real over-filtering guard.
HEGELR_MAX_FILTER_ATTEMPTS <- 3

# Validate size arguments shared by g_vectors()/g_lists(). Returns the
# engine-side (min, max) pair: an infinite max_size becomes the 2^53
# "no bound" sentinel, the largest value the u64-safe ABI subset accepts.
hegelr_collection_bounds <- function(min_size, max_size) {
  min_size <- hegelr_validate_number(min_size, "min_size",
    min = 0, max = hegelr_max_integer, whole = TRUE
  )
  if (is.null(max_size) || length(max_size) != 1L || is.na(max_size) ||
    !is.numeric(max_size) || max_size < min_size ||
    (!is.infinite(max_size) && max_size > hegelr_max_integer)) {
    stop("`max_size` must be a number >= `min_size` (Inf allowed)", call. = FALSE)
  }
  max_bound <- if (is.infinite(max_size)) hegelr_max_integer else as.numeric(max_size)
  c(min = min_size, max = max_bound)
}

#' @title Generate atomic vectors
#'
#' @description Draws an atomic vector whose elements come from `gen`; the
#'   engine chooses the length through a collection session
#'   (`new_collection` / `collection_more`) inside a LIST span. Elements
#'   are unified into an atomic vector of the element type: doubles,
#'   logicals and characters via `c()`; raw elements via `as.raw()`. An
#'   empty draw yields the element generator's typed empty prototype when
#'   the type is knowable without a draw (`numeric(0)` for [g_integers()],
#'   `raw(0)` for [g_raw()], ...). Otherwise the result is `NULL` (e.g.
#'   under [g_map()], whose output type depends on the transform).
#'
#' @param gen Element generator (built by a `g_*()` function).
#' @param min_size Minimum length (whole number `>= 0`).
#' @param max_size Maximum length (whole number, or `Inf` for unbounded).
#'   `Inf` is sent to the engine as the 2^53 "no bound" sentinel.
#'
#' @return A generator descriptor (class `hegelr_generator`).
#'
#' @examples
#' g_vectors(g_integers(-100, 100), max_size = 20)
#' @export
g_vectors <- function(gen, min_size = 0, max_size = Inf) {
  hegelr_validate_generator(gen)
  bounds <- hegelr_collection_bounds(min_size, max_size)
  min_size <- bounds[["min"]]
  max_bound <- bounds[["max"]]

  hegelr_generator(
    draw = function(tc) {
      # Go binding parity: on an aborting error (budget exhausted, engine
      # rejection, property failure) the span is left open - the runner
      # tears the whole test case down regardless.
      hegelr_start_span(tc$context, tc$handle, HEGEL_LABEL_LIST)
      coll <- hegelr_new_collection(tc$context, tc$handle, min_size, max_bound)
      out <- list()
      repeat {
        more <- hegelr_stop_for_status(
          hegelr_collection_more(tc$context, tc$handle, coll)
        )
        if (!isTRUE(more)) {
          break
        }
        out[[length(out) + 1L]] <- gen$draw(tc)
      }
      hegelr_stop_span(tc$context, tc$handle, FALSE)
      if (!length(out)) {
        # Typed empty when the element generator knows its type (R's
        # `x[[i]] <- NULL` deletes entries, so NULL here corrupts callers'
        # collections); NULL only when the type is unknowable.
        return(gen$empty %||% NULL)
      }
      if (is.raw(out[[1L]])) {
        as.raw(do.call(c, lapply(out, as.integer)))
      } else {
        do.call(c, out)
      }
    },
    label = hegelr_label("g_vectors", gen = I(gen$label), min_size = min_size,
      max_size = max_size, .defaults = list(min_size = 0, max_size = Inf)),
    empty = gen$empty %||% NULL
  )
}

#' @title Generate lists
#'
#' @description Like [g_vectors()] but returns a plain `list()`, so
#'   elements may be of any type (including nested generators' outputs of
#'   differing kinds). Uses the same LIST span and collection session
#'   protocol.
#'
#' @param gen Element generator (built by a `g_*()` function).
#' @param min_size Minimum length (whole number `>= 0`).
#' @param max_size Maximum length (whole number, or `Inf` for unbounded).
#'
#' @return A generator descriptor (class `hegelr_generator`).
#'
#' @examples
#' g_lists(g_logicals(), max_size = 5)
#' @export
g_lists <- function(gen, min_size = 0, max_size = Inf) {
  hegelr_validate_generator(gen)
  bounds <- hegelr_collection_bounds(min_size, max_size)
  min_size <- bounds[["min"]]
  max_bound <- bounds[["max"]]

  hegelr_generator(
    draw = function(tc) {
      hegelr_start_span(tc$context, tc$handle, HEGEL_LABEL_LIST)
      coll <- hegelr_new_collection(tc$context, tc$handle, min_size, max_bound)
      out <- list()
      repeat {
        more <- hegelr_stop_for_status(
          hegelr_collection_more(tc$context, tc$handle, coll)
        )
        if (!isTRUE(more)) {
          break
        }
        out[[length(out) + 1L]] <- gen$draw(tc)
      }
      hegelr_stop_span(tc$context, tc$handle, FALSE)
      out
    },
    label = hegelr_label("g_lists", gen = I(gen$label), min_size = min_size,
      max_size = max_size, .defaults = list(min_size = 0, max_size = Inf)),
    empty = list()
  )
}

#' @title Generate tuples
#'
#' @description Draws each of `...gens` in order inside a TUPLE span,
#'   returning their values as a list, optionally named via `.names`.
#'
#' @param ... Element generators (built by `g_*()` functions).
#' @param .names Optional character vector of element names, of the same
#'   length as the number of generators.
#'
#' @return A generator descriptor (class `hegelr_generator`) drawing one
#'   (named) list per case.
#'
#' @examples
#' g_tuple(g_integers(), g_text(max_size = 4), .names = c("n", "s"))
#' @export
g_tuple <- function(..., .names = NULL) {
  gens <- list(...)
  if (!length(gens)) {
    stop("g_tuple() needs at least one generator", call. = FALSE)
  }
  lapply(seq_along(gens), function(i) {
    hegelr_validate_generator(gens[[i]], sprintf("..%d (argument %d)", i, i))
  })
  if (!is.null(.names)) {
    .names <- hegelr_validate_char_vector(.names, ".names")
    if (length(.names) != length(gens)) {
      stop("`.names` must have the same length as the number of generators",
        call. = FALSE
      )
    }
  }

  hegelr_generator(
    draw = function(tc) {
      hegelr_start_span(tc$context, tc$handle, HEGEL_LABEL_TUPLE)
      out <- lapply(gens, function(g) g$draw(tc))
      hegelr_stop_span(tc$context, tc$handle, FALSE)
      if (!is.null(.names)) {
        names(out) <- .names
      }
      out
    },
    label = sprintf("g_tuple(%s)",
      paste(vapply(gens, function(g) g$label, character(1)), collapse = ", "))
  )
}

#' @title Generate a choice among generators
#'
#' @description Draws an index with `generate_integer` inside a ONE_OF span
#'   and delegates to the corresponding generator, producing a value of one
#'   of `...gens`' types.
#'
#' @param ... Candidate generators (built by `g_*()` functions). At least
#'   one.
#'
#' @return A generator descriptor (class `hegelr_generator`).
#'
#' @examples
#' g_one_of(g_integers(), g_text(max_size = 3))
#' @export
g_one_of <- function(...) {
  gens <- list(...)
  if (!length(gens)) {
    stop("g_one_of() needs at least one generator", call. = FALSE)
  }
  lapply(seq_along(gens), function(i) {
    hegelr_validate_generator(gens[[i]], sprintf("..%d (argument %d)", i, i))
  })
  n <- length(gens)

  hegelr_generator(
    draw = function(tc) {
      hegelr_start_span(tc$context, tc$handle, HEGEL_LABEL_ONE_OF)
      idx <- hegelr_stop_for_status(
        hegelr_generate_integer(tc$context, tc$handle, 0, n - 1)
      )
      value <- gens[[idx + 1L]]$draw(tc)
      hegelr_stop_span(tc$context, tc$handle, FALSE)
      value
    },
    label = sprintf("g_one_of(%s)",
      paste(vapply(gens, function(g) g$label, character(1)), collapse = ", "))
  )
}

#' @title Generate one of a fixed set of values
#'
#' @description Draws an index with `generate_integer` inside a
#'   SAMPLED_FROM span and returns the corresponding element of the atomic
#'   vector `values`.
#'
#' @param values An atomic vector with at least one element.
#'
#' @return A generator descriptor (class `hegelr_generator`) drawing one
#'   element of `values` per case.
#'
#' @examples
#' g_sampled_from(c("alpha", "beta", "gamma"))
#' @export
g_sampled_from <- function(values) {
  if (!is.atomic(values) || !length(values) || anyNA(values)) {
    stop("`values` must be a non-empty atomic vector without missing values",
      call. = FALSE
    )
  }
  n <- length(values)

  hegelr_generator(
    draw = function(tc) {
      hegelr_start_span(tc$context, tc$handle, HEGEL_LABEL_SAMPLED_FROM)
      idx <- hegelr_stop_for_status(
        hegelr_generate_integer(tc$context, tc$handle, 0, n - 1)
      )
      value <- values[[idx + 1L]]
      hegelr_stop_span(tc$context, tc$handle, FALSE)
      value
    },
    label = sprintf("g_sampled_from(%s)", hegelr_preview(values)),
    empty = values[0]
  )
}

#' @title Generate a constant
#'
#' @description Always produces `value`; draws nothing from the engine.
#'
#' @param value Any R object, returned as-is.
#'
#' @return A generator descriptor (class `hegelr_generator`).
#'
#' @examples
#' g_just(42)
#' @export
g_just <- function(value) {
  hegelr_generator(
    draw = function(tc) value,
    label = sprintf("g_just(%s)", hegelr_preview(value))
  )
}

#' @title Transform a generator's output
#'
#' @description Draws from `gen` inside a MAPPED span and returns
#'   `f(value)`. During shrinking the whole span shrinks as one unit.
#'
#' @param gen Inner generator (built by a `g_*()` function).
#' @param f Function applied to each drawn value.
#'
#' @return A generator descriptor (class `hegelr_generator`).
#'
#' @examples
#' g_map(g_integers(0, 9), function(x) x^2)
#' @export
g_map <- function(gen, f) {
  hegelr_validate_generator(gen)
  if (!is.function(f)) {
    stop("`f` must be a function", call. = FALSE)
  }
  hegelr_generator(
    draw = function(tc) {
      hegelr_start_span(tc$context, tc$handle, HEGEL_LABEL_MAPPED)
      value <- f(gen$draw(tc))
      hegelr_stop_span(tc$context, tc$handle, FALSE)
      value
    },
    label = sprintf("g_map(%s, f)", gen$label)
  )
}

#' @title Filter a generator's output
#'
#' @description Repeatedly draws from `gen` inside a FILTER span. When
#'   `predicate` rejects a value the span is stopped with
#'   `discard = TRUE`, reverting the engine's choices for that attempt, and
#'   the draw is retried. After 3 rejected attempts (the family cap, per
#'   the Rust and Go bindings), the generator signals `hegelr_assume`,
#'   rejecting the test case (the case counts as INVALID, exactly like
#'   `tc$assume(FALSE)`); the engine's `filter_too_much` health check is
#'   the real guard against over-filtered generators.
#'
#' @param gen Inner generator (built by a `g_*()` function).
#' @param predicate Function returning `TRUE`/`FALSE` for acceptable
#'   values.
#'
#' @return A generator descriptor (class `hegelr_generator`).
#'
#' @examples
#' g_filter(g_integers(0, 100), function(x) x %% 7 == 0)
#' @export
g_filter <- function(gen, predicate) {
  hegelr_validate_generator(gen)
  if (!is.function(predicate)) {
    stop("`predicate` must be a function", call. = FALSE)
  }
  hegelr_generator(
    draw = function(tc) {
      for (attempt in seq_len(HEGELR_MAX_FILTER_ATTEMPTS)) {
        hegelr_start_span(tc$context, tc$handle, HEGEL_LABEL_FILTER)
        value <- gen$draw(tc)
        keep <- isTRUE(predicate(value))
        hegelr_stop_span(tc$context, tc$handle, !keep)
        if (keep) {
          return(value)
        }
      }
      stop(hegelr_condition(
        "hegelr_assume",
        sprintf(
          "g_filter rejected %d draws in a row; rejecting this test case",
          HEGELR_MAX_FILTER_ATTEMPTS
        )
      ))
    },
    label = sprintf("g_filter(%s, predicate)", gen$label),
    empty = gen$empty
  )
}
