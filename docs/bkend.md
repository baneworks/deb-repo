# bkend

The switching backend (docker | local).

## Overview

Function to create repo dir.

## Index

* [bkendAptSources](#bkendaptsources)
* [bkendAptCache](#bkendaptcache)

### bkendAptSources

Function to excute the source stage.
Not using `bkendExec` (for pretty output reasons)

#### Example

```bash
$(bkendAptSources <task>)"
```

#### Options

* `task` a build task

### bkendAptCache

Function to excute the `apt-cache show`.

#### Example

```bash
$(bkendAptCache <pkg>)"
```

#### Options

* `pkg` package to query

