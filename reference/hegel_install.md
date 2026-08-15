# Install the libhegel engine

Downloads the prebuilt libhegel engine library (a single file such as
`libhegel-windows-amd64.dll`) from the Hegel releases on GitHub
(<https://github.com/hegeldev/hegel-rust/releases>) into
`tools::R_user_dir("hegelr", "cache")/libhegel/<version>/`. The file is
stored under its canonical name (`hegel.dll`, `libhegel.so` or
`libhegel.dylib`), where
[`hegel_library_path()`](https://sims1253.github.io/hegel-r/reference/hegel_library_path.md)
finds it automatically. When the release publishes a `.sha256` sidecar
for the asset, the download is verified against it (requires R \>= 4.5;
skipped with a message on older R).

This function needs the *jsonlite* package (a soft dependency) to read
the GitHub API response, and network access. The GitHub API requires a
`User-Agent` header; hegel_install() sends it on every request. When the
`GITHUB_PAT` or `GITHUB_TOKEN` environment variable is set, its value is
sent as a bearer token, raising the API rate limit above the 60
unauthenticated requests/hour.

## Usage

``` r
hegel_install(version = "latest")
```

## Arguments

- version:

  Version to install: `"latest"` (the default) or an exact release
  version such as `"0.32.5"` (with or without a leading `v`).

## Value

The path of the installed library, invisibly.

## Examples

``` r
# \donttest{
if (interactive() && !hegel_library_available()) {
  hegel_install()
  hegel_version()
}
# }
```
