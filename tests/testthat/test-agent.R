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

test_that("fork preserves the secure flag", {
  chat <- MockChat$new(responses = list("ok"))
  # Create non-secure agent and fork it
  agent_nonsecure <- Agent$new(name = "ns", chat = chat, secure = FALSE)
  forked_ns <- agent_nonsecure$fork()
  # Access internal field via R6 enclosure
  expect_false(forked_ns$.__enclos_env__$private$.secure)

  # We can't fully test secure = TRUE without securer installed,

  # but we can check the field is copied correctly by checking default
  chat2 <- MockChat$new(responses = list("ok"))
  agent_default <- Agent$new(name = "def", chat = chat2)
  forked_default <- agent_default$fork()
  expect_false(forked_default$.__enclos_env__$private$.secure)
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

# ---- agent() constructor function ----

test_that("agent() constructor creates an Agent", {
  chat <- MockChat$new(responses = list("hello"))
  a <- agent(name = "from-constructor", chat = chat)
  expect_s3_class(a, "Agent")
})

test_that("agent() passes through all arguments", {
  chat <- MockChat$new()
  a <- agent(
    name = "full",
    chat = chat,
    system_prompt = "Be helpful",
    secure = FALSE,
    sandbox = FALSE
  )
  expect_s3_class(a, "Agent")
  expect_equal(chat$get_system_prompt(), "Be helpful")
})

# ---- invoke with state context injection ----

test_that("invoke injects state fields as context prefix", {
  chat <- MockChat$new(responses = list("got it"))
  agent <- Agent$new(name = "ctx", chat = chat)

  agent$invoke("do something", state = list(
    messages = list("ignored"),
    user_name = "Alice",
    topic = "weather"
  ))

  # Check that the prompt sent to the chat had a "Context:" prefix
  turns <- chat$get_turns()
  user_prompt <- turns[[1]]$content
  expect_match(user_prompt, "Context:")
  expect_match(user_prompt, "user_name: Alice")
  expect_match(user_prompt, "topic: weather")
  expect_match(user_prompt, "do something")
})

test_that("invoke does not inject context when state has only messages", {
  chat <- MockChat$new(responses = list("ok"))
  agent <- Agent$new(name = "no-ctx", chat = chat)

  agent$invoke("hello", state = list(messages = list("msg")))

  turns <- chat$get_turns()
  user_prompt <- turns[[1]]$content
  # Should be just the prompt, no Context: prefix
  expect_equal(user_prompt, "hello")
})

test_that("invoke handles empty state gracefully", {
  chat <- MockChat$new(responses = list("fine"))
  agent <- Agent$new(name = "empty-state", chat = chat)

  result <- agent$invoke("test", state = list())
  expect_equal(result, "fine")
})

test_that("invoke_turn also injects state context", {
  chat <- MockChat$new(responses = list("noted"))
  agent <- Agent$new(name = "turn-ctx", chat = chat)

  turn <- agent$invoke_turn("do it", state = list(priority = "high"))

  turns <- chat$get_turns()
  user_prompt <- turns[[1]]$content
  expect_match(user_prompt, "Context:")
  expect_match(user_prompt, "priority: high")
})

# ---- finalize ----

test_that("finalize calls close without error", {
  chat <- MockChat$new()
  agent <- Agent$new(name = "finalizer", chat = chat)

  # finalize is private (R6 >= 2.4.0 convention); delegates to close()
  priv <- agent$.__enclos_env__$private
  expect_no_error(priv$finalize())
  # calling again is safe (close is idempotent)
  expect_no_error(priv$finalize())
})

# ---- lock_class ----

test_that("Agent class is locked (cannot add new fields)", {
  chat <- MockChat$new()
  agent <- Agent$new(name = "locked", chat = chat)

  expect_error(agent$new_field <- "bad", "locked")
})
