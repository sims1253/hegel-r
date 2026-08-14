# Integration verification script (architect run).
# Run from the package root: Rscript tools/integrate.R <stage>
stage <- commandArgs(trailingOnly = TRUE)[[1L]]

if (identical(stage, "document")) {
  roxygen2::roxygenise(".", clean = TRUE)
  cat("roxygenise: OK\n")
} else if (identical(stage, "install")) {
  # R CMD INSTALL via system2 so compile output is visible on failure
  ok <- system2(file.path(R.home("bin"), "R"),
    c("CMD", "INSTALL", "--no-multiarch", "."), wait = TRUE)
  stopifnot(ok == 0L)
  cat("install: OK\n")
} else if (identical(stage, "test")) {
  library(testthat)
  library(hegelr)
  res <- testthat::test_local(".", stop_on_failure = FALSE)
  df <- as.data.frame(res)
  cat(sprintf(
    "tests: %d passed, %d failed, %d skipped, %d errored\n",
    sum(df$passed), sum(df$failed), sum(df$skipped), sum(df$error)
  ))
  fails <- df[df$failed > 0 | df$error > 0, ]
  if (nrow(fails)) print(fails[, c("file", "test", "failed", "error")])
  quit(status = if (nrow(fails)) 1L else 0L)
}
