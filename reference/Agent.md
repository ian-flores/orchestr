# Create an Agent

Preferred constructor for creating Agent objects. Wraps the `Agent` R6
class.

## Usage

``` r
agent(
  name,
  chat,
  tools = list(),
  system_prompt = NULL,
  secure = FALSE,
  sandbox = TRUE,
  memory = NULL
)
```

## Arguments

- name:

  Character string identifying this agent.

- chat:

  An ellmer::Chat object.

- tools:

  List of tool objects.

- system_prompt:

  Optional system prompt override.

- secure:

  Logical; use securer sandbox.

- sandbox:

  Logical; enable OS sandbox when secure is TRUE.

- memory:

  Optional Memory object.

## Value

An `Agent` R6 object.

## Chat Protocol

The `chat` object must implement these methods:

- `$chat(prompt)` - Send a message and return the response text

- `$get_turns()` - Return the conversation history

- `$set_turns(turns)` - Replace the conversation history

- `$clone(deep = TRUE)` - Deep clone the chat object

## See also

Other agents:
[`react_graph()`](https://ian-flores.github.io/orchestr/reference/react_graph.md)

## Examples

``` r
if (FALSE) { # \dontrun{
chat <- ellmer::chat_openai(model = "gpt-4o")
a <- agent("researcher", chat)
a$invoke("What is R?")
} # }
```
