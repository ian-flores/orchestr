#' Convert an Agent to a graph node handler function
#'
#' @param agent An `Agent` object.
#' @param input_key State key containing the input prompt (default `"messages"`).
#' @param output_key State key for the response (default `"messages"`).
#' @return A function suitable for use as a graph node handler.
#' @family node-helpers
#' @export
#' @examples
#' \dontrun{
#' chat <- ellmer::chat_openai(model = "gpt-4o")
#' a <- agent("helper", chat)
#' handler <- as_node(a)
#' }
as_node <- function(agent, input_key = "messages", output_key = "messages") {
  if (!inherits(agent, "Agent")) {
    rlang::abort("`agent` must be an Agent object.", call = NULL)
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
#' @return A function suitable for use as a graph node handler.
#' @note These functions are for manual tool dispatch in custom node handlers.
#' When using \code{\link[=agent]{Agent}} objects with ellmer, tool calling is handled
#' internally by ellmer's Chat class. See \code{\link{react_graph}} for the
#' recommended pattern.
#' @family node-helpers
#' @export
#' @examples
#' \dontrun{
#' tools <- list(add = function(a, b) a + b)
#' handler <- tool_node(tools)
#' }
tool_node <- function(tools) {
  if (!is.list(tools) || !rlang::is_named(tools)) {
    rlang::abort("`tools` must be a named list of functions.", call = NULL)
  }
  function(state, config) {
    tool_results <- list()
    for (tc in state$pending_tool_calls %||% list()) {
      tool_fn <- tools[[tc$name]]
      if (is.null(tool_fn)) {
        rlang::warn(paste0("Unknown tool '", tc$name, "' in pending_tool_calls, skipping."))
        next
      }
      result <- do.call(tool_fn, tc$args)
      tool_results <- c(
        tool_results,
        list(list(tool_call_id = tc$id, result = result))
      )
    }
    list(tool_results = tool_results, pending_tool_calls = list())
  }
}

#' Route based on pending tool calls
#'
#' Returns `"tools"` if the state has pending tool calls, `"end"` otherwise.
#'
#' @param state Current graph state.
#' @return Character string: either a tool node name or \code{END}.
#' @note These functions are for manual tool dispatch in custom node handlers.
#' When using \code{\link[=agent]{Agent}} objects with ellmer, tool calling is handled
#' internally by ellmer's Chat class. See \code{\link{react_graph}} for the
#' recommended pattern.
#' @family node-helpers
#' @export
#' @examples
#' route_tool_calls(list(pending_tool_calls = list()))
#' route_tool_calls(list(pending_tool_calls = list(list(name = "add"))))
route_tool_calls <- function(state) {
  if (length(state$pending_tool_calls %||% list()) > 0L) "tools" else "end"
}

#' Create a constant router
#'
#' Returns a condition function that always routes to the given node name.
#'
#' @param node_name Character node name to route to.
#' @return A function that always returns the given node name.
#' @family node-helpers
#' @export
#' @examples
#' router <- route_to("next_node")
#' router(list())
route_to <- function(node_name) {
  if (!is.character(node_name) || length(node_name) != 1L) {
    rlang::abort("`node_name` must be a single character string.", call = NULL)
  }
  function(state) node_name
}
