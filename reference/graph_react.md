# Create a ReAct (Reasoning + Acting) agent graph

Builds a single-agent graph with state management and checkpointing.
Tool calling is handled internally by ellmer's `Chat` class during
`$chat()`, so no separate tool dispatch node is needed.

`react_graph()` was renamed to `graph_react()` in version 0.2.0 and is
now deprecated.

## Usage

``` r
graph_react(agent, max_iterations = 10L)

react_graph(...)
```

## Arguments

- agent:

  An `Agent` object.

- max_iterations:

  Integer safety cap.

- ...:

  Arguments passed to `graph_react()`.

## Value

A compiled `AgentGraph` object.

## Details

Tools should be registered on the agent at construction time via
`agent(tools = ...)` rather than passed here.

## See also

Other agents:
[`agent()`](https://ian-flores.github.io/orchestr/reference/Agent.md)

Other convenience:
[`graph_pipeline()`](https://ian-flores.github.io/orchestr/reference/graph_pipeline.md),
[`graph_supervisor()`](https://ian-flores.github.io/orchestr/reference/graph_supervisor.md)

## Examples

``` r
if (FALSE) { # \dontrun{
chat <- ellmer::chat_openai(model = "gpt-4o")
a <- agent("assistant", chat)
graph <- graph_react(a)
graph$invoke(list(messages = list("Hello")))
} # }
```
