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

test_that("thread_id longer than 200 characters is rejected", {
  cp <- checkpointer()
  long_id <- paste(rep("a", 201), collapse = "")
  expect_error(cp$save(long_id, "node_a", list(x = 1)), "200 characters")
  expect_error(cp$load(long_id), "200 characters")
  expect_error(cp$history(long_id), "200 characters")
})

test_that("thread_id exactly 200 characters is accepted", {
  cp <- checkpointer()
  exact_id <- paste(rep("b", 200), collapse = "")
  expect_no_error(cp$save(exact_id, "node_a", list(x = 1)))
  result <- cp$load(exact_id)
  expect_equal(result$node, "node_a")
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

  files <- list.files(tmp_dir, pattern = "\\.jsonl$")
  expect_length(files, 2)
})


# ---- thread_id collision resistance (S10) ----

test_that("thread_ids that would collide under gsub get separate files", {
  tmp_dir <- tempfile("cp_collision_")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  cp <- checkpointer(backend = "file", path = tmp_dir)
  cp$save("a/b", "n1", list(x = 1))
  cp$save("a_b", "n2", list(x = 2))

  # They should produce different files because the hash suffix differs
  files <- list.files(tmp_dir, pattern = "\\.jsonl$")
  expect_length(files, 2)

  r1 <- cp$load("a/b")
  r2 <- cp$load("a_b")
  expect_equal(r1$state$x, 1)
  expect_equal(r2$state$x, 2)
})


# ---- Schema versioning (S9) ----

test_that("file backend writes _schema_version in JSONL entries", {
  tmp_dir <- tempfile("cp_ver_")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  cp <- checkpointer(backend = "file", path = tmp_dir)
  cp$save("t1", "node_a", list(x = 1))

  # Read raw file and check for version field
  files <- list.files(tmp_dir, pattern = "\\.jsonl$", full.names = TRUE)
  raw_line <- readLines(files[[1]], n = 1)
  parsed <- jsonlite::fromJSON(raw_line, simplifyVector = FALSE)
  expect_equal(parsed[["_schema_version"]], 1L)
})

test_that("reading old-format checkpoint data warns about missing version", {
  tmp_dir <- tempfile("cp_oldver_")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)
  dir.create(tmp_dir, recursive = TRUE)

  # Write a JSONL line WITHOUT _schema_version (simulating old format)
  # Use the same filename scheme: safe_thread_id produces sanitized-hash
  safe_id <- paste0("old_thread-", substr(rlang::hash("old_thread"), 1, 8))
  jsonl_path <- file.path(tmp_dir, paste0(safe_id, ".jsonl"))
  entry <- list(node = "n1", state = list(x = 1), timestamp = Sys.time())
  cat(jsonlite::toJSON(entry, auto_unbox = TRUE), "\n",
      file = jsonl_path, sep = "")

  cp <- checkpointer(backend = "file", path = tmp_dir)
  expect_warning(
    cp$load("old_thread"),
    "without a schema version"
  )
})


# ---- lock_class (S15) ----

test_that("Checkpointer class is locked", {
  cp <- checkpointer()
  expect_error(cp$new_field <- 1, "locked")
})
