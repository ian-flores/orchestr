#' Memory R6 Class
#'
#' Key-value store with local (in-process) and file (JSON) backends.
#' Use the [memory()] constructor function.
#'
#' @note The file backend is not concurrency-safe. If multiple R processes
#'   access the same file, data loss may occur. Use the local backend for
#'   concurrent access within a single process, or implement external file
#'   locking.
#' @keywords internal
Memory <- R6::R6Class(

  "Memory",
  lock_class = TRUE,

  public = list(

    #' @description Create a new Memory store
    #' @param backend Either `"local"` (in-process list) or `"file"` (JSON).
    #' @param path File path for the `"file"` backend.
    initialize = function(backend = c("local", "file"), path = NULL) {
      backend <- rlang::arg_match(backend)
      private$backend <- backend

      if (backend == "file") {
        if (is.null(path)) {
          rlang::abort("File backend requires a `path` argument.", call = NULL)
        }
        private$path <- path
        if (file.exists(path)) {
          raw <- jsonlite::read_json(path, simplifyVector = FALSE)
          private$check_schema_version(raw)
          raw[["_schema_version"]] <- NULL
          private$store <- raw
        } else {
          private$store <- list()
          private$persist()
        }
      } else {
        private$store <- list()
      }
    },

    #' @description Set a key-value pair
    #' @param key Character key
    #' @param value Any R object (must be JSON-serializable for file backend)
    set = function(key, value) {
      private$check_key(key)
      private$store[[key]] <- value
      private$persist()
      invisible(self)
    },

    #' @description Get a value by key
    #' @param key Character key
    #' @param default Value to return if key is missing (default: NULL)
    #' @return The stored value, or `default` if not found
    get = function(key, default = NULL) {
      private$check_key(key)
      if (self$has(key)) {
        private$store[[key]]
      } else {
        default
      }
    },

    #' @description Check if a key exists
    #' @param key Character key
    #' @return Logical
    has = function(key) {
      private$check_key(key)
      key %in% names(private$store)
    },

    #' @description Delete a key
    #' @param key Character key
    #' @return Invisible self
    delete = function(key) {
      private$check_key(key)
      private$store[[key]] <- NULL
      private$persist()
      invisible(self)
    },

    #' @description List all keys
    #' @return Character vector of keys (possibly empty)
    keys = function() {
      names(private$store) %||% character(0L)
    },

    #' @description Return the entire store as a list
    #' @return Named list
    as_list = function() {
      private$store
    },

    #' @description Remove all keys
    #' @return Invisible self
    clear = function() {
      private$store <- list()
      private$persist()
      invisible(self)
    }
  ),

  private = list(
    backend = NULL,
    path = NULL,
    store = NULL,

    check_key = function(key) {
      if (!is.character(key) || length(key) != 1L || nchar(key) == 0L) {
        rlang::abort("`key` must be a non-empty single character string.", call = NULL)
      }
    },

    persist = function() {
      if (private$backend == "file") {
        out <- private$store
        out[["_schema_version"]] <- 1L
        jsonlite::write_json(
          out,
          private$path,
          auto_unbox = TRUE,
          pretty = TRUE
        )
      }
    },

    check_schema_version = function(data) {
      version <- data[["_schema_version"]]
      if (is.null(version)) {
        rlang::warn(
          "Reading memory data without a schema version (old format).",
          .frequency = "once",
          .frequency_id = "orchestr_memory_no_version"
        )
      } else if (version > 1L) {
        rlang::warn(paste0(
          "Memory schema version ", version,
          " is newer than supported version 1. ",
          "Data may not be read correctly."
        ))
      }
    }
  )
)

#' Create a key-value memory store
#'
#' @param backend Either `"local"` (in-process list) or `"file"` (JSON file).
#' @param path File path for the file backend.
#' @note The \code{path} parameter for file backends should be a trusted value.
#'   Do not derive it from LLM output or untrusted user input.
#' @return A \code{Memory} R6 object.
#' @family persistence
#' @export
#' @examples
#' mem <- memory()
#' mem$set("foo", 42)
#' mem$get("foo")
memory <- function(backend = c("local", "file"), path = NULL) {
  Memory$new(backend = backend, path = path)
}
