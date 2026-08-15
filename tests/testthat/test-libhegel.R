# Tests for R/libhegel.R — engine library resolution, the version gate, and
# the hegel_install() asset selection. All offline: no engine, no network.

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
