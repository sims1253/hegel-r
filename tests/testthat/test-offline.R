# Offline tests: they run everywhere and never touch the libhegel engine.
# They cover argument validation (error messages are expected to name the
# offending argument), generator descriptor construction, TestCase behavior
# without a live run, and library-path resolution.

test_that("hegel_library_path() honors HEGEL_LIBHEGEL_PATH when the file exists", {
  # hegel_library_path() caches positive resolutions in package state; the
  # temp path below outlives this test, so restore the cache afterwards.
  # (R has no `pkg:::x <- y` assignment form, so go through the env.)
  pkg_env <- hegelr:::hegelr_env
  saved <- pkg_env$lib_path
  on.exit(pkg_env$lib_path <- saved, add = TRUE)

  dir <- file.path(tempdir(), "hegelr-libhegel-path")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  lib_name <- if (.Platform$OS.type == "windows") "hegel.dll" else "libhegel.so"
  lib <- file.path(dir, lib_name)
  file.create(lib)
  on.exit(unlink(dir, recursive = TRUE, force = TRUE), add = TRUE)

  local_envvar_(HEGEL_LIBHEGEL_PATH = lib)
  expect_identical(hegelr::hegel_library_path(), lib)

  # A nonexistent path must not be used verbatim: resolution falls through
  # to the cache directory, system locations, or the bare library name.
  local_envvar_(HEGEL_LIBHEGEL_PATH = file.path(dir, "does-not-exist.so"))
  resolved <- tryCatch(
    hegelr::hegel_library_path(),
    error = function(e) NA_character_
  )
  expect_false(identical(resolved, file.path(dir, "does-not-exist.so")))
})

test_that("the cache scan prefers the highest installed version", {
  pkg_env <- hegelr:::hegelr_env
  saved <- pkg_env$lib_path
  on.exit(pkg_env$lib_path <- saved, add = TRUE)

  # Redirect tools::R_user_dir()'s cache root for the scan.
  cache <- file.path(tempdir(), "hegelr-cache-scan")
  dir.create(cache, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(cache, recursive = TRUE, force = TRUE), add = TRUE)
  local_envvar_(R_USER_CACHE_DIR = cache)

  lib_name <- if (.Platform$OS.type == "windows") "hegel.dll" else "libhegel.so"
  # 0.9.2 sorts above 0.32.x as a plain string; the scan must not fall for
  # that (0.32.10 is the highest install here, not 0.9.2). R_user_dir()
  # nests the package under an "R" directory inside the cache root.
  for (v in c("0.32.1", "0.32.10", "0.9.2")) {
    dir <- file.path(cache, "R", "hegelr", "libhegel", v)
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    file.create(file.path(dir, lib_name))
  }
  pkg_env$lib_path <- NULL
  expect_identical(
    hegelr::hegel_library_path(),
    file.path(cache, "R", "hegelr", "libhegel", "0.32.10", lib_name)
  )
})

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

test_that("hegel_reproduce() requires both blob and property", {
  expect_error(hegel_reproduce(), "blob|argument")
  expect_error(hegel_reproduce("x"), "property|argument")
})

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

test_that("generators are descriptors with non-empty labels", {
  generators <- list(
    g_integers(),
    g_doubles(),
    g_logicals(),
    g_raw(),
    g_text(),
    g_characters(),
    g_from_regex("a[bc]d"),
    g_emails(),
    g_urls(),
    g_domains(),
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

test_that("generators carry typed empty prototypes for zero-length draws", {
  expect_identical(g_integers()$empty, numeric(0))
  expect_identical(g_doubles()$empty, numeric(0))
  expect_identical(g_logicals()$empty, logical(0))
  expect_identical(g_raw()$empty, raw(0))
  expect_identical(g_text()$empty, character(0))
  expect_identical(g_characters()$empty, character(0))
  expect_identical(g_from_regex("a")$empty, character(0))
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

test_that("the minimum supported engine version is 0.32.0", {
  expect_identical(hegelr:::LIBHEGEL_MIN_VERSION, "0.32.0")
})

test_that("the version gate enforces the 0.32.x engine line", {
  expect_error(hegelr:::hegelr_check_version("0.31.9"), "too old")
  expect_error(hegelr:::hegelr_check_version("0.33.0"), "incompatible")
  expect_error(hegelr:::hegelr_check_version("1.0.0"), "incompatible")
  # Patch drift warns once per process; reset the flag to observe it.
  pkg_env <- hegelr:::hegelr_env
  warned <- pkg_env$version_warned
  on.exit(pkg_env$version_warned <- warned, add = TRUE)
  pkg_env$version_warned <- FALSE
  expect_warning(hegelr:::hegelr_check_version("0.32.9"), "differs")
  expect_no_warning(hegelr:::hegelr_check_version("0.32.9"))
  expect_no_warning(hegelr:::hegelr_check_version("0.32.5"))
  expect_warning(hegelr:::hegelr_check_version("banana"), "could not parse")
})

# The exact asset list of the real hegel-rust v0.32.5 release; the installer
# must keep matching this layout (bare library files + .sha256 sidecars).
release_assets <- c(
  "libhegel-darwin-arm64.dylib",
  "libhegel-darwin-arm64.dylib.sha256",
  "libhegel-linux-amd64.so",
  "libhegel-linux-amd64.so.sha256",
  "libhegel-linux-arm64.so",
  "libhegel-linux-arm64.so.sha256",
  "libhegel-windows-amd64.dll",
  "libhegel-windows-amd64.dll.sha256",
  "libhegel-windows-arm64.dll",
  "libhegel-windows-arm64.dll.sha256"
)

test_that("the asset picker selects the right library per platform", {
  expect_identical(
    release_assets[[hegelr:::hegelr_pick_asset(release_assets, "Windows", "x86_64")]],
    "libhegel-windows-amd64.dll"
  )
  # Sys.info()"machine" on Windows reports "x86-64" with a hyphen.
  expect_identical(
    release_assets[[hegelr:::hegelr_pick_asset(release_assets, "Windows", "x86-64")]],
    "libhegel-windows-amd64.dll"
  )
  expect_identical(
    release_assets[[hegelr:::hegelr_pick_asset(release_assets, "Linux", "x86_64")]],
    "libhegel-linux-amd64.so"
  )
  expect_identical(
    release_assets[[hegelr:::hegelr_pick_asset(release_assets, "Linux", "aarch64")]],
    "libhegel-linux-arm64.so"
  )
  expect_identical(
    release_assets[[hegelr:::hegelr_pick_asset(release_assets, "Darwin", "arm64")]],
    "libhegel-darwin-arm64.dylib"
  )
})

test_that("the asset picker never picks a checksum sidecar", {
  for (spec in list(
    c("Windows", "x86_64"), c("Linux", "x86_64"), c("Darwin", "arm64")
  )) {
    picked <- release_assets[[hegelr:::hegelr_pick_asset(release_assets, spec[[1]], spec[[2]])]]
    expect_false(grepl("\\.sha256$", picked))
  }
})

test_that("the asset picker errors on unsupported platforms", {
  expect_error(
    hegelr:::hegelr_pick_asset(release_assets, "SunOS", "x86_64"),
    "unsupported platform"
  )
})

test_that("canonical library names match the resolution pattern", {
  expect_identical(hegelr:::hegelr_canonical_lib_name("Windows"), "hegel.dll")
  expect_identical(hegelr:::hegelr_canonical_lib_name("Darwin"), "libhegel.dylib")
  expect_identical(hegelr:::hegelr_canonical_lib_name("Linux"), "libhegel.so")
  for (n in c("Windows", "Darwin", "Linux")) {
    expect_true(grepl(
      hegelr:::hegelr_lib_pattern(),
      hegelr:::hegelr_canonical_lib_name(n)
    ))
  }
})

test_that("GitHub headers carry a bearer token when one is set", {
  # CI exports GITHUB_PAT/GITHUB_TOKEN; unset both so the baseline is
  # hermetic in any environment.
  local_envvar_(GITHUB_PAT = NA, GITHUB_TOKEN = NA)
  headers <- hegelr:::hegelr_github_headers()
  expect_false("Authorization" %in% names(headers))
  expect_identical(headers[["User-Agent"]], "hegelr (R package)")

  local_envvar_(GITHUB_PAT = "secret-token")
  headers <- hegelr:::hegelr_github_headers()
  expect_identical(headers[["Authorization"]], "Bearer secret-token")

  # GITHUB_PAT wins when both are set; GITHUB_TOKEN applies alone.
  local_envvar_(GITHUB_TOKEN = "other-token")
  expect_identical(
    hegelr:::hegelr_github_headers()[["Authorization"]],
    "Bearer secret-token"
  )
  local_envvar_(GITHUB_PAT = NA)
  expect_identical(
    hegelr:::hegelr_github_headers()[["Authorization"]],
    "Bearer other-token"
  )
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
