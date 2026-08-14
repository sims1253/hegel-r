# Primitive generators (ARCHITECTURE.md section 5 table) plus the shared
# validation / status / label helpers used by every generator file.
#
# The generator descriptor protocol (draw / label / empty) is documented on
# hegelr_generator() below.

# Integers cross the C boundary as R doubles restricted to the u64-safe
# subset: whole numbers with absolute value <= 2^53 (ARCHITECTURE.md
# section 4). Also used as the "no upper bound" sentinel for collection
# sizes.
hegelr_max_integer <- 2^53

# --- status translation -------------------------------------------------

# Translate a draw result's status field per ARCHITECTURE.md section 5:
# 0 -> return the value; -1 -> signal hegelr_stop_test (case OVERRUN);
# -2 -> signal hegelr_assume (case INVALID). Other codes never reach R (the
# shim raises them as errors directly), so hitting the default is a bug.
hegelr_stop_for_status <- function(res) {
  status <- as.integer(res$status)
  if (identical(status, 0L)) {
    return(res$value)
  }
  if (identical(status, -1L)) {
    stop(hegelr_condition(
      "hegelr_stop_test", "engine choice budget exhausted"
    ))
  }
  if (identical(status, -2L)) {
    stop(hegelr_condition(
      "hegelr_assume", "engine assumption rejected this test case"
    ))
  }
  stop(sprintf("unexpected engine draw status: %s", status), call. = FALSE)
}

# --- eager argument validation -------------------------------------------

hegelr_validate_scalar <- function(x, name) {
  if (is.null(x) || length(x) != 1L || is.na(x)) {
    stop(sprintf("`%s` must be a single non-missing value", name), call. = FALSE)
  }
  invisible(TRUE)
}

hegelr_validate_number <- function(x, name, min = -Inf, max = Inf, whole = FALSE) {
  hegelr_validate_scalar(x, name)
  if (!is.numeric(x)) {
    stop(sprintf("`%s` must be a number", name), call. = FALSE)
  }
  if (x < min || x > max) {
    stop(sprintf("`%s` must be between %s and %s", name, min, max), call. = FALSE)
  }
  if (isTRUE(whole) && x != floor(x)) {
    stop(sprintf("`%s` must be a whole number", name), call. = FALSE)
  }
  as.numeric(x)
}

hegelr_validate_flag <- function(x, name) {
  if (is.null(x) || length(x) != 1L || is.na(x) || !is.logical(x)) {
    stop(sprintf("`%s` must be TRUE or FALSE", name), call. = FALSE)
  }
  x
}

hegelr_validate_string <- function(x, name, nullable = FALSE) {
  if (is.null(x)) {
    if (isTRUE(nullable)) return(NULL)
    stop(sprintf("`%s` must not be NULL", name), call. = FALSE)
  }
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    stop(sprintf("`%s` must be a single non-empty string", name), call. = FALSE)
  }
  x
}

hegelr_validate_char_vector <- function(x, name) {
  if (is.null(x)) return(NULL)
  if (!is.character(x) || !length(x) || anyNA(x)) {
    stop(sprintf(
      "`%s` must be NULL or a non-empty character vector without missing values",
      name
    ), call. = FALSE)
  }
  x
}

hegelr_validate_generator <- function(gen, name = "gen") {
  if (!inherits(gen, "hegelr_generator")) {
    stop(sprintf(
      "`%s` must be a hegelr generator (built by a g_*() function)", name
    ), call. = FALSE)
  }
  invisible(TRUE)
}

# --- labels ---------------------------------------------------------------

# Compact scalar rendering for generator labels. AsIs (I()) suppresses the
# quoting applied to plain character values, so an inner generator's label
# embeds unquoted: g_vectors(g_integers(), min_size = 1).
hegelr_fmt <- function(x) {
  if (is.null(x)) return("NULL")
  if (inherits(x, "AsIs")) return(paste0(x, collapse = ""))
  if (is.character(x)) return(paste0('"', paste(x, collapse = ""), '"'))
  if (is.logical(x)) return(as.character(x))
  if (length(x) != 1L || is.na(x)) return(hegelr_preview(x))
  if (is.infinite(x)) return(if (x > 0) "Inf" else "-Inf")
  if (x == floor(x) && abs(x) < 1e15) {
    format(x, trim = TRUE, drop0trailing = TRUE, scientific = FALSE)
  } else {
    format(x, trim = TRUE, digits = 6)
  }
}

# Build a label like "g_integers(min = -100, max = 100)" from named args.
# Arguments still at their defaults (named in `.defaults`) are omitted so
# draw-report lines stay readable: `g_integers()`, not
# `g_integers(min = -9007199254740992, max = 9007199254740992)`.
hegelr_label <- function(name, ..., .defaults = list()) {
  args <- list(...)
  if (length(args)) {
    keep <- vapply(seq_along(args), function(i) {
      nm <- names(args)[[i]]
      !(nm %in% names(.defaults) && identical(args[[i]], .defaults[[nm]]))
    }, logical(1))
    args <- args[keep]
  }
  if (!length(args)) {
    return(paste0(name, "()"))
  }
  parts <- vapply(
    seq_along(args),
    function(i) paste0(names(args)[[i]], " = ", hegelr_fmt(args[[i]])),
    character(1)
  )
  paste0(name, "(", paste(parts, collapse = ", "), ")")
}

# The generator descriptor protocol: a list of class "hegelr_generator" with
# elements `draw = function(tc) value` (tc is the hegelr_test_case
# environment; draw calls the .Call bindings with tc$context and tc$handle),
# `label = "short name"` (used in draw reports), and `empty`: a typed empty
# prototype of the produced type (`numeric(0)`, `raw(0)`, ...) or NULL when
# the type is unknowable without drawing (e.g. g_map's transform output).
# g_vectors returns `empty` for zero-length draws: R's `x[[i]] <- NULL`
# deletes list entries, so a NULL empty silently corrupts caller-side
# collections.
hegelr_generator <- function(draw, label, empty = NULL) {
  structure(
    list(draw = draw, label = label, empty = empty),
    class = "hegelr_generator"
  )
}

# --- generators --------------------------------------------------------------

#' @title Generate integers
#'
#' @description Draws integers in `[min, max]` (both inclusive). Values are
#'   returned as R **doubles**: the ABI carries integers as doubles
#'   restricted to the u64-safe subset (whole numbers with `|x| <= 2^53`).
#'   `g_integers()` cannot produce or accept anything outside that range.
#'
#' @param min Lower bound (whole number, `>= -2^53`). Defaults to `-2^53`.
#' @param max Upper bound (whole number, `<= 2^53`). Defaults to `2^53`.
#'
#' @return A generator descriptor (class `hegelr_generator`) drawing one
#'   numeric value per [hegel_test()] case.
#'
#' @examples
#' # Building a generator needs no engine; gen$label previews the draw
#' # report.
#' gen <- g_integers(1, 10)
#' gen$label
#' @export
g_integers <- function(min = -2^53, max = 2^53) {
  min <- hegelr_validate_number(min, "min",
    min = -hegelr_max_integer, max = hegelr_max_integer, whole = TRUE
  )
  max <- hegelr_validate_number(max, "max",
    min = -hegelr_max_integer, max = hegelr_max_integer, whole = TRUE
  )
  if (min > max) {
    stop("`min` must be less than or equal to `max`", call. = FALSE)
  }
  hegelr_generator(
    draw = function(tc) {
      hegelr_stop_for_status(
        hegelr_generate_integer(tc$context, tc$handle, min, max)
      )
    },
    label = hegelr_label("g_integers", min = min, max = max,
      .defaults = list(min = -2^53, max = 2^53)),
    empty = numeric(0)
  )
}

#' @title Generate doubles
#'
#' @description Draws doubles in `[min, max]`, backed by the engine's
#'   `generate_float` primitive (64-bit width). `allow_nan` and
#'   `allow_infinity` default to `NULL`, resolved per the family rule: NaN
#'   only when the range is unbounded on both ends, infinities only when
#'   at least one end is unbounded. (Go: "true when no bounds are set,
#'   false otherwise"; TypeScript: NaN when *neither* side is bounded,
#'   infinity when *either* side is open.) Pass `TRUE`/`FALSE` to decide
#'   explicitly.
#'
#' @param min Lower bound. Defaults to `-Inf`.
#' @param max Upper bound. Defaults to `Inf`.
#' @param allow_nan Whether NaN may be generated (`NULL` = family
#'   conditional default).
#' @param allow_infinity Whether infinite values may be generated (`NULL`
#'   = family conditional default).
#' @param exclude_min Exclude `min` itself from the range (finite `min`
#'   only).
#' @param exclude_max Exclude `max` itself from the range (finite `max`
#'   only).
#' @param smallest_nonzero Smallest nonzero magnitude the engine will
#'   produce; a positive finite number (default `5e-324`).
#'
#' @return A generator descriptor (class `hegelr_generator`) drawing one
#'   double per case.
#'
#' @examples
#' gen <- g_doubles(0, 1, smallest_nonzero = 1e-10)
#' gen$label
#' @export
g_doubles <- function(min = -Inf, max = Inf, allow_nan = NULL,
                      allow_infinity = NULL, exclude_min = FALSE,
                      exclude_max = FALSE, smallest_nonzero = 5e-324) {
  hegelr_validate_scalar(min, "min")
  hegelr_validate_scalar(max, "max")
  if (is.nan(min) || is.nan(max)) {
    stop("`min` and `max` must not be NaN", call. = FALSE)
  }
  if (min > max) {
    stop("`min` must be less than or equal to `max`", call. = FALSE)
  }
  has_min <- is.finite(min)
  has_max <- is.finite(max)
  allow_nan <- allow_nan %||% (!has_min && !has_max)
  allow_nan <- hegelr_validate_flag(allow_nan, "allow_nan")
  allow_infinity <- allow_infinity %||% (!has_min || !has_max)
  allow_infinity <- hegelr_validate_flag(allow_infinity, "allow_infinity")
  exclude_min <- hegelr_validate_flag(exclude_min, "exclude_min")
  exclude_max <- hegelr_validate_flag(exclude_max, "exclude_max")
  smallest_nonzero <- hegelr_validate_number(smallest_nonzero, "smallest_nonzero",
    min = 0, max = Inf, whole = FALSE
  )
  if (smallest_nonzero <= 0) {
    stop("`smallest_nonzero` must be positive", call. = FALSE)
  }
  if (is.infinite(min) && !isTRUE(allow_infinity)) {
    stop("min = -Inf requires `allow_infinity = TRUE`", call. = FALSE)
  }
  if (is.infinite(max) && !isTRUE(allow_infinity)) {
    stop("max = Inf requires `allow_infinity = TRUE`", call. = FALSE)
  }
  if (isTRUE(exclude_min) && !is.finite(min)) {
    stop("`exclude_min = TRUE` requires a finite `min`", call. = FALSE)
  }
  if (isTRUE(exclude_max) && !is.finite(max)) {
    stop("`exclude_max = TRUE` requires a finite `max`", call. = FALSE)
  }
  hegelr_generator(
    draw = function(tc) {
      hegelr_stop_for_status(hegelr_generate_float(
        tc$context, tc$handle, min, max,
        allow_nan, allow_infinity, exclude_min, exclude_max, smallest_nonzero
      ))
    },
    label = hegelr_label("g_doubles", min = min, max = max,
      .defaults = list(min = -Inf, max = Inf)),
    empty = numeric(0)
  )
}

#' @title Generate logicals
#'
#' @description Draws `TRUE`/`FALSE` values, with `TRUE` probability `p`,
#'   backed by the engine's `generate_boolean` primitive.
#'
#' @param p Probability of drawing `TRUE`; a single number in `[0, 1]`.
#'
#' @return A generator descriptor (class `hegelr_generator`) drawing one
#'   logical value per case.
#'
#' @examples
#' gen <- g_logicals(p = 0.25)
#' gen$label
#' @export
g_logicals <- function(p = 0.5) {
  p <- hegelr_validate_number(p, "p", min = 0, max = 1)
  hegelr_generator(
    draw = function(tc) {
      hegelr_stop_for_status(
        hegelr_generate_boolean(tc$context, tc$handle, p)
      )
    },
    label = hegelr_label("g_logicals", p = p, .defaults = list(p = 0.5)),
    empty = logical(0)
  )
}

#' @title Generate raw byte vectors
#'
#' @description Draws raw vectors with a length chosen by the engine in
#'   `[min_size, max_size]`, backed by the engine's `generate_bytes`
#'   primitive. `max_size = Inf` (the default) means unbounded, matching
#'   the Go and TypeScript bindings' `Binary` defaults; the engine's own
#'   size budget and health checks cap what is generated.
#'
#' @param min_size Minimum length (whole number `>= 0`).
#' @param max_size Maximum length (whole number `>= 0`, or `Inf` for
#'   unbounded).
#'
#' @return A generator descriptor (class `hegelr_generator`) drawing one
#'   raw vector per case.
#'
#' @examples
#' gen <- g_raw(0, 16)
#' gen$label
#' @export
g_raw <- function(min_size = 0, max_size = Inf) {
  min_size <- hegelr_validate_number(min_size, "min_size",
    min = 0, max = hegelr_max_integer, whole = TRUE
  )
  if (is.infinite(max_size)) {
    max_size <- hegelr_max_integer
  } else {
    max_size <- hegelr_validate_number(max_size, "max_size",
      min = 0, max = hegelr_max_integer, whole = TRUE
    )
  }
  if (min_size > max_size) {
    stop("`min_size` must be less than or equal to `max_size`", call. = FALSE)
  }
  hegelr_generator(
    draw = function(tc) {
      hegelr_stop_for_status(
        hegelr_generate_bytes(tc$context, tc$handle, min_size, max_size)
      )
    },
    label = hegelr_label("g_raw", min_size = min_size, max_size = max_size,
      .defaults = list(min_size = 0, max_size = Inf)),
    empty = raw(0)
  )
}
