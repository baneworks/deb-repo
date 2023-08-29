#!/usr/bin/env bash

. ./bin/log-lib
. ./bin/task-lib
. ./bin/bspec-lib
. ./bin/debver-lib

dverIsVReq() {
  local str="$1"
  # echo "${str:0:1}" >&2
  local res
  [[ "${str:0:1}" == '=' ]] && res="true"
  [[ "${str:0:1}" == '>' ]] && res="true"
  [[ "${str:0:1}" == '<' ]] && res="true"
  echo "$res"
}

# fixme: ugly as hell and just as slow
# summarize all of version constrains: breqVreqSum <task>
# return 0 - success
# return 1 - fail
taskSumVReq() {
  local task="$1"

  info $task "versions ..."

  local regexp='s/^\([0-9]\+\)\s\([^ ]\+\)\s\?\(.*\)$'

  local flatten="./.build-reqs/$task/$BREQ_FLATTEN"
  local flatten_new="./.build-reqs/$task/${BREQ_FLATTEN}-new"

  mapfile -t lines < $flatten

  for ((i=0; i<${#lines[@]}; ++i)); do #? i-for

    local -a match_backwards # store vreq lines that suppose to be changed
    local -a enode_backwards # store end nodes lines that suppose to be changed

    local src_bspec=$(echo "${lines[$i]}" | sed -n "$regexp/\2/p")
    local src_bname=$(bspecName "$src_bspec")
    local src_bver=$(bspecVersionHR "$src_bspec")

    # [[ "$src_bname" == "libc6" ]] || continue # fixme: test
    # [[ "$src_bname" == "libgcc-s1" ]] || continue # fixme: test

    echo "$i" >&2
    echo "$src_bname" >&2

    # fixme: slooow
    if [[ -z $(dverIsVReq $src_bver) ]]; then #? end nodes
      enode_backwards+=($i) #? better to parse separatly
      continue
    fi

    local match=($(cat "$flatten" | grep -n '^[0-9]\+\s'"$src_bname"'\/\s\?.*$' | sed -n 's/^\([0-9]\+\):.*$/\1/p'))

    echo "${match[@]:0:5}" >&2

    for ((j=0; j<${#match[@]}; ++j)); do #? j-for

      local lnum=$(( ${match[$j]} - 1 ))
      local dst_bspec=$(echo ${lines[$lnum]} | sed -n "$regexp/\2/p")
      local dst_bname=$(bspecName "$dst_bspec")
      local dst_bver=$(bspecVersionHR "$dst_bspec")

      [[ -n $(dverIsVReq "$dst_bver") ]] || continue #? end node

      # fixme: test - never riched
      if [[ -z "$dst_bver" ]]; then
        error  1 "VERSUM" "expected vreq but got $dst_bspec"
        return 1
      fi

      local dst_level=$(echo ${lines[$lnum]} | sed -n "$regexp/\1/p")
      local dst_provides=$(echo ${lines[$lnum]} | sed -n "$regexp/\3/p")
      local new_bv=$(dverCompose "$dst_bver" "$src_bver")

      if [[ $? -gt 0 ]] || [[ -z "$new_bv" ]]; then #! empty vreq is also bad
        error 1 "VERSUM" "fails to compose $src_bver with $dst_bver"
        return 1
      fi

      src_bver="$new_bv"

      if [[ -n "$dst_provides" ]]; then #! hmm, vreq looks strange 'libc6/>=2.14 libc6-2.25'
        local rw_line="$dst_level $dst_bname/${src_bver// /} $dst_provides" #? provides just in case of
        error 1 "VERSUM" "vreq also contains provides $rw_line"
        return 1
      fi

      rw_line="$dst_level $dst_bname/${src_bver// /}"
      match_backwards+=($lnum)

    done #? /k-for

    for ((k=0; k<${#match_backwards[@]}; ++k)); do #? --- backwards vreqs

      local k_line=${lines[${match_backwards[$k]}]}
      local k_bspec=$(echo "$k_line" | sed -n "$regexp/\2/p")
      local k_bname=$(bspecName "$k_bspec")
      local k_bver=$(bspecVersionHR "$k_bspec")

      # fixme: test - uneeded if
      if [[ -n $(dverIsVReq $k_bver) ]]; then #? 1st, 2nd form of end node
        lines[${match_backwards[k]}]="$rw_line"
      fi

    done #? --- /bk_vreqs

    local full_form_bspec prev_bspec
    for ((k=0; k<${#enode_backwards[@]}; ++k)); do #? --- backwards end_nodes

      local k_line=${lines[${enode_backwards[$k]}]}

      local k_bspec=$(echo "$k_line" | sed -n "$regexp/\2/p")
      local k_bname=$(bspecName "$k_bspec")
      local k_bver=$(bspecVersion "$k_bspec")
      local k_provides=$(echo "$k_line" | sed -n "$regexp/\3/p") # fixme: move to if to speedup

      if [[ -z $(dverIsVReq $k_bver) ]]; then #? 1st, 2nd form of end node

        [[ -z $full_form_bspec ]] && full_form_bspec="$k_bspec"

        if [[ -z $k_provides ]]; then #? 1st form (without provides)
          # echo "$k: $k_line" >&2
          echo "end node: $k_bname/$k_bver (1nd form)" >&2
          local rw_vreq=$(echo "$rw_line" | sed -n "$regexp/\2/p")
          rw_vreq=$(bspecVersionHR "$rw_vreq")
          echo dverMatch "$rw_vreq" "$k_bver" >&2
          if [[ -n $(dverMatch "$rw_vreq" "$k_bver") ]]; then
            echo "ok" >&2
          else
            echo '--------------' >&2
            echo "$k_line" >&2
            echo "$rw_line" >&2
            echo '--------------' >&2
            error 1 VERSUM "Vreq mismatch $rw_vreq & $k_bver at line ${k_line:0:16} ..."
            return 1
          fi
        else  #? 1st form (with provides)
          echo "$k: $k_line" >&2
          echo "end node: $k_bname/$k_bver $k_provides (2nd form)" >&2
          local rw_vreq=$(echo "$rw_line" | sed -n "$regexp/\2/p")
          rw_vreq=$(bspecVersionHR "$rw_vreq")
          echo dverMatch "$rw_vreq" "$k_bver" >&2
          if [[ -n $(dverMatch "$rw_vreq" "$k_bver") ]]; then
            echo "ok" >&2
          else
            echo "!matched" >&2
          fi
        fi

      elif [[ -z "$k_bver" && -z "$k_provides" ]]; then #? 3rd form of end node

        # just use
        echo "$k: $k_line" >&2
        echo "end node: $k_bspec (3rd form)" >&2

      elif [[ -z "$k_bver" && -n "$k_provides" ]]; then #? 4th form of end node

        error  1 VERSUM "this form or end nodes isn't supported yet $k_line"
        return 1

      else #! vreq
        error 1 VERSUM "expected end node but got vreq at $k_line"
        return 1
      fi

      #? ensures that end nodes are same, except 3rd form
      if [[ $k -gt 0 ]] &&
          [[ -n full_form_bspec ]] && # full form exists
          [[ "$k_bspec" != "$prev_bspec" ]]
      then
        error 1 VERSUM "few end nodes differs $k_bspec != $prev_k_bspec"
        return 1

      fi

      prev_bspec="$k_bspec"

    done #? --- /bk_enodes ----

    # fixme: test
    # [[ $src_bname == "libc6" ]] && break

    # fixme: test
    # [[ $src_bname == "libgcc-s1" ]] && break

  done #? i-for

  [[ -f "$flatten_new" ]] && rm -f "$flatten_new"
  touch "$flatten_new"

  for line in "${lines[@]}"; do
    echo "$line" >> "$flatten_new"
  done

}

taskSumVReqNew() {
  local task="$1"
  local regexp='s/^\([0-9]\+\)\s\([^ ]\+\)\s\?\(.*\)$'
  local flatten="./.build-reqs/$task/$BREQ_FLATTEN"
  local flatten_rw="./.build-reqs/$task/${BREQ_FLATTEN}-rw"
  # local skip=(1 5 7)
  local skip

  info $task "versions ..."

  rm -rf "./.build-reqs/$task/.debug/"

  local test_one_again=2

  mapfile -t lines < "$flatten"
  for ((i=0; i<${#lines[@]}; ++i)); do #? i for lines

    # if [[ $test_one_again -gt 0 ]]; then
    #   [[ $test_one_again -eq 1 ]] && i=8
    #   test_one_again=$(( $test_one_again - 1 ))
    # else
    #   break
    # fi

    [[ " ${skip[*]} " == *" $i "* ]] && echo "---- /$i/ skipping -----" >&2 && continue

    # echo '========================' >&2
    # echo -n "[$i] " >&2

    unset src_bspec src_bname src_bver
    unset dst_bspec dst_bname dst_bver
    unset enodes vreqs rw_bver pnode_bver
    unset node_level node_bspec node_bname node_bver node_provides

    local src_bspec=$(echo "${lines[$i]}" | sed -n "$regexp/\2/p")
    local src_bname=$(bspecName "$src_bspec")
    # local src_bver=$(bspecVersionHR "$src_bspec")

    # todo: narrow flatten during processing for speedup
    local match=($(cat "$flatten" | grep -n '^[0-9]\+\s'"$src_bname"'\/\s\?.*$' | sed -n 's/^\([0-9]\+\):.*$/\1/p')) # fixme: bug
    [[ ${#match[@]} -eq 1 ]] && continue

    mkdir -p "./.build-reqs/$task/.debug/$src_bname/"
    cat "$flatten" | grep -n '^[0-9]\+\s'"$src_bname"'\/\s\?.*$' >> "./.build-reqs/$task/.debug/$src_bname/match"

    # echo " ${match[@]:0:5}" >&2

    #? splitting vreqs and epoints
    # echo "--- splitting vreqs and epoints ---" >&2
    echo "$src_bspec" >&2
    local enodes vreqs
    for ((j=0; j<${#match[@]}; ++j)); do
      local li=$(( ${match[$j]} - 1))
      # echo "${lines[$li]}" >&2

      local src_bspec=$(echo "${lines[$li]}" | sed -n "$regexp/\2/p")
      local src_bname=$(bspecName "$src_bspec")
      local src_bver=$(bspecVersionHR "$src_bspec")

      # if [[ "$src_bver" == '< 2.32' ]]; then
      #   echo "dverIsVReq \"$src_bver\""
      #   error 1 TST TST
      # fi

      if [[ -n $(dverIsVReq "$src_bver") ]]; then
        vreqs+=($li)
      else
        enodes+=($li)
      fi
    done

    #? vreqs
    if [[ ${#vreqs[@]} -gt 0 ]]; then

      # echo "${lines[${vreqs[0]}]}" >&2

      local src_bspec=$(echo "${lines[${vreqs[0]}]}" | sed -n "$regexp/\2/p")
      local src_bname=$(bspecName "$src_bspec")
      local src_bver=$(bspecVersionHR "$src_bspec")

      # echo "$src_bspec" >&2

      #? composing vreqs
      # echo "--- composing vreqs ---" >&2
      # echo "vreqs: ${vreqs[@]}" >&2
      # echo "src: $src_bspec" >&2

      local rw_bver=$(bspecVersionHR "${vreqs[0]}")
      # todo: with j=0 we have 1-useles run of loop
      for ((j=0; j<${#vreqs[@]}; ++j)); do
        local li=${vreqs[$j]}
        local dst_bspec=$(echo ${lines[$li]} | sed -n "$regexp/\2/p")
        local dst_bname=$(bspecName "$dst_bspec")
        local dst_bver=$(bspecVersionHR "$dst_bspec")
        local dst_level=$(echo ${lines[$li]} | sed -n "$regexp/\1/p")
        local dst_provides=$(echo ${lines[$li]} | sed -n "$regexp/\3/p")

        # echo "dst: $dst_bspec" >&2

        if [[ -n "$dst_provides" ]]; then #! vreq looks strange 'libc6/>=2.14 libc6-2.25'
          error 1 VERSUM "vreq contains provides at line $(( $li + 1 )) '${lines[$li]:0:18}...'"
          return 1
        fi

        #? after loop rw_bver will contains final vreq (rw_line - whole line)
        if [[ -n "$dst_bver" ]]; then
          [[ -z "$rw_bver" ]] && rw_bver="$dst_bver"

          # [[ "$src_bname" == "libc6" ]] && echo dverCompose "$dst_bver" "$rw_bver" >&2

          rw_bver=$(dverCompose "$dst_bver" "$rw_bver") # fixme: fix dverCompose arg order
          # local ec="$?"

          if [[ $? -gt 0 ]] || [[ -z "$rw_bver" ]]; then #! empty vreq is also bad
            # echo "/($i) $src_bname/ ec: $ec ec: $? rw_bver: $rw_bver dst_bspec: $dst_bspec dst_bver: $dst_bver" >&2
            error 1 VERSUM "fails to compose with $dst_bver at line $(( $li + 1 )) '${lines[$li]:0:18}...'"
            return 1
          fi
        fi

        # echo "/compose/" "$dst_bver U $rw_bver ==> $rw_bver" >&2

      done

      #? replacing vreqs
      # echo "--- replacing vreqs ---" >&2
      # echo "vreqs: ${vreqs[@]}" >&2
      # echo "res_line: $rw_line" >&2
      for ((j=0; j<${#vreqs[@]}; ++j)); do
        local li=${vreqs[$j]}
        # preserve level
        local dst_level=$(echo ${lines[$li]} | sed -n "$regexp/\1/p")
        lines[$li]="$dst_level $dst_bname/${rw_bver// /}"
        # echo "rw_line[$li]: $dst_level $dst_bname/${rw_bver// /}" >&2
      done

    fi #? /vreqs

    #? walk thru epoins
    if [[ -n "$rw_bver" ]]; then # some vreqs to rewrite
      # echo "--- enodes walk ---" >&2
      # echo "enodes: ${enodes[@]}" >&2
      local pnode_bver
      for ((j=0; j<${#enodes[@]}; ++j)); do
        local li=${enodes[$j]}

        # echo "line[$li]: ${lines[$li]}" >&2

        local node_level=$(echo "${lines[$li]}" | sed -n "$regexp/\1/p")
        local node_bspec=$(echo "${lines[$li]}" | sed -n "$regexp/\2/p")
        local node_bname=$(bspecName "$node_bspec")
        local node_bver=$(bspecVersion "$node_bspec")
        local node_provides=$(echo ${lines[$li]} | sed -n "$regexp/\3/p")

        # todo: form template
        # if [[ -n "$node_bver" && -n $k_provides ]]; then #? 1st form (with provides)
        # fi
        # if [[ -n "$node_bver" && -z $k_provides ]]; then #? 2nd form (without provides)
        # fi
        # if [[ -z "$node_bver" && -z $k_provides ]]; then #? 3rd form (just name)
        # fi
        # if [[ -z "$node_bver" && -n $k_provides ]]; then #? 4th form (error)
        # fi

        if [[ -n "$node_bver"  ]]; then
          if [[ -z $(dverMatch "$rw_bver" "$node_bver") ]]; then
            echo "/($i) $src_bname/ ec: $? rw_bver: $rw_bver node_bspec: $node_bspec node_bver: $node_bver" >&2
            echo "dverMatch" "$rw_bver" "$node_bver" >&2
            error 1 VERSUM "end point not matched $rw_bver at line $(( $li + 1 )) '${lines[$li]:0:18}...'"
            return 1
          fi
          if [[ -n "$pnode_bver" ]] && [[ -z $(dverCmp "$pnode_bver" "$node_bver") ]]; then
            error 1 VERSUM "mess in end point versions at line $(( $li + 1 )) '${lines[$li]:0:18}...'"
            return 1
          fi
          [[ -z "$pnode_bver" ]] && pnode_bver="$node_bver"
        fi

        # echo "rw-line[$li]: $node_level $node_bspec $node_provides" >&2
        lines[$li]="$node_level $node_bspec $node_provides"
      done
    fi #? /enodes

    skip+=(${enodes[@]})
    skip+=(${vreqs[@]})

    # echo "!!!!!!!!!!!!!!!!!!!!!!11">&2

    # if [[ -n $test_one_again ]]; then
    #   i=8
    #   test_one_again=""
    # else
    #   break
    # fi

    # break

  done #? i-for

  #? ---- fixatig changes ----
  [[ -f "$flatten_rw" ]] && rm -f "$flatten_rw" && touch "$flatten_rw"
  for line in "${lines[@]}"; do
    echo "$line" >> "$flatten_rw"
  done

}

# echo $(dverCompose ">= 2.65" ">= 2.65")
# [[ -z $(dverMatch '>= 2.65' '2.69-14') ]] && echo "false" || echo "true"

taskSumVReqNew "bash"

# [[ -z $(dverMatch '> 2.31' '2.31-13+deb11u6') ]] && echo "false" || echo "true"
# [[ -z $(dverMatch '< 2.32' '2.31-13+deb11u6') ]] && echo "false" || echo "true"

# bspecVersion 'libc6/<2.32'
# bspecVersionHR 'libc6/<2.32'
# [[ -z $(dverIsVReq '< 2.32') ]] && echo "false" || echo "true"

# batdiff ./.build-reqs/bash/.flatten{,-new} # fixme: test

# echo $(dverCompose ">= 2.65" ">= 2.25")
# [[ -z $(dverIsVReq "libgcc-s1/10.2.1-6") ]] && echo "false" || echo "true"