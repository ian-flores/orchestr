#' GraphBuilder R6 Class
#'
#' Fluent API for constructing agent workflow graphs.
#' Use the [graph_builder()] constructor function.
#'
#' @keywords internal
GraphBuilder <- R6::R6Class(

  "GraphBuilder",
  lock_class = TRUE,

  public = list(

    #' @description Create a new GraphBuilder
    #' @param state_schema Optional `StateSchema` for typed state with reducers.
    initialize = function(state_schema = NULL) {
      if (!is.null(state_schema) && !inherits(state_schema, "StateSchema")) {
        rlang::abort("`state_schema` must be a StateSchema object or NULL.", call = NULL)
      }
      private$schema <- state_schema
      private$nodes <- list()
      private$edges <- list()
      private$conditional_edges <- list()
      private$entry <- NULL
      private$interrupt_before <- character(0)
      private$interrupt_after <- character(0)
      private$cp <- NULL
    },

    #' @description Add a node to the graph
    #' @param name Character node name
    #' @param handler Function(state, config) or Agent object
    #' @return Self (for chaining)
    add_node = function(name, handler) {
      private$check_name(name)
      if (name == END) {
        rlang::abort("Cannot use reserved name '__end__' as a node name.", call = NULL)
      }
      if (name %in% names(private$nodes)) {
        rlang::abort(paste0("Node '", name, "' already exists."), call = NULL)
      }
      if (!is.function(handler) && !inherits(handler, "Agent")) {
        rlang::abort("`handler` must be a function or an Agent object.", call = NULL)
      }
      if (inherits(handler, "Agent")) {
        handler <- as_node(handler)
      }
      private$nodes[[name]] <- handler
      invisible(self)
    },

    #' @description Add a fixed edge between nodes
    #' @param from Source node name
    #' @param to Target node name (or `END`)
    #' @return Self (for chaining)
    add_edge = function(from, to) {
      private$check_name(from)
      if (!is.character(to) || length(to) != 1L) {
        rlang::abort("`to` must be a single character string.", call = NULL)
      }
      # Check for conflicting conditional edge
      cond_sources <- vapply(private$conditional_edges, `[[`, character(1), "from")
      if (from %in% cond_sources) {
        rlang::abort(
          paste0("Node '", from, "' already has a conditional edge; cannot add a fixed edge."),
          call = NULL
        )
      }
      private$edges <- c(private$edges, list(list(from = from, to = to)))
      invisible(self)
    },

    #' @description Add a conditional edge
    #' @param from Source node name
    #' @param condition Function(state) returning a character key
    #' @param mapping Named list mapping condition keys to node names
    #' @return Self (for chaining)
    add_conditional_edge = function(from, condition, mapping) {
      private$check_name(from)
      if (!is.function(condition)) {
        rlang::abort("`condition` must be a function.", call = NULL)
      }
      if (!is.list(mapping) || !rlang::is_named(mapping)) {
        rlang::abort("`mapping` must be a named list.", call = NULL)
      }
      # Check for conflicting fixed edge
      fixed_sources <- vapply(private$edges, `[[`, character(1), "from")
      if (from %in% fixed_sources) {
        rlang::abort(
          paste0("Node '", from, "' already has a fixed edge; cannot add a conditional edge."),
          call = NULL
        )
      }
      private$conditional_edges <- c(
        private$conditional_edges,
        list(list(from = from, condition = condition, mapping = mapping))
      )
      invisible(self)
    },

    #' @description Set the entry point node
    #' @param name Node name to start execution from
    #' @return Self (for chaining)
    set_entry_point = function(name) {
      private$check_name(name)
      private$entry <- name
      invisible(self)
    },

    #' @description Set interrupt gate nodes for human-in-the-loop
    #' @param before Character vector of node names to interrupt before
    #' @param after Character vector of node names to interrupt after
    #' @return Self (for chaining)
    set_interrupt = function(before = NULL, after = NULL) {
      if (!is.null(before)) {
        private$interrupt_before <- before
      }
      if (!is.null(after)) {
        private$interrupt_after <- after
      }
      invisible(self)
    },

    #' @description Attach a checkpointer for state persistence
    #' @param checkpointer A Checkpointer object
    #' @return Self (for chaining)
    set_checkpointer = function(checkpointer) {
      if (!inherits(checkpointer, "Checkpointer")) {
        rlang::abort("`checkpointer` must be a Checkpointer object.", call = NULL)
      }
      private$cp <- checkpointer
      invisible(self)
    },

    #' @description Compile the graph into a runnable AgentGraph
    #' @param max_iterations Integer safety cap on loop iterations
    #' @param verbose Logical; if `TRUE`, log node execution and routing via
    #'   [cli::cli_inform()].
    #' @return An `AgentGraph` object
    compile = function(max_iterations = 100L, verbose = FALSE) {
      # Validate entry point
      if (is.null(private$entry)) {
        rlang::abort("Entry point must be set before compiling.", call = NULL)
      }
      if (!private$entry %in% names(private$nodes)) {
        rlang::abort(paste0(
          "Entry point '", private$entry, "' is not a registered node."
        ), call = NULL)
      }

      # Validate edge targets
      all_node_names <- names(private$nodes)
      valid_targets <- c(all_node_names, END)

      for (e in private$edges) {
        if (!e$from %in% all_node_names) {
          rlang::abort(paste0("Edge source '", e$from, "' is not a registered node."), call = NULL)
        }
        if (!e$to %in% valid_targets) {
          rlang::abort(paste0("Edge target '", e$to, "' is not a registered node or END."), call = NULL)
        }
      }

      for (ce in private$conditional_edges) {
        if (!ce$from %in% all_node_names) {
          rlang::abort(paste0(
            "Conditional edge source '", ce$from, "' is not a registered node."
          ), call = NULL)
        }
        for (target in ce$mapping) {
          if (!target %in% valid_targets) {
            rlang::abort(paste0(
              "Conditional edge target '", target, "' is not a registered node or END."
            ), call = NULL)
          }
        }
      }

      # Validate dead-end nodes: every non-END node must have an outgoing edge
      fixed_sources <- vapply(private$edges, `[[`, character(1), "from")
      cond_sources <- vapply(
        private$conditional_edges, `[[`, character(1), "from"
      )
      has_outgoing <- union(fixed_sources, cond_sources)
      dead_ends <- setdiff(all_node_names, has_outgoing)
      if (length(dead_ends) > 0L) {
        rlang::abort(
          paste0(
            "Dead-end nodes with no outgoing edge: ",
            paste(dead_ends, collapse = ", "),
            ". Add an edge from each or route to END."
          ),
          call = NULL
        )
      }

      # Validate interrupt node names reference actual nodes
      bad_before <- setdiff(private$interrupt_before, all_node_names)
      if (length(bad_before) > 0L) {
        rlang::abort(
          paste0(
            "interrupt_before references unknown nodes: ",
            paste(bad_before, collapse = ", ")
          ),
          call = NULL
        )
      }
      bad_after <- setdiff(private$interrupt_after, all_node_names)
      if (length(bad_after) > 0L) {
        rlang::abort(
          paste0(
            "interrupt_after references unknown nodes: ",
            paste(bad_after, collapse = ", ")
          ),
          call = NULL
        )
      }

      # Build adjacency for reachability check
      adj <- private$build_adjacency()
      reachable <- private$find_reachable(private$entry, adj)
      unreachable <- setdiff(all_node_names, reachable)
      if (length(unreachable) > 0L) {
        rlang::warn(paste0(
          "Unreachable nodes: ", paste(unreachable, collapse = ", ")
        ))
      }

      AgentGraph$new(
        nodes = private$nodes,
        edges = private$edges,
        conditional_edges = private$conditional_edges,
        entry = private$entry,
        schema = private$schema,
        interrupt_before = private$interrupt_before,
        interrupt_after = private$interrupt_after,
        checkpointer = private$cp,
        max_iterations = as.integer(max_iterations),
        verbose = verbose
      )
    },

    #' @description Print the builder
    #' @param ... Ignored.
    print = function(...) {
      cli::cli_h3("GraphBuilder")
      cli::cli_ul()
      cli::cli_li("Nodes: {paste(names(private$nodes), collapse = ', ')}")
      cli::cli_li("Entry: {private$entry %||% '(not set)'}")
      cli::cli_li("Edges: {length(private$edges)} fixed, {length(private$conditional_edges)} conditional")
      cli::cli_end()
      invisible(self)
    }
  ),

  private = list(
    schema = NULL,
    nodes = NULL,
    edges = NULL,
    conditional_edges = NULL,
    entry = NULL,
    interrupt_before = NULL,
    interrupt_after = NULL,
    cp = NULL,

    check_name = function(name) {
      if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
        rlang::abort("Node name must be a non-empty single character string.", call = NULL)
      }
    },

    build_adjacency = function() {
      adj <- list()
      for (e in private$edges) {
        adj[[e$from]] <- c(adj[[e$from]], e$to)
      }
      for (ce in private$conditional_edges) {
        adj[[ce$from]] <- c(adj[[ce$from]], unlist(ce$mapping, use.names = FALSE))
      }
      adj
    },

    find_reachable = function(start, adj) {
      visited <- character(0)
      queue <- start
      while (length(queue) > 0L) {
        current <- queue[[1L]]
        queue <- queue[-1L]
        if (current %in% visited || current == END) next
        visited <- c(visited, current)
        neighbors <- adj[[current]] %||% character(0)
        queue <- c(queue, setdiff(neighbors, visited))
      }
      visited
    }
  )
)

#' Create a graph builder
#'
#' @param state_schema Optional `StateSchema` for typed state with reducers.
#' @return A `GraphBuilder` R6 object.
#' @family graph-building
#' @export
#' @examples
#' g <- graph_builder()
#' g$add_node("a", function(state, config) list(x = 1))
#' g$add_edge("a", END)
#' g$set_entry_point("a")
graph_builder <- function(state_schema = NULL) {
  GraphBuilder$new(state_schema = state_schema)
}
