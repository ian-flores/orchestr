#' @keywords internal
"_PACKAGE"

#' @importFrom rlang abort warn inform check_installed is_installed is_named
#'   arg_match %||% signal cnd
#' @importFrom cli cli_h3 cli_ul cli_li cli_end
#' @importFrom R6 R6Class
#' @importFrom jsonlite toJSON fromJSON read_json write_json
#' @importFrom methods is
#' @importFrom stats setNames
NULL

#' End sentinel for graph execution
#'
#' Use `END` as a target node name to indicate that graph execution should
#' stop after the current node.
#'
#' @family graph-building
#' @export
END <- "__end__"
