# Create a ReAct (Reasoning + Acting) agent graph

Builds a single-agent graph with state management and checkpointing.
Tool calling is handled internally by ellmer's `Chat` class during
`$chat()`, so no separate tool dispatch node is needed.

## Usage

``` r
react_graph(agent, max_iterations = 10L)
```

## Arguments

- agent:

  An `Agent` object.

- max_iterations:

  Integer safety cap.

## Value

A compiled `AgentGraph` object.

## Details

Tools should be registered on the agent at construction time via
`agent(tools = ...)` rather than passed here.

## See also

Other agents:
[`agent()`](https://ian-flores.github.io/orchestr/reference/Agent.md)

Other convenience:
[`pipeline_graph()`](https://ian-flores.github.io/orchestr/reference/pipeline_graph.md),
[`supervisor_graph()`](https://ian-flores.github.io/orchestr/reference/supervisor_graph.md)

## Examples

``` r
if (FALSE) { # \dontrun{
chat <- ellmer::chat_openai(model = "gpt-4o")
a <- agent("assistant", chat)
graph <- react_graph(a)
graph$invoke(list(messages = list("Hello")))
} # }
```
