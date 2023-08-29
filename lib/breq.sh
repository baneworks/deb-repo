#!/usr/bin/env bash
# @file breq
# @brief A library for generating build-depends for a task.

# region #! breq strings funcs

# pack depends to spaceless string: breqPackString <string>
breqPackString() {
  local str="$1"
  # str=$(tr -cd '[:print:]' <<< "$str")
  str="${str//' '/'&'}"
  echo "$str"
}

# unpack spaceless string: breqUnpackString <string>
breqUnpackString() {
  local str="$1"
  str="${str//'&'/' '}"
  echo "$str"
}

# unpack and call taskParseBR: breqParsePacked <string>
breqParsePacked() {
  local unpacked=$(breqUnpackString "$1")
  # fixme: package:any hack
  unpacked=$(sed 's/\(.*\)\:any$/\1/' <<< "$unpacked")
  local breqs=$(taskParseBR "$unpacked")
  echo "${breqs[*]}"
}

# endregion

# region #! version funcs

# check version reqs and return index of suitable: breqWhichVersion <cond> <@versions>
# @description Function to find suitable package from available packages accroding dependency requrenment string.
#
# @example
#    $(breqWhichVersion <req> <packages>)"
#
# @arg `req` requrenment string like ">= 2.4 2.31-13+deb11u6".
# @arg packages array of available in [bspec](./lib-bspec) format.
#
# @stdout index of suitable package
#
# @exitcode 0 on success
# @exitcode 1 on failure.
breqWhichVersion() {
  local cond="$1"
  shift
  local avail=($@)

  # fixme: test samples
  testAddToVersionSamples $cond $avail # generate version samples

  for ((idx=0; idx < ${#avail[@]}; ++idx)); do
    local matched=$(dverMatch "$cond" "${avail[$idx]}")
    [[ -n "$matched" ]] && break
  done


  if [[ -n $matched ]]; then
    echo $idx
    return 0
  else
    return 1
  fi
}

# endregion

# region #! node funcs

# fixme: replace to grep
# $1 - bspec
breqSeenBefore() {
  local bspec="$1"
  local bname=$(bspecName "$bspec")
  local bver=$(bspecVersionHR "$bspec")
  mapfile -t lines < "$BREQ_DIR/$task/$BREQ_FLATTEN"
  for line in "${lines[@]}"; do
    line=$(sed 's/^\([0-9]\+\s\+\)\(.*\)$/\2/' <<< "$line")
    local la=(${line})
    for provided_bs in ${la[@]}; do
      local provided_bn=$(bspecName "$provided_bs")
      local provided_bv=$(bspecVersion "$provided_bs")
      if [[ "$bname" == "$provided_bn" ]]; then
        if [[ -z $bver ]]; then
          echo "true"
          return 0
        fi
        if [[ -n $(dverMatch "$bver" "$provided_bv") ]]; then
          echo "true"
          return 0
        else
          echo ""
          return 0
        fi
      fi
    done
  done
}

# todo: add feature to store cyclic info
#? 1. a feature to store in flat file (e.g. $task/.cyclics)
#? 2. a feature to mark entire cyclic chain using (retcode=2
#?    and retvalue preserve machanics)

# @description Function to add node to build-depens tree. Reqursive.
#
# @example
#    $(breqAddNode <level> <bspec> <retcode> <retvalue> <@parents>)"
#
# @arg level numeric target level of build-depens tree.
# @arg bspec build-dependency in `bspec` format.
# @arg retvalue result value of pervious execution.
#      Used at top level to find exact point of failure
# @arg parents parents array of build-dependency upto root node.
#
# @stdout last processed (failed) package in bspec format (@see bspec).
#
# @exitcode usial behaivor
#
# @see bspec
breqAddNode() {
  local level=$(( $1 + 1 ))
  local bspec="$2"
  local retvalue="$3"
  shift; shift; shift;

  local bname=$(bspecName "$bspec")
  local bver=$(bspecVersionHR "$bspec")

  local task=($@); task="${task[0]}"

  if [[ $(grep -c "$bname" < "$BREQ_DIR/$task/$BREQ_FLATTEN") -eq 0 ]] ||
     [[ $(grep -c "$bname" < "$BREQ_DIR/$task/.virtuals") -eq 0 ]]
  then
    # todo: perfomance inpact -> find way to move lover
    local str=$(dockerAptCache "$bname")
    #? ---- virtual ----
    if [[ "$str" == "virtual" ]]; then
      local pva=($(dockerAptVirtualProviders "$bname"))
      for ((i=0; i<${#pva[@]}; ++i)); do
        local pfields=(${pva[$i]//'&'/ })
        local virt_vrq=$(sed 's/[()]//g' <<< "${pfields[2]} ${pfields[3]}")
        local virt_ver="${pfields[1]}"
        local virt_name="${pfields[0]}"
        [[ "$bver" == "$virt_vrq" ]] && break
      done
      if [[ $i -gt ${#pva[@]} ]]; then
        breqPrintStatus $level "err" "!prov"
        echo "$bspec" # pass current package upstack
        return 1 #! no providers for virtual isn't good - lets caller decide
      fi
      echo "$bname $virt_name" >> "$BREQ_DIR/$task/.virtuals"
      local str=$(dockerAptCache "$virt_name=$virt_ver")
      bspec="$virt_name/$virt_ver"
      bname=$(bspecName $bspec)
      bver=$(bspecVersionHR $bspec)
    fi
  fi
  #? ---- /virtual ----

  #? ---- init ----
  local pa=($@) # parents array
  local parent="${pa[-1]}" # prev node
  local pinfo # parents str separated by "/"
  local req_dir="$BREQ_DIR" # path to store node info
  local is_cyclic cyclic_dir cyclic_parent

  local prev_idx=-1
  for p in "${pa[@]}"; do
    pinfo+="/$p"
    req_dir+="/$p"
    prev_idx=$(( $prev_idx + 1 ))
    #* if bname in parents, trigger cycle checks
    if [[ "$p" == "$bname" ]]; then
      is_cyclic="true"
      cyclic_dir="$req_dir"
      if [[ $prev_idx -ge 0 ]]; then # store cyclic parent
        cyclic_parent=${pa[$prev_idx]}
      else #! cyclic source is task themself - giving up
        breqPrintStatus $level "err" "unbreakable circle"
        echo "$bspec"  # pass current package upstack
        return 1
      fi
    fi
  done

  req_dir+="/$bname"
  pinfo="${pinfo:1}"
  [[ -d "$req_dir" ]] || mkdir "$req_dir"
  echo "$bname" > "$req_dir/.name"
  echo "$bver" > "$req_dir/.version"
  echo "$parent" > "$req_dir/.parent"
  #? ---- /init ----

  breqPrintName $level "$pinfo/$bname"

  #? ---- cyclic depend ----
  if [[ -n $is_cyclic ]]; then # yep, cyclic dependecy
    local cyclic_bver=$(cat $cyclic_dir/.version | tr -d ' ')
    local cyclic_bspec="$bname/$cyclic_bver"
    # mark nodes
    echo "$bspec" > "$cyclic_dir/.cyclic"
    echo "$cyclic_bspec" > "$req_dir/.cyclic"
    breqPrintStatus $level "warn" "cyclic";
    retcode=0
    if [[ "$cyclic_bspec" != "$bspec" ]]; then # node of cycle may be with diff version req
      #* package may depend on other version, can we solve?
      local ver_rw
      if [[ -n "$cyclic_bver" && -n "$bver" ]]; then
        ver_rw=$(dverCompose "$(bspecVersionHR $cyclic_bspec)" "$(bspecVersionHR $bspec)")
        local ver_code="$?"
        # fixme: test samples
        testAddToVReqSamples "$(bspecVersionHR $cyclic_bspec)" "$(bspecVersionHR $bspec)" "$ver_rw" "$ver_code"
        if [[ "$ver_code" -gt 0 ]]; then #! cannot compose vreqs - giving up
          if [[ "$ver_code" -eq 2 ]]; then # todo: implement '> <' composition
            breqPrintStatus $level "warn" "ver:rw \"${cyclic_bver// /} U ${bver// /}\""' => !impl'
            echo "$bspec"
            return 0 #! not implemented must not be a caller problem
          else
            breqPrintStatus $level "err" "ver:rw \"${cyclic_bver// /} U ${bver// /}\""' => '"\"${ver_rw// /}\""
            echo "$bspec" # pass current package upstack
            return 0 # cyclic themselfs isn't failure
          fi
        fi
      else
        [[ -n "$cyclic_bver" ]] && ver_rw="$cyclic_bver" || ver_rw="$bver"
      fi
      breqPrintStatus $level "warn" "ver:add \"${ver_rw// /}\"";
    fi
    echo "$bspec" # pass current package upstack
    return 0 # cyclic themselfs isn't failure
  fi
  #? ---- /cyclic ----

  # todo: as follows broke full tree search - make variant of addNode for full tree traverse
  #? ---- seen_before ----
  local is_seen=$(breqSeenBefore "$bspec")
  if [[ -n $is_seen ]]; then
    #? add as endpoint for vreq checks
    # todo: do more clever realisation
    echo "$level $bspec" >> "$BREQ_DIR/$task/$BREQ_FLATTEN"
    breqPrintStatus $level "have" "$bname"
    echo "$retvalue"
    return 0
  fi
  #? ---- /seen ----

  #? ---- gathering depends ----
  local str=$(dockerAptCache "$bname")
  local dstr=$(breqPackString "$(sed -n 's/^Depends: \(.*\)$/\1/pg' <<< $str)")

  local da
  for line in ${dstr//"\n"/ }; do
    line=$(tr -cd '[:print:]' <<< "$line")
    da+=($line)
  done

  #* nodeps is ok - check for cyclic we done earlier
  if [[ ${#da[@]} -eq 0 ]]; then
    # fixme: possible bug
    if [[ "${bver:0:1}" == '>' || "${bver:0:1}" == '<' || "${bver:0:1}" == '=' ]]; then
      local new_vstr=$(breqPackString "$(sed -n 's/^Version: \(.*\)$/\1/pg' <<< $str)")
      unset newver_a; local newver_a
      for line in ${new_vstr//"\n"/ }; do
        line=$(tr -cd '[:print:]' <<< "$line")
        newver_a+=($line)
      done
      local new_vr=$(sed 's/\([><=]\+\)\([^ ]\+\)$/\1 \2/' <<< "$bver")
      for ((vidx=0; vids<${#newver_a[@]}; ++vids)); do
        [[ -n $(dverMatch "$new_vr" "${newver_a[$vidx]}") ]] && break
      done
      if [[ $vidx -ge ${#newver_a[@]} ]]; then
        breqPrintStatus $level "err" "!ver"
        echo "$bspec"
        return 1 #! nover
      fi
      bspec="$bname/${newver_a[$vidx]}"
      bver="${newver_a[$vidx]}"
    fi
    # fixme: ugly & boilerplate & possible bug
    #? ---- gathering provides ----
    local prov_str=$(breqPackString "$(sed -n 's/^Provides: \(.*\)$/\1/pg' <<< $str)")
    unset prov_a; local prov_a
    for line in ${prov_str//"\n"/ }; do
      line=$(tr -cd '[:print:]' <<< "$line")
      prov_a+=($line)
    done
    local provides="${prov_a[$idx]}"
    provides=$(breqParsePacked "${provides[@]}")
    provides=$(sed 's/\/=/\//g' <<< "$provides") # remove = from provides
    #? ---- /provides ----
    echo "$level $bname/$bver $provides" >> "$BREQ_DIR/$task/$BREQ_FLATTEN" # todo: cover with tests
    # fixme: not actualy needed
    echo "$provides" > "$req_dir/.provides" # save depend's provides
    breqPrintStatus $level "nodep"
    echo "$retvalue"  # don't mutate retvalue
    return 0
  fi
  #? ---- /depends ----

  #? ---- versions logic ----
  #* avaible versions
  local vstr=$(sed -n 's/^Version: \(.*\)$/\1/1p' <<< "$str")
  local va
  for line in ${vstr//"\n"/ }; do
    line=$(tr -cd '[:print:]' <<< $line)
    va+=($line)
  done

  #* which version is needed?
  local idx=0
  if [[ -n $bver ]] ; then
    # fixme: add propper parsing for: <!nocheck> [linux-any]
    if [[ $bver != '<!nocheck>' ]] && [[ $bver != '[linux-any]' ]]; then
      idx=$(breqWhichVersion "$bver" "${va[@]}")
      if [[ $? -gt 0 ]]; then
        breqPrintStatus $level "err" "!ver"
        #* general error - mutating retcode & retvalue to this dependency
        echo "$bspec" # pass current package upstack
        return 1 #! nover isn't good - lets caller decide
      fi
    fi
  fi
  local bdeps="${da[$idx]}" #* this is our set
  # update bspec, bver to selected version
  bver="${va[$idx]}"
  bspec="$bname/$bver"
  # fixme: not actualy needed
  echo "${bdeps[@]}" > "$req_dir/.satisfyers" # save depend's satisfyers
  #? ---- /versions ----

  #? ---- gathering provides ----
  local prov_str=$(breqPackString "$(sed -n 's/^Provides: \(.*\)$/\1/pg' <<< $str)")
  unset prov_a; local prov_a
  for line in ${prov_str//"\n"/ }; do
    line=$(tr -cd '[:print:]' <<< "$line")
    prov_a+=($line)
  done
  local provides="${prov_a[$idx]}"
  provides=$(breqParsePacked "${provides[@]}")
  provides=$(sed 's/\/=/\//g' <<< "$provides") # remove = from provides
  echo "$level $bspec $provides" >> "$BREQ_DIR/$task/$BREQ_FLATTEN" # todo: cover with tests
  # fixme: not actualy needed
  echo "$provides" > "$req_dir/.provides" # save depend's provides
  #? ---- /provides ----

  #? ---- dive in, praise the buddha ----
  for curset_packed in "${bdeps[@]}"; do
    pa+=("$bname")
    local curset=$(breqParsePacked $curset_packed)
    for bi in ${curset[@]} ; do
      echo -ne $(breqRepStr "$level" "\n" "\t" '-> ') >&2
      #* dive deeper
      retvalue=$(breqAddNode $level "$bi" "$retvalue" "${pa[@]}")
      local retcode="$?"
      [[ $retcode -gt 0 ]] && break;
    done
  done
  #? ---- surfaced, thank god good ----

  echo "$retvalue"
  return $retcode
}

# endregion