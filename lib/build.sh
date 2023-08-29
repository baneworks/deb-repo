#!/usr/bin/env bash
# @file build
# @brief Functions to build a task.

# init build process
buildInit() {
  [[ -z $(dockerInit) ]] && return 1

  # fixme: ugly
  # fixme: test mode
  info buildInit "--- test mode ---"
  # guestClearFHS
  # guestCreateFHS
}

# build task: buildTask <task>
buildTask() {
  local task="$1"
  local bspecs

  # fixme: test mode
  info "buildTask /$task/" "... taskInit skipped ..."
  # taskInit $task
  # bspecs=$(taskReqs $task)

  # fixme: test mode
  info "buildTask /$task/" "... breqAddNode skipped ..."
  # local retcode last_package
  # for bs in ${bspecs[@]}; do
  #   last_package=$(breqAddNode 0 "$bs" "" "$task")
  #   retcode=$?
  #   [[ $retcode -gt 0 ]] && error 1 EDEPEND "failed to get depended package: $(bspecName $last_package)"
  #   echo "" # instead [ OK ]
  # done

  # fixme: test mode
  # info "buildTask /$task/" "... taskSumVReq skipped ..."
  [[ -f "$BREQ_DIR/$task/$BREQ_FLATTEN_RW" ]] && rm -f "$BREQ_DIR/$task/$BREQ_FLATTEN_RW"
  info $task "versions ..."
  taskSumVreq "$task" "$BREQ_FLATTEN" "$BREQ_FLATTEN_RW"

  # fixme: test mode
  # info "buildTask /$task/" "packages (1/4): ... taskFinalDepends skipped ..."
  [[ -f "$BREQ_DIR/$task/$BREQ_PKGS" ]] && rm -f "$BREQ_DIR/$task/$BREQ_PKGS"
  info $task "packages (1/4): packages list ..."
  taskFinalDepends "$task" "$BREQ_FLATTEN_RW" "$BREQ_PKGS"
  [[ $? -gt 0 ]] && error 1 FDEPS "finalization of depends failed"

  # fixme: test mode
  # info "buildTask /$task/" "packages (2/4): ... taskUnalias skipped ..."
  [[ -f "$BREQ_DIR/$task/$BREQ_PKGS_UNALIAS" ]] && rm -f "$BREQ_DIR/$task/$BREQ_PKGS_UNALIAS"
  info $task "packages (2/4): solving virtuals ..."
  taskUnalias "$task" "$BREQ_PKGS" "$BREQ_PKGS_UNALIAS"
  [[ $? -gt 0 ]] && error 1 FDEPS "solving virtuals failed"

  # todo: is actually needed
  # fixme: test mode
  # info "buildTask /$task/" "packages (3/4): ... taskSumVreq skipped ..."
  [[ -f "$BREQ_DIR/$task/$BREQ_PKGS_RW" ]] && rm -f "$BREQ_DIR/$task/$BREQ_PKGS_RW"
  info $task "packages (3/4): making list ..."
  taskSumVreq "$task" "$BREQ_PKGS_UNALIAS" "$BREQ_PKGS_RW"
  [[ $? -gt 0 ]] && error 1 FDEPS "creation of pkg list failed"

  # fixme: test mode
  # info "buildTask /$task/" "packages (4/4): ... taskClearDepends skipped ..."
  info $task "packages (4/4): cleaning list ..."
  [[ -f "$BREQ_DIR/$task/$BREQ_PKGS_CLR" ]] && rm -f "$BREQ_DIR/$task/$BREQ_PKGS_CLR"
  taskClearDepends "$task" "$BREQ_PKGS_RW" "$BREQ_PKGS_CLR"
  [[ $? -gt 0 ]] && error 1 FDEPS "cleaning of depends failed"

  # fixme: test mode
  # info "buildTask /$task/" "install (1/4): ... taskFilterInstalled skipped ..."
  info $task "install (1/4): filter installed ..."
  [[ -f "$BREQ_DIR/$task/$BREQ_PKGS_INST" ]] && rm -f "$BREQ_DIR/$task/$BREQ_PKGS_INST"
  taskFilterInstalled "$task" "$BREQ_PKGS_CLR" "$BREQ_PKGS_INST"
  [[ $? -gt 0 ]] && error 1 DPKG "filtering installed failed"

  # fixme: test mode
  # info "buildTask /$task/" "install (2/4): ... taskMkInstall skipped ..."
  info $task "install (2/4): pkgs list ..."
  [[ -f "$BREQ_DIR/$task/$BREQ_PKGS_INST_FLT" ]] && rm -f "$BREQ_DIR/$task/$BREQ_PKGS_INST_FLT"
  taskMkInstall "$task" "$BREQ_PKGS_INST" "$BREQ_PKGS_INST_FLT"
  [[ $? -gt 0 ]] && error 1 DPKG "mk install list failed"

  # fixme: test mode
  # info "buildTask /$task/" "install (3/4): ... taskDload skipped ..."
  info $task "install (3/4): pkgs dload ..."
  [[ -f "$BREQ_DIR/$task/$BREQ_PKGS_DLSH" ]] && rm -f "$BREQ_DIR/$task/$BREQ_PKGS_DLSH"
  [[ -d "$(dockerRelativePath sh)/$task" ]] && dockerRmDir "./$(tagValue sh)/$task"
  [[ -d "$(dockerRelativePath dbin)/$task" ]] && dockerRmDir ./"$(tagValue dbin)/$task"
  taskDload "$task" "$BREQ_PKGS_INST_FLT" "$BREQ_PKGS_DLSH"
  [[ $? -gt 0 ]] && error 1 DPKG "dload install list failed"

  # fixme: test mode
  # info "buildTask /$task/" "install (4/4): ... taskDebInstall skipped ..."
  # info $task "install (4/4): dpkg install ..."
  [[ -f "$BREQ_DIR/$task/$BREQ_PKGS_ISH" ]] && rm -f "$BREQ_DIR/$task/$BREQ_PKGS_ISH"
  [[ -f "$(dockerRelativePath sh)/$task/$BREQ_PKGS_ISH" ]] && dockerRmDir ./"$(tagValue sh)/$task/$BREQ_PKGS_ISH"
  [[ -f "$BREQ_DIR/$task/$BREQ_PKGS_USH" ]] && rm -f "$BREQ_DIR/$task/$BREQ_PKGS_USH"
  [[ -f "$(dockerRelativePath sh)/$task/$BREQ_PKGS_USH" ]] && dockerRmDir ./"$(tagValue sh)/$task/$BREQ_PKGS_USH"
  [[ -f "$BREQ_DIR/$task/$BREQ_PKGS_LSH" ]] && rm -f "$BREQ_DIR/$task/$BREQ_PKGS_LSH"
  [[ -f "$(dockerRelativePath sh)/$task/$BREQ_PKGS_LSH" ]] && dockerRmDir ./"$(tagValue sh)/$task/$BREQ_PKGS_LSH"
  taskDebInstallTest "$task" "$BREQ_PKGS_INST_FLT" "$BREQ_PKGS_ISH" "$BREQ_PKGS_USH" "$BREQ_PKGS_LSH"
  [[ $? -gt 0 ]] && error 1 DPKG "install debs failed"

}

# build all tasks: buildAll
buildAll() {
  buildInit || return 1
  for task in $(taskList); do
    buildTask "$task"
    # fixme: test mode
    break
  done
}