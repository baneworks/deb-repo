#!/usr/bin/env bash
# @file bspec
# @brief Function to work with package specifications.

# @description Return name part from bspec.
#
# @example
#    $(bspecName <breq_spec>)
#
# @arg package spec
#
# @stdout package name
#
# @internal
bspecName() {
  local bname=(${1//'/'/ })
  echo "${bname[0]}"
}

# todo: compose with bspecVersionHR
# @description Return version part from bspec.
#
# @example
#    $(bspecVersion <breq_spec>)
#
# @arg package spec
#
# @stdout package version
#
# @internal
bspecVersion() {
  local bver=(${1//'/'/ })
  echo "${bver[1]}"
}

# @description Return version part from bspec in human readable format.
#
# @example
#    $(bspecVersionHR <breq_spec>)
#
# @arg package spec
#
# @stdout package version
#
# @internal
bspecVersionHR() {
  local bver=(${1//'/'/ })
  echo $(sed -n 's/\([<>=]\+\)/\1 /pg' <<< "${bver[1]}")
}

# @description Return package file name from bspec.
#
# @example
#    $(bspecFile <breq_spec> [arch])
#
# @arg package spec
# @arg arch of package, if ommited - `apt-cache show` will be called
#
# @stdout package version
#
# @internal
bspecFile() {
  local bname=(${1//'/'/ })
  local bver="${bname[1]}"
  bname="${bname[0]}"
  local arch="$2"
  if [[ -z "$arch" ]]; then #? fetch platform
    # avaible versions
    local str="$(dockerAptCache "$bname")"
    [[ $? -gt 0 ]] && return 1
    local vstr=$(sed -n 's/^Version: \(.*\)$/\1/1p' <<< "$str")
    local va
    for sl in ${vstr//"\n"/ }; do
      sl=$(tr -cd '[:print:]' <<< "$sl")
      va+=("$sl")
    done
    # which version is needed?
    local idx=$(breqWhichVersion "$bver" "${va[@]}")
    [[ $? -gt 0 ]] && echo "" && return 1 #! no suitable version
    # fetch platform
    local astr=$(sed -n 's/^Architecture: \(.*\)$/\1/1p' <<< "$str")
    local aa
    for al in ${astr//"\n"/ }; do
      al=$(tr -cd '[:print:]' <<< "$al")
      aa+=("$al")
    done
    [[ $? -gt 0 ]] && echo "" && return 1 #! mess in platforms and versions
    local arch=${aa[$idx]}
  fi
  bver=${bver//':'/'%3a'}
  echo "${bname}_${bver}_${arch}.deb"
}