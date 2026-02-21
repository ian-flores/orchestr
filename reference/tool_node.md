# Create a tool execution node

Returns a handler function that processes pending tool calls in the
state.

## Usage

``` r
tool_node(tools)
```

## Arguments

- tools:

  Named list of tool functions keyed by tool name.

## Value

A function suitable for use as a graph node handler.

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
[`route_tool_calls()`](https://ian-flores.github.io/orchestr/reference/route_tool_calls.md)

## Examples

``` r
if (FALSE) { # \dontrun{
tools <- list(add = function(a, b) a + b)
handler <- tool_node(tools)
} # }
```
