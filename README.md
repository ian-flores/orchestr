# orchestr

<!-- badges: start -->
[![R-CMD-check](https://github.com/ian-flores/orchestr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/ian-flores/orchestr/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/ian-flores/orchestr/graph/badge.svg)](https://app.codecov.io/gh/ian-flores/orchestr)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![pkgdown](https://github.com/ian-flores/orchestr/actions/workflows/pkgdown.yaml/badge.svg)](https://ian-flores.github.io/orchestr/)
<!-- badges: end -->

> [!CAUTION]
> **Alpha software.** This package is part of a broader effort by [Ian Flores Siaca](https://github.com/ian-flores) to develop proper AI infrastructure for the R ecosystem. It is under active development and should **not** be used in production until an official release is published. APIs may change without notice.

Graph-based multi-agent workflow orchestration for R. Built on
[ellmer](https://github.com/tidyverse/ellmer) for LLM chat and
optionally [securer](https://github.com/ian-flores/securer) for
sandboxed code execution.

## When to use orchestr

Use orchestr when a single ellmer chat isn't enough -- when you need multi-step reasoning (ReAct loops), parallel tool execution, supervisor-routed agent teams, or persistent memory across turns. If your workflow fits in one LLM call, use ellmer directly. If it needs orchestration, use orchestr.

## Part of the secure-r-dev Ecosystem

orchestr is part of a 7-package ecosystem for building governed AI agents in R:

```
                    ┌─────────────┐
                    │   securer    │
                    └──────┬──────┘
          ┌────────────────┼─────────────────┐
          │                │                  │
   ┌──────▼──────┐  ┌─────▼──────┐  ┌───────▼────────┐
   │ securetools  │  │ secureguard│  │ securecontext   │
   └──────┬───────┘  └─────┬──────┘  └───────┬────────┘
          └────────────────┼─────────────────┘
                    ┌──────▼────────┐
                    │>>> orchestr<<<│
                    └──────┬────────┘
          ┌────────────────┼─────────────────┐
          │                                  │
   ┌──────▼──────┐                    ┌──────▼──────┐
   │ securetrace  │                   │ securebench  │
   └─────────────┘                    └─────────────┘
```

orchestr is the orchestration hub that wires agents into workflows. It sits below the tool/guardrail/context layer and above the observability and benchmarking layers, coordinating agents that use securer for execution, secureguard for safety, and securecontext for memory.

| Package | Role |
|---------|------|
| [securer](https://github.com/ian-flores/securer) | Sandboxed R execution with tool-call IPC |
| [securetools](https://github.com/ian-flores/securetools) | Pre-built security-hardened tool definitions |
| [secureguard](https://github.com/ian-flores/secureguard) | Input/code/output guardrails (injection, PII, secrets) |
| [orchestr](https://github.com/ian-flores/orchestr) | Graph-based agent orchestration |
| [securecontext](https://github.com/ian-flores/securecontext) | Document chunking, embeddings, RAG retrieval |
| [securetrace](https://github.com/ian-flores/securetrace) | Structured tracing, token/cost accounting, JSONL export |
| [securebench](https://github.com/ian-flores/securebench) | Guardrail benchmarking with precision/recall/F1 metrics |

## Installation

```r
# install.packages("pak")
pak::pak("ian-flores/orchestr")
```

## Setup

orchestr uses [ellmer](https://github.com/tidyverse/ellmer) for LLM access. You'll need an API key for your chosen provider:

```r
# For Anthropic (Claude)
Sys.setenv(ANTHROPIC_API_KEY = "your-key-here")

# For OpenAI
Sys.setenv(OPENAI_API_KEY = "your-key-here")
```

See ellmer's documentation for all supported providers.

## Features

- **Agent** -- wraps an ellmer Chat with tools and optional secure execution
- **GraphBuilder** -- fluent API for constructing agent graphs with typed state
- **Conditional routing** -- route between agents based on state
- **Human-in-the-loop** -- interrupt graph execution for human approval
- **State management** -- typed state schemas with reducers, snapshots
- **Memory & checkpointing** -- persist state across invocations
- **Visualization** -- render graphs as Mermaid diagrams

## Quick Start

### Single Agent (ReAct)

The `react_graph()` function wraps a single agent with state management and
checkpointing. ellmer's `Chat` class handles tool call loops internally --
when an agent has registered tools, they are executed automatically during
`$chat()`. The graph wraps this with state management and checkpointing.

```r
library(orchestr)
library(ellmer)

analyst <- agent("analyst", chat = chat_anthropic(
  system_prompt = "You analyze data. Use your tools to compute results."
))
graph <- react_graph(analyst, max_iterations = 5)
result <- graph$invoke(list(messages = list("What is the mean of c(1,2,3,4,5)?")))
```

### Agent Pipeline

`pipeline_graph()` chains agents in sequence. Each agent processes the state
and passes it to the next. One LLM call per agent in the pipeline.

```r
drafter <- agent("drafter", chat = chat_anthropic(
  system_prompt = "Write a short draft on the given topic."
))

editor <- agent("editor", chat = chat_anthropic(
  system_prompt = "Improve the following draft."
))

pipeline <- pipeline_graph(drafter, editor)
result <- pipeline$invoke(list(messages = list("Benefits of open source.")))
```

### Supervisor Routing

`supervisor_graph()` creates a supervisor that routes tasks to specialized
workers. The supervisor decides which worker to invoke (or to finish) by
calling an automatically injected `route` tool.

```r
supervisor <- agent("supervisor", chat = chat_anthropic(
  system_prompt = "You coordinate workers to solve tasks."
))

math_worker <- agent("math", chat = chat_anthropic(
  system_prompt = "You are a math expert. Solve math problems step by step."
))

writing_worker <- agent("writing", chat = chat_anthropic(
  system_prompt = "You are a writing expert. Help with writing tasks."
))

graph <- supervisor_graph(
  supervisor = supervisor,
  workers = list(math = math_worker, writing = writing_worker),
  max_iterations = 10
)
result <- graph$invoke(list(messages = list("Calculate the integral of x^2 from 0 to 1.")))
```

## Cost Awareness

Each node in a graph that calls an LLM makes an API request. Be mindful of costs:

- `react_graph()`: The agent runs once, with ellmer handling any tool calls internally
- `pipeline_graph()`: One LLM call per agent in the pipeline
- `supervisor_graph(max_iterations = 50)`: Up to 50+ LLM calls (supervisor routing + worker execution). Start with low `max_iterations` values
- Use `verbose = TRUE` when compiling graphs to see execution flow: `compile(verbose = TRUE)`

## Documentation

- [Getting Started](https://ian-flores.github.io/orchestr/articles/quickstart.html)
- [Multi-Agent Workflows](https://ian-flores.github.io/orchestr/articles/multi-agent.html)
- [Secure Execution](https://ian-flores.github.io/orchestr/articles/securer.html)

## Contributing

Contributions are welcome! Please file issues on GitHub and submit pull requests.

## License

MIT
