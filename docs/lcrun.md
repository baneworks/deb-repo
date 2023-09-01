# lcrun

The local run backend.

## Overview

Function to create repo dir. Safe function

## Index

* [lcrunAptSources](#lcrunaptsources)
* [lcrunAptCache](#lcrunaptcache)

### lcrunAptSources

Function to excute the source stage.
Not using `lcrunExec` (for pretty output reasons)

#### Example

```bash
$(lcrunAptSources <task>)"
```

#### Options

* `task` a build task

### lcrunAptCache

Function to excute the `apt-cache show`.

#### Example

```bash
$(lcrunAptCache <pkg>)"
```

#### Options

* `pkg` package to query

