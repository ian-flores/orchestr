# MockGraph for testing as_mermaid without AgentGraph
MockGraph <- R6::R6Class(
  "MockGraph",
  public = list(
    initialize = function(nodes, edges) {
      private$.nodes <- nodes
      private$.edges <- edges
    },
    get_nodes = function() private$.nodes,
    get_edges = function() private$.edges
  ),
  private = list(
    .nodes = NULL,
    .edges = NULL
  )
)

test_that("as_mermaid renders simple linear graph", {
  graph <- MockGraph$new(
    nodes = c("start", "process", END),
    edges = list(
      list(from = "start", to = "process"),
      list(from = "process", to = END)
    )
  )

  result <- as_mermaid(graph)
  expect_match(result, "graph TD")
  expect_match(result, 'start\\["start"\\]')
  expect_match(result, 'process\\["process"\\]')
  expect_match(result, "END\\(\\(END\\)\\)")
  expect_match(result, "start --> process")
  expect_match(result, "process --> END")
})

test_that("as_mermaid renders conditional edges", {
  graph <- MockGraph$new(
    nodes = c("router", "agent_a", "agent_b"),
    edges = list(
      list(
        from = "router",
        condition = "route_fn",
        mapping = list(option_a = "agent_a", option_b = "agent_b")
      )
    )
  )

  result <- as_mermaid(graph)
  expect_match(result, "router -->\\|option_a\\| agent_a")
  expect_match(result, "router -->\\|option_b\\| agent_b")
})

test_that("as_mermaid sanitizes node names with special chars", {
  graph <- MockGraph$new(
    nodes = c("my-node", "other node"),
    edges = list(
      list(from = "my-node", to = "other node")
    )
  )

  result <- as_mermaid(graph)
  # Hyphens and spaces replaced with underscores in IDs
  expect_match(result, 'my_node\\["my-node"\\]')
  expect_match(result, 'other_node\\["other node"\\]')
  expect_match(result, "my_node --> other_node")
})

test_that("as_mermaid sanitizes labels with Mermaid-special characters", {
  # Test that special characters like [], {}, <>, |, " in labels are escaped
  graph <- MockGraph$new(
    nodes = c("node[1]", "node<2>"),
    edges = list(
      list(from = "node[1]", to = "node<2>")
    )
  )

  result <- as_mermaid(graph)
  # IDs should have special chars replaced with underscores
  expect_match(result, "node_1_")
  expect_match(result, "node_2_")
  # Labels should be sanitized with entity references, inside quotes
  expect_match(result, '\\["node&#91;1&#93;"\\]')
  expect_match(result, '\\["node&lt;2&gt;"\\]')
})

test_that("as_mermaid handles conditional edge labels with special chars", {
  graph <- MockGraph$new(
    nodes = c("a", "b"),
    edges = list(
      list(
        from = "a",
        condition = "fn",
        mapping = list("go|fast" = "b")
      )
    )
  )

  result <- as_mermaid(graph)
  # The pipe character in label should be escaped
  expect_match(result, "go&#124;fast")
})

test_that("END constant equals __end__", {
  expect_equal(END, "__end__")
})
