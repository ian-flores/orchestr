test_that("new_interrupt creates agentgraph_interrupt condition", {
  state <- list(messages = "hello")
  cond <- new_interrupt(state = state, node = "reviewer", step = 3L)

  expect_s3_class(cond, "agentgraph_interrupt")
  expect_s3_class(cond, "condition")
  expect_equal(cond$node, "reviewer")
  expect_equal(cond$step, 3L)
  expect_identical(cond$state, state)
  expect_match(cond$message, "reviewer")
  expect_match(cond$message, "3")
})

test_that("new_interrupt can be caught with tryCatch", {
  cond <- new_interrupt(state = list(), node = "check", step = 1L)

  caught <- tryCatch(
    {
      rlang::cnd_signal(cond)
      NULL
    },
    agentgraph_interrupt = function(c) c
  )

  expect_s3_class(caught, "agentgraph_interrupt")
  expect_equal(caught$node, "check")
})

test_that("approval_tool returns an ellmer tool definition", {
  skip_if_not_installed("ellmer")

  tool <- approval_tool()

  # ellmer::tool() returns an R6 ToolDef object

  expect_true(!is.null(tool))
})

test_that("approval_tool accepts custom prompt_fn", {
  skip_if_not_installed("ellmer")

  custom_fn <- function(action) paste0("Please approve: ", action, "? ")
  tool <- approval_tool(prompt_fn = custom_fn)

  expect_true(!is.null(tool))
})
