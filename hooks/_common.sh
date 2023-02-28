#!/usr/bin/env bash

set -eo pipefail

#######################################################################
# Parse args and filenames passed to script and populate respective
# global variables with appropriate values
# Globals (init and populate):
#   ARGS (array) arguments for yq-raw mode
#   SORT_PATHS (array) K/V of with Path to file as Key and
#     golang regex for include-only specific yq path
#   ENV_VARS (array) environment variables will be available
#     for all 3rd-party tools executed by a hook.
#   FILES (array) filenames to check
# Arguments:
#   $@ (array) all specified in `hooks.[].args` in
#     `.pre-commit-config.yaml` and filenames.
#######################################################################
function common::parse_cmdline {
  # common global arrays.
  # Populated via `common::parse_cmdline` and can be used inside hooks' functions
  ARGS=() SORT_PATHS=() FILES=()
  # shellcheck disable=SC2034 # Used inside `common::export_provided_env_vars` function
  ENV_VARS=()

  local argv
  argv=$(getopt -o s:,r: --long yq-raw:,sort: -- "$@") || return
  eval "set -- $argv"

  for argv; do
    case $argv in
      -r | --yq-raw)
        shift
        # `argv` is an string from array with content like:
        #     ('provider aws' '--version "> 0.14"' '--ignore-path "some/path"')
        #   where each element is the value of each `--args` from hook config.
        # `echo` prints contents of `argv` as an expanded string
        # `xargs` passes expanded string to `printf`
        # `printf` which splits it into NUL-separated elements,
        # NUL-separated elements read by `read` using empty separator
        #     (`-d ''` or `-d $'\0'`)
        #     into an `ARGS` array

        # This allows to "rebuild" initial `args` array of sort of grouped elements
        # into a proper array, where each element is a standalone array slice
        # with quoted elements being treated as a standalone slice of array as well.
        while read -r -d '' ARG; do
          ARGS+=("$ARG")
        done < <(echo "$1" | xargs printf '%s\0')
        shift
        ;;
      -s | --sort)
        shift
        SORT_PATHS+=("$1")
        shift
        ;;
      --)
        shift
        # shellcheck disable=SC2034 # Variable is used
        FILES=("$@")
        break
        ;;
    esac
  done
}

#######################################################################
# Function which compares two semver versions.
# Based on https://stackoverflow.com/a/4025065 <- Function tests here
# Arguments:
#   ver1 (string) valid semver version
#   ver2 (string) valid semver version
# Returns:
#   101 if ver1 < ver2
#   102 if ver1 = ver2
#   103 if ver1 > ver2
function common::compare_versions {
  [[ "$1" == "$2" ]] && return 102

  local IFS=.
  read -r -a ver1 <<< "$1"
  read -r -a ver2 <<< "$2"
  local i

  # fill empty fields in ver1 with zeros
  for ((i = ${#ver1[@]}; i < ${#ver2[@]}; i++)); do
    ver1[i]=0
  done

  for ((i = 0; i < ${#ver1[@]}; i++)); do
    # fill empty fields in ver2 with zeros
    [[ -z ${ver2[i]} ]] && ver2[i]=0

    ((10#${ver1[i]} > 10#${ver2[i]})) && return 103

    ((10#${ver1[i]} < 10#${ver2[i]})) && return 101

  done

  return 1
}

#######################################################################
# Hook execution boilerplate logic which is common to hooks, that run
# on per file basis.
# 1. Run for each file `per_file_hook_unique_part`, on all paths
# 2.1. If at least 1 check failed - change exit code to non-zero
# 3. Complete hook execution and return exit code
# Arguments:
#   args_array_length (integer) Count of arguments in args array.
#   args (array) arguments that configure wrapped tool behavior
#   files (array) filenames to check
#######################################################################
function common::per_file_hook {
  local -i args_array_length=$1
  shift
  local -a args=()
  # Expand args to a true array.
  # Based on https://stackoverflow.com/a/10953834
  while ((args_array_length-- > 0)); do
    args+=("$1")
    shift
  done
  # assign rest of function's positional ARGS into `files` array,
  # despite there's only one positional ARG left
  local -a -r files=("$@")

  # preserve errexit status
  shopt -qo errexit && ERREXIT_IS_SET=true
  # allow hook to continue if exit_code is greater than 0
  set +e
  local final_exit_code=0

  # Mac uses, as always, have a very outdated patch by default which
  # miss some functionality
  local patch_version_outdated=true
  patch_version=$(patch --version | grep -o 'patch.*' | cut -d' ' -f2)
  common::compare_versions "$patch_version" "2.7.6"
  [ $? -ge 102 ] && patch_version_outdated=false

  # run hook for each path
  for filename in "${files[@]}"; do

    per_file_hook_unique_part "$filename" $patch_version_outdated "${args[@]}"

    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
      final_exit_code=$exit_code
    fi

  done

  # restore errexit if it was set before the "for" loop
  [[ $ERREXIT_IS_SET ]] && set -e
  # return the hook final exit_code
  exit $final_exit_code
}

#?
#?
#? Functions below copy-pasted from https://github.com/antonbabenko/pre-commit-terraform/blob/v1.77.1/hooks/_common.sh
#? If you need an update - go and check what new was added/fixed
#?
#?

#######################################################################
# Init arguments parser
# Arguments:
#   script_dir - absolute path to hook dir location
#######################################################################
function common::initialize {
  local -r script_dir=$1
  # source getopt function
  # shellcheck source=../lib_getopt
  . "$script_dir/../lib_getopt"
}

#######################################################################
# Expand environment variables definition into their values in '--args'.
# Support expansion only for ${ENV_VAR} vars, not $ENV_VAR.
# Globals (modify):
#   ARGS (array) arguments that configure wrapped tool behavior
#######################################################################
function common::parse_and_export_env_vars {
  local arg_idx

  for arg_idx in "${!ARGS[@]}"; do
    local arg="${ARGS[$arg_idx]}"

    # Repeat until all env vars will be expanded
    while true; do
      # Check if at least 1 env var exists in `$arg`
      # shellcheck disable=SC2016 # '${' should not be expanded
      if [[ "$arg" =~ .*'${'[A-Z_][A-Z0-9_]+?'}'.* ]]; then
        # Get `ENV_VAR` from `.*${ENV_VAR}.*`
        local env_var_name=${arg#*$\{}
        env_var_name=${env_var_name%%\}*}
        local env_var_value="${!env_var_name}"
        # shellcheck disable=SC2016 # '${' should not be expanded
        common::colorify "green" 'Found ${'"$env_var_name"'} in:        '"'$arg'"
        # Replace env var name with its value.
        # `$arg` will be checked in `if` conditional, `$ARGS` will be used in the next functions.
        # shellcheck disable=SC2016 # '${' should not be expanded
        arg=${arg/'${'$env_var_name'}'/$env_var_value}
        ARGS[$arg_idx]=$arg
        # shellcheck disable=SC2016 # '${' should not be expanded
        common::colorify "green" 'After ${'"$env_var_name"'} expansion: '"'$arg'\n"
        continue
      fi
      break
    done
  done
}

#######################################################################
# Colorize provided string and print it out to stdout
# Environment variables:
#   PRE_COMMIT_COLOR (string) If set to `never` - do not colorize output
# Arguments:
#   COLOR (string) Color name that will be used to colorize
#   TEXT (string)
# Outputs:
#   Print out provided text to stdout
#######################################################################
function common::colorify {
  # shellcheck disable=SC2034
  local -r red="\x1b[0m\x1b[31m"
  # shellcheck disable=SC2034
  local -r green="\x1b[0m\x1b[32m"
  # shellcheck disable=SC2034
  local -r yellow="\x1b[0m\x1b[33m"
  # Color reset
  local -r RESET="\x1b[0m"

  # Params start #
  local COLOR="${!1}"
  local -r TEXT=$2
  # Params end #

  if [ "$PRE_COMMIT_COLOR" = "never" ]; then
    COLOR=$RESET
  fi

  echo -e "${COLOR}${TEXT}${RESET}"
}

#######################################################################
# Export provided K/V as environment variables.
# Arguments:
#   env_vars (array)  environment variables will be available
#     for all 3rd-party tools executed by a hook.
#######################################################################
function common::export_provided_env_vars {
  local -a -r env_vars=("$@")

  local var
  local var_name
  local var_value

  for var in "${env_vars[@]}"; do
    var_name="${var%%=*}"
    var_value="${var#*=}"
    # shellcheck disable=SC2086
    export $var_name="$var_value"
  done
}
