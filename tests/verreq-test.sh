#!/usr/bin/env bash
# @file tests for lib-debver
# @brief A library for parsing and comparing debian version strings.

. ./bin/debver-lib
. ./bin/bspec-lib
. ./bin/log-lib

dverCompose() {
  local l="$1" r="$2"
  local lc=$(dverCondition "$l") rc=$(dverCondition "$r")
  local lt=$(dverTarget "$l") rt=$(dverTarget "$r")
  local res="false"

  # fixme: implement '><' case
  if [[ "${lc:0:1}" == '>' && "${rc:0:1}" == '<' ]]; then
    echo ""
    return 1
  fi

  #? [= & >] and [> & =] cases
  if [[ "$lc" == '=' && "${rc:0:1}" == '>' ]] ||
     [[ "${lc:0:1}" == '>' && "$rc" == '=' ]]
  then
    local cmp
    # fixme: in dverCmp wrong op order
    if [[ "${lc:0:1}" == '>' && "$rc" == '=' ]]; then  #? [> & =] variant
      local tmp="$l"; l="$r"; r="$tmp"
      lc=$(dverCondition "$l"); rc=$(dverCondition "$r")
      lt=$(dverTarget "$l"); rt=$(dverTarget "$r")
    fi
    cmp=$(dverCmp "$rt" "$lt")
    case $cmp in
      '>') echo "= $lt" && return 0;;
      '=') [[ "${rc:1:1}" == '=' ]] && echo "= $lt" && return 0 || echo "" && return 0 ;;
      '<') echo "" && return 0 ;;
        *) echo "" && return 1 ;;
    esac
  fi

  #? [= & <] or [< & =] cases
  if [[ "$lc" == '=' && "${rc:0:1}" == '<' ]] ||
     [[ "${lc:0:1}" == '<' && "$rc" == '=' ]]
  then
    local cmp
    # fixme: in dverCmp wrong op order
    if [[ "${lc:0:1}" == '<' && "$rc" == '=' ]]; then  #? [< & =] variant
      local tmp="$l"; l="$r"; r="$tmp"
      lc=$(dverCondition "$l"); rc=$(dverCondition "$r")
      lt=$(dverTarget "$l"); rt=$(dverTarget "$r")
    fi
    cmp=$(dverCmp "$rt" "$lt")
    case $cmp in
      '<') echo "= $lt" && return 0;;
      '=') [[ "${rc:1:1}" == '=' ]] && echo "= $lt" || echo "" ; return 0 ;;
      '<') echo "" && return 0 ;;
        *) echo "" && return 1 ;;
    esac
  fi

  #? = & = case
  if [[ "$lc" == '=' && "$rc" == '=' ]]; then
    if [[ $(dverCmp "$rt" "$lt") == '=' ]]; then
      echo "$r" && return 0
    else
      echo "" && return 1
    fi
  fi

  #? [> & >] or [< & <] cases
  if [[ "${lc:0:1}" == '>' && "${rc:0:1}" == '>' ]] ||
     [[ "${lc:0:1}" == '<' && "${rc:0:1}" == '<' ]]
  then
    # fixme: in dverCmp wrong op order
    local cmp=$(dverCmp "$rt" "$lt")
    if [[ "${lc:0:1}" == '<' && "${rc:0:1}" == '<' ]]; then  #? [< & <] variant
      case $cmp in
      '<') echo "$l" && return 0;;
      '=') [[ "${lc:1:1}" == '=' ]] || echo "$r"; [[ "${rc:1:1}" == '=' ]] || echo "$l"; return 0;;
      '>') echo "$r" && return 0 ;;
        *) echo "" && return 1 ;;
    esac
    fi
    case $cmp in
      '>') echo "$l" && return 0;;
      '=') [[ "${lc:1:1}" == '=' ]] || echo "$l"; [[ "${rc:1:1}" == '=' ]] || echo "$r"; return 0;;
      '<') echo "$r" && return 0 ;;
        *) echo "" && return 1 ;;
    esac
  fi

  echo "$res"
  return 1
}

mapfile -t lines < './tests/samples/version-req'

ln=0
for line in "${lines[@]}"; do
  ln=$(( $ln + 1 ))
  if [[ "${line:0:1}" != '#' ]]; then
    [[ -z "$line" ]] && continue

    ta=(${line//;/ })
    tst_1="${ta[0]//&/ }"
    tst_2="${ta[1]//&/ }"
    [[ "${ta[2]}" == "x" ]] && tst_r="" || tst_r="${ta[2]//&/ }"

    res=$(dverCompose "$tst_1" "$tst_2")

    [[ $ln -le 9 ]] && echo -ne " "
    echo -ne "$ln "
    if [[ "$res" != "!implemented" ]]; then
      if [[ "$res" == "$tst_r" ]]; then
        info "$tst_1 U $tst_2" "$res"
      else
        error 0 "$tst_1 U $tst_2" "expected: \"$tst_r\" got: \"$res\""
      fi
    else
      warning "$tst_1 U $tst_2" "$res"
    fi
  fi
done