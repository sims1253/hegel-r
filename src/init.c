/*
 * init.c — native routine registration for hegelr: every C_hegelr_*
 * wrapper registered with its exact arity (one row per hegelr_* function
 * in R/bindings.R — keep the two in sync), dynamic symbols disabled so
 * calls resolve through this table only.
 */

#include <Rinternals.h>
#include <R_ext/Rdynload.h>

SEXP C_hegelr_load(SEXP);
SEXP C_hegelr_is_loaded(void);
SEXP C_hegelr_version(void);
SEXP C_hegelr_context_new(void);
SEXP C_hegelr_settings_new(SEXP);
SEXP C_hegelr_settings_set_test_cases(SEXP, SEXP, SEXP);
SEXP C_hegelr_settings_set_seed(SEXP, SEXP, SEXP, SEXP);
SEXP C_hegelr_settings_set_derandomize(SEXP, SEXP, SEXP);
SEXP C_hegelr_settings_set_verbosity(SEXP, SEXP, SEXP);
SEXP C_hegelr_settings_set_database(SEXP, SEXP, SEXP);
SEXP C_hegelr_settings_set_database_key(SEXP, SEXP, SEXP);
SEXP C_hegelr_settings_set_mode(SEXP, SEXP, SEXP);
SEXP C_hegelr_settings_set_phases(SEXP, SEXP, SEXP);
SEXP C_hegelr_settings_set_suppress_health_check(SEXP, SEXP, SEXP);
SEXP C_hegelr_settings_set_report_multiple_failures(SEXP, SEXP, SEXP);
SEXP C_hegelr_run_start(SEXP, SEXP);
SEXP C_hegelr_next_test_case(SEXP, SEXP);
SEXP C_hegelr_mark_complete(SEXP, SEXP, SEXP, SEXP);
SEXP C_hegelr_target(SEXP, SEXP, SEXP, SEXP);
SEXP C_hegelr_run_result(SEXP, SEXP);
SEXP C_hegelr_run_result_status(SEXP, SEXP);
SEXP C_hegelr_run_result_error(SEXP, SEXP);
SEXP C_hegelr_run_result_failure_count(SEXP, SEXP);
SEXP C_hegelr_run_result_failure(SEXP, SEXP, SEXP);
SEXP C_hegelr_failure_origin(SEXP, SEXP);
SEXP C_hegelr_failure_blob(SEXP, SEXP);
SEXP C_hegelr_test_case_from_blob(SEXP, SEXP, SEXP);
SEXP C_hegelr_start_span(SEXP, SEXP, SEXP);
SEXP C_hegelr_stop_span(SEXP, SEXP, SEXP);
SEXP C_hegelr_new_collection(SEXP, SEXP, SEXP, SEXP);
SEXP C_hegelr_collection_more(SEXP, SEXP, SEXP);
SEXP C_hegelr_collection_reject(SEXP, SEXP, SEXP, SEXP);
SEXP C_hegelr_generate_boolean(SEXP, SEXP, SEXP);
SEXP C_hegelr_generate_integer(SEXP, SEXP, SEXP, SEXP);
SEXP C_hegelr_generate_float(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
SEXP C_hegelr_generate_bytes(SEXP, SEXP, SEXP, SEXP);
SEXP C_hegelr_string_generator_text(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
SEXP C_hegelr_string_generator_regex(SEXP, SEXP, SEXP);
SEXP C_hegelr_string_generator_email(SEXP);
SEXP C_hegelr_string_generator_url(SEXP);
SEXP C_hegelr_string_generator_domain(SEXP, SEXP);
SEXP C_hegelr_generate_string(SEXP, SEXP, SEXP);

static const R_CallMethodDef callMethods[] = {
    {"C_hegelr_load",                       (DL_FUNC) &C_hegelr_load,                       1},
    {"C_hegelr_is_loaded",                  (DL_FUNC) &C_hegelr_is_loaded,                  0},
    {"C_hegelr_version",                    (DL_FUNC) &C_hegelr_version,                    0},
    {"C_hegelr_context_new",                (DL_FUNC) &C_hegelr_context_new,                0},
    {"C_hegelr_settings_new",               (DL_FUNC) &C_hegelr_settings_new,               1},
    {"C_hegelr_settings_set_test_cases",    (DL_FUNC) &C_hegelr_settings_set_test_cases,    3},
    {"C_hegelr_settings_set_seed",          (DL_FUNC) &C_hegelr_settings_set_seed,          4},
    {"C_hegelr_settings_set_derandomize",   (DL_FUNC) &C_hegelr_settings_set_derandomize,   3},
    {"C_hegelr_settings_set_verbosity",     (DL_FUNC) &C_hegelr_settings_set_verbosity,     3},
    {"C_hegelr_settings_set_database",      (DL_FUNC) &C_hegelr_settings_set_database,      3},
    {"C_hegelr_settings_set_database_key",  (DL_FUNC) &C_hegelr_settings_set_database_key,  3},
    {"C_hegelr_settings_set_mode",          (DL_FUNC) &C_hegelr_settings_set_mode,          3},
    {"C_hegelr_settings_set_phases",        (DL_FUNC) &C_hegelr_settings_set_phases,        3},
    {"C_hegelr_settings_set_suppress_health_check", (DL_FUNC) &C_hegelr_settings_set_suppress_health_check, 3},
    {"C_hegelr_settings_set_report_multiple_failures", (DL_FUNC) &C_hegelr_settings_set_report_multiple_failures, 3},
    {"C_hegelr_run_start",                  (DL_FUNC) &C_hegelr_run_start,                  2},
    {"C_hegelr_next_test_case",             (DL_FUNC) &C_hegelr_next_test_case,             2},
    {"C_hegelr_mark_complete",              (DL_FUNC) &C_hegelr_mark_complete,              4},
    {"C_hegelr_target",                     (DL_FUNC) &C_hegelr_target,                     4},
    {"C_hegelr_run_result",                 (DL_FUNC) &C_hegelr_run_result,                 2},
    {"C_hegelr_run_result_status",          (DL_FUNC) &C_hegelr_run_result_status,          2},
    {"C_hegelr_run_result_error",           (DL_FUNC) &C_hegelr_run_result_error,          2},
    {"C_hegelr_run_result_failure_count",   (DL_FUNC) &C_hegelr_run_result_failure_count,   2},
    {"C_hegelr_run_result_failure",         (DL_FUNC) &C_hegelr_run_result_failure,         3},
    {"C_hegelr_failure_origin",             (DL_FUNC) &C_hegelr_failure_origin,             2},
    {"C_hegelr_failure_blob",               (DL_FUNC) &C_hegelr_failure_blob,               2},
    {"C_hegelr_test_case_from_blob",        (DL_FUNC) &C_hegelr_test_case_from_blob,        3},
    {"C_hegelr_start_span",                 (DL_FUNC) &C_hegelr_start_span,                 3},
    {"C_hegelr_stop_span",                  (DL_FUNC) &C_hegelr_stop_span,                  3},
    {"C_hegelr_new_collection",             (DL_FUNC) &C_hegelr_new_collection,             4},
    {"C_hegelr_collection_more",            (DL_FUNC) &C_hegelr_collection_more,            3},
    {"C_hegelr_collection_reject",          (DL_FUNC) &C_hegelr_collection_reject,          4},
    {"C_hegelr_generate_boolean",           (DL_FUNC) &C_hegelr_generate_boolean,           3},
    {"C_hegelr_generate_integer",           (DL_FUNC) &C_hegelr_generate_integer,           4},
    {"C_hegelr_generate_float",             (DL_FUNC) &C_hegelr_generate_float,             9},
    {"C_hegelr_generate_bytes",             (DL_FUNC) &C_hegelr_generate_bytes,             4},
    {"C_hegelr_string_generator_text",      (DL_FUNC) &C_hegelr_string_generator_text,     10},
    {"C_hegelr_string_generator_regex",     (DL_FUNC) &C_hegelr_string_generator_regex,     3},
    {"C_hegelr_string_generator_email",     (DL_FUNC) &C_hegelr_string_generator_email,     1},
    {"C_hegelr_string_generator_url",       (DL_FUNC) &C_hegelr_string_generator_url,       1},
    {"C_hegelr_string_generator_domain",    (DL_FUNC) &C_hegelr_string_generator_domain,    2},
    {"C_hegelr_generate_string",            (DL_FUNC) &C_hegelr_generate_string,            3},
    {NULL, NULL, 0}
};

void R_init_hegelr(DllInfo *info)
{
    R_registerRoutines(info, NULL, callMethods, NULL, NULL);
    R_useDynamicSymbols(info, FALSE);
}
