# AgentGraph R6 Class

AgentGraph R6 Class

AgentGraph R6 Class

## Details

Compiled, immutable, runnable agent graph. Created by
[GraphBuilder](https://ian-flores.github.io/orchestr/reference/GraphBuilder.md)`$compile()`,
not directly.

## Methods

### Public methods

- [`AgentGraph$new()`](#method-AgentGraph-new)

- [`AgentGraph$invoke()`](#method-AgentGraph-invoke)

- [`AgentGraph$stream()`](#method-AgentGraph-stream)

- [`AgentGraph$as_mermaid()`](#method-AgentGraph-as_mermaid)

- [`AgentGraph$get_nodes()`](#method-AgentGraph-get_nodes)

- [`AgentGraph$get_edges()`](#method-AgentGraph-get_edges)

- [`AgentGraph$print()`](#method-AgentGraph-print)

- [`AgentGraph$format()`](#method-AgentGraph-format)

- [`AgentGraph$clone()`](#method-AgentGraph-clone)

------------------------------------------------------------------------

### Method `new()`

Create a compiled agent graph. Not intended for direct use; create via
`GraphBuilder$compile()`.

#### Usage

    AgentGraph$new(
      nodes,
      edges,
      conditional_edges,
      entry,
      schema,
      interrupt_before,
      interrupt_after,
      checkpointer,
      max_iterations,
      verbose = FALSE
    )

#### Arguments

- `nodes`:

  Named list of handler functions/Agents

- `edges`:

  List of fixed edge specs

- `conditional_edges`:

  List of conditional edge specs

- `entry`:

  Character entry point node name

- `schema`:

  Optional StateSchema

- `interrupt_before`:

  Character vector of node names

- `interrupt_after`:

  Character vector of node names

- `checkpointer`:

  Optional Checkpointer

- `max_iterations`:

  Integer safety cap

- `verbose`:

  Logical; if `TRUE`, log node entry/exit with timing, routing
  decisions, and iteration count via
  [`cli::cli_inform()`](https://cli.r-lib.org/reference/cli_abort.html).

------------------------------------------------------------------------

### Method `invoke()`

Run the graph to completion

#### Usage

    AgentGraph$invoke(state = list(), config = list(), verbose = private$.verbose)

#### Arguments

- `state`:

  Named list of initial state

- `config`:

  Named list of configuration (e.g., thread_id, resume_from)

- `verbose`:

  Logical; if `TRUE`, log execution details. Overrides the graph-level
  default set at compile time.

#### Returns

Final state as a named list

------------------------------------------------------------------------

### Method `stream()`

Run the graph and collect state snapshots

#### Usage

    AgentGraph$stream(
      state = list(),
      config = list(),
      on_step = NULL,
      verbose = private$.verbose
    )

#### Arguments

- `state`:

  Named list of initial state

- `config`:

  Named list of configuration

- `on_step`:

  Optional callback function called after each node with the snapshot as
  its sole argument. Useful for real-time progress reporting.

- `verbose`:

  Logical; if `TRUE`, log execution details. Overrides the graph-level
  default set at compile time.

#### Returns

List of `state_snapshot` objects

------------------------------------------------------------------------

### Method [`as_mermaid()`](https://ian-flores.github.io/orchestr/reference/as_mermaid.md)

Generate a Mermaid diagram of the graph

#### Usage

    AgentGraph$as_mermaid()

#### Returns

Character string with Mermaid markup

------------------------------------------------------------------------

### Method `get_nodes()`

Get node names

#### Usage

    AgentGraph$get_nodes()

#### Returns

Character vector

------------------------------------------------------------------------

### Method `get_edges()`

Get edge specifications

#### Usage

    AgentGraph$get_edges()

#### Returns

List of edge specs (fixed and conditional)

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print method

#### Usage

    AgentGraph$print(...)

#### Arguments

- `...`:

  Ignored.

------------------------------------------------------------------------

### Method [`format()`](https://rdrr.io/r/base/format.html)

Format method

#### Usage

    AgentGraph$format(...)

#### Arguments

- `...`:

  Ignored.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    AgentGraph$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
