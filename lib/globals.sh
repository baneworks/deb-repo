#!/usr/bin/env bash
# @file globals
# @brief A set of global variables for sh-dpkg.
# @description A set of global variables for sh-dpkg-source, sh-dpkg-tree, sh-dpkg-dload,
#              sh-dpkg-install, sh-dpkg-binary, sh-dpkg-purge.
#              Testing and collecting test samples not allowed for installed sh-dpkg and
#              must be disabled. If you want tests - it must be enabled outside
#              (e.g. in `.envrc`) by setting TEST_ENABLE (TEST_RUN, TEST_SAMPLES whatever
#              you need).

#! tests - not affected on installed sh-dpkg and must be disabled
#? testing (TEST_ENABLE, TEST_RUN, TEST_SAMPLES) must be enabled outside (e.g. in `.envrc`)
if [[ -n ${TEST_ENABLE} ]]; then
  [[ -z ${TEST_DIR} ]] && TEST_DIR="./tests"
  if [[ -n ${TEST_SAMPLES} ]]; then
    TSMPL_VER="${TEST_DIR}/samples/vers"
    TSMPL_VREQ="${TEST_DIR}/samples/vreq"
  fi
fi

#! tags
TAG_SH="sh"
TAG_DBIN="bin"
TAG_DSRC="src"
TAG_OUT="out"
TAG_TMP="tmp"
TAG_TREE=".btree"

#! repo
REPO_NAME="sh-dpkg" # todo: confugure.in

#! docker run
DC_NAME="debian"
DC_USER="mtain"
DC_GROUP="users"
DC_RERO_DIR="/var/tmp" # todo: confugure.in
DC_REPO="$DC_RERO_DIR/$REPO_NAME"
DC_SUCMD="su -c '$cmd'"

#! local run
LC_REPO_DIR="/var/tmp/"
LC_REPO="$LC_REPO_DIR/$REPO_NAME" # todo: confugure.in
LC_TREE="$LC_REPO/$TAG_TREE"
LC_SUCMD="su -c '$cmd'"

# todo: implement switchable repo
REPO="$DC_REPO" # fixme: temporary
TREE="$REPO/$TAG_BTREE"

# todo: drop
TAG_TREE_DIR="$REPO/$TAG_TREE"   #? "tree"
TAG_SH_DIR="$REPO/$TAG_SH"       #? "sh"
TAG_DBIN_DIR="$REPO/$TAG_DBIN"   #? "dbin"
TAG_DSRC_DIR="$REPO/$TAG_DSRC"   #? "dsrc"
TAG_OUT_DIR="$REPO/$TAG_OUT"     #? "out"
TAG_TMP_DIR="$REPO/$TAG_TMP"     #? "tmp"

#! flatten file
BREQ_FLATTEN=".flatten-in"
BREQ_FLATTEN_RW=".flatten-out"

#! packages file related
BREQ_PKGS=".packages-in"
BREQ_PKGS_UNALIAS=".packages-in-1"
BREQ_PKGS_RW=".packages-in-2"
BREQ_PKGS_CLR=".packages-out"

#! install file related
BREQ_PKGS_INST=".install-in"
BREQ_PKGS_INST_FLT=".install-in-1"
BREQ_PKGS_INST_CRL=".install-out"
BREQ_PKGS_DLSH="download.sh"
BREQ_PKGS_ISH="install.sh"
BREQ_PKGS_USH="uninstall.sh"
BREQ_PKGS_LSH="fcheck.sh"

#! depends parsing related
CYC_MAX_DEPTH=200 # limit for cyclic processing

#! colors
COLOR_OFF='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_GRAY='\033[0;90m'