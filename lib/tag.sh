# return tag list
tagList() {
  echo $($TAG_TREE $TAG_SH $TAG_DSRC $TAG_DBIN $TAG_TMP)
}

# get tag value: tagValue <tag>
function tagValue() {
  case "$1" in
     repo) echo ${REPO_NAME} ;;
    btree) echo ${TAG_TREE} ;;
       sh) echo ${TAG_SH} ;;
     dbin) echo ${TAG_DBIN} ;;
     dsrc) echo ${TAG_DSRC} ;;
      tmp) echo ${TAG_TMP} ;;
        *) error 1 BADTAG "unknown dir tag" ;;
  esac
}

# fixme: is actually needed?
# get tag dirname: tagDir <tag>
function tagDir() {
  case "$1" in
       sh) echo ${TAG_SH_DIR} ;;
    btree) echo ${TAG_TREE_DIR} ;;
     dbin) echo ${TAG_DBIN_DIR} ;;
     dsrc) echo ${TAG_DSRC_DIR} ;;
      tmp) echo ${TAG_TMP_DIR} ;;
        *) error 1 BADTAG "unknown dir tag" ;;
  esac
}