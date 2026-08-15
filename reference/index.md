# Package index

## Running properties

- [`hegel_test()`](https://sims1253.github.io/hegel-r/reference/hegel_test.md)
  : Run a property-based test
- [`hegel_reproduce()`](https://sims1253.github.io/hegel-r/reference/hegel_reproduce.md)
  : Replay a stored counterexample

## Generators

### Primitive values

- [`g_integers()`](https://sims1253.github.io/hegel-r/reference/g_integers.md)
  : Generate integers
- [`g_doubles()`](https://sims1253.github.io/hegel-r/reference/g_doubles.md)
  : Generate doubles
- [`g_logicals()`](https://sims1253.github.io/hegel-r/reference/g_logicals.md)
  : Generate logicals
- [`g_characters()`](https://sims1253.github.io/hegel-r/reference/g_characters.md)
  : Generate single characters
- [`g_raw()`](https://sims1253.github.io/hegel-r/reference/g_raw.md) :
  Generate raw byte vectors
- [`g_text()`](https://sims1253.github.io/hegel-r/reference/g_text.md) :
  Generate text strings
- [`g_vectors()`](https://sims1253.github.io/hegel-r/reference/g_vectors.md)
  : Generate atomic vectors
- [`g_lists()`](https://sims1253.github.io/hegel-r/reference/g_lists.md)
  : Generate lists
- [`g_tuple()`](https://sims1253.github.io/hegel-r/reference/g_tuple.md)
  : Generate tuples

## Generators

### Internet domains

- [`g_emails()`](https://sims1253.github.io/hegel-r/reference/g_emails.md)
  : Generate email addresses
- [`g_urls()`](https://sims1253.github.io/hegel-r/reference/g_urls.md) :
  Generate URLs
- [`g_domains()`](https://sims1253.github.io/hegel-r/reference/g_domains.md)
  : Generate domain names
- [`g_from_regex()`](https://sims1253.github.io/hegel-r/reference/g_from_regex.md)
  : Generate strings matching a regular expression

## Generators

### Composition and refinement

- [`g_map()`](https://sims1253.github.io/hegel-r/reference/g_map.md) :
  Transform a generator's output
- [`g_filter()`](https://sims1253.github.io/hegel-r/reference/g_filter.md)
  : Filter a generator's output
- [`g_just()`](https://sims1253.github.io/hegel-r/reference/g_just.md) :
  Generate a constant
- [`g_sampled_from()`](https://sims1253.github.io/hegel-r/reference/g_sampled_from.md)
  : Generate one of a fixed set of values
- [`g_one_of()`](https://sims1253.github.io/hegel-r/reference/g_one_of.md)
  : Generate a choice among generators

## Engine management

The libhegel engine is loaded at runtime, never linked at install time.
These helpers install, locate, and load it.

- [`hegel_install()`](https://sims1253.github.io/hegel-r/reference/hegel_install.md)
  : Install the libhegel engine
- [`hegel_load()`](https://sims1253.github.io/hegel-r/reference/hegel_load.md)
  : Load the libhegel engine
- [`hegel_version()`](https://sims1253.github.io/hegel-r/reference/hegel_version.md)
  : Report the libhegel engine version
- [`hegel_library_available()`](https://sims1253.github.io/hegel-r/reference/hegel_library_available.md)
  : Check whether the libhegel engine can be loaded
- [`hegel_library_path()`](https://sims1253.github.io/hegel-r/reference/hegel_library_path.md)
  : Resolve the path of the libhegel engine library

## Cached string generators

### Internal machinery

- [`hegelr_stringgen()`](https://sims1253.github.io/hegel-r/reference/hegelr_stringgen.md)
  : Get-or-create a cached string generator
- [`hegelr_cache_context()`](https://sims1253.github.io/hegel-r/reference/hegelr_cache_context.md)
  : Process-lifetime engine context for cached string generators

## Package

- [`hegelr`](https://sims1253.github.io/hegel-r/reference/hegelr-package.md)
  [`hegelr-package`](https://sims1253.github.io/hegel-r/reference/hegelr-package.md)
  : hegelr: Property-Based Testing in R, Powered by Hegel
