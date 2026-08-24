# Replay a stored counterexample

Re-runs one property case from a reproduction `blob`, as printed by a
failing
[`hegel_test()`](https://sims1253.github.io/hegel-r/reference/hegel_test.md)
report, driving the property once with draw reporting enabled.

If the property fails again, the failure is re-raised as a
`hegelr_failure` condition (inheriting from `error`) carrying the draw
report and the original message. If the property passes, the blob no
longer reproduces and an error of class `hegelr_stale_blob` is signaled.
The Rust binding treats this as a hard failure too: the bug may have
been fixed, or the blob may be stale.

## Usage

``` r
hegel_reproduce(blob, property, ...)
```

## Arguments

- blob:

  A reproduction blob string, as shown in a failure report.

- property:

  The property, as passed to
  [`hegel_test()`](https://sims1253.github.io/hegel-r/reference/hegel_test.md).

- ...:

  Unused; must be empty. Present for forward compatibility.

## Value

Called for its output and side effects; a reproduced failure or a stale
blob is signaled as an error condition rather than returned.

## Examples

``` r
# \donttest{
if (hegel_library_available()) {
  my_sort <- function(x) {
    out <- sort(x)
    out[!duplicated(out)] # the bug: drops duplicates
  }
  property <- function(tc) {
    xs <- tc$draw(g_vectors(g_integers(-100, 100), max_size = 20))
    if (!identical(my_sort(xs), sort(xs))) {
      stop("my_sort() does not match base::sort()")
    }
  }
  blob <- tryCatch(
    hegel_test(property),
    hegelr_failure = function(e) {
      b <- e$blobs[[1L]]
      if (!is.na(b) && nzchar(b)) b else NULL
    },
    error = function(e) NULL
  )
  if (is.character(blob)) {
    tryCatch(
      hegel_reproduce(blob, property),
      hegelr_failure = function(e) cat("still failing\n"),
      hegelr_stale_blob = function(e) cat("fixed or stale\n")
    )
  }
}
# }
```
