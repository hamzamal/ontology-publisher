#!/usr/bin/env bash
#
# _functions.sh defines a list of generic functions that can be used by any of the
# other scripts in this directory (or its subdirectories).
#

export GREP=grep

#
# Generic function that returns 1 if the variable with the given name does not exist (as a local or global Bash variable or
# as an environment variable)
#
function variableExists() {

  local variableName="$1"

#  if (set -u; : $variableName) 2> /dev/null ; then
#    return 1
#  fi
#  return 0

  export 2>&1 | ${GREP} -q "declare -x ${variableName}=" && return 0
  declare 2>&1 | ${GREP} -q "^${variableName}=" && return 0

  return 1
}

#
# Generic function that can be used to test for the existence of a given variable
#
function require() {

  local variableName="$1"

  variableExists ${variableName} && return 0

  set -- $(caller 0)

  errorNoSource "The $(sourceLine $@) requires ${variableName}"

  return 1
}

#
# Generic function that can be used to test for the existence of a given variable and whether it has a value other
# than an empty string.
#
function requireValue() {

  local variableName="$1"

  if ! variableExists ${variableName} ; then

    set -- $(caller 0)
    error "The $(sourceLine $@) requires ${variableName}"
    return 1
  fi

  local variableValue="${!variableName}"

  [ -n "${variableValue}" ] && return 0

  set -- $(caller 0)

  errorNoSource "The $(sourceLine $@) requires a value in variable ${variableName}"

  exit 1
}

#
# Generic function that can be used to test for the existence of a given variable and whether it has a value other
# than an empty string.
#
function requireParameter() {

  local variableName="$1"

  if ! variableExists ${variableName} ; then

    set -- $(caller 1)

    case $2 in
      assert*) # see test-framework.sh
        set -- $(caller 2)
        errorNoSource "The $(sourceLine $@) requires ${variableName}"
        ;;
      *)
        errorNoSource "The $(sourceLine $@) requires ${variableName}"
        ;;
    esac
    errorNoSource "The $(sourceLine $@) requires ${variableName}"
    return 1
  fi

  local variableValue="${!variableName}"

  [ -n "${variableValue}" ] && return 0

  set -- $(caller 1)
  case $2 in
    assert*) # see test-framework.sh
      set -- $(caller 2)
      errorNoSource "The $(sourceLine $@) requires a value for parameter ${variableName}"
      ;;
    *)
      errorNoSource "The $(sourceLine $@) requires a value for parameter ${variableName}"
      ;;
  esac
  exit 1
}

function isMacOSX() {

  test "$(uname -s)" == "Darwin"
}

#
# Create a temporary file with a given file extension.
#
function mktempWithExtension() {

  local -r name="$1"
  local -r extension="$2"

  local tempName

  (
    if isMacOSX ; then
      tempName="$(mktemp -t "${name}")" || return $?
      local -r newName="${tempName}.${extension}"

      mv -f "${tempName}" "${tempName}.${extension}" || return $?

      echo -n "${newName}"
      return 0
    fi

    tempName="$(mktemp --quiet --suffix=".${extension}" -t "${name}.XXXXXX")" || return $?

    echo -n "${tempName}"
  )
  if [ $? -ne 0 ] ; then
    error "Could not create temporary file ${name}.XXXX.${extension}"
    return 1
  fi

  return 0
}

function printfLog() {

  printf -- "$*" >&2
}

function log() {

  blue "$@" >&2
}

function logRule() {

  echo $(printf '=%.0s' {1..40}) $(bold "$@") >&2
}

function logItem() {

  local -r item="$1"
  shift

  printf -- ' - %-25s : [%s]\n' "${item}" "$(bold "$@")"
}

function logVar() {

  logItem "$1" "${!1}"
}

#
# Log each line of the input stream.
#
function pipelog() {

  while IFS= read -r line; do
    log "${line}"
  done

  return 0
}

function warning() {

  local line="$@"

  printf "WARNING: \e[31m${line}\e[0m\n" >&2
}

function verbose() {

  ((verbose)) && log "$@"
}

function debug() {

  ((debug)) || return 0

  local args="$@"

  local n=0
  local prefix=""
  while caller $((n++)) >/dev/null 2>&1; do prefix="${prefix}-" ; done;
  prefix="${prefix:2}"

  lightGrey "DEBUG:                    -${prefix}$@" >&2
}

function sourceLine() {

  local -r lineNumber="$1"
  local -r functionName="$2"
  local -r sourceFile="$(sourceFile $3)"
  local -r baseSourceName="$(basename "${sourceFile}")"

  printf "function %s() at .(%s:%d)" "${functionName}" "${baseSourceName}" "${lineNumber}"
}

function error() {

  if ((builder_no_error_prefix)) ; then
    log "$*"
    return 1
  fi

  if ((builder_running_inside_container)) ; then
    echo "$(date "+%Y-%m-%d %H:%M:%S.%3N") ERROR: $@" >&2
  else
    local line="$*"
    # shellcheck disable=SC2046
    set -- $(caller 0)
    if ! printf "ERROR: in $(sourceLine "$@"): \e[31m${line}\e[0m\n" >&2 ; then
      echo "ERROR: Could not show error: $* ${line}" >&2
    fi
  fi

  return 1
}

function errorNoSource() {

  if ((builder_no_error_prefix)) ; then
    log "$*"
    return 1
  fi

  if ((builder_running_inside_container)) ; then
    error "$@"
  else
    local line="$*"
    set -- $(caller 0)
    printf "ERROR: \e[31m${line}\e[0m\n" >&2
  fi

  return 1
}

function errorInCaller() {

  if ((builder_no_error_prefix)) ; then
    log "$*"
    return 1
  fi

  if ((builder_running_inside_container)) ; then
    echo "$(date "+%Y-%m-%d %H:%M:%S.%3N") ERROR: $@" >&2
  else
    local line="$*"
    line="${line//[0m;/[0;31m}"
    set -- $(caller 1)
    printf "ERROR: in $(sourceLine $@): \e[31m${line}\e[0m\n" >&2
  fi

  return 1
}

function errorInCallerOfCaller() {

  if ((builder_no_error_prefix)) ; then
    log "$*"
    return 1
  fi

  if ((builder_running_inside_container)) ; then
    echo "$(date "+%Y-%m-%d %H:%M:%S.%3N") ERROR: $@" >&2
  else
    local line="$*"
    set -- $(caller 2)
    printf "ERROR: in $(sourceLine $@): \e[31m${line}\e[0m\n" >&2
  fi

  return 1
}

function printfError() {

  if ((builder_no_error_prefix)) ; then
    printfLog "$*"
    return 1
  fi

  if ((builder_running_inside_container)) ; then
    local -r timestamp="$(date "+%Y-%m-%d %H:%M:%S.%3N")"
    local -r formatString="%s ERROR: $1"
    shift
    printf -- "${formatString}" "$@" >&2
  else
    local formatString="ERROR: %s: \e[31m%s\e[0m $1"
    shift
    local line="$*"
    # shellcheck disable=SC2046
    set -- $(caller 0)
    printf -- "${formatString}" "$(sourceLine "$@")" ${line} >&2
  fi

  return 1
}

#
# Red is for error messages
#
function red() {

  printf "\e[31m%b\e[0m\n" "$*"
}

#
# Blue is for technical but important messages
#
function blue() {

  printf "\e[34m%b\e[0m\n" "$*"
}

#
# Bold is for emphasis
#
function bold() {

  printf "\e[1m$*\e[0m\n"
}

#
# Lightgrey is for debug/trace type of logging that is usually to be ignored
#
function lightGrey() {

  printf "\e[37m$*\e[0m\n"
}

#
# Log the given file with jq (pretty plus coloring) and if it's not valid JSON say so and dump file on the log
#
function logjson() {

  local file="$1"

  if [ ! -f "${file}" ] ; then
    warning "${file} does not exist"
    return 0
  fi

  if isJsonFile "${file}" ; then
    ${JQ} . "${file}" >&2 # pipelog strips ANSI colors
    return 0
  fi

  log "${file} is not valid JSON:"
  cat "${file}" | pipelog
  log "-----"

  return 1
}

#
# Return true (0) if the given file is a JSON file.
#
function isJsonFile() {

  local file="$1"

  [ -f "${file}" ] || return 1

  ${JQ} . "$1" >/dev/null 2>&1
}

function sourceFile() {

  local sourceFile="$1"
  #
  # Strip the Jenkins workspace directory from the source file name if it's in there
  #
  sourceFile="${sourceFile/${WORKSPACE}/.}"
  #
  # Strip the current directory from the source file name if it's in there
  #
  sourceFile="${sourceFile/$(pwd)/.}"

  printf "${sourceFile}"
}

function logFileName() {

  local -r name1="${1/${WORKSPACE}/.}"
  local -r name2="${name1/${OUTPUT}/<output>}"
  local -r name3="${name2/${INPUT}/<input>}"

  echo -n "${name3}"
}

#
# mktemp does not replace the XXX with a random number if it's not at the end of the string,
# so add the .ttl extension after the tmp files have been created.
#
function createTempFile() {

  local prefix="$1"
  local extension="$2"
  local tmpfile=$(mktemp ${TMPDIR}/${prefix}.XXXXXX)

  mv "${tmpfile}" "${tmpfile}.${extension}"

  printf "${tmpfile}.${extension}"
}

#
# Only call once at the top of the root process
#
function initRootProcess() {

  #
  # TMPDIR
  #
  if [ -z "${TMPDIR}" ] ; then
    error "Missing TMPDIR"
    return 1
  fi
  rm -rf "${TMPDIR:?}/*" >/dev/null 2>&1
}

#
# Initialize (the locations of) the tools that are supposed to be installed at the OS level
#
function initOSBasedTools() {

  local bashMajorVersion="${BASH_VERSINFO:-0}"

  if ((bashMajorVersion != 4)) ; then
    error "We need to run this with Bash 4, not version: ${BASH_VERSINFO:?}"
    if [ "$(uname -s)" == "Darwin" ] ; then
      log "Run 'brew install bash' to get this installed"
      return 1
    fi
  fi
  #
  # The command below is only available in Bash 4
  #
  shopt -s globstar

  #export | sort

  if [ -z "${WORKSPACE}" ] ; then
    export is_running_in_jenkins=1 # = false
    WORKSPACE="${SCRIPT_DIR}/test-workspace"
    mkdir -p "${WORKSPACE}" >/dev/null 2>&1
  else
    export is_running_in_jenkins=0 # = true
  fi
  mkdir -p "${WORKSPACE}/bin" "${WORKSPACE}/target" >/dev/null 2>&1

  #
  # TAR
  #
  export TAR=tar

  #
  # GREP
  #
  export GREP=grep
  export GREP_OPTIONS=

  #
  # FIND
  #
  export FIND=find

  #
  # SED
  #
  export SED=sed

  #
  # CP
  #
  export CP=cp

  #
  # TREE
  #
  export TREE=tree

  #
  # JQ
  #
  # JQ is used to read/edit JSON files.
  #
  # Install on linux with "yum install jq".
  # Install on Mac OS X with "brew install jq".
  #
  export JQ=jq

  if which jq >/dev/null 2>&1 ; then
    export JQ=$(which jq)
  else
    error "jq not found"
    return 1
  fi

  #
  # Python 3
  #
  export PYTHON3=python3

  if which python3 >/dev/null 2>&1 ; then
    export PYTHON3=$(which python3)
  elif which python3.6 >/dev/null 2>&1 ; then
    export PYTHON3=$(which python3.6)
  else
    error "python3 not found"
    return 1
  fi

  return 0
}

#
# Initialize the (locations of) the tools that are installed via the fibo-infra repo
#
function initRepoBasedTools() {

  #
  # We should install Jena on the Jenkins server and not have it in the git-repo, takes up too much space for each
  # release of Jena
  #
  if [ ! -d /usr/share/java/jena/latest ] ; then
    error "Could not find Jena"
    return 1
  fi
  JENAROOT="$(cd /usr/share/java/jena/latest && pwd -L)" ; export JENAROOT
  logVar JENAROOT

  export JENA_BIN="${JENAROOT}/bin"
  export JENA_ARQ="${JENA_BIN}/arq"
  export JENA_RIOT="${JENA_BIN}/riot"

  JENA3_JARS="."

  while read jar ; do
    JENA3_JARS+=":${jar}"
  done < <(find "${JENAROOT}/lib/" -name '*.jar')

  export JENA3_JARS

  if [ ! -f "${JENA_ARQ}" ] ; then
    error "${JENA_ARQ} not found"
    return 1
  fi

  return 0
}

function initWorkspaceVars() {

  require INPUT || return $?
  require OUTPUT || return $?
  require family || return $?

  #
  # source_family_root: the root directory of the ${family} repo
  #
  export source_family_root="${INPUT:?}/${family:?}"
  #
  # Add your own directory locations above if you will
  #
  if [ ! -d "${source_family_root}" ] ; then
    error "source_family_root directory not found (${source_family_root})"
    return 1
  fi
  ((verbose)) && logVar source_family_root

  export spec_root="${OUTPUT:?}"
  export spec_family_root="${spec_root}/${family:?}"
  export product_root=""
  export branch_root=""
  export tag_root=""
  export product_branch_tag=""
  #
  # Ontology root is required for other products like widoco
  #
  export ontology_product_tag_root=""
  #
  # TODO: Make URL configurable
  #
  export spec_root_url="https://spec.edmcouncil.org"
  export spec_family_root_url="${spec_root_url}/${family}"
  export product_root_url=""
  export branch_root_url=""
  export tag_root_url=""

  return 0
}

#
# Since we have to deal with multiple products (ontology, vocabulary etc) we need to be able to switch back
# and forth, call this function whenever you generate something for another product. The git branch and tag name
# always remain the same though.
#
export ontology_publisher_current_product="${ontology_publisher_current_product}"
#
function setProduct() {

  export ontology_publisher_current_product="$1"

  require GIT_BRANCH || return $?
  require GIT_TAG_NAME || return $?
  require spec_family_root || return $?

  ((verbose)) && logItem "spec_family_root" "${spec_family_root/${WORKSPACE}/}"

  export product_root="${spec_family_root}/${ontology_publisher_current_product}"
  export product_root_url="${spec_family_root_url}/${ontology_publisher_current_product}"

  if [ ! -d "${product_root}" ] ; then
    mkdir -p "${product_root}" || return $?
  fi

  ((verbose)) && logItem "product_root" "${product_root/${WORKSPACE}/}"

  export branch_root="${product_root}/${GIT_BRANCH}"
  export branch_root_url="${product_root_url}/${GIT_BRANCH}"

  if [ ! -d "${branch_root}" ] ; then
    mkdir -p "${branch_root}" || return $?
  fi

  ((verbose)) && logItem "branch_root" "${branch_root/${WORKSPACE}/}"

  export tag_root="${branch_root}/${GIT_TAG_NAME}"
  export tag_root_url="${branch_root_url}/${GIT_TAG_NAME}"

  if [ ! -d "${tag_root}" ] ; then
    mkdir -p "${tag_root}" || return $?
  fi

  ((verbose)) && logItem "tag_root" "${tag_root/${WORKSPACE}/}"

  export product_branch_tag="${ontology_publisher_current_product}/${GIT_BRANCH}/${GIT_TAG_NAME}"
  export family_product_branch_tag="${family}/${product_branch_tag}"

  return 0
}

function initGitVars() {

  if [ -z "${GIT_COMMIT}" ] ; then
    export GIT_COMMIT="$(cd ${source_family_root} && git rev-parse --short HEAD)"
    ((verbose)) && logVar GIT_COMMIT
  fi

  if [ -z "${GIT_COMMENT}" ] ; then
    export GIT_COMMENT=$(cd ${source_family_root} && git log --format=%B -n 1 ${GIT_COMMIT} | ${GREP} -v "^$")
    ((verbose)) && logVar GIT_COMMENT
  fi

  if [ -z "${GIT_AUTHOR}" ] ; then
    export GIT_AUTHOR=$(cd ${source_family_root} && git show -s --pretty=%an)
    ((verbose)) && logVar GIT_AUTHOR
  fi

  #
  # Get the git branch name to be used as directory names and URL fragments and make it
  # all lower case
  #
  # Note that we always do the subsequent replacements on the GIT_BRANCH value since Jenkins
  # might have specified the value for GIT_BRANCH which might need to be corrected.
  #
  if [ -z "${GIT_BRANCH}" ] ; then
    GIT_BRANCH=$(cd ${source_family_root} && git rev-parse --abbrev-ref HEAD | tr '[:upper:]' '[:lower:]') ; export GIT_BRANCH
  fi
  #
  # Replace all slashes in a branch name with dashes so that we don't mess up the URLs for the ontologies
  #
  export GIT_BRANCH="${GIT_BRANCH//\//-}"
  #
  # Strip the "heads-tags-" prefix from the Branch name if its in there.
  #
  if [[ "${GIT_BRANCH}" =~ ^heads-tags-(.*)$ ]] ; then
    GIT_BRANCH="${BASH_REMATCH[0]}" ; export GIT_BRANCH
  fi
  ((verbose)) && logVar GIT_BRANCH

  #
  # If the current commit has a tag associated to it then the Git Tag Message Plugin in Jenkins will
  # initialize the GIT_TAG_NAME variable with that tag. Otherwise set it to "latest"
  #
  # See https://wiki.jenkins-ci.org/display/JENKINS/Git+Tag+Message+Plugin
  #
  if [ "${GIT_TAG_NAME}" == "latest" ] ; then
    unset GIT_TAG_NAME
  fi
  if [ -z "${GIT_TAG_NAME}" ] ; then
    GIT_TAG_NAME="$(cd ${source_family_root} ; echo $(git describe --contains --exact-match 2>/dev/null))"
    GIT_TAG_NAME="${GIT_TAG_NAME%^*}" # Strip the suffix
  fi
  export GIT_TAG_NAME="${GIT_TAG_NAME:-${GIT_BRANCH}_latest}"
  #
  # If the tag name includes an underscore then assume it's ok, leave it alone since the next step is to then
  # treat the part before the underscore as the branch name (see below).
  # If the tag name does NOT include an underscore then put the branch name in front of it (separated with an
  # underscore) so that the further processing down below will not fail.
  #
  if [[ ${GIT_TAG_NAME} =~ ^.+_.+$ ]] ; then
    :
  else
    export GIT_TAG_NAME="${GIT_BRANCH}_${GIT_TAG_NAME}"
    log "Added branch as prefix to the tag: GIT_TAG_NAME=${GIT_TAG_NAME}"
  fi
  ((verbose)) && logVar GIT_TAG_NAME
  #
  # So, if this tag has an underscore in it, it is assumed to be a tag that we should treat as a version, which
  # should be reflected in the URLs of all published artifacts.
  # The first part is supposed to be the branch name onto which the tag was set. The second part is the actual
  # version string, which is supposed to be in the following format:
  #
  # <year>Q<quarter>[S<sequence>]
  #
  # Such as 2017Q1 or 2018Q2S2 (sequence 0 is assumed to be the first delivery that quarter, where we leave out "Q0")
  #
  # Any other version string is accepted too but should not be made on the master branch.
  #
  if [[ "${GIT_TAG_NAME}" =~ ^(.*)_(.*)$ ]] ; then
    tagBranchSection="${BASH_REMATCH[1]}"
    tagVersionSection="${BASH_REMATCH[2]}"

    if [ -n "${tagBranchSection}" ] ; then
      tagBranchSection=$(echo ${tagBranchSection} | tr '[:upper:]' '[:lower:]')
      log "Found branch name in git tag: ${tagBranchSection}"
      export GIT_BRANCH="${tagBranchSection}"
    fi
    if [ -n "${tagVersionSection}" ] ; then
      log "Found version string in git tag: ${tagVersionSection}"
      export GIT_TAG_NAME="${tagVersionSection}"
    fi
  fi

  saveEnvironmentVariable GIT_BRANCH || return $?
  saveEnvironmentVariable GIT_TAG_NAME || return $?
  saveEnvironmentVariable GIT_AUTHOR || return $?
  saveEnvironmentVariable GIT_COMMIT || return $?
  saveEnvironmentVariable GIT_COMMENT || return $?

  #
  # Set default product
  #
  setProduct ontology

  return 0
}

function saveEnvironmentVariable() {

  require OUTPUT || return $?

  local variable="$1"
  local value="${!variable}"

  logVar "${variable}"

  mkdir -p "${OUTPUT}/env" >/dev/null 2>&1
  echo -n "${value}" > "${OUTPUT}/env/${variable}"
}

function initJiraVars() {

  JIRA_ISSUE="$(echo ${GIT_COMMENT} | rev | ${GREP} -oP '\d+-[A-Z0-9]+(?!-?[a-zA-Z]{1,10})' | rev | sort -u)" ; export JIRA_ISSUE

  logVar JIRA_ISSUE

  saveEnvironmentVariable JIRA_ISSUE || return $?

  return 0
}