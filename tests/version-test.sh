#!/usr/bin/env bash
# @file tests for lib-debver
# @brief A library for parsing and comparing debian version strings.

. ./tests/vestion-test.sh
. ./bin/debver-lib

testVersionSamples() {
  local -a ca ta va
  local regexp='s/^\([\<\>=]\+\)\s\(.*\)\s\(.*\)$'

  mapfile -t lines < ${TEST_VERSAMPLES}
  for line in "${lines[@]}"; do
    ca+=($(echo $line | sed -n "$regexp/\1/p"))
    ta+=($(echo $line | sed -n "$regexp/\2/p"))
    va+=($(echo $line | sed -n "$regexp/\3/p"))
  done

  [[ ${#ca[@]} -eq ${#ta[@]} ]] && [[ ${#ca[@]} -eq ${#va[@]} ]] || return 0

  retcode=0
  for (( i = 0; i < ${#ca[@]}; i++ )); do
    local res=$(compareVersions "${ta[i]}" "${va[i]}")
    if [[ $? -gt 0 ]]; then
      retcode=$?
      return $retcode
    fi
    case "${ca[i]}" in
      '>') [[ $res == '>' ]] && retcode=0 ;;
      '>=') [[ $res == '>' || $res == '=' ]] && retcode=0 ;;
      '=') [[ $res == '=' ]] && retcode=0 ;;
      '<=') [[ $res == '<' || $res == '=' ]] && retcode=0 ;;
      '<')  [[ $res == '<' ]] && retcode=0 ;;
      '>>') [[ $res == '>' ]] && retcode=0 ;;
      '<<') [[ $res == '<' ]] && retcode=0 ;;
        *) retcode=1 ;;
    esac
  done

  [[ $(cat $TEST_VERSAMPLES | wc -l) -eq $i ]] || return 1

  return $retcode
}





