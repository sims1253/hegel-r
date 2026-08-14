/*
 * hegel_loader.c — runtime loading of the libhegel engine. POSIX uses
 * dlopen/dlsym (RTLD_NOW | RTLD_LOCAL); Windows converts the UTF-8 path to
 * wide chars and uses LoadLibraryW/GetProcAddress. Every required symbol
 * is resolved into the shared hegelr_abi table; a partial table is never
 * committed (the library is unloaded and the staged table discarded on
 * any missing symbol).
 */

#include "hegel_abi.h"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#else
#include <dlfcn.h>
#endif

/* How many missing symbol names to embed in the error message. */
#define HEGELR_MISSING_MAX 5

hegelr_abi_t hegelr_abi; /* zero-initialized until a load succeeds */

#ifdef _WIN32
typedef HMODULE hegelr_dlhandle;
#else
typedef void *hegelr_dlhandle;
#endif

static hegelr_dlhandle hegelr_handle; /* the loaded engine, kept for life */

int hegelr_is_loaded(void)
{
    return hegelr_handle != NULL;
}

/* Append formatted text to a bounded error buffer; never overflows and
 * keeps the buffer NUL-terminated. */
static void err_append(char *errbuf, size_t errlen, size_t *off, const char *fmt, ...)
{
    va_list ap;
    int n;

    if (errbuf == NULL || errlen == 0 || *off >= errlen)
        return;
    va_start(ap, fmt);
    n = vsnprintf(errbuf + *off, errlen - *off, fmt, ap);
    va_end(ap);
    if (n < 0)
        return;
    if ((size_t) n >= errlen - *off)
        *off = errlen - 1; /* truncated: park on the final NUL */
    else
        *off += (size_t) n;
}

static hegelr_dlhandle hegelr_dlopen(const char *path)
{
#ifdef _WIN32
    int n;
    wchar_t *wpath;
    HMODULE h;

    /* The R side passes UTF-8 (Rf_translateCharUTF8 at the wrapper). */
    n = MultiByteToWideChar(CP_UTF8, 0, path, -1, NULL, 0);
    if (n <= 0)
        return NULL;
    wpath = (wchar_t *) malloc((size_t) n * sizeof(wchar_t));
    if (wpath == NULL)
        return NULL;
    if (MultiByteToWideChar(CP_UTF8, 0, path, -1, wpath, n) <= 0) {
        free(wpath);
        return NULL;
    }
    h = LoadLibraryW(wpath);
    free(wpath);
    return h;
#else
    return dlopen(path, RTLD_NOW | RTLD_LOCAL);
#endif
}

static void *hegelr_dlsym(hegelr_dlhandle handle, const char *name)
{
#ifdef _WIN32
    return (void *) (uintptr_t) GetProcAddress(handle, name);
#else
    return dlsym(handle, name);
#endif
}

static void hegelr_dlclose(hegelr_dlhandle handle)
{
#ifdef _WIN32
    FreeLibrary(handle);
#else
    dlclose(handle);
#endif
}

int hegelr_load_library(const char *path, char *errbuf, size_t errlen)
{
    hegelr_dlhandle handle;
    hegelr_abi_t abi; /* staged; committed only when fully resolved */
    const char *missing[HEGELR_MISSING_MAX];
    int n_missing = 0;
    size_t off = 0;

    if (errbuf != NULL && errlen > 0)
        errbuf[0] = '\0';

    if (path == NULL || path[0] == '\0') {
        err_append(errbuf, errlen, &off,
                   "hegelr: library path must be a non-empty string");
        return -1;
    }

    if (hegelr_handle != NULL)
        return 0; /* already loaded: idempotent */

    handle = hegelr_dlopen(path);
    if (handle == NULL) {
#ifdef _WIN32
        char sysmsg[256];
        DWORD e = GetLastError();
        if (!FormatMessageA(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                            NULL, e, 0, sysmsg, (DWORD) sizeof sysmsg, NULL))
            snprintf(sysmsg, sizeof sysmsg, "unknown error");
        sysmsg[strcspn(sysmsg, "\r\n")] = '\0';
        err_append(errbuf, errlen, &off,
                   "hegelr: cannot load libhegel from '%s': %s (Windows error %lu)",
                   path, sysmsg, (unsigned long) e);
#else
        const char *why = dlerror();
        err_append(errbuf, errlen, &off,
                   "hegelr: cannot load libhegel from '%s': %s",
                   path, why != NULL ? why : "unknown error");
#endif
        return -1;
    }

    memset(&abi, 0, sizeof abi);

/* POSIX dlsym idiom: write the object pointer through the field's
 * address, avoiding an ISO C function-pointer cast. */
#define HEGELR_RESOLVE(field, name)                        \
    do {                                                   \
        void *sym_ = hegelr_dlsym(handle, (name));         \
        if (sym_ == NULL) {                                \
            if (n_missing < HEGELR_MISSING_MAX)            \
                missing[n_missing] = (name);               \
            n_missing++;                                   \
        } else {                                           \
            *(void **) &abi.field = sym_;                  \
        }                                                  \
    } while (0)

    HEGELR_RESOLVE(context_new, "hegel_context_new");
    HEGELR_RESOLVE(context_free, "hegel_context_free");
    HEGELR_RESOLVE(context_last_error, "hegel_context_last_error");
    HEGELR_RESOLVE(settings_new, "hegel_settings_new");
    HEGELR_RESOLVE(settings_free, "hegel_settings_free");
    HEGELR_RESOLVE(settings_set_test_cases, "hegel_settings_set_test_cases");
    HEGELR_RESOLVE(settings_set_seed, "hegel_settings_set_seed");
    HEGELR_RESOLVE(settings_set_derandomize, "hegel_settings_set_derandomize");
    HEGELR_RESOLVE(settings_set_verbosity, "hegel_settings_set_verbosity");
    HEGELR_RESOLVE(settings_set_database, "hegel_settings_set_database");
    HEGELR_RESOLVE(settings_set_database_key, "hegel_settings_set_database_key");
    HEGELR_RESOLVE(settings_set_mode, "hegel_settings_set_mode");
    HEGELR_RESOLVE(settings_set_phases, "hegel_settings_set_phases");
    HEGELR_RESOLVE(settings_set_suppress_health_check, "hegel_settings_set_suppress_health_check");
    HEGELR_RESOLVE(settings_set_report_multiple_failures, "hegel_settings_set_report_multiple_failures");
    HEGELR_RESOLVE(run_start, "hegel_run_start");
    HEGELR_RESOLVE(run_free, "hegel_run_free");
    HEGELR_RESOLVE(next_test_case, "hegel_next_test_case");
    HEGELR_RESOLVE(mark_complete, "hegel_mark_complete");
    HEGELR_RESOLVE(target, "hegel_target");
    HEGELR_RESOLVE(run_result, "hegel_run_result");
    HEGELR_RESOLVE(run_result_free, "hegel_run_result_free");
    HEGELR_RESOLVE(run_result_status, "hegel_run_result_status");
    HEGELR_RESOLVE(run_result_error, "hegel_run_result_error");
    HEGELR_RESOLVE(run_result_failure_count, "hegel_run_result_failure_count");
    HEGELR_RESOLVE(run_result_failure, "hegel_run_result_failure");
    HEGELR_RESOLVE(failure_free, "hegel_failure_free");
    HEGELR_RESOLVE(failure_origin, "hegel_failure_origin");
    HEGELR_RESOLVE(failure_reproduction_blob, "hegel_failure_reproduction_blob");
    HEGELR_RESOLVE(test_case_from_blob, "hegel_test_case_from_blob");
    HEGELR_RESOLVE(test_case_free, "hegel_test_case_free");
    HEGELR_RESOLVE(start_span, "hegel_start_span");
    HEGELR_RESOLVE(stop_span, "hegel_stop_span");
    HEGELR_RESOLVE(new_collection, "hegel_new_collection");
    HEGELR_RESOLVE(collection_more, "hegel_collection_more");
    HEGELR_RESOLVE(collection_reject, "hegel_collection_reject");
    HEGELR_RESOLVE(collection_free, "hegel_collection_free");
    HEGELR_RESOLVE(generate_boolean, "hegel_generate_boolean");
    HEGELR_RESOLVE(generate_integer, "hegel_generate_integer");
    HEGELR_RESOLVE(generate_float, "hegel_generate_float");
    HEGELR_RESOLVE(generate_bytes, "hegel_generate_bytes");
    HEGELR_RESOLVE(generate_bytes_result_free, "hegel_generate_bytes_result_free");
    HEGELR_RESOLVE(string_generator_text, "hegel_string_generator_text");
    HEGELR_RESOLVE(string_generator_regex, "hegel_string_generator_regex");
    HEGELR_RESOLVE(string_generator_email, "hegel_string_generator_email");
    HEGELR_RESOLVE(string_generator_url, "hegel_string_generator_url");
    HEGELR_RESOLVE(string_generator_domain, "hegel_string_generator_domain");
    HEGELR_RESOLVE(string_generator_free, "hegel_string_generator_free");
    HEGELR_RESOLVE(generate_string, "hegel_generate_string");
    HEGELR_RESOLVE(generate_string_result_free, "hegel_generate_string_result_free");
    HEGELR_RESOLVE(version, "hegel_version");

#undef HEGELR_RESOLVE

    if (n_missing > 0) {
        int i;
        int shown = n_missing < HEGELR_MISSING_MAX ? n_missing : HEGELR_MISSING_MAX;
        err_append(errbuf, errlen, &off,
                   "hegelr: library at '%s' is missing %d required libhegel symbol%s"
                   " (engine version mismatch?)", path, n_missing,
                   n_missing == 1 ? "" : "s");
        for (i = 0; i < shown; i++)
            err_append(errbuf, errlen, &off, "%s %s", i == 0 ? ":" : ",", missing[i]);
        if (n_missing > shown)
            err_append(errbuf, errlen, &off, ", ... and %d more", n_missing - shown);
        hegelr_dlclose(handle);
        return -1;
    }

    hegelr_abi = abi;
    hegelr_handle = handle; /* kept open for the process lifetime */
    return 0;
}
