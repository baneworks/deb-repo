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
              bkendMkDir "" "$(tagValue sh)/$task" ;;
              # stageInvalidate 'deb purge' ;;
       'deb') bkendRm "$(tagValue sh)" "$task/build.sh"
              bkendRm "$(tagValue out)" "$task"
              bkendMkDir "" "$(tagValue out)/$task" ;;
              # stageInvalidate 'purge' ;;
     'purge') bkendRm "$(tagValue sh)" "$task/uninstall.sh"
              stageInvalidate 'inst deb purge' ;;
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
    if [[ -f "$STAMPD/$task/${stage}/state" ]]; then
      echo "dirty" > "$STAMPD/$task/${stage}/state"
    fi
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
  if [[ $rc -eq 0 ]]; then
    echo "clear" > "$STAMPD/$task/${stage}/state"
  fi
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
      # echo "clear" > "$STAMPD/$task/${stage}/state"
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

  # echo "clear" > "$STAMPD/$task/${stage}/state"
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
  local task="$1"
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
  local rv=$(taskSumVreq "$task" "$STAMPD/$task/tree/$BREQ_FLATTEN" "$STAMPD/$task/walk/$BREQ_FLATTEN_RW")
  if [[ $? -eq 1 ]]; then
    logStatus "err" "fail"
    logTask $task "can't compose version's requrenments, exiting"
    error 1 stage "can't compose version's requrenments, see log"
  elif [[ $? -eq 2 ]]; then
    logStatus "warn" "issue"
  else
    logStatus "ok"
  fi

  logHead $task "depends finalisation ..."

  rv=$(taskFinalDepends "$task" "$STAMPD/$task/walk/$BREQ_FLATTEN_RW" "$STAMPD/$task/walk/$BREQ_PKGS")
  if [[ $? -eq 1 ]]; then
    logStatus "err" "fail"
    logTask $task "can't finalize depends, exiting"
    error 1 stage "can't finalize depends, see log"
  elif [[ $? -eq 2 ]]; then
    logStatus "warn" "issue"
  else
    logStatus "ok"
  fi

  logHead $task "solving virtuals ..."

  rv=$(taskUnalias "$task" "$STAMPD/$task/walk/$BREQ_PKGS" "$STAMPD/$task/walk/$BREQ_PKGS_UNALIAS")
  if [[ $? -eq 1 ]]; then
    logStatus "err" "fail"
    logTask $task "can't substitute virtuals, exiting"
    error 1 stage "can't substitute virtuals, see log"
  elif [[ $? -eq 2 ]]; then
    logStatus "warn" "issue"
  else
    logStatus "ok"
  fi

  # fixme: needed?
  logHead $task "composing version's requrenments ..."

  rc=$(taskSumVreq "$task" "$STAMPD/$task/walk/$BREQ_PKGS_UNALIAS" "$STAMPD/$task/walk/$BREQ_PKGS_RW")
  if [[ $? -eq 1 ]]; then
    logStatus "err" "fail"
    logTask $task "composing version's requrenments (2nd run) failed, exiting"
    error 1 stage "can't compose version's requrenments, see log"
  elif [[ $? -eq 2 ]]; then
    logStatus "warn" "issue"
  else
    logStatus "ok"
  fi

  logHead $task "cleaning list ..."

  rv=$(taskClearDepends "$task" "$STAMPD/$task/walk/$BREQ_PKGS_RW" "$STAMPD/$task/walk/$BREQ_PKGS_CLR")
  if [[ $? -eq 1 ]]; then
    logStatus "err" "fail"
    logTask $task "clearing package list failed, exiting"
    error 1 stage "can't clear package list, see log"
  elif [[ $? -eq 2 ]]; then
    logStatus "warn" "issue"
  else
    logStatus "ok"
  fi

  logHead $task "filter installed ..."

  rv=$(taskFilterInstalled "$task" "$STAMPD/$task/walk/$BREQ_PKGS_CLR" "$STAMPD/$task/walk/$BREQ_PKGS_INST")
  if [[ $? -eq 1 ]]; then
    logStatus "err" "fail"
    logTask $task "clearing of installed packages failed, exiting"
    error 1 stage "can't drop installed packages, see log"
  elif [[ $? -eq 2 ]]; then
    logStatus "warn" "issue"
  else
    logStatus "ok"
  fi

  logHead $task "package install list ..."

  rv=$(taskMkInstall "$task" "$STAMPD/$task/walk/$BREQ_PKGS_INST" "$STAMPD/$task/walk/$BREQ_PKGS_INST_FLT")
  if [[ $? -eq 1 ]]; then
    logStatus "err" "fail"
    logTask $task "creation of package installation list failed, exiting"
    error 1 stage "can't make package installation list, see log"
  elif [[ $? -eq 2 ]]; then
    logStatus "warn" "issue"
  else
    logStatus "ok"
  fi

  logHead $task "generating dowload sripts ..."

  rv=$(taskDload "$task" "$STAMPD/$task/walk/$BREQ_PKGS_INST_FLT" "$STAMPD/$task/walk/$BREQ_PKGS_DLSH")
  if [[ $? -eq 1 ]]; then
    logStatus "err" "fail"
    logTask $task "fail to generate 'dload.sh', exiting"
    error 1 stage "can't make download script, see log"
  elif [[ $? -eq 2 ]]; then
    logStatus "warn" "issue"
  else
    logStatus "ok"
  fi

  logHead $task "generating install/uninstall & check sripts ..."

  bkendMkDir "" "$(tagValue sh)"
  rv=$(taskDebInstall "$task" "$STAMPD/$task/walk/$BREQ_PKGS_INST_FLT" "$STAMPD/$task/walk/$BREQ_PKGS_ISH" "$STAMPD/$task/walk/$BREQ_PKGS_USH" "$STAMPD/$task/walk/$BREQ_PKGS_LSH")
  if [[ $? -eq 1 ]]; then
    logStatus "err" "fail"
    logTask $task "fail to generate 'install.sh', 'uninstall.sh', 'fcheck.sh', exiting"
    error 1 stage "can't make install/uninstall scripts, see log"
  elif [[ $? -eq 2 ]]; then
    logStatus "warn" "issue"
  else
    logStatus "ok"
  fi

  # echo "clear" > "$STAMPD/$task/${stage}/state"
  logTask $task "package list builded"
  return 0
}

# @description Function to excute the "dload" stage.
#
# @example
#    $(stageDload <task>)"
#
# @arg `task` a build task
stageDownload() {
  local task="$1"

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
  bkendExec "$task" "$(tagValue sh)" "chmod u+x $BREQ_PKGS_DLSH"

  # logHead "$task" "downloading debs ..."

  logTask "$task" "executing sh -c ../../$task/$(tagValue sh)/$BREQ_PKGS_DLSH at $task/$(tagValue dbin)"
  local rv=$(bkendExec "$task" 'dbin' "sh -c ../../$(tagValue sh)/$task/$BREQ_PKGS_DLSH > /dev/null 2>&1")
  if [[ $? -gt 0 ]]; then
    logTask $task "fail to donwload debs: "
    logTask $task "--- $BREQ_PKGS_DLSH ---"
    logTask $task "$rv"
    logTask $task "--- /$BREQ_PKGS_DLSH ---"
  else
    logStatus "ok"
  fi
  if [[ $? -eq 1 ]]; then
    logStatus "err" "fail"
    error 1 stage "fail to donwload debs, see log"
  elif [[ $? -eq 2 ]]; then
    logStatus "warn" "issue"
  fi

  # echo "clear" > "$STAMPD/$task/${stage}/state"
  logTask $task "all debs downloaded"
  return 0
}

# @description Function to excute the "install" stage.
#
# @example
#    $(stageInstall <task>)"
#
# @arg `task` a build task
stageInstall() {
  local task="$1"

  local pstate_status=$(stageHas "$task" "dload")
  if [ $pstate_status != 'clear' ]; then
    logTask "$task" "previous stage 'walk' isnt clear, exitig"
    error 1 stage "unclear previous stage (walk)"
  fi

  if ! [[ -f "$STAMPD/$task/walk/$BREQ_PKGS_ISH" ]]; then
    logTask $task "install script $BREQ_PKGS_ISH not found, exiting"
    error 1 stage "no install script, see log"
  fi
  bkendCopy $(tagValue sh) $task "$STAMPD/$task/walk/$BREQ_PKGS_ISH"
  bkendExec "$task" "$(tagValue sh)" "chmod u+x $BREQ_PKGS_ISH"

  logTask "$task" "executing $BKEND_SUCMD -c ../../$task/$(tagValue sh)/$BREQ_PKGS_ISH at $task/$(tagValue dbin)"
  local rv=$(bkendExec "$task" 'dbin' "$BKEND_SUCMD -c ../../$(tagValue sh)/$task/$BREQ_PKGS_ISH  > /dev/null 2>&1")
  local rc=$?
  logTask $task "--- $BREQ_PKGS_ISH ---"
  logTask $task "$rv"
  logTask $task "--- /$BREQ_PKGS_ISH ---"
  if [[ $rc -gt 0 ]]; then
    logTask $task "fail to install debs"
    logStatus "err" "fail"
    error 1 stage "fail to install debs, see log"
  fi
  logStatus "ok"

  # echo "clear" > "$STAMPD/$task/${stage}/state"
  logTask $task "all debs installed"
  return 0
}

# @description Function to excute the "build" stage.
#
# @example
#    $(stageBinary <task>)"
#
# @arg `task` a build task
stageBinary() {
  local task="$1"
  echo "" >&2

  local pstate_status=$(stageHas "$task" "inst")
  if [ $pstate_status != 'clear' ]; then
    logTask "$task" "previous stage 'install' isnt clear, exitig"
    error 1 stage "unclear previous stage (install)"
  fi

  logHead "$task" "unpacking ..."
  local rv=$(bkendExec "$task" "dsrc" "apt-get source $task")
  local rc=$?
  logTask $task "--- apt-get source ---"
  # logTask $task "$rv" # fixme: not working
  logTask $task "--- /apt-get source ---"
  if [[ $rc -gt 0 ]]; then
    logTask $task "fail to unpack sources: "
    logStatus "err" "fail"
    error 1 stage "fail to unpack sources, see log"
  fi
  rv=$(bkendLs "-d $(tagValue dsrc)/$task/*")
  if [[ $(wc -l <<< "$rv") -gt 1 ]]; then
    logStatus "err" "fail"
    error 1 stage "few source's dir, which should built?"
  fi
  local bdir=(${rv//'/'/ })
  bdir=${bdir[-1]}
  logStatus "ok"
  logTask $task "source unpacked"

  logHead "$task" "configure ..."
  rv=$(bkendExec "$task/$bdir" "dsrc" "./debian/rules configure")
  rc=$?
  logTask $task "--- configure ---"
  # logTask $task "$rv" # fixme: not working
  logTask $task "--- /configure ---"
  if [[ $rc -gt 0 ]]; then
    logTask $task "fail to configure sources: "
    logStatus "err" "fail"
    error 1 stage "fail on debian/rules configure"
  fi
  logTask $task "source configured"
  logStatus "ok"

  logHead "$task" "build ..."
  bkendMkDir "dsrc" "$bdir/stamps" # fixme: hack
  rv=$(bkendExec "$task/$bdir" "dsrc" "$BKEND_SUCMD -c './debian/rules binary 2> /dev/null'")
  rc=$?
  logTask $task "--- binary ---"
  # logTask $task "$rv" # fixme: not working
  logTask $task "--- /binary ---"
  if [[ $rc -gt 0 ]]; then
    logTask $task "fail to configure sources: "
    logStatus "err" "fail"
    error 1 stage "fail on debian/rules binary"
  fi
  logTask $task "all debs build"
  logStatus "ok"

  logHead "$task" "collecting debs ..."
  rv=$(bkendExec "$task" "dsrc" "$BKEND_SUCMD -c \"cp *.deb ../../$(tagValue out)/$task/\"")
  rc=$?
  if [[ $rc -gt 0 ]]; then
    logTask $task "fail while collecting results"
    logStatus "err" "fail"
    error 1 stage "fail while collecting results"
  fi
  local do_chmod="true"
  local uid=$(bkendExec "$task" "out" "id -un")
  local gid=$(bkendExec "$task" "out" "id -gn")
  if [[ $? -gt 0 ]]; then
    logTask $task "cant get user id:gid"
    logStatus "warn" "!chown"
    unset do_chmod
  fi
  if [[ -n $do_chmod ]]; then
    rv=$(bkendExec "$task" "out" "$BKEND_SUCMD -c \"chown $uid:$gid *.deb\"")
    logTask $task "all debs in $(tagValue out)/$task"
  fi
  logStatus "ok"

  return 0
}

# @description Function to excute the "install" stage.
#
# @example
#    $(stageInstall <task>)"
#
# @arg `task` a build task
stagePurge() {
  local task="$1"

  local pstate_status=$(stageHas "$task" "install")
  # if [ $pstate_status != 'clear' ]; then
  #   logTask "$task" "install stage isnt clear, exitig"
  #   error 1 stage "unclear install stage"
  # fi

  if ! [[ -f "$STAMPD/$task/walk/$BREQ_PKGS_USH" ]]; then
    logTask $task "uninstall script $BREQ_PKGS_USH not found, exiting"
    error 1 stage "no uninstall script, see log"
  fi
  bkendCopy $(tagValue sh) $task "$STAMPD/$task/walk/$BREQ_PKGS_USH"
  bkendExec "$task" "$(tagValue sh)" "chmod u+x $BREQ_PKGS_USH"

  logTask "$task" "executing $BKEND_SUCMD -c ../../$task/$(tagValue sh)/$BREQ_PKGS_USH at $task/$(tagValue dbin)"
  local rv=$(bkendExec "$task" 'dbin' "$BKEND_SUCMD -c ../../$(tagValue sh)/$task/$BREQ_PKGS_USH 2>&1")
  logTask $task "--- $BREQ_PKGS_USH ---"
  logTask $task "$rv"
  logTask $task "--- /$BREQ_PKGS_USH ---"
  if [[ $? -eq 0 ]]; then
    logStatus "ok"
  else
    logTask $task "fail to purge debs"
    logStatus "err" "fail"
    error 1 stage "fail to purge debs, see log"
  fi

  # echo "clear" > "$STAMPD/$task/${stage}/state"
  logTask $task "all debs purged"
  return 0
}

# endregion