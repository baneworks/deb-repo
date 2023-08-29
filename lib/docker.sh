#!/usr/bin/env bash
# @file docker
# @brief The docker backend.

# get container pid
function dockePid() {
  local pid=$(docker inspect -f '{{.State.Pid}}' $DC_NAME)
  if [[ $pid -le 1 ]]; then
   error 1 NOCONTAINER "no debian container running"
   return 1
  fi
  echo "$pid"
}

dockerInit() {
  declare GUEST_PID=$(dockePid)
  [[ GUEST_PID -le 1 ]] && (echo ""; return 1)
  echo "true"
}

# get /proc path for tag: dockerRelativePath <tag> <path>
function dockerRelativePath() {
  local dir
  if [ -z $1 ]; then
    dir="/proc/$GUEST_PID/root/$DC_REPO"
  elif [ -z $2 ]; then
    dir="/proc/$GUEST_PID/root/$DC_REPO/$(tagValue $1)"
  else
    dir="/proc/$GUEST_PID/root/$DC_REPO/$(tagValue $1)/$2"
  fi
  echo $dir
}

# create repo dir $REPO_NAME
dockerMakeRepoDir() {
  docker exec -u $DC_USER:$DC_GROUP -w "/home/$DC_USER" $DC_NAME mkdir $(tagValue "repo" )
}

# remove whole repo $REPO_NAME
dockerRmRepo() {
  docker exec -u $DC_USER:$DC_GROUP -w "/home/$DC_USER" $DC_NAME rm -Rf $(tagValue "repo" )
}

# execute docker command inside $REPO_NAME: dockerExec <command>
dockerExec() {
  docker exec -u $DC_USER:$DC_GROUP -w "/$DC_REPO" $DC_NAME $@
}

# execute docker command inside dir: dockerDirExec <dir> <command>
dockerDirExec() {
  local reldir
  reldir=$1
  shift;
  docker exec -u $DC_USER:$DC_GROUP -w "/$DC_REPO/$reldir/" $DC_NAME $@
}

#* only for pretty output
# excute apt-get sources: dockerAptSources <task>
dockerAptSources() {
  local task wdir retval
  task=$1
  shift;
  wdir=$(tagValue 'dsrc')
  wdir="/$DC_REPO/$wdir"
  wdir="$wdir/$task"
  retval=$(docker exec -u $DC_USER:$DC_GROUP -w $wdir -it $DC_NAME sh -c "apt-get source -q -d $task 1> /dev/null; exit $?")
  [[ $retval != "" ]] && retval="-1"
  echo "$retval"
}

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

# create dir inside repo: dockerMakeDir <dir>
dockerMakeDir() {
  dockerDirExec "" mkdir $@
}

# delete dir inside repo: dockerMakeDir <dir>
dockerRmDir() {
  dockerExec rm -rf $@
}

# create guest fhs
function guestClearFHS () {
  [[ -d $(dockerRelativePath "") ]] && dockerRmRepo
}

# fixme: ugly
# create guest fhs
function guestCreateFHS () {
  local wdir=$(dockerRelativePath )
  local btree=$(dockerRelativePath "btree")
  local sh=$(dockerRelativePath "sh")
  local dbin=$(dockerRelativePath "dbin")
  local dsrc=$(dockerRelativePath "dsrc")
  local tmp=$(dockerRelativePath "tmp")
  [ ! -d $wdir ]  && dockerMakeRepoDir
  [ ! -d $btree ] && dockerMakeDir $(tagValue "btree")
  [ ! -d $sh ]    && dockerMakeDir $(tagValue "sh")
  [ ! -d $dbin ]  && dockerMakeDir $(tagValue "dbin")
  [ ! -d $dsrc ]  && dockerMakeDir $(tagValue "dsrc")
  [ ! -d $tmp ]   && dockerMakeDir $(tagValue "tmp")
}

dockerInit