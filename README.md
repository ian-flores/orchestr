# orchestr

Graph-based multi-agent workflow orchestration for R. Built on
[ellmer](https://github.com/tidyverse/ellmer) for LLM chat and
optionally [securer](https://github.com/ian-flores/securer) for
sandboxed code execution.

## Installation

```r
# install.packages("remotes")
remotes::install_github("ian-flores/orchestr")
```

## Features

- **Agent** -- wraps an ellmer Chat with tools and optional secure execution
- **GraphBuilder** -- fluent API for constructing agent graphs with typed state
- **Conditional routing** -- route between agents based on state
- **Human-in-the-loop** -- interrupt graph execution for human approval
- **State management** -- typed state schemas with reducers, snapshots
- **Memory & checkpointing** -- persist state across invocations
- **Visualization** -- render graphs as Mermaid diagrams

## Quick Start

### Single Agent

```r
library(orchestr)
library(ellmer)

agent <- Agent$new(
  name = "assistant",
  chat = chat_anthropic(model = "claude-sonnet-4-5-20250514"),
  system_prompt = "You are a helpful assistant."
)

agent$invoke("What is the capital of France?")
```

### Agent Pipeline

```r
drafter <- Agent$new(
  name = "drafter",
  chat = chat_anthropic(model = "claude-sonnet-4-5-20250514"),
  system_prompt = "Write a short draft on the given topic."
)

editor <- Agent$new(
  name = "editor",
  chat = chat_anthropic(model = "claude-sonnet-4-5-20250514"),
  system_prompt = "Improve the following draft."
)

g <- graph_builder()
g$add_node("draft", drafter)
g$add_node("edit", editor)
g$add_edge("draft", "edit")
g$add_edge("edit", END)
g$set_entry_point("draft")

pipeline <- g$compile()
result <- pipeline$invoke(list(messages = list("Benefits of open source.")))
```

### Supervisor Routing

```r
g <- graph_builder()

g$add_node("supervisor", function(state, config) {
  msg <- state$messages[[length(state$messages)]]
  state$route <- if (grepl("math", msg, ignore.case = TRUE)) "math" else "writing"
  state
})
g$add_node("math", math_agent)
g$add_node("writing", writing_agent)

g$add_conditional_edge(
  "supervisor",
  condition = function(state) state$route,
  mapping = list(math = "math", writing = "writing")
)
g$add_edge("math", END)
g$add_edge("writing", END)
g$set_entry_point("supervisor")

graph <- g$compile()
```

## Documentation

- [Getting Started](https://ian-flores.github.io/orchestr/articles/quickstart.html)
- [Multi-Agent Workflows](https://ian-flores.github.io/orchestr/articles/multi-agent.html)
- [Secure Execution](https://ian-flores.github.io/orchestr/articles/securer.html)

## License

MIT
