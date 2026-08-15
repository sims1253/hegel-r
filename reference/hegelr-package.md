# hegelr: Property-Based Testing in R, Powered by Hegel

Provides property-based testing for R, powered by the native Hegel
engine (libhegel, the Rust core from hegeldev/hegel-rust). It adds
Hypothesis-style integrated shrinking, a persistent example database,
and composable generators, and integrates directly with testthat.
Property bodies are ordinary R closures that draw values with
tc\$draw(), assume preconditions with tc\$assume(), and fail with
stop(), stopifnot(), or testthat expectations. The engine handles
generation, shrinking, and replay. The engine library is loaded at
runtime, never linked at install time: run hegelr::hegel_install() once
or point HEGEL_LIBHEGEL_PATH at a local build.

## See also

Useful links:

- <https://github.com/sims1253/hegel-r>

- Report bugs at <https://github.com/sims1253/hegel-r/issues>

## Author

**Maintainer**: Maximilian Scholz <dev.scholz@mailbox.org>

Authors:

- Maximilian Scholz <dev.scholz@mailbox.org>
