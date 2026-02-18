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

# Helper to access MockChat private fields for assertions
mock_chat_tools <- function(chat) {
  chat$.__enclos_env__$private$.tools
}
