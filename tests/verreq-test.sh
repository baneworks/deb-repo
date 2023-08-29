#!/usr/bin/env bash
# @file tests for lib-debver
# @brief A library for parsing and comparing debian version strings.

. ./bin/debver-lib
. ./bin/bspec-lib
. ./bin/log-lib

echo "cmp: $(dverCmp '3.1-3' '3.1~')"
echo "match: $(dverMatch '>= 3.1~' '3.1-3')"

[[ '~' > '-' ]] && echo ">" || echo "<"

exit 0

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