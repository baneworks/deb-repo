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

# @description Function to excute the "tree" stage. On this stage
#              dependency tree are built
#
# @example
#    $(stageTree <task>)"
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
  return 0
}

# @description Function to excute the "walk" stage. During this stage:
#              1. Calling (taskSumVReq)[./task#taskSumVReq] to summarize
#                 all of version constrains.
#              2. Unspin cycles and return ready to install packages
#                 list with suitable version specification.
#                 See (taskFinalDepends)[./task#taskFinalDepends]
#              4. Unalias virtual packages to its providers calling
#                 (taskUnalias)[./task#taskUnalias].
#              5. Another call of `taskSumVreq`, and i not shure why.
#                 will check it later.
#              6. Do some cleanup (taskClearDepends)[./task#taskClearDepends]
#              7. Filter installed (taskFilterInstalled)[./task#taskFilterInstalled]
#              8. Generate `dload.sh`, `install.sh`, `uninstall.sh`.
#                 See (taskMkInstall)[./task#taskMkInstall]
#
# @example
#    $(stageWalk <task>)"
#
# @arg `task` a build task
stageWalk() {
  local task="$1" rc
  echo "" >&2 # we give a lot of output

  local pstage_state=$(stageHas "$task" "tree")
  if [ $pstage_state != 'clear' ]; then
    logTask "$task" "previous stage 'tree' isnt clear, exitig"
    error 1 stage "unclear previous stage (tree)"
  fi

  logHead $task "composing version's requrenments ..."

  if ! [[ -f "$STAMPD/$task/tree/$BREQ_FLATTEN" ]]; then
    logTask $task "depends description file $BREQ_FLATTEN not found, exiting"
    error 1 stage "no depends description file, see log"
  fi
  rc=$(taskSumVreq "$task" "$STAMPD/$task/tree/$BREQ_FLATTEN" "$STAMPD/$task/walk/$BREQ_FLATTEN_RW")
  if [[ $rc -eq 1 ]]; then
    logStatus "err" "fail"
    logTask $task "can't compose version's requrenments, exiting"
    error 1 stage "can't compose version's requrenments, see log"
  elif [[ $rc -eq 2 ]]; then
    logStatus "warn" "issue"
  else
    logStatus "ok"
  fi

  logHead $task "depends finalisation ..."

  rc=$(taskFinalDepends "$task" "$STAMPD/$task/walk/$BREQ_FLATTEN_RW" "$STAMPD/$task/walk/$BREQ_PKGS")
  if [[ $rc -eq 1 ]]; then
    logStatus "err" "fail"
    logTask $task "can't finalize depends, exiting"
    error 1 stage "can't finalize depends, see log"
  elif [[ $rc -eq 2 ]]; then
    logStatus "warn" "issue"
  else
    logStatus "ok"
  fi

  logHead $task "solving virtuals ..."

  rc=$(taskUnalias "$task" "$STAMPD/$task/walk/$BREQ_PKGS" "$STAMPD/$task/walk/$BREQ_PKGS_UNALIAS")
  if [[ $rc -eq 1 ]]; then
    logStatus "err" "fail"
    logTask $task "can't substitute virtuals, exiting"
    error 1 stage "can't substitute virtuals, see log"
  elif [[ $rc -eq 2 ]]; then
    logStatus "warn" "issue"
  else
    logStatus "ok"
  fi

  # fixme: needed?
  logHead $task "composing version's requrenments ..."

  rc=$(taskSumVreq "$task" "$STAMPD/$task/walk/$BREQ_PKGS_UNALIAS" "$STAMPD/$task/walk/$BREQ_PKGS_RW")
  if [[ $rc -eq 1 ]]; then
    logStatus "err" "fail"
    logTask $task "composing version's requrenments (2nd run) failed, exiting"
    error 1 stage "can't compose version's requrenments, see log"
  elif [[ $rc -eq 2 ]]; then
    logStatus "warn" "issue"
  else
    logStatus "ok"
  fi

  logHead $task "cleaning list ..."

  rc=$(taskClearDepends "$task" "$STAMPD/$task/walk/$BREQ_PKGS_RW" "$STAMPD/$task/walk/$BREQ_PKGS_CLR")
  if [[ $rc -eq 1 ]]; then
    logStatus "err" "fail"
    logTask $task "clearing package list failed, exiting"
    error 1 stage "can't clear package list, see log"
  elif [[ $rc -eq 2 ]]; then
    logStatus "warn" "issue"
  else
    logStatus "ok"
  fi

  logHead $task "filter installed ..."

  rc=$(taskFilterInstalled "$task" "$STAMPD/$task/walk/$BREQ_PKGS_CLR" "$STAMPD/$task/walk/$BREQ_PKGS_INST")
  if [[ $rc -eq 1 ]]; then
    logStatus "err" "fail"
    logTask $task "clearing of installed packages failed, exiting"
    error 1 stage "can't drop installed packages, see log"
  elif [[ $rc -eq 2 ]]; then
    logStatus "warn" "issue"
  else
    logStatus "ok"
  fi

  logHead $task "package install list ..."

  rc=$(taskMkInstall "$task" "$STAMPD/$task/walk/$BREQ_PKGS_INST" "$STAMPD/$task/walk/$BREQ_PKGS_INST_FLT")
  if [[ $rc -eq 1 ]]; then
    logStatus "err" "fail"
    logTask $task "creation of package installation list failed, exiting"
    error 1 stage "can't make package installation list, see log"
  elif [[ $rc -eq 2 ]]; then
    logStatus "warn" "issue"
  else
    logStatus "ok"
  fi

  logHead $task "generating dowload sripts ..."

  rc=$(taskDload "$task" "$STAMPD/$task/walk/$BREQ_PKGS_INST_FLT" "$STAMPD/$task/walk/$BREQ_PKGS_DLSH")
  if [[ $rc -eq 1 ]]; then
    logStatus "err" "fail"
    logTask $task "fail to generate 'dload.sh', exiting"
    error 1 stage "can't make download script, see log"
  elif [[ $rc -eq 2 ]]; then
    logStatus "warn" "issue"
  else
    logStatus "ok"
  fi

  logHead $task "generating install/uninstall & check sripts ..."

  bkendMkDir "" "$(tagValue sh)"
  rc=$(taskDebInstall "$task" "$STAMPD/$task/walk/$BREQ_PKGS_INST_FLT" "$STAMPD/$task/walk/$BREQ_PKGS_ISH" "$STAMPD/$task/walk/$BREQ_PKGS_USH" "$STAMPD/$task/walk/$BREQ_PKGS_LSH")
  if [[ $rc -eq 1 ]]; then
    logStatus "err" "fail"
    logTask $task "fail to generate 'install.sh', 'uninstall.sh', 'fcheck.sh', exiting"
    error 1 stage "can't make install/uninstall scripts, see log"
  elif [[ $rc -eq 2 ]]; then
    logStatus "warn" "issue"
  else
    logStatus "ok"
  fi

  echo "clear" > "$STAMPD/$task/${stage}/state"
  logTask $task "package list builded"
  return 0
}

# @description Function to excute the "dload" stage.
#
# @example
#    $(stageDload <task>)"
#
# @arg `task` a build task
stageDload() {
  local task="$1"
  echo "" >&2 # we give a lot of output

  local pstate_status=$(stageHas "$task" "walk")
  if [ $pstate_status != 'clear' ]; then
    logTask "$task" "previous stage 'walk' isnt clear, exitig"
    error 1 stage "unclear previous stage (walk)"
  fi

  if ! [[ -f "$STAMPD/$task/walk/$BREQ_PKGS_DLSH" ]]; then
    logTask $task "download script $BREQ_PKGS_DLSH not found, exiting"
    error 1 stage "no download script, see log"
  fi
  bkendCopy $(tagValue sh) $task "$STAMPD/$task/walk/$BREQ_PKGS_DLSH"

  logHead "$task" "downloading debs ..."

  local rv=$(bkendExec "$task" 'dbin' "sh -c ../../$task/$(tagValue sh)/$BREQ_PKGS_DLSH")
  if [[ $rc -eq 1 ]]; then
    logStatus "err" "fail"
    logTask $task "fail to donwload debs: "
    logTask $task "--- $BREQ_PKGS_DLSH ---"
    logTask $task "$rv"
    logTask $task "--- /$BREQ_PKGS_DLSH ---"
    error 1 stage "fail to donwload debs, see log"
  elif [[ $rc -eq 2 ]]; then
    logStatus "warn" "issue"
  else
    logStatus "ok"
  fi

  echo "clear" > "$STAMPD/$task/${stage}/state"
  logTask $task "all debs downloaded"
  return 0
}

# endregion