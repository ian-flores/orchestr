#' Create a ReAct (Reasoning + Acting) agent graph
#'
#' Builds a graph with an agent node that calls the agent, a tools node that
#' processes tool calls, and conditional routing between them.
#'
#' @param agent An `Agent` object.
#' @param tools Named list of tool functions.
#' @param max_iterations Integer safety cap.
#' @return An `AgentGraph` object.
#' @export
react_graph <- function(agent, tools = list(), max_iterations = 10L) {
  if (!inherits(agent, "Agent")) {
    rlang::abort("`agent` must be an Agent object.")
  }
  schema <- state_schema(messages = "append:list")
  gb <- graph_builder(state_schema = schema)
  gb$add_node("agent", as_node(agent))
  if (length(tools) > 0L) {
    gb$add_node("tools", tool_node(tools))
  } else {
    # No-op tools node
    gb$add_node("tools", function(state, config) {
      list(pending_tool_calls = list())
    })
  }
  gb$add_conditional_edge(
    "agent",
    route_tool_calls,
    list(tools = "tools", end = END)
  )
  gb$add_edge("tools", "agent")
  gb$set_entry_point("agent")
  gb$compile(max_iterations = max_iterations)
}

#' Create a sequential pipeline graph
#'
#' Chains agents in order: agent1 -> agent2 -> ... -> END.
#'
#' @param ... `Agent` objects, in execution order. If unnamed, node names
#'   are auto-generated as `"step_1"`, `"step_2"`, etc.
#' @return An `AgentGraph` object.
#' @export
pipeline_graph <- function(...) {
  agents <- list(...)
  if (length(agents) == 0L) {
    rlang::abort("At least one agent is required.")
  }
  for (a in agents) {
    if (!inherits(a, "Agent")) {
      rlang::abort("All arguments must be Agent objects.")
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
  gb$compile()
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
#' @return An `AgentGraph` object.
#' @export
supervisor_graph <- function(supervisor, workers, max_iterations = 50L) {
  if (!inherits(supervisor, "Agent")) {
    rlang::abort("`supervisor` must be an Agent object.")
  }
  if (!is.list(workers) || !rlang::is_named(workers)) {
    rlang::abort("`workers` must be a named list of Agent objects.")
  }
  for (w in workers) {
    if (!inherits(w, "Agent")) {
      rlang::abort("All workers must be Agent objects.")
    }
  }

  worker_names <- names(workers)
  valid_targets <- c(worker_names, "FINISH")

  # Inject routing tool + system prompt into the supervisor's Chat
  chat <- supervisor$get_chat()
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

  # Build the supervisor node: invokes agent, then reads the route from state
  sup_node <- function(state, config) {
    # Reset next_worker each supervisor turn
    route_result <- list(next_worker = NULL)
    # Create a one-shot route tool that captures the decision
    route_tool <- ellmer::tool(
      fun = function(worker) {
        if (!worker %in% valid_targets) {
          return(paste0(
            "Invalid worker. Choose one of: ",
            paste(valid_targets, collapse = ", ")
          ))
        }
        route_result$next_worker <<- worker
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

  mapping <- as.list(stats::setNames(worker_names, worker_names))
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
