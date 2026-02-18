#' Checkpointer R6 Class
#'
#' Persists graph execution state for workflow resumption.
#' Use the [checkpointer()] constructor function.
#'
#' @keywords internal
Checkpointer <- R6::R6Class(

  "Checkpointer",

  public = list(

    #' @description Create a new Checkpointer
    #' @param backend Either `"memory"` (in-process) or `"file"` (directory of
    #'   JSON files, one per thread).
    #' @param path Directory path for the `"file"` backend.
    initialize = function(backend = c("memory", "file"), path = NULL) {
      backend <- rlang::arg_match(backend)
      private$backend <- backend

      if (backend == "file") {
        if (is.null(path)) {
          rlang::abort("File backend requires a `path` argument.")
        }
        private$path <- path
        if (!dir.exists(path)) {
          dir.create(path, recursive = TRUE)
        }
      }

      private$store <- list()
    },

    #' @description Save a checkpoint for a thread
    #' @param thread_id Character string identifying the thread/conversation
    #' @param node_name Character string naming the current node
    #' @param state Named list of current state
    #' @return Invisible self
    save = function(thread_id, node_name, state) {
      private$check_thread_id(thread_id)
      if (!is.character(node_name) || length(node_name) != 1L) {
        rlang::abort("`node_name` must be a single character string.")
      }
      if (!is.list(state)) {
        rlang::abort("`state` must be a list.")
      }

      entry <- list(
        node = node_name,
        state = state,
        timestamp = Sys.time()
      )

      if (private$backend == "memory") {
        if (is.null(private$store[[thread_id]])) {
          private$store[[thread_id]] <- list()
        }
        private$store[[thread_id]] <- c(private$store[[thread_id]], list(entry))
      } else {
        # File backend: read existing, append, write back
        thread_file <- private$thread_path(thread_id)
        existing <- private$read_thread(thread_file)
        existing <- c(existing, list(entry))
        private$write_thread(thread_file, existing)
      }

      invisible(self)
    },

    #' @description Load the latest checkpoint for a thread
    #' @param thread_id Character string identifying the thread
    #' @return A list with `node` and `state`, or `NULL` if no checkpoints exist
    load = function(thread_id) {
      private$check_thread_id(thread_id)
      snapshots <- private$get_snapshots(thread_id)
      if (length(snapshots) == 0L) {
        return(NULL)
      }
      latest <- snapshots[[length(snapshots)]]
      list(node = latest$node, state = latest$state)
    },

    #' @description Get all checkpoints for a thread
    #' @param thread_id Character string identifying the thread
    #' @return A list of snapshots, each with `node`, `state`, and `timestamp`
    history = function(thread_id) {
      private$check_thread_id(thread_id)
      private$get_snapshots(thread_id)
    }
  ),

  private = list(
    backend = NULL,
    path = NULL,
    store = NULL,

    check_thread_id = function(thread_id) {
      if (!is.character(thread_id) || length(thread_id) != 1L ||
          nchar(thread_id) == 0L) {
        rlang::abort("`thread_id` must be a non-empty single character string.")
      }
    },

    get_snapshots = function(thread_id) {
      if (private$backend == "memory") {
        private$store[[thread_id]] %||% list()
      } else {
        thread_file <- private$thread_path(thread_id)
        private$read_thread(thread_file)
      }
    },

    thread_path = function(thread_id) {
      # Sanitize thread_id for use as filename
      safe_id <- gsub("[^a-zA-Z0-9_-]", "_", thread_id)
      file.path(private$path, paste0(safe_id, ".json"))
    },

    read_thread = function(path) {
      if (!file.exists(path)) {
        return(list())
      }
      jsonlite::read_json(path, simplifyVector = FALSE)
    },

    write_thread = function(path, snapshots) {
      jsonlite::write_json(
        snapshots,
        path,
        auto_unbox = TRUE,
        pretty = TRUE
      )
    }
  )
)

#' Create a workflow checkpointer
#'
#' Persists graph execution state so workflows can be resumed.
#'
#' @param backend Either `"memory"` (in-process) or `"file"` (directory of JSON
#'   files).
#' @param path Directory path for the file backend.
#' @return A `Checkpointer` R6 object.
#' @export
#' @examples
#' cp <- checkpointer()
#' cp$save("thread-1", "node_a", list(x = 1))
#' cp$load("thread-1")
checkpointer <- function(backend = c("memory", "file"), path = NULL) {
  Checkpointer$new(backend = backend, path = path)
}
