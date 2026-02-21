# Create a constant router

Returns a condition function that always routes to the given node name.

## Usage

``` r
route_to(node_name)
```

## Arguments

- node_name:

  Character node name to route to.

## Value

A function that always returns the given node name.

## See also

Other node-helpers:
[`as_node()`](https://ian-flores.github.io/orchestr/reference/as_node.md),
[`route_tool_calls()`](https://ian-flores.github.io/orchestr/reference/route_tool_calls.md),
[`tool_node()`](https://ian-flores.github.io/orchestr/reference/tool_node.md)

## Examples

``` r
router <- route_to("next_node")
router(list())
#> [1] "next_node"
```
