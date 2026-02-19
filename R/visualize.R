#' Render an agent graph as a Mermaid diagram
#'
#' Generates a [Mermaid](https://mermaid.js.org/) flowchart string from an
#' `AgentGraph` object. Useful for documentation and debugging.
#'
#' @param graph An `AgentGraph` object with `$get_nodes()` and `$get_edges()`
#'   methods.
#' @return A character string containing a Mermaid diagram definition.
#' @export
#' @examples
#' g <- graph_builder()
#' g$add_node("a", function(state, config) list())
#' g$add_edge("a", "__end__")
#' g$set_entry_point("a")
#' graph <- g$compile()
#' cat(as_mermaid(graph))
as_mermaid <- function(graph) {
  nodes <- graph$get_nodes()
  raw_edges <- graph$get_edges()

  lines <- "graph TD"

  # Render node declarations
  for (node in nodes) {
    label <- render_node(node)
    lines <- c(lines, paste0("    ", label))
  }

  # Normalize edge list: AgentGraph returns list(fixed=, conditional=),
  # but a plain list of edge specs is also accepted.
  if (!is.null(raw_edges$fixed) || !is.null(raw_edges$conditional)) {
    fixed_edges <- raw_edges$fixed %||% list()
    cond_edges <- raw_edges$conditional %||% list()
    all_edges <- c(fixed_edges, cond_edges)
  } else {
    all_edges <- raw_edges
  }

  # Render edges
  for (edge in all_edges) {
    from_id <- sanitize_id(edge$from)

    if (!is.null(edge$condition)) {
      # Conditional edge: one line per mapping entry
      for (i in seq_along(edge$mapping)) {
        label <- names(edge$mapping)[[i]]
        target <- edge$mapping[[i]]
        to_id <- sanitize_id(target)
        lines <- c(lines, sprintf("    %s -->|%s| %s", from_id, sanitize_label(label), to_id))
      }
    } else {
      # Fixed edge
      to_id <- sanitize_id(edge$to)
      lines <- c(lines, sprintf("    %s --> %s", from_id, to_id))
    }
  }

  paste(lines, collapse = "\n")
}

# -- internal helpers ----------------------------------------------------------

render_node <- function(node) {
  if (identical(node, END)) {
    return("END((END))")
  }
  id <- sanitize_id(node)
  sprintf("%s[\"%s\"]", id, sanitize_label(node))
}

sanitize_id <- function(node) {
  if (identical(node, END)) {
    return("END")
  }
  gsub("[^A-Za-z0-9_]", "_", node)
}

sanitize_label <- function(label) {
  # Escape characters that have special meaning in Mermaid
  label <- gsub('"', "&quot;", label, fixed = TRUE)
  label <- gsub("<", "&lt;", label, fixed = TRUE)
  label <- gsub(">", "&gt;", label, fixed = TRUE)
  label <- gsub("[", "&#91;", label, fixed = TRUE)
  label <- gsub("]", "&#93;", label, fixed = TRUE)
  label <- gsub("{", "&#123;", label, fixed = TRUE)
  label <- gsub("}", "&#125;", label, fixed = TRUE)
  label <- gsub("|", "&#124;", label, fixed = TRUE)
  label
}
