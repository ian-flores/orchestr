#' Checkpointer R6 Class
#'
#' Persists graph execution state for workflow resumption.
#' Use the [checkpointer()] constructor function.
#'
#' @note The file backend uses append-only JSONL (JSON Lines) files. It is not
#'   safe for concurrent multi-process access to the same thread. Use the memory
#'   backend for concurrent use within a single R process.
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
          rlang::abort("File backend requires a `path` argument.", call = NULL)
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
        rlang::abort("`node_name` must be a single character string.", call = NULL)
      }
      if (!is.list(state)) {
        rlang::abort("`state` must be a list.", call = NULL)
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
        # File backend: append one JSON line (JSONL format)
        thread_file <- private$thread_path(thread_id)
        line <- jsonlite::toJSON(entry, auto_unbox = TRUE)
        cat(line, "\n", file = thread_file, sep = "", append = TRUE)
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
        rlang::abort("`thread_id` must be a non-empty single character string.", call = NULL)
      }
      if (nchar(thread_id) > 200L) {
        rlang::abort("`thread_id` must be 200 characters or fewer.", call = NULL)
      }
    },

    get_snapshots = function(thread_id) {
      if (private$backend == "memory") {
        private$store[[thread_id]] %||% list()
      } else {
        private$read_thread(thread_id)
      }
    },

    thread_path = function(thread_id) {
      # Sanitize thread_id for use as filename
      safe_id <- gsub("[^a-zA-Z0-9_-]", "_", thread_id)
      file.path(private$path, paste0(safe_id, ".jsonl"))
    },

    # Backward-compat path for old .json files
    legacy_thread_path = function(thread_id) {
      safe_id <- gsub("[^a-zA-Z0-9_-]", "_", thread_id)
      file.path(private$path, paste0(safe_id, ".json"))
    },

    read_thread = function(thread_id) {
      jsonl_path <- private$thread_path(thread_id)
      json_path <- private$legacy_thread_path(thread_id)

      if (file.exists(jsonl_path)) {
        private$read_jsonl(jsonl_path)
      } else if (file.exists(json_path)) {
        # Backward compat: read old JSON array format
        jsonlite::read_json(json_path, simplifyVector = FALSE)
      } else {
        list()
      }
    },

    read_jsonl = function(path) {
      lines <- readLines(path, warn = FALSE)
      lines <- lines[nzchar(trimws(lines))]
      lapply(lines, function(l) {
        jsonlite::fromJSON(l, simplifyVector = FALSE)
      })
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
#' @return A \code{Checkpointer} R6 object.
#' @family persistence
#' @export
#' @examples
#' cp <- checkpointer()
#' cp$save("thread-1", "node_a", list(x = 1))
#' cp$load("thread-1")
checkpointer <- function(backend = c("memory", "file"), path = NULL) {
  Checkpointer$new(backend = backend, path = path)
}
