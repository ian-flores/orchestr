#' Convert an Agent to a graph node handler function
#'
#' @param agent An `Agent` object.
#' @param input_key State key containing the input prompt (default `"messages"`).
#' @param output_key State key for the response (default `"messages"`).
#' @return A function(state, config) suitable for `GraphBuilder$add_node()`.
#' @export
as_node <- function(agent, input_key = "messages", output_key = "messages") {
  if (!inherits(agent, "Agent")) {
    rlang::abort("`agent` must be an Agent object.")
  }
  function(state, config) {
    msgs <- state[[input_key]]
    prompt <- if (is.list(msgs) && length(msgs) > 0L) {
      as.character(msgs[[length(msgs)]])
    } else if (is.character(msgs)) {
      msgs
    } else {
      ""
    }
    response <- agent$invoke(prompt, state = state)
    updates <- list()
    updates[[output_key]] <- list(response)
    updates
  }
}

#' Create a tool execution node
#'
#' Returns a handler function that processes pending tool calls in the state.
#'
#' @param tools Named list of tool functions keyed by tool name.
#' @return A function(state, config) for use with `GraphBuilder$add_node()`.
#' @export
tool_node <- function(tools) {
  if (!is.list(tools) || !rlang::is_named(tools)) {
    rlang::abort("`tools` must be a named list of functions.")
  }
  function(state, config) {
    tool_results <- list()
    for (tc in state$pending_tool_calls %||% list()) {
      tool_fn <- tools[[tc$name]]
      if (!is.null(tool_fn)) {
        result <- do.call(tool_fn, tc$args)
        tool_results <- c(
          tool_results,
          list(list(tool_call_id = tc$id, result = result))
        )
      }
    }
    list(tool_results = tool_results, pending_tool_calls = list())
  }
}

#' Route based on pending tool calls
#'
#' Returns `"tools"` if the state has pending tool calls, `"end"` otherwise.
#'
#' @param state Current graph state.
#' @return `"tools"` or `"end"`.
#' @export
route_tool_calls <- function(state) {
  if (length(state$pending_tool_calls %||% list()) > 0L) "tools" else "end"
}

#' Create a constant router
#'
#' Returns a condition function that always routes to the given node name.
#'
#' @param node_name Character node name to route to.
#' @return A function(state) returning `node_name`.
#' @export
route_to <- function(node_name) {
  if (!is.character(node_name) || length(node_name) != 1L) {
    rlang::abort("`node_name` must be a single character string.")
  }
  function(state) node_name
}
