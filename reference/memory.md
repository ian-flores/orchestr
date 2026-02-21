# Create a key-value memory store

Create a key-value memory store

## Usage

``` r
memory(backend = c("local", "file"), path = NULL)
```

## Arguments

- backend:

  Either `"local"` (in-process list) or `"file"` (JSON file).

- path:

  File path for the file backend.

## Value

A `Memory` R6 object.

## Note

The `path` parameter for file backends should be a trusted value. Do not
derive it from LLM output or untrusted user input.

## See also

Other persistence:
[`checkpointer()`](https://ian-flores.github.io/orchestr/reference/checkpointer.md)

## Examples

``` r
mem <- memory()
mem$set("foo", 42)
mem$get("foo")
#> [1] 42
```
