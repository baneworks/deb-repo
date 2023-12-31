#!/usr/bin/env bash
# @file task
# @brief Task library.

# fixme: refactor taskParseBR
# parse Build-Depends and return array: taskParseBR <br_string>
taskParseBR() {
  local str="$1"
  str=$(tr -cd '[:print:]' <<< $str)

  # fixme: alternate depends (x | y) not supported yet, installing both
  str=$(sed 's/ | bsdmainutils (<< 12\.1\.1~)//g' <<< $str) # fixme: hack
  str=$(sed 's/ | debconf-2.0//g' <<< $str) # fixme: hack
  str=$(sed 's/ |/,/g' <<< $str)

  str=${str//', '/'/'}
  str=${str//' '/'&'}
  str=$(sed 's/^\&//g' <<< "$str")
  str=$(sed 's/\&$//g' <<< "$str")
  str=$(sed 's/\([>=]\)\&/\1/g' <<< "$str")             #? like (>= 10.1)
  str=$(sed 's/>>/>/g' <<< "$str")                      #? convert things like (>> 10.1) (> 10.1)
  str=$(sed 's/<<&/</g' <<< "$str")                     #? convert things like (<< 10.1) (< 10.1)
  str=$(sed 's/\&\(\[.*\]\)/\&(\1)/g' <<< "$str")       #? like [linux-any]
  str=$(sed 's/\&\(<!nocheck>\)/\&(\1)/g' <<< "$str")   #? like <!no-check>
  str=$(sed 's/\(:any\/\)/\//g' <<< "$str")             #? like :any

  local bspecs
  for s in ${str//'/'/ }; do
    local n=$(sed 's/\(.*\)\s(\(.*\))/\1/g' <<<${s//'&'/ })
    local v=$(sed -n 's/\(.*\)\s(\(.*\))/\2/gp' <<<${s//'&'/ })
    bspecs+=("$n/$v")
  done

  echo "${bspecs[*]}"
}

# @description Function to parse task dcs and return breqs array.
#
# @example
#    $(taskReqs <task>)"
#
# @arg `task` a build task
taskReqs() {
  local task="$1"

  local dsc=$(bkendLs "$(tagValue dsrc)/$task" '*.dsc')
  [ $(echo $dsc | wc -l) -eq 1 ] || error 1 task "messed up with DSC file [$task]"

  local bspecs=($(taskParseBR "$(cat $dsc | sed -n 's/Build-Depends:\(.*\)/\1/p')"))
  bspecs+=($(taskParseBR "$(cat $dsc | sed -n 's/Build-Depends-Indep:\(.*\)/\1/p')"))

  for ((i=0; i<${#bspecs[@]}; ++i)); do
    #? ---- virtual ----
    local name=$(bspecName "${bspecs[$i]}")
    local ver=$(bspecVersionHR "${bspecs[$i]}")
    local str=$(dockerAptCache "$name")
    if [[ "$str" == "virtual" ]]; then
      local pva=($(dockerAptVirtualProviders "$name"))
      for ((j=0; j<${#pva[@]}; ++j)); do
        local pfields=(${pva[$j]//'&'/ })
        local virt_vrq=$(sed 's/[()]//g' <<< "${pfields[2]} ${pfields[3]}")
        local virt_ver="${pfields[1]}"
        local virt_name="${pfields[0]}"
        [[ "$ver" == "$virt_vrq" ]] && break
      done
      if [[ $j -gt ${#pva[@]} ]]; then
        breqPrintStatus 0 "err" "!prov"
        echo "$bspec" # pass current package upstack
        return 1 #! no providers for virtual isn't good - lets caller decide
      fi
      bspecs[$i]="$virt_name/$virt_ver"
    fi
    #? ---- /virtual ----
  done

  echo "${bspecs[*]}"
}

# endregion

# region #! depends finalisation

# fixme: ugly as hell and just as slow
# todo: cover with tests
# @description Function to summarize all of version constrains.
#
#*  Package entries (i.e. endnode of graph) can be in few forms:
#     1. like 'libc6/2.31-13+deb11u5' - this is definetly a end node
#        with version specification
#     2. like 'libc6/2.31-13+deb11u5 <provides>' - also a end node,
#        with version specification and 'provides' list
#     3. like 'libc6/' - a end node or package reqirenments
#     4. like 'libc6/ <provides>' - a end node or package reqirenments
#*  To change end nodes in forms 1, 2:
#*  a. check version compatibility and leave as is if fit
#*  b. if not - call wichVersion find suitable and replace
#
#? The 3rd form can be replaced to vreq without any consequences
#
#! The 4th form looks discouraging and definitely cannot be replaced
#! by vreq. I think you can do the same for cases of forms 1,2, but
#! I'm not sure. So, for now, consider as a bug
#
# @example
#    $(taskSumVReq <task> <in> <out>)
#
# @arg `task` a build task.
# @arg in a name `flatten` file to read from
# @arg out a name of result file
#
# @exitcode 0 on success
# @exitcode 1 on failure
# @exitcode 2 success with issues
#
# @see [Vreq rewrite](./README.md#version-requrinments)
taskSumVreq() {
  local task="$1"
  local flatten="$2"
  local flatten_rw="$3"
  local regexp='s/^\([0-9]\+\)\s\([^ ]\+\)\s\?\(.*\)$'
  local comment_rg='s/^\(#.*\)$'
  local skip
  local rc=0

  mapfile -t lines < "$flatten"
  for ((i=0; i<${#lines[@]}; ++i)); do #? i for lines
    local comment_line=$(sed -n "$comment_rg/\1/p" <<< "$line")
    [[ -n $comment_line ]] && echo "$comment_line" >> "$flatten_rw"

    unset src_bspec src_bname src_bver
    unset dst_bspec dst_bname dst_bver
    unset enodes vreqs rw_bver pnode_bver
    unset node_level node_bspec node_bname node_bver node_provides

    [[ " ${skip[*]} " == *" $i "* ]] && continue #? skipping already processed lines

    local src_bspec=$(echo "${lines[$i]}" | sed -n "$regexp/\2/p")
    local src_bname=$(bspecName "$src_bspec")

    # todo: narrow flatten during processing for speedup
    local match=($(cat "$flatten" | grep -n '^[0-9]\+\s'"$src_bname"'\/\s\?.*$' | sed -n 's/^\([0-9]\+\):.*$/\1/p'))
    [[ ${#match[@]} -eq 1 ]] && continue

    #? splitting vreqs and epoints
    local enodes vreqs
    for ((j=0; j<${#match[@]}; ++j)); do
      local li=$(( ${match[$j]} - 1))

      local src_bspec=$(echo "${lines[$li]}" | sed -n "$regexp/\2/p")
      local src_bname=$(bspecName "$src_bspec")
      local src_bver=$(bspecVersionHR "$src_bspec")

      if [[ -n $(dverIsVReq "$src_bver") ]]; then
        vreqs+=($li)
      else
        enodes+=($li)
      fi
    done

    #? vreqs
    if [[ ${#vreqs[@]} -gt 0 ]]; then

      local src_bspec=$(echo "${lines[${vreqs[0]}]}" | sed -n "$regexp/\2/p")
      local src_bname=$(bspecName "$src_bspec")
      local src_bver=$(bspecVersionHR "$src_bspec")

      local rw_bver=$(bspecVersionHR "${vreqs[0]}")

      # todo: with j=0 we have 1-useles run of loop
      for ((j=0; j<${#vreqs[@]}; ++j)); do
        local li=${vreqs[$j]}
        local dst_bspec=$(echo ${lines[$li]} | sed -n "$regexp/\2/p")
        local dst_bname=$(bspecName "$dst_bspec")
        local dst_bver=$(bspecVersionHR "$dst_bspec")
        local dst_level=$(echo ${lines[$li]} | sed -n "$regexp/\1/p")
        local dst_provides=$(echo ${lines[$li]} | sed -n "$regexp/\3/p")

        if [[ -n "$dst_provides" ]]; then #! vreq looks strange 'libc6/>=2.14 libc6-2.25'
          logTask "$task" "vreq contains provides at line $(( $li + 1 )) '${lines[$li]:0:18}...'"
          error 1 task "vreq contains provides at line $(( $li + 1 )) '${lines[$li]:0:18}...'"
          return 1
        fi

        #? after loop rw_bver will contains final vreq (rw_line - whole line)
        if [[ -n "$dst_bver" ]]; then
          [[ -z "$rw_bver" ]] && rw_bver="$dst_bver"

          # fixme: fix dverCompose arg order
          rw_bver=$(dverCompose "$dst_bver" "$rw_bver")
          local errc="$?"

          if [[ $errc -gt 0 ]] || [[ -z "$rw_bver" ]]; then #! empty vreq is also bad
            if [[ $errc -eq 2 ]]; then #! not implemented is not a caller problem
              logTask "$task" "not implemented compose with ${dst_bver:0:12}... with ${rw_bver:0:12}... at line $(( $li + 1 ))"
              rc=2
            else
              logTask "$task" "fails to compose with $dst_bver at line $(( $li + 1 )) '${lines[$li]:0:18}...'"
              error 1 task "fails to compose with $dst_bver at line $(( $li + 1 )) '${lines[$li]:0:18}...'"
              return 1
            fi
          fi
        fi

      done

      #? replacing vreqs
      for ((j=0; j<${#vreqs[@]}; ++j)); do
        local li=${vreqs[$j]}
        local dst_level=$(echo ${lines[$li]} | sed -n "$regexp/\1/p") # preserve level
        lines[$li]="$dst_level $dst_bname/${rw_bver// /}"
      done

    fi #? /vreqs

    #? walk thru epoins
    if [[ -n "$rw_bver" ]]; then # some vreqs to rewrite
      local pnode_bver
      for ((j=0; j<${#enodes[@]}; ++j)); do
        local li=${enodes[$j]}

        local node_level=$(echo "${lines[$li]}" | sed -n "$regexp/\1/p")
        local node_bspec=$(echo "${lines[$li]}" | sed -n "$regexp/\2/p")
        local node_bname=$(bspecName "$node_bspec")
        local node_bver=$(bspecVersion "$node_bspec")
        local node_provides=$(echo ${lines[$li]} | sed -n "$regexp/\3/p")

        if [[ -n "$node_bver"  ]]; then
          if [[ -z $(dverMatch "$rw_bver" "$node_bver") ]]; then
            logTask "$task" "end point not matched $rw_bver at line $(( $li + 1 )) '${lines[$li]:0:18}...'"
            error 1 task "end point not matched $rw_bver at line $(( $li + 1 )) '${lines[$li]:0:18}...'"
            return 1
          fi
          if [[ -n "$pnode_bver" ]] && [[ -z $(dverCmp "$pnode_bver" "$node_bver") ]]; then
            logTask "$task" "mess in end point versions at line $(( $li + 1 )) '${lines[$li]:0:18}...'"
            error 1 task "mess in end point versions at line $(( $li + 1 )) '${lines[$li]:0:18}...'"
            return 1
          fi
          [[ -z "$pnode_bver" ]] && pnode_bver="$node_bver"
        fi

        lines[$li]="$node_level $node_bspec $node_provides"
      done
    fi #? /enodes

    skip+=(${enodes[@]})
    skip+=(${vreqs[@]})

  done #? i-for

  #? ---- fixatig changes ----
  [[ -f "$flatten_rw" ]] && rm -f "$flatten_rw" && touch "$flatten_rw"
  for line in "${lines[@]}"; do
    echo "$line" >> "$flatten_rw"
  done

  return $rc
}

# @description Function to contruct package chain.
#
# @example
#    $(taskMakeChain <bname> <prev level> <level> <array>)
#
# @arg `bname` a package name to add
# @arg `prev level` a previous level of chain
# @arg `level` a current level of chain
# @arg `array` a cain to add package to
#
# @stdout package chain array
#
# @internal
taskMakeChain() {
  local bn="$1" prev="$2" lvl="$3"
  shift; shift; shift
  local chain=("$@")

  if [[ $lvl -gt $prev ]]; then
    chain+=($bn)
  elif [[ $lvl -eq $prev ]]; then
    chain[-1]=$bn
  else
    if [[ $lvl -ge 1 ]]; then
      chain=(${chain[@]:0:$(( $lvl - 1 ))})
      chain+=($bn)
    else
      chain=($bn)
    fi
  fi
  echo "${chain[@]}"
}

# fixme: slooow
# todo: remode j-for on all lines to lines just matche provider
# @description Function to unalias virtual packages to its providers.
#   Actually we need to remove already statisfied alias and preserve
#   unsatisfied virtuals.
#
# @example
#    $(taskSumVReq <task> <in> <out>)
#
# @arg `task` a build task.
# @arg in a name `flatten` file to read from
# @arg out a name of result file
#
# @exitcode 0 on success
# @exitcode 1 on failure
#
# @see [Vreq rewrite](./README.md#version-requrinments)
taskUnalias() {
  local task="$1"
  local pkgs_in="$2"
  local pkgs_out="$3"
  local regexp='s/^\([0-9]\+\)\s\([^ ]\+\)\s\?\(.*\)$'
  local comment_rg='s/^\(#.*\)$'
  local skip

  mapfile -t lines < "$pkgs_in"

  local skip
  for ((i=0; i<${#lines[@]}; ++i)); do #? i-lines
    [[ " ${skip[*]} " == *" $i "* ]] && continue

    local comment_line=$(sed -n 's/^\(#.*\)$/\1/p' <<< ${lines[$i]})
    if [[ -n "$comment_line" ]]; then
      skip+=($i)
      continue
    fi

    local i_level=$(echo "${lines[$i]}" | sed -n "$regexp/\1/p")
    local i_bspec=$(echo "${lines[$i]}" | sed -n "$regexp/\2/p")
    local i_provides=$(echo "${lines[$i]}" | sed -n "$regexp/\3/p")

    [[ -z "$i_provides" ]] && continue
    skip+=($i) # provider entry point found - no need to substitute in future

    for p_bspec in ${i_provides[@]}; do #? provides
      local p_bname=$(bspecName "$p_bspec")
      local match=($(cat "$pkgs_in" | grep -n '^[0-9]\+\s'"$p_bname"'\/\s\?.*$' | sed -n 's/^\([0-9]\+\):.*$/\1/p'))

      for ln in ${match[@]}; do
        local j=$(( $ln - 1 ))
        [[ $i -eq $j || " ${skip[*]} " == *" $j "* ]] && continue

        lines[$j]="# virtual: ${lines[$j]}"
        skip+=($j)
      done

    done #? /provides

    skip+=($i)

  done #? /i-lines

  for ((i=0; i<${#lines[@]}; ++i)); do #? i-lines
    echo "${lines[$i]}" >> "$pkgs_out"
  done

  return 0
}

# fixme: slooow
# todo: cover with tests
# @description Function to finalize all depends to flat list.
#   Parses `.flatten`, unspin cycles and return ready to install
#   packages list with suitable version specification.
#
# @example
#    $(taskFinalDepends <task> <in> <out>)
#
# @arg `task` a build task.
# @arg in a name `flatten` file to read from
# @arg out a name of result file
#
# @exitcode 0 on success
# @exitcode 1 on failure
#
# @see [depends parsing](./README.md#-depends-parsing)
taskFinalDepends() {
  local task="$1"
  local pkgs_in="$2"
  local pkgs_out="$3"

  local regexp='s/^\([0-9]\+\)\s\([^ ]\+\)\s\?\(.*\)$'

  local chain prev_chain

  local pkg_bnames pkg_bspecs
  local cpkg_bnames cpkg_bspecs

  local chain_dir prev_cdir
  local prev_bname
  local p_level=0 pp_level=0

  readarray -t lines < "$pkgs_in"

  for ((i=0; i<"${#lines[@]}"; ++i)); do #? main for

    local li=$(( $i + 1 ))
    local level=$(echo "${lines[$i]}" | sed -n "$regexp/\1/p")
    local bspec=$(echo "${lines[$i]}" | sed -n "$regexp/\2/p")
    local provides=$(echo "${lines[$i]}" | sed -n "$regexp/\3/p")
    local bname=$(bspecName "$bspec")

    #? skipping if already added
    if [[ " ${pkg_bnames[*]} " == *" $bname "* || " ${cpkg_bnames[*]} " == *" $bname "* ]]; then

      chain=($(taskMakeChain "$bname" "$p_level" "$level" ${chain[@]}))

      chain_dir="${chain[*]}"
      chain_dir=${chain_dir// /'/'}

      p_level="$level"

      # todo: find better way to inform
      # echo -ne "\t$COLOR_GRAY" >&2
      # [[ $li -lt 10 ]] && echo -n " " >&2
      # [[ $li -lt 100 ]] && echo -n " " >&2
      # echo -e "$li $chain_dir$COLOR_OFF" >&2

      continue
    fi

    chain=($(taskMakeChain "$bname" "$p_level" "$level" ${chain[@]}))

    chain_dir="${chain[*]}"
    chain_dir=${chain_dir// /'/'}

    #? --- cyclic ---
    if [[ -f "$BREQ_DIR/$task/$chain_dir/.cyclic" ]]; then
      pp_level="$p_level"

      prev_cdir="$chain_dir"
      prev_chain=("${chain[@]}")

      local cycle_bnames=($bname)
      local cycle_bspecs=($bspec)

      echo "# cycle" >> "$pkgs_out"
      echo "$li $bspec $provides" >> "$pkgs_out"

      # todo: find better way to inform
      # echo -ne "\t$COLOR_YELLOW" >&2
      # [[ $li -lt 10 ]] && echo -n " " >&2
      # [[ $li -lt 100 ]] && echo -n " " >&2
      # echo -e "$li $bname$COLOR_OFF" >&2

      cpkg_bnames+=("$bname")
      cpkg_bspecs+=("$bspec")

      local j=0 in_cycle="true"
      while [[ -n $in_cycle ]]; do
        local c_li=$(( $i + $j + 1 ))
        local c_level=$(echo "${lines[$c_li]}" | sed -n "$regexp/\1/p")
        local c_bspec=$(echo "${lines[$c_li]}" | sed -n "$regexp/\2/p")
        local c_provides=$(echo "${lines[$c_li]}" | sed -n "$regexp/\3/p")
        local c_bname=$(bspecName "$c_bspec")

        [[ $level -ge $c_level || $j -ge $CYC_MAX_DEPTH ]] && break

        # todo: what if case package already in cycle
        cycle_bnames+=("$c_bname")
        cycle_bspecs+=("$c_bspec")
        cpkg_bnames+=("$c_bname")
        cpkg_bspecs+=("$c_bspec")

        echo "$c_li $c_bspec $c_provides" >> "$pkgs_out"

        # todo: find better way to inform
        # echo -ne "\t$COLOR_YELLOW" >&2
        # [[ $c_li -lt 10 ]] && echo -n " " >&2
        # [[ $c_li -lt 100 ]] && echo -n " " >&2
        # echo -e "$c_li $c_bname$COLOR_OFF" >&2

        j=$(( $j + 1 ))

      done
      unset in_cycle

      if [[ $j -ge $CYC_MAX_DEPTH ]]; then
        error 1 FDEPS "depth of cicle reached limit"
        retutn 1
      else
        # todo: find better way to inform
        # echo -ne "\t$COLOR_YELLOW" >&2
        # [[ $c_li -lt 10 ]] && echo -n " " >&2
        # [[ $c_li -lt 100 ]] && echo -n " " >&2
        # echo -e "$(( $i + $j + 1)) $bname$COLOR_OFF" >&2

        i=$(( $i + $j ))
        p_level="$pp_level"

        chain_dir="$prev_cdir"
        chain=("${prev_chain[@]}")

        chain=($(taskMakeChain "$prev_bname" "$pp_level" "$c_level" ${chain[@]}))
        chain_dir="${chain[*]}"
        chain_dir=${chain_dir// /'/'}

        # echo "$li-$c_li ${cycle_bspecs[@]}" >> "$pkgs_out"
        echo "# /cycle" >> "$pkgs_out"

        continue
      fi

    fi #? --- /cyclic ---

    pkg_bnames+=($bname)
    p_level="$level"

    echo "$li $bspec $provides" >> "$pkgs_out"

    # todo: find better way to inform
    # echo -ne "\t" >&2
    # [[ $li -lt 10 ]] && echo -n " " >&2
    # [[ $li -lt 100 ]] && echo -n " " >&2
    # echo "$li $chain_dir" >&2

  done #? /main

  return 0
}

# fixme: slooow
# todo: this can be done in one pass with look-ahead regexp
# @description Function to do some cleanup on depends.
#
# @example
#    $(taskClearDepends <task> <in> <out>)
#
# @arg `task` a build task.
# @arg in a name `flatten` file to read from
# @arg out a name of result file
#
# @exitcode 0 on success
# @exitcode 1 on failure
taskClearDepends() {
  local task="$1"
  local pkgs_in="$2"
  local pkgs_out="$3"
  local regexp='s/^\([0-9]\+\)\s\([^ ]\+\)\s\?\(.*\)$'
  local comment_rg='s/^#.*$//'

  mapfile -t lines < "$pkgs_in"

  #? collecting enodes & vreqs
  local en_specs en_names
  local vr_specs vr_names
  local skip
  for ((i=0; i<${#lines[@]}; ++i)); do
    # comments
    local comment_line=$(sed -n 's/^\(#.*\)$/\1/p' <<< ${lines[$i]})
    if [[ -n "$comment_line" ]]; then
      echo "$comment_line" >> "$pkgs_out"
      skip+=($i)
      continue
    fi

    [[ " ${skip[*]} " == *" $i "* ]] && continue

    local i_level=$(echo "${lines[$i]}" | sed -n "$regexp/\1/p")
    local i_bspec=$(echo "${lines[$i]}" | sed -n "$regexp/\2/p")
    # local i_provides=$(echo "${lines[$i]}" | sed -n "$regexp/\3/p")
    local i_bname=$(bspecName "$i_bspec")
    local i_bver=$(bspecVersionHR "$i_bspec")

    local search_fspec="true"
    for ((j=0; j<${#lines[@]}; ++j)); do #? j
      [[ " ${skip[*]} " == *" $j "* ]] && continue

      local j_bspec=$(echo "${lines[$j]}" | sed -n "$regexp/\2/p")
      local j_bname=$(bspecName "$j_bspec")

      [[ "$j_bname" != "$i_bname" ]] && continue

      if [[ -n $search_fspec ]]; then
        local full_spec=""
        for ((k=0; k<${#lines[@]}; ++k)); do #? k
          [[ " ${skip[*]} " == *" $k "* ]] && continue
          local k_bspec=$(echo "${lines[$k]}" | sed -n "$regexp/\2/p")
          local k_bname=$(bspecName "$k_bspec")
          if [[ "$k_bname" == "$j_bname" ]]; then
            if [[ -n "$k_bname" ]]; then
              if [[ -z "$full_spec" ]]; then
                full_spec="$k_bspec"
                unset search_fspec
                break
              fi
            fi
          fi
        done
        [[ -z "$full_spec" || $k -ge ${#lines[@]} ]] && return 1
      fi

      local j_bver=$(bspecVersionHR "$j_bspec")

      lines[$j]="$full_spec"
      skip+=($j)

    done #? j

    echo "$i_level $full_spec">> "$pkgs_out"
    skip+=($i)

  done

  return 0
}

# todo: rewrite vreqs to version
# @description Function to generate .
#
# @example
#    $(taskFilterInstalled <task> <in> <out>)
#
# @arg `task` a build task.
# @arg in a file to read from
# @arg out a name of result file
#
# @exitcode 0 on success
# @exitcode 1 on failure
taskFilterInstalled() {
  local task="$1"
  local pkgs_in="$2"
  local pkgs_out="$3"
  local regexp='s/^\([0-9]\+\)\s\([^ ]\+\)\s\?\(.*\)$'
  local comment_rg='s/^#.*$//'

  mapfile -t lines < "$pkgs_in"

  #? collecting enodes & vreqs
  for ((i=0; i<${#lines[@]}; ++i)); do

    local comment_line=$(sed -n 's/^\(#.*\)$/\1/p' <<< ${lines[$i]})
    if [[ -n "$comment_line" ]]; then
      echo "$comment_line" >> "$pkgs_out"
      continue
    fi

    local level=$(echo "${lines[$i]}" | sed -n "$regexp/\1/p")
    local bspec=$(echo "${lines[$i]}" | sed -n "$regexp/\2/p")
    local bname=$(bspecName "$bspec")
    local bver=$(bspecVersion $bspec) # fixme: bspecVersion + bspecVersionHR convert to one

    # fixme: a hack
    if [[ "${bver:0:1}" == '=' ]]; then
      bver="${bver:1}"
    elif [[ "${bver:0:1}" == '<' || "${bver:0:1}" == '>' ]]; then
      bver=$(bspecVersionHR $bspec)
    fi

    log=$(dockerDpkgStatus "$bname")
    if [[ $? -eq 0 ]]; then #? installed
      local vstr=$(sed -n 's/Version:\s\?\(.*\)$/\1/p' <<< $log)
      vstr=$(tr -cd '[:print:]' <<< "$vstr")
      local vreq="$bver"
      [[ -z $(dverIsVReq "$bver") ]] && vreq=">= $bver"
      [[ -z $(dverMatch "$vreq" "$vstr") ]] && return 1 # version mismatch
      echo "# installed: ${lines[$i]}" >> "$pkgs_out"
      continue
    elif [[ -z $bver || "${bver:0:1}" == '>' || "${bver:0:1}" == '<' ]]; then #? 'libc6/>= 2.14' => check avail version and => 'libc6'
      # avaible versions
      local vstr="$(dockerAptCache "$bname")"
      [[ $? -gt 0 ]] && return 1
      local vstr=$(sed -n 's/^Version: \(.*\)$/\1/1p' <<< "$vstr")
      unset va; local va
      for sl in ${vstr//"\n"/ }; do
        sl=$(tr -cd '[:print:]' <<< "$sl")
        va+=("$sl")
      done
      if [[ -z $bver ]]; then #? first availible ver
        bver="${va[0]}" # newer matched version
      else
        # which version is needed?
        local idx=$(breqWhichVersion "$bver" "${va[@]}")
        [[ $? -gt 0 ]] && return 1 #! no suitable version
        bver="${va[$idx]}" # newer matched version
      fi
    fi

    echo "$level $bname/$bver" >> "$pkgs_out"

  done

  return 0
}

# @description Function to generate install list.
#
# @example
#    $(taskMkInstall <task> <in> <out>)
#
# @arg `task` a build task.
# @arg in a file to read from
# @arg out a name of result file
#
# @exitcode 0 on success
# @exitcode 1 on failure
taskMkInstall() {
  local task="$1"
  local pkgs_in="$2"
  local pkgs_out="$3"

  local regexp='s/^\([0-9]\+\)\s\([^ ]\+\)\s\?\(.*\)$'
  local comment_rg='s/^#.*$//'
  local cstart_rg='s/^\(# cycle\)$/\1/p'
  local cend_rg='s/^\(# \/cycle\)$/\1/p'

  mapfile -t lines < "$pkgs_in"

  for ((i=0; i<${#lines[@]}; ++i)); do
    local bspec
    if [[ -n $(sed -n "$comment_rg" <<< ${lines[$i]}) ]] &&
       [[ -z $(sed -n "$cstart_rg" <<< ${lines[$i]}) ]] &&
       [[ -z $(sed -n "$cend_rg" <<< ${lines[$i]}) ]]
    then
      continue
    else
      bspec=$(echo "${lines[$i]}" | sed -n "$regexp/\2/p")
      # echo "$(( $i + 1 )) bs=$bspec" >&2
    fi

    if [[ -n $(sed -n "$cstart_rg" <<< ${lines[$i]}) ]]; then
      local cycle in_cycle="true"
      while [[ -n $in_cycle ]]; do
        i=$(( $i + 1 ))
        [[ -n $(sed -n "$cstart_rg" <<< ${lines[$i]}) || $i -gt ${#lines[@]} ]] && return 1
        if [[ -n $(sed -n "$cend_rg" <<< ${lines[$i]}) ]]; then
          unset in_cycle
          break
        elif [[ -z $(sed -n "$comment_rg" <<< ${lines[$i]}) ]]; then
          bspec=$(echo "${lines[$i]}" | sed -n "$regexp/\2/p")
          [[ -n "$bspec" ]] && cycle+=("$bspec")
        fi
      done
      [[ ${#cycle[@]} -gt 0 ]] && echo "${cycle[@]}" >> "$pkgs_out"
    fi

    [[ -n "$bspec" ]] && echo "$bspec" >> "$pkgs_out"

  done

  return 0
}

# @description Function to generate download script.
#
# @example
#    $(taskDload <task> <in> <out>)
#
# @arg `task` a build task.
# @arg in a file to read from
# @arg out a name of result file (without task name)
#
# @exitcode 0 on success
# @exitcode 1 on failure
taskDload() {
  local task="$1"
  local pkgs_in="$2"
  local pkgs_out="$3"
  local shebang="#!/usr/bin/env bash\n"
  local cmd_start="res=\`"
  local cmd_end="\`"
  local mid='[[ $? -gt 0 ]] && echo "$res" && exit 1'
  local end="\nexit 0"
  echo -e "$shebang" >> "$pkgs_out"
  mapfile -t lines < "$pkgs_in"
  for ((i=0; i<${#lines[@]}; ++i)); do
    local pa=(${lines[$i]})
    if [[ ${#pa[@]} -gt 1 ]]; then #? cycle
      echo -e "# cycle\n" >> "$pkgs_out"
      for ((j=0; j<${#pa[@]}; ++j)); do
        local bname=(${pa[$j]//'/'/ })
        local bver="${bname[1]}"
        bname="${bname[0]}"
        if [[ -z "$bver" ]]; then
          echo "apt-get download \"$bname\"" >> "$pkgs_out"
        else
          echo "apt-get download \"$bname=$bver\"" >> "$pkgs_out"
        fi
        echo "$mid" >> "$pkgs_out"
        echo "" >> "$pkgs_out"
      done
      echo -e "# /cycle\n" >> "$pkgs_out"
    else #? pkg
      local bname=(${pa[0]//'/'/ })
      local bver="${bname[1]}"
      bname="${bname[0]}"
      if [[ -z "$bver" ]]; then
        echo "${cmd_start}apt-get download \"$bname\"${cmd_end}" >> "$pkgs_out"
      else
        echo "${cmd_start}apt-get download \"$bname=$bver\"${cmd_end}" >> "$pkgs_out"
      fi
      echo "$mid" >> "$pkgs_out"
      echo "" >> "$pkgs_out"
    fi
  done
  echo -e "$end" >> "$pkgs_out"

  local res
  local script=(${pkgs_out//'/'/ })
  script="${script[-1]}"

  # #? copy script
  # res=$(dockerMakeDir "$(tagValue sh)/${task}/")
  # [[ $? -gt 0 ]] && echo "$res" && return 1
  # res=$(dockerMakeDir "$(tagValue dbin)/${task}/")
  # [[ $? -gt 0 ]] && echo "$res" && return 1
  # res=$(dockerCopy "sh" "$task" "$pkgs_out")
  # [[ $? -gt 0 ]] && echo "$res" && return 1

  # #? executing script
  # res=$(dockerDirExec "$(tagValue dbin)/$task" "sh ../../$(tagValue sh)/$task/$script")
  # [[ $? -gt 0 ]] && echo "$res" && return 1

  return 0
}

# @description Function to generate install script.
#
# @example
#    $(taskDebInstall <task> <in> <install> <uninstall>)
#
# @arg `task` a build task.
# @arg `in` a package list file.
# @arg `install` a name of install script
# @arg `uninstall` a name of uninstall script
#
# @exitcode 0 on success
# @exitcode 1 on failure
taskDebInstall() {
  local task="$1"
  local pkgs_in="$2"
  local ish_out="$3"
  local ush_out="$4"
  local lsh_out="$5"

  local shebang="#!/usr/bin/env bash\n"

  local icmd_start="res=\`"
  local icmd_end="\`"
  local imid='[[ $? -gt 0 ]] && echo "$res" && exit 1'
  local iend="\nexit 0"

  local ucmd_start="res=\`"
  local ucmd_end="\`"
  local umid='[[ $? -gt 0 ]] && echo "$res" && exit 1'
  local uend="\nexit 0"

  local lcmd_start="file=\`"
  local lcmd_end="\`"
  local lmid='[[ -f "\$file" ]] || echo "\$file" && exit 1'
  local lend="\nexit 0"

  echo -e "$shebang" >> "$ish_out"
  echo -e "$shebang" >> "$ush_out"
  echo -e "$shebang" >> "$lsh_out"

  echo -n "${icmd_start}dpkg -i " >> "$ish_out"
  echo -n "${ucmd_start}dpkg --purge " >> "$ush_out"

  mapfile -t lines < "$pkgs_in"
  for ((i=0; i<${#lines[@]}; ++i)); do
    local pa=(${lines[$i]})
    if [[ ${#pa[@]} -gt 1 ]]; then #? cycle
      # echo "# cycle" >> "$ish_out"
      # echo "# cycle" >> "$ush_out"
      echo "# cycle" >> "$lsh_out"
      # echo -n "${icmd_start}dpkg -i " >> "$ish_out"
      # echo -n "${ucmd_start}dpkg --purge " >> "$ush_out"
      echo -n "${lcmd_start}" >> "$lsh_out"
      for ((j=0; j<${#pa[@]}; ++j)); do
        local fname=$(bspecFile ${pa[$j]})
        local bname=$(bspecName ${pa[$j]})
        [[ -z $fname || $? -gt 0 ]] && return 1
        echo -n " ${fname}" >> "$ish_out"
        echo -n " ${bname}" >> "$ush_out"
        echo -n "${fname}" >> "$lsh_out"
        [[ $j -lt $(( ${#pa[@]} - 1 )) ]] && echo -n " " >> "$ish_out"
        [[ $j -lt $(( ${#pa[@]} - 1 )) ]] && echo -n " " >> "$ush_out"
        [[ $j -lt $(( ${#pa[@]} - 1 )) ]] && echo -n " " >> "$lsh_out"
      done
      echo " \\" >> "$ish_out"
      echo " \\" >> "$ush_out"
      echo "${lcmd_end}" >> "$lsh_out"
      # echo "${imid}" >> "$ish_out"
      # echo "${umid}" >> "$ush_out"
      echo "${lmid}" >> "$lsh_out"
      # echo "# /cycle" >> "$ish_out"
      # echo "# /cycle" >> "$ush_out"
      echo "# /cycle" >> "$lsh_out"
    else #? pkg
      local fname=$(bspecFile ${pa[0]})
      local bname=$(bspecName ${pa[0]})
      [[ -z $fname || $? -gt 0 ]] && return 1
      # echo "${icmd_start}dpkg -i ${fname}${icmd_end}" >> "$ish_out"
      # echo "${ucmd_start}dpkg --purge ${bname}${ucmd_end}" >> "$ush_out"
      echo -n "${fname}" >> "$ish_out"
      echo -n "${bname}" >> "$ush_out"
      [[ $i -lt $(( ${#lines[@]} - 1 )) ]] && echo " \\" >> "$ish_out"
      [[ $i -lt $(( ${#lines[@]} - 1 )) ]] && echo " \\" >> "$ush_out"
      echo "${lcmd_start}${fname}${ucmd_end}" >> "$lsh_out"
      # echo "${imid}" >> "$ish_out"
      # echo "${umid}" >> "$ush_out"
      echo "${lmid}" >> "$lsh_out"
    fi
  done
  echo "${icmd_end}" >> "$ish_out"
  echo "${ucmd_end}" >> "$ush_out"

  echo "${imid}" >> "$ish_out"
  echo "${umid}" >> "$ush_out"

  echo -e "$iend" >> "$ish_out"
  echo -e "$uend" >> "$ush_out"
  echo -e "$lend" >> "$lsh_out"

  local res
  local iscript=(${ish_out//'/'/ }); iscript="${iscript[-1]}"
  local uscript=(${ush_out//'/'/ }); uscript="${uscript[-1]}"
  local lscript=(${lsh_out//'/'/ }); lscript="${lscript[-1]}"

  # # #? copy scripts
  # res=$(dockerCopy "sh" "$task" "$ish_out")
  # [[ $? -gt 0 ]] && echo "$res" && return 1
  # res=$(dockerCopy "sh" "$task" "$ush_out")
  # [[ $? -gt 0 ]] && echo "$res" && return 1
  # res=$(dockerCopy "sh" "$task" "$lsh_out")
  # [[ $? -gt 0 ]] && echo "$res" && return 1

  # #? executing script
  # checks downloaded files
  # res=$(dockerDirExec "$(tagValue dbin)/$task" "sh ../../$(tagValue sh)/$task/$lscript")
  # [[ $? -gt 0 ]] && echo "$res" && return 1
  # install packages
  # res=$(dockerDirExec "$(tagValue dbin)/$task" "sh ../../$(tagValue sh)/$task/$iscript")
  # [[ $? -gt 0 ]] && echo "$res" && return 1

  return 0
}

# endregion