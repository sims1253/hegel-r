# Check whether the libhegel engine can be loaded

Returns `TRUE` when a library path resolves *and* the engine loads
successfully (including the version gate). It never signals - any error
from resolution or loading is caught and mapped to `FALSE` - so it is
safe to call unconditionally, e.g. to guard examples or tests.

## Usage

``` r
hegel_library_available()
```

## Value

`TRUE` or `FALSE`.

## Examples

``` r
if (hegel_library_available()) {
  cat("engine ready, version", hegel_version(), "\n")
} else {
  cat("engine absent; run hegel_install() to fetch it\n")
}
#> engine absent; run hegel_install() to fetch it
```
