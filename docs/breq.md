# breq

A library for generating build-depends for a task.

## Overview

Function to pack depends to spaceless string.

## Index

* [breqWhichVersion](#breqwhichversion)
* [breqAddNode](#breqaddnode)

### breqWhichVersion

Function to check version reqs and return index of suitable.

#### Example

```bash
$(breqWhichVersion <req> <packages>)
```

#### Options

* `req` requrenment string like ">= 2.4 2.31-13+deb11u6".
* packages array of available in [bspec](./lib-bspec) format.

#### Exit codes

* **0**: on success
* **1**: on failure.

#### Output on stdout

* index of suitable package

### breqAddNode

Function to add node to build-depens tree. Reqursive.

#### Example

```bash
$(breqAddNode <level> <bspec> <retcode> <retvalue> <@parents>)"
```

#### Options

* level numeric target level of build-depens tree.
* bspec build-dependency in `bspec` format.
* retvalue result value of pervious execution.
* parents parents array of build-dependency upto root node.

#### Exit codes

* usial behaivor

#### Output on stdout

* last processed (failed) package in bspec format (@see bspec).

#### See also

* [bspec](#bspec)

