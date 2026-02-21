# Convert an Agent to a graph node handler function

Convert an Agent to a graph node handler function

## Usage

``` r
as_node(agent, input_key = "messages", output_key = "messages")
```

## Arguments

- agent:

  An `Agent` object.

- input_key:

  State key containing the input prompt (default `"messages"`).

- output_key:

  State key for the response (default `"messages"`).

## Value

A function suitable for use as a graph node handler.

## See also

Other node-helpers:
[`route_to()`](https://ian-flores.github.io/orchestr/reference/route_to.md),
[`route_tool_calls()`](https://ian-flores.github.io/orchestr/reference/route_tool_calls.md),
[`tool_node()`](https://ian-flores.github.io/orchestr/reference/tool_node.md)

## Examples

``` r
if (FALSE) { # \dontrun{
chat <- ellmer::chat_openai(model = "gpt-4o")
a <- agent("helper", chat)
handler <- as_node(a)
} # }
```
