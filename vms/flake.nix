/* Initial realise of debian development environment for NixOS.
   This flake design by itself supports package generation for
   few architectures, but for now (because of docker) it allow
   run debian only for x86_64-linux, aarch64-linux system.
   TODO: migrate to quemu to support all archs
*/
{
  description = "flake to maintain debootstrap based cross-packaging";


  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # systems.url = "github:nix-systems/x86_64-linux"; #? x86_64-linux only
    systems.url = "github:nix-systems/default-linux";  #? x86_64-linux, aarch64-linux
    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.systems.follows = "systems";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        legacyArchTag = if system == "x86_64-linux"
                  then "amd64"
                  else if system == "x86_64-linux"
                    then "arm64"
                    else system;
        # fixme: nix's debootstrap seems to be broken
        # todo: fix issues
        # chrootDebianBullseye = pkgs.stdenv.mkDerivation rec {
        #   pname = "debian";
        #   version = "bullseye";
        #   name = "${pname}-${version}";
        #   builder = "${pkgs.bash}/bin/bash"; # fixme: create dir
        #   args = [ "fakeroot"
        #            "fakechroot"
        #            "debootstrap --variant=fakechroot"
        #            "--arch ${legacyArchTag}"
        #            "bullseye"
        #            "debootstrap-bullseye"
        #            "http://ftp.ru.debian.org/debian" ];
        #   src = ./.;
        #   inherit system;
        # };
        dockerDebianBbullseyeSlim = pkgs.dockerTools.buildImage {
          name = "debian";
          tag = "bullseye";
          fromImageName = "debian";
          fromImageTag = "bullseye-slim";
          fromImage = pkgs.dockerTools.pullImage {
            imageName = "debian";
            finalImageName = "debian";
            finalImageTag = "bullseye-slim";
            imageDigest = "sha256:fd3b382990294beb46aa7549edb9f40b11a070f959365ef7f316724b2e425f90";
            sha256 = "1c5l8007hd301a7b1dvqrdpyfjsl9qbsn7f9r85zbbl0kaj8dwm0";
          };
          /*
          TODO: use dockerTools.buildLayeredImage and add layers:
            1. to put inside /var/lib/apt/lists and cacerts
            2. ssh layer
          */
          copyToRoot = pkgs.buildEnv {
            name = "addins-layer";
            paths = [ pkgs.bashInteractive ];
            pathsToLink = [ "/bin" ];
          };
          runAsRoot = ''
            #!${pkgs.stdenv.shell}
            set -ex
            echo "nameserver 10.0.2.3" > cat /etc/resolv.conf
            # echo "85.143.112.112 deb.debian.org"
            # /usr/bin/apt-get update
            # /usr/bin/apt-get install sudo
            /usr/sbin/adduser mtain
            /usr/sbin/usermod -aG sudo mtain
            /bin/cat /etc/passwd > /etc/passwd-
            /bin/cat /etc/shadow > /etc/shadow-
            (/bin/cat /etc/passwd- | /bin/sed "s/^root:x/root:/g") > /etc/passwd
            (/bin/cat /etc/shadow- | /bin/sed "s/^root:\*:/root::/g") > /etc/shadow
            rm /etc/shadow- /etc/passwd-
          '';
          config = {
            Hostname = "debootstrap";
            User = "mtain";
            Cmd = "${pkgs.bashInteractive}/bin/bash";
          };
        };
        # TODO: add container mamagment
        runDebianBullseye = pkgs.writeShellScriptBin "run-debian-bullseye" ''
          #!/usr/bin/env bash
          set -e; set -o pipefail;
          echo "Loading docker image: ${dockerDebianBbullseyeSlim}"
          if [ `docker images -q debian:bullseye | wc -l` -ge 1 ]; then
            oldimage=$((docker images ) | sed -n 's/^\(debian\)\s*\(bullseye-slim\)\s*\([0-9a-f]*\).*/\1:\2:\3/p')
            echo "Removing previous docker image: $oldimage"
            docker rmi --force debian:bullseye
          fi
          image=$((docker load < ${dockerDebianBbullseyeSlim}) | sed -n '$s/^Loaded image: //p')
          echo "Loaded image: $image"
          if [ "$1" = "root" ]; then
            docker run --platform linux/${legacyArchTag} -l debian -u 0 -i -t debian:bullseye bash
          else
            docker run --platform linux/${legacyArchTag} -l debian -i -t debian:bullseye
          fi
        '';
      in {
        packages = {
          # debian-bullseye-chroot = chrootDebianBullseye;
          debian-bullseye-docker = dockerDebianBbullseyeSlim;
          run-debian-bullseye = runDebianBullseye;
          default = runDebianBullseye; # defaults to nix build
        };
        # apps = rec {
        #   debian-bullseye-docker = flake-utils.lib.mkApp { drv = self.packages.${system}.debian-bullseye-docker; };
        #   default = dockerDebianBbullseye;
        # };
        devShell = pkgs.mkShell {
          buildInputs = [
            pkgs.makeWrapper
            pkgs.coreutils
            pkgs.fakeroot
            pkgs.fakechroot
            pkgs.debootstrap
            pkgs.nix-prefetch-docker
            pkgs.cmake
            pkgs.gnumake
            runDebianBullseye
          ];
          shellHook = ''
            echo "=========== dev shell for debian packaging ==========="
            echo "current system: ${builtins.toString system}"
            echo "======================================================"
          '';
        };
      });
}
