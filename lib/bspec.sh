#!/usr/bin/env bash
# @file bspec
# @brief Function to work with package specifications.

# return name part from bspec: bspecName <breq_spec>
bspecName() {
  local bname=(${1//'/'/ })
  echo "${bname[0]}"
}

# return version part from bspec: bspecVersion <breq_spec>
bspecVersion() {
  local bver=(${1//'/'/ })
  echo "${bver[1]}"
}

# return version in readabe form: bspecVersionHR <breq_spec>
bspecVersionHR() {
  local bver=(${1//'/'/ })
  echo $(sed -n 's/\([<>=]\+\)/\1 /pg' <<< "${bver[1]}")
}

# return filename from bspec: bspecFile <breq_spec> [arch]
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