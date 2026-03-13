# Create a sequential pipeline graph

Chains agents in order: agent1 -\> agent2 -\> ... -\> END.

## Usage

``` r
graph_pipeline(..., max_iterations = 100L)

pipeline_graph(...)
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
[`graph_react()`](https://ian-flores.github.io/orchestr/reference/graph_react.md),
[`graph_supervisor()`](https://ian-flores.github.io/orchestr/reference/graph_supervisor.md)

## Examples

``` r
if (FALSE) { # \dontrun{
chat1 <- ellmer::chat_openai(model = "gpt-4o")
chat2 <- ellmer::chat_openai(model = "gpt-4o")
graph <- graph_pipeline(agent("drafter", chat1), agent("reviewer", chat2))
graph$invoke(list(messages = list("Write a poem")))
} # }
```
