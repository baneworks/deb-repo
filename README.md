---
title: deb-repo
keywords: [linux, nix, debian, debian bullseye, dpkg]
date: 2023-07-31
---

# deb-repo-test

This is realisation for AstraLinux test task for the position of maintainer. The test includes a main and
additional task.

Main task of the test:

> Write a script in bash or python to download from the debian "bullseye" repository and automatically build
> from sources of several packages (bash gawk sed) and their build dependencies in pure debootstrap from
> debian bullseye repository. The result must be formatted as a deb package, and supplemented with comments.

Additional task:

> Consider the issue (possible only in theory) of ordering dependencies, breaking cyclic dependencies
> and formation of the assembly order.

# Preparing environment

As I working within [NixOS](https://nixos.org/) usage of debian native build stack is a kind tricky. The
main difficulty lies in the side effects of the storage system when we trying to chroot in debootstraped
guest system. For extra fun, as if the `NixOS` FHS incompatibility wasn't enough, the `debootstrap` utility
appears to be broken and abandoned. Well, having fun is having fun, so ...

Since we need a working environment for the Debian build stack, the obvious solution is to use qemu guest
and do all the work inside.

However, I am implementing another option - creating a working environment using NixOS (development shell
inside `nix flake`) with the necessary docker containers inside the environment and automated logging into
(`direnv`), updating and starting containers. See [flake.nix](./vms/flake.nix) for implementation details.

To use the environment:

1. cd to `vms` folder
2. wait for `direnv` invoke `nix flake` and rebuild (if needed) containers, packages, scrips
3. use `run-debian-bullseye [root] [bg]` to run container with or without enter into as user `mtain` (or
    `root`)
4. work inside container or use ssh to connect from host

# Usage

List of packages needed to build taken from [packages.built](./packages.built).

Since debootstrapped debian not even allow to work with .tar.xv all work is performed on the host. This includes
preparing the container for assembly, parsing DSC files and collecting dependencies.

If the parsing of the package dependency tree was successful, we install the required dependencies in the
container and trying to build a package.

1. From the `~/dev/deb-repo/vms`, load and run debian image (basically is pure bullseye-slim).

```sh
./run-debian-bullseye
```

2. Rename the resulting container to `debian` and run again:

```sh
docker rename `docker ps | sed -n "s/\(.*\)\sdebian:bullseye.*/\1/p"` debian
docker start -i debian
```

3. Run `~/dev/deb-repo/make-repo` on the host and wait for the build to complete.

# TODO

# References
