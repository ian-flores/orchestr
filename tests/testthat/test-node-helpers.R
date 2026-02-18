# ---- as_node ----

test_that("as_node() returns a function", {
  chat <- MockChat$new(responses = list("response"))
  agent <- Agent$new(name = "test", chat = chat)
  handler <- as_node(agent)
  expect_true(is.function(handler))
})

test_that("as_node() handler extracts last message and returns response", {
  chat <- MockChat$new(responses = list("answer"))
  agent <- Agent$new(name = "test", chat = chat)
  handler <- as_node(agent)

  state <- list(messages = list("hello", "question"))
  result <- handler(state, list())
  expect_equal(result$messages, list("answer"))
})

test_that("as_node() uses custom input/output keys", {
  chat <- MockChat$new(responses = list("custom_reply"))
  agent <- Agent$new(name = "test", chat = chat)
  handler <- as_node(agent, input_key = "input", output_key = "output")

  state <- list(input = list("prompt"))
  result <- handler(state, list())
  expect_equal(result$output, list("custom_reply"))
  expect_null(result$messages)
})

test_that("as_node() handles character input_key", {
  chat <- MockChat$new(responses = list("ok"))
  agent <- Agent$new(name = "test", chat = chat)
  handler <- as_node(agent)

  state <- list(messages = "direct string")
  result <- handler(state, list())
  expect_equal(result$messages, list("ok"))
})

test_that("as_node() rejects non-Agent", {
  expect_error(as_node("not an agent"), "Agent object")
})


# ---- tool_node ----

test_that("tool_node() processes pending tool calls", {
  tools <- list(
    add = function(a, b) a + b,
    greet = function(name) paste("hello", name)
  )
  handler <- tool_node(tools)

  state <- list(
    pending_tool_calls = list(
      list(id = "tc1", name = "add", args = list(a = 2, b = 3)),
      list(id = "tc2", name = "greet", args = list(name = "world"))
    )
  )

  result <- handler(state, list())
  expect_length(result$tool_results, 2)
  expect_equal(result$tool_results[[1]]$result, 5)
  expect_equal(result$tool_results[[2]]$result, "hello world")
  expect_equal(result$pending_tool_calls, list())
})

test_that("tool_node() handles empty pending_tool_calls", {
  handler <- tool_node(list(x = identity))
  result <- handler(list(), list())
  expect_equal(result$tool_results, list())
  expect_equal(result$pending_tool_calls, list())
})

test_that("tool_node() skips unknown tools", {
  handler <- tool_node(list(known = identity))
  state <- list(
    pending_tool_calls = list(
      list(id = "tc1", name = "unknown_tool", args = list())
    )
  )
  result <- handler(state, list())
  expect_equal(result$tool_results, list())
})

test_that("tool_node() rejects unnamed tools list", {
  expect_error(tool_node(list(identity)), "named list")
})


# ---- route_tool_calls ----

test_that("route_tool_calls() returns 'tools' with pending calls", {
  state <- list(pending_tool_calls = list(list(id = "1")))
  expect_equal(route_tool_calls(state), "tools")
})

test_that("route_tool_calls() returns 'end' with no pending calls", {
  expect_equal(route_tool_calls(list()), "end")
  expect_equal(route_tool_calls(list(pending_tool_calls = list())), "end")
})


# ---- route_to ----

test_that("route_to() returns constant router", {
  router <- route_to("target")
  expect_equal(router(list()), "target")
  expect_equal(router(list(x = 1)), "target")
})

test_that("route_to() validates input", {
  expect_error(route_to(123), "single character")
})
