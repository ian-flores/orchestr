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
#' @param supervisor An `Agent` object that decides routing.
#' @param workers Named list of `Agent` objects.
#' @return An `AgentGraph` object.
#' @export
supervisor_graph <- function(supervisor, workers) {
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

  schema <- state_schema(messages = "append:list")
  gb <- graph_builder(state_schema = schema)
  gb$add_node("supervisor", as_node(supervisor))

  worker_names <- names(workers)
  mapping <- as.list(stats::setNames(worker_names, worker_names))
  mapping[["end"]] <- END

  # The supervisor's response text should contain a worker name
  route_fn <- function(state) {
    msgs <- state$messages
    last_msg <- if (length(msgs) > 0L) as.character(msgs[[length(msgs)]]) else ""
    for (wn in worker_names) {
      if (grepl(wn, last_msg, fixed = TRUE)) return(wn)
    }
    "end"
  }

  gb$add_conditional_edge("supervisor", route_fn, mapping)
  for (wn in worker_names) {
    gb$add_node(wn, as_node(workers[[wn]]))
    gb$add_edge(wn, "supervisor")
  }
  gb$set_entry_point("supervisor")
  gb$compile()
}
