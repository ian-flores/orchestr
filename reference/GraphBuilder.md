# GraphBuilder R6 Class

GraphBuilder R6 Class

GraphBuilder R6 Class

## Details

Fluent API for constructing agent workflow graphs. Use the
[`graph_builder()`](https://ian-flores.github.io/orchestr/reference/graph_builder.md)
constructor function.

## Methods

### Public methods

- [`GraphBuilder$new()`](#method-GraphBuilder-new)

- [`GraphBuilder$add_node()`](#method-GraphBuilder-add_node)

- [`GraphBuilder$add_edge()`](#method-GraphBuilder-add_edge)

- [`GraphBuilder$add_conditional_edge()`](#method-GraphBuilder-add_conditional_edge)

- [`GraphBuilder$set_entry_point()`](#method-GraphBuilder-set_entry_point)

- [`GraphBuilder$set_interrupt()`](#method-GraphBuilder-set_interrupt)

- [`GraphBuilder$set_checkpointer()`](#method-GraphBuilder-set_checkpointer)

- [`GraphBuilder$compile()`](#method-GraphBuilder-compile)

- [`GraphBuilder$print()`](#method-GraphBuilder-print)

- [`GraphBuilder$clone()`](#method-GraphBuilder-clone)

------------------------------------------------------------------------

### Method `new()`

Create a new GraphBuilder

#### Usage

    GraphBuilder$new(state_schema = NULL)

#### Arguments

- `state_schema`:

  Optional `StateSchema` for typed state with reducers.

------------------------------------------------------------------------

### Method `add_node()`

Add a node to the graph

#### Usage

    GraphBuilder$add_node(name, handler)

#### Arguments

- `name`:

  Character node name

- `handler`:

  Function(state, config) or Agent object

#### Returns

Self (for chaining)

------------------------------------------------------------------------

### Method `add_edge()`

Add a fixed edge between nodes

#### Usage

    GraphBuilder$add_edge(from, to)

#### Arguments

- `from`:

  Source node name

- `to`:

  Target node name (or `END`)

#### Returns

Self (for chaining)

------------------------------------------------------------------------

### Method `add_conditional_edge()`

Add a conditional edge

#### Usage

    GraphBuilder$add_conditional_edge(from, condition, mapping)

#### Arguments

- `from`:

  Source node name

- `condition`:

  Function(state) returning a character key

- `mapping`:

  Named list mapping condition keys to node names

#### Returns

Self (for chaining)

------------------------------------------------------------------------

### Method `set_entry_point()`

Set the entry point node

#### Usage

    GraphBuilder$set_entry_point(name)

#### Arguments

- `name`:

  Node name to start execution from

#### Returns

Self (for chaining)

------------------------------------------------------------------------

### Method `set_interrupt()`

Set interrupt gate nodes for human-in-the-loop

#### Usage

    GraphBuilder$set_interrupt(before = NULL, after = NULL)

#### Arguments

- `before`:

  Character vector of node names to interrupt before

- `after`:

  Character vector of node names to interrupt after

#### Returns

Self (for chaining)

------------------------------------------------------------------------

### Method `set_checkpointer()`

Attach a checkpointer for state persistence

#### Usage

    GraphBuilder$set_checkpointer(checkpointer)

#### Arguments

- `checkpointer`:

  A Checkpointer object

#### Returns

Self (for chaining)

------------------------------------------------------------------------

### Method `compile()`

Compile the graph into a runnable AgentGraph

#### Usage

    GraphBuilder$compile(max_iterations = 100L, verbose = FALSE)

#### Arguments

- `max_iterations`:

  Integer safety cap on loop iterations

- `verbose`:

  Logical; if `TRUE`, log node execution and routing via
  [`cli::cli_inform()`](https://cli.r-lib.org/reference/cli_abort.html).

#### Returns

An `AgentGraph` object

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print the builder

#### Usage

    GraphBuilder$print(...)

#### Arguments

- `...`:

  Ignored.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    GraphBuilder$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
