# Create an approval tool for human-in-the-loop workflows

Returns an
[`ellmer::tool()`](https://ellmer.tidyverse.org/reference/tool.html)
definition that prompts a human for approval via
[`readline()`](https://rdrr.io/r/base/readline.html). If approved,
returns `"approved"`. If rejected, calls
[`ellmer::tool_reject()`](https://ellmer.tidyverse.org/reference/tool_reject.html)
to signal rejection to the LLM.

## Usage

``` r
approval_tool(prompt_fn = NULL)
```

## Arguments

- prompt_fn:

  Optional function that receives the tool arguments and returns a
  character string to display as the approval prompt. Defaults to
  `"Approve this action? (yes/no): "`.

## Value

An ellmer tool definition for human-in-the-loop approval.

## See also

Other interrupts:
[`new_interrupt()`](https://ian-flores.github.io/orchestr/reference/new_interrupt.md)

## Examples

``` r
if (FALSE) { # \dontrun{
tool <- approval_tool()
chat <- ellmer::chat_openai(model = "gpt-4o")
chat$register_tool(tool)
} # }
```
