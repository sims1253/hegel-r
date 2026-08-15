/*
 * hegel_abi.h — single source of truth for the libhegel C ABI as bound by
 * hegelr: one function-pointer typedef per engine function, collected in
 * the hegelr_abi table that hegel_loader.c fills at runtime via
 * dlopen/dlsym or LoadLibraryW/GetProcAddress. Constants, opaque handle
 * types and callback/buffer types mirror hegel.h from the hegel-c crate
 * (the engine header is deliberately not included or linked; values must
 * be kept in sync with the pinned engine version).
 */

#ifndef HEGELR_ABI_H
#define HEGELR_ABI_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

/* ---- Engine result codes (mirrored from hegel_result_t) ------------- */

#define HEGEL_OK            0   /* success */
#define HEGEL_E_STOP_TEST  (-1) /* choice budget exhausted: abort the body */
#define HEGEL_E_ASSUME     (-2) /* assumption failed: discard the case */

/* ---- hegel_status_t: outcome of one test case (mark_complete) -------- */

#define HEGEL_STATUS_VALID       0
#define HEGEL_STATUS_INVALID     1
#define HEGEL_STATUS_OVERRUN     2
#define HEGEL_STATUS_INTERESTING 3

/* ---- hegel_run_status_t: aggregate outcome of a finished run --------- */

#define HEGEL_RUN_STATUS_PASSED 0
#define HEGEL_RUN_STATUS_FAILED 1
#define HEGEL_RUN_STATUS_ERROR  2

/* The engine's enums are int-sized; calling through a table of int-
   returning pointers is ABI-identical. */
typedef int hegel_result_t;

/* ---- Opaque engine handles (same declaration pattern as hegel.h) ----- */

typedef struct hegel_collection_t       hegel_collection_t;
typedef struct hegel_context_t          hegel_context_t;
typedef struct hegel_failure_t          hegel_failure_t;
typedef struct hegel_run_t              hegel_run_t;
typedef struct hegel_run_result_t       hegel_run_result_t;
typedef struct hegel_settings_t         hegel_settings_t;
typedef struct hegel_string_generator_t hegel_string_generator_t;
typedef struct hegel_test_case_t        hegel_test_case_t;

/* ---- Engine callback and by-value buffer types (from hegel.h) -------- */

typedef void (*hegel_output_callback_t)(void *user_data, const char *line, size_t len);

typedef struct {
    uint8_t *data;
    size_t len;
} hegel_generate_bytes_result_t;

typedef struct {
    char *data;
    size_t len;
} hegel_generate_string_result_t;

/* ---- One function-pointer typedef per bound engine function ---------- */

typedef hegel_context_t *(*hegelr_context_new_fn)(void);
typedef hegel_result_t (*hegelr_context_free_fn)(hegel_context_t *ctx);
typedef const char *(*hegelr_context_last_error_fn)(const hegel_context_t *ctx);

typedef hegel_result_t (*hegelr_settings_new_fn)(hegel_context_t *ctx,
                                                 hegel_settings_t **out_settings);
typedef hegel_result_t (*hegelr_settings_free_fn)(hegel_context_t *ctx, hegel_settings_t *s);
typedef hegel_result_t (*hegelr_settings_set_test_cases_fn)(hegel_context_t *ctx,
                                                            hegel_settings_t *s,
                                                            uint64_t n);
typedef hegel_result_t (*hegelr_settings_set_seed_fn)(hegel_context_t *ctx,
                                                      hegel_settings_t *s,
                                                      uint64_t seed,
                                                      bool has_seed);
typedef hegel_result_t (*hegelr_settings_set_derandomize_fn)(hegel_context_t *ctx,
                                                             hegel_settings_t *s,
                                                             bool derandomize);
typedef hegel_result_t (*hegelr_settings_set_verbosity_fn)(hegel_context_t *ctx,
                                                           hegel_settings_t *s,
                                                           uint32_t v);
typedef hegel_result_t (*hegelr_settings_set_database_fn)(hegel_context_t *ctx,
                                                          hegel_settings_t *s,
                                                          const char *database);
typedef hegel_result_t (*hegelr_settings_set_database_key_fn)(hegel_context_t *ctx,
                                                              hegel_settings_t *s,
                                                              const char *key);
typedef hegel_result_t (*hegelr_settings_set_mode_fn)(hegel_context_t *ctx,
                                                      hegel_settings_t *s,
                                                      uint32_t mode);
typedef hegel_result_t (*hegelr_settings_set_phases_fn)(hegel_context_t *ctx,
                                                        hegel_settings_t *s,
                                                        uint32_t phases);
typedef hegel_result_t (*hegelr_settings_set_suppress_health_check_fn)(hegel_context_t *ctx,
                                                                       hegel_settings_t *s,
                                                                       uint32_t checks);
typedef hegel_result_t (*hegelr_settings_set_report_multiple_failures_fn)(hegel_context_t *ctx,
                                                                          hegel_settings_t *s,
                                                                          bool yes);

typedef hegel_result_t (*hegelr_run_start_fn)(hegel_context_t *ctx,
                                              const hegel_settings_t *settings,
                                              hegel_output_callback_t callback,
                                              void *user_data,
                                              hegel_run_t **out_run);
typedef hegel_result_t (*hegelr_run_free_fn)(hegel_context_t *ctx, hegel_run_t *run);
typedef hegel_result_t (*hegelr_next_test_case_fn)(hegel_context_t *ctx,
                                                   hegel_run_t *run,
                                                   hegel_test_case_t **out_test_case);
typedef hegel_result_t (*hegelr_mark_complete_fn)(hegel_context_t *ctx,
                                                  hegel_test_case_t *tc,
                                                  uint32_t status,
                                                  const char *origin);
typedef hegel_result_t (*hegelr_target_fn)(hegel_context_t *ctx,
                                           hegel_test_case_t *tc,
                                           double value,
                                           const char *label);
typedef hegel_result_t (*hegelr_run_result_fn)(hegel_context_t *ctx,
                                               hegel_run_t *run,
                                               hegel_run_result_t **out_result);
typedef hegel_result_t (*hegelr_run_result_free_fn)(hegel_context_t *ctx,
                                                    hegel_run_result_t *r);
typedef hegel_result_t (*hegelr_run_result_status_fn)(hegel_context_t *ctx,
                                                      const hegel_run_result_t *r,
                                                      uint32_t *out_status);
typedef hegel_result_t (*hegelr_run_result_error_fn)(hegel_context_t *ctx,
                                                     const hegel_run_result_t *r,
                                                     const char **out_error);
typedef hegel_result_t (*hegelr_run_result_failure_count_fn)(hegel_context_t *ctx,
                                                             const hegel_run_result_t *r,
                                                             size_t *out_count);
typedef hegel_result_t (*hegelr_run_result_failure_fn)(hegel_context_t *ctx,
                                                       const hegel_run_result_t *r,
                                                       size_t index,
                                                       hegel_failure_t **out_failure);
typedef hegel_result_t (*hegelr_failure_free_fn)(hegel_context_t *ctx, hegel_failure_t *f);
typedef hegel_result_t (*hegelr_failure_origin_fn)(hegel_context_t *ctx,
                                                   const hegel_failure_t *f,
                                                   const char **out_origin);
typedef hegel_result_t (*hegelr_failure_reproduction_blob_fn)(hegel_context_t *ctx,
                                                              const hegel_failure_t *f,
                                                              const char **out_blob);

typedef hegel_result_t (*hegelr_test_case_from_blob_fn)(hegel_context_t *ctx,
                                                        const hegel_settings_t *s,
                                                        const char *blob,
                                                        hegel_output_callback_t callback,
                                                        void *user_data,
                                                        hegel_test_case_t **out_test_case);
typedef hegel_result_t (*hegelr_test_case_free_fn)(hegel_context_t *ctx,
                                                   hegel_test_case_t *tc);

typedef hegel_result_t (*hegelr_start_span_fn)(hegel_context_t *ctx,
                                               hegel_test_case_t *tc,
                                               uint64_t label);
typedef hegel_result_t (*hegelr_stop_span_fn)(hegel_context_t *ctx,
                                              hegel_test_case_t *tc,
                                              bool discard);

typedef hegel_result_t (*hegelr_new_collection_fn)(hegel_context_t *ctx,
                                                   hegel_test_case_t *tc,
                                                   uint64_t min_size,
                                                   uint64_t max_size,
                                                   hegel_collection_t **out_collection);
typedef hegel_result_t (*hegelr_collection_more_fn)(hegel_context_t *ctx,
                                                    hegel_test_case_t *tc,
                                                    hegel_collection_t *collection,
                                                    bool *out_more);
typedef hegel_result_t (*hegelr_collection_reject_fn)(hegel_context_t *ctx,
                                                      hegel_test_case_t *tc,
                                                      hegel_collection_t *collection,
                                                      const char *why);
typedef hegel_result_t (*hegelr_collection_free_fn)(hegel_context_t *ctx,
                                                    hegel_collection_t *collection);

typedef hegel_result_t (*hegelr_generate_boolean_fn)(hegel_context_t *ctx,
                                                     hegel_test_case_t *tc,
                                                     double p,
                                                     bool forced,
                                                     bool has_forced,
                                                     bool *out_value);
typedef hegel_result_t (*hegelr_generate_integer_fn)(hegel_context_t *ctx,
                                                     hegel_test_case_t *tc,
                                                     int64_t min_value,
                                                     int64_t max_value,
                                                     int64_t *out_value);
typedef hegel_result_t (*hegelr_generate_float_fn)(hegel_context_t *ctx,
                                                   hegel_test_case_t *tc,
                                                   uint32_t width,
                                                   double min_value,
                                                   double max_value,
                                                   bool allow_nan,
                                                   bool allow_infinity,
                                                   bool exclude_min,
                                                   bool exclude_max,
                                                   double smallest_nonzero_magnitude,
                                                   double *out_value);
typedef hegel_result_t (*hegelr_generate_bytes_fn)(hegel_context_t *ctx,
                                                   hegel_test_case_t *tc,
                                                   uint64_t min_size,
                                                   uint64_t max_size,
                                                   hegel_generate_bytes_result_t *out_result);
typedef hegel_result_t (*hegelr_generate_bytes_result_free_fn)(
    hegel_context_t *ctx, hegel_generate_bytes_result_t *result);

typedef hegel_result_t (*hegelr_string_generator_text_fn)(
    hegel_context_t *ctx,
    uint64_t min_size,
    uint64_t max_size,
    const char *codec,
    uint32_t min_codepoint,
    uint32_t max_codepoint,
    const char *const *categories,
    size_t categories_len,
    const char *const *exclude_categories,
    size_t exclude_categories_len,
    const uint8_t *include_characters,
    size_t include_characters_len,
    const uint8_t *exclude_characters,
    size_t exclude_characters_len,
    hegel_string_generator_t **out_generator);
typedef hegel_result_t (*hegelr_string_generator_regex_fn)(hegel_context_t *ctx,
                                                           const char *pattern,
                                                           bool fullmatch,
                                                           const hegel_string_generator_t *alphabet,
                                                           hegel_string_generator_t **out_generator);
typedef hegel_result_t (*hegelr_string_generator_email_fn)(hegel_context_t *ctx,
                                                           hegel_string_generator_t **out_generator);
typedef hegel_result_t (*hegelr_string_generator_url_fn)(hegel_context_t *ctx,
                                                         hegel_string_generator_t **out_generator);
typedef hegel_result_t (*hegelr_string_generator_domain_fn)(hegel_context_t *ctx,
                                                            uint64_t max_length,
                                                            hegel_string_generator_t **out_generator);
typedef hegel_result_t (*hegelr_string_generator_free_fn)(hegel_context_t *ctx,
                                                          hegel_string_generator_t *generator);
typedef hegel_result_t (*hegelr_generate_string_fn)(hegel_context_t *ctx,
                                                    hegel_test_case_t *tc,
                                                    const hegel_string_generator_t *generator,
                                                    hegel_generate_string_result_t *out_result);
typedef hegel_result_t (*hegelr_generate_string_result_free_fn)(
    hegel_context_t *ctx, hegel_generate_string_result_t *result);

typedef hegel_result_t (*hegelr_version_fn)(hegel_context_t *ctx, const char **out_version);

/* ---- The resolved-symbol table --------------------------------------- */

typedef struct {
    hegelr_context_new_fn                 context_new;
    hegelr_context_free_fn                context_free;
    hegelr_context_last_error_fn          context_last_error;
    hegelr_settings_new_fn                settings_new;
    hegelr_settings_free_fn               settings_free;
    hegelr_settings_set_test_cases_fn     settings_set_test_cases;
    hegelr_settings_set_seed_fn           settings_set_seed;
    hegelr_settings_set_derandomize_fn    settings_set_derandomize;
    hegelr_settings_set_verbosity_fn      settings_set_verbosity;
    hegelr_settings_set_database_fn           settings_set_database;
    hegelr_settings_set_database_key_fn       settings_set_database_key;
    hegelr_settings_set_mode_fn               settings_set_mode;
    hegelr_settings_set_phases_fn             settings_set_phases;
    hegelr_settings_set_suppress_health_check_fn settings_set_suppress_health_check;
    hegelr_settings_set_report_multiple_failures_fn settings_set_report_multiple_failures;
    hegelr_run_start_fn                   run_start;
    hegelr_run_free_fn                    run_free;
    hegelr_next_test_case_fn              next_test_case;
    hegelr_mark_complete_fn               mark_complete;
    hegelr_target_fn                      target;
    hegelr_run_result_fn                  run_result;
    hegelr_run_result_free_fn             run_result_free;
    hegelr_run_result_status_fn           run_result_status;
    hegelr_run_result_error_fn            run_result_error;
    hegelr_run_result_failure_count_fn    run_result_failure_count;
    hegelr_run_result_failure_fn          run_result_failure;
    hegelr_failure_free_fn                failure_free;
    hegelr_failure_origin_fn              failure_origin;
    hegelr_failure_reproduction_blob_fn   failure_reproduction_blob;
    hegelr_test_case_from_blob_fn         test_case_from_blob;
    hegelr_test_case_free_fn              test_case_free;
    hegelr_start_span_fn                  start_span;
    hegelr_stop_span_fn                   stop_span;
    hegelr_new_collection_fn              new_collection;
    hegelr_collection_more_fn             collection_more;
    hegelr_collection_reject_fn           collection_reject;
    hegelr_collection_free_fn             collection_free;
    hegelr_generate_boolean_fn            generate_boolean;
    hegelr_generate_integer_fn            generate_integer;
    hegelr_generate_float_fn              generate_float;
    hegelr_generate_bytes_fn              generate_bytes;
    hegelr_generate_bytes_result_free_fn  generate_bytes_result_free;
    hegelr_string_generator_text_fn       string_generator_text;
    hegelr_string_generator_regex_fn      string_generator_regex;
    hegelr_string_generator_email_fn      string_generator_email;
    hegelr_string_generator_url_fn        string_generator_url;
    hegelr_string_generator_domain_fn     string_generator_domain;
    hegelr_string_generator_free_fn       string_generator_free;
    hegelr_generate_string_fn             generate_string;
    hegelr_generate_string_result_free_fn generate_string_result_free;
    hegelr_version_fn                     version;
} hegelr_abi_t;

/* Defined in hegel_loader.c; zeroed until a load succeeds. Never read it
   directly without first checking hegelr_is_loaded(). */
extern hegelr_abi_t hegelr_abi;

/* ---- Loader entry points (hegel_loader.c) ----------------------------- */

/* Load the engine library at `path` and resolve every bound symbol.
 * Returns 0 on success (also when the engine is already loaded; loading
 * is idempotent and ignores the path in that case). On failure returns
 * -1 and writes a bounded diagnostic into errbuf (NUL-terminated), naming
 * the loader error or the first missing symbols so version mismatches are
 * diagnosable. errbuf may be NULL / errlen 0 to discard the message. */
int hegelr_load_library(const char *path, char *errbuf, size_t errlen);

/* TRUE (non-zero) once hegelr_load_library has succeeded. */
int hegelr_is_loaded(void);

#endif /* HEGELR_ABI_H */
