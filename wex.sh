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
			printf "[DEBUG] "
			"${@}"
			printf "\\n"
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
  ${_ME} -w workflow.yml -c wex.json --verbose
  ${_ME} --version 

Options:
  -h --help      Display this help information.
  -D --debug     Log additional information to see what Wex is doing. 
  --version      Print version. 
  --verbose      Make Workflow runner log more information.
  --logs         Print Workflow logs (Same logs you'd see on Github).

Arguments:
  -w --workflow  Workflow to use. 
  -c --config    Config file with experiments.
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
_OPT_PRINT_HELP=1
_OPT_VERBOSE=0
_OPT_LOG_WORKFLOW=0
_OPT_USE_DEBUG=0
_OPT_PRINT_VERSION=0

# Initialize additional expected argument variables.
_ARG_WORKFLOW=
_ARG_CONFIG=

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
		_OPT_PRINT_HELP=1
		;;
	--version)
		_OPT_PRINT_VERSION=1
		_OPT_PRINT_HELP=0
		;;
	--verbose)
		_OPT_VERBOSE=1
		;;
	--debug)
		_OPT_USE_DEBUG=1
		;;
	--logs)
		_OPT_LOG_WORKFLOW=1
		;;
	-w | --workflow)
		_ARG_WORKFLOW="$(__get_option_value "${__arg}" "${__val:-}")"
		_OPT_PRINT_HELP=0
		;;
	-c | --config)
		_ARG_CONFIG="$(__get_option_value "${__arg}" "${__val:-}")"
		_OPT_PRINT_HELP=0
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
	_debug printf "Wex trying \`${_ARG_WORKFLOW}\` with config \`${_ARG_CONFIG}\`"
	fails=0
	tmp_directory=$(_cp_workflow)
	total=$(yq -c '.experiments | length' "$_ARG_CONFIG")
	_debug printf "Found $total experiments to test"
	# Loop over each experiment in config
	while read -r experiment; do
		# Get the webhook event
		event=$(echo "$experiment" | yq -c 'with_entries(select(.key != "it")) | keys[]' | tr -d '\"')
		# (1) create inputs file
		tmp_inputs=
		inputs=$(echo "$experiment" | yq -c ".$event.inputs")
		if ! [ "$inputs" = "null" ]; then
			_debug printf "Creating inputs file from config inputs"
			# TODO: make tmp directory global since all  functions will push there
			tmp_inputs=$(_create_input "$tmp_directory" "$inputs")
		fi

		# (2) modify workflow so that steps do not run
		# TODO: add support for reusable workflows
		# TODO: support no output specified in config
		_mod_step_run "${tmp_directory}/${_ARG_WORKFLOW}" "$(echo "$experiment" | yq -c ".$event.outputs")"

		# (3) call act
		logs=$(_run_act "$event" "$tmp_directory" "$tmp_inputs")

		# TODO: this should print as act outputs instead of waiting for the process to complete
		if ((_OPT_LOG_WORKFLOW)); then
			echo "$logs"
		fi

		# (4) test logs for expected text
		title=$(echo "$experiment" | yq -c '.it')
		# TODO: create a helper function for passing variable to yq
		failed_test=0
		include_tests=$(echo "$experiment" | yq -c ".$event.test.includes")
		exclude_tests=$(echo "$experiment" | yq -c ".$event.test.excludes")

		# TODO: make this more DRY
		if [[ "$include_tests" != "null" ]]; then
			while read -r tests; do
				if ! _test_experiment "$logs" "$tests" true; then
					# TODO: make this return an integer
					failed_test=1
				fi
			done < <(echo "$include_tests")
		fi

		# TODO: make this more DRY
		if [[ "$exclude_tests" != "null" ]]; then
			while read -r tests; do
				if ! _test_experiment "$logs" "$tests" false; then
					failed_test=1
				fi
			done < <(echo "$exclude_tests")
		fi

		if ((failed_test)); then
			echo "$title - ⚠ FAILED"
			_debug printf "Failed experiment, incrementing fails!"
			((fails = fails + 1))
		else
			echo "$title - ✔ PASSED"
		fi
	done < <(yq -c '.experiments[]' "$_ARG_CONFIG")

	# Cleanup tmp workflow
	rm -r "$tmp_directory"

	# Check results!
	if ! ((fails)); then
		echo "== $total/$total EXPERIMENTS PASSED =="
		exit 0
	else
		_exit_1 echo " - $fails/$total EXPERIMENTS FAILED!"
	fi
}

_test_experiment() {
	pass=true
	while read -r test; do
		# TODO: make this more DRY
		if "$3"; then
			if ! echo "$1" | grep -q "$(echo "⭐ Run Main $test" | tr -d '\"')"; then
				# Fail if a single test does not pass
				pass=false
			fi
		else
			if echo "$1" | grep -q "$(echo "⭐ Run Main $test" | tr -d '\"')"; then
				# Fail if a single test does not pass
				pass=false
			fi
		fi
	done < <(echo "$2")

	# check that all tests pass
	if "$pass"; then
		return 0
	else
		return 1
	fi
}

_mod_step_run() {
	_debug printf "Modifying steps in $1"

	echo "$2" | yq -c "keys[]" | while read -r step; do
		target_step_id=$(echo "$step" | tr -d '"')
		override=""
		# build string of echos to set output in step.run
		while read -r output_key; do
			key=$(echo "$output_key" | tr -d '"')
			value=$(echo "$2" | yq -c ".${step}.${output_key}")
			override="${override}\n$(_set_output "$key" "$value")"
		done < <(echo "$2" | yq -c ".${step} | keys[]")
		# delete 'uses' on step if set
		yq -iy "del(.jobs[].steps[] | select(.id == \"${target_step_id}\") | .uses)" "$1"
		# set existing or add new 'run' to just echo outputs
		yq -iy "(.jobs[].steps[] | select(.id == \"${target_step_id}\") | .run) = \"${override}\"" "$1"
	done
}

_set_output() {
	key="$1"
	value=$(echo "$2" | tr -d '"') # escape quotes around strings
	printf "echo ::set-output name=%s::%s" "$key" "$value"
}

_create_input() {
	echo "{ \"inputs\": {} }" | yq -j "(.inputs) = $2" >"$1/inputs.json"
	echo "$1/inputs.json"
}

_run_act() {
	# TODO: pass secrets from .env file as `-s KEY=VALUE` args to act
	args="$1 -W $2"
	if ((_OPT_VERBOSE)); then
		_debug printf "Adding verbose flag to act"
		args=" -v $args"
	fi
	if [[ -n "$3" ]]; then
		args=" -e $3 $args"
	fi
	_debug printf "Starting act with args \'$args\'"
	eval act "$args"
}

_cp_workflow() {
	# Make a tmp directory to store modified workflow
	workflow_directory=$(mktemp -d)
	# Copy provided workflow to tmp directory
	_debug printf "Making a copy of %s in %s" "$_ARG_WORKFLOW" "$workflow_directory"
	# shellcheck disable=2154
	cp "$_ARG_WORKFLOW" "$workflow_directory"
	echo "$workflow_directory"
}

###############################################################################
# Main
###############################################################################

_main() {
	if ((_OPT_PRINT_HELP)); then
		_print_help
	elif ((_OPT_PRINT_VERSION)); then
		_print_version
	else
		# Make sure the required arguments are set and valid
		if [ -z "$_ARG_WORKFLOW" ]; then
			_exit_1 printf "Missing workflow argument. See --help."
		elif [ ! -f "$_ARG_WORKFLOW" ]; then
			_exit_1 printf "Workflow file '${_ARG_WORKFLOW}' does not exists."
		fi
		if [ -z "$_ARG_CONFIG" ]; then
			_exit_1 printf "Missing config argument. See --help."
		elif [ ! -f "$_ARG_CONFIG" ]; then
			_exit_1 printf "Config file '${_ARG_CONFIG}' does not exists."
		fi
		# Run the show
		_wex "$@"
	fi
}

_main "$@"
