# docker

The docker backend.

## Overview

get container pid.

## Index

* [dockerAptSources](#dockeraptsources)
* [dockerAptCache](#dockeraptcache)

### dockerAptSources

Function to excute the `apt-get source`.
Not using `dockerExec` (for pretty output reasons)

#### Example

```bash
$(dockerAptSources <task>)"
```

#### Options

* `task` a build task

### dockerAptCache

Function to excute the `apt-cache show`.

#### Example

```bash
$(dockerAptCache <pkg>)"
```

#### Options

* `pkg` package to query

