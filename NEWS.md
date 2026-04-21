# orchestr 0.2.0

## Documentation

* README and all five vignettes (`quickstart`, `governed-agent`,
  `multi-agent`, `securer`, `tracing`) now use the canonical
  `graph_react()` / `graph_pipeline()` / `graph_supervisor()` names
  instead of the deprecated `react_graph()` / `pipeline_graph()` /
  `supervisor_graph()` aliases. The aliases themselves are still
  exported with `lifecycle::deprecate_warn()` until a future release.

# orchestr 0.1.0

* Initial CRAN release.
* `Agent` R6 class wrapping ellmer `Chat` objects with optional securer
  sandbox integration.
* `GraphBuilder` fluent API for constructing agent graphs with typed state,
  conditional routing, and human-in-the-loop interrupts.
* `AgentGraph` compiled graph runtime with `$invoke()` and `$stream()` methods.
* `StateSchema` typed state with overwrite and append reducers.
* Convenience constructors: `react_graph()`, `pipeline_graph()`,
  `supervisor_graph()`.
* `Memory` R6 class for key-value persistence (memory and file backends).
* `Checkpointer` R6 class for workflow state persistence (memory and file
  backends using JSONL format).
* `as_mermaid()` for graph visualization.
* Optional securetrace integration for structured tracing of graph execution.
