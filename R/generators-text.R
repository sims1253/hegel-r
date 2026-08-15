# Text generators. All are backed by
# engine string generators: immutable, shareable handles cached per schema
# for the process lifetime via hegelr_stringgen() (bindings.R). The handles
# are constructed against the dedicated cache context, never a run context.
#
# Engine strings may contain interior NULs; the shim truncates at the first
# NUL for R (documented ABI caveat) and marks everything UTF-8.

hegelr_max_codepoint <- 2^32 - 1

# Shared implementation for g_text()/g_characters(): validates constraints,
# builds the schema cache key, and returns the draw closure for a text
# string generator with the given size bounds (Inf max = unbounded,
# sentineled to the ABI-safe 2^53 by hegelr_collection_bounds()).
hegelr_text_generator <- function(min_size, max_size, codec, min_codepoint,
                                  max_codepoint, categories,
                                  exclude_categories, include_characters,
                                  exclude_characters, alphabet) {
  bounds <- hegelr_collection_bounds(min_size, max_size)
  min_size <- bounds[["min"]]
  max_size <- bounds[["max"]]
  min_codepoint <- hegelr_validate_number(min_codepoint, "min_codepoint",
    min = 0, max = hegelr_max_codepoint, whole = TRUE
  )
  max_codepoint <- hegelr_validate_number(max_codepoint, "max_codepoint",
    min = 0, max = hegelr_max_codepoint, whole = TRUE
  )
  if (min_codepoint > max_codepoint) {
    stop("`min_codepoint` must be less than or equal to `max_codepoint`",
      call. = FALSE
    )
  }
  codec <- hegelr_validate_string(codec, "codec", nullable = TRUE)
  categories <- hegelr_validate_char_vector(categories, "categories")
  exclude_categories <- hegelr_validate_char_vector(
    exclude_categories, "exclude_categories"
  )
  include_characters <- hegelr_validate_string(
    include_characters, "include_characters", nullable = TRUE
  )
  exclude_characters <- hegelr_validate_string(
    exclude_characters, "exclude_characters", nullable = TRUE
  )
  alphabet <- hegelr_validate_string(alphabet, "alphabet", nullable = TRUE)
  if (!is.null(alphabet) && !is.null(include_characters)) {
    stop("pass either `alphabet` or `include_characters`, not both",
      call. = FALSE
    )
  }
  if (!is.null(alphabet)) {
    include_characters <- alphabet
  }

  # Schema digest: cache key for the shared string-generator handle.
  schema <- list(
    min_size = min_size, max_size = max_size, codec = codec,
    min_codepoint = min_codepoint, max_codepoint = max_codepoint,
    categories = categories, exclude_categories = exclude_categories,
    include_characters = include_characters,
    exclude_characters = exclude_characters
  )
  key <- paste(deparse(schema), collapse = "")

  list(
    key = key,
    draw = function(tc) {
      sg <- hegelr_stringgen(key, function(ctx) {
        hegelr_string_generator_text(
          ctx, min_size, max_size, codec, min_codepoint, max_codepoint,
          categories, exclude_categories,
          include_characters, exclude_characters
        )
      })
      hegelr_stop_for_status(
        hegelr_generate_string(tc$context, sg, tc$handle)
      )
    }
  )
}

#' @title Generate text strings
#'
#' @description Draws strings with a length in `[min_size, max_size]`
#'   (unbounded above by default, per the family's `text()`) from
#'   codepoints in `[min_codepoint, max_codepoint]`, optionally restricted
#'   to (or excluding) Unicode categories and character sets. Backed by
#'   the engine's text string generator.
#'
#'   `alphabet` is sugar for `include_characters`: a string whose
#'   characters form the allowed set. Pass either `alphabet` or
#'   `include_characters`, not both.
#'
#' @param min_size Minimum string length (whole number `>= 0`).
#' @param max_size Maximum string length (whole number `>= 0`, or `Inf` for
#'   unbounded - the default).
#' @param codec Encoding hint, `"utf-8"` by default, or `NULL` for the
#'   engine default.
#' @param min_codepoint Smallest allowed codepoint (default 0).
#' @param max_codepoint Largest allowed codepoint (default `2^32 - 1`).
#' @param categories Optional character vector of allowed Unicode
#'   categories.
#' @param exclude_categories Optional character vector of excluded Unicode
#'   categories.
#' @param include_characters Optional string of always-allowed characters.
#' @param exclude_characters Optional string of excluded characters.
#' @param alphabet Optional string of allowed characters; sugar for
#'   `include_characters`.
#'
#' @return A generator descriptor (class `hegelr_generator`) drawing one
#'   character string per case.
#'
#' @examples
#' g_text(max_size = 8)
#' g_text(alphabet = "abc")
#' @export
g_text <- function(min_size = 0, max_size = Inf, codec = "utf-8",
                   min_codepoint = 0, max_codepoint = 2^32 - 1,
                   categories = NULL, exclude_categories = NULL,
                   include_characters = NULL, exclude_characters = NULL,
                   alphabet = NULL) {
  gen <- hegelr_text_generator(
    min_size, max_size, codec, min_codepoint, max_codepoint,
    categories, exclude_categories, include_characters,
    exclude_characters, alphabet
  )
  hegelr_generator(
    draw = gen$draw,
    label = hegelr_label("g_text", min_size = min_size, max_size = max_size),
    empty = character(0)
  )
}

#' @title Generate single characters
#'
#' @description Draws a single character (one Unicode codepoint) per case -
#'   the family's `characters()`: a text generator fixed to length 1.
#'   Constraint parameters are identical to [g_text()].
#'
#' @param codec Encoding hint, `"utf-8"` by default, or `NULL` for the
#'   engine default.
#' @param min_codepoint Smallest allowed codepoint (default 0).
#' @param max_codepoint Largest allowed codepoint (default `2^32 - 1`).
#' @param categories Optional character vector of allowed Unicode
#'   categories.
#' @param exclude_categories Optional character vector of excluded Unicode
#'   categories.
#' @param include_characters Optional string of always-allowed characters.
#' @param exclude_characters Optional string of excluded characters.
#' @param alphabet Optional string of allowed characters; sugar for
#'   `include_characters`.
#'
#' @return A generator descriptor (class `hegelr_generator`) drawing one
#'   single-character string per case.
#'
#' @examples
#' g_characters(categories = c("Lu", "Ll"))
#' @export
g_characters <- function(codec = "utf-8", min_codepoint = 0,
                         max_codepoint = 2^32 - 1, categories = NULL,
                         exclude_categories = NULL,
                         include_characters = NULL,
                         exclude_characters = NULL, alphabet = NULL) {
  gen <- hegelr_text_generator(
    1, 1, codec, min_codepoint, max_codepoint,
    categories, exclude_categories, include_characters,
    exclude_characters, alphabet
  )
  hegelr_generator(
    draw = gen$draw,
    label = "g_characters()",
    empty = character(0)
  )
}

#' @title Generate strings matching a regular expression
#'
#' @description Draws strings matching `pattern`, via the engine's regex
#'   string generator.
#'
#' @param pattern A single regular expression string.
#' @param fullmatch When `TRUE` (the default) the whole string must match;
#'   otherwise a partial match suffices.
#'
#' @return A generator descriptor (class `hegelr_generator`) drawing one
#'   character string per case.
#'
#' @examples
#' g_from_regex("[a-z]{3,8}")
#' @export
g_from_regex <- function(pattern, fullmatch = TRUE) {
  pattern <- hegelr_validate_string(pattern, "pattern")
  fullmatch <- hegelr_validate_flag(fullmatch, "fullmatch")
  key <- paste(
    deparse(list(pattern = pattern, fullmatch = fullmatch)),
    collapse = ""
  )
  hegelr_generator(
    draw = function(tc) {
      sg <- hegelr_stringgen(key, function(ctx) {
        hegelr_string_generator_regex(ctx, pattern, fullmatch)
      })
      hegelr_stop_for_status(
        hegelr_generate_string(tc$context, sg, tc$handle)
      )
    },
    label = sprintf("g_from_regex(%s)", hegelr_fmt(pattern)),
    empty = character(0)
  )
}

#' @title Generate email addresses
#'
#' @description Draws syntactically valid email addresses via the engine's
#'   email string generator.
#'
#' @return A generator descriptor (class `hegelr_generator`) drawing one
#'   character string per case.
#'
#' @examples
#' g_emails()
#' @export
g_emails <- function() {
  key <- "stringgen:email"
  hegelr_generator(
    draw = function(tc) {
      sg <- hegelr_stringgen(key, function(ctx) {
        hegelr_string_generator_email(ctx)
      })
      hegelr_stop_for_status(
        hegelr_generate_string(tc$context, sg, tc$handle)
      )
    },
    label = "g_emails()",
    empty = character(0)
  )
}

#' @title Generate URLs
#'
#' @description Draws syntactically valid URLs via the engine's URL string
#'   generator.
#'
#' @return A generator descriptor (class `hegelr_generator`) drawing one
#'   character string per case.
#'
#' @examples
#' g_urls()
#' @export
g_urls <- function() {
  key <- "stringgen:url"
  hegelr_generator(
    draw = function(tc) {
      sg <- hegelr_stringgen(key, function(ctx) {
        hegelr_string_generator_url(ctx)
      })
      hegelr_stop_for_status(
        hegelr_generate_string(tc$context, sg, tc$handle)
      )
    },
    label = "g_urls()",
    empty = character(0)
  )
}

#' @title Generate domain names
#'
#' @description Draws syntactically valid domain names of at most
#'   `max_length` characters, via the engine's domain string generator.
#'
#' @param max_length Maximum domain length (whole number `>= 1`). Defaults
#'   to 255.
#'
#' @return A generator descriptor (class `hegelr_generator`) drawing one
#'   character string per case.
#'
#' @examples
#' g_domains(max_length = 63)
#' @export
g_domains <- function(max_length = 255) {
  max_length <- hegelr_validate_number(max_length, "max_length",
    min = 1, max = hegelr_max_integer, whole = TRUE
  )
  key <- paste(deparse(list(max_length = max_length)), collapse = "")
  hegelr_generator(
    draw = function(tc) {
      sg <- hegelr_stringgen(key, function(ctx) {
        hegelr_string_generator_domain(ctx, max_length)
      })
      hegelr_stop_for_status(
        hegelr_generate_string(tc$context, sg, tc$handle)
      )
    },
    label = hegelr_label("g_domains", max_length = max_length),
    empty = character(0)
  )
}
