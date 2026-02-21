# Route based on pending tool calls

Returns `"tools"` if the state has pending tool calls, `"end"`
otherwise.

## Usage

``` r
route_tool_calls(state)
```

## Arguments

- state:

  Current graph state.

## Value

Character string: either a tool node name or `END`.

## Note

These functions are for manual tool dispatch in custom node handlers.
When using
[`Agent`](https://ian-flores.github.io/orchestr/reference/Agent.md)
objects with ellmer, tool calling is handled internally by ellmer's Chat
class. See
[`react_graph`](https://ian-flores.github.io/orchestr/reference/react_graph.md)
for the recommended pattern.

## See also

Other node-helpers:
[`as_node()`](https://ian-flores.github.io/orchestr/reference/as_node.md),
[`route_to()`](https://ian-flores.github.io/orchestr/reference/route_to.md),
[`tool_node()`](https://ian-flores.github.io/orchestr/reference/tool_node.md)

## Examples

``` r
route_tool_calls(list(pending_tool_calls = list()))
#> [1] "end"
route_tool_calls(list(pending_tool_calls = list(list(name = "add"))))
#> [1] "tools"
```
