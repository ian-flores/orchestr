# ---- react_graph ----

test_that("react_graph() builds a runnable graph", {
  chat <- MockChat$new(responses = list("done"))
  agent <- Agent$new(name = "react", chat = chat)
  ag <- react_graph(agent)
  expect_s3_class(ag, "AgentGraph")
  expect_true("agent" %in% ag$get_nodes())
  expect_true("tools" %in% ag$get_nodes())
})

test_that("react_graph() routes to end when no tool calls", {
  chat <- MockChat$new(responses = list("final answer"))
  agent <- Agent$new(name = "react", chat = chat)
  ag <- react_graph(agent)

  result <- ag$invoke(list(messages = list("question"), pending_tool_calls = list()))
  expect_true("messages" %in% names(result))
})

test_that("react_graph() rejects non-Agent", {
  expect_error(react_graph("bad"), "Agent object")
})


# ---- pipeline_graph ----

test_that("pipeline_graph() chains agents", {
  chat1 <- MockChat$new(responses = list("first"))
  chat2 <- MockChat$new(responses = list("second"))
  a1 <- Agent$new(name = "a1", chat = chat1)
  a2 <- Agent$new(name = "a2", chat = chat2)

  ag <- pipeline_graph(a1, a2)
  expect_s3_class(ag, "AgentGraph")
  nodes <- ag$get_nodes()
  expect_length(nodes, 2)
})

test_that("pipeline_graph() uses provided names", {
  chat <- MockChat$new(responses = list("r"))
  a1 <- Agent$new(name = "a1", chat = chat)
  a2 <- Agent$new(name = "a2", chat = MockChat$new(responses = list("s")))

  ag <- pipeline_graph(first = a1, second = a2)
  expect_equal(ag$get_nodes(), c("first", "second"))
})

test_that("pipeline_graph() auto-generates names", {
  chat <- MockChat$new(responses = list("r"))
  a1 <- Agent$new(name = "x", chat = chat)
  a2 <- Agent$new(name = "y", chat = MockChat$new(responses = list("s")))

  ag <- pipeline_graph(a1, a2)
  expect_equal(ag$get_nodes(), c("step_1", "step_2"))
})

test_that("pipeline_graph() executes in sequence", {
  chat1 <- MockChat$new(responses = list("from_a"))
  chat2 <- MockChat$new(responses = list("from_b"))
  a1 <- Agent$new(name = "a", chat = chat1)
  a2 <- Agent$new(name = "b", chat = chat2)

  ag <- pipeline_graph(a1, a2)
  result <- ag$invoke(list(messages = list("start")))
  # Last response should be from agent b
  msgs <- result$messages
  expect_equal(msgs[[length(msgs)]], "from_b")
})

test_that("pipeline_graph() requires at least one agent", {
  expect_error(pipeline_graph(), "At least one agent")
})

test_that("pipeline_graph() rejects non-Agent args", {
  expect_error(pipeline_graph("bad"), "Agent objects")
})


# ---- supervisor_graph ----

test_that("supervisor_graph() builds a graph with correct nodes", {
  sup_chat <- MockChat$new(responses = list("thinking..."))
  supervisor <- Agent$new(name = "sup", chat = sup_chat)

  w1_chat <- MockChat$new(responses = list("worker1 result"))
  workers <- list(worker1 = Agent$new(name = "w1", chat = w1_chat))

  ag <- supervisor_graph(supervisor, workers)
  expect_s3_class(ag, "AgentGraph")
  expect_true("supervisor" %in% ag$get_nodes())
  expect_true("worker1" %in% ag$get_nodes())
})

test_that("supervisor_graph() injects routing system prompt", {
  sup_chat <- MockChat$new(responses = list("done"))
  supervisor <- Agent$new(name = "sup", chat = sup_chat)
  workers <- list(
    coder = Agent$new(name = "c", chat = MockChat$new()),
    writer = Agent$new(name = "w", chat = MockChat$new())
  )

  ag <- supervisor_graph(supervisor, workers)
  sp <- sup_chat$get_system_prompt()
  expect_match(sp, "coder")
  expect_match(sp, "writer")
  expect_match(sp, "FINISH")
})

test_that("supervisor_graph() defaults to FINISH when route tool not called", {
  # MockChat doesn't execute tools, so next_worker stays NULL -> "FINISH" -> END
  sup_chat <- MockChat$new(responses = list("I'll just think"))
  supervisor <- Agent$new(name = "sup", chat = sup_chat)
  workers <- list(alpha = Agent$new(name = "a", chat = MockChat$new()))

  ag <- supervisor_graph(supervisor, workers)
  result <- ag$invoke(list(messages = list("start")))
  expect_true(is.list(result))
  expect_equal(result$next_worker, "FINISH")
})

test_that("supervisor_graph() registers route tool on supervisor chat", {
  sup_chat <- MockChat$new(responses = list("thinking"))
  supervisor <- Agent$new(name = "sup", chat = sup_chat)
  workers <- list(w1 = Agent$new(name = "w1", chat = MockChat$new()))

  ag <- supervisor_graph(supervisor, workers)
  # After compile, the route tool should have been registered during invoke
  result <- ag$invoke(list(messages = list("start")))
  tools <- mock_chat_tools(sup_chat)
  expect_true(length(tools) > 0L)
})

test_that("supervisor_graph() rejects invalid args", {
  expect_error(supervisor_graph("bad", list()), "Agent object")
  sup <- Agent$new(name = "s", chat = MockChat$new())
  expect_error(supervisor_graph(sup, list("bad")), "named list")
})
