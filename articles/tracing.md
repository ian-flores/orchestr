# Traced Agent Workflows

orchestr integrates with
[securetrace](https://github.com/ian-flores/securetrace) to give you
full observability into agent graph execution. Pass a `Trace` object to
`$invoke()` or `$stream()` and every node gets its own span – timing,
errors, and metadata are captured automatically.

For orchestr basics, see
[`vignette("quickstart")`](https://ian-flores.github.io/orchestr/articles/quickstart.md).
For securetrace fundamentals, see
[`vignette("observability", package = "securetrace")`](https://ian-flores.github.io/securetrace/articles/observability.html).

## Installation

``` r
# install.packages("pak")
pak::pak("ian-flores/orchestr")
pak::pak("ian-flores/securetrace")
```

## Basic Tracing

The `trace=` parameter on `AgentGraph$invoke()` accepts a
[`securetrace::Trace`](https://ian-flores.github.io/securetrace/reference/Trace.html)
object. When provided, orchestr wraps each node execution in a span
named `"node:<name>"`:

``` r
library(orchestr)
library(ellmer)
library(securetrace)

analyst <- agent("analyst", chat = chat_anthropic(
  system_prompt = "You are a data analyst."
))

graph <- react_graph(analyst)

# Create a trace and pass it to invoke
tr <- Trace$new("analyst-run", metadata = list(task = "mtcars"))
tr$start()

result <- graph$invoke(
  list(messages = list("Describe the mtcars dataset.")),
  trace = tr
)

tr$end()

# Inspect the spans
tr$summary()
#> Trace: analyst-run
#>   Spans: 1
#>   Duration: 2.3s
#>   node:analyst -- 2.3s (completed)
```

If securetrace is not installed, passing `trace=` issues a warning and
execution continues without tracing.

## Pipeline Tracing

In a pipeline, each agent becomes its own span. This makes it easy to
see where time is spent across the chain:

``` r
profiler <- agent("profiler", chat = chat_anthropic(
  system_prompt = "Profile datasets: columns, types, distributions."
))

analyst <- agent("analyst", chat = chat_anthropic(
  system_prompt = "Identify patterns and correlations from a data profile."
))

reporter <- agent("reporter", chat = chat_anthropic(
  system_prompt = "Write a non-technical summary of analytical findings."
))

pipeline <- pipeline_graph(profiler, analyst, reporter)

tr <- Trace$new("data-pipeline")
tr$start()

result <- pipeline$invoke(
  list(messages = list("Analyze mtcars fuel efficiency.")),
  trace = tr
)

tr$end()

# Three spans, one per pipeline stage
tr$summary()
#> Trace: data-pipeline
#>   Spans: 3
#>   Duration: 6.1s
#>   node:profiler  -- 2.1s (completed)
#>   node:analyst   -- 2.5s (completed)
#>   node:reporter  -- 1.5s (completed)
```

## Supervisor Tracing

Supervisor graphs produce a richer trace because the supervisor may
route to multiple workers across several iterations. Each supervisor
decision and worker execution gets its own span:

``` r
supervisor <- agent("supervisor", chat = chat_anthropic(
  system_prompt = "You coordinate workers to solve tasks."
))

math_worker <- agent("math", chat = chat_anthropic(
  system_prompt = "Solve math problems step by step."
))

writing_worker <- agent("writing", chat = chat_anthropic(
  system_prompt = "Help with writing tasks."
))

graph <- supervisor_graph(
  supervisor = supervisor,
  workers = list(math = math_worker, writing = writing_worker),
  max_iterations = 10
)

tr <- Trace$new("supervisor-run")
tr$start()

result <- graph$invoke(
  list(messages = list("Write a poem that includes the first 5 primes.")),
  trace = tr
)

tr$end()

# Spans show the routing pattern
tr$summary()
#> Trace: supervisor-run
#>   Spans: 4
#>   Duration: 8.2s
#>   node:supervisor -- 1.2s (completed)
#>   node:math       -- 1.8s (completed)
#>   node:supervisor -- 1.5s (completed)
#>   node:writing    -- 3.7s (completed)
```

## Streaming with Traces

`$stream()` also accepts `trace=`. You get both state snapshots and full
tracing:

``` r
tr <- Trace$new("streamed-pipeline")
tr$start()

snapshots <- pipeline$stream(
  list(messages = list("Analyze iris dataset.")),
  trace = tr
)

tr$end()

# State snapshots for progress reporting
for (snap in snapshots) {
  cat(sprintf("Step %d, node: %s\n", snap$step, snap$node))
}
#> Step 1, node: profiler
#> Step 2, node: analyst
#> Step 3, node: reporter

# Trace for observability
tr$summary()
```

## Cost Accounting

When agent nodes make LLM calls, securetrace can track token usage and
compute cost. Combine the `trace=` parameter with
[`trace_total_cost()`](https://ian-flores.github.io/securetrace/reference/trace_total_cost.html)
to monitor spend across an entire graph run:

``` r
tr <- Trace$new("cost-tracking")
tr$start()

result <- graph$invoke(
  list(messages = list("Explain the central limit theorem.")),
  trace = tr
)

tr$end()

# Total cost across all spans
securetrace::trace_total_cost(tr)
#> [1] 0.0234
```

For this to work, the LLM spans must have model and token information
set. If you use orchestr’s built-in Agent class with ellmer, this is
handled automatically when securetrace integration is active.

## Exporting Traces

### JSONL Export

Write traced agent runs to a JSONL file for post-hoc analysis:

``` r
exp <- jsonl_exporter("agent-traces.jsonl")

tr <- Trace$new("export-demo")
tr$start()

result <- pipeline$invoke(
  list(messages = list("Summarize the iris dataset.")),
  trace = tr
)

tr$end()

# Export the completed trace
export_trace(exp, tr)
```

### Console Export

For interactive debugging, use
[`console_exporter()`](https://ian-flores.github.io/securetrace/reference/console_exporter.html)
to print spans as they complete:

``` r
exp <- console_exporter(verbose = TRUE)

tr <- Trace$new("debug-run")
tr$start()

result <- graph$invoke(
  list(messages = list("What is 2 + 2?")),
  trace = tr
)

tr$end()
export_trace(exp, tr)
#> [TRACE] debug-run (3.1s)
#>   [SPAN] node:supervisor -- 1.2s completed
#>   [SPAN] node:math       -- 0.8s completed
#>   [SPAN] node:supervisor -- 1.1s completed
```

## Cloud-Native Integration

For production deployments, securetrace supports OTLP export (Jaeger,
Grafana Tempo), Prometheus metrics, and W3C Trace Context propagation.
See
[`vignette("cloud-native", package = "securetrace")`](https://ian-flores.github.io/securetrace/articles/cloud-native.html)
for full details.

### OTLP Export

Send traced agent runs to a Jaeger or Tempo collector:

``` r
exp <- otlp_exporter(
  endpoint = "http://localhost:4318",
  service_name = "r-agent-pipeline"
)

tr <- Trace$new("production-pipeline")
tr$start()

result <- pipeline$invoke(
  list(messages = list("Analyze mtcars.")),
  trace = tr
)

tr$end()
export_trace(exp, tr)
#> Trace exported to http://localhost:4318/v1/traces
```

### Prometheus Metrics

Expose agent metrics for Prometheus scraping. Each traced graph run
feeds counters for span counts, token usage, and cost:

``` r
reg <- prometheus_registry()
prom_exp <- prometheus_exporter(reg)

# Run several traced agent invocations
for (task in c("Summarize iris.", "Describe mtcars.", "Analyze sleep.")) {
  tr <- Trace$new("batch-run")
  tr$start()

  result <- pipeline$invoke(
    list(messages = list(task)),
    trace = tr
  )

  tr$end()
  export_trace(prom_exp, tr)
}

# View cumulative metrics
cat(format_prometheus(reg))
#> securetrace_spans_total{type="custom",status="completed"} 9
#> securetrace_traces_total{status="completed"} 3
```

## Multi-Exporter Setup

In production, combine OTLP, Prometheus, and JSONL for complete
observability:

``` r
reg <- prometheus_registry()

combined <- multi_exporter(
  otlp_exporter("http://localhost:4318", service_name = "r-agent"),
  prometheus_exporter(reg),
  jsonl_exporter("traces.jsonl")
)

# Start Prometheus scrape endpoint
srv <- serve_prometheus(reg, host = "0.0.0.0", port = 9090)

# All traced agent runs go to all three destinations
tr <- Trace$new("production-run")
tr$start()

result <- pipeline$invoke(
  list(messages = list("Full analysis of mtcars.")),
  trace = tr
)

tr$end()
export_trace(combined, tr)

# Clean up
httpuv::stopServer(srv)
```

This gives you:

- **Jaeger/Tempo** – full traces with per-node spans for each agent run
- **Prometheus** – time-series metrics for dashboards and alerting
- **JSONL** – local audit trail for compliance and post-hoc analysis

## Error Tracing

When a node fails, orchestr records the error on the span before
re-raising it. This means failed runs still produce useful traces:

``` r
tr <- Trace$new("error-demo")
tr$start()

tryCatch(
  graph$invoke(
    list(messages = list("Trigger an error.")),
    trace = tr
  ),
  error = function(e) {
    message("Graph failed: ", conditionMessage(e))
  }
)

tr$end()

# The trace contains error information on the failed span
tr$summary()
#> Trace: error-demo
#>   Spans: 1
#>   Duration: 0.5s
#>   node:supervisor -- 0.5s (error)
```
