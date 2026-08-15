# AGENTS.md — hegelr

R binding for the [Hegel](https://hegel.dev) property-based testing
engine (libhegel). See `ARCHITECTURE.md` for the full design and the
binding contract — read it before changing `src/` or `R/`.

Ground rules:

- Base R only in `Imports:`. `Suggests:` for testthat/jsonlite.
- The native engine is **never** a link-time dependency. `src/` dlopens
  it.
- Every `src/` change must keep the wrapper table in §4 of
  `ARCHITECTURE.md` and the arity in `src/init.c` in sync.
- Property bodies are plain R closures:
  [`stop()`](https://rdrr.io/r/base/stop.html) fails the case,
  `tc$assume()` rejects it, `tc$draw()` is the only randomness allowed.
- Tests: offline tests must pass without the engine; online tests skip
  via `skip_if_no_libhegel()`.
- Engine ABI reference: `hegel-rust/hegel-c/include/hegel.h` (pinned
  version in `R/libhegel.R`).
