# Helper: build a simple two-node graph
build_traced_graph <- function() {
  g <- graph_builder()
  g$add_node("a", function(state, config) list(value = state$value + 1))
  g$add_node("b", function(state, config) list(value = state$value * 2))
  g$add_edge("a", "b")
  g$add_edge("b", "__end__")
  g$set_entry_point("a")
  g$compile()
}


# ---- invoke() without tracing ----

test_that("invoke() with trace = NULL works normally", {
  ag <- build_traced_graph()
  result <- ag$invoke(list(value = 0), trace = NULL)
  expect_equal(result$value, 2)
})


# ---- invoke() with tracing ----

test_that("invoke() with trace creates spans for each node", {
  skip_if_not_installed("securetrace")

  ag <- build_traced_graph()
  tr <- securetrace::Trace$new("test-invoke")
  tr$start()

  result <- ag$invoke(list(value = 0), trace = tr)
  tr$end()

  expect_equal(result$value, 2)
  expect_length(tr$spans, 2)
})

test_that("invoke() span names follow 'node:{name}' pattern", {
  skip_if_not_installed("securetrace")

  ag <- build_traced_graph()
  tr <- securetrace::Trace$new("test-names")
  tr$start()

  ag$invoke(list(value = 0), trace = tr)
  tr$end()

  span_names <- vapply(tr$spans, function(s) s$name, character(1))
  expect_equal(span_names, c("node:a", "node:b"))
})

test_that("invoke() spans have correct metadata", {
  skip_if_not_installed("securetrace")

  ag <- build_traced_graph()
  tr <- securetrace::Trace$new("test-meta")
  tr$start()

  ag$invoke(list(value = 0), trace = tr)
  tr$end()

  # First span: node a, step 0

  expect_equal(tr$spans[[1]]$metadata$node, "a")
  expect_equal(tr$spans[[1]]$metadata$step, 0L)
  # Second span: node b, step 1
  expect_equal(tr$spans[[2]]$metadata$node, "b")
  expect_equal(tr$spans[[2]]$metadata$step, 1L)
})

test_that("invoke() spans have type 'custom'", {
  skip_if_not_installed("securetrace")

  ag <- build_traced_graph()
  tr <- securetrace::Trace$new("test-type")
  tr$start()

  ag$invoke(list(value = 0), trace = tr)
  tr$end()

  types <- vapply(tr$spans, function(s) s$type, character(1))
  expect_equal(types, c("custom", "custom"))
})

test_that("invoke() spans are ended with 'ok' status", {
  skip_if_not_installed("securetrace")

  ag <- build_traced_graph()
  tr <- securetrace::Trace$new("test-status")
  tr$start()

  ag$invoke(list(value = 0), trace = tr)
  tr$end()

  statuses <- vapply(tr$spans, function(s) s$status, character(1))
  expect_equal(statuses, c("ok", "ok"))
})


# ---- Error handling with tracing ----

test_that("invoke() error in node results in span with error status", {
  skip_if_not_installed("securetrace")

  g <- graph_builder()
  g$add_node("ok_node", function(state, config) list(x = 1))
  g$add_node("bad_node", function(state, config) stop("boom"))
  g$add_edge("ok_node", "bad_node")
  g$add_edge("bad_node", "__end__")
  g$set_entry_point("ok_node")
  ag <- g$compile()

  tr <- securetrace::Trace$new("test-error")
  tr$start()

  expect_error(ag$invoke(list(), trace = tr), "boom")
  tr$end()

  # Two spans: ok_node succeeded, bad_node errored
  expect_length(tr$spans, 2)
  expect_equal(tr$spans[[1]]$status, "ok")
  expect_equal(tr$spans[[2]]$status, "error")
})


# ---- stream() with tracing ----

test_that("stream() with trace creates spans", {
  skip_if_not_installed("securetrace")

  ag <- build_traced_graph()
  tr <- securetrace::Trace$new("test-stream")
  tr$start()

  snapshots <- ag$stream(list(value = 0), trace = tr)
  tr$end()

  expect_length(snapshots, 2)
  expect_length(tr$spans, 2)

  span_names <- vapply(tr$spans, function(s) s$name, character(1))
  expect_equal(span_names, c("node:a", "node:b"))
})

test_that("stream() with trace = NULL works normally", {
  ag <- build_traced_graph()
  snapshots <- ag$stream(list(value = 0), trace = NULL)
  expect_length(snapshots, 2)
  expect_equal(snapshots[[2]]@state$value, 2)
})


# ---- Warning when securetrace not installed ----

test_that("invoke() warns when trace is non-NULL but securetrace not installed", {
  ag <- build_traced_graph()

  local_mocked_bindings(
    is_installed = function(pkg, ...) {
      if (pkg == "securetrace") FALSE else TRUE
    },
    .package = "rlang"
  )

  expect_warning(
    ag$invoke(list(value = 0), trace = "fake_trace"),
    "securetrace is not installed"
  )
})

test_that("stream() warns when trace is non-NULL but securetrace not installed", {
  ag <- build_traced_graph()

  local_mocked_bindings(
    is_installed = function(pkg, ...) {
      if (pkg == "securetrace") FALSE else TRUE
    },
    .package = "rlang"
  )

  expect_warning(
    ag$stream(list(value = 0), trace = "fake_trace"),
    "securetrace is not installed"
  )
})
