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
[bash autoconf]  ... [ OK ]
[bash autoconf perl]  ... [ OK ]
[bash autoconf perl perl-base]  ... [ !dep ] ... [ OK ]
[bash autoconf m4]  ... [ OK ]
[bash autoconf m4 libc6]  ... [ OK ]
[bash autoconf m4 libc6 libgcc-s1]  ... [ OK ]
[bash autoconf m4 libc6 libgcc-s1 gcc-10-base]  ... [ !dep ] ... [ OK ]
[bash autoconf debianutils]  ... [ !dep ] ...
[bash autotools-dev]  ... [ !dep ] ...
[bash bison]  ... [ +m4 ] ... [ OK ]
[bash bison libc6]  ... [ OK ]
[bash bison libc6 libgcc-s1]  ... [ +gcc-10-base ] ...
[bash libncurses5-dev]  ... [ OK ]
[bash libncurses5-dev libtinfo6]  ... [ +libc6 ] ... [ OK ]
[bash libncurses5-dev libncurses-dev]  ... [ +libtinfo6 ] ...
[bash texinfo]  ... [ +libc6 ] ... [ +perl ] ... [ OK ]
[bash texinfo perlapi-5.32.0]  ... [ !dep ] ... [ OK ]
[bash texinfo libtext-unidecode-perl]  ... [ +perl ] ... [ OK ]
[bash texinfo libxml-libxml-perl]  ... [ +perl ] ... [ OK ]
[bash texinfo tex-common]  ... [ OK ]
[bash texinfo tex-common ucf]  ... [ OK ]
[bash texinfo tex-common ucf debconf]  ... [ !dep ] ...
[bash texi2html]  ... [ +libtext-unidecode-perl ] ... [ OK ]
[bash texi2html perl:any]  ... [ +perl-base ] ...
[bash debhelper]  ... [ OK ]
[bash debhelper autotools-dev]  ... [ !dep ] ... [ OK ]
[bash debhelper dh-autoreconf]  ... [ OK ]
[bash debhelper dh-autoreconf autoconf]  ... [ +perl ] ... [ OK ]
[bash debhelper dh-strip-nondeterminism]  ... [ OK ]
[bash debhelper dh-strip-nondeterminism libdebhelper-perl]  ... [ +perl:any ] ... [ OK ]
[bash debhelper dpkg]  ... [ OK ]
[bash debhelper dpkg tar]  ... [ !dep ] ... [ OK ]
[bash debhelper dpkg-dev]  ... [ +perl ] ... [ OK ]
[bash debhelper dwz]  ... [ +libc6 ] ... [ OK ]
[bash debhelper file]  ... [ +libc6 ] ... [ OK ]
[bash debhelper libdpkg-perl]  ... [ +perl ] ... [ OK ]
[bash debhelper man-db]  ... [ OK ]
[bash debhelper man-db bsdextrautils]  ... [ !dep ] ... [ OK ]
[bash debhelper libdebhelper-perl]  ... [ +perl:any ] ... [ OK ]
[bash debhelper po-debconf]  ... [ OK ]
[bash debhelper po-debconf gettext]  ... [ +libc6 ] ... [ +perl:any ] ...
[bash gettext]  ... [ +libc6 ] ... [ OK ]
[bash gettext libgomp1]  ... [ +gcc-10-base ] ... [ OK ]
[bash gettext libunistring2]  ... [ +libc6 ] ... [ OK ]
[bash gettext libxml2]  ... [ +libc6 ] ... [ OK ]
[bash gettext gettext-base]  ... [ +libc6 ] ... [ +dpkg ] ... [ OK ]
[bash gettext install-info]  ... [ +libc6 ] ...
[bash sharutils]  ... [ +libc6 ] ...
[bash locales]  ... [ OK ]
[bash locales libc-bin]  ... [ +libc6 ] ... [ OK ]
[bash locales libc-l10n]  ... [ !dep ] ... [ +debconf ] ... [ OK ]
[bash locales debconf-2.0]  ... [ !dep ] ...
[bash time]  ... [ +libc6 ] ...
[bash xz-utils]  ... [ +libc6 ] ... [ OK ]
[bash xz-utils liblzma5]  ... [ +libc6 ] ...
[bash dpkg-dev]  ... [ +perl ] ... [ +libdpkg-perl ] ... [ +tar ] ... [ OK ]
[bash dpkg-dev bzip2]  ... [ OK ]
[bash dpkg-dev bzip2 libbz2-1.0]  ... [ +libc6 ] ... [ OK ]
[bash dpkg-dev xz-utils]  ... [ +libc6 ] ... [ OK ]
[bash dpkg-dev patch]  ... [ +libc6 ] ... [ OK ]
[bash dpkg-dev make]  ... [ +libc6 ] ... [ OK ]
[bash dpkg-dev binutils]  ... [ OK ]
[bash dpkg-dev binutils binutils-common]  ... [ !dep ] ...
```

# TODO

# References
