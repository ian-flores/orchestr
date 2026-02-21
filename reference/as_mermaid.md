# Render an agent graph as a Mermaid diagram

Generates a [Mermaid](https://mermaid.js.org/) flowchart string from an
`AgentGraph` object. Useful for documentation and debugging.

## Usage

``` r
as_mermaid(graph)
```

## Arguments

- graph:

  An `AgentGraph` object with `$get_nodes()` and `$get_edges()` methods.

## Value

A character string containing a Mermaid diagram definition.

## Examples

``` r
g <- graph_builder()
g$add_node("a", function(state, config) list())
g$add_edge("a", "__end__")
g$set_entry_point("a")
graph <- g$compile()
cat(as_mermaid(graph))
#> graph TD
#>     a["a"]
#>     a --> END
```
