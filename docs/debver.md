# lib-debver

A library for parsing and comparing debian version strings.

## Overview

Function to compare two debian's version strings. Compares by left to right by single character.

## Index

* [dverCmp](#dvercmp)
* [dverIsVReq](#dverisvreq)
* [dverCondition](#dvercondition)
* [dverTarget](#dvertarget)
* [dverMatch](#dvermatch)
* [dverCompose](#dvercompose)

### dverCmp

Function to compare two debian's version strings. Compares by left to right by single character.

#### Example

```bash
$(dverCmp <left_ver> <right_ver>)
```

#### Options

* `left` left debian version string.
* `right` right debian version string.

#### Exit codes

* **0**: on success.
* **1**: on failure.

#### Output on stdout

* `>` if `left` is greater than `right`.
* `=` if `left` is equals `right`.
* `<` if `left` is less than `right`.

#### See also

* [deb-version](https://manpages.ubuntu.com/manpages/xenial/en/man5/deb-version.5.html)

### dverIsVReq

Is string an version requrenment.

#### Example

```bash
$(dverIsVReq <str>)
```

#### Options

* `str` requrenment string like ">= 2.4 2.31-13+deb11u6".

#### Output on stdout

* "true" if str is Vreq.
* "" if not.

### dverCondition

Function to extract condition operator from depend requrenment string.

#### Example

```bash
$(dverCondition <req>)
```

#### Options

* `req` requrenment string like ">= 2.4 2.31-13+deb11u6".

#### Output on stdout

* condition operator string.

### dverTarget

Function to extract target version from depend requrenment string.

#### Example

```bash
$(dverTarget <req>)"
```

#### Options

* `req` requrenment string like ">= 2.4 2.31-13+deb11u6".

#### Output on stdout

* target version.

### dverMatch

Function to apply depend requrenment string to package version.

#### Example

```bash
$(dverMatch <req> <version>)
```

#### Options

* `req` requrenment string like ">= 2.4 2.31-13+deb11u6".
* `version` package version.

#### Output on stdout

* "true" if matched.
* "" if not matched.

### dverCompose

Function to compose two version's requirenment string.
Conposition done in *non-extending* mode (e.g. result of
composition of ">= 2.4" + ">= 2.5" will be ">= 2.5")

#### Example

```bash
$(dverCompose <left> <right>)
```

#### Options

* `left` requrenment string to compose with right (e.g. ">= 2.4").
* `right` requrenment string to compose (e.g. ">= 2.5").

#### Exit codes

* **0**: on success composition (in this case )
* **1**: on failure
* **2**: not implemented yet

#### Output on stdout

* new composed version requirenment string on success.
* "" real result of composition is empty (if exitcode = 0).

#### See also

* [version requrenment string](https://manpages.ubuntu.com/manpages/xenial/en/man5/deb-control.5.html)

