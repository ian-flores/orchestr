# ---- Checkpointer: memory backend ----

test_that("checkpointer() creates a memory Checkpointer by default", {
  cp <- checkpointer()
  expect_s3_class(cp, "Checkpointer")
})

test_that("load() returns NULL for unknown thread", {
  cp <- checkpointer()
  expect_null(cp$load("nonexistent"))
})

test_that("save/load round-trips latest checkpoint", {
  cp <- checkpointer()
  cp$save("t1", "node_a", list(x = 1))
  result <- cp$load("t1")
  expect_equal(result$node, "node_a")
  expect_equal(result$state$x, 1)
})

test_that("load() returns the most recent checkpoint", {
  cp <- checkpointer()
  cp$save("t1", "node_a", list(x = 1))
  cp$save("t1", "node_b", list(x = 2))
  result <- cp$load("t1")
  expect_equal(result$node, "node_b")
  expect_equal(result$state$x, 2)
})

test_that("history() returns all snapshots in order", {
  cp <- checkpointer()
  cp$save("t1", "a", list(x = 1))
  cp$save("t1", "b", list(x = 2))
  cp$save("t1", "c", list(x = 3))

  h <- cp$history("t1")
  expect_length(h, 3)
  expect_equal(h[[1]]$node, "a")
  expect_equal(h[[2]]$node, "b")
  expect_equal(h[[3]]$node, "c")
})

test_that("history() returns empty list for unknown thread", {
  cp <- checkpointer()
  expect_equal(cp$history("nope"), list())
})

test_that("threads are isolated", {
  cp <- checkpointer()
  cp$save("t1", "a", list(x = 1))
  cp$save("t2", "b", list(y = 2))

  r1 <- cp$load("t1")
  r2 <- cp$load("t2")
  expect_equal(r1$node, "a")
  expect_equal(r2$node, "b")
  expect_equal(r1$state$x, 1)
  expect_equal(r2$state$y, 2)
})

test_that("save() validates inputs", {
  cp <- checkpointer()
  expect_error(cp$save(123, "a", list()), "non-empty single character")
  expect_error(cp$save("t1", 123, list()), "single character string")
  expect_error(cp$save("t1", "a", "not a list"), "must be a list")
})


# ---- Checkpointer: file backend ----

test_that("file backend persists checkpoints", {
  tmp_dir <- tempfile("cp_test_")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  cp1 <- checkpointer(backend = "file", path = tmp_dir)
  cp1$save("t1", "node_a", list(x = 10))
  cp1$save("t1", "node_b", list(x = 20))

  # New checkpointer reading the same directory

  cp2 <- checkpointer(backend = "file", path = tmp_dir)
  result <- cp2$load("t1")
  expect_equal(result$node, "node_b")
  expect_equal(result$state$x, 20)

  h <- cp2$history("t1")
  expect_length(h, 2)
})

test_that("file backend creates directory if needed", {
  tmp_dir <- file.path(tempdir(), "cp_new_dir_test")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  expect_false(dir.exists(tmp_dir))
  cp <- checkpointer(backend = "file", path = tmp_dir)
  expect_true(dir.exists(tmp_dir))
})

test_that("file backend requires path", {
  expect_error(checkpointer(backend = "file"), "requires a `path`")
})

test_that("file backend isolates threads to separate files", {
  tmp_dir <- tempfile("cp_iso_")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  cp <- checkpointer(backend = "file", path = tmp_dir)
  cp$save("thread-A", "n1", list(a = 1))
  cp$save("thread-B", "n2", list(b = 2))

  files <- list.files(tmp_dir, pattern = "\\.json$")
  expect_length(files, 2)
})
