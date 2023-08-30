# return tag list
tagList() {
  echo $($TAG_TREE $TAG_SH $TAG_DSRC $TAG_DBIN $TAG_OUT $TAG_LOG)
}

# get tag value: tagValue <tag>
function tagValue() {
  case "$1" in
     tree) echo ${TAG_TREE} ;;
       sh) echo ${TAG_SH} ;;
     dbin) echo ${TAG_DBIN} ;;
     dsrc) echo ${TAG_DSRC} ;;
      out) echo ${TAG_OUT} ;;
      log) echo ${TAG_LOG} ;;
        *) error 1 BADTAG "unknown dir tag ($1)" ;;
  esac
}

# fixme: is actually needed?
# get tag dirname: tagDir <tag>
function tagDir() {
  case "$1" in
     tree) echo ${TAG_TREE_DIR} ;;
       sh) echo ${TAG_SH_DIR} ;;
     dbin) echo ${TAG_DBIN_DIR} ;;
     dsrc) echo ${TAG_DSRC_DIR} ;;
      out) echo ${TAG_OUT_DIR} ;;
      log) echo ${TAG_LOG_DIR} ;;
        *) error 1 BADTAG "unknown dir tag ($1)" ;;
  esac
}