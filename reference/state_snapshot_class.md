# State snapshot S7 class

Records the state at a particular node and step in graph execution.

## Usage

``` r
state_snapshot_class(state = NULL, node = character(0), step = NULL)
```

## Arguments

- state:

  Named list of current state.

- node:

  Character string naming the node.

- step:

  Integer step number.

## Examples

``` r
snap <- state_snapshot_class(state = list(x = 1), node = "a", step = 1L)
snap@node
#> [1] "a"
snap@step
#> [1] 1
```
