# ---- GraphBuilder ----

test_that("graph_builder() creates a GraphBuilder", {
  g <- graph_builder()
  expect_s3_class(g, "GraphBuilder")
})

test_that("add_node() accepts functions", {
  g <- graph_builder()
  g$add_node("a", function(state, config) list())
  expect_output(print(g), "a")
})

test_that("add_node() rejects duplicate names", {
  g <- graph_builder()
  g$add_node("a", function(state, config) list())
  expect_error(
    g$add_node("a", function(state, config) list()),
    "already exists"
  )
})

test_that("add_node() rejects END as name", {
  g <- graph_builder()
  expect_error(g$add_node("__end__", function(s, c) list()), "reserved")
})

test_that("add_node() rejects non-function/non-Agent handlers", {
  g <- graph_builder()
  expect_error(g$add_node("a", "not a function"), "function or an Agent")
})

test_that("method chaining works", {
  g <- graph_builder()
  result <- g$add_node("a", function(s, c) list())$
    add_edge("a", "__end__")$
    set_entry_point("a")
  expect_identical(result, g)
})

test_that("compile() errors without entry point", {
  g <- graph_builder()
  g$add_node("a", function(s, c) list())
  expect_error(g$compile(), "Entry point must be set")
})

test_that("compile() errors with unregistered entry point", {
  g <- graph_builder()
  g$add_node("a", function(s, c) list())
  g$set_entry_point("missing")
  expect_error(g$compile(), "not a registered node")
})

test_that("compile() errors with invalid edge target", {
  g <- graph_builder()
  g$add_node("a", function(s, c) list())
  g$add_edge("a", "nonexistent")
  g$set_entry_point("a")
  expect_error(g$compile(), "not a registered node or END")
})

test_that("compile() errors with invalid edge source", {
  g <- graph_builder()
  g$add_node("a", function(s, c) list())
  g$add_edge("ghost", "a")
  g$set_entry_point("a")
  expect_error(g$compile(), "not a registered node")
})

test_that("compile() warns about unreachable nodes", {
  g <- graph_builder()
  g$add_node("a", function(s, c) list())
  g$add_node("orphan", function(s, c) list())
  g$add_edge("a", "__end__")
  g$add_edge("orphan", "__end__")
  g$set_entry_point("a")
  expect_warning(g$compile(), "Unreachable")
})

test_that("compile() returns an AgentGraph", {
  g <- graph_builder()
  g$add_node("a", function(s, c) list(x = 1))
  g$add_edge("a", "__end__")
  g$set_entry_point("a")
  ag <- g$compile()
  expect_s3_class(ag, "AgentGraph")
})

test_that("compile() validates conditional edge targets", {
  g <- graph_builder()
  g$add_node("a", function(s, c) list())
  g$add_conditional_edge("a", function(s) "go", list(go = "nowhere"))
  g$set_entry_point("a")
  expect_error(g$compile(), "not a registered node or END")
})

test_that("compile() validates conditional edge source", {
  g <- graph_builder()
  g$add_node("a", function(s, c) list())
  g$add_conditional_edge("ghost", function(s) "x", list(x = "a"))
  g$set_entry_point("a")
  expect_error(g$compile(), "not a registered node")
})

test_that("graph_builder() rejects invalid state_schema", {
  expect_error(graph_builder(state_schema = "bad"), "StateSchema")
})

test_that("set_checkpointer() rejects non-Checkpointer", {
  g <- graph_builder()
  expect_error(g$set_checkpointer("bad"), "Checkpointer")
})

test_that("END is exported and equals __end__", {
  expect_equal(END, "__end__")
})

# ---- compile(verbose = TRUE) ----

test_that("compile(verbose = TRUE) produces a verbose AgentGraph", {
  g <- graph_builder()
  g$add_node("a", function(s, c) list(x = 1))
  g$add_edge("a", "__end__")
  g$set_entry_point("a")
  ag <- g$compile(verbose = TRUE)
  expect_s3_class(ag, "AgentGraph")

  # Verify the AgentGraph logs when invoked
  msgs <- character(0)
  withCallingHandlers(
    ag$invoke(list()),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  combined <- paste(msgs, collapse = " ")
  expect_match(combined, "Starting graph execution")
})

test_that("compile(verbose = FALSE) produces a quiet AgentGraph", {
  g <- graph_builder()
  g$add_node("a", function(s, c) list(x = 1))
  g$add_edge("a", "__end__")
  g$set_entry_point("a")
  ag <- g$compile(verbose = FALSE)

  msgs <- character(0)
  withCallingHandlers(
    ag$invoke(list()),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  expect_length(msgs, 0L)
})
