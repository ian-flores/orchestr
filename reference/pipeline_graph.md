# Create a sequential pipeline graph

Chains agents in order: agent1 -\> agent2 -\> ... -\> END.

## Usage

``` r
pipeline_graph(..., max_iterations = 100L)
```

## Arguments

- ...:

  `Agent` objects, in execution order. If unnamed, node names are
  auto-generated as `"step_1"`, `"step_2"`, etc.

- max_iterations:

  Integer safety cap (default 100).

## Value

A compiled `AgentGraph` object.

## See also

Other convenience:
[`react_graph()`](https://ian-flores.github.io/orchestr/reference/react_graph.md),
[`supervisor_graph()`](https://ian-flores.github.io/orchestr/reference/supervisor_graph.md)

## Examples

``` r
if (FALSE) { # \dontrun{
chat1 <- ellmer::chat_openai(model = "gpt-4o")
chat2 <- ellmer::chat_openai(model = "gpt-4o")
graph <- pipeline_graph(agent("drafter", chat1), agent("reviewer", chat2))
graph$invoke(list(messages = list("Write a poem")))
} # }
```
