/* Alpha realise of debian development environment for NixOS.
   This flake support package generation for few architectures,
   but for now (because of docker) it allow
   run debian only for x86_64-linux, aarch64-linux system.
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
        #   builder = "${pkgs.bash}/bin/bash";
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
        aptListsDebianBbullseye = with pkgs; stdenv.mkDerivation {
          name = "debian-bullseye-apt-lists";
          phases = [ "installPhase" ];
          srcs = [
            (fetchurl { url = "http://ftp.debian.org/debian/dists/bullseye/InRelease";
                        sha256 = "6XZxmxvje542upnVpf9ldCY5LdCT3qRrvkvlQvw6Mbo=";
                        name = "deb.debian.org_debian_dists_bullseye_InRelease"; })
            (fetchurl { url = "http://ftp.debian.org/debian/dists/bullseye-updates/InRelease";
                        sha256 = "p4E4aNpDaCks5a8ZdmpeH+uYun+N/9vs1qSrhHJdC0Q=";
                        name = "deb.debian.org_debian_dists_bullseye-updates_InRelease"; })
            (fetchurl { url = "https://security.debian.org/debian-security/dists/bullseye-security/InRelease";
                        sha256 = "MKKwg8+a9pfVNZG/8z1sMaXHSDO5e+qvxn1wf43Bzpo=";
                        name = "deb.debian.org_debian-security_dists_bullseye-security_InRelease"; })
            (fetchurl { url = "http://ftp.debian.org/debian/dists/bullseye/main/binary-amd64/Packages.gz";
                        sha256 = "sha256-Xvz9HhG8pmG66rBA3f9PwoTa7GkST26Pn3IQoNkbc1Y=";
                        name = "deb.debian.org_debian_dists_bullseye_main_binary-amd64_Packages.gz"; })
            (fetchurl { url = "http://ftp.debian.org/debian/dists/bullseye-updates/main/binary-amd64/Packages.xz";
                        sha256 = "RN7TliEpcAdWUE2G+FSkUGzEiZ+gj/Q7iQeIh+UIkZg=";
                        name = "deb.debian.org_debian_dists_bullseye-updates_main_binary-amd64_Packages.xz"; })
            (fetchurl { url = "https://security.debian.org/debian-security/dists/bullseye-security/main/binary-amd64/Packages.gz";
                        sha256 = "qER8V6uVO0yH4a9Lv0KQTArwMkjUGPJ2p7xNipVVOqI=";
                        name = "deb.debian.org_debian-security_dists_bullseye-security_main_binary-amd64_Packages.gz"; })
            (fetchurl { url = "http://ftp.debian.org/debian/dists/bullseye/main/source/Sources.gz";
                        sha256 = "vKfHQv95pKtGn6cO2SfvNXNRbh/iurzl4cVUqe1Hong=";
                        name = "deb.debian.org_debian_dists_bullseye_main_source_Sources.gz"; })
            (fetchurl { url = "http://ftp.debian.org/debian/dists/bullseye-updates/main/source/Sources.xz";
                        sha256 = "CJNWbhWTBA9ykjOL5YrK4hRS1Avj0zSml5qu7Fafl2I=";
                        name = "deb.debian.org_debian_dists_bullseye-updates_main_source_Sources.xz"; })
            (fetchurl { url = "https://security.debian.org/debian-security/dists/bullseye-security/main/source/Sources.gz";
                        sha256 = "E4Kgzgx3Kp7FlaMORZuZo+Nu6ix6vHAdmNzIJ+ZuJG4=";
                        name = "deb.debian.org_debian-security_dists_bullseye-security_main_source_Sources.gz"; })
          ];
          sourceRoot = ".";
          installPhase = ''
            # runHook preInstall

            mkdir -p $out/var/lib/apt/lists
            for s in $srcs; do
              tn=$(echo $s | sed "s/.*-deb\(.*\)/deb\1/")
              ln -s $s $out/var/lib/apt/lists/$tn
            done

            # runHook postInstall
          '';
        };
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
          copyToRoot = pkgs.buildEnv {
            name = "addins-layer";
            paths = [ pkgs.bashInteractive aptListsDebianBbullseye ];
            pathsToLink = [ "/bin" "/var" ];
          };
          runAsRoot = ''
            #!${pkgs.stdenv.shell}
            set -ex
            #? user cfg
            /usr/sbin/adduser mtain
            /usr/sbin/usermod -aG sudo mtain
            /bin/sed -i "s/^root:x/root:/g" /etc/passwd
            /bin/sed -i "s/^root:\*:/root::/g" /etc/shadow
            #? net cfg
            echo "nameserver 10.0.2.3" > /etc/resolv.conf
            # echo "85.143.112.112 deb.debian.org" #? russian mirror
            #? apt cfg
            echo "deb-src http://deb.debian.org/debian bullseye main" >> /etc/apt/sources.list
            echo "deb-src http://deb.debian.org/debian-security/ bullseye-security main" >> /etc/apt/sources.list
            echo "deb-src http://deb.debian.org/debian bullseye-updates main" >> /etc/apt/sources.list
          '';
          config = {
            Hostname = "debootstrap";
            User = "mtain";
            Cmd = "${pkgs.bashInteractive}/bin/bash";
          };
        };
        runDebianBullseye = pkgs.writeShellScriptBin "run-debian-bullseye" ''
          #!/usr/bin/env bash
          set -e; set -o pipefail;

          if [[ $1 == "help" ]]; then
            cat << EOM
            This script load and start Debian Bullseye docker container
            Container can be started with (default) or without attaching

            usage: run-debian-bullseye [bg]
            options: bg - to run container without attaching
          EOM
            exit 0
          else
            if ! [[ -z $1 ]] && [[ $1 != "bg" ]]; then
              echo "Unknow args, try help"
              exit -1
            fi
          fi

          #? values
          if [[ -f ".prev_image" ]]; then
            prev_image=$(cat ".prev_image")
          fi
          [[ $1 == "bg" ]] || run_in_bg="-i"

          #? check for diff between current and previous image
          if [[ $prev_image != "${dockerDebianBbullseyeSlim}" ]]; then
            echo "Image new or changed, propagating to docker ..."
            old_img_id=$((docker images ) | sed -n 's/^\(debian\)\s*\(bullseye-slim\)\s*\([0-9a-f]*\).*/\1:\2:\3/p')
            old_cnt_id=$(docker ps -aq -f ancestor=debian:bullseye -f name=debian)

            if ! [[ -z $prev_image ]]; then
              echo "Removing previous docker container... "
              docker rm --force $old_cnt_id
              echo "Removing previous docker image... "
              docker rmi --force debian:bullseye
            fi

            echo "Loading docker image: ${dockerDebianBbullseyeSlim}"
            docker load < ${dockerDebianBbullseyeSlim}
            echo "${dockerDebianBbullseyeSlim}" > ".prev_image"
            run_new=1
          fi

          #? run docker
          if [[ $run_new ]]; then
            docker run --platform linux/${legacyArchTag} -h debian --name debian $run_in_bg -t debian:bullseye
          else
            if ! [[ -z $( docker ps -q -f ancestor=debian:bullseye -f name=debian ) ]]; then
              docker attach debian
            else
              docker start $run_in_bg debian
            fi
          fi
        '';
      in {
        packages = {
          # debian-bullseye-chroot = chrootDebianBullseye;
          debian-bullseye-apt-lists = aptListsDebianBbullseye;
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
            # pkgs.makeWrapper
            # pkgs.coreutils
            # pkgs.fakeroot
            # pkgs.fakechroot
            # pkgs.debootstrap
            # pkgs.nix-prefetch-docker
            # pkgs.dive
            # pkgs.cmake
            # pkgs.gnumake
            aptListsDebianBbullseye
            # dockerDebianBbullseyeSlim
            runDebianBullseye
          ];
          shellHook = ''
            cat << EOM
            =========== dev shell for debian packaging ===========
            current system: ${builtins.toString system}
            helpers: run-debian-bullseye, stop-debian-bullseye
            ======================================================
            EOM
          '';
        };
      });
}
