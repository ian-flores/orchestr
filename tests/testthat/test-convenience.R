# ---- graph_react ----

test_that("graph_react() builds a runnable graph", {

chat <- MockChat$new(responses = list("done"))
  agent <- Agent$new(name = "react", chat = chat)
  ag <- graph_react(agent)
  expect_s3_class(ag, "AgentGraph")
  expect_true("agent" %in% ag$get_nodes())
  # New architecture: single node, no separate "tools" node
  expect_length(ag$get_nodes(), 1L)
})

test_that("graph_react() routes agent directly to END", {
  chat <- MockChat$new(responses = list("final answer"))
  agent <- Agent$new(name = "react", chat = chat)
  ag <- graph_react(agent)

  result <- ag$invoke(list(messages = list("question")))
  expect_true("messages" %in% names(result))
})

test_that("graph_react() rejects non-Agent", {
  expect_error(graph_react("bad"), "Agent")
})

test_that("graph_react() graph has agent -> END edge", {
  chat <- MockChat$new(responses = list("ok"))
  agent <- Agent$new(name = "react", chat = chat)
  ag <- graph_react(agent)

  edges <- ag$get_edges()
  fixed <- edges$fixed
  # There should be a fixed edge from agent to END
  targets <- vapply(fixed, function(e) e$to, character(1))
  sources <- vapply(fixed, function(e) e$from, character(1))
  expect_true("agent" %in% sources)
  expect_true("__end__" %in% targets)
})

test_that("react_graph() is deprecated wrapper for graph_react()", {
  chat <- MockChat$new(responses = list("done"))
  agent <- Agent$new(name = "react", chat = chat)
  lifecycle::expect_deprecated(
    ag <- react_graph(agent)
  )
  expect_s3_class(ag, "AgentGraph")
})


# ---- graph_pipeline ----

test_that("graph_pipeline() chains agents", {
  chat1 <- MockChat$new(responses = list("first"))
  chat2 <- MockChat$new(responses = list("second"))
  a1 <- Agent$new(name = "a1", chat = chat1)
  a2 <- Agent$new(name = "a2", chat = chat2)

  ag <- graph_pipeline(a1, a2)
  expect_s3_class(ag, "AgentGraph")
  nodes <- ag$get_nodes()
  expect_length(nodes, 2)
})

test_that("graph_pipeline() uses provided names", {
  chat <- MockChat$new(responses = list("r"))
  a1 <- Agent$new(name = "a1", chat = chat)
  a2 <- Agent$new(name = "a2", chat = MockChat$new(responses = list("s")))

  ag <- graph_pipeline(first = a1, second = a2)
  expect_equal(ag$get_nodes(), c("first", "second"))
})

test_that("graph_pipeline() auto-generates names", {
  chat <- MockChat$new(responses = list("r"))
  a1 <- Agent$new(name = "x", chat = chat)
  a2 <- Agent$new(name = "y", chat = MockChat$new(responses = list("s")))

  ag <- graph_pipeline(a1, a2)
  expect_equal(ag$get_nodes(), c("step_1", "step_2"))
})

test_that("graph_pipeline() executes in sequence", {
  chat1 <- MockChat$new(responses = list("from_a"))
  chat2 <- MockChat$new(responses = list("from_b"))
  a1 <- Agent$new(name = "a", chat = chat1)
  a2 <- Agent$new(name = "b", chat = chat2)

  ag <- graph_pipeline(a1, a2)
  result <- ag$invoke(list(messages = list("start")))
  # Last response should be from agent b
  msgs <- result$messages
  expect_equal(msgs[[length(msgs)]], "from_b")
})

test_that("graph_pipeline() requires at least one agent", {
  expect_error(graph_pipeline(), "At least one agent")
})

test_that("graph_pipeline() rejects non-Agent args", {
  expect_error(graph_pipeline("bad"), "Agent")
})

test_that("pipeline_graph() is deprecated wrapper for graph_pipeline()", {
  chat <- MockChat$new(responses = list("done"))
  a1 <- Agent$new(name = "a1", chat = chat)
  lifecycle::expect_deprecated(
    ag <- pipeline_graph(a1)
  )
  expect_s3_class(ag, "AgentGraph")
})


# ---- graph_supervisor ----

test_that("graph_supervisor() builds a graph with correct nodes", {
  sup_chat <- MockChat$new(responses = list("thinking..."))
  supervisor <- Agent$new(name = "sup", chat = sup_chat)

  w1_chat <- MockChat$new(responses = list("worker1 result"))
  workers <- list(worker1 = Agent$new(name = "w1", chat = w1_chat))

  ag <- graph_supervisor(supervisor, workers)
  expect_s3_class(ag, "AgentGraph")
  expect_true("supervisor" %in% ag$get_nodes())
  expect_true("worker1" %in% ag$get_nodes())
})

test_that("graph_supervisor() does not mutate the original supervisor chat", {
  sup_chat <- MockChat$new(responses = list("done"), system_prompt = "original")
  supervisor <- Agent$new(name = "sup", chat = sup_chat)
  workers <- list(
    coder = Agent$new(name = "c", chat = MockChat$new()),
    writer = Agent$new(name = "w", chat = MockChat$new())
  )

  ag <- graph_supervisor(supervisor, workers)
  # Original chat should be untouched
  expect_equal(sup_chat$get_system_prompt(), "original")
  expect_length(mock_chat_tools(sup_chat), 0L)
})

test_that("graph_supervisor() defaults to FINISH when route tool not called", {
  # MockChat doesn't execute tools, so next_worker stays NULL -> "FINISH" -> END
  sup_chat <- MockChat$new(responses = list("I'll just think"))
  supervisor <- Agent$new(name = "sup", chat = sup_chat)
  workers <- list(alpha = Agent$new(name = "a", chat = MockChat$new()))

  ag <- graph_supervisor(supervisor, workers)
  result <- ag$invoke(list(messages = list("start")))
  expect_true(is.list(result))
  expect_equal(result$next_worker, "FINISH")
})

test_that("graph_supervisor() executes using cloned chat with routing", {
  sup_chat <- MockChat$new(responses = list("routing decision"))
  supervisor <- Agent$new(name = "sup", chat = sup_chat)
  workers <- list(w1 = Agent$new(name = "w1", chat = MockChat$new()))

  ag <- graph_supervisor(supervisor, workers)
  # Original chat should have no tools registered (clone was modified instead)
  tools <- mock_chat_tools(sup_chat)
  expect_length(tools, 0L)
  # Graph should still be functional (clone has the route tool)
  result <- ag$invoke(list(messages = list("start")))
  expect_true(is.list(result))
})

test_that("graph_supervisor() rejects invalid args", {
  expect_error(graph_supervisor("bad", list()), "Agent")
  sup <- Agent$new(name = "s", chat = MockChat$new())
  expect_error(graph_supervisor(sup, list("bad")), "named list")
})

test_that("supervisor_graph() is deprecated wrapper for graph_supervisor()", {
  sup_chat <- MockChat$new(responses = list("done"))
  supervisor <- Agent$new(name = "sup", chat = sup_chat)
  workers <- list(w1 = Agent$new(name = "w1", chat = MockChat$new()))
  lifecycle::expect_deprecated(
    ag <- supervisor_graph(supervisor, workers)
  )
  expect_s3_class(ag, "AgentGraph")
})
