#!/usr/bin/env bash
set -eo pipefail

# globals variables
# shellcheck disable=SC2155 # No way to assign to readonly variable in separate lines
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=_common.sh
. "$SCRIPT_DIR/_common.sh"

function main {
  check_is_deps_installed

  common::initialize "$SCRIPT_DIR"
  common::parse_cmdline "$@"
  common::export_provided_env_vars "${ENV_VARS[@]}"
  common::parse_and_export_env_vars

  get_configs "${SORT_PATHS[@]}"
  # shellcheck disable=SC2153 # False positive
  common::per_file_hook "${#ARGS[@]}" "${ARGS[@]}" "${FILES[@]}"
}

#######################################################################
# Check is `bash` >= 4. Check is `yq` is installed locally.
#  If not - check is `docker` installed, pull the `yq` image and use it
# as `yq` inside the hook.
# Outputs:
#   If bash < 4.0.0 - Mac users get info on how to install the newest bash
#   If no `yq` and `docker` - exit with the corresponding error
#######################################################################
function check_is_deps_installed {
  # Mac uses, as always, have a very outdated bash by default which
  # miss some functionality
  bash_version=$(bash --version | head -n 1 | grep -o 'version.*' | cut -d' ' -f2)
  set +e
  common::compare_versions "$bash_version" "4.0.0"
  local exit_code=$?
  set -e
  if [ "$exit_code" -lt 102 ]; then
    common::colorify "yellow" "That hook needs at least bash 4 to work. Please install it via the next command and reload shell:"
    common::colorify "yellow" "brew install bash"
    exit 1
  fi

  # Backport to docker
  if ! command -v yq &> /dev/null; then

    if ! command -v docker &> /dev/null; then
      echo "To run this hook, please, install 'yq' or 'docker'"
      exit 1
    fi

    # Prevent "Docker pull logs" added to fixed file.
    # https://github.com/SpotOnInc/pre-commit-yq/issues/9
    docker pull mikefarah/yq:4 > /dev/null

    function yq {
      docker run --rm -i -v "${PWD}":/workdir mikefarah/yq:4 "$@"
    }
  fi
}

#######################################################################
# Parse --sort passed to script and populate CONFIG
# global variable as K/V "FILE": "PATH to sort"
# Globals (init and populate):
#   SORT_REGEXPS (associative array) K/V of path in files that should be sorted
# Arguments:
#   sort_paths (array) arguments that configure hook behavior
#######################################################################
function get_configs {
  local -r sort_paths=("$@")
  declare -g -A SORT_REGEXPS

  for config in "${sort_paths[@]}"; do
    IFS='=' read -r filename path_to_sort <<< "$config"

    # $alphabetize receives string like 'file1=path1; file2=path2;' etc.
    # It gets split by `;` into array, which we're parsing here ('file1=path1' ' file2=path2')
    # Next line removes leading spaces.
    # shellcheck disable=SC2001 # Rule exception
    filename=$(echo "$filename" | sed 's/^[[:space:]]*//')

    SORT_REGEXPS["${filename}"]="$path_to_sort"
  done
}

#######################################################################
# Unique part of `common::per_file_hook`. The function is executed in loop
# on each provided dir path. Run wrapped tool with specified arguments
# Arguments:
#   filename (string) PATH to file relative to git repo root.
#     Can be used in error logging
#   patch_version_outdated (bool) If true - enable slower but working
#     for legacy systems (like MacOS) solution
#   args (array) arguments that configure wrapped tool behavior
# Outputs:
#   If failed - print out hook checks the status
#######################################################################
function per_file_hook_unique_part {
  local -r filename=$1
  local -r patch_version_outdated=$2
  shift 2
  local -a -r args=("$@")

  local exit_code no_blanks diff
  local PATHS_TO_SORT='.'
  # Run custom rule if specified

  if [ ${#args[@]} -gt 0 ]; then
    yq_output=$(yq "${args[@]}" "$filename" 2>&1)
    exit_code=$?
    error_type="in raw_yq mode"

  elif
    [ -z "${SORT_REGEXPS["${filename}"]}" ]
  then
    yq_output=$(yq e '( ... |select(type == "!!seq")) |= sort_by( select(tag == "!!str") //  (keys | .[0]) )' "$filename" 2>&1)
    exit_code=$?
    error_type="on whole file"
  else
    PATHS_TO_SORT="${SORT_REGEXPS["${filename}"]}"
    yq_output=$(yq e '(with_entries(select(.key | test ("'"$PATHS_TO_SORT"'"))) | ... |select(type == "!!seq")) |= sort_by( select(tag == "!!str") //  (keys | .[0]) )' "$filename" 2>&1)
    exit_code=$?
    error_type="with PATH '$PATHS_TO_SORT'"
  fi

  # yq completely remove blank lines from the output.
  # Next lines return blank lines back
  # https://github.com/mikefarah/yq/issues/515#issuecomment-1050637663
  if [ $exit_code -eq 0 ]; then
    # Get YAML file without blank lines
    no_blanks=$(yq "$PATHS_TO_SORT" "$filename")
    # Find are there any changes made by yq query
    no_blanks_diff=$(diff -B <(echo "$no_blanks") <(echo "$yq_output"))

    if [ -n "$no_blanks_diff" ]; then
      # `patch` need a physical file, so let's create it
      no_blanks_file="${filename}.no_blanks"
      echo "$no_blanks" > "$no_blanks_file"

      if [ "$patch_version_outdated" == true ]; then
        # Save patch that does not contain blank lines
        patch --forward -r - --no-backup-if-mismatch --quiet "$no_blanks_file" < <(echo "$no_blanks_diff")
        # Find where need to insert blank lines from original file
        diff=$(diff -B "${filename}" "$no_blanks_file")
      else
        # Save patch that does not contain blank lines to variable
        no_blanks_patch=$(patch --forward -o - -r - --no-backup-if-mismatch --quiet "$no_blanks_file" < <(echo "$no_blanks_diff"))
        # Find where need to insert blank lines from original file
        diff=$(diff -B "${filename}" <(echo "$no_blanks_patch"))
      fi

      # Patch original file
      patch_output=$(patch --forward -r - --no-backup-if-mismatch --quiet "${filename}" < <(echo "$diff") 2>&1)
      exit_code=$?
      # Remove temp file
      rm -f "$no_blanks_file"

      if [ $exit_code -ne 0 ]; then
        common::colorify "yellow" "Failed to patch file. Please, add the file to pre-commit hook exclude section.
File: '$filename'"
        echo -e "$patch_output\n\n"
      fi
    fi
  else
    common::colorify "yellow" "Hook failed $error_type. Check the file and hook settings to fix the error.
File: '$filename'"
    echo -e "$yq_output\n\n"
  fi

  # return exit code to common::per_dir_hook
  return $exit_code

}

[ "${BASH_SOURCE[0]}" != "$0" ] || main "$@"
