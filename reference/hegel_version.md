# Report the libhegel engine version

Loads the engine (via
[`hegel_load()`](https://sims1253.github.io/hegel-r/reference/hegel_load.md))
and returns its version string.

## Usage

``` r
hegel_version()
```

## Value

A character string, e.g. `"0.32.5"`.

## Examples

``` r
if (hegel_library_available()) {
  hegel_version()
}
```
