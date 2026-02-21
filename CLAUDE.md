# orchestr – Development Guide

## What This Is

An R package for graph-based multi-agent workflow orchestration. Built
on ellmer for LLM chat and optionally securer for sandboxed code
execution.

## Architecture

    Agent (R6)           -- wraps ellmer::Chat + optional securer
    GraphBuilder (R6)    -- fluent API for constructing graphs
    AgentGraph (R6)      -- compiled, runnable graph with event loop
    StateSchema (R6)     -- typed state with reducers
    Memory (R6)          -- key-value store (local + file backends)
    Checkpointer (R6)    -- workflow state persistence

## Key Files

- `R/agent.R` – Agent R6 class
- `R/graph-builder.R` – GraphBuilder fluent API
- `R/agent-graph.R` – AgentGraph execution engine
- `R/state.R` – StateSchema + state_snapshot S3 class
- `R/memory.R` – Memory R6 (local + file)
- `R/checkpointer.R` – Checkpointer R6 (memory + file)
- `R/node-helpers.R` – as_node(), tool_node(), route_tool_calls()
- `R/convenience.R` – react_graph(), pipeline_graph(),
  supervisor_graph()
- `R/interrupt.R` – interrupt conditions, approval_tool()
- `R/visualize.R` – as_mermaid() graph rendering

## Development Commands

``` bash
Rscript -e "devtools::test('.')"
Rscript -e "devtools::check('.')"
Rscript -e "devtools::document('.')"
Rscript -e "devtools::load_all('.')"
```

## Design Principles

- ellmer is Imports; securer is Suggests
- All tests use mocked ellmer Chat (no real API calls)
- Graph execution has max_iterations safety cap
- State merging uses reducers (append for lists, overwrite for scalars)
- END sentinel = “**end**” string constant
