#!/usr/bin/env bash
# @file bkend
# @brief The switching backend (docker | local).

[[ -n "${SHDPKG_USEDOCKER}" && -n "${SHDPKG_LCRUN}" ]] && error 1 bkend "choose local or docker backend, not both"
[[ -n $SHDPKG_LCRUN ]] && BKEND_SUCMD="$LC_SUCMD"
[[ -n $SHDPKG_USEDOCKER ]] && BKEND_SUCMD="$DC_SUCMD"

source "$LIBS/docker.sh"
source "$LIBS/lcrun.sh"

# @description Function to create repo dir.
#
# @internal
bkendMkRepo() {
  [[ -n $SHDPKG_LCRUN ]] && lcrunMkRepo
  [[ -n $SHDPKG_USEDOCKER ]] && dockerMkRepo
}

# @description Function to create dir inside repo.
#
# @arg dir - dirname
#
# @internal
bkendMkDir() {
  [[ -n $SHDPKG_LCRUN ]] && lcrunMkDir "$@"
  [[ -n $SHDPKG_USEDOCKER ]] && dockerMkDir "$@"
}

# @description Function to create dir inside repo.
#
# @arg dir - dirname
#
# @internal
bkendRm() {
  [[ -n $SHDPKG_LCRUN ]] && lcrunRm "$@"
  [[ -n $SHDPKG_USEDOCKER ]] && dockerRm "$@"
}

# @description Function to write to file.
#
# @arg file - file relative to repo
# @arg msg - message
#
# @internal
bkendWrite() {
  [[ -n $SHDPKG_LCRUN ]] && lcrunWrite "$@"
  [[ -n $SHDPKG_USEDOCKER ]] && dockerWrite "$@"
}

# @description Function to ls.
#
# @arg dir - dir inside repo
# @arg pattern - pattern
#
# @internal
bkendLs() {
  local rv
  [[ -n $SHDPKG_LCRUN ]] && rv=$(lcrunLs $@)
  [[ -n $SHDPKG_USEDOCKER ]] && rv=$(dockerLs $@)
  echo "$rv"
}

# @description Function to cp.
#
# @arg dir - dir inside repo
# @arg pattern - pattern
#
# @internal
bkendCopy() {
  [[ -n $SHDPKG_LCRUN ]] && lcrunCopy "$@"
  [[ -n $SHDPKG_USEDOCKER ]] && dockerCopy "$@"
}

# @description Function to exec.
#
# @arg task - task name
# @arg tag - dir tag
# @arg cmd - command to execute
#
# @internal
bkendExec() {
  local rv rc=0
  if [[ -n $SHDPKG_LCRUN ]]; then
    rv=$(lcrunExec "$@")
    rc=$?
  elif [[ -n $SHDPKG_USEDOCKER ]]; then
    rv=$(dockerExec "$(tagValue $2)/$1" "$3")
    rc=$?
  fi
  echo "$rv"
  return $rc
}

# @description Function to excute the source stage.
#   Not using `bkendExec` (for pretty output reasons)
#
# @example
#    $(bkendAptSources <task>)"
#
# @arg `task` a build task
bkendAptSources() {
  [[ -n $SHDPKG_LCRUN ]] && lcrunAptSources "$@"
  [[ -n $SHDPKG_USEDOCKER ]] && dockerAptSources "$@"
}

# @description Function to excute the `apt-cache show`.
#
# @example
#    $(bkendAptCache <pkg>)"
#
# @arg `pkg` package to query
bkendAptCache() {
  local rv rc=0
  if [[ -n $SHDPKG_LCRUN ]]; then
    rv=$(lcrunAptCache "$@")
    rc=$?
  elif [[ -n $SHDPKG_USEDOCKER ]]; then
    rv=$(dockerAptCache "$@")
    rc=$?
  fi
  echo "$rv"
  return $rc
}