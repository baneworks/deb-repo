# stage

Stage library.

## Overview

Function to create dir inside repo.

## Index

* [stageHas](#stagehas)
* [stageInit](#stageinit)
* [stageInvalidate](#stageinvalidate)
* [stageExec](#stageexec)
* [stageSources](#stagesources)
* [stageTree](#stagetree)
* [stageWalk](#stagewalk)
* [stageDownload](#stagedownload)
* [stageInstall](#stageinstall)
* [stageBinary](#stagebinary)
* [stagePurge](#stagepurge)

### stageHas

Function to check stage status and stamp status.
If stage's stamp dir is present but no state file - return
'none' as resut with retcode 1.

#### Example

```bash
$(stageHas <task> <stage>)"
```

#### Options

* `task` a build task
* `stages` a stage to check

#### Exit codes

* **0**: on success
* **1**: on failure

#### Output on stdout

* - status of task (e.g. none, valid, dirty, ...), if 'all' specified
  call self with STAGES

### stageInit

Function to init stage.

#### Example

```bash
$(stageInit <task> <stages>)"
```

#### Options

* `force` to force state recreation
* `task` a build task
* `stage` a stage to check

#### Exit codes

* **0**: on success
* **1**: on failure

### stageInvalidate

Function to invalidate stage.

#### Example

```bash
$(stageInvalidate <task> <stages>)"
```

#### Options

* `task` a build task
* `stages` a stage's array to invalidate

### stageExec

Function to excute stage.

#### Example

```bash
$(stageExec <task> <stage>)"
```

#### Options

* `task` a build task

### stageSources

Function to excute the source stage.

#### Example

```bash
$(stageExec <task>)"
```

#### Options

* `task` a build task

### stageTree

Function to excute the "tree" stage. On this stage
dependency tree are built

#### Example

```bash
$(stageTree <task>)"
```

#### Options

* `task` a build task

### stageWalk

Function to excute the "walk" stage. During this stage:
1. Calling (taskSumVReq)[./task#taskSumVReq] to summarize
all of version constrains.
2. Unspin cycles and return ready to install packages
list with suitable version specification.
See (taskFinalDepends)[./task#taskFinalDepends]
4. Unalias virtual packages to its providers calling
(taskUnalias)[./task#taskUnalias].
5. Another call of `taskSumVreq`, and i not shure why.
will check it later.
6. Do some cleanup (taskClearDepends)[./task#taskClearDepends]
7. Filter installed (taskFilterInstalled)[./task#taskFilterInstalled]
8. Generate `dload.sh`, `install.sh`, `uninstall.sh`.
See (taskMkInstall)[./task#taskMkInstall]

#### Example

```bash
$(stageWalk <task>)"
```

#### Options

* `task` a build task

### stageDownload

Function to excute the "dload" stage.

#### Example

```bash
$(stageDload <task>)"
```

#### Options

* `task` a build task

### stageInstall

Function to excute the "install" stage.

#### Example

```bash
$(stageInstall <task>)"
```

#### Options

* `task` a build task

### stageBinary

Function to excute the "build" stage.

#### Example

```bash
$(stageBinary <task>)"
```

#### Options

* `task` a build task

### stagePurge

Function to excute the "install" stage.

#### Example

```bash
$(stageInstall <task>)"
```

#### Options

* `task` a build task

