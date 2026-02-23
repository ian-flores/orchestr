# Changelog

## orchestr 0.1.0

- Initial CRAN release.
- `Agent` R6 class wrapping ellmer `Chat` objects with optional securer
  sandbox integration.
- `GraphBuilder` fluent API for constructing agent graphs with typed
  state, conditional routing, and human-in-the-loop interrupts.
- `AgentGraph` compiled graph runtime with `$invoke()` and `$stream()`
  methods.
- `StateSchema` typed state with overwrite and append reducers.
- Convenience constructors:
  [`react_graph()`](https://ian-flores.github.io/orchestr/reference/react_graph.md),
  [`pipeline_graph()`](https://ian-flores.github.io/orchestr/reference/pipeline_graph.md),
  [`supervisor_graph()`](https://ian-flores.github.io/orchestr/reference/supervisor_graph.md).
- `Memory` R6 class for key-value persistence (memory and file
  backends).
- `Checkpointer` R6 class for workflow state persistence (memory and
  file backends using JSONL format).
- [`as_mermaid()`](https://ian-flores.github.io/orchestr/reference/as_mermaid.md)
  for graph visualization.
- Optional securetrace integration for structured tracing of graph
  execution.
