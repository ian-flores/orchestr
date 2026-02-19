# MockChat -- simulates ellmer::Chat for testing
# Provides canned responses without requiring API keys.

MockChat <- R6::R6Class(
  "MockChat",
  public = list(
    initialize = function(responses = list("Hello from mock agent"),
                          system_prompt = NULL) {
      private$.responses <- responses
      private$.response_idx <- 0L
      private$.turns <- list()
      private$.tools <- list()
      private$.system_prompt <- system_prompt
    },

    chat = function(prompt) {
      private$.response_idx <- private$.response_idx + 1L
      idx <- ((private$.response_idx - 1L) %% length(private$.responses)) + 1L
      response <- private$.responses[[idx]]

      # Record the user turn
      user_turn <- list(role = "user", content = prompt)
      private$.turns <- c(private$.turns, list(user_turn))

      # Record the assistant turn
      assistant_turn <- list(role = "assistant", content = response)
      class(assistant_turn) <- "Turn"
      private$.turns <- c(private$.turns, list(assistant_turn))
      private$.last_turn <- assistant_turn

      response
    },

    last_turn = function() {
      private$.last_turn
    },

    get_turns = function() {
      private$.turns
    },

    register_tool = function(tool_def) {
      private$.tools <- c(private$.tools, list(tool_def))
      invisible(self)
    },

    set_tools = function(tools) {
      private$.tools <- tools
      invisible(self)
    },

    set_turns = function(value) {
      private$.turns <- value
      invisible(self)
    },

    set_system_prompt = function(prompt) {
      private$.system_prompt <- prompt
      invisible(self)
    },

    get_system_prompt = function() {
      private$.system_prompt
    }
  ),

  private = list(
    .responses = list(),
    .response_idx = 0L,
    .turns = list(),
    .tools = list(),
    .system_prompt = NULL,
    .last_turn = NULL,

    deep_clone = function(name, value) {
      # Deep copy lists so cloned chat is independent
      if (name %in% c(".responses", ".turns", ".tools")) {
        return(lapply(value, identity))
      }
      value
    }
  ),

  cloneable = TRUE
)

# MockToolChat -- extends MockChat to simulate tool invocations.
# Each response can optionally trigger registered tools with given arguments.
#
# Usage:
#   chat <- MockToolChat$new(
#     responses = list("routing to coder"),
#     tool_calls = list(
#       list(list(tool_idx = 1L, args = list(worker = "coder")))
#     )
#   )
#
# tool_calls is a list aligned with responses. Each entry is a list of
# calls to fire: list(tool_idx = <position in registered tools>, args = list(...)).
# When $chat() is called, the matching tool_calls entry fires each tool
# by invoking the registered ellmer::ToolDef (which is callable) with the
# given args. This lets tests verify supervisor routing patterns where
# tool side-effects drive graph state.

MockToolChat <- R6::R6Class(
  "MockToolChat",
  inherit = MockChat,
  public = list(
    initialize = function(responses = list("Hello from mock agent"),
                          tool_calls = list(),
                          system_prompt = NULL) {
      super$initialize(responses = responses, system_prompt = system_prompt)
      private$.tool_calls <- tool_calls
    },

    chat = function(prompt) {
      # Determine which tool_calls entry to use (same cycling as responses)
      idx <- ((private$.response_idx) %% length(private$.responses)) + 1L

      # Fire tool side-effects before recording turns
      if (idx <= length(private$.tool_calls)) {
        calls <- private$.tool_calls[[idx]]
        for (tc in calls) {
          tool_def <- private$.tools[[tc$tool_idx]]
          if (!is.null(tool_def) && is.function(tool_def)) {
            do.call(tool_def, tc$args)
          }
        }
      }

      # Delegate to parent for turn recording and response
      super$chat(prompt)
    }
  ),

  private = list(
    .tool_calls = list(),

    deep_clone = function(name, value) {
      if (name == ".tool_calls") return(lapply(value, identity))
      super$deep_clone(name, value)
    }
  )
)

# Helper to access MockChat private fields for assertions
mock_chat_tools <- function(chat) {
  chat$.__enclos_env__$private$.tools
}
