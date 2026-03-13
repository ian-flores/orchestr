#' Create a ReAct (Reasoning + Acting) agent graph
#'
#' Builds a single-agent graph with state management and checkpointing.
#' Tool calling is handled internally by ellmer's `Chat` class during
#' `$chat()`, so no separate tool dispatch node is needed.
#'
#' Tools should be registered on the agent at construction time via
#' `agent(tools = ...)` rather than passed here.
#'
#' @param agent An `Agent` object.
#' @param max_iterations Integer safety cap.
#' @return A compiled \code{AgentGraph} object.
#' @family agents
#' @family convenience
#' @export
#' @examples
#' \dontrun{
#' chat <- ellmer::chat_openai(model = "gpt-4o")
#' a <- agent("assistant", chat)
#' graph <- graph_react(a)
#' graph$invoke(list(messages = list("Hello")))
#' }
graph_react <- function(agent, max_iterations = 10L) {
  if (!inherits(agent, "Agent")) {
    cli::cli_abort("{.arg agent} must be an {.cls Agent} object.")
  }

  schema <- state_schema(messages = "append:list")
  gb <- graph_builder(state_schema = schema)
  gb$add_node("agent", as_node(agent))
  gb$add_edge("agent", END)
  gb$set_entry_point("agent")
  gb$compile(max_iterations = max_iterations)
}

#' @description
#' `react_graph()` was renamed to `graph_react()` in version 0.2.0 and
#' is now deprecated.
#'
#' @param ... Arguments passed to [graph_react()].
#' @rdname graph_react
#' @export
react_graph <- function(...) {
  lifecycle::deprecate_warn("0.2.0", "react_graph()", "graph_react()")
  graph_react(...)
}

#' Create a sequential pipeline graph
#'
#' Chains agents in order: agent1 -> agent2 -> ... -> END.
#'
#' @param ... `Agent` objects, in execution order. If unnamed, node names
#'   are auto-generated as `"step_1"`, `"step_2"`, etc.
#' @param max_iterations Integer safety cap (default 100).
#' @return A compiled \code{AgentGraph} object.
#' @family convenience
#' @export
#' @examples
#' \dontrun{
#' chat1 <- ellmer::chat_openai(model = "gpt-4o")
#' chat2 <- ellmer::chat_openai(model = "gpt-4o")
#' graph <- graph_pipeline(agent("drafter", chat1), agent("reviewer", chat2))
#' graph$invoke(list(messages = list("Write a poem")))
#' }
graph_pipeline <- function(..., max_iterations = 100L) {
  agents <- list(...)
  if (length(agents) == 0L) {
    cli::cli_abort("At least one agent is required.")
  }
  for (a in agents) {
    if (!inherits(a, "Agent")) {
      cli::cli_abort("All arguments must be {.cls Agent} objects.")
    }
  }

  # Use provided names or generate them
  nms <- names(agents)
  if (is.null(nms)) {
    nms <- paste0("step_", seq_along(agents))
  } else {
    missing <- which(nms == "" | is.na(nms))
    nms[missing] <- paste0("step_", missing)
  }

  schema <- state_schema(messages = "append:list")
  gb <- graph_builder(state_schema = schema)
  for (i in seq_along(agents)) {
    gb$add_node(nms[[i]], as_node(agents[[i]]))
  }
  for (i in seq_len(length(agents) - 1L)) {
    gb$add_edge(nms[[i]], nms[[i + 1L]])
  }
  gb$add_edge(nms[[length(nms)]], END)
  gb$set_entry_point(nms[[1L]])
  gb$compile(max_iterations = max_iterations)
}

#' @rdname graph_pipeline
#' @export
pipeline_graph <- function(...) {
  lifecycle::deprecate_warn("0.2.0", "pipeline_graph()", "graph_pipeline()")
  graph_pipeline(...)
}

#' Create a supervisor graph that routes to workers
#'
#' The supervisor agent decides which worker to invoke based on its response.
#' Each worker's response is fed back to the supervisor for re-evaluation.
#'
#' The supervisor node sets `state$next_worker` via a routing tool that the
#' supervisor calls. The routing condition reads this field to dispatch to the
#' correct worker, or end the graph if the supervisor calls `route("FINISH")`.
#'
#' @param supervisor An `Agent` object that decides routing. A system prompt
#'   suffix and a `route` tool are automatically injected.
#' @param workers Named list of `Agent` objects.
#' @param max_iterations Integer safety cap (default 50).
#' @return A compiled \code{AgentGraph} object.
#' @family convenience
#' @export
#' @examples
#' \dontrun{
#' sup <- agent("boss", ellmer::chat_openai(model = "gpt-4o"))
#' w1 <- agent("coder", ellmer::chat_openai(model = "gpt-4o"))
#' w2 <- agent("tester", ellmer::chat_openai(model = "gpt-4o"))
#' graph <- graph_supervisor(sup, list(coder = w1, tester = w2))
#' }
graph_supervisor <- function(supervisor, workers, max_iterations = 50L) {
  if (!inherits(supervisor, "Agent")) {
    cli::cli_abort("{.arg supervisor} must be an {.cls Agent} object.")
  }
  if (!is.list(workers) || !rlang::is_named(workers)) {
    cli::cli_abort("{.arg workers} must be a named list of {.cls Agent} objects.")
  }
  for (w in workers) {
    if (!inherits(w, "Agent")) {
      cli::cli_abort("All workers must be {.cls Agent} objects.")
    }
  }

  worker_names <- names(workers)
  valid_targets <- c(worker_names, "FINISH")

  # Clone the chat to avoid mutating the supervisor's original Chat
  chat <- supervisor$get_chat()$clone(deep = TRUE)
  existing_sp <- chat$get_system_prompt() %||% ""
  routing_sp <- paste0(
    existing_sp,
    "\n\nYou coordinate a team of workers: ",
    paste(worker_names, collapse = ", "), ".\n",
    "After each worker response, decide whether to delegate to another ",
    "worker or finish. Call the `route` tool with the worker name or ",
    "\"FINISH\" to end."
  )
  chat$set_system_prompt(routing_sp)

  # Shared environment for capturing route decisions across invocations
  route_result <- new.env(parent = emptyenv())
  route_result$next_worker <- NULL

  # Register route tool ONCE during graph construction
  route_tool <- ellmer::tool(
    fun = function(worker) {
      if (!worker %in% valid_targets) {
        return(paste0(
          "Invalid worker. Choose one of: ",
          paste(valid_targets, collapse = ", ")
        ))
      }
      route_result$next_worker <- worker
      paste0("Routing to: ", worker)
    },
    description = paste0(
      "Route to a worker or finish. Valid targets: ",
      paste(valid_targets, collapse = ", ")
    ),
    arguments = list(
      worker = ellmer::type_string(paste0(
        "Worker name or FINISH. Options: ",
        paste(valid_targets, collapse = ", ")
      ))
    )
  )
  chat$register_tool(route_tool)

  # Build the supervisor node handler (does NOT re-register the tool)
  sup_node <- function(state, config) {
    route_result$next_worker <- NULL
    msgs <- state$messages
    prompt <- if (length(msgs) > 0L) as.character(msgs[[length(msgs)]]) else ""
    response <- chat$chat(prompt)
    list(
      messages = list(response),
      next_worker = route_result$next_worker %||% "FINISH"
    )
  }

  schema <- state_schema(messages = "append:list", next_worker = "character")
  gb <- graph_builder(state_schema = schema)
  gb$add_node("supervisor", sup_node)

  mapping <- as.list(setNames(worker_names, worker_names))
  mapping[["FINISH"]] <- END

  route_fn <- function(state) {
    state$next_worker %||% "FINISH"
  }

  gb$add_conditional_edge("supervisor", route_fn, mapping)
  for (wn in worker_names) {
    gb$add_node(wn, as_node(workers[[wn]]))
    gb$add_edge(wn, "supervisor")
  }
  gb$set_entry_point("supervisor")
  gb$compile(max_iterations = max_iterations)
}

#' @description
#' `supervisor_graph()` was renamed to `graph_supervisor()` in version 0.2.0
#' and is now deprecated.
#'
#' @param ... Arguments passed to [graph_supervisor()].
#' @rdname graph_supervisor
#' @export
supervisor_graph <- function(...) {
  lifecycle::deprecate_warn("0.2.0", "supervisor_graph()", "graph_supervisor()")
  graph_supervisor(...)
}
