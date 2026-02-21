# Create a graph builder

Create a graph builder

## Usage

``` r
graph_builder(state_schema = NULL)
```

## Arguments

- state_schema:

  Optional `StateSchema` for typed state with reducers.

## Value

A `GraphBuilder` R6 object.

## See also

Other graph-building:
[`END`](https://ian-flores.github.io/orchestr/reference/END.md),
[`state_schema()`](https://ian-flores.github.io/orchestr/reference/state_schema.md)

## Examples

``` r
g <- graph_builder()
g$add_node("a", function(state, config) list(x = 1))
g$add_edge("a", END)
g$set_entry_point("a")
```
