#!/usr/bin/env bash

###############################################################################
# Strict Mode
###############################################################################

# Treat unset variables and parameters other than the special parameters ‘@’ or
# ‘*’ as an error when performing parameter expansion. An 'unbound variable'
# error message will be written to the standard error, and a non-interactive
# shell will exit.
#
# This requires using parameter expansion to test for unset variables.
#
# http://www.gnu.org/software/bash/manual/bashref.html#Shell-Parameter-Expansion
#
# The two approaches that are probably the most appropriate are:
#
# ${parameter:-word}
#   If parameter is unset or null, the expansion of word is substituted.
#   Otherwise, the value of parameter is substituted. In other words, "word"
#   acts as a default value when the value of "$parameter" is blank. If "word"
#   is not present, then the default is blank (essentially an empty string).
#
# ${parameter:?word}
#   If parameter is null or unset, the expansion of word (or a message to that
#   effect if word is not present) is written to the standard error and the
#   shell, if it is not interactive, exits. Otherwise, the value of parameter
#   is substituted.
#
# Examples
# ========
#
# Arrays:
#
#   ${some_array[@]:-}              # blank default value
#   ${some_array[*]:-}              # blank default value
#   ${some_array[0]:-}              # blank default value
#   ${some_array[0]:-default_value} # default value: the string 'default_value'
#
# Positional variables:
#
#   ${1:-alternative} # default value: the string 'alternative'
#   ${2:-}            # blank default value
#
# With an error message:
#
#   ${1:?'error message'}  # exit with 'error message' if variable is unbound
#
# Short form: set -u
set -o nounset

# Exit immediately if a pipeline returns non-zero.
#
# NOTE: This can cause unexpected behavior. When using `read -rd ''` with a
# heredoc, the exit status is non-zero, even though there isn't an error, and
# this setting then causes the script to exit. `read -rd ''` is synonymous with
# `read -d $'\0'`, which means `read` until it finds a `NUL` byte, but it
# reaches the end of the heredoc without finding one and exits with status `1`.
#
# Two ways to `read` with heredocs and `set -e`:
#
# 1. set +e / set -e again:
#
#     set +e
#     read -rd '' variable <<HEREDOC
#     HEREDOC
#     set -e
#
# 2. Use `<<HEREDOC || true:`
#
#     read -rd '' variable <<HEREDOC || true
#     HEREDOC
#
# More information:
#
# https://www.mail-archive.com/bug-bash@gnu.org/msg12170.html
#
# Short form: set -e
set -o errexit

# Allow the above trap be inherited by all functions in the script.
#
# Short form: set -E
set -o errtrace

# Return value of a pipeline is the value of the last (rightmost) command to
# exit with a non-zero status, or zero if all commands in the pipeline exit
# successfully.
set -o pipefail

# Set $IFS to only newline and tab.
#
# http://www.dwheeler.com/essays/filenames-in-shell.html
IFS=$'\n\t'

###############################################################################
# Environment
###############################################################################

# $_NAME
#
# This program's name.
_NAME="Wex"

# $_ME
#
# This program's basename.
_ME="$(basename "${0}")"

# $_VERSION
#
# This program's version.
_VERSION=0.1.0

###############################################################################
# Debug
###############################################################################

# _debug()
#
# Usage:
#   _debug <command> <options>...
#
# Description:
#   Execute a command and print to standard error. The command is expected to
#   print a message and should typically be either `echo`, `printf`, or `cat`.
#
# Example:
#   _debug printf "Debug info. Variable: %s\\n" "$0"
__DEBUG_COUNTER=0
_debug() {
	if ((${_USE_DEBUG:-0})); then
		__DEBUG_COUNTER=$((__DEBUG_COUNTER + 1))
		{
			# Prefix debug message with "bug (U+1F41B)"
			printf "🐛  %s " "${__DEBUG_COUNTER}"
			"${@}"
			printf "―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――\\n"
		} 1>&2
	fi
}

###############################################################################
# Error Messages
###############################################################################

# _exit_1()
#
# Usage:
#   _exit_1 <command>
#
# Description:
#   Exit with status 1 after executing the specified command with output
#   redirected to standard error. The command is expected to print a message
#   and should typically be either `echo`, `printf`, or `cat`.
_exit_1() {
	{
		printf "%s " "$(tput setaf 1)!$(tput sgr0)"
		"${@}"
	} 1>&2
	exit 1
}

# _warn()
#
# Usage:
#   _warn <command>
#
# Description:
#   Print the specified command with output redirected to standard error.
#   The command is expected to print a message and should typically be either
#   `echo`, `printf`, or `cat`.
_warn() {
	{
		printf "%s " "$(tput setaf 1)!$(tput sgr0)"
		"${@}"
	} 1>&2
}

###############################################################################
# Version
###############################################################################

# _print_version()
#
# Usage:
#   _print_version
#
# Description:
#   Print the program version.
_print_version() {
	echo "${_NAME}" v"${_VERSION}"
}

###############################################################################
# Help
###############################################################################

# _print_help()
#
# Usage:
#   _print_help
#
# Description:
#   Print the program help information.
_print_help() {
	echo "  __      __                "
	echo " /  \    /  \ ____ ___  ___ "
	echo " \   \/\/   // __ \\\  \/  /"
	echo "  \        /\  ___/ >    <  "
	echo "   \__/\  /  \___  >__/\_ \ "
	echo "        \/       \/      \/ "
	cat <<HEREDOC
Usage:
  ${_ME} [--options] [--arguments]
  ${_ME} -w .github/workflows/flowzone.yml -c tests/wex.json --verbose
  ${_ME} --version 

Options:
  -h --help      Display this help information.
  -D --debug     Log additional information to see what Wex is doing. 
  --verbose      Make Workflow runner log more information.

Arguments:
  -w --workflow  Workflow to use. 
  -c --config    Config file with experiments.
  --version      Print version. 
HEREDOC
}

###############################################################################
# Options
#
# NOTE: The `getops` builtin command only parses short options and BSD `getopt`
# does not support long arguments (GNU `getopt` does), so the most portable
# and clear way to parse options is often to just use a `while` loop.
#
# For a pure bash `getopt` function, try pure-getopt:
#   https://github.com/agriffis/pure-getopt
#
# More info:
#   http://wiki.bash-hackers.org/scripting/posparams
#   http://www.gnu.org/software/libc/manual/html_node/Argument-Syntax.html
#   http://stackoverflow.com/a/14203146
#   http://stackoverflow.com/a/7948533
#   https://stackoverflow.com/a/12026302
#   https://stackoverflow.com/a/402410
###############################################################################

# Parse Options ###############################################################

# Initialize program option variables.
_PRINT_HELP=1
_VERBOSE=0
_USE_DEBUG=0

# Initialize additional expected argument variables.
_OPTION_W=0
_OPTION_C=0
_PRINT_VERSION=0

# __get_option_value()
#
# Usage:
#   __get_option_value <option> <value>
#
# Description:
#  Given a flag (e.g., -e | --example) return the value or exit 1 if value
#  is blank or appears to be another option.
__get_option_value() {
	local __arg="${1:-}"
	local __val="${2:-}"

	if [[ -n "${__val:-}" ]] && [[ ! "${__val:-}" =~ ^- ]]; then
		printf "%s\\n" "${__val}"
	else
		_exit_1 printf "%s requires a valid argument.\\n" "${__arg}"
	fi
}

while ((${#})); do
	__arg="${1:-}"
	__val="${2:-}"

	case "${__arg}" in
	-h | --help)
		_PRINT_HELP=1
		;;
	--verbose)
		_VERBOSE=1
		;;
	--debug)
		_USE_DEBUG=1
		;;
	-w | --workflow)
		_OPTION_W="$(__get_option_value "${__arg}" "${__val:-}")"
		_PRINT_HELP=0
		;;
	-c | --config)
		_OPTION_C="$(__get_option_value "${__arg}" "${__val:-}")"
		_PRINT_HELP=0
		;;
	--version)
		_PRINT_VERSION=1
		_PRINT_HELP=0
		;;
	--endopts)
		# Terminate option parsing.
		break
		;;
	-*)
		_exit_1 printf "Unexpected option: %s\\n" "${__arg}"
		;;
	esac

	shift
done

###############################################################################
# Program Functions
###############################################################################

_wex() {
	_debug printf "Wex is starting..."
}

_mod_step_run() {
	_debug printf "Modifying steps run step"
}

_create_input() {
	_debug printf "Making input file..."
}

_run_act() {
	_debug printf "Running act..."
}

_cp_workflow() {
	_debug printf "Copying workflow..."
}

###############################################################################
# Main
###############################################################################

_main() {
	if ((_PRINT_HELP)); then
		_print_help
	elif ((_PRINT_VERSION)); then
		_print_version
	else
		# Make sure the require arguments are set
		if ((_OPTION_W)); then
			_exit_1 printf "Missing workflow argument. See --help."
		fi
		if ((_OPTION_C)); then
			_exit_1 printf "Missing config argument. See --help."
		fi
		# Run the show
		_wex "$@"
	fi
}

_main "$@"
