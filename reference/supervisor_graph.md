# Create a supervisor graph that routes to workers

The supervisor agent decides which worker to invoke based on its
response. Each worker's response is fed back to the supervisor for
re-evaluation.

## Usage

``` r
supervisor_graph(supervisor, workers, max_iterations = 50L)
```

## Arguments

- supervisor:

  An `Agent` object that decides routing. A system prompt suffix and a
  `route` tool are automatically injected.

- workers:

  Named list of `Agent` objects.

- max_iterations:

  Integer safety cap (default 50).

## Value

A compiled `AgentGraph` object.

## Details

The supervisor node sets `state$next_worker` via a routing tool that the
supervisor calls. The routing condition reads this field to dispatch to
the correct worker, or end the graph if the supervisor calls
`route("FINISH")`.

## See also

Other convenience:
[`pipeline_graph()`](https://ian-flores.github.io/orchestr/reference/pipeline_graph.md),
[`react_graph()`](https://ian-flores.github.io/orchestr/reference/react_graph.md)

## Examples

``` r
if (FALSE) { # \dontrun{
sup <- agent("boss", ellmer::chat_openai(model = "gpt-4o"))
w1 <- agent("coder", ellmer::chat_openai(model = "gpt-4o"))
w2 <- agent("tester", ellmer::chat_openai(model = "gpt-4o"))
graph <- supervisor_graph(sup, list(coder = w1, tester = w2))
} # }
```
