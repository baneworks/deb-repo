#!/usr/bin/env bash
# @file lib-debver
# @brief A library for parsing and comparing debian version strings.

# @description Function to compare two debian's version strings. Compares by left to right by single character.
#
# @example
#    $(dverCmp <left_ver> <right_ver>)
#
# @arg `left` left debian version string.
# @arg `right` right debian version string.
#
# @stdout `>` if `left` is greater than `right`.
# @stdout `=` if `left` is equals `right`.
# @stdout `<` if `left` is less than `right`.
#
# @exitcode 0 on success.
# @exitcode 1 on failure.
#
# @see [deb-version](https://manpages.ubuntu.com/manpages/xenial/en/man5/deb-version.5.html)
dverCmp() {
  local tstr="$2" vstr="$1"

  # peace of cake
  if [[ $tstr == $vstr ]]; then
    echo "="
    return 0
  fi

  #? ---- epoch ----
  local regexp='s/^\([0-9]\+\):\(.*\)$'
  local t_epoch=$(sed -n "$regexp/\1/1p" <<< $tstr)
  local v_epoch=$(sed -n "$regexp/\1/1p" <<< $vstr)
  [[ -z $t_epoch ]] && t_epoch=0
  [[ -z $v_epoch ]] && v_epoch=0

  if ! [[ $t_epoch -eq $v_epoch ]]; then
    [[ $t_epoch -gt $v_epoch ]] && echo ">"
    [[ $t_epoch -lt $v_epoch ]] && echo "<"
    return 0
  fi
  ! [[ $t_epoch -eq 0 ]] && tstr=$(sed -n "$regexp/\2/p" <<< $tstr)
  ! [[ $v_epoch -eq 0 ]] && vstr=$(sed -n "$regexp/\2/p" <<< $vstr)

  regexp='s/^\(.*\)-\(.*\)$'
  local t_debian=$(sed -n "$regexp/\2/1p" <<< $tstr)
  local v_debian=$(sed -n "$regexp/\2/1p" <<< $vstr)
  local t_upstream v_upstream
  if [[ -z "$t_debian" ]]; then
    t_upstream="$tstr"
  else
    t_upstream=$(sed -n "$regexp/\1/1p" <<< $tstr)
  fi
  if [[ -z $v_debian ]]; then
    v_upstream=$vstr
  else
    v_upstream=$(sed -n "$regexp/\1/1p" <<< $vstr)
  fi

  local ret=0
  local res=""
  local parts=2

  while [[ $parts -gt 0 ]]; do

    case $parts in
      '2') local tstr_part=$t_upstream; local vstr_part=$v_upstream ;;
      '1') local tstr_part=$t_debian; local vstr_part=$v_debian ;;
        *) break;;
    esac

    local i=0
    while [[ -n $tstr_part || -n $vstr_part ]]; do
      #? '-' & '~' part. '-' is greatest, but '~' smallest (thanks a lot, debian)
      regexp='s/^\([~\-]\)\(.*\)\?$'
      local t_special=$(sed -n "$regexp/\1/1p" <<< $tstr_part)
      local v_special=$(sed -n "$regexp/\1/1p" <<< $vstr_part)
      if ! [[ $t_special == $v_special ]]; then
        [[ $t_special == '-' ]] && res=">"
        [[ $t_special == '~' ]] && res="<"
        [[ $v_special == '-' ]] && res="<"
        [[ $v_special == '~' ]] && res=">"
        echo "$res"
        return $ret
      fi
      [[ -n $t_special ]] && tstr_part=$(sed -n "$regexp/\2/1p" <<< $tstr_part)
      [[ -n $v_special ]] && vstr_part=$(sed -n "$regexp/\2/1p" <<< $vstr_part)

      #? non digit part
      regexp='s/^\([^0-9]\+\)\([0-9].*\)\?$'
      local t_chars=$(sed -n "$regexp/\1/1p" <<< $tstr_part)
      local v_chars=$(sed -n "$regexp/\1/1p" <<< $vstr_part)
      if ! [[ $t_chars == $v_chars ]]; then
        [[ $t_chars > $v_chars ]] && res=">"
        [[ $t_chars < $v_chars ]] && res="<"
        echo "$res"
        return $ret
      fi
      [[ -n $t_chars ]] && tstr_part=$(sed -n "$regexp/\2/1p" <<< $tstr_part)
      [[ -n $v_chars ]] && vstr_part=$(sed -n "$regexp/\2/1p" <<< $vstr_part)

      #? digit part
      regexp='s/^\([0-9]\+\)\([^0-9].*\)\?$'
      local t_num=$(sed -n "$regexp/\1/1p" <<< $tstr_part)
      local v_num=$(sed -n "$regexp/\1/1p" <<< $vstr_part)
      if ! [[ $t_num -eq $v_num ]]; then
        [[ $t_num -gt $v_num ]] && res=">"
        [[ $t_num -lt $v_num ]] && res="<"
        echo "$res"
        return $ret
      fi
      [[ -n $t_num ]] && tstr_part=$(sed -n "$regexp/\2/1p" <<< $tstr_part)
      [[ -n $v_num ]] && vstr_part=$(sed -n "$regexp/\2/1p" <<< $vstr_part)

      i=$(( i + 1 ))
    done

    parts=$(( $parts - 1 ))

  done

  [[ -z $res ]] && ret=1
  echo "$res"
  return $ret
}

# @description Is string an version requrenment.
#
# @example
#    $(dverIsVReq <str>)
#
# @arg `str` requrenment string like ">= 2.4 2.31-13+deb11u6".
#
# @stdout "true" if str is Vreq.
# @stdout "" if not.
dverIsVReq() {
  local str="$1"
  local res
  [[ "${str:0:1}" == '=' ]] && res="true"
  [[ "${str:0:1}" == '>' ]] && res="true"
  [[ "${str:0:1}" == '<' ]] && res="true"
  echo "$res"
}

# @description Function to extract condition operator from depend requrenment string.
#
# @example
#    $(dverCondition <req>)
#
# @arg `req` requrenment string like ">= 2.4 2.31-13+deb11u6".
#
# @stdout condition operator string.
dverCondition() {
  local cond_op="$1"
  cond_op=$(tr -cd '[:print:]' <<< "$cond_op")
  cond_op=($cond_op)
  local target="${cond_op[1]}"
  cond_op="${cond_op[0]}"
  echo "$cond_op"
}

# @description Function to extract target version from depend requrenment string.
#
# @example
#    $(dverTarget <req>)"
#
# @arg `req` requrenment string like ">= 2.4 2.31-13+deb11u6".
#
# @stdout target version.
dverTarget() {
  local cond_op="$1"
  cond_op=$(tr -cd '[:print:]' <<< "$cond_op")
  cond_op=($cond_op)
  local target="${cond_op[1]}"
  echo "$target"
}

# @description Function to apply depend requrenment string to package version.
#
# @example
#    $(dverMatch <req> <version>)
#
# @arg `req` requrenment string like ">= 2.4 2.31-13+deb11u6".
# @arg `version` package version.
#
# @stdout "true" if matched.
# @stdout "" if not matched.
dverMatch() {
  local cond=$(dverCondition "$1")
  local tver=$(dverTarget "$1")
  local ver="$2"
  local res=$(dverCmp "$tver" "$ver")

  [[ $? -gt 1 ]] && error 1 DVER "version compare error"

  local match
  case "$cond" in
    '>') [[ $res == '>' ]] && match="true" ;;
    '>=') [[ $res == '>' || $res == '=' ]] && match="true" ;;
    '=') [[ $res == '=' ]] && match="true" ;;
    '<=') [[ $res == '<' || $res == '=' ]] && match="true" ;;
    '<')  [[ $res == '<' ]] && match="true" ;;
    '>>') [[ $res == '>' ]] && match="true" ;;
    '<<') [[ $res == '<' ]] && match="true" ;;
      *) echo "" ;;
  esac

  echo "$match"
}

# todo: test cover
# @description Function to compose two version's requirenment string.
#   Conposition done in *non-extending* mode (e.g. result of
#   composition of ">= 2.4" + ">= 2.5" will be ">= 2.5")
#
# @example
#    $(dverCompose <left> <right>)
#
# @arg `left` requrenment string to compose with right (e.g. ">= 2.4").
# @arg `right` requrenment string to compose (e.g. ">= 2.5").
#
# @stdout new composed version requirenment string on success.
# @stdout "" real result of composition is empty (if exitcode = 0).
#
# @exitcode 0 on success composition (in this case )
# @exitcode 1 on failure
# @exitcode 2 not implemented yet
#
# @see [version requrenment string](https://manpages.ubuntu.com/manpages/xenial/en/man5/deb-control.5.html)
dverCompose() {
  local l="$1" r="$2"
  local lc=$(dverCondition "$l") rc=$(dverCondition "$r")
  local lt=$(dverTarget "$l") rt=$(dverTarget "$r")
  local res=""

  # easy - equals
  if [[ "$l" == "$r" ]]; then
    echo "$l"
    return 0
  fi

  # fixme: implement '><' '<>' case
  if [[ "${lc:0:1}" == '>' && "${rc:0:1}" == '<' ]] ||
     [[ "${lc:0:1}" == '<' && "${rc:0:1}" == '>' ]]
  then
    echo ""
    return 2
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
    local cmp=$(dverCmp "$rt" "$lt") #? [< & <] variant
    if [[ "${lc:0:1}" == '<' && "${rc:0:1}" == '<' ]]; then
      case $cmp in
      '<') echo "$l" && return 0;;
      '=') [[ "${lc:1:1}" == '=' ]] || echo "$r"; [[ "${rc:1:1}" == '=' ]] || echo "$l"; return 0;;
      '>') echo "$r" && return 0 ;;
        *) echo "" && return 1 ;;
    esac
    fi
    case $cmp in #? [> & >] variant
      '>') echo "$l" && return 0 ;;
      '=') [[ "${lc:1:1}" == '=' ]] || echo "$l"; [[ "${rc:1:1}" == '=' ]] || echo "$r"; return 0;;
      '<') echo "$r" && return 0;;
        *) echo "" && return 1 ;;
    esac
  fi

  echo "$res"
  return 1
}