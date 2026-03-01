# Multi-Agent Workflows

## Choosing a multi-agent pattern

When a single agent cannot handle a task because it has distinct stages
or requires different expertise for different subtasks, orchestr offers
two multi-agent patterns: pipelines and supervisors.

A pipeline is the right choice when you know the sequence of steps at
design time. Data flows linearly from one specialist to the next, like
an assembly line. Each agent makes exactly one LLM call, so costs are
predictable and execution order is deterministic.

A supervisor is the right choice when the routing depends on the content
of the request. A coordinator agent reads the user’s message, decides
which specialist should handle it, and dispatches accordingly. The
supervisor can route to multiple workers across several iterations,
which makes it suitable for open-ended tasks where the needed expertise
is not known in advance.

Here is a comparison of the two patterns:

     Pattern     | Flow          | LLM Calls  | Best For
     ------------|---------------|------------|----------------------------------
     Pipeline    | A -> B -> C   | 1 per node | Fixed stages, predictable cost
     Supervisor  | Router -> *   | 2+ per     | Dynamic routing, open-ended tasks
                 |               | iteration  |

If your workflow has a fixed sequence of steps, start with a pipeline.
If the routing logic depends on the user’s input, use a supervisor. If
you need something more complex (conditional branches, cycles,
human-in-the-loop approvals), drop down to
[`graph_builder()`](https://ian-flores.github.io/orchestr/reference/graph_builder.md)
for full control over the topology.

## Pipeline pattern

A pipeline passes state through a sequence of agents, each transforming
it before handing off to the next. Each agent has a focused role, which
makes individual agents easier to test and swap than a single monolithic
prompt.

The pipeline flow looks like this:

     [User Input]
          |
          v
     +-----------+     +-----------+     +-----------+
     |  Agent A  | --> |  Agent B  | --> |  Agent C  |
     | (profile) |     | (analyze) |     |  (report) |
     +-----------+     +-----------+     +-----------+
                                              |
                                              v
                                        [Final Output]

Use
[`pipeline_graph()`](https://ian-flores.github.io/orchestr/reference/pipeline_graph.md)
for a concise setup, or
[`graph_builder()`](https://ian-flores.github.io/orchestr/reference/graph_builder.md)
for full control.

### Using `pipeline_graph()`

The simplest way to create a pipeline. Pass agents in order and orchestr
wires the edges automatically.

``` r
library(orchestr)
library(ellmer)

drafter <- agent("drafter", chat = chat_anthropic(
  system_prompt = "Write a short draft on the given topic."
))

editor <- agent("editor", chat = chat_anthropic(
  system_prompt = "Improve the following draft. Fix grammar and clarity."
))

pipeline <- pipeline_graph(drafter, editor)

result <- pipeline$invoke(list(
  messages = list("Write about the benefits of open source software.")
))
cat(result$messages[[length(result$messages)]])
```

### Data analysis pipeline

A more realistic pipeline that profiles data, analyzes patterns, and
produces a report. The profiler gathers facts, the analyst interprets
them, and the reporter writes up the results. Each agent sees the
accumulated conversation history, so the analyst can reference the
profiler’s output and the reporter can reference both.

``` r
profiler <- agent("profiler", chat = chat_anthropic(
  system_prompt = "Profile datasets: describe columns, types, missing values, distributions."
))

analyst <- agent("analyst", chat = chat_anthropic(
  system_prompt = "Given a data profile, identify patterns, correlations, and anomalies."
))

reporter <- agent("reporter", chat = chat_anthropic(
  system_prompt = "Write a clear, non-technical summary of analytical findings."
))

graph <- pipeline_graph(profiler, analyst, reporter)
result <- graph$invoke(list(messages = list(
  "Analyze the mtcars dataset focusing on fuel efficiency factors."
)))
```

### Using `graph_builder()` directly

For conditional edges, cycles, or custom node functions, use the builder
API.
[`pipeline_graph()`](https://ian-flores.github.io/orchestr/reference/pipeline_graph.md)
and
[`supervisor_graph()`](https://ian-flores.github.io/orchestr/reference/supervisor_graph.md)
use this same API internally. The builder exposes the full graph
topology: add nodes, wire edges (including conditional edges), and set
the entry point explicitly.

``` r
drafter <- agent("drafter", chat = chat_anthropic(
  system_prompt = "Write a short draft on the given topic."
))

editor <- agent("editor", chat = chat_anthropic(
  system_prompt = "Improve the following draft. Fix grammar and clarity."
))

g <- graph_builder()
g$add_node("draft", drafter)
g$add_node("edit", editor)
g$add_edge("draft", "edit")
g$add_edge("edit", END)
g$set_entry_point("draft")

pipeline <- g$compile(verbose = TRUE)

result <- pipeline$invoke(list(
  messages = list("Write about functional programming in R.")
))
cat(result$messages[[length(result$messages)]])
```

## Supervisor pattern

Supervisors make routing decisions at runtime. A supervisor agent reads
the user’s request, picks the right specialist, and dispatches the work
using a `route` tool that orchestr injects automatically. After the
worker responds, control returns to the supervisor, which can route
again or finish.

A question about calculus goes to the math worker; a request to polish
prose goes to the writing worker. The supervisor decides using the LLM’s
own judgment, guided by its system prompt and the worker descriptions.

The routing flow looks like this:

                     +------------+
                     | Supervisor |
                     +-----+------+
                           |
              route("math") | route("writing") | FINISH
                   |                |               |
                   v                v               v
              +--------+      +----------+      [Output]
              |  Math  |      | Writing  |
              +--------+      +----------+
                   |                |
                   +----+     +----+
                        |     |
                        v     v
                   (back to Supervisor)

``` r
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

# Route to math
result <- graph$invoke(list(
  messages = list("Calculate the integral of x^2 from 0 to 1.")
))
```

The supervisor automatically receives a `route` tool that it calls to
dispatch to workers or finish. Start with low `max_iterations` values to
control costs; each iteration involves an LLM call for the supervisor
plus the selected worker.

## State management

All graph types in orchestr share a common state model. State is a named
list that flows through the graph and gets modified by each node. By
default, orchestr uses a simple schema where `messages` is a list that
gets appended to as agents respond.

State flow determines what each agent sees. In a pipeline, the second
agent sees the first agent’s output in the message history. In a
supervisor, each worker sees the full conversation including the
supervisor’s routing decisions. Agents build on each other’s work
without explicit message passing.

For advanced use cases, `StateSchema$new()` lets you define typed fields
with custom reducers. For example, you might accumulate a `findings`
list across pipeline stages while keeping a `summary` field that gets
overwritten by the final agent.

## Streaming state snapshots

Use `$stream()` to collect state snapshots at each step. This is useful
for building progress indicators in interactive applications, or for
debugging graph execution by looking at intermediate states.

``` r
pipeline <- pipeline_graph(
  agent("drafter", chat = chat_anthropic(
    system_prompt = "Write a short draft on the given topic."
  )),
  agent("editor", chat = chat_anthropic(
    system_prompt = "Improve the following draft."
  ))
)

snapshots <- pipeline$stream(list(
  messages = list("Write about functional programming in R.")
))

for (snap in snapshots) {
  cat(sprintf("Step %d, node: %s\n", snap$step, snap$node))
}
```

## Visualizing the graph

[`as_mermaid()`](https://ian-flores.github.io/orchestr/reference/as_mermaid.md)
generates a Mermaid diagram string for a graph, which you can render in
any Mermaid-compatible viewer (GitHub markdown, pkgdown sites, Quarto
documents, or the Mermaid live editor).

``` r
supervisor <- agent("supervisor", chat = chat_anthropic(
  system_prompt = "You coordinate workers."
))
math_worker <- agent("math", chat = chat_anthropic(
  system_prompt = "Math expert."
))
writing_worker <- agent("writing", chat = chat_anthropic(
  system_prompt = "Writing expert."
))

graph <- supervisor_graph(
  supervisor = supervisor,
  workers = list(math = math_worker, writing = writing_worker)
)

cat(as_mermaid(graph))
# Output:
# graph TD
#     supervisor[supervisor]
#     math[math]
#     writing[writing]
#     supervisor -->|math| math
#     supervisor -->|writing| writing
#     math --> supervisor
#     writing --> supervisor
```

## Next steps

- [Getting
  started](https://ian-flores.github.io/orchestr/articles/quickstart.md):
  single-agent basics and provider setup
- [Secure
  execution](https://ian-flores.github.io/orchestr/articles/securer.md):
  sandboxed code execution with securer
- [Traced
  workflows](https://ian-flores.github.io/orchestr/articles/tracing.md):
  observability with securetrace
- [Governed
  agent](https://ian-flores.github.io/orchestr/articles/governed-agent.md):
  the full 7-package stack
