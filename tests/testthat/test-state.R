# ---- StateSchema ----

test_that("state_schema() creates a StateSchema", {
  schema <- state_schema(messages = "append:list", done = "logical")
  expect_s3_class(schema, "StateSchema")
  expect_equal(schema$field_names(), c("messages", "done"))
})

test_that("state_schema() errors with no fields", {
  expect_error(state_schema(), "at least one field")
})

test_that("state_schema() errors with unnamed fields", {
  expect_error(state_schema("logical"), "must be named")
})

test_that("validate() accepts valid types", {
  schema <- state_schema(x = "numeric", y = "character")
  expect_true(schema$validate(list(x = 1.5)))
  expect_true(schema$validate(list(y = "hello")))
  expect_true(schema$validate(list(x = 42, y = "ok")))
})

test_that("validate() rejects wrong types", {
  schema <- state_schema(x = "numeric")
  expect_error(schema$validate(list(x = "not a number")), "expects type")
})

test_that("validate() rejects unknown fields", {
  schema <- state_schema(x = "numeric")
  expect_error(schema$validate(list(z = 1)), "Unknown state fields")
})

test_that("validate() passes for 'any' type", {
  schema <- state_schema(data = "any")
  expect_true(schema$validate(list(data = "string")))
  expect_true(schema$validate(list(data = 42)))
  expect_true(schema$validate(list(data = list(a = 1))))
})

test_that("validate() passes for empty updates", {
  schema <- state_schema(x = "numeric")
  expect_true(schema$validate(list()))
  expect_true(schema$validate(NULL))
})

test_that("merge() overwrites by default", {
  schema <- state_schema(x = "numeric", y = "character")
  current <- list(x = 1, y = "a")
  result <- schema$merge(current, list(x = 99))
  expect_equal(result$x, 99)
  expect_equal(result$y, "a")
})

test_that("merge() appends for append:list reducer", {
  schema <- state_schema(msgs = "append:list")
  current <- list(msgs = list("hello"))
  result <- schema$merge(current, list(msgs = list("world")))
  expect_equal(result$msgs, list("hello", "world"))
})

test_that("merge() appends to empty state", {
  schema <- state_schema(msgs = "append:list")
  result <- schema$merge(list(), list(msgs = list("first")))
  expect_equal(result$msgs, list("first"))
})

test_that("merge() validates before merging", {
  schema <- state_schema(x = "numeric")
  expect_error(schema$merge(list(x = 1), list(x = "bad")), "expects type")
})

test_that("all supported types validate correctly", {
  schema <- state_schema(
    a = "logical",
    b = "numeric",
    c = "character",
    d = "integer",
    e = "list",
    f = "data.frame"
  )
  expect_true(schema$validate(list(a = TRUE)))
  expect_true(schema$validate(list(b = 3.14)))
  expect_true(schema$validate(list(c = "hi")))
  expect_true(schema$validate(list(d = 1L)))
  expect_true(schema$validate(list(e = list(1, 2))))
  expect_true(schema$validate(list(f = data.frame(x = 1))))
})


# ---- max_append parameter ----

test_that("max_append truncates append reducer results", {
  schema <- state_schema(items = "append:list", .max_append = 3)
  # Start with empty, add 5 items one at a time
  state <- list(items = list())
  state <- schema$merge(state, list(items = list("a")))
  state <- schema$merge(state, list(items = list("b")))
  state <- schema$merge(state, list(items = list("c")))
  state <- schema$merge(state, list(items = list("d")))
  state <- schema$merge(state, list(items = list("e")))

  # Only the last 3 items should remain
  expect_length(state$items, 3L)
  expect_equal(state$items, list("c", "d", "e"))
})

test_that("max_append truncates when adding multiple items at once", {
  schema <- state_schema(log = "append:list", .max_append = 2)
  state <- list(log = list("old"))
  state <- schema$merge(state, list(log = list("new1", "new2", "new3")))
  expect_length(state$log, 2L)
  expect_equal(state$log, list("new2", "new3"))
})

test_that("default max_append = Inf allows unlimited growth", {
  schema <- state_schema(items = "append:list")
  expect_equal(schema$max_append, Inf)
  state <- list(items = list())
  for (i in seq_len(100)) {
    state <- schema$merge(state, list(items = list(i)))
  }
  expect_length(state$items, 100L)
})

test_that("max_append does not affect overwrite reducer", {
  schema <- state_schema(items = "append:list", count = "numeric", .max_append = 2)
  state <- list(items = list(), count = 0)
  state <- schema$merge(state, list(items = list("a"), count = 100))
  state <- schema$merge(state, list(items = list("b"), count = 200))
  state <- schema$merge(state, list(items = list("c"), count = 300))
  # append field is truncated
  expect_length(state$items, 2L)
  # overwrite field is just the last value
  expect_equal(state$count, 300)
})


# ---- state_snapshot S3 class ----

test_that("new_state_snapshot() creates correct structure", {
  snap <- new_state_snapshot(list(x = 1), "node_a", 3)
  expect_s3_class(snap, "state_snapshot")
  expect_equal(snap$state, list(x = 1))
  expect_equal(snap$node, "node_a")
  expect_equal(snap$step, 3L)
})

test_that("new_state_snapshot() validates inputs", {
  expect_error(new_state_snapshot("bad", "a", 1), "must be a list")
  expect_error(new_state_snapshot(list(), 123, 1), "single character")
  expect_error(new_state_snapshot(list(), "a", "bad"), "single number")
})

test_that("format.state_snapshot produces readable output", {
  snap <- new_state_snapshot(list(x = 1, y = 2), "node_b", 5)
  fmt <- format(snap)
  expect_match(fmt, "state_snapshot")
  expect_match(fmt, "node_b")
  expect_match(fmt, "Step: 5")
  expect_match(fmt, "x, y")
})

test_that("print.state_snapshot returns invisible self", {
  snap <- new_state_snapshot(list(a = 1), "n", 1)
  expect_output(result <- print(snap), "state_snapshot")
  expect_identical(result, snap)
})


# ---- merge_state_plain ----

test_that("merge_state_plain() does plain overwrite", {
  current <- list(a = 1, b = 2)
  updates <- list(b = 99, c = 3)
  result <- merge_state_plain(current, updates)
  expect_equal(result, list(a = 1, b = 99, c = 3))
})


# ---- lock_class (S15) ----

test_that("StateSchema class is locked", {
  schema <- state_schema(x = "numeric")
  expect_error(schema$new_field <- 1, "locked")
})
