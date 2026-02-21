# Getting Started with orchestr

## Installation

``` r
# install.packages("remotes")
remotes::install_github("ian-flores/orchestr")
```

## API Key Setup

orchestr uses [ellmer](https://github.com/tidyverse/ellmer) for LLM
access. Set your provider’s API key before running any examples:

``` r
# For Anthropic (Claude)
Sys.setenv(ANTHROPIC_API_KEY = "your-key-here")

# For OpenAI
Sys.setenv(OPENAI_API_KEY = "your-key-here")
```

See ellmer’s documentation for all supported providers.

## Your First Agent

An `Agent` wraps an ellmer `Chat` object. The
[`agent()`](https://ian-flores.github.io/orchestr/reference/Agent.md)
constructor is the recommended way to create one.

``` r
library(orchestr)
library(ellmer)

analyst <- agent("analyst", chat = chat_anthropic(
  system_prompt = "You are a data analyst. Analyze data and provide insights."
))

# Single-turn conversation
response <- analyst$invoke("Describe the key features of the iris dataset.")
cat(response)
```

## Adding Tools

Agents become more powerful when you give them tools. ellmer’s `Chat`
class handles tool call loops internally – when an agent has registered
tools, they are executed automatically during `$chat()`.

``` r
summary_tool <- tool(
  function(dataset_name) {
    data <- get(dataset_name, envir = asNamespace("datasets"))
    paste(capture.output(summary(data)), collapse = "\n")
  },
  "Get a summary of a built-in R dataset.",
  arguments = list(
    dataset_name = type_string("Name of a dataset in the datasets package")
  )
)

analyst <- agent("analyst",
  chat = chat_anthropic(
    system_prompt = "You are a data analyst. Use your tools to examine data."
  ),
  tools = list(summary_tool)
)

response <- analyst$invoke("Summarize the mtcars dataset.")
cat(response)
```

## Single-Agent Graph with `react_graph()`

The
[`react_graph()`](https://ian-flores.github.io/orchestr/reference/react_graph.md)
function wraps a single agent with state management and checkpointing.
This is the simplest way to run an agent inside a graph.

``` r
analyst <- agent("analyst", chat = chat_anthropic(
  system_prompt = "You are a data analyst. Analyze data and provide insights."
))

graph <- react_graph(analyst)
result <- graph$invoke(list(messages = list(
  "What are the key relationships in the mtcars dataset?"
)))
```

Use `verbose = TRUE` when compiling to see execution flow. With the
convenience functions, pass `verbose` to `$invoke()`:

``` r
result <- graph$invoke(
  list(messages = list("Describe the distribution of mpg in mtcars.")),
  verbose = TRUE
)
```

## Agent Pipeline with `pipeline_graph()`

Chain multiple agents in sequence. Each agent processes the state and
passes it to the next. One LLM call per agent.

``` r
profiler <- agent("profiler", chat = chat_anthropic(
  system_prompt = "Profile datasets: describe columns, types, missing values, distributions."
))

analyst <- agent("analyst", chat = chat_anthropic(
  system_prompt = "Given a data profile, identify patterns, correlations, and anomalies."
))

pipeline <- pipeline_graph(profiler, analyst)
result <- pipeline$invoke(list(messages = list(
  "Analyze the mtcars dataset focusing on fuel efficiency factors."
)))
```

## Next Steps

- **[Multi-Agent
  Workflows](https://ian-flores.github.io/orchestr/articles/multi-agent.md)**
  – pipelines, supervisor routing, and visualization
- **[Secure
  Execution](https://ian-flores.github.io/orchestr/articles/securer.md)**
  – sandboxed code execution with securer
