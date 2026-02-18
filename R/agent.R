#' Agent R6 Class
#'
#' @description
#' An agent wraps an [ellmer::Chat] object with optional tool registration
#' and secure code execution via securer. Use [agent()] to create instances.
#'
#' @keywords internal
#' @export
Agent <- R6::R6Class(
  "Agent",
  public = list(
    #' @description Create a new Agent.
    #' @param name Character scalar. Agent identity.
    #' @param chat An [ellmer::Chat] object.
    #' @param tools List of tool definitions (ellmer tool objects or securer
    #'   tool objects).
    #' @param system_prompt Optional character scalar. Overrides the chat's
    #'   system prompt.
    #' @param secure Logical. If `TRUE`, wrap code execution in a securer
    #'   sandbox.
    #' @param sandbox Logical. If `TRUE` and `secure` is `TRUE`, enable OS
    #'   sandbox.
    #' @param memory Optional Memory object for cross-invocation state.
    initialize = function(name,
                          chat,
                          tools = list(),
                          system_prompt = NULL,
                          secure = FALSE,
                          sandbox = TRUE,
                          memory = NULL) {
      if (!is.character(name) || length(name) != 1L || is.na(name) ||
            !nzchar(name)) {
        abort("`name` must be a non-empty string.", call = NULL)
      }
      private$.name <- name
      private$.secure <- secure
      private$.sandbox <- sandbox
      private$.memory <- memory
      private$.chat <- chat

      if (!is.null(system_prompt)) {
        private$.chat$set_system_prompt(system_prompt)
      }

      private$register_tools(tools)
    },

    #' @description Invoke the agent with a prompt.
    #' @param prompt Character scalar. The prompt to send.
    #' @param state Named list. Additional state passed to the invocation.
    #' @return Character scalar: the agent's text response.
    invoke = function(prompt, state = list()) {
      extra <- state[!names(state) %in% c("messages", "")]
      if (length(extra) > 0L) {
        context_lines <- vapply(names(extra), function(nm) {
          paste0(nm, ": ", paste(as.character(extra[[nm]]), collapse = ", "))
        }, character(1))
        prompt <- paste0(
          "Context:\n", paste(context_lines, collapse = "\n"), "\n\n", prompt
        )
      }
      private$.chat$chat(prompt)
    },

    #' @description Invoke the agent and return the full Turn.
    #' @param prompt Character scalar. The prompt to send.
    #' @param state Named list. Additional state.
    #' @return An ellmer Turn object (the last assistant turn).
    invoke_turn = function(prompt, state = list()) {
      extra <- state[!names(state) %in% c("messages", "")]
      if (length(extra) > 0L) {
        context_lines <- vapply(names(extra), function(nm) {
          paste0(nm, ": ", paste(as.character(extra[[nm]]), collapse = ", "))
        }, character(1))
        prompt <- paste0(
          "Context:\n", paste(context_lines, collapse = "\n"), "\n\n", prompt
        )
      }
      private$.chat$chat(prompt)
      private$.chat$last_turn()
    },

    #' @description Get the underlying Chat object.
    #' @return The [ellmer::Chat] object.
    get_chat = function() {
      private$.chat
    },

    #' @description Get all conversation turns.
    #' @return A list of Turn objects.
    get_turns = function() {
      private$.chat$get_turns()
    },

    #' @description Reset conversation history, keeping tools registered.
    reset = function() {
      private$.chat$set_turns(list())
      invisible(self)
    },

    #' @description Fork this agent for parallel use.
    #' @return A new Agent with a deep-cloned Chat.
    fork = function() {
      cloned_chat <- private$.chat$clone(deep = TRUE)
      Agent$new(
        name = private$.name,
        chat = cloned_chat,
        tools = list(),
        system_prompt = NULL,
        secure = private$.secure,
        sandbox = private$.sandbox,
        memory = private$.memory
      )
    },

    #' @description Clean up resources.
    close = function() {
      if (!is.null(private$.secure_session)) {
        private$.secure_session$close()
        private$.secure_session <- NULL
      }
      invisible(self)
    },

    #' @description Print method.
    #' @param ... Ignored.
    print = function(...) {
      cli::cli_h3("Agent: {private$.name}")
      cli::cli_ul()
      cli::cli_li("Tools: {length(private$.tools)}")
      cli::cli_li("Secure: {private$.secure}")
      if (private$.secure) {
        cli::cli_li("Sandbox: {private$.sandbox}")
      }
      cli::cli_end()
      invisible(self)
    }
  ),

  private = list(
    .name = NULL,
    .chat = NULL,
    .tools = list(),
    .secure = FALSE,
    .sandbox = TRUE,
    .memory = NULL,
    .secure_session = NULL,

    register_tools = function(tools) {
      if (length(tools) == 0L) return(invisible(NULL))

      private$.tools <- tools

      if (private$.secure) {
        check_installed("securer", reason = "to use secure execution")

        private$.secure_session <- securer::SecureSession$new(
          sandbox = private$.sandbox
        )

        ellmer_tools <- list()
        for (tool in tools) {
          if (inherits(tool, "securer_tool")) {
            ellmer_tools <- c(
              ellmer_tools,
              list(securer::securer_as_ellmer_tool(
                tool,
                private$.secure_session
              ))
            )
          } else {
            ellmer_tools <- c(ellmer_tools, list(tool))
          }
        }
        private$.chat$set_tools(ellmer_tools)
      } else {
        for (tool in tools) {
          private$.chat$register_tool(tool)
        }
      }
    }
  )
)

#' Create an Agent
#'
#' Preferred constructor for creating Agent objects. Wraps the
#' \code{Agent} R6 class.
#'
#' @aliases Agent
#' @param name Character string identifying this agent.
#' @param chat An ellmer::Chat object.
#' @param tools List of tool objects.
#' @param system_prompt Optional system prompt override.
#' @param secure Logical; use securer sandbox.
#' @param sandbox Logical; enable OS sandbox when secure is TRUE.
#' @param memory Optional Memory object.
#' @return An \code{Agent} R6 object.
#' @export
agent <- function(name, chat, tools = list(), system_prompt = NULL,
                  secure = FALSE, sandbox = TRUE, memory = NULL) {
  Agent$new(name = name, chat = chat, tools = tools,
            system_prompt = system_prompt, secure = secure,
            sandbox = sandbox, memory = memory)
}
