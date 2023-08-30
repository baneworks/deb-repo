#!/usr/bin/env bash
# @file docker
# @brief The docker backend.

# region #? low level

# @description get container pid.
# @internal
function dockePid() {
  local pid=$(docker inspect -f '{{.State.Pid}}' $DC_NAME)
  if [[ $pid -le 1 ]]; then
   error 1 docker "no debian container running"
   return 1
  fi
  echo "$pid"
}

# @description init module.
# @internal
dockerInit() {
  GUEST_PID=$(dockePid)
  [[ $GUEST_PID -le 1 ]] && (echo ""; return 1)
  echo "$GUEST_PID"
}

# @description Function exec docker command inside specified dir.
#
# @arg dir - dir relative to repo
# @arg cmd - command to execute
#
# @internal
dockerExec() {
  local dir="$1"; shift
  docker exec -u $DC_USER:$DC_GROUP -w "$DC_REPO/$dir" $DC_NAME sh -c "$@"
}

# @description Function to create repo dir. Safe
#
# @internal
dockerMkRepo() {
  docker exec -u $DC_USER:$DC_GROUP $DC_NAME mkdir -p "$DC_REPO"
}

# @description Function to create dir inside repo. Safe.
#
# @arg parent - parent dir relative to repo
# @arg dir - dir relative to repo
#
# @internal
dockerMkDir() {
  local pd="$1"; shift
  for d in "$@"; do
    [[ -d $(dockerPath "$pd/$d") ]] || dockerExec "$pd" "mkdir -p $d"
  done
}

# @description Function to create dir inside repo. Unsafe.
#
# @arg parent - parent dir relative to repo
# @arg obj - dir or file to remove (relative to repo)
#
# @internal
dockerRm() {
  local pd="$1"; shift
  for obj in "$@"; do
    [[ -d $(dockerPath "$pd/$obj") ]] && dockerExec "$pd" "rm -rf $obj"
    [[ -f $(dockerPath "$pd/$obj") ]] && dockerExec "$pd" "rm -f $obj"
  done
}

# @description get /proc path for tag: dockerPath <dir>
#
# @arg dir - dir relative to repo
#
# @internal
function dockerPath() {
  echo "/proc/${GUEST_PID}/root${DC_REPO}/$1"
}

# @description Function to write to file.
#
# @arg file - file relative to repo
# @arg msg - mesage
#
# @internal
dockerWrite() {
  local cmd="echo '""$2""' >> $DC_REPO/""$1"
  dockerExec "" "$cmd"
}

# @description Function to ls.
#
# @arg dir - dir inside repo
# @arg pattern - pattern
#
# @internal
dockerLs() {
  local cmd="$(dockerPath $1)/$2"
  local rv=`/usr/bin/env ls $cmd`
  echo "$rv"
}

# endregion

# region #? top level

# @description Function to excute the source stage.
#              Not using `dockerExec` (for pretty output reasons)
#
# @example
#    $(dockerAptSources <task>)"
#
# @arg `task` a build task
dockerAptSources() {
  local task="$1" wdir=$(tagValue dsrc)
  local rv=$(docker exec -u $DC_USER:$DC_GROUP -w "$DC_REPO/$wdir/$task" -it $DC_NAME sh -c "apt-get source -q -d $task 1> /dev/null; exit $?")
  local rc=$?
  echo "$rv"
  return "$rc"
}

# endregion

# region #! old part

# excute apt-cache show: dockerAptCache <pkg>
dockerAptCache() {
  local pkg="$1"
  local str=$(docker exec -u $DC_USER:$DC_GROUP -it $DC_NAME sh -c "apt-cache show $pkg")
  local errc=0
  retval=$(grep -E '^Version|^Depends|^Provides|^Architecture' <<< "$str")
  if [[ -z "$retval" ]]; then #? checks for virtual
    if [[ -n $(grep 'as it is purely virtual' <<< "$str") ]]; then
      retval="virtual"
      errc=0
    else
      retval=""
      errc=1
    fi
  fi
  echo "$retval"
  return $errc
}

# excute apt-cache showpkg to solve purely virtual: dockerAptCache <pkg>
dockerAptVirtualProviders() {
  local pkg="$1"
  retval=$(docker exec -u $DC_USER:$DC_GROUP -it $DC_NAME sh -c "apt-cache showpkg $pkg | grep -A100 'Reverse Provides:'")
  if [[ -n "$retval" ]]; then
    retval=$(breqPackString "$retval")
    local vpa
    for line in ${retval//"\n"/ }; do
      [[ -n $(grep 'Reverse' <<< "$line") ]] && continue
      line=$(tr -cd '[:print:]' <<< "$line")
      vpa+=("$line")
    done
  fi
  echo "${vpa[@]}"
  return 0
}

# excute dpkg --status: dockerDpkgStatus <pkg>
dockerDpkgStatus() {
  local retval pkg="$1"
  retval=$(docker exec -u $DC_USER:$DC_GROUP -it $DC_NAME sh -c "dpkg -s $pkg 2> /dev/null | grep -E '^Status|^Version|^Architecture'; exit $?")
  [[ -z "$retval" ]] && return 1
  echo "$retval"
  return 0
}

# copy file to guest FS: dockerCopy <tag> <task> <file>
dockerCopy() {
  local retval tag="$1" task="$2"
  local file=(${3//'/'/ })
  file="${file[-1]}"
  retval=$(docker cp "$3" "${DC_NAME}:${DC_REPO}/$(tagValue $tag)/${task}/${file}")
  local errc=$?
  echo "$retval"
  return $errc
}

# endregion

#? module init

if [[ -n $SHDPKG_USEDOCKER ]]; then
  GUEST_PID=$(dockerInit)
  [[ -z $GUEST_PID ]] && error 1 DKR "docker bkend init fail"
fi