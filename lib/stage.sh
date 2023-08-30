#!/usr/bin/env bash
# @file stage
# @brief Stage library.

# region #? service

# @description Function to create dir inside repo.
#
# @arg stage - stage name
#
# @internal
stageKnown() {
  if ! [[ " ${STAGES[@]} all " == *" $1 "* ]]; then
    error 1 stage "unknown stage $1"
  fi
  return 0
}

# @description Function to check stage status and stamp status.
#              If stage's stamp dir is present but no state file - return
#              'none' as resut with retcode 1.
#
# @example
#    $(stageHas <task> <stage>)"
#
# @arg `task` a build task
# @arg `stages` a stage to check
#
# @stdout - status of task (e.g. none, valid, dirty, ...), if 'all' specified
#           call self with STAGES
#
# @exitcode 0 on success
# @exitcode 1 on failure
stageHas() {
  local task="$1" stage="$2"
  if [ -f "$STAMPD/$task/${stage}/state" ]; then
    echo $(cat "$STAMPD/$task/${stage}/state")
    return 0
  elif [ -d "$STAMPD/$task/${stage}/state" ]; then
    echo "none"
    return 0
  fi
  echo "wrong"
  return 1
}

# @description Function to init stage.
#
# @example
#    $(stageInit <task> <stages>)"
#
# @arg `force` to force state recreation
# @arg `task` a build task
# @arg `stage` a stage to check
#
# @exitcode 0 on success
# @exitcode 1 on failure
stageInit() {
  local force="$1" task="$2" stage="$3"
  [[ -n $force && $force != "--force" ]] && error 1 stage "mess in args"
  stageKnown "$stage"
  bkendMkRepo # safe at any speed
  bkendRm "$(tagValue log)" "$task.log"
  bkendMkDir "" "$(tagValue log)"
  logTask "$task" "--- $stage stage ---"
  local state=$(stageHas "$task" "$stage")
  if [ $? -gt 0 ]; then
    logTask "$task" "stage in unknown state"
    error 1 stage "check stage $stage state"
  fi
  if [[ $state == "clear" && -z $force ]]; then
    logTask "$task" "stage already clear, nothing to do"
    error 1 stage "stage \'$stage\' in clear state, use --force luke"
  fi
  rm -rf "$STAMPD/$task/${stage}"
  mkdir -p "$STAMPD/$task/${stage}"
  case "$stage" in
    'source') bkendRm "$(tagValue dsrc)" "$task"
              bkendMkDir "" "$(tagValue dsrc)/$task"
              stageInvalidate 'tree walk dload inst deb purge' ;;
     'dload') bkendRm "$(tagValue sh)" "$task/dload.sh"
              bkendRm "$(tagValue dbin)" "$task"
              bkendMkDir "" "$(tagValue sh)/$task"
              bkendMkDir "" "$(tagValue dbin)/$task"
              stageInvalidate 'inst deb purge' ;;
      'inst') bkendRm "$(tagValue sh)" "$task/install.sh"
              bkendMkDir "" "$(tagValue sh)/$task"
              stageInvalidate 'deb purge' ;;
       'deb') bkendRm "$(tagValue sh)" "$task/build.sh"
              bkendRm "$(tagValue out)" "$task"
              bkendMkDir "" "$(tagValue out)/$task"
              stageInvalidate 'purge' ;;
     'purge') bkendRm "$(tagValue sh)" "$task/uninstall.sh" ;;
           *) ;;
  esac
  return 0
}

# @description Function to invalidate stage.
#
# @example
#    $(stageInvalidate <task> <stages>)"
#
# @arg `task` a build task
# @arg `stages` a stage's array to invalidate
stageInvalidate() {
  local task="$1"; shift
  local stages="$@"
  for stage in ${stages[@]}; do
    stageKnown "$stage"
    [[ -f "$STAMPD/$task/${stage}/state" ]] && (echo "dirty" > "$STAMPD/$task/${stage}/state")
  done
  return 0
}

# @description Function to excute stage.
#
# @example
#    $(stageExec <task> <stage>)"
#
# @arg `task` a build task
stageExec() {
  local task="$1" stage="$2" rc=0 rv=""
  case "$stage" in
    'source') rv=$(stageSources $task); rc=$? ;;
      'tree') rv=$(stageTree $task); rc=$? ;;
      'walk') rv=$(stageWalk $task); rc=$? ;;
     'dload') rv=$(stageDownload $task); rc=$? ;;
      'inst') rv=$(stageInstall $task); rc=$? ;;
       'deb') rv=$(stageBinary $task); rc=$? ;;
     'purge') rv=$(stagePurge $task); rc=$? ;;
           *) error 1 stage "stage ${stage} unknown" ;;
  esac
  echo "$rv"
  return "$rc"
}

# endregion

# region #? stages

# @description Function to excute the source stage.
#
# @example
#    $(stageExec <task>)"
#
# @arg `task` a build task
stageSources() {
  local task="$1"
  local rv=$(bkendAptSources $task)
  local rc=$?
  if [[ $rc -gt 0 ]]; then
    logTask $task "gathering sources failed with reasons:"
    logTask $task "--- apt-get source ---"
    logTask $task "$rv"
    logTask $task "--- /apt-get source ---"
    error 1 stage "apt-get source failed, see log"
  else
    rv=$(bkendLs "$(tagValue dsrc)/$task" '*.dsc')
    if [[ $(wc -l <<< "$rv") -eq 1 ]]; then
      echo "clear" > "$STAMPD/$task/${stage}/state"
      logTask $task "sources loaded, dsc: $rv"
      logStatus "ok"
    else
      logTask $task "recived few dsc, givind up"
      logTask $task "--- dsc ---"
      logTask $task "$rv"
      logTask $task "--- /dsc ---"
      error 1 stage "recived few dsc, givind up"
    fi
  fi
  echo "$rv"
  return 0
}

# @description Function to excute the source stage.
#
# @example
#    $(stageExec <task>)"
#
# @arg `task` a build task
stageTree() {
  local task="$1"
  echo "" >&2 # we give a lot of output

  local state_source=$(stageHas "$task" "source")
  if [ $state_source != 'clear' ]; then
    logTask "$task" "previous stage 'source' isnt clear, exitig"
    error 1 stage "unclear previous stage (source)"
  fi

  logHead "$task" "obtaining build-depends ..."
  local bspecs=$(taskReqs $task)
  if [[ ${#bspecs[@]} -eq 0 ]]; then
    logTask "$task" "fail to obtain build-depends, exiting"
    logStatus "err" "fail"
    return 1
  fi
  logTask "$task" "collected build-depends"
  logStatus "ok"

  # fixme: ugly
  touch "$STAMPD/$task/tree/$BREQ_FLATTEN"
  touch "$STAMPD/$task/tree/.virtuals"

  local retcode last_package
  for bs in ${bspecs[@]}; do
    last_package=$(breqAddNode 0 "$bs" "" "$task")
    retcode=$?
    [[ $retcode -gt 0 ]] && error 1 stage "failed to get depended package: $(bspecName $last_package)"
    echo "" >&2 # instead [ OK ]
  done

  echo "clear" > "$STAMPD/$task/${stage}/state"
  logTask $task "depends tree builded"
}

# endregion