/*
 * hegel_wrappers.c — the .Call surface: one C_hegelr_* wrapper per entry
 * registered in src/init.c. Each wrapper validates
 * its arguments, forwards through the hegelr_abi function-pointer table,
 * and either returns the contract value or raises an R error carrying the
 * engine diagnostic. Handles are external pointers tagged with their
 * handle type; every non-context handle also carries its owning context
 * extptr both as the "context" attribute (for the R layer) and in the
 * external pointer's prot slot (for finalizers, which must not allocate),
 * so the garbage collector can never free a context before its
 * dependents.
 */

#include "hegel_abi.h"

#include <Rinternals.h>
#include <R_ext/Error.h>
#include <R_ext/Memory.h>
#include <R_ext/Print.h>

#include <limits.h>
#include <stdint.h>
#include <string.h>

/* Largest integer exactly representable as an R double. */
#define HEGELR_2P53 9007199254740992.0

/* ---------------------------------------------------------------------- */
/* Engine-call helpers                                                    */
/* ---------------------------------------------------------------------- */

static void hegelr_require_loaded(const char *who)
{
    if (!hegelr_is_loaded())
        Rf_error("hegelr shim %s: libhegel is not loaded; call hegelr::hegel_load() first", who);
}

/* The engine's last diagnostic on ctx, or NULL when unavailable. */
static const char *hegelr_last_error(hegel_context_t *ctx)
{
    if (ctx == NULL || !hegelr_is_loaded())
        return NULL;
    return hegelr_abi.context_last_error(ctx);
}

static void hegelr_error_msg(hegel_result_t code, const char *msg, const char *who)
{
    if (msg != NULL && msg[0] != '\0')
        Rf_error("hegelr shim %s: %s (engine code %d)", who, msg, (int) code);
    Rf_error("hegelr shim %s: libhegel call failed (engine code %d)", who, (int) code);
}

/* Raise an R error unless the engine call succeeded. */
static void hegelr_check(hegel_result_t code, hegel_context_t *ctx, const char *who)
{
    if (code == HEGEL_OK)
        return;
    hegelr_error_msg(code, hegelr_last_error(ctx), who);
}

/* Draw primitives map OK / STOP_TEST / ASSUME onto the status field;
 * anything else is an error. */
static int draw_status(hegel_result_t code, hegel_context_t *ctx, const char *who)
{
    if (code == HEGEL_OK || code == HEGEL_E_STOP_TEST || code == HEGEL_E_ASSUME)
        return (int) code;
    hegelr_check(code, ctx, who);
    return (int) HEGEL_OK; /* not reached: Rf_error does not return */
}

/* ---------------------------------------------------------------------- */
/* Argument validation                                                    */
/* ---------------------------------------------------------------------- */

/* A length-1 numeric (double preferred, integer tolerated); NA rejected,
 * +/-Inf allowed for callers that interpret it themselves. */
static double num_scalar(SEXP x, const char *who, const char *arg)
{
    if (TYPEOF(x) == INTSXP && Rf_length(x) == 1) {
        int v = INTEGER(x)[0];
        if (v == NA_INTEGER)
            Rf_error("hegelr shim %s: %s must not be NA", who, arg);
        return (double) v;
    }
    if (TYPEOF(x) != REALSXP || Rf_length(x) != 1)
        Rf_error("hegelr shim %s: %s must be a length-1 numeric vector", who, arg);
    if (ISNAN(REAL(x)[0]))
        Rf_error("hegelr shim %s: %s must not be NA", who, arg);
    return REAL(x)[0];
}

/* Whole number with |x| <= 2^53, as required by the contract for any
 * integer crossing the boundary as an R double. */
static int64_t as_i64_checked(SEXP x, const char *who, const char *arg)
{
    double v = num_scalar(x, who, arg);
    if (v != floor(v) || v < -HEGELR_2P53 || v > HEGELR_2P53)
        Rf_error("hegelr shim %s: %s must be a whole number with |x| <= 2^53", who, arg);
    return (int64_t) v;
}

/* Unsigned variant for sizes, labels, seeds and indices (u64-safe
 * subset: whole, in [0, 2^53]). */
static uint64_t as_u64_checked(SEXP x, const char *who, const char *arg)
{
    double v = num_scalar(x, who, arg);
    if (v < 0.0 || v != floor(v) || v > HEGELR_2P53)
        Rf_error("hegelr shim %s: %s must be a whole number in [0, 2^53]", who, arg);
    return (uint64_t) v;
}

static int lgl_scalar(SEXP x, const char *who, const char *arg)
{
    int v;
    if (TYPEOF(x) != LGLSXP || Rf_length(x) != 1)
        Rf_error("hegelr shim %s: %s must be a length-1 logical vector", who, arg);
    v = LOGICAL(x)[0];
    if (v == NA_LOGICAL)
        Rf_error("hegelr shim %s: %s must not be NA", who, arg);
    return v;
}

static const char *str_arg(SEXP x, const char *who, const char *arg)
{
    if (TYPEOF(x) != STRSXP || Rf_length(x) != 1)
        Rf_error("hegelr shim %s: %s must be a length-1 character vector", who, arg);
    return Rf_translateCharUTF8(STRING_ELT(x, 0));
}

/* ---------------------------------------------------------------------- */
/* Handles                                                                */
/* ---------------------------------------------------------------------- */

/* Extract and type-check an engine handle: external pointer, right tag,
 * non-NULL address. Also the single gate through which every wrapper
 * reaches the engine, so the abi table is never dereferenced unloaded. */
static void *handle_ptr(SEXP x, const char *tagname, const char *who, const char *arg)
{
    void *p;
    hegelr_require_loaded(who);
    if (TYPEOF(x) != EXTPTRSXP)
        Rf_error("hegelr shim %s: %s must be a hegelr handle (external pointer)", who, arg);
    if (R_ExternalPtrTag(x) != Rf_install(tagname))
        Rf_error("hegelr shim %s: %s must be a hegelr '%s' handle", who, arg, tagname);
    p = R_ExternalPtrAddr(x);
    if (p == NULL)
        Rf_error("hegelr shim %s: %s is not a valid hegelr handle (already freed?)", who, arg);
    return p;
}

/* The owning context of a handle, read from the external pointer's prot
 * slot. Chosen over the "context" attribute because reading it cannot
 * allocate, so it is safe inside GC finalizers. NULL for context handles
 * themselves and when the context has already been finalized. */
static hegel_context_t *owner_ctx(SEXP pt)
{
    SEXP c = R_ExternalPtrProtected(pt);
    if (c == R_NilValue || TYPEOF(c) != EXTPTRSXP)
        return NULL;
    return (hegel_context_t *) R_ExternalPtrAddr(c);
}

/* Wrap an engine pointer as a tagged external pointer with a finalizer.
 * ctx is the owning context extptr (R_NilValue for contexts themselves):
 * storing it both in the prot slot and as the "context" attribute keeps
 * it reachable, ordering finalization after all dependents. */
static SEXP mk_handle(SEXP tag, void *ptr, SEXP ctx, R_CFinalizer_t fin)
{
    SEXP pt = PROTECT(R_MakeExternalPtr(ptr, tag, ctx));
    Rf_setAttrib(pt, Rf_install("context"), ctx);
    R_RegisterCFinalizerEx(pt, fin, TRUE);
    UNPROTECT(1);
    return pt;
}

/* Finalizer for the context handle itself. */
static void fin_context(SEXP pt)
{
    hegel_context_t *ctx = (hegel_context_t *) R_ExternalPtrAddr(pt);
    if (ctx != NULL && hegelr_is_loaded())
        hegelr_abi.context_free(ctx);
    R_ClearExternalPtr(pt);
}

/* Finalizers for the engine's handle frees, each called as free(ctx, handle). */
#define HEGELR_FINALIZER(name, handle_t, field)             \
    static void name(SEXP pt)                               \
    {                                                       \
        handle_t *p = (handle_t *) R_ExternalPtrAddr(pt);   \
        if (p != NULL && hegelr_is_loaded())                \
            hegelr_abi.field(owner_ctx(pt), p);             \
        R_ClearExternalPtr(pt);                             \
    }

HEGELR_FINALIZER(fin_settings, hegel_settings_t, settings_free)
HEGELR_FINALIZER(fin_run, hegel_run_t, run_free)
HEGELR_FINALIZER(fin_test_case, hegel_test_case_t, test_case_free)
HEGELR_FINALIZER(fin_run_result, hegel_run_result_t, run_result_free)
HEGELR_FINALIZER(fin_failure, hegel_failure_t, failure_free)
HEGELR_FINALIZER(fin_collection, hegel_collection_t, collection_free)
HEGELR_FINALIZER(fin_string_generator, hegel_string_generator_t, string_generator_free)

/* ---------------------------------------------------------------------- */
/* Value construction                                                     */
/* ---------------------------------------------------------------------- */

/* Marked-UTF-8 string of exactly len bytes, truncated at the first
 * embedded NUL (R char data cannot carry interior NULs). */
static SEXP mk_string_utf8_len(const char *buf, size_t len)
{
    const char *nul;
    SEXP s;

    if (len > (size_t) INT_MAX)
        len = (size_t) INT_MAX;
    nul = (const char *) memchr(buf, '\0', len);
    if (nul != NULL)
        len = (size_t) (nul - buf);
    s = PROTECT(Rf_allocVector(STRSXP, 1));
    SET_STRING_ELT(s, 0, Rf_mkCharLenCE(buf, (int) len, CE_UTF8));
    UNPROTECT(1);
    return s;
}

static SEXP mk_string_utf8(const char *cstr)
{
    return mk_string_utf8_len(cstr, strlen(cstr));
}

/* list(value = <value>, status = <int>) as returned by draw primitives. */
static SEXP mk_draw_result(SEXP value, int status)
{
    SEXP ans, names;

    PROTECT(value);
    ans = PROTECT(Rf_allocVector(VECSXP, 2));
    SET_VECTOR_ELT(ans, 0, value);
    SET_VECTOR_ELT(ans, 1, Rf_ScalarInteger(status));
    names = PROTECT(Rf_allocVector(STRSXP, 2));
    SET_STRING_ELT(names, 0, Rf_mkChar("value"));
    SET_STRING_ELT(names, 1, Rf_mkChar("status"));
    Rf_setAttrib(ans, R_NamesSymbol, names);
    UNPROTECT(3);
    return ans;
}

/* Engine output trampoline: `line` points at len bytes that may not be
 * NUL-terminated, so always print by length. */
static void hegelr_output_cb(void *user_data, const char *line, size_t len)
{
    (void) user_data;
    Rprintf("%.*s\n", (int) len, line);
}

/* Character vector -> UTF-8 C-string array (R_alloc lives until the .Call
 * returns, which outlives the engine call). NULL passes through as NULL;
 * an empty vector stays a non-NULL empty array because the engine
 * distinguishes "no restriction" from "empty alphabet". */
static const char *const *chr_vec_to_carray(SEXP x, const char *who, const char *arg,
                                            size_t *len_out)
{
    R_xlen_t i, n;
    const char **arr;

    *len_out = 0;
    if (x == R_NilValue)
        return NULL;
    if (TYPEOF(x) != STRSXP)
        Rf_error("hegelr shim %s: %s must be a character vector or NULL", who, arg);
    n = Rf_length(x);
    arr = (const char **) R_alloc(n > 0 ? n : 1, sizeof(const char *));
    for (i = 0; i < n; i++)
        arr[i] = Rf_translateCharUTF8(STRING_ELT(x, i));
    *len_out = (size_t) n;
    return arr;
}

/* Length-1 string or NULL -> UTF-8 byte buffer + length. R strings cannot
 * contain U+0000, so strlen bounds the buffer. */
static const uint8_t *utf8_buf_or_null(SEXP x, const char *who, const char *arg,
                                       size_t *len_out)
{
    const char *s;

    *len_out = 0;
    if (x == R_NilValue)
        return NULL;
    s = str_arg(x, who, arg);
    *len_out = strlen(s);
    return (const uint8_t *) s;
}

/* ---------------------------------------------------------------------- */
/* Load / version / context                                               */
/* ---------------------------------------------------------------------- */

SEXP C_hegelr_load(SEXP path)
{
    char errbuf[512];
    const char *cpath;

    if (TYPEOF(path) != STRSXP || Rf_length(path) != 1)
        Rf_error("hegelr shim %s: path must be a length-1 character vector", __func__);
    cpath = Rf_translateCharUTF8(STRING_ELT(path, 0));
    if (hegelr_load_library(cpath, errbuf, sizeof errbuf) != 0)
        Rf_error("%s", errbuf);
    return Rf_ScalarLogical(1); /* TRUE: R_TrueValue is not public API */
}

SEXP C_hegelr_is_loaded(void)
{
    return Rf_ScalarLogical(hegelr_is_loaded());
}

SEXP C_hegelr_version(void)
{
    hegel_context_t *ctx;
    const char *v = NULL;
    hegel_result_t code;
    SEXP ans;

    hegelr_require_loaded(__func__);
    ctx = hegelr_abi.context_new(); /* never returns NULL */
    code = hegelr_abi.version(ctx, &v);
    if (code != HEGEL_OK) {
        const char *msg = hegelr_last_error(ctx);
        hegelr_abi.context_free(ctx);
        hegelr_error_msg(code, msg, __func__);
    }
    ans = PROTECT(mk_string_utf8_len(v, strlen(v))); /* v is engine-static */
    hegelr_abi.context_free(ctx);
    UNPROTECT(1);
    return ans;
}

SEXP C_hegelr_context_new(void)
{
    hegel_context_t *ctx;

    hegelr_require_loaded(__func__);
    ctx = hegelr_abi.context_new();
    return mk_handle(Rf_install("hegelr_context"), ctx, R_NilValue, fin_context);
}

/* ---------------------------------------------------------------------- */
/* Settings                                                               */
/* ---------------------------------------------------------------------- */

SEXP C_hegelr_settings_new(SEXP ctx_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_settings_t *s = NULL;

    hegelr_require_loaded(__func__);
    hegelr_check(hegelr_abi.settings_new(ctx, &s), ctx, __func__);
    return mk_handle(Rf_install("hegelr_settings"), s, ctx_s, fin_settings);
}

SEXP C_hegelr_settings_set_test_cases(SEXP ctx_s, SEXP s_s, SEXP n_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_settings_t *s = (hegel_settings_t *) handle_ptr(s_s, "hegelr_settings", __func__, "s");
    uint64_t n = as_u64_checked(n_s, __func__, "n");

    hegelr_check(hegelr_abi.settings_set_test_cases(ctx, s, n), ctx, __func__);
    return Rf_ScalarLogical(1); /* TRUE: R_TrueValue is not public API */
}

SEXP C_hegelr_settings_set_seed(SEXP ctx_s, SEXP s_s, SEXP seed_s, SEXP has_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_settings_t *s = (hegel_settings_t *) handle_ptr(s_s, "hegelr_settings", __func__, "s");
    uint64_t seed = as_u64_checked(seed_s, __func__, "seed");
    bool has_seed = lgl_scalar(has_s, __func__, "has") != 0;

    hegelr_check(hegelr_abi.settings_set_seed(ctx, s, seed, has_seed), ctx, __func__);
    return Rf_ScalarLogical(1); /* TRUE: R_TrueValue is not public API */
}

SEXP C_hegelr_settings_set_derandomize(SEXP ctx_s, SEXP s_s, SEXP lgl_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_settings_t *s = (hegel_settings_t *) handle_ptr(s_s, "hegelr_settings", __func__, "s");
    bool derandomize = lgl_scalar(lgl_s, __func__, "derandomize") != 0;

    hegelr_check(hegelr_abi.settings_set_derandomize(ctx, s, derandomize), ctx, __func__);
    return Rf_ScalarLogical(1); /* TRUE: R_TrueValue is not public API */
}

SEXP C_hegelr_settings_set_verbosity(SEXP ctx_s, SEXP s_s, SEXP v_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_settings_t *s = (hegel_settings_t *) handle_ptr(s_s, "hegelr_settings", __func__, "s");
    int64_t v = as_i64_checked(v_s, __func__, "verbosity");

    if (v < 0 || v > 3)
        Rf_error("hegelr shim %s: verbosity must be one of 0 (quiet), 1 (normal), 2 (verbose), 3 (debug)",
                 __func__);
    hegelr_check(hegelr_abi.settings_set_verbosity(ctx, s, (uint32_t) v), ctx, __func__);
    return Rf_ScalarLogical(1); /* TRUE: R_TrueValue is not public API */
}

SEXP C_hegelr_settings_set_database(SEXP ctx_s, SEXP s_s, SEXP path_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_settings_t *s = (hegel_settings_t *) handle_ptr(s_s, "hegelr_settings", __func__, "s");
    /* NULL -> engine default (./.hegel/examples/); "" -> disable. */
    const char *database = (path_s == R_NilValue) ? NULL : str_arg(path_s, __func__, "database");

    hegelr_check(hegelr_abi.settings_set_database(ctx, s, database), ctx, __func__);
    return Rf_ScalarLogical(1); /* TRUE: R_TrueValue is not public API */
}

SEXP C_hegelr_settings_set_database_key(SEXP ctx_s, SEXP s_s, SEXP key_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_settings_t *s = (hegel_settings_t *) handle_ptr(s_s, "hegelr_settings", __func__, "s");
    const char *key = (key_s == R_NilValue) ? NULL : str_arg(key_s, __func__, "key");

    hegelr_check(hegelr_abi.settings_set_database_key(ctx, s, key), ctx, __func__);
    return Rf_ScalarLogical(1); /* TRUE: R_TrueValue is not public API */
}

SEXP C_hegelr_settings_set_mode(SEXP ctx_s, SEXP s_s, SEXP mode_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_settings_t *s = (hegel_settings_t *) handle_ptr(s_s, "hegelr_settings", __func__, "s");
    int64_t mode = as_i64_checked(mode_s, __func__, "mode");

    if (mode < 0 || mode > 1)
        Rf_error("hegelr shim %s: mode must be 0 (test run) or 1 (single test case)", __func__);
    hegelr_check(hegelr_abi.settings_set_mode(ctx, s, (uint32_t) mode), ctx, __func__);
    return Rf_ScalarLogical(1); /* TRUE: R_TrueValue is not public API */
}

SEXP C_hegelr_settings_set_phases(SEXP ctx_s, SEXP s_s, SEXP mask_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_settings_t *s = (hegel_settings_t *) handle_ptr(s_s, "hegelr_settings", __func__, "s");
    uint64_t mask = as_u64_checked(mask_s, __func__, "phases");

    if (mask > 31)
        Rf_error("hegelr shim %s: phases mask must be in [0, 31] (bits 0-4)", __func__);
    hegelr_check(hegelr_abi.settings_set_phases(ctx, s, (uint32_t) mask), ctx, __func__);
    return Rf_ScalarLogical(1); /* TRUE: R_TrueValue is not public API */
}

SEXP C_hegelr_settings_set_suppress_health_check(SEXP ctx_s, SEXP s_s, SEXP checks_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_settings_t *s = (hegel_settings_t *) handle_ptr(s_s, "hegelr_settings", __func__, "s");
    uint64_t checks = as_u64_checked(checks_s, __func__, "checks");

    if (checks > 15)
        Rf_error("hegelr shim %s: health-check mask must be in [0, 15] (bits 0-3)", __func__);
    hegelr_check(hegelr_abi.settings_set_suppress_health_check(ctx, s, (uint32_t) checks), ctx,
                 __func__);
    return Rf_ScalarLogical(1); /* TRUE: R_TrueValue is not public API */
}

SEXP C_hegelr_settings_set_report_multiple_failures(SEXP ctx_s, SEXP s_s, SEXP yes_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_settings_t *s = (hegel_settings_t *) handle_ptr(s_s, "hegelr_settings", __func__, "s");
    bool yes = lgl_scalar(yes_s, __func__, "yes") != 0;

    hegelr_check(hegelr_abi.settings_set_report_multiple_failures(ctx, s, yes), ctx, __func__);
    return Rf_ScalarLogical(1); /* TRUE: R_TrueValue is not public API */
}

/* ---------------------------------------------------------------------- */
/* Run loop                                                               */
/* ---------------------------------------------------------------------- */

SEXP C_hegelr_run_start(SEXP ctx_s, SEXP s_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_settings_t *s = (hegel_settings_t *) handle_ptr(s_s, "hegelr_settings", __func__, "s");
    hegel_run_t *run = NULL;

    hegelr_check(hegelr_abi.run_start(ctx, s, hegelr_output_cb, NULL, &run), ctx, __func__);
    return mk_handle(Rf_install("hegelr_run"), run, ctx_s, fin_run);
}

SEXP C_hegelr_next_test_case(SEXP ctx_s, SEXP run_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_run_t *run = (hegel_run_t *) handle_ptr(run_s, "hegelr_run", __func__, "run");
    hegel_test_case_t *tc = NULL;

    hegelr_check(hegelr_abi.next_test_case(ctx, run, &tc), ctx, __func__);
    if (tc == NULL)
        return R_NilValue; /* run finished */
    return mk_handle(Rf_install("hegelr_test_case"), tc, ctx_s, fin_test_case);
}

SEXP C_hegelr_mark_complete(SEXP ctx_s, SEXP tc_s, SEXP status_s, SEXP origin_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_test_case_t *tc = (hegel_test_case_t *) handle_ptr(tc_s, "hegelr_test_case", __func__, "tc");
    int64_t status = as_i64_checked(status_s, __func__, "status");
    const char *origin = NULL;

    if (status < HEGEL_STATUS_VALID || status > HEGEL_STATUS_INTERESTING)
        Rf_error("hegelr shim %s: status must be one of 0 (VALID), 1 (INVALID), 2 (OVERRUN), 3 (INTERESTING)",
                 __func__);
    /* The engine reads origin only for INTERESTING outcomes. */
    if (status == HEGEL_STATUS_INTERESTING)
        origin = str_arg(origin_s, __func__, "origin");

    hegelr_check(hegelr_abi.mark_complete(ctx, tc, (uint32_t) status, origin), ctx, __func__);
    return Rf_ScalarLogical(1); /* TRUE: R_TrueValue is not public API */
}

SEXP C_hegelr_target(SEXP ctx_s, SEXP tc_s, SEXP value_s, SEXP label_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_test_case_t *tc = (hegel_test_case_t *) handle_ptr(tc_s, "hegelr_test_case", __func__, "tc");
    double value = num_scalar(value_s, __func__, "value");
    const char *label = (label_s == R_NilValue) ? NULL : str_arg(label_s, __func__, "label");

    hegelr_check(hegelr_abi.target(ctx, tc, value, label), ctx, __func__);
    return Rf_ScalarLogical(1); /* TRUE: R_TrueValue is not public API */
}

/* ---------------------------------------------------------------------- */
/* Run results and failures                                               */
/* ---------------------------------------------------------------------- */

SEXP C_hegelr_run_result(SEXP ctx_s, SEXP run_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_run_t *run = (hegel_run_t *) handle_ptr(run_s, "hegelr_run", __func__, "run");
    hegel_run_result_t *r = NULL;

    hegelr_check(hegelr_abi.run_result(ctx, run, &r), ctx, __func__);
    return mk_handle(Rf_install("hegelr_run_result"), r, ctx_s, fin_run_result);
}

SEXP C_hegelr_run_result_status(SEXP ctx_s, SEXP result_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_run_result_t *r = (hegel_run_result_t *) handle_ptr(result_s, "hegelr_run_result", __func__, "result");
    uint32_t status = 0;

    hegelr_check(hegelr_abi.run_result_status(ctx, r, &status), ctx, __func__);
    return Rf_ScalarInteger((int) status);
}

SEXP C_hegelr_run_result_error(SEXP ctx_s, SEXP result_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_run_result_t *r = (hegel_run_result_t *) handle_ptr(result_s, "hegelr_run_result", __func__, "result");
    const char *err = NULL;

    hegelr_check(hegelr_abi.run_result_error(ctx, r, &err), ctx, __func__);
    if (err == NULL)
        return R_NilValue;
    return mk_string_utf8(err);
}

SEXP C_hegelr_run_result_failure_count(SEXP ctx_s, SEXP result_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_run_result_t *r = (hegel_run_result_t *) handle_ptr(result_s, "hegelr_run_result", __func__, "result");
    size_t count = 0;

    hegelr_check(hegelr_abi.run_result_failure_count(ctx, r, &count), ctx, __func__);
    return Rf_ScalarInteger((int) count);
}

SEXP C_hegelr_run_result_failure(SEXP ctx_s, SEXP result_s, SEXP i0_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_run_result_t *r = (hegel_run_result_t *) handle_ptr(result_s, "hegelr_run_result", __func__, "result");
    uint64_t i0 = as_u64_checked(i0_s, __func__, "i0");
    hegel_failure_t *f = NULL;

    hegelr_check(hegelr_abi.run_result_failure(ctx, r, (size_t) i0, &f), ctx, __func__);
    return mk_handle(Rf_install("hegelr_failure"), f, ctx_s, fin_failure);
}

SEXP C_hegelr_failure_origin(SEXP ctx_s, SEXP failure_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_failure_t *f = (hegel_failure_t *) handle_ptr(failure_s, "hegelr_failure", __func__, "failure");
    const char *origin = NULL;

    hegelr_check(hegelr_abi.failure_origin(ctx, f, &origin), ctx, __func__);
    if (origin == NULL)
        return R_NilValue;
    return mk_string_utf8(origin);
}

SEXP C_hegelr_failure_blob(SEXP ctx_s, SEXP failure_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_failure_t *f = (hegel_failure_t *) handle_ptr(failure_s, "hegelr_failure", __func__, "failure");
    const char *blob = NULL;

    hegelr_check(hegelr_abi.failure_reproduction_blob(ctx, f, &blob), ctx, __func__);
    if (blob == NULL)
        return R_NilValue;
    return mk_string_utf8(blob);
}

/* ---------------------------------------------------------------------- */
/* Replay, spans, collections                                             */
/* ---------------------------------------------------------------------- */

SEXP C_hegelr_test_case_from_blob(SEXP ctx_s, SEXP s_s, SEXP blob_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_settings_t *s = (hegel_settings_t *) handle_ptr(s_s, "hegelr_settings", __func__, "s");
    const char *blob = str_arg(blob_s, __func__, "blob");
    hegel_test_case_t *tc = NULL;

    hegelr_check(hegelr_abi.test_case_from_blob(ctx, s, blob, hegelr_output_cb, NULL, &tc),
                 ctx, __func__);
    return mk_handle(Rf_install("hegelr_test_case"), tc, ctx_s, fin_test_case);
}

SEXP C_hegelr_start_span(SEXP ctx_s, SEXP tc_s, SEXP label_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_test_case_t *tc = (hegel_test_case_t *) handle_ptr(tc_s, "hegelr_test_case", __func__, "tc");
    uint64_t label = as_u64_checked(label_s, __func__, "label");

    hegelr_check(hegelr_abi.start_span(ctx, tc, label), ctx, __func__);
    return Rf_ScalarLogical(1); /* TRUE: R_TrueValue is not public API */
}

SEXP C_hegelr_stop_span(SEXP ctx_s, SEXP tc_s, SEXP discard_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_test_case_t *tc = (hegel_test_case_t *) handle_ptr(tc_s, "hegelr_test_case", __func__, "tc");
    bool discard = lgl_scalar(discard_s, __func__, "discard") != 0;

    hegelr_check(hegelr_abi.stop_span(ctx, tc, discard), ctx, __func__);
    return Rf_ScalarLogical(1); /* TRUE: R_TrueValue is not public API */
}

SEXP C_hegelr_new_collection(SEXP ctx_s, SEXP tc_s, SEXP min_s, SEXP max_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_test_case_t *tc = (hegel_test_case_t *) handle_ptr(tc_s, "hegelr_test_case", __func__, "tc");
    uint64_t min_size = as_u64_checked(min_s, __func__, "min");
    uint64_t max_size = as_u64_checked(max_s, __func__, "max");
    hegel_collection_t *coll = NULL;

    if (min_size > max_size)
        Rf_error("hegelr shim %s: min must be <= max", __func__);
    hegelr_check(hegelr_abi.new_collection(ctx, tc, min_size, max_size, &coll), ctx, __func__);
    return mk_handle(Rf_install("hegelr_collection"), coll, ctx_s, fin_collection);
}

SEXP C_hegelr_collection_more(SEXP ctx_s, SEXP tc_s, SEXP coll_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_test_case_t *tc = (hegel_test_case_t *) handle_ptr(tc_s, "hegelr_test_case", __func__, "tc");
    hegel_collection_t *coll = (hegel_collection_t *) handle_ptr(coll_s, "hegelr_collection", __func__, "coll");
    bool more = false;
    int status;
    SEXP value, ans;

    status = draw_status(hegelr_abi.collection_more(ctx, tc, coll, &more),
                         ctx, __func__);
    value = PROTECT(status == HEGEL_OK ? Rf_ScalarLogical(more) : R_NilValue);
    ans = mk_draw_result(value, status);
    UNPROTECT(1);
    return ans;
}

SEXP C_hegelr_collection_reject(SEXP ctx_s, SEXP tc_s, SEXP coll_s, SEXP why_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_test_case_t *tc = (hegel_test_case_t *) handle_ptr(tc_s, "hegelr_test_case", __func__, "tc");
    hegel_collection_t *coll = (hegel_collection_t *) handle_ptr(coll_s, "hegelr_collection", __func__, "coll");
    const char *why = (why_s == R_NilValue) ? NULL : str_arg(why_s, __func__, "why");

    hegelr_check(hegelr_abi.collection_reject(ctx, tc, coll, why), ctx, __func__);
    return Rf_ScalarLogical(1); /* TRUE: R_TrueValue is not public API */
}

/* ---------------------------------------------------------------------- */
/* Draw primitives                                                        */
/* ---------------------------------------------------------------------- */

SEXP C_hegelr_generate_boolean(SEXP ctx_s, SEXP tc_s, SEXP p_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_test_case_t *tc = (hegel_test_case_t *) handle_ptr(tc_s, "hegelr_test_case", __func__, "tc");
    double p = num_scalar(p_s, __func__, "p");
    bool out = false;
    int status;
    SEXP value, ans;

    if (p < 0.0 || p > 1.0)
        Rf_error("hegelr shim %s: p must be a probability in [0, 1]", __func__);
    status = draw_status(hegelr_abi.generate_boolean(ctx, tc, p, false, false, &out),
                         ctx, __func__);
    value = PROTECT(status == HEGEL_OK ? Rf_ScalarLogical(out != 0) : R_NilValue);
    ans = mk_draw_result(value, status);
    UNPROTECT(1);
    return ans;
}

SEXP C_hegelr_generate_integer(SEXP ctx_s, SEXP tc_s, SEXP min_s, SEXP max_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_test_case_t *tc = (hegel_test_case_t *) handle_ptr(tc_s, "hegelr_test_case", __func__, "tc");
    int64_t min_value = as_i64_checked(min_s, __func__, "min");
    int64_t max_value = as_i64_checked(max_s, __func__, "max");
    int64_t out = 0;
    int status;
    SEXP value, ans;

    if (min_value > max_value)
        Rf_error("hegelr shim %s: min must be <= max", __func__);
    status = draw_status(hegelr_abi.generate_integer(ctx, tc, min_value, max_value, &out),
                         ctx, __func__);
    /* Integer-ish values cross to R as doubles (contract: whole doubles). */
    value = PROTECT(status == HEGEL_OK ? Rf_ScalarReal((double) out) : R_NilValue);
    ans = mk_draw_result(value, status);
    UNPROTECT(1);
    return ans;
}

SEXP C_hegelr_generate_float(SEXP ctx_s, SEXP tc_s, SEXP min_s, SEXP max_s,
                             SEXP allow_nan_s, SEXP allow_inf_s,
                             SEXP excl_min_s, SEXP excl_max_s,
                             SEXP smallest_nonzero_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_test_case_t *tc = (hegel_test_case_t *) handle_ptr(tc_s, "hegelr_test_case", __func__, "tc");
    double min_value = num_scalar(min_s, __func__, "min");  /* +/-Inf allowed */
    double max_value = num_scalar(max_s, __func__, "max");
    bool allow_nan = lgl_scalar(allow_nan_s, __func__, "allow_nan") != 0;
    bool allow_infinity = lgl_scalar(allow_inf_s, __func__, "allow_infinity") != 0;
    bool exclude_min = lgl_scalar(excl_min_s, __func__, "exclude_min") != 0;
    bool exclude_max = lgl_scalar(excl_max_s, __func__, "exclude_max") != 0;
    double smallest = num_scalar(smallest_nonzero_s, __func__, "smallest_nonzero");
    double out = 0.0;
    int status;
    SEXP value, ans;

    if (min_value > max_value)
        Rf_error("hegelr shim %s: min must be <= max", __func__);
    if (!(smallest > 0.0) || !R_FINITE(smallest))
        Rf_error("hegelr shim %s: smallest_nonzero must be a positive finite double", __func__);
    status = draw_status(hegelr_abi.generate_float(ctx, tc, 64,
                                                   min_value, max_value,
                                                   allow_nan, allow_infinity,
                                                   exclude_min, exclude_max,
                                                   smallest, &out),
                         ctx, __func__);
    value = PROTECT(status == HEGEL_OK ? Rf_ScalarReal(out) : R_NilValue);
    ans = mk_draw_result(value, status);
    UNPROTECT(1);
    return ans;
}

SEXP C_hegelr_generate_bytes(SEXP ctx_s, SEXP tc_s, SEXP min_s, SEXP max_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_test_case_t *tc = (hegel_test_case_t *) handle_ptr(tc_s, "hegelr_test_case", __func__, "tc");
    uint64_t min_size = as_u64_checked(min_s, __func__, "min");
    uint64_t max_size = as_u64_checked(max_s, __func__, "max");
    hegel_generate_bytes_result_t res = { NULL, 0 };
    int status;
    SEXP value, ans;

    if (min_size > max_size)
        Rf_error("hegelr shim %s: min must be <= max", __func__);
    status = draw_status(hegelr_abi.generate_bytes(ctx, tc, min_size, max_size, &res),
                         ctx, __func__);
    if (status == HEGEL_OK) {
        value = PROTECT(Rf_allocVector(RAWSXP, (R_xlen_t) res.len));
        if (res.len > 0)
            memcpy(RAW(value), res.data, res.len);
    } else {
        value = PROTECT(R_NilValue);
    }
    hegelr_abi.generate_bytes_result_free(ctx, &res); /* safe on zeroed structs */
    ans = mk_draw_result(value, status);
    UNPROTECT(1);
    return ans;
}

/* ---------------------------------------------------------------------- */
/* String generators                                                      */
/* ---------------------------------------------------------------------- */

SEXP C_hegelr_string_generator_text(SEXP ctx_s, SEXP min_s, SEXP max_s, SEXP codec_s,
                                    SEXP min_cp_s, SEXP max_cp_s, SEXP categories_s,
                                    SEXP exclude_categories_s, SEXP include_characters_s,
                                    SEXP exclude_characters_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    uint64_t min_size = as_u64_checked(min_s, __func__, "min");
    uint64_t max_size = as_u64_checked(max_s, __func__, "max");
    const char *codec = (codec_s == R_NilValue) ? NULL : str_arg(codec_s, __func__, "codec");
    uint64_t min_cp = as_u64_checked(min_cp_s, __func__, "min_codepoint");
    uint64_t max_cp = as_u64_checked(max_cp_s, __func__, "max_codepoint");
    const char *const *categories;
    const char *const *exclude_categories;
    const uint8_t *include_characters;
    const uint8_t *exclude_characters;
    size_t categories_len, exclude_categories_len;
    size_t include_characters_len, exclude_characters_len;
    hegel_string_generator_t *gen = NULL;

    if (min_size > max_size)
        Rf_error("hegelr shim %s: min must be <= max", __func__);
    if (min_cp > 0xFFFFFFFFULL || max_cp > 0xFFFFFFFFULL)
        Rf_error("hegelr shim %s: codepoints must be in [0, 2^32-1]", __func__);
    if (min_cp > max_cp)
        Rf_error("hegelr shim %s: min_codepoint must be <= max_codepoint", __func__);

    categories = chr_vec_to_carray(categories_s, __func__, "categories", &categories_len);
    exclude_categories = chr_vec_to_carray(exclude_categories_s, __func__,
                                           "exclude_categories", &exclude_categories_len);
    include_characters = utf8_buf_or_null(include_characters_s, __func__,
                                           "include_characters", &include_characters_len);
    exclude_characters = utf8_buf_or_null(exclude_characters_s, __func__,
                                           "exclude_characters", &exclude_characters_len);

    hegelr_check(hegelr_abi.string_generator_text(ctx, min_size, max_size, codec,
                                                  (uint32_t) min_cp, (uint32_t) max_cp,
                                                  categories, categories_len,
                                                  exclude_categories, exclude_categories_len,
                                                  include_characters, include_characters_len,
                                                  exclude_characters, exclude_characters_len,
                                                  &gen),
                 ctx, __func__);
    return mk_handle(Rf_install("hegelr_string_generator"), gen, ctx_s,
                     fin_string_generator);
}

SEXP C_hegelr_string_generator_regex(SEXP ctx_s, SEXP pattern_s, SEXP fullmatch_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    const char *pattern = str_arg(pattern_s, __func__, "pattern");
    bool fullmatch = lgl_scalar(fullmatch_s, __func__, "fullmatch") != 0;
    hegel_string_generator_t *gen = NULL;

    /* No alphabet generator is exposed over this wrapper (NULL = none). */
    hegelr_check(hegelr_abi.string_generator_regex(ctx, pattern, fullmatch, NULL, &gen),
                 ctx, __func__);
    return mk_handle(Rf_install("hegelr_string_generator"), gen, ctx_s,
                     fin_string_generator);
}

SEXP C_hegelr_string_generator_email(SEXP ctx_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_string_generator_t *gen = NULL;

    hegelr_check(hegelr_abi.string_generator_email(ctx, &gen), ctx, __func__);
    return mk_handle(Rf_install("hegelr_string_generator"), gen, ctx_s,
                     fin_string_generator);
}

SEXP C_hegelr_string_generator_url(SEXP ctx_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_string_generator_t *gen = NULL;

    hegelr_check(hegelr_abi.string_generator_url(ctx, &gen), ctx, __func__);
    return mk_handle(Rf_install("hegelr_string_generator"), gen, ctx_s,
                     fin_string_generator);
}

SEXP C_hegelr_string_generator_domain(SEXP ctx_s, SEXP max_length_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    uint64_t max_length = as_u64_checked(max_length_s, __func__, "max_length");
    hegel_string_generator_t *gen = NULL;

    hegelr_check(hegelr_abi.string_generator_domain(ctx, max_length, &gen), ctx, __func__);
    return mk_handle(Rf_install("hegelr_string_generator"), gen, ctx_s,
                     fin_string_generator);
}

SEXP C_hegelr_generate_string(SEXP ctx_s, SEXP sg_s, SEXP tc_s)
{
    hegel_context_t *ctx = (hegel_context_t *) handle_ptr(ctx_s, "hegelr_context", __func__, "ctx");
    hegel_string_generator_t *sg = (hegel_string_generator_t *) handle_ptr(sg_s, "hegelr_string_generator", __func__, "sg");
    hegel_test_case_t *tc = (hegel_test_case_t *) handle_ptr(tc_s, "hegelr_test_case", __func__, "tc");
    hegel_generate_string_result_t res = { NULL, 0 };
    int status;
    SEXP value, ans;

    status = draw_status(hegelr_abi.generate_string(ctx, tc, sg, &res), ctx, __func__);
    if (status == HEGEL_OK) {
        value = PROTECT(mk_string_utf8_len(res.data, res.len));
        hegelr_abi.generate_string_result_free(ctx, &res);
    } else {
        value = PROTECT(R_NilValue);
    }
    ans = mk_draw_result(value, status);
    UNPROTECT(1);
    return ans;
}
