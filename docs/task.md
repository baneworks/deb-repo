# task

Task library.

## Overview

Function to parse task dcs and return breqs array.

## Index

* [taskReqs](#taskreqs)
* [taskSumVreq](#tasksumvreq)
* [taskUnalias](#taskunalias)
* [taskFinalDepends](#taskfinaldepends)
* [taskClearDepends](#taskcleardepends)
* [taskFilterInstalled](#taskfilterinstalled)
* [taskMkInstall](#taskmkinstall)
* [taskDload](#taskdload)
* [taskDebInstall](#taskdebinstall)

### taskReqs

Function to parse task dcs and return breqs array.

#### Example

```bash
$(taskReqs <task>)"
```

#### Options

* `task` a build task

### taskSumVreq

Function to summarize all of version constrains.

*  Package entries (i.e. endnode of graph) can be in few forms:
1. like 'libc6/2.31-13+deb11u5' - this is definetly a end node
with version specification
2. like 'libc6/2.31-13+deb11u5 <provides>' - also a end node,
with version specification and 'provides' list
3. like 'libc6/' - a end node or package reqirenments
4. like 'libc6/ <provides>' - a end node or package reqirenments
*  To change end nodes in forms 1, 2:
*  a. check version compatibility and leave as is if fit
*  b. if not - call wichVersion find suitable and replace

? The 3rd form can be replaced to vreq without any consequences

! The 4th form looks discouraging and definitely cannot be replaced
! by vreq. I think you can do the same for cases of forms 1,2, but
! I'm not sure. So, for now, consider as a bug

#### Example

```bash
$(taskSumVReq <task> <in> <out>)
```

#### Options

* `task` a build task.
* in a name `flatten` file to read from
* out a name of result file

#### Exit codes

* **0**: on success
* **1**: on failure
* **2**: success with issues

#### See also

* [Vreq rewrite](./README.md#version-requrinments)

### taskUnalias

Function to unalias virtual packages to its providers.
Actually we need to remove already statisfied alias and preserve
unsatisfied virtuals.

#### Example

```bash
$(taskSumVReq <task> <in> <out>)
```

#### Options

* `task` a build task.
* in a name `flatten` file to read from
* out a name of result file

#### Exit codes

* **0**: on success
* **1**: on failure

#### See also

* [Vreq rewrite](./README.md#version-requrinments)

### taskFinalDepends

Function to finalize all depends to flat list.
Parses `.flatten`, unspin cycles and return ready to install
packages list with suitable version specification.

#### Example

```bash
$(taskFinalDepends <task> <in> <out>)
```

#### Options

* `task` a build task.
* in a name `flatten` file to read from
* out a name of result file

#### Exit codes

* **0**: on success
* **1**: on failure

#### See also

* [depends parsing](./README.md#-depends-parsing)

### taskClearDepends

Function to do some cleanup on depends.

#### Example

```bash
$(taskClearDepends <task> <in> <out>)
```

#### Options

* `task` a build task.
* in a name `flatten` file to read from
* out a name of result file

#### Exit codes

* **0**: on success
* **1**: on failure

### taskFilterInstalled

Function to generate .

#### Example

```bash
$(taskFilterInstalled <task> <in> <out>)
```

#### Options

* `task` a build task.
* in a file to read from
* out a name of result file

#### Exit codes

* **0**: on success
* **1**: on failure

### taskMkInstall

Function to generate install list.

#### Example

```bash
$(taskMkInstall <task> <in> <out>)
```

#### Options

* `task` a build task.
* in a file to read from
* out a name of result file

#### Exit codes

* **0**: on success
* **1**: on failure

### taskDload

Function to generate download script.

#### Example

```bash
$(taskDload <task> <in> <out>)
```

#### Options

* `task` a build task.
* in a file to read from
* out a name of result file (without task name)

#### Exit codes

* **0**: on success
* **1**: on failure

### taskDebInstall

Function to generate install script.

#### Example

```bash
$(taskDebInstall <task> <in> <install> <uninstall>)
```

#### Options

* `task` a build task.
* `in` a package list file.
* `install` a name of install script
* `uninstall` a name of uninstall script

#### Exit codes

* **0**: on success
* **1**: on failure

