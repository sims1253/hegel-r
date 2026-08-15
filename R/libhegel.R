# Engine library resolution, loading, version gating and installation.
# The resolution order is documented on hegel_library_path().

# The oldest libhegel ABI hegelr can drive. Loading an older engine is an
# error (the shim resolves symbols that may not exist there).
LIBHEGEL_MIN_VERSION <- "0.32.0"

# The exact engine version hegelr was written against. A different version
# loads (after passing the minimum gate) but emits a once-per-process
# warning so users know behavior may drift.
LIBHEGEL_PINNED_VERSION <- "0.32.5"

# Filename pattern identifying the engine inside an extracted install (and
# during cache-dir scanning).
hegelr_lib_pattern <- function() {
  "^(libhegel\\.(so|dylib)|hegel\\.dll)$"
}

# Step 4 of the resolution order: a bare library name, letting the OS
# loader search `PATH` / the standard system directories (notably Windows
# `LoadLibrary` semantics). The soname is chosen per platform so that
# Unix `dlopen()` can also find it.
hegelr_bare_library_name <- function() {
  switch(Sys.info()[["sysname"]],
    Windows = "hegel", # LoadLibrary() appends .dll
    Darwin = "libhegel.dylib",
    "libhegel.so"
  )
}

#' @title Resolve the path of the libhegel engine library
#'
#' @description `hegel_library_path()` locates the native libhegel engine
#'   without loading it. Candidates are tried in this order:
#'
#' 1. The `HEGEL_LIBHEGEL_PATH` environment variable, when it points at an
#'    existing file.
#' 2. Installs managed by [hegel_install()]: the highest-versioned
#'    `libhegel/<version>/` directory under `tools::R_user_dir("hegelr",
#'    "cache")`. An `installed.rds` marker (written by `hegel_install()`)
#'    is honored first; otherwise the directory is searched recursively for
#'    `libhegel.so`, `libhegel.dylib` or `hegel.dll`.
#' 3. Standard system locations on Unix-alikes: `/usr/local/lib`,
#'    `/usr/lib`, `/opt/homebrew/lib`, `/usr/local/homebrew/lib`.
#' 4. A bare library name, letting the OS loader search `PATH` and the
#'    system directories.
#'
#' Only positive resolutions (steps 1-3) are cached for the process; the
#' bare-name fallback is returned uncached, so resolution still finds a
#' later install or environment-variable change.
#'
#' @return A character string: an absolute library file path, or a bare
#'   library name if no file was found (in which case loading may still
#'   succeed via the OS loader).
#'
#' @examples
#' cat("libhegel resolves to:", hegel_library_path(), "\n")
#' @export
hegel_library_path <- function() {
  # 1. Explicit override. Checked before the cache so setting the env var
  # later in the session always wins (a cached engine install must not mask
  # a user's local build).
  env <- Sys.getenv("HEGEL_LIBHEGEL_PATH", unset = "")
  if (nzchar(env) && file.exists(env)) {
    hegelr_env$lib_path <- env
    return(env)
  }

  if (!is.null(hegelr_env$lib_path)) {
    return(hegelr_env$lib_path)
  }

  # 2. Installs managed by hegel_install() under the user cache dir.
  # Version directories are tried from highest to lowest, so a broken
  # highest install (e.g. a stale marker or a partial extraction) falls
  # through to the next one instead of dead-ending the search.
  root <- file.path(tools::R_user_dir("hegelr", "cache"), "libhegel")
  if (dir.exists(root)) {
    versions <- list.dirs(root, recursive = FALSE, full.names = FALSE)
    parsed <- lapply(versions, function(v) {
      tryCatch(numeric_version(v), error = function(e) NULL)
    })
    ok <- !vapply(parsed, is.null, logical(1))
    if (any(ok)) {
      candidates <- versions[ok]
      vers <- parsed[ok]
      # numeric_version objects are not sortable as a vector; a zero-padded
      # component key sorts lexicographically the same as numerically, so
      # plain order() ranks the installs highest-first. (Unpadded strings
      # would rank 0.9.x above 0.10.x.)
      key <- vapply(vers, function(v) {
        paste(sprintf("%06d", unclass(v)[[1L]]), collapse = ".")
      }, character(1))
      ordered <- order(key, decreasing = TRUE)
      for (dir in file.path(root, candidates[ordered])) {
        # Marker file first: hegel_install() writes installed.rds next to
        # the dll so nested layouts resolve without a recursive scan.
        marker <- file.path(dir, "installed.rds")
        if (file.exists(marker)) {
          marked <- tryCatch(readRDS(marker), error = function(e) NULL)
          if (is.character(marked) && length(marked) == 1L &&
            !is.na(marked) && file.exists(marked)) {
            hegelr_env$lib_path <- marked
            return(marked)
          }
        }
        found <- list.files(dir, pattern = hegelr_lib_pattern(),
          recursive = TRUE, full.names = TRUE)
        if (length(found)) {
          # Prefer the shallowest hit (the canonical root library).
          lib <- found[[which.min(nchar(found))]]
          hegelr_env$lib_path <- lib
          return(lib)
        }
      }
    }
  }

  # 3. Standard system locations on Unix-alikes.
  if (.Platform$OS.type == "unix") {
    for (dir in c(
      "/usr/local/lib", "/usr/lib",
      "/opt/homebrew/lib", "/usr/local/homebrew/lib"
    )) {
      for (name in c("libhegel.so", "libhegel.dylib", "hegel.dll")) {
        cand <- file.path(dir, name)
        if (file.exists(cand)) {
          hegelr_env$lib_path <- cand
          return(cand)
        }
      }
    }
  }

  # 4. Bare name for the OS loader.
  hegelr_bare_library_name()
}

# Version gate, matching the family's enforcement strength: a hard error
# below LIBHEGEL_MIN_VERSION and on any major.minor mismatch with the
# pinned version (the TypeScript binding hard-fails unless major.minor
# matches; Rust's Cargo pin makes mismatch impossible). A patch-level
# difference loads with a once-per-process warning. Unparseable versions
# only warn (and skip the comparisons) - they cannot be ordered.
hegelr_check_version <- function(version) {
  parsed <- tryCatch(numeric_version(version), error = function(e) NULL)
  if (is.null(parsed)) {
    warning(sprintf(
      "could not parse libhegel version %s; skipping the version gate",
      version
    ), call. = FALSE)
    return(invisible(NULL))
  }
  pinned <- numeric_version(LIBHEGEL_PINNED_VERSION)
  if (parsed < numeric_version(LIBHEGEL_MIN_VERSION)) {
    stop(sprintf(
      paste0(
        "libhegel %s is too old: hegelr requires at least %s. ",
        "Run hegelr::hegel_install() or point HEGEL_LIBHEGEL_PATH at a newer build."
      ),
      version, LIBHEGEL_MIN_VERSION
    ), call. = FALSE)
  }
  mm <- function(v) {
    # First two components (major.minor) of a parsed version. unclass()
    # gives the integer component vector; subsetting the numeric_version
    # itself before unclass() does not restrict it.
    unclass(v)[[1L]][1:2]
  }
  if (!identical(mm(parsed), mm(pinned))) {
    stop(sprintf(
      paste0(
        "libhegel %s is incompatible: hegelr targets the %s.%s engine ABI. ",
        "Run hegelr::hegel_install() to fetch a matching engine, or point ",
        "HEGEL_LIBHEGEL_PATH at a %s.%s build."
      ),
      version, mm(pinned)[[1L]], mm(pinned)[[2L]],
      mm(pinned)[[1L]], mm(pinned)[[2L]]
    ), call. = FALSE)
  }
  if (parsed != pinned && !isTRUE(hegelr_env$version_warned)) {
    hegelr_env$version_warned <- TRUE
    warning(sprintf(
      paste0(
        "libhegel %s differs from version %s, which hegelr was written ",
        "against; behavior may differ"
      ),
      version, LIBHEGEL_PINNED_VERSION
    ), call. = FALSE)
  }
  invisible(NULL)
}

#' @title Load the libhegel engine
#' @keywords internal
#'
#' @description Loads the engine through the compiled shim, at the path
#'   resolved by [hegel_library_path()], and records the engine version.
#'   The call is idempotent: once the engine is loaded (and has passed the
#'   version gate) later calls are no-ops. Every public entry point
#'   ([hegel_test()], [hegel_version()], ...) calls this automatically.
#'
#' @return `TRUE`, invisibly.
hegel_load <- function() {
  if (isTRUE(hegelr_env$lib_loaded)) {
    return(invisible(TRUE))
  }
  path <- hegel_library_path()
  hegelr_load(path) # thin .Call wrapper; errors name missing symbols
  version <- hegelr_version()
  hegelr_check_version(version)
  hegelr_env$engine_version <- version
  hegelr_env$lib_loaded <- TRUE
  invisible(TRUE)
}

#' @title Report the libhegel engine version
#'
#' @description Loads the engine (via [hegel_load()]) and returns its
#'   version string.
#'
#' @return A character string, e.g. `"0.32.5"`.
#'
#' @examples
#' if (hegel_library_available()) {
#'   hegel_version()
#' }
#' @export
hegel_version <- function() {
  hegel_load()
  hegelr_env$engine_version
}

#' @title Check whether the libhegel engine can be loaded
#'
#' @description Returns `TRUE` when a library path resolves *and* the
#'   engine loads successfully (including the version gate). It never
#'   signals - any error from resolution or loading is caught and mapped
#'   to `FALSE` - so it is safe to call unconditionally, e.g. to guard
#'   examples or tests.
#'
#' @return `TRUE` or `FALSE`.
#'
#' @examples
#' if (hegel_library_available()) {
#'   cat("engine ready, version", hegel_version(), "\n")
#' } else {
#'   cat("engine absent; run hegel_install() to fetch it\n")
#' }
#' @export
hegel_library_available <- function() {
  tryCatch(
    {
      suppressWarnings(hegel_load())
      TRUE
    },
    error = function(e) FALSE
  )
}

# --- hegel_install() helpers ------------------------------------------------

# Custom headers for every download.file() call: the GitHub API rejects
# requests without a User-Agent, and GITHUB_PAT / GITHUB_TOKEN (when set)
# is sent as a bearer token so authenticated requests get the higher API
# rate limit instead of the 60/hour unauthenticated cap.
hegelr_github_headers <- function(accept = NULL) {
  headers <- c(`User-Agent` = "hegelr (R package)")
  token <- Sys.getenv("GITHUB_PAT")
  if (!nzchar(token)) {
    token <- Sys.getenv("GITHUB_TOKEN")
  }
  if (nzchar(token)) {
    headers <- c(headers, c(Authorization = paste("Bearer", token)))
  }
  if (!is.null(accept)) {
    headers <- c(headers, c(Accept = accept))
  }
  headers
}

# Download `url` to `dest` via download.file(method = "libcurl"), which
# supports custom headers on every platform. Errors are re-raised with the
# URL included.
hegelr_download <- function(url, dest, headers) {
  status <- tryCatch(
    suppressWarnings(utils::download.file(
      url, dest, mode = "wb", method = "libcurl",
      headers = headers, quiet = TRUE
    )),
    error = function(e) {
      stop(sprintf("failed to download %s: %s", url, conditionMessage(e)),
        call. = FALSE
      )
    }
  )
  if (!identical(as.integer(status), 0L)) {
    stop(sprintf("failed to download %s (exit status %s)", url, status),
      call. = FALSE
    )
  }
  if (!file.exists(dest) || file.info(dest)$size == 0) {
    stop(sprintf("download of %s produced an empty file", url), call. = FALSE)
  }
  invisible(TRUE)
}

# Fetch a single release object from the GitHub API. Uses the small
# per-release endpoints (releases/latest, releases/tags/<tag>) rather than
# the full release list, whose ~600 KB response truncates through
# download.file() on some platforms (observed on Windows). A specific
# version is tried as both "v<prefix>" and bare tags; all download/parse
# failures fall through to one clear error.
hegelr_github_release <- function(version) {
  urls <- if (identical(version, "latest")) {
    "https://api.github.com/repos/hegeldev/hegel-rust/releases/latest"
  } else {
    c(
      sprintf(
        "https://api.github.com/repos/hegeldev/hegel-rust/releases/tags/v%s",
        version
      ),
      sprintf(
        "https://api.github.com/repos/hegeldev/hegel-rust/releases/tags/%s",
        version
      )
    )
  }
  for (url in urls) {
    release <- tryCatch({
      tmp <- tempfile(fileext = ".json")
      on.exit(unlink(tmp), add = TRUE)
      hegelr_download(
        url, tmp, hegelr_github_headers(accept = "application/vnd.github+json")
      )
      txt <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
      jsonlite::fromJSON(txt, simplifyVector = FALSE)
    }, error = function(e) NULL)
    if (!is.null(release) && !is.null(release$tag_name)) {
      return(release)
    }
  }
  stop(sprintf(
    paste0(
      "no hegel-rust release matches version %s on ",
      "https://github.com/hegeldev/hegel-rust/releases (checked tags v%1$s and %1$s)"
    ),
    version
  ), call. = FALSE)
}

# Pick the release asset matching this platform. Releases publish bare
# library files (e.g. "libhegel-windows-amd64.dll"), each with a ".sha256"
# sidecar; matching is case-insensitive on the asset name: platform tag AND
# architecture tag AND a bare-library extension (which also excludes the
# checksum sidecars). `sysname`/`arch` are injectable for testing; arch
# defaults to R.version$arch because Sys.info()'s "machine" spells x86_64
# with a hyphen on Windows. Returns the 1-based index; errors listing every
# asset name when nothing matches.
hegelr_pick_asset <- function(names, sysname = Sys.info()[["sysname"]],
                              arch = R.version$arch) {
  arm <- arch %in% c("arm64", "aarch64")
  arch_pat <- if (arm) "arm64|aarch64" else "x86_64|x86-64|amd64|x64"
  spec <- switch(sysname,
    Windows = list(platform = "windows|win", ext = "\\.dll$"),
    Darwin = list(platform = "darwin|macos|osx", ext = "\\.dylib$"),
    Linux = list(platform = "linux", ext = "\\.so$"),
    stop(sprintf("unsupported platform: %s", sysname), call. = FALSE)
  )
  hit <- grepl(spec$platform, names, ignore.case = TRUE) &
    grepl(arch_pat, names, ignore.case = TRUE) &
    grepl(spec$ext, names, ignore.case = TRUE) &
    !grepl("\\.sha256$", names, ignore.case = TRUE)
  if (!any(hit)) {
    stop(sprintf(
      paste0(
        "no release asset matches this platform (%s, %s). ",
        "Available assets:\n%s"
      ),
      sysname, arch,
      paste0("  - ", names, collapse = "\n")
    ), call. = FALSE)
  }
  which(hit)[[1L]]
}

# Canonical on-disk name for the engine library (matches the resolution
# pattern in hegelr_lib_pattern()); release assets like
# "libhegel-windows-amd64.dll" are stored under this name.
hegelr_canonical_lib_name <- function(sysname = Sys.info()[["sysname"]]) {
  switch(sysname,
    Windows = "hegel.dll",
    Darwin = "libhegel.dylib",
    "libhegel.so"
  )
}

#' @title Install the libhegel engine
#'
#' @description Downloads the prebuilt libhegel engine library (a single
#'   file such as `libhegel-windows-amd64.dll`) from the Hegel releases on
#'   GitHub
#'   (<https://github.com/hegeldev/hegel-rust/releases>) into
#'   `tools::R_user_dir("hegelr", "cache")/libhegel/<version>/`. The file
#'   is stored under its canonical name (`hegel.dll`, `libhegel.so` or
#'   `libhegel.dylib`), where [hegel_library_path()] finds it
#'   automatically. When the release publishes a `.sha256` sidecar for the
#'   asset, the download is verified against it (requires R >= 4.5; skipped
#'   with a message on older R).
#'
#' This function needs the *jsonlite* package (a soft dependency) to read
#' the GitHub API response, and network access. The GitHub API requires a
#' `User-Agent` header; hegel_install() sends it on every request. When the
#' `GITHUB_PAT` or `GITHUB_TOKEN` environment variable is set, its value is
#' sent as a bearer token, raising the API rate limit above the 60
#' unauthenticated requests/hour.
#'
#' @param version Version to install: `"latest"` (the default) or an exact
#'   release version such as `"0.32.5"` (with or without a leading `v`).
#'
#' @return The path of the installed library, invisibly.
#'
#' @examples
#' \donttest{
#' if (interactive() && !hegel_library_available()) {
#'   hegel_install()
#'   hegel_version()
#' }
#' }
#' @export
hegel_install <- function(version = "latest") {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop(paste0(
      "`hegel_install()` needs the 'jsonlite' package to read the GitHub ",
      "API. Install it with install.packages(\"jsonlite\")."
    ), call. = FALSE)
  }
  if (!is.character(version) || length(version) != 1L || is.na(version) ||
    !nzchar(version)) {
    stop("`version` must be a single non-empty string", call. = FALSE)
  }

  release <- hegelr_github_release(version)
  tag <- as.character(release$tag_name %||% "")
  rel_version <- sub("^v", "", tag)
  if (!nzchar(rel_version)) {
    stop(sprintf("release %s has no tag_name", tag), call. = FALSE)
  }

  assets <- release$assets
  if (is.null(assets) || !length(assets)) {
    stop(sprintf("release %s published no assets", tag), call. = FALSE)
  }
  asset_names <- vapply(assets, function(a) as.character(a$name %||% ""), character(1))
  idx <- hegelr_pick_asset(asset_names)
  asset <- assets[[idx]]
  url <- as.character(asset$browser_download_url %||% "")
  if (!nzchar(url)) {
    stop(sprintf("asset %s has no browser_download_url", asset_names[[idx]]),
      call. = FALSE
    )
  }

  dest_dir <- file.path(
    tools::R_user_dir("hegelr", "cache"), "libhegel", rel_version
  )
  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)

  # Releases ship bare library files, so the download is the library: store
  # it under the canonical name the resolver pattern expects.
  lib <- file.path(dest_dir, hegelr_canonical_lib_name())
  hegelr_download(url, lib, hegelr_github_headers())

  # Verify against the asset's .sha256 sidecar when one is published.
  hegelr_verify_sha256(assets, asset_names, asset_names[[idx]], lib, url)

  # Marker so hegel_library_path() step 2 resolves this install directly.
  marker <- file.path(dest_dir, "installed.rds")
  saveRDS(lib, marker)

  # Cache the fresh install; force a reload on the next engine use.
  hegelr_env$lib_path <- lib
  hegelr_env$lib_loaded <- FALSE
  hegelr_env$engine_version <- NULL
  invisible(lib)
}

# Verify `lib` against the ".sha256" sidecar published next to
# `asset_name`, when that sidecar exists in the release. tools::sha256sum()
# is R >= 4.5; on older R the check is skipped with a message. A mismatch
# removes the corrupt download and errors.
hegelr_verify_sha256 <- function(assets, asset_names, asset_name, lib, url) {
  sidecar <- paste0(asset_name, ".sha256")
  if (!(sidecar %in% asset_names)) {
    return(invisible(FALSE))
  }
  sha_url <- as.character(
    assets[[which(asset_names == sidecar)[[1L]]]]$browser_download_url %||% ""
  )
  if (!nzchar(sha_url)) {
    return(invisible(FALSE))
  }
  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  tryCatch(
    hegelr_download(sha_url, tmp, hegelr_github_headers()),
    error = function(e) {
      message("could not fetch the sha256 sidecar; skipping verification")
    }
  )
  if (!file.exists(tmp)) {
    return(invisible(FALSE))
  }
  expected <- trimws(sub("\\s+[*].*$", "", readLines(tmp, warn = FALSE)[[1L]]))
  if (!grepl("^[0-9a-fA-F]{64}$", expected)) {
    return(invisible(FALSE))
  }
  if (!exists("sha256sum", envir = asNamespace("tools"), inherits = FALSE)) {
    message("skipping sha256 verification (tools::sha256sum needs R >= 4.5)")
    return(invisible(FALSE))
  }
  actual <- tolower(as.character(tools::sha256sum(lib)))
  if (!identical(actual, tolower(expected))) {
    unlink(lib)
    stop(sprintf(
      paste0(
        "sha256 mismatch for %s (expected %s, got %s): the download may be ",
        "corrupted; the file was removed, please retry hegel_install()"
      ),
      basename(lib), expected, actual
    ), call. = FALSE)
  }
  invisible(TRUE)
}
