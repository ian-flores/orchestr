#' StateSchema R6 Class
#'
#' Defines typed fields with optional reducers for graph state management.
#' Use the [state_schema()] constructor function.
#'
#' @keywords internal
StateSchema <- R6::R6Class(

  "StateSchema",

  public = list(

    #' @description Create a new StateSchema
    #' @param ... Named type specifications. Each value is a string like
    #'   `"append:list"`, `"any"`, `"logical"`, `"numeric"`, `"character"`,
    #'   `"list"`, `"data.frame"`, or `"integer"`.
    #'   The `"append:list"` form uses an append reducer for lists.
    initialize = function(...) {
      specs <- list(...)
      if (length(specs) == 0L) {
        rlang::abort("StateSchema requires at least one field specification.")
      }
      if (!rlang::is_named(specs)) {
        rlang::abort("All StateSchema fields must be named.")
      }
      parsed <- lapply(specs, private$parse_spec)
      private$fields <- parsed
    },

    #' @description Validate a set of updates against the schema

    #' @param updates Named list of values to validate
    #' @return Invisible TRUE if valid; aborts on error
    validate = function(updates) {
      if (!is.list(updates) || length(updates) == 0L) {
        return(invisible(TRUE))
      }
      unknown <- setdiff(names(updates), names(private$fields))
      if (length(unknown) > 0L) {
        rlang::abort(paste0(
          "Unknown state fields: ", paste(unknown, collapse = ", ")
        ))
      }
      for (nm in names(updates)) {
        spec <- private$fields[[nm]]
        if (spec$type != "any") {
          val <- updates[[nm]]
          if (!private$check_type(val, spec$type)) {
            rlang::abort(paste0(
              "Field '", nm, "' expects type '", spec$type,
              "', got '", class(val)[[1L]], "'."
            ))
          }
        }
      }
      invisible(TRUE)
    },

    #' @description Merge updates into current state using reducers
    #' @param current Named list representing current state
    #' @param updates Named list of updates
    #' @return Merged state as a named list
    merge = function(current, updates) {
      self$validate(updates)
      result <- current
      for (nm in names(updates)) {
        spec <- private$fields[[nm]]
        if (spec$reducer == "append") {
          existing <- result[[nm]] %||% list()
          result[[nm]] <- c(existing, updates[[nm]])
        } else {
          result[[nm]] <- updates[[nm]]
        }
      }
      result
    },

    #' @description Get field names defined in this schema
    #' @return Character vector of field names
    field_names = function() {
      names(private$fields)
    }
  ),

  private = list(
    fields = NULL,

    parse_spec = function(spec) {
      if (!is.character(spec) || length(spec) != 1L) {
        rlang::abort("Each field spec must be a single string.")
      }
      if (grepl("^append:", spec)) {
        type_part <- sub("^append:", "", spec)
        list(type = type_part, reducer = "append")
      } else {
        list(type = spec, reducer = "overwrite")
      }
    },

    check_type = function(val, type) {
      switch(type,
        logical   = is.logical(val),
        numeric   = is.numeric(val),
        character = is.character(val),
        integer   = is.integer(val),
        list      = is.list(val),
        "data.frame" = is.data.frame(val),
        any       = TRUE,
        # Default: use is()
        is(val, type)
      )
    }
  )
)

#' Create a typed state schema
#'
#' Defines fields and their types/reducers for graph state.
#' Field specs are strings: `"logical"`, `"numeric"`, `"character"`,
#' `"list"`, `"any"`, or `"append:list"` for append reducer.
#'
#' @param ... Named field specifications (e.g., `messages = "append:list"`,
#'   `done = "logical"`).
#' @return A `StateSchema` R6 object.
#' @export
#' @examples
#' schema <- state_schema(messages = "append:list", done = "logical")
#' schema$validate(list(done = TRUE))
#' schema$merge(list(messages = list("a")), list(messages = list("b")))
state_schema <- function(...) {
  StateSchema$new(...)
}


# ---- state_snapshot S3 class ----

#' Create a state snapshot
#'
#' Records the state at a particular node and step in graph execution.
#'
#' @param state Named list of current state
#' @param node Character string naming the node
#' @param step Integer step number
#' @return An object of class `"state_snapshot"`
#' @export
new_state_snapshot <- function(state, node, step) {
  if (!is.list(state)) {
    rlang::abort("`state` must be a list.")
  }
  if (!is.character(node) || length(node) != 1L) {
    rlang::abort("`node` must be a single character string.")
  }
  if (!is.numeric(step) || length(step) != 1L) {
    rlang::abort("`step` must be a single number.")
  }
  structure(
    list(state = state, node = node, step = as.integer(step)),
    class = "state_snapshot"
  )
}

#' @export
format.state_snapshot <- function(x, ...) {
  paste0(
    "<state_snapshot>\n",
    "  Node: ", x$node, "\n",
    "  Step: ", x$step, "\n",
    "  State keys: ", paste(names(x$state), collapse = ", "), "\n"
  )
}

#' @export
print.state_snapshot <- function(x, ...) {
  cat(format(x, ...), sep = "")
  invisible(x)
}


#' Merge state without a schema
#'
#' Shallow overwrite merge for schema-less state. Each key in `updates`
#' replaces the corresponding key in `current`.
#'
#' @param current Named list of current state
#' @param updates Named list of updates
#' @return Merged named list
#' @keywords internal
merge_state_plain <- function(current, updates) {
  result <- current
  for (nm in names(updates)) {
    result[[nm]] <- updates[[nm]]
  }
  result
}
