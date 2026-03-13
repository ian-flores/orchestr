# Package index

## Agent

- [`agent()`](https://ian-flores.github.io/orchestr/reference/Agent.md)
  : Create an Agent

## Graph Construction

- [`graph_builder()`](https://ian-flores.github.io/orchestr/reference/graph_builder.md)
  : Create a graph builder
- [`END`](https://ian-flores.github.io/orchestr/reference/END.md) : End
  sentinel for graph execution

## State

- [`state_schema()`](https://ian-flores.github.io/orchestr/reference/state_schema.md)
  : Create a typed state schema
- [`state_snapshot_class()`](https://ian-flores.github.io/orchestr/reference/state_snapshot_class.md)
  : State snapshot S7 class
- [`new_state_snapshot()`](https://ian-flores.github.io/orchestr/reference/new_state_snapshot.md)
  : Create a state snapshot

## Node Helpers

- [`as_node()`](https://ian-flores.github.io/orchestr/reference/as_node.md)
  : Convert an Agent to a graph node handler function
- [`tool_node()`](https://ian-flores.github.io/orchestr/reference/tool_node.md)
  : Create a tool execution node
- [`route_tool_calls()`](https://ian-flores.github.io/orchestr/reference/route_tool_calls.md)
  : Route based on pending tool calls
- [`route_to()`](https://ian-flores.github.io/orchestr/reference/route_to.md)
  : Create a constant router

## Convenience Graphs

- [`graph_react()`](https://ian-flores.github.io/orchestr/reference/graph_react.md)
  [`react_graph()`](https://ian-flores.github.io/orchestr/reference/graph_react.md)
  : Create a ReAct (Reasoning + Acting) agent graph
- [`graph_pipeline()`](https://ian-flores.github.io/orchestr/reference/graph_pipeline.md)
  [`pipeline_graph()`](https://ian-flores.github.io/orchestr/reference/graph_pipeline.md)
  : Create a sequential pipeline graph
- [`graph_supervisor()`](https://ian-flores.github.io/orchestr/reference/graph_supervisor.md)
  [`supervisor_graph()`](https://ian-flores.github.io/orchestr/reference/graph_supervisor.md)
  : Create a supervisor graph that routes to workers

## Memory & Persistence

- [`memory()`](https://ian-flores.github.io/orchestr/reference/memory.md)
  : Create a key-value memory store
- [`checkpointer()`](https://ian-flores.github.io/orchestr/reference/checkpointer.md)
  : Create a workflow checkpointer

## Human-in-the-Loop

- [`new_interrupt()`](https://ian-flores.github.io/orchestr/reference/new_interrupt.md)
  : Create an agent graph interrupt condition
- [`approval_tool()`](https://ian-flores.github.io/orchestr/reference/approval_tool.md)
  : Create an approval tool for human-in-the-loop workflows

## Visualization

- [`as_mermaid()`](https://ian-flores.github.io/orchestr/reference/as_mermaid.md)
  : Render an agent graph as a Mermaid diagram
