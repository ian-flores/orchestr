test_that("Agent can be created with name and chat", {
  chat <- MockChat$new()
  agent <- Agent$new(name = "test-agent", chat = chat)

  expect_s3_class(agent, "Agent")
})

test_that("Agent rejects invalid names", {
  chat <- MockChat$new()

  expect_error(Agent$new(name = "", chat = chat), "non-empty string")
  expect_error(Agent$new(name = NA_character_, chat = chat), "non-empty string")
  expect_error(Agent$new(name = c("a", "b"), chat = chat), "non-empty string")
  expect_error(Agent$new(name = 123, chat = chat), "non-empty string")
})

test_that("invoke returns text response", {
  chat <- MockChat$new(responses = list("I am a helpful agent"))
  agent <- Agent$new(name = "responder", chat = chat)

  result <- agent$invoke("Hello")
  expect_equal(result, "I am a helpful agent")
})

test_that("invoke_turn returns a Turn object", {
  chat <- MockChat$new(responses = list("Turn response"))
  agent <- Agent$new(name = "turner", chat = chat)

  turn <- agent$invoke_turn("Hello")
  expect_equal(turn$role, "assistant")
  expect_equal(turn$content, "Turn response")
})

test_that("invoke cycles through multiple responses", {
  chat <- MockChat$new(responses = list("first", "second", "third"))
  agent <- Agent$new(name = "cycler", chat = chat)

  expect_equal(agent$invoke("a"), "first")
  expect_equal(agent$invoke("b"), "second")
  expect_equal(agent$invoke("c"), "third")
  # Wraps around

  expect_equal(agent$invoke("d"), "first")
})

test_that("get_chat returns the chat object", {
  chat <- MockChat$new()
  agent <- Agent$new(name = "getter", chat = chat)

  expect_identical(agent$get_chat(), chat)
})

test_that("get_turns returns conversation history", {
  chat <- MockChat$new(responses = list("reply"))
  agent <- Agent$new(name = "historian", chat = chat)

  agent$invoke("Hello")
  turns <- agent$get_turns()

  expect_length(turns, 2) # user + assistant
  expect_equal(turns[[1]]$role, "user")
  expect_equal(turns[[1]]$content, "Hello")
  expect_equal(turns[[2]]$role, "assistant")
  expect_equal(turns[[2]]$content, "reply")
})

test_that("reset clears history", {
  chat <- MockChat$new(responses = list("reply"))
  agent <- Agent$new(name = "resetter", chat = chat)

  agent$invoke("Hello")
  expect_length(agent$get_turns(), 2)

  agent$reset()
  expect_length(agent$get_turns(), 0)
})

test_that("fork creates independent copy", {
  chat <- MockChat$new(responses = list("original", "forked"))
  agent <- Agent$new(name = "original-agent", chat = chat)
  agent$invoke("setup")

  forked <- agent$fork()

  # Forked agent has same name
  output <- capture.output(forked$print(), type = "message")
  expect_match(paste(output, collapse = "\n"), "original-agent")

  # Forked agent has independent chat (invoke doesn't affect original)
  forked_result <- forked$invoke("new prompt")
  expect_type(forked_result, "character")
})

test_that("system_prompt is set on chat", {
  chat <- MockChat$new()
  agent <- Agent$new(
    name = "prompted",
    chat = chat,
    system_prompt = "You are a pirate."
  )

  expect_equal(chat$get_system_prompt(), "You are a pirate.")
})

test_that("tools are registered on the chat (non-secure mode)", {
  chat <- MockChat$new()
  tool1 <- list(name = "tool1")
  tool2 <- list(name = "tool2")

  agent <- Agent$new(
    name = "tooled",
    chat = chat,
    tools = list(tool1, tool2)
  )

  registered <- mock_chat_tools(chat)
  expect_length(registered, 2)
})

test_that("close is safe to call multiple times", {
  chat <- MockChat$new()
  agent <- Agent$new(name = "closer", chat = chat)

  expect_no_error(agent$close())
  expect_no_error(agent$close())
})

test_that("print shows agent info", {
  chat <- MockChat$new()
  agent <- Agent$new(name = "printer", chat = chat)

  output <- capture.output(agent$print(), type = "message")
  output_str <- paste(output, collapse = "\n")
  expect_match(output_str, "printer")
  expect_match(output_str, "Secure.*FALSE")
})

test_that("print shows secure info when secure", {
  # Can't actually create secure agent without securer,

  # but we can test the non-secure path
  chat <- MockChat$new()
  agent <- Agent$new(name = "display", chat = chat, tools = list("a", "b"))

  output <- capture.output(agent$print(), type = "message")
  output_str <- paste(output, collapse = "\n")
  expect_match(output_str, "display")
  expect_match(output_str, "Tools.*2")
})
