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

2. Run `~/dev/deb-repo/make-repo` on the host and wait for the build to complete.

# Results

Results of `~/dev/deb-repo/make-repo` with **cyclic vetrex detection** is:

```sh bash
❯❯❯ make-repo
[bash]: dirs ...
[bash]: sources ...
[bash]: build-reqs ...
{bash autoconf}
  ->{perl}
    ->{perl-base} [!dep]
    ->{perl-modules-5.32}
      ->{perl-base} [!dep]
    ->{libperl5.32}
      ->{libbz2-1.0}
        ->{libc6}
          ->{libgcc-s1}
            ->{gcc-10-base} [!dep]
            ->[+libc6]
          ->{libcrypt1}
            ->[+libc6]
      ->[+libc6]
      ->[+libcrypt1]
      ->{libdb5.3}
        ->[+libc6]
      ->{libgdbm-compat4}
        ->[+libc6]
        ->{libgdbm6}
          ->[+libc6]
      ->[+libgdbm6]
      ->{zlib1g}
        ->[+libc6]
      ->[+perl-modules-5.32]
  ->{m4}
    ->[+libc6]
    ->{libsigsegv2}
      ->[+libc6]
  ->{debianutils} [!dep]
{bash autotools-dev} [!dep]
{bash bison}
  ->[+m4]
  ->[+libc6]
{bash libncurses5-dev}
  ->{libtinfo6}
    ->[+libc6]
  ->{libncurses-dev}
    ->[+libtinfo6]
    ->{libncurses6}
      ->[+libtinfo6]
      ->[+libc6]
    ->{libncursesw6}
      ->[+libtinfo6]
      ->[+libc6]
    ->{libc6-dev}
      ->[+libc6]
      ->{libc-dev-bin}
        ->[+libc6]
        ->[+libc6]
      ->{linux-libc-dev} [!dep]
      ->{libcrypt-dev}
        ->[+libcrypt1]
      ->{libnsl-dev}
        ->{libnsl2}
          ->[+libc6]
          ->{libtirpc3}
            ->[+libc6]
            ->{libgssapi-krb5-2}
              ->[+libc6]
              ->{libcom-err2}
                ->[+libc6]
              ->{libk5crypto3}
                ->[+libc6]
                ->{libkrb5support0}
                  ->[+libc6]
              ->{libkrb5-3}
                ->[+libc6]
                ->[+libcom-err2]
                ->[+libk5crypto3]
                ->{libkeyutils1}
                  ->[+libc6]
                ->[+libkrb5support0]
                ->{libssl1.1}
                  ->[+libc6]
                  ->{debconf} [!dep]
                  ->{debconf-2.0} [!dep]
              ->[+libkrb5support0]
            ->{libtirpc-common} [!dep]
        ->{libtirpc-dev}
          ->[+libtirpc3]
    ->[+libc-dev]
    ->{ncurses-bin} [!dep]
```

# TODO

# References
