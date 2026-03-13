# Create a supervisor graph that routes to workers

The supervisor agent decides which worker to invoke based on its
response. Each worker's response is fed back to the supervisor for
re-evaluation.

`supervisor_graph()` was renamed to `graph_supervisor()` in version
0.2.0 and is now deprecated.

## Usage

``` r
graph_supervisor(supervisor, workers, max_iterations = 50L)

supervisor_graph(...)
```

## Arguments

- supervisor:

  An `Agent` object that decides routing. A system prompt suffix and a
  `route` tool are automatically injected.

- workers:

  Named list of `Agent` objects.

- max_iterations:

  Integer safety cap (default 50).

- ...:

  Arguments passed to `graph_supervisor()`.

## Value

A compiled `AgentGraph` object.

## Details

The supervisor node sets `state$next_worker` via a routing tool that the
supervisor calls. The routing condition reads this field to dispatch to
the correct worker, or end the graph if the supervisor calls
`route("FINISH")`.

## See also

Other convenience:
[`graph_pipeline()`](https://ian-flores.github.io/orchestr/reference/graph_pipeline.md),
[`graph_react()`](https://ian-flores.github.io/orchestr/reference/graph_react.md)

## Examples

``` r
if (FALSE) { # \dontrun{
sup <- agent("boss", ellmer::chat_openai(model = "gpt-4o"))
w1 <- agent("coder", ellmer::chat_openai(model = "gpt-4o"))
w2 <- agent("tester", ellmer::chat_openai(model = "gpt-4o"))
graph <- graph_supervisor(sup, list(coder = w1, tester = w2))
} # }
```
