#!/usr/bin/env bash
# @file globals
# @brief An collections of test asserts and samples.

#! tests - not affected on installed sh-dpkg and must be disabled
#? testing (TEST_ENABLE, TEST_RUN, TEST_SAMPLES) must be enabled outside (e.g. in `.envrc`)
if [[ -n ${TEST_ENABLE} ]]; then
  [[ -z ${TEST_DIR} ]] && TEST_DIR="./tests"
  if [[ -n ${TEST_SAMPLES} ]]; then
    TSMPL_VER="${TEST_DIR}/samples/vers"
    TSMPL_VREQ="${TEST_DIR}/samples/vreq"
  fi
fi

# return true if global test mode enabled
isTestEnabled() {
  [[ -n TEST_ENABLE ]] && echo "1" || echo ""
}

isSamplesEnabled() {
  [[ -n TEST_SAMPLES ]] && echo "1" || echo ""
}

# initialize tests - files, variables, etc
testInit() {
  if [[ $(isTestEnabled) ]]; then
    if [[ $(isSamplesEnabled) ]]; then
      [[ -f "$TSMPL_VER" ]] && rm -f "$TSMPL_VER"
      touch "$TSMPL_VER"
      [[ -f "$TSMPL_VREQ" ]] && rm -f "$TSMPL_VREQ"
      touch "$TSMPL_VREQ"
      # fixme: pre-generated samples
      cat "${TSMPL_VREQ}-include" > "$TSMPL_VREQ"
    fi
  fi
}

# define test asserts: testAsserts <func_name>
testAsserts() {
  return
}

# do fuction test
testFunc() {
  return
}

# add function to call trace
testCallTrace() {
  return
}

# add to version samples: testAddToVersionSamples <cond> <@version>
testAddToVersionSamples() {
  [[ $(isSamplesEnabled) ]] || return
  local cond="$1"
  shift
  echo "$cond" "$@" >> "$TSMPL_VER"
}

# add to version samples: testAddToVersionSamples <vr1> <vr2> <vres> <vcode>
testAddToVReqSamples() {
  [[ $(isSamplesEnabled) ]] || return
  local res="$1;$2;$3;$4"
  res="${res// /'&'}"
  echo "$res" >> "$TSMPL_VREQ"
}

testInit