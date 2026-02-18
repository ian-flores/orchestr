#' AgentGraph R6 Class
#'
#' Compiled, immutable, runnable agent graph. Created by
#' [GraphBuilder]`$compile()`, not directly.
#'
#' @keywords internal
AgentGraph <- R6::R6Class(

  "AgentGraph",

  public = list(

    #' @description Create a compiled agent graph. Not intended for direct use;
    #'   create via `GraphBuilder$compile()`.
    #' @param nodes Named list of handler functions/Agents
    #' @param edges List of fixed edge specs
    #' @param conditional_edges List of conditional edge specs
    #' @param entry Character entry point node name
    #' @param schema Optional StateSchema
    #' @param interrupt_before Character vector of node names
    #' @param interrupt_after Character vector of node names
    #' @param checkpointer Optional Checkpointer
    #' @param max_iterations Integer safety cap
    initialize = function(nodes, edges, conditional_edges, entry, schema,
                          interrupt_before, interrupt_after, checkpointer,
                          max_iterations) {
      private$nodes <- nodes
      private$edges <- edges
      private$conditional_edges <- conditional_edges
      private$entry <- entry
      private$schema <- schema
      private$interrupt_before <- interrupt_before
      private$interrupt_after <- interrupt_after
      private$checkpointer <- checkpointer
      private$max_iterations <- max_iterations

      # Pre-compute edge lookup for fast resolution
      private$edge_map <- list()
      for (e in edges) {
        private$edge_map[[e$from]] <- e$to
      }
      private$cond_map <- list()
      for (ce in conditional_edges) {
        private$cond_map[[ce$from]] <- ce
      }
    },

    #' @description Run the graph to completion
    #' @param state Named list of initial state
    #' @param config Named list of configuration (e.g., thread_id, resume_from)
    #' @return Final state as a named list
    invoke = function(state = list(), config = list()) {
      # Try to resume from checkpoint
      current_node <- private$entry
      step <- 0L

      if (!is.null(private$checkpointer) && !is.null(config$thread_id)) {
        cp_data <- private$checkpointer$load(config$thread_id)
        if (!is.null(cp_data)) {
          state <- cp_data$state
          current_node <- cp_data$node
        }
      }

      # Resume from interrupt
      if (!is.null(config$resume_from)) {
        current_node <- config$resume_from$node
        state <- config$resume_from$state %||% state
      }

      while (step < private$max_iterations) {
        if (current_node == END) break

        # Interrupt before
        if (current_node %in% private$interrupt_before) {
          private$signal_interrupt(state, current_node, step)
        }

        # Run node handler
        state <- private$run_node(current_node, state, config)
        step <- step + 1L

        # Checkpoint after node execution
        if (!is.null(private$checkpointer) && !is.null(config$thread_id)) {
          private$checkpointer$save(config$thread_id, current_node, state)
        }

        # Interrupt after
        if (current_node %in% private$interrupt_after) {
          private$signal_interrupt(state, current_node, step)
        }

        # Resolve next node
        current_node <- private$resolve_next(current_node, state)
      }

      if (step >= private$max_iterations && current_node != END) {
        rlang::abort(paste0(
          "Graph exceeded max_iterations (", private$max_iterations, ")."
        ))
      }

      state
    },

    #' @description Run the graph and collect state snapshots
    #' @param state Named list of initial state
    #' @param config Named list of configuration
    #' @return List of `state_snapshot` objects
    stream = function(state = list(), config = list()) {
      current_node <- private$entry
      step <- 0L
      snapshots <- list()

      if (!is.null(config$resume_from)) {
        current_node <- config$resume_from$node
        state <- config$resume_from$state %||% state
      }

      while (step < private$max_iterations) {
        if (current_node == END) break

        state <- private$run_node(current_node, state, config)
        step <- step + 1L

        snapshots <- c(
          snapshots,
          list(new_state_snapshot(state, current_node, step))
        )

        current_node <- private$resolve_next(current_node, state)
      }

      if (step >= private$max_iterations && current_node != END) {
        rlang::abort(paste0(
          "Graph exceeded max_iterations (", private$max_iterations, ")."
        ))
      }

      snapshots
    },

    #' @description Generate a Mermaid diagram of the graph
    #' @return Character string with Mermaid markup
    as_mermaid = function() {
      lines <- "graph TD"
      # Nodes
      for (nm in names(private$nodes)) {
        lines <- c(lines, paste0("    ", nm, "[", nm, "]"))
      }
      lines <- c(lines, paste0("    ", END, "((END))"))
      # Entry arrow
      lines <- c(lines, paste0("    __start__([Start]) --> ", private$entry))
      # Fixed edges
      for (e in private$edges) {
        lines <- c(lines, paste0("    ", e$from, " --> ", e$to))
      }
      # Conditional edges
      for (ce in private$conditional_edges) {
        for (key in names(ce$mapping)) {
          target <- ce$mapping[[key]]
          lines <- c(lines, paste0(
            "    ", ce$from, " -->|", key, "| ", target
          ))
        }
      }
      paste(lines, collapse = "\n")
    },

    #' @description Get node names
    #' @return Character vector
    get_nodes = function() {
      names(private$nodes)
    },

    #' @description Get edge specifications
    #' @return List of edge specs (fixed and conditional)
    get_edges = function() {
      list(
        fixed = private$edges,
        conditional = private$conditional_edges
      )
    },

    #' @description Print method
    #' @param ... Ignored.
    print = function(...) {
      cat("<AgentGraph>\n")
      cat("  Nodes:", paste(names(private$nodes), collapse = ", "), "\n")
      cat("  Entry:", private$entry, "\n")
      cat("  Max iterations:", private$max_iterations, "\n")
      invisible(self)
    },

    #' @description Format method
    #' @param ... Ignored.
    format = function(...) {
      paste0(
        "<AgentGraph>\n",
        "  Nodes: ", paste(names(private$nodes), collapse = ", "), "\n",
        "  Entry: ", private$entry, "\n",
        "  Max iterations: ", private$max_iterations, "\n"
      )
    }
  ),

  private = list(
    nodes = NULL,
    edges = NULL,
    conditional_edges = NULL,
    entry = NULL,
    schema = NULL,
    interrupt_before = NULL,
    interrupt_after = NULL,
    checkpointer = NULL,
    max_iterations = NULL,
    edge_map = NULL,
    cond_map = NULL,

    run_node = function(node_name, state, config) {
      handler <- private$nodes[[node_name]]

      if (inherits(handler, "Agent")) {
        # Agent handler: extract last message, invoke, wrap response
        msgs <- state$messages
        last_msg <- if (length(msgs) > 0L) msgs[[length(msgs)]] else ""
        response <- handler$invoke(last_msg, state = state)
        updates <- list(messages = list(response))
      } else {
        updates <- handler(state, config)
      }

      if (!is.list(updates)) {
        rlang::abort(paste0(
          "Node '", node_name, "' handler must return a named list of state updates."
        ))
      }

      # Merge updates
      if (!is.null(private$schema)) {
        private$schema$merge(state, updates)
      } else {
        merge_state_plain(state, updates)
      }
    },

    resolve_next = function(node_name, state) {
      # Check conditional edges first
      ce <- private$cond_map[[node_name]]
      if (!is.null(ce)) {
        key <- ce$condition(state)
        if (!is.character(key) || length(key) != 1L) {
          rlang::abort(paste0(
            "Condition function for node '", node_name,
            "' must return a single character key."
          ))
        }
        target <- ce$mapping[[key]]
        if (is.null(target)) {
          rlang::abort(paste0(
            "Condition returned '", key,
            "' but no mapping exists for that key from node '", node_name, "'."
          ))
        }
        return(target)
      }

      # Check fixed edges
      target <- private$edge_map[[node_name]]
      if (!is.null(target)) {
        return(target)
      }

      rlang::abort(paste0(
        "No edge found from node '", node_name, "'. Dead end."
      ))
    },

    signal_interrupt = function(state, node_name, step) {
      rlang::signal(
        paste0("Interrupt at node '", node_name, "'"),
        class = "agentgraph_interrupt",
        state = state,
        node = node_name,
        step = step
      )
    }
  )
)
