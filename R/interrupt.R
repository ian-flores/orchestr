#' Create an agent graph interrupt condition
#'
#' Creates a condition of class `agentgraph_interrupt` that can be signalled
#' to pause graph execution for human review.
#'
#' @param state The current graph state at the point of interruption.
#' @param node Character scalar. The node that triggered the interrupt.
#' @param step Integer. The execution step number.
#' @return A condition object of class `agentgraph_interrupt`.
#' @export
new_interrupt <- function(state, node, step) {
  cnd(
    "agentgraph_interrupt",
    message = sprintf("Interrupt at node '%s' (step %d)", node, step),
    state = state,
    node = node,
    step = step
  )
}

#' Create an approval tool for human-in-the-loop workflows
#'
#' Returns an [ellmer::tool()] definition that prompts a human for approval
#' via [readline()]. If approved, returns `"approved"`. If rejected, calls
#' [ellmer::tool_reject()] to signal rejection to the LLM.
#'
#' @param prompt_fn Optional function that receives the tool arguments and
#'   returns a character string to display as the approval prompt. Defaults
#'   to `"Approve this action? (yes/no): "`.
#' @return An ellmer tool definition.
#' @export
approval_tool <- function(prompt_fn = NULL) {
  prompt_fn <- prompt_fn %||% function(...) "Approve this action? (yes/no): "

  approve_fn <- function(action = "unspecified action") {
    prompt_text <- prompt_fn(action)
    response <- readline(prompt = prompt_text)
    if (tolower(trimws(response)) %in% c("yes", "y")) {
      "approved"
    } else {
      ellmer::tool_reject(paste0("Action rejected by user: ", action))
    }
  }

  ellmer::tool(
    approve_fn,
    "Ask the user for approval before proceeding with an action.",
    arguments = list(
      action = ellmer::type_string(
        "Description of the action to approve."
      )
    )
  )
}
