# Create an agent graph interrupt condition

Creates a condition of class `agentgraph_interrupt` that can be
signalled to pause graph execution for human review.

## Usage

``` r
new_interrupt(state, node, step)
```

## Arguments

- state:

  The current graph state at the point of interruption.

- node:

  Character scalar. The node that triggered the interrupt.

- step:

  Integer. The execution step number.

## Value

An `agentgraph_interrupt` condition object.

## See also

Other interrupts:
[`approval_tool()`](https://ian-flores.github.io/orchestr/reference/approval_tool.md)

## Examples

``` r
cnd <- new_interrupt(list(x = 1), "review_node", 3L)
cnd$node
#> [1] "review_node"
cnd$step
#> [1] 3
```
