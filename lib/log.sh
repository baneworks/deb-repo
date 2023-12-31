#!/usr/bin/env bash
# @file log
# @brief Function for a looging.

# region #? general

# @ description print error message and exit: <task> <message>
# @internal
error() {
	local err tag msg
	err="$1"
	tag="$2"
	msg="$3"
	shift; shift; shift
	(printf "\n${COLOR_RED}[$tag]${COLOR_OFF}: $msg\n" "$@") >&2
	exit $err
}

# @ description print warning message: <task> <message>
# @internal
warning() {
  local tag msg
	tag="$1"
  msg="$2"
  shift; shift
	(printf "${COLOR_YELLOW}[$tag]${COLOR_OFF}: $msg\n" "$@") >&2
}

# @ description print info message: <task> <message>
# @internal
info() {
  local tag msg
	tag="$1"
  msg="$2"
  shift; shift
	(printf "${COLOR_GREEN}[$tag]${COLOR_OFF}: $msg\n" "$@") >&2
}

# @ description print head message: <task> <message>
# @internal
logHead() {
  (printf "${COLOR_OFF}[${COLOR_GREEN}$1${COLOR_OFF}] $2") >&2
}

# @ description print status message: status <status> <message>
# @internal
logStatus() {
  case "$1" in
       'ok') (printf " [${COLOR_GREEN}OK${COLOR_OFF}]\n") >&2 ;;
     'note') (printf " [${COLOR_GRAY}$2${COLOR_OFF}]\n") >&2 ;;
     'warn') (printf " [${COLOR_YELLOW}$2${COLOR_OFF}]\n") >&2 ;;
      'err') (printf " [${COLOR_RED}$2${COLOR_OFF}]\n") >&2 ;;
          *) (printf " [${COLOR_RED}$1:$2${COLOR_OFF}]\n") >&2 ;;
  esac
}

# endregion

# region #? tabbed

# fixme: ugly
# @description Print tabbed node tag: logTabHead <level> <@bnames> <message>"
# @internal
logTabHead() {
  local lvl="$1"
  IFS="/" read -ra pth <<< "$2"

  if [[ $lvl -eq 1 ]]; then
    (printf "${COLOR_OFF}{${pth[0]}${COLOR_GREEN} ${pth[1]}${COLOR_OFF}} $3") >&2
    return
  fi

  local len=$(( ${#pth[@]} - 1))
  local head="${pth[@]:0:$len}"
  for h in ${pth[@]:0:$len}; do
    head+="$h "
  done
  last="${pth[-1]}"
  (printf "${COLOR_OFF}{${COLOR_GREEN}$last${COLOR_OFF}} $3") >&2

  return
}

# @description Print tabbed status message: logTabStatus <level> <status> <message>
# @internal
logTabStatus() {
  local lvl="$1"; shift
  [[ $lvl -eq 1 ]] && nl="\n"
  case "$1" in
       'ok') [[ $lvl -eq 1 ]] && (printf " [${COLOR_GREEN}OK${COLOR_OFF}]$nl") >&2 || (printf "") >&2 ;;
    'nodep') (printf "[${COLOR_GRAY}!dep${COLOR_OFF}] ") >&2 ;;
     'have') (printf "[${COLOR_GRAY}+$2${COLOR_OFF}] ") >&2 ;;
     'note') (printf "[${COLOR_YELLOW}$2${COLOR_OFF}] ") >&2 ;;
     'warn') (printf "[${COLOR_YELLOW}$2${COLOR_OFF}] ") >&2 ;;
      'err') (printf "[${COLOR_RED}$2${COLOR_OFF}]\n") >&2 ;;
          *) (printf "[${COLOR_RED}$1:$2${COLOR_OFF}]$nl") >&2 ;;
  esac
}

# @description Replicate string: logRepStr <count> <pre> <str> <post>
# @internal
logRepStr() {
  local res="$2"
  for ((i=0; i<"$1"; i++)); do
    res="${res}$3"
  done
  echo "${res}$4"
}

# endregion

# region #? journal

# @ description add line to task log: <task> <message>
# @internal
logTask() {
  bkendWrite "$(tagValue log)/$1.log" "$2"
}

# endregion