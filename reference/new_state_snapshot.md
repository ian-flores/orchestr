# Create a state snapshot

Records the state at a particular node and step in graph execution.

## Usage

``` r
new_state_snapshot(state, node, step)
```

## Arguments

- state:

  Named list of current state

- node:

  Character string naming the node

- step:

  Integer step number

## Value

A `state_snapshot` S3 object.
