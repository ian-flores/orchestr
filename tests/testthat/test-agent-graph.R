# Helper: build a simple graph
build_linear_graph <- function(schema = NULL) {
  g <- graph_builder(state_schema = schema)
  g$add_node("a", function(state, config) list(value = state$value + 1))
  g$add_node("b", function(state, config) list(value = state$value * 2))
  g$add_edge("a", "b")
  g$add_edge("b", "__end__")
  g$set_entry_point("a")
  g$compile()
}


# ---- Linear execution ----

test_that("linear graph executes A -> B -> END", {
  ag <- build_linear_graph()
  result <- ag$invoke(list(value = 0))
  # A: 0 + 1 = 1, B: 1 * 2 = 2
  expect_equal(result$value, 2)
})

test_that("linear graph with different initial state", {
  ag <- build_linear_graph()
  result <- ag$invoke(list(value = 10))
  # A: 10 + 1 = 11, B: 11 * 2 = 22
  expect_equal(result$value, 22)
})


# ---- Conditional routing ----

test_that("conditional edge routes correctly", {
  g <- graph_builder()
  g$add_node("start", function(state, config) state)
  g$add_node("even", function(state, config) list(result = "even"))
  g$add_node("odd", function(state, config) list(result = "odd"))

  g$add_conditional_edge(
    "start",
    function(state) if (state$value %% 2 == 0) "is_even" else "is_odd",
    list(is_even = "even", is_odd = "odd")
  )
  g$add_edge("even", "__end__")
  g$add_edge("odd", "__end__")
  g$set_entry_point("start")
  ag <- g$compile()

  result_even <- ag$invoke(list(value = 4))
  expect_equal(result_even$result, "even")

  result_odd <- ag$invoke(list(value = 3))
  expect_equal(result_odd$result, "odd")
})

test_that("unknown condition key errors", {
  g <- graph_builder()
  g$add_node("a", function(state, config) state)
  g$add_conditional_edge(
    "a",
    function(state) "unknown_key",
    list(known = "__end__")
  )
  g$set_entry_point("a")
  ag <- g$compile()
  expect_error(ag$invoke(list()), "no mapping exists")
})


# ---- State merging with schema ----

test_that("state merging uses schema reducers", {
  schema <- state_schema(items = "append:list", count = "numeric")
  g <- graph_builder(state_schema = schema)
  g$add_node("a", function(state, config) {
    list(items = list("from_a"), count = 1)
  })
  g$add_node("b", function(state, config) {
    list(items = list("from_b"), count = 2)
  })
  g$add_edge("a", "b")
  g$add_edge("b", "__end__")
  g$set_entry_point("a")
  ag <- g$compile()

  result <- ag$invoke(list(items = list(), count = 0))
  expect_equal(result$items, list("from_a", "from_b"))
  expect_equal(result$count, 2)  # overwritten, not appended
})


# ---- Max iterations ----

test_that("max_iterations prevents infinite loops", {
  g <- graph_builder()
  g$add_node("loop", function(state, config) {
    list(i = state$i + 1)
  })
  g$add_edge("loop", "loop")
  g$set_entry_point("loop")
  ag <- g$compile(max_iterations = 5L)

  expect_warning(
    result <- ag$invoke(list(i = 0)),
    "max_iterations"
  )
  expect_true(result$.__graph_truncated__)
})


# ---- Stream ----

test_that("stream() returns state snapshots", {
  ag <- build_linear_graph()
  snapshots <- ag$stream(list(value = 0))
  expect_length(snapshots, 2)
  expect_true(S7::S7_inherits(snapshots[[1]], state_snapshot_class))
  expect_true(S7::S7_inherits(snapshots[[2]], state_snapshot_class))
  expect_equal(snapshots[[1]]@node, "a")
  expect_equal(snapshots[[1]]@step, 1L)
  expect_equal(snapshots[[2]]@node, "b")
  expect_equal(snapshots[[2]]@step, 2L)
  expect_equal(snapshots[[2]]@state$value, 2)
})

test_that("stream() on_step callback is invoked for each step", {
  ag <- build_linear_graph()
  received_snapshots <- list()
  callback <- function(snap) {
    received_snapshots[[length(received_snapshots) + 1L]] <<- snap
  }

  snapshots <- ag$stream(list(value = 0), on_step = callback)
  expect_length(received_snapshots, 2L)
  expect_true(S7::S7_inherits(received_snapshots[[1]], state_snapshot_class))
  expect_equal(received_snapshots[[1]]@node, "a")
  expect_equal(received_snapshots[[2]]@node, "b")
})


# ---- Verbose logging ----

test_that("invoke with verbose = TRUE emits log messages", {
  ag <- build_linear_graph()
  msgs <- character(0)
  withCallingHandlers(
    ag$invoke(list(value = 0), verbose = TRUE),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  combined <- paste(msgs, collapse = " ")
  # Should mention node names and "Starting"
  expect_match(combined, "Starting graph execution")
  expect_match(combined, "a")
  expect_match(combined, "b")
  expect_match(combined, "completed in")
})

test_that("stream with verbose = TRUE emits log messages", {
  ag <- build_linear_graph()
  msgs <- character(0)
  withCallingHandlers(
    ag$stream(list(value = 0), verbose = TRUE),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  combined <- paste(msgs, collapse = " ")
  expect_match(combined, "Starting graph streaming")
  expect_match(combined, "completed in")
})

test_that("verbose = FALSE does not emit log messages", {
  ag <- build_linear_graph()
  msgs <- character(0)
  withCallingHandlers(
    ag$invoke(list(value = 0), verbose = FALSE),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  expect_length(msgs, 0L)
})


# ---- run_node error wrapping ----

test_that("run_node wraps handler errors with node name", {
  g <- graph_builder()
  g$add_node("failing_node", function(state, config) {
    stop("something broke")
  })
  g$add_edge("failing_node", "__end__")
  g$set_entry_point("failing_node")
  ag <- g$compile()

  expect_error(ag$invoke(list()), "Error in node 'failing_node'")
})


# ---- Mermaid output ----

test_that("as_mermaid() generates valid diagram", {
  ag <- build_linear_graph()
  mermaid <- ag$as_mermaid()
  expect_match(mermaid, "graph TD")
  expect_match(mermaid, "a\\[a\\]")
  expect_match(mermaid, "b\\[b\\]")
  expect_match(mermaid, "a --> b")
  expect_match(mermaid, "b --> __end__")
  expect_match(mermaid, "__start__")
})

test_that("as_mermaid() shows conditional edge labels", {
  g <- graph_builder()
  g$add_node("a", function(s, c) s)
  g$add_node("b", function(s, c) s)
  g$add_conditional_edge("a", function(s) "go", list(go = "b", stop = "__end__"))
  g$add_edge("b", "__end__")
  g$set_entry_point("a")
  ag <- g$compile()

  mermaid <- ag$as_mermaid()
  expect_match(mermaid, "a -->\\|go\\| b")
  expect_match(mermaid, "a -->\\|stop\\| __end__")
})


# ---- get_nodes / get_edges ----

test_that("get_nodes() returns node names", {
  ag <- build_linear_graph()
  expect_equal(ag$get_nodes(), c("a", "b"))
})

test_that("get_edges() returns edge specs", {
  ag <- build_linear_graph()
  edges <- ag$get_edges()
  expect_named(edges, c("fixed", "conditional"))
  expect_length(edges$fixed, 2)
})


# ---- Print/format ----

test_that("print() outputs graph info", {
  ag <- build_linear_graph()
  expect_output(print(ag), "AgentGraph")
  expect_output(print(ag), "a, b")
})

test_that("format() returns string", {
  ag <- build_linear_graph()
  fmt <- format(ag)
  expect_match(fmt, "AgentGraph")
})


# ---- Dead-end detection ----

test_that("node with no outgoing edge errors at compile time", {
  g <- graph_builder()
  g$add_node("a", function(s, c) list(x = 1))
  g$add_node("b", function(s, c) list(x = 2))
  g$add_edge("a", "b")
  # b has no edge out
  g$set_entry_point("a")
  expect_error(g$compile(), "Dead-end nodes")
})


# ---- Handler return validation ----

test_that("non-list handler return errors", {
  g <- graph_builder()
  g$add_node("bad", function(s, c) "not a list")
  g$add_edge("bad", "__end__")
  g$set_entry_point("bad")
  ag <- g$compile()
  expect_error(ag$invoke(list()), "must return a named list")
})


# ---- Checkpointing ----

test_that("checkpointing saves and resumes state", {
  cp <- checkpointer()

  g <- graph_builder()
  g$add_node("a", function(state, config) list(value = state$value + 1))
  g$add_node("b", function(state, config) list(value = state$value * 10))
  g$add_edge("a", "b")
  g$add_edge("b", "__end__")
  g$set_entry_point("a")
  g$set_checkpointer(cp)
  ag <- g$compile()

  ag$invoke(list(value = 0), config = list(thread_id = "t1"))

  # Verify checkpoints were saved
  h <- cp$history("t1")
  expect_length(h, 2)
  expect_equal(h[[1]]$node, "a")
  expect_equal(h[[2]]$node, "b")
})


# ---- Interrupt signaling ----

test_that("interrupt_before signals condition", {
  g <- graph_builder()
  g$add_node("a", function(s, c) list(x = 1))
  g$add_edge("a", "__end__")
  g$set_entry_point("a")
  g$set_interrupt(before = "a")
  ag <- g$compile()

  caught <- NULL
  withCallingHandlers(
    ag$invoke(list()),
    agentgraph_interrupt = function(cond) {
      caught <<- cond
    }
  )
  # The condition was signaled (not an error, just a signal)
  # Since signal() doesn't stop execution, the graph should complete
  expect_equal(caught$node, "a")
})

test_that("interrupt_after signals condition after node", {
  g <- graph_builder()
  g$add_node("a", function(s, c) list(x = 1))
  g$add_edge("a", "__end__")
  g$set_entry_point("a")
  g$set_interrupt(after = "a")
  ag <- g$compile()

  caught <- NULL
  withCallingHandlers(
    ag$invoke(list()),
    agentgraph_interrupt = function(cond) {
      caught <<- cond
    }
  )
  expect_equal(caught$node, "a")
  expect_equal(caught$state$x, 1)  # after execution, state is updated
})


# ---- Resume from config ----

test_that("resume_from restarts at specified node", {
  g <- graph_builder()
  g$add_node("a", function(state, config) list(value = state$value + 1))
  g$add_node("b", function(state, config) list(value = state$value * 10))
  g$add_edge("a", "b")
  g$add_edge("b", "__end__")
  g$set_entry_point("a")
  ag <- g$compile()

  # Resume from b with value=5 (skip a entirely)
  result <- ag$invoke(list(), config = list(
    resume_from = list(node = "b", state = list(value = 5))
  ))
  expect_equal(result$value, 50)
})


# ---- Graceful max_iterations truncation ----

test_that("invoke warns and returns truncated state on max_iterations", {
  g <- graph_builder()
  g$add_node("loop", function(state, config) {
    list(i = state$i + 1)
  })
  g$add_edge("loop", "loop")
  g$set_entry_point("loop")
  ag <- g$compile(max_iterations = 5L)

  expect_warning(
    result <- ag$invoke(list(i = 0)),
    "max_iterations"
  )
  expect_true(result$.__graph_truncated__)
  expect_equal(result$i, 5)
})

test_that("stream warns and returns partial snapshots on max_iterations", {
  g <- graph_builder()
  g$add_node("loop", function(state, config) {
    list(i = state$i + 1)
  })
  g$add_edge("loop", "loop")
  g$set_entry_point("loop")
  ag <- g$compile(max_iterations = 3L)

  expect_warning(
    snapshots <- ag$stream(list(i = 0)),
    "max_iterations"
  )
  expect_length(snapshots, 3)
})


# ---- Dynamic snapshot allocation ----

test_that("stream with large max_iterations does not OOM on allocation", {
  g <- graph_builder()
  g$add_node("a", function(state, config) list(value = 1))
  g$add_edge("a", "__end__")
  g$set_entry_point("a")
  # Large max_iterations but graph terminates after 1 step
  ag <- g$compile(max_iterations = 1000000L)

  snapshots <- ag$stream(list(value = 0))
  expect_length(snapshots, 1)
})

test_that("stream grows snapshot buffer dynamically beyond initial cap", {
  g <- graph_builder()
  g$add_node("loop", function(state, config) list(i = state$i + 1))
  g$add_conditional_edge(
    "loop",
    function(state) if (state$i >= 1500) "done" else "continue",
    list(done = "__end__", continue = "loop")
  )
  g$set_entry_point("loop")
  ag <- g$compile(max_iterations = 2000L)

  snapshots <- ag$stream(list(i = 0))
  # Should have exactly 1500 snapshots (i goes from 1 to 1500)
  expect_length(snapshots, 1500)
})


# ---- max_iterations validation ----

test_that("max_iterations must be a finite positive integer", {
  g <- graph_builder()
  g$add_node("a", function(s, c) list(x = 1))
  g$add_edge("a", "__end__")
  g$set_entry_point("a")

  expect_error(g$compile(max_iterations = -1L), "finite positive integer")
  expect_error(g$compile(max_iterations = 0L), "finite positive integer")
  expect_error(g$compile(max_iterations = Inf), "finite positive integer")
  expect_error(g$compile(max_iterations = NA_integer_), "finite positive integer")
  expect_error(g$compile(max_iterations = "ten"), "finite positive integer")
})
