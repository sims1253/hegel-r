# Resolve the path of the libhegel engine library

`hegel_library_path()` locates the native libhegel engine without
loading it. Candidates are tried in this order:

1.  The `HEGEL_LIBHEGEL_PATH` environment variable, when it points at an
    existing file.

2.  Installs managed by
    [`hegel_install()`](https://sims1253.github.io/hegel-r/reference/hegel_install.md):
    the highest-versioned `libhegel/<version>/` directory under
    `tools::R_user_dir("hegelr", "cache")`. An `installed.rds` marker
    (written by
    [`hegel_install()`](https://sims1253.github.io/hegel-r/reference/hegel_install.md))
    is honored first; otherwise the directory is searched recursively
    for `libhegel.so`, `libhegel.dylib` or `hegel.dll`.

3.  Standard system locations on Unix-alikes: `/usr/local/lib`,
    `/usr/lib`, `/opt/homebrew/lib`, `/usr/local/homebrew/lib`.

4.  A bare library name, letting the OS loader search `PATH` and the
    system directories.

Only positive resolutions (steps 1-3) are cached for the process; the
bare-name fallback is returned uncached, so resolution still finds a
later install or environment-variable change.

## Usage

``` r
hegel_library_path()
```

## Value

A character string: an absolute library file path, or a bare library
name if no file was found (in which case loading may still succeed via
the OS loader).

## Examples

``` r
cat("libhegel resolves to:", hegel_library_path(), "\n")
#> libhegel resolves to: /home/runner/.cache/R/hegelr/libhegel/0.32.5/libhegel.so 
```
