# Create a typed state schema

Defines fields and their types/reducers for graph state. Field specs are
strings: `"logical"`, `"numeric"`, `"character"`, `"list"`, `"any"`, or
`"append:list"` for append reducer.

## Usage

``` r
state_schema(..., .max_append = Inf)
```

## Arguments

- ...:

  Named field specifications (e.g., `messages = "append:list"`,
  `done = "logical"`).

- .max_append:

  Maximum number of items to retain for append reducers. Defaults to
  `Inf` (no limit). When the limit is exceeded, only the most recent
  items are kept.

## Value

A `StateSchema` R6 object.

## See also

Other graph-building:
[`END`](https://ian-flores.github.io/orchestr/reference/END.md),
[`graph_builder()`](https://ian-flores.github.io/orchestr/reference/graph_builder.md)

## Examples

``` r
schema <- state_schema(messages = "append:list", done = "logical")
schema$validate(list(done = TRUE))
schema$merge(list(messages = list("a")), list(messages = list("b")))
#> $messages
#> $messages[[1]]
#> [1] "a"
#> 
#> $messages[[2]]
#> [1] "b"
#> 
#> 
```
