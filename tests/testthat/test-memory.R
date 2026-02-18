# ---- Memory: local backend ----

test_that("memory() creates a local Memory by default", {
  mem <- memory()
  expect_s3_class(mem, "Memory")
  expect_equal(mem$keys(), character(0))
})

test_that("set/get round-trips values", {
  mem <- memory()
  mem$set("key1", 42)
  expect_equal(mem$get("key1"), 42)
})

test_that("get() returns default when key missing", {
  mem <- memory()
  expect_null(mem$get("missing"))
  expect_equal(mem$get("missing", "fallback"), "fallback")
})

test_that("has() checks key existence", {
  mem <- memory()
  expect_false(mem$has("x"))
  mem$set("x", 1)
  expect_true(mem$has("x"))
})

test_that("delete() removes a key", {
  mem <- memory()
  mem$set("x", 1)
  mem$delete("x")
  expect_false(mem$has("x"))
})

test_that("keys() returns all keys", {
  mem <- memory()
  mem$set("a", 1)
  mem$set("b", 2)
  expect_setequal(mem$keys(), c("a", "b"))
})

test_that("as_list() returns full store", {
  mem <- memory()
  mem$set("a", 1)
  mem$set("b", "two")
  result <- mem$as_list()
  expect_equal(result$a, 1)
  expect_equal(result$b, "two")
})

test_that("clear() removes everything", {
  mem <- memory()
  mem$set("a", 1)
  mem$set("b", 2)
  mem$clear()
  expect_equal(mem$keys(), character(0))
})

test_that("set() returns self for chaining", {
  mem <- memory()
  result <- mem$set("x", 1)
  expect_identical(result, mem)
})

test_that("invalid key errors", {
  mem <- memory()
  expect_error(mem$set(123, "val"), "non-empty single character")
  expect_error(mem$set("", "val"), "non-empty single character")
  expect_error(mem$get(NULL), "non-empty single character")
})


# ---- Memory: file backend ----

test_that("file backend persists to disk", {
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)

  mem1 <- memory(backend = "file", path = tmp)
  mem1$set("x", 100)
  mem1$set("y", "hello")

  # Create a new Memory pointing at the same file

  mem2 <- memory(backend = "file", path = tmp)
  expect_equal(mem2$get("x"), 100)
  expect_equal(mem2$get("y"), "hello")
})

test_that("file backend delete persists", {
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)

  mem <- memory(backend = "file", path = tmp)
  mem$set("a", 1)
  mem$delete("a")

  mem2 <- memory(backend = "file", path = tmp)
  expect_false(mem2$has("a"))
})

test_that("file backend clear persists", {
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)

  mem <- memory(backend = "file", path = tmp)
  mem$set("a", 1)
  mem$clear()

  mem2 <- memory(backend = "file", path = tmp)
  expect_equal(mem2$keys(), character(0))
})

test_that("file backend requires path", {
  expect_error(memory(backend = "file"), "requires a `path`")
})
