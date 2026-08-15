> [!IMPORTANT]
> This client is not officially supported by the Hegel core team.
> See https://hegel.dev for more details.

# Hegel for R

hegelr is a property-based testing library for R. Hegel is based on [Hypothesis](https://github.com/hypothesisworks/hypothesis), using the [Hegel protocol](https://hegel.dev/).

## Installation

Install the development version from GitHub with:

```r
# install.packages("remotes")
remotes::install_github("sims1253/hegel-r")
```

or

```r
# install.packages("pak")
pak::pak("sims1253/hegel-r")
```

### Engine setup

hegelr drives [libhegel](https://github.com/hegeldev/hegel-rust), the native Rust engine. The engine is never linked at install time; it is loaded at runtime. Run

```r
hegelr::hegel_install()
```

once to download the published engine — a single prebuilt library file (e.g. `libhegel-windows-amd64.dll`, with sha256 verification) — from the [hegeldev/hegel-rust releases](https://github.com/hegeldev/hegel-rust/releases) into hegelr's cache directory.

To use a local build instead (for example one built with cargo from a hegel-rust checkout), point `HEGEL_LIBHEGEL_PATH` at the library:

```r
Sys.setenv(HEGEL_LIBHEGEL_PATH = "/path/to/libhegel.so")
```

libhegel 0.32.x is required; hegelr checks the engine version on load. R 4.1.0 or newer is required.

## Quickstart

Here's a quick example of how to write a Hegel test:

```r
library(testthat)
library(hegelr)

my_sort <- function(x) {
  sorted <- sort(x)
  sorted[!duplicated(sorted)] # drops duplicates: a bug!
}

test_that("my_sort matches the reference sort", {
  hegel_test(function(tc) {
    x <- tc$draw(g_vectors(g_integers()))
    stopifnot(identical(my_sort(x), sort(x)))
  })
})
```

This test will fail when run with `devtools::test()` (or under `R CMD check`). Hegel will produce a minimal failing test case for us:

```
  draw_1 <- c(0, 0)
Reproduce with: hegel_reproduce("AXicY2VgYGBkZOBiZEBhMAAAAd8AIQ==", property)
identical(my_sort(x), sort(x)) is not TRUE
```

Hegel reports the minimal example showing that our sort is incorrectly dropping duplicates. If we remove the `sorted[!duplicated(sorted)]` line from `my_sort()`, this test will then pass (because it's just comparing the standard sort against itself).

The `Reproduce with:` line replays the saved failing example without a full run: pass the blob and the property to `hegel_reproduce()`.

```r
hegel_reproduce("AXicY2VgYGBkZOBiZEBhMAAAAd8AIQ==", function(tc) {
  x <- tc$draw(g_vectors(g_integers()))
  stopifnot(identical(my_sort(x), sort(x)))
})
```
