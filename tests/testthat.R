# This file is part of the standard testthat setup and runs all test files in
# tests/testthat when `R CMD check` (or `devtools::test()`) executes.

library(testthat)
library(hegelr)

test_check("hegelr")
