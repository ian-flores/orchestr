# End sentinel for graph execution

Use `END` as a target node name to indicate that graph execution should
stop after the current node.

## Usage

``` r
END
```

## Format

An object of class `character` of length 1.

## Value

A character string (`"__end__"`) used as a sentinel value.

## See also

Other graph-building:
[`graph_builder()`](https://ian-flores.github.io/orchestr/reference/graph_builder.md),
[`state_schema()`](https://ian-flores.github.io/orchestr/reference/state_schema.md)

## Examples

``` r
# Use END as the target of a graph edge to stop execution
END
#> [1] "__end__"
g <- graph_builder()
g$add_node("a", function(state, config) list(x = 1))
g$add_edge("a", END)
```
