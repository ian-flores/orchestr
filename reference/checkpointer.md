# Create a workflow checkpointer

Persists graph execution state so workflows can be resumed.

## Usage

``` r
checkpointer(backend = c("memory", "file"), path = NULL)
```

## Arguments

- backend:

  Either `"memory"` (in-process) or `"file"` (directory of JSON files).

- path:

  Directory path for the file backend.

## Value

A `Checkpointer` R6 object.

## See also

Other persistence:
[`memory()`](https://ian-flores.github.io/orchestr/reference/memory.md)

## Examples

``` r
cp <- checkpointer()
cp$save("thread-1", "node_a", list(x = 1))
cp$load("thread-1")
#> $node
#> [1] "node_a"
#> 
#> $state
#> $state$x
#> [1] 1
#> 
#> 
```
