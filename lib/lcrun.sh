#!/usr/bin/env bash
# @file lcrun
# @brief The local run backend.

# region #? low level

# @description Function to create repo dir. Safe function
#
# @internal
lcrunMkRepo() {
  [ ! -d "$(tagValue log)/$task" ] && mkdir -p "$LC_REPO/$(tagValue log)"
}

# @description Function to create dir inside repo.
#
# @arg parent - parent dir relative to repo
# @arg dir - dirname
#
# @internal
lcrunMkDir() {
  local pd="$1"; shift
  for d in "$@"; do
    mkdir -p "$LC_REPO/$pd/$d"
  done
}

# @description Function to create dir inside repo. Unsafe.
#
# @arg parent - parent dir relative to repo
# @arg obj - dir or file to remove (relative to repo)
#
# @internal
lcrunRm() {
  local pd="$1"; shift
  for obj in "$@"; do
    [[ -d "$pd/$obj" ]] && rm -rf "$pd/$obj"
    [[ -f "$pd/$obj" ]] && rm -f "$pd/$obj"
  done
}

# @description Function to write to file.
#
# @arg file - file relative to repo
# @arg msg - mesage
#
# @internal
lcrunWrite() {
  echo "$2" >> "$LC_REPO/$1"
  echo ""
}

# @description Function to ls.
#
# @arg dir - dir inside repo
# @arg pattern - pattern
#
# @internal
lcrunLs() {
  echo `/usr/bin/env ls $LC_REPO/$1/$2`
}

# @description Function to copy file to guest FS.
#
# @example
#    $(lcrunCopy <tag> <task> <file>)
#
# @arg tag - place tag
# @arg task - a task name
# @arg file - a file name to copy
#
# @internal
lcrunCopy() {
  local retval tag="$1" task="$2"
  local file=(${3//'/'/ })
  file="${file[-1]}"
  retval=$(cp "$3" "$LC_REPO/$(tagValue $tag)/${task}/${file}")
  local errc=$?
  echo "$retval"
  return $errc
}

# @description Function exec command inside specified dir.
#
# @arg task - task name
# @arg tag - dir tag
# @arg cmd - command to execute
#
# @internal
lcrunExec() {
  local task="$1" wdir=$(tagValue $2) cwd=`pwd`
  cd "$LC_REPO/$wdir"
  local rv=$(sh -c "$3")
  local rc=$?
  cd "$cwd"
  echo "$rv"
  return "$rc"
}

# endregion

# region #? top level

# @description Function to excute the source stage.
#              Not using `lcrunExec` (for pretty output reasons)
#
# @example
#    $(lcrunAptSources <task>)"
#
# @arg `task` a build task
lcrunAptSources() {
  local task="$1" wdir=$(tagValue dsrc) cwd=`pwd`
  cd "$LC_REPO/$wdir"
  local rv=$(sh -c "apt-get source -q -d $task 1> /dev/null")
  local rc=$?
  cd "$cwd"
  echo "$rv"
  return "$rc"
}

# endregion
