#!/usr/bin/env bash

branch=`cat ./tests/samples/ac-branch`

source ./bin/bspec-lib
source ./bin/log-lib

regexp='s/^\([0-9]\+\)\s\([^ ]\+\)\s\?\(.*\)$'
btree="./.build-reqs/bash"
pkgs_out="$btree/.packages"

[[ -f "$pkgs_out" ]] && rm -f "$pkgs_out"

readarray -t lines <<< "$branch"

CYC_MAX_DEPTH=20

# $1 - bname
# $2 - prev level
# $3 - level
# $@ - array
# @stdout array
makeChain() {
  local bn="$1" prev="$2" lvl="$3"
  shift; shift; shift
  local chain=("$@")

  if [[ $lvl -gt $prev ]]; then
    chain+=($bn)
  elif [[ $lvl -eq $prev ]]; then
    chain[-1]=$bn
  else
    local len=${#chain[@]}
    chain=(${chain[@]:0:$(( $lvl - 1 ))})
    chain+=($bn)
  fi

  echo "${chain[@]}"
}

unset pa pkgs bname bspec level li i
declare -a pa p_pa pkgs glob_cyc glob_cyc_spec

p_pa_dir=""
p_bname=""
pp_level=0
p_level=0
for ((i=0; i<"${#lines[@]}"; ++i)); do
  li=$(( $i + 1 ))
  level=$(echo "${lines[$i]}" | sed -n "$regexp/\1/p")
  bspec=$(echo "${lines[$i]}" | sed -n "$regexp/\2/p")
  bname=$(bspecName "$bspec")

  #? skipping if already added
  if [[ " ${pkgs[*]} " == *" $bname "* || " ${glob_cyc[*]} " == *" $bname "* ]]; then
    pa=($(makeChain "$bname" "$p_level" "$level" ${pa[@]}))
    pa_dir="${pa[*]}"
    pa_dir=${pa_dir// /'/'}
    p_level="$level"

    echo -e "$COLOR_GRAY$li $pa_dir$COLOR_OFF"

    continue #? skipping already processed lines
  fi

  pa=($(makeChain "$bname" "$p_level" "$level" ${pa[@]}))
  pa_dir="${pa[*]}"
  pa_dir=${pa_dir// /'/'}

  #? --- cyclic ---
  if [[ -f "./.build-reqs/bash/$pa_dir/.cyclic" ]]; then
    # echo "/$li/ $bname lvl: $level plvl: $p_level $pa_dir"
    # echo "--- cyclic ---"

    pp_level="$p_level"
    p_pa_dir="$pa_dir"
    p_pa=("${pa[@]}")

    # declare -a cyclic=($bname)
    declare -a cyclic=($bname)
    declare -a cyclic_spec=($bspec)
    echo -e "$COLOR_YELLOW$li ${bname}$COLOR_OFF"

    glob_cyc+=("$bname")
    glob_cyc_spec+=("$bspec")
    in_cycle="true"
    j=0
    # local j=0 in_cycle="true"
    while [[ -n $in_cycle ]]; do
      c_li=$(( $i + $j + 1 ))
      c_level=$(echo "${lines[$c_li]}" | sed -n "$regexp/\1/p")
      c_bspec=$(echo "${lines[$c_li]}" | sed -n "$regexp/\2/p")
      c_bname=$(bspecName "$c_bspec")

      [[ $level -gt $c_level || $j -ge $CYC_MAX_DEPTH ]] && break

      cyclic+=("$c_bname")
      glob_cyc+=("$c_bname")
      cyclic_spec+=("$c_bspec")
      glob_cyc_spec+=("$c_bspec")


      echo -e "$COLOR_YELLOW$(( $c_li + 1)) ${c_bname}$COLOR_OFF"

      j=$(( $j + 1 ))

    done
    unset in_cycle #cyclic

    if [[ $j -ge $CYC_MAX_DEPTH ]]; then
      echo "depth of cicle reached limit"
      exit 1
    else
      i=$(( $i + $j ))
      p_level="$pp_level"
      pa_dir="$p_pa_dir"
      pa=("${p_pa[@]}")

      pa=($(makeChain "$p_bname" "$pp_level" "$c_level" ${pa[@]}))
      pa_dir="${pa[*]}"
      pa_dir=${pa_dir// /'/'}

      # echo "${cyclic[@]}" >> "$pkgs_out"
      echo "${cyclic_spec[@]}" >> "$pkgs_out"
      continue
    fi
    #? --- /cyclic ---

  fi

  pkgs+=($bname)
  # echo "$bname" >> "$pkgs_out"
  echo "$bspec" >> "$pkgs_out"

  echo -e "$COLOR_GREEN$li $pa_dir$COLOR_OFF"

  p_level="$level"
done